classdef spatialTransferSteppingSurround < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        centerDiameter = 250 % um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 800 % um
        flashDuration=50 % ms
        fixFlashTime=100  % ms
        barWidth=[20 60 120]  % um
        variableFlashTime=[50 200 400]   % um
        surroundStepContrast=[0  1 -1]
        adaptContrast=0.5
        testContrast=0.5
        meanIntensity=0.25
        preTime=750
        stimTime=1000
        tailTime=750
        centerZeroMean=false
        psth=true
        numberOfAverages = uint16(3) % number of epochs to queue
        amp
    end
    
    properties(Hidden)
        ampType
        currentBarWidth
        currentFlashDelay
        currentPhase
        currentSurroundStepContrast
        flashTimes
        phases=[0 180]
        startMatrix
        adaptMatrix
        testMatrix     
        surroundMatrix
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
      
            obj.showFigure('edu.washington.riekelab.chris.figures.spatialAdaptFigure',...
                obj.rig.getDevice(obj.amp),'barWidth',obj.barWidth,'variableFlashTimes',obj.variableFlashTime, ...
                'psth',obj.psth,'coloredBy',obj.phases);
            
            if obj.testContrast<0 && obj.centerZeroMean
                obj.testContrast=-((1-obj.adaptContrast)/2);  % this push positive stripes back to mean intensity,
                % and dark stripe to zero and avoid out of range
            end
        end
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            phaseIndex=mod(obj.numEpochsCompleted,length(obj.phases))+1;
            flashIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,length(obj.phases))) ...,
                /length(obj.phases),length(obj.variableFlashTime))+1;
            barWidthIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,length(obj.phases)*length(obj.variableFlashTime)))  ...,
                /(length(obj.phases)*length(obj.variableFlashTime)),length(obj.barWidth))+1;
            surroundIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,length(obj.phases)*length(obj.variableFlashTime)*length(obj.barWidth))) ...,
                /(length(obj.phases)*length(obj.variableFlashTime)*length(obj.barWidth)),length(obj.surroundStepContrast))+1;
        
            obj.currentPhase=obj.phases(phaseIndex);
            obj.currentFlashDelay=obj.variableFlashTime(flashIndex);
            obj.currentBarWidth=obj.barWidth(barWidthIndex);
            obj.currentSurroundStepContrast=obj.surroundStepContrast(surroundIndex);
            obj.flashTimes=[obj.fixFlashTime obj.preTime+obj.currentFlashDelay obj.preTime+obj.stimTime-obj.fixFlashTime ...,
                obj.preTime+obj.stimTime+obj.currentFlashDelay  obj.preTime+obj.stimTime+obj.tailTime-obj.fixFlashTime];
 
                                                                                                                                                                                                                                                 
            % create center matrix for adapting and flashing
            obj.adaptMatrix.base=obj.createCenterGrateMat(obj.meanIntensity,0,0,'seesaw');
            if obj.centerZeroMean
                obj.adaptMatrix.test=obj.createCenterGrateMat(obj.meanIntensity,obj.adaptContrast,0,'seesaw');
            else
                obj.adaptMatrix.test=obj.createCenterGrateMat(obj.meanIntensity*(1+obj.adaptContrast),obj.adaptContrast/(1+obj.adaptContrast),0,'seesaw');
            end
            obj.testMatrix.base=obj.createCenterGrateMat(0,1,obj.currentPhase,'seesaw');  % this create the test grating
            obj.testMatrix.test=obj.createCenterGrateMat(obj.meanIntensity*obj.testContrast,1, obj.currentPhase,'seesaw');  % this create the test grating
            
            
            % create the surround matrix 
            obj.surroundMatrix.base=obj.createSurroundGrateMat(obj.meanIntensity,0);
            obj.surroundMatrix.test=obj.createSurroundGrateMat(obj.meanIntensity,obj.currentSurroundStepContrast);   
            obj.startMatrix=obj.adaptMatrix.base+obj.testMatrix.base+obj.surroundMatrix.base;

             
            % there are three experimenatl parameters manipulated. the
            % arrangement change pattern, flashDelay, then bar width, the order
            % can be switched accordingly.
            epoch.addParameter('currentPhase', obj.currentPhase);
            epoch.addParameter('currentBarWidth', obj.currentBarWidth);
            epoch.addParameter('currentFlashDelay', obj.currentFlashDelay);
            epoch.addParameter('currentSurroundStepContrast', obj.currentSurroundStepContrast);
        end
        
        function p=createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
             p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.meanIntensity); % Set background intensity
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);

    
            % add  grating
            obj.startMatrix=uint8(obj.startMatrix);
            scene=stage.builtin.stimuli.Image(obj.startMatrix);
            scene.size = [annulusOuterDiameterPix  annulusOuterDiameterPix]; %scale up to canvas size
            scene.position=canvasSize/2;
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);

            sceneController = stage.builtin.controllers.PropertyController(scene, 'imageMatrix',...
                @(state) obj.getImgMatrix( state.time));
            p.addController(sceneController);
                
            % add aperture
            if obj.annulusOuterDiameter>0
                aperture=stage.builtin.stimuli.Rectangle();
                aperture.position=canvasSize/2;
                aperture.size=[annulusOuterDiameterPix annulusOuterDiameterPix];
                mask=stage.core.Mask.createCircularAperture(1,1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
                aperture.color=obj.meanIntensity;
            end
                              
        end
        
        
        function [imgMat] = getImgMatrix(obj,time)
            adaptMat=obj.adaptMatrix.base;
            % update the center matrix 
            if time>obj.preTime*1e-3  && time<(obj.preTime+obj.stimTime)*1e-3
                adaptMat=obj.adaptMatrix.test;
            end
            testMat=obj.testMatrix.base;
            for i=1:length(obj.flashTimes)
                if time>obj.flashTimes(i)*1e-3 && time< (obj.flashTimes(i)+obj.flashDuration)*1e-3
                    testMat=obj.testMatrix.test;
                end
            end
            % update the surround matrix
            surroundMat=obj.surroundMatrix.base;
            if time>obj.preTime*1e-3 && time>(obj.preTime+obj.stimTime)*1e-3
                surroundMat= obj.surroundMatrix.test;
            end
            imgMat=adaptMat+testMat+surroundMat;
            if max(imgMat(:))>255 || min(imgMat(:))<0
                disp(['max__' num2str(max(imgMat(:))) '__min__' num2str(min(imgMat(:)))]);
                error('img matrix intensity out of range');
            end
            imgMat=uint8(imgMat);
        end
        
 
        
        function [sinewave2D] = createCenterGrateMat(obj,meanIntensity,contrast,phase,mode)
            centerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.centerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
            currentBarWidthPix=ceil(obj.rig.getDevice('Stage').um2pix(obj.currentBarWidth));
            x =pi*meshgrid(linspace(-annulusOuterDiameterPix/2,annulusOuterDiameterPix/2,annulusOuterDiameterPix));
            sinewave2D =sin(x/currentBarWidthPix +phase/180*pi);
            if strcmp(mode,'seesaw')
                sinewave2D(sinewave2D>0)=1;
                sinewave2D(sinewave2D<=0)=-1;
            end
            sinewave2D=(1+sinewave2D*contrast) *meanIntensity*255;
            %aperture the center 
            for i=1:size(sinewave2D,1)
                for j=1:size(sinewave2D,2)
                    if sqrt((i-annulusOuterDiameterPix/2)^2+(j-annulusOuterDiameterPix/2)^2)> centerDiameterPix/2
                        sinewave2D(i,j)=0;
                    end
                end
            end
        end
        
        function [x] = createSurroundGrateMat(obj,meanIntensity,contrast)
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
            x =ones(annulusOuterDiameterPix,annulusOuterDiameterPix);
            %aperture the center
            for i=1:size(x,1)
                for j=1:size(x,2)
                    if sqrt((i-annulusOuterDiameterPix/2)^2+(j-annulusOuterDiameterPix/2)^2)< annulusInnerDiameterPix/2
                        x(i,j)=0;
                    end
                end
            end
            x=x*meanIntensity*(1+contrast)*255;
            
        end
        
            
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared <obj.numberOfAverages*length(obj.surroundStepContrast)* ...,
                length(obj.phases)*length(obj.barWidth)*length(obj.variableFlashTime);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted <obj.numberOfAverages*length(obj.surroundStepContrast)* ...,
                length(obj.phases)*length(obj.barWidth)*length(obj.variableFlashTime);
        end
    end
        
end



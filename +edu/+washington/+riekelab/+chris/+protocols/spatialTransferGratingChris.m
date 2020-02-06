classdef spatialTransferGratingChris < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        apertureDiameter=300   % um
        barWidth=[10 20 40 80 120] % um
        flashDuration=50 % ms
        fixFlashTime=100
        variableFlashTime=[50 100 200 400]
        adaptaContrast=0.5
        testContrast=0.5
        meanIntensity=0.15
        preTime=1000
        stimTime=2000
        tailTime=1000
        zeroMean=false
        downSample=4
    end
    
    properties(Hidden)
        ampType
        currentBarWidth
        currentFlashDelay
        currentPhase
        flashTimes
        phases=[0 180]
        startMatrix
        adaptMatrix
        testMatrix
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
            %%%%%%%%% need a new online analysis figure later
            obj.showFigure('edu.washington.riekelab.chris.figures.spatialAdaptFigure',...
                obj.rig.getDevice(obj.amp),'barWidth',obj.barWidth,'variableFlashTimes',obj.flashTimes, ...
                'psth',obj.psth,'coloredBy',obj.phases);         
            
            if obj.testContrast<0 && obj.zeroMean
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
            phaseIndex = mod(obj.numEpochsCompleted,length(obj.phases))+1;   % 3 because there are 2 different phase
            flashIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,length(obj.phases)))/length(obj.phases),legnth(obj.variableFlashTime))+1;
            obj.currentFlashDelay=obj.variableFlashTime(flashIndex);
            obj.flashTimes=[obj.fixFlashTime obj.preTime+obj.currentFlashDelay obj.preTime+obj.stimTime-obj.fixFlashTime ...,
                obj.preTime+obj.stimTime+obj.currentFlashDelay  obj.preTime+obj.stimTime+obj.tailTime-obj.fixFlashTime];
            barWidthIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,length(obj.phases)*obj.variableFlashTime))  ...,
                /(length(obj.phases)*obj.variableFlashTime),length(obj.barWidth))+1;
            obj.currentBarWidth=obj.barWidth(barWidthIndex);
                                                                                                                                                                                                                                                                        
            % create matrix for adapting and flashing
            obj.adaptMatrix.base=createGrateMat(obj.meanIntensity,0,0,'seesaw');
            if obj.zeroMean
                obj.adaptMatrix.test=createGrateMat(obj.meanIntensity,obj.adaptContrast,0,'seesaw');
            else
                obj.adaptMatrix.test=createGrateMat(obj.meanIntensity*(1+obj.adaptContrast),obj.adaptContrast/(1+obj.adaptContrast),0,'seesaw');
            end
            switch phaseIndex
                case 1
                    obj.currentPhase=0;
                    
                case 2
                    obj.currentPhase=180;
            end
            obj.testMatrix.base=createGrateMat(0,1,obj.currentPhase,'seesaw');  % this create the test grating
            obj.testMatrix.test=createGrateMat(obj.meanIntensity*obj.testContrast,1, obj.currentPhase,'seesaw');  % this create the test grating
            obj.startMatrix=uint8(obj.adaptMatrix.base+obj.testMatrix.base);
            % there are three experimenatl parameters manipulated. the
            % arrangement change pattern, flashDelay, then bar width, the order
            % can be switched accordingly.
            epoch.addParameter('currentPhase', obj.currentPhase);
            epoch.addPamameter('currentBarWidth', obj.currentBarWidth);
            epoch.addPamameter('currentFlashDelay', obj.currentFlashDelay);
        end
        
        function p=createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            apertureDiameterPix = 2*round(obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter)/2);
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.meanIntensity); % Set background intensity
            
            obj.startMatrix=uint8(obj.startMatrix);
            scene=stage.builtin.stimuli.Image(obj.startMatrix);
            scene.size = [apertureDiameterPix  apertureDiameterPix]; %scale up to canvas size
            scene.position=canvasSize/2;
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            
            
            sceneController = stage.builtin.controllers.PropertyController(scene, 'imageMatrix',...
                @(state)getImgMatrix( state.time));
            p.addController(sceneController);
            
            % add aperture
            if obj.apertureDiameter>0
                aperture=stage.builtin.stimuli.Rectangle();
                aperture.position=canvasSize/2;
                aperture.size=[apertureDiameterPix apertureDiameterPix];
                mask=Mask.createCircularAperture(1,1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
                aperture.color=obj.backgroundIntensity;
            end
        end
        
        
        function [imgMat] = getImgMatrix(obj,time)
            if time<obj.preTime*1e-3 || time>(obj.preTime+obj.stimTime)*1e-3
                adaptMat=obj.adaptMatrix.base;
            else
                adaptMat=obj.adaptMatrix.test;
            end
            
            testMat=obj.testMatrix.base;
            for i=1:length(obj.flashTimes)
                if time>obj.flashTimes(i)*1e-3 && time< (obj.flashTimes(i)+obj.flashDuration)*1e-3
                    testMat=obj.testMatrix.test;
                end
            end
            imgMat=adaptMat+testMat;
            if max(imgMat(:))>255 || min(imgMat(:))<0
                error('img matrix intensity out of range');
            end
            imgMat=uint8(imgMat);
        end
        
        
        function [sinewave2D] = createGrateMat(obj,meanIntensity,contrast,phase,mode)
            apertureDiameterPix = 2*round(obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter)/2);
            apertureDiameterPix=ceil(apertureDiameterPix/obj.downSample);
            obj.currentBarWidth=ceil(obj.currenBarWidth/obj.downSample);
            [x,~] = meshgrid(linspace(-pi,pi,apertureDiameterPix));
            numCycles=apertureDiameterPix/(2*obj.currentBarWidth);
            sinewave2D =sin(numCycles*(x-phase/180*pi));
            if strcmp(mode,'seesaw')
                sinewave2D(sinewave2D>0)=1;
                sinewave2D(sinewave2D<=0)=-1;
            end
            sinewave2D=(1+sinewave2D*contrast) *meanIntensity*255;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < length(obj.phases)*length(obj.barWidth)*length(obj.variableFlashTime);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < length(obj.phases)*length(obj.barWidth)*length(obj.variableFlashTime);
        end
        
    end
    
    
end


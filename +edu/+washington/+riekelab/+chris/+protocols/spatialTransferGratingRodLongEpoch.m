classdef spatialTransferGratingRodLongEpoch < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        apertureDiameter=300   % um
        flashDuration=100 % ms
        barWidth=[ 20 50 100]
        variableFlashTime=[5000 10000  15000 25000]
        fixFlashTime=2000
        phaseInterval=1000; % switch phases every flash
        meanIntensity=0.2
        adaptStepIntensity=0.5
        testContrast=0.3
        preTime=0
        stimTime=30000
        tailTime=30000
        downSample=1
        psth=true
        numberOfAverages = uint16(3) % number of epochs to queue
        amp
    end
    
    properties(Hidden)
        ampType
        currentBarWidth
        flashTimes
        phases=[0 180]
        startMatrix
        adaptMatrix
        testMatrix
        phaseIndex
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
            obj.showFigure('edu.washington.riekelab.chris.figures.spatialAdaptMultiplePhasesFigure',...
                obj.rig.getDevice(obj.amp),'barWidth',obj.barWidth, ...
                'psth',obj.psth);
            obj.flashTimes=sort([obj.preTime+obj.fixFlashTime obj.preTime+obj.variableFlashTime ...
                obj.preTime+obj.variableFlashTime+obj.phaseInterval obj.preTime+obj.stimTime+obj.fixFlashTime ...
                obj.preTime+obj.stimTime+obj.variableFlashTime obj.preTime+obj.stimTime+obj.variableFlashTime+obj.phaseInterval ...
                obj.preTime+obj.stimTime+obj.tailTime-obj.fixFlashTime]);
            obj.phaseIndex=[1 repmat([1,2],1,numel(obj.variableFlashTime)) 1 1 repmat([1,2],1,numel(obj.variableFlashTime)) 1];
        end
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            barWidthIndex = mod(obj.numEpochsCompleted,length(obj.barWidth))+1;
            obj.currentBarWidth=obj.barWidth(barWidthIndex);
            
            % create matrix for adapting and flashing
            obj.adaptMatrix.base=obj.createGrateMat(obj.meanIntensity,0,obj.phases(1),'seesaw');
            obj.adaptMatrix.test=obj.createGrateMat((obj.meanIntensity+obj.adaptStepIntensity)/2,...
                abs(obj.adaptStepIntensity-obj.meanIntensity)/(obj.meanIntensity+obj.adaptStepIntensity),obj.phases(1),'seesaw');
            obj.testMatrix.base=obj.createGrateMat(0,1,obj.phases(1),'seesaw');  % this create the test grating
            obj.testMatrix.test.inphase.step=obj.createGrateMat(((obj.meanIntensity+obj.adaptStepIntensity)*obj.testContrast)/2,obj.testContrast/2, obj.phases(1),'seesaw');  % this create the test grating
            obj.testMatrix.test.offphase.step=obj.createGrateMat(((obj.meanIntensity+obj.adaptStepIntensity)*obj.testContrast)/2,obj.testContrast/2, obj.phases(2),'seesaw');  % this create the test grating
            obj.testMatrix.test.inphase.tail=obj.createGrateMat((obj.meanIntensity*obj.testContrast)/2,obj.testContrast/2, obj.phases(1),'seesaw');  % this create the test grating
            obj.testMatrix.test.offphase.tail=obj.createGrateMat((obj.meanIntensity*obj.testContrast)/2,obj.testContrast/2, obj.phases(2),'seesaw');  % this create the test grating
  
            obj.startMatrix=uint8(obj.adaptMatrix.base+obj.testMatrix.base);
            epoch.addParameter('currentBarWidth', obj.currentBarWidth);
        end
        
        function p=createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            apertureDiameterPix =obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(0); % Set background intensity
            
            obj.startMatrix=uint8(obj.startMatrix);
            scene=stage.builtin.stimuli.Image(obj.startMatrix);
            scene.size = [apertureDiameterPix  apertureDiameterPix]; %scale up to canvas size
            scene.position=canvasSize/2;
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            
            sceneController = stage.builtin.controllers.PropertyController(scene, 'imageMatrix',...
                @(state) getImgMatrix( obj,state.time));
            p.addController(sceneController);
            
            % add aperture
            if obj.apertureDiameter>0
                aperture=stage.builtin.stimuli.Rectangle();
                aperture.position=canvasSize/2;
                aperture.size=[apertureDiameterPix apertureDiameterPix];
                mask=stage.core.Mask.createCircularAperture(1,1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
                aperture.color=0;
            end
            
            
            
            function [imgMat] = getImgMatrix(obj,time)
                if time< (obj.preTime*1e-3) || time>  ((obj.preTime+obj.stimTime)*1e-3)
                    adaptMat=obj.adaptMatrix.base;
                else
                    adaptMat=obj.adaptMatrix.test;
                end
                testMat=obj.testMatrix.base;
                for i=1:length(obj.flashTimes)
                    if time>   obj.flashTimes(i)*1e-3 && time<  (obj.flashTimes(i)+obj.flashDuration)*1e-3
                        if obj.phaseIndex(i)==1
                            if time< obj.stimTime*1e-3
                                testMat=obj.testMatrix.test.inphase.step;
                            else
                                testMat=obj.testMatrix.test.inphase.tail;
                            end
                        elseif obj.phaseIndex(i)==2
                            if time< obj.stimTime*1e-3
                                testMat=obj.testMatrix.test.offphase.step;
                            else
                                testMat=obj.testMatrix.test.offphase.tail;
                            end
                        end
                    end
                end
                imgMat=adaptMat+testMat;
                if max(imgMat(:))>255 || min(imgMat(:))<0
                    disp(['max__' num2str(max(imgMat(:))) '__min__' num2str(min(imgMat(:)))]);
                    error('img matrix intensity out of range');
                end
                imgMat=uint8(imgMat);
            end
        end
        
        function [sinewave2D] = createGrateMat(obj,meanIntensity,contrast,phase,mode)
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            currentBarWidthPix=ceil(obj.rig.getDevice('Stage').um2pix(obj.currentBarWidth));
            x =pi*meshgrid(linspace(-apertureDiameterPix/2,apertureDiameterPix/2,apertureDiameterPix/obj.downSample));
            sinewave2D =sin(x/currentBarWidthPix +phase/180*pi);
            if strcmp(mode,'seesaw')
                sinewave2D(sinewave2D>0)=1;
                sinewave2D(sinewave2D<=0)=-1;
            end
            sinewave2D=(1+sinewave2D*contrast) *meanIntensity*255;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared <obj.numberOfAverages*length(obj.barWidth);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted <obj.numberOfAverages*length(obj.barWidth);
        end
    end
end



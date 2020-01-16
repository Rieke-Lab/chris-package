classdef spatialAdaptF1Probe < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        apertureDiameter=300  %um
        barWidth=[20 40 80 120]  % um
        flashDuration=50  %ms
        fixFlashTime=100  % ms
        variableFlashTime=[50 100 200 400]
        spatialContrast=0.6
        temporalContrast=0.5
        backgroundIntensity=0.05
        stepIntensity=0.2
        preTime=1000
        stimTime=2000
        tailTime=1000
        downSample=1
        imgName='029'
        psth=true
        amp
        numberOfAverage=uint16(3)
        interpulseInterval=0
    end
    
    properties(Hidden)
        ampType
        currentBarWidth
        currentFlashDelay
        currentPattern
        imgIDType=symphonyui.core.PropertyType('char','row',{'img029','img031','img032','img046','img058','img080','img084'});
        imgMatDir='C:\Users\Public\Documents\turner-package\+edu\+washington\+riekelab\+turner\+rescource\subjectTrajectory';
        flashTimes
        patterns={'spot','grating','patch'}
    end
    
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            % create natural image patch for adapting
            imgData=load(fullfile(obj.imgDir, obj.imgName));
            picture=imgData.information.picture;
            patchLocs=floor(imgData.information.patchToAdapt.fixLocs);
            apertureDiameterPix=2*floor(obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter)/2);  % transform to pix
            obj.patchAdapt=picture(patchLocs(1)-apertureDiameterPix/2:obj.downSample:patchLocs(1)+apertureDiameterPix/2-1, ...,
                patchLocs(2)-apertureDiameterPix/2:obj.downSample:patchLocs(2)+apertureDiameterPix/2-1);
            obj.patchAdapt=obj.patchAdapt';
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            %%%%%%%%% need a new online analysis figure later
            obj.showFigure('edu.washington.riekelab.turner.figures.spatialAdaptFigure',...
                obj.rig.getDevice(obj.amp),'groupBy',{'currentPattern'},'barWidth',obj.barWidth,'variableFlashTimes',obj.flashTimes, ...
                'psth',obj.psth,'coloredBy',obj.patterns);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            stimTypeIndex = mod(obj.numEpochsCompleted,3)+1;   % 3 because there are 3 different patterns
            flashIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,3))/3,legnth(obj.variableFlashTime))+1;
            obj.currentFlashDelay=obj.variableFlashTime(flashIndex);
            obj.flashTimes=[obj.fixFlashTime obj.preTime+obj.currentFlashDelay obj.preTime+obj.stimTime-obj.fixFlashTime ...,
                obj.preTime+obj.stimTime+obj.currentFlashDelay  obj.preTime+obj.stimTime+obj.tailTime-obj.fixFlashTime];
            barWidthIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,3*obj.variableFlashTime))/(3*obj.variableFlashTime),length(obj.barWidth))+1;
            obj.currentBarWidth=obj.barWidth(barWidthIndex);
            switch stimTypeIndex
                case 1
                    obj.currentPattern='spot';
                    obj.adaptMatrix.base=createGrateMat(obj.backgroundIntensity,0,0,'seesaw');
                    obj.adaptMatrix.step=createGrateMat(obj.stepIntensity,0,0,'seesaw',obj.downSample);
                case 2
                    obj.currentPattern='grating';
                    obj.adaptMatrix.base=createGrateMat(obj.backgroundIntensity,obj.spatialContrast,0,'seesaw',obj.downSample);
                    obj.adaptMatrix.step=createGrateMat(obj.stepIntensity,obj.spatialContrast,0,'seesaw',obj.downSample);
                case 3
                    obj.currentPattern='patch';
                    obj.adaptMatrix.base=normImg(obj.patchAdapt,obj.backgroundIntensity);
                    obj.adaptMatrix.step=normImg(obj.patchAdapt,obj.stepIntensity);
            end
            obj.testMatrix.base=createGrateMat(obj.backgroundIntensity*obj.temporalContrast,0, obj.apertureDiameter, obj.barWidth,0,'seesaw',obj.downSample);  % this create the test grating
            obj.testMatrix.step=createGrateMat(obj.stepIntensity*obj.temporalContrast,0, obj.apertureDiameter, obj.barWidth,0,'seesaw',obj.downSample);  % this create the test grating
            obj.startMatrix=uint8(obj.adaptMatrix.base);
            
            % there are three experimenatl parameters manipulated. the
            % arrangement change pattern, flashDelay, then bar width, the order
            % can be switched accordingly.
            epoch.addParameter('currentPattern', obj.currentPattern);
            epoch.addPamameter('currentBarWidth', obj.currentBarWidth);
            epoch.addPamameter('currentFlashDelay', obj.currentFlashDelay);
        end
        
        function p=createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            apertureDiameterPix = 2*round(obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter)/2);
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            startMatrix=uint8(obj.adaptMatrix.base);
            scene=stage.builtin.stimuli.Image(startMatrix);
            scene.size = [apertureDiameterPix  apertureDiameterPix]; %scale up to canvas size
            scene.position=canvasSize/2;
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            
            
            sceneController = stage.builtin.controllers.PropertyController(scene, 'imageMatrix',...
                @(state)getImgMatrixProbeWithSpot( state.time));
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
        
        function [img] = normImg(obj,img,meanIntensity)
            img=double(img);
            img=img/max(img(:));
            img=(img-mean(img(:)))/mean(img(:)); % contrast image
            img=img*meanIntensity+ meanIntensity;
            img=img*255;
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
            sinewave2D=(1+sinewave2D*contrast)*meanIntensity*255;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < 3*length(obj.barWidth)*length(obj.variableFlashTime);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < 3*length(obj.barWidth)*length(obj.variableFlashTime);
        end
        
    end
    
    
end


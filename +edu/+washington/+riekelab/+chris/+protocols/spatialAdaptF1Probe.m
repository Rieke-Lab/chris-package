classdef spatialAdaptF1Probe < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        apertureDiameter=300  %um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 600 % um
        barWidth=[20  60]  % um
        flashDuration=50  %ms
        fixFlashTime=100  % ms
        variableFlashTime=[50 150 ]
        spatialContrast=0.8
        temporalContrast=0.5
        backgroundIntensity=0.1
        stepIntensity=0.4
        preTime=600
        stimTime=600
        tailTime=600
        downSample=1
        naturalImageContrastScale=1
        imgName='img031'
        psth=true
        amp
        numberOfAverage=uint16(3)
        interpulseInterval=0
        scaleFactor=2
    end
    
    properties(Hidden)
        ampType
        currentBarWidth
        currentFlashDelay
        currentPattern
        imgNameType=symphonyui.core.PropertyType('char','row',{'img029','img031','img032','img046','img058','img080','img084'});
        imgMatDir='C:\Users\Fred Rieke\Documents\chris-package\+edu\+washington\+riekelab\+chris\+resources\subjectTrajectory';
        flashTimes
        patterns={'spot','grating','patch'}
        testMatrix
        adaptMatrix
        startMatrix
        patchAdapt
        surroundIndex
        patchIndex
        patchInfo
        picture
    end
    
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            % create natural image patch for adapting
            imgData=load(fullfile(obj.imgMatDir, obj.imgName));
            obj.picture=imgData.information.picture;
            obj.patchInfo=imgData.information.patchToAdapt;
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            %%%%%%%%% need a new online analysis figure later
            obj.showFigure('edu.washington.riekelab.chris.figures.spatialAdaptFigure',...
                obj.rig.getDevice(obj.amp),'barWidth',obj.barWidth,'variableFlashTimes',obj.variableFlashTime, ...
                'psth',obj.psth,'coloredBy',obj.patterns);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
      
            stimTypeIndex = mod(obj.numEpochsCompleted,length(obj.patterns))+1;  % 3 because there are 3 different patterns
            flashIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,length(obj.patterns)))/length(obj.patterns), ...,
                length(obj.variableFlashTime))+1;
            obj.currentFlashDelay=obj.variableFlashTime(flashIndex);
            obj.flashTimes=[obj.fixFlashTime obj.preTime+obj.currentFlashDelay obj.preTime+obj.stimTime-obj.fixFlashTime ...,
                obj.preTime+obj.stimTime+obj.currentFlashDelay  obj.preTime+obj.stimTime+obj.tailTime-obj.fixFlashTime];
            barWidthIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,length(obj.patterns)*length(obj.variableFlashTime))) ...,
                /(length(obj.patterns)*length(obj.variableFlashTime)),length(obj.barWidth))+1;
            obj.currentBarWidth=obj.barWidth(barWidthIndex);
            obj.surroundIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,length(obj.barWidth)*length(obj.patterns)*length(obj.variableFlashTime))) ...,
                /(length(obj.barWidth)*length(obj.patterns)*length(obj.variableFlashTime)),2)+1;
            obj.patchIndex=mod((obj.numEpochsCompleted-rem(obj.numEpochsCompleted,2*length(obj.barWidth)*length(obj.patterns)*length(obj.variableFlashTime))) ...,
                /(2*length(obj.barWidth)*length(obj.patterns)*length(obj.variableFlashTime)),7)+1;
            patchLocs=obj.patchInfo(obj.patchIndex).fixLocs;
            % set up the image patch , each picture has 7 patches
            apertureDiameterPix=obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);  % transform to pix     
            obj.patchAdapt=obj.picture(patchLocs(1)-round(apertureDiameterPix/(2*obj.scaleFactor)):patchLocs(1)+round(apertureDiameterPix/(2*obj.scaleFactor)), ...,
                patchLocs(2)-round(apertureDiameterPix/(2*obj.scaleFactor)):patchLocs(2)+round(apertureDiameterPix/(2*obj.scaleFactor)));
            obj.patchAdapt=imresize(obj.patchAdapt, apertureDiameterPix/(size(obj.patchAdapt,1)*obj.downSample),'nearest');
            obj.patchAdapt=obj.patchAdapt';
            
            switch stimTypeIndex
                case 1
                    obj.currentPattern='spot';
                    obj.adaptMatrix.base=obj.createGrateMat(obj.backgroundIntensity,0,0,'seesaw');
                    obj.adaptMatrix.step=obj.createGrateMat(obj.stepIntensity,0,0,'seesaw');
                case 2
                    obj.currentPattern='grating';
                    obj.adaptMatrix.base=obj.createGrateMat(obj.backgroundIntensity,obj.spatialContrast,0,'seesaw');
                    obj.adaptMatrix.step=obj.createGrateMat(obj.stepIntensity,obj.spatialContrast,0,'seesaw');
                case 3
                    obj.currentPattern='patch';
                    obj.adaptMatrix.base=obj.normImg(obj.patchAdapt,obj.backgroundIntensity);
                    obj.adaptMatrix.step=obj.normImg(obj.patchAdapt,obj.stepIntensity);
            end
            obj.testMatrix.base=obj.createGrateMat(obj.backgroundIntensity*obj.temporalContrast,0,0,'seesaw');  % this create the test grating
            obj.testMatrix.step=obj.createGrateMat(obj.stepIntensity*obj.temporalContrast,0,0,'seesaw');  % this create the test grating
         
            obj.startMatrix=obj.adaptMatrix.base;
            % there are three experimenatl parameters manipulated. the
            % arrangement change pattern, flashDelay, then bar width, the order
            % can be switched accordingly.
            epoch.addParameter('currentPattern', obj.currentPattern);
            epoch.addParameter('currentBarWidth', obj.currentBarWidth);
            epoch.addParameter('currentFlashDelay', obj.currentFlashDelay);
            epoch.addParameter('surroundIndex', obj.surroundIndex);            
            epoch.addParameter('patchIndex', obj.patchIndex);
            
        end
        
        function p=createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            apertureDiameterPix =obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            annulusInnerDiameterPix =obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix =obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % add surround 
               % add the surround ring step
               if obj.surroundIndex==2
                   surroundSpot = stage.builtin.stimuli.Ellipse();
                   surroundSpot.radiusX = annulusOuterDiameterPix/2;
                   surroundSpot.radiusY = annulusOuterDiameterPix/2;
                   surroundSpot.position = canvasSize/2;
                   p.addStimulus(surroundSpot);
                   surroundSpotIntensity = stage.builtin.controllers.PropertyController(surroundSpot, 'color',...
                       @(state) obj.getSurroundIntensity(state.time));
                   p.addController(surroundSpotIntensity);
                   % hide during pre & post
                   surroundSpotVisible = stage.builtin.controllers.PropertyController(surroundSpot, 'visible', ...
                       @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                   p.addController(surroundSpotVisible);
                   %mask / annulus...
                   maskSpot = stage.builtin.stimuli.Ellipse();
                   maskSpot.radiusX = annulusInnerDiameterPix/2;
                   maskSpot.radiusY = annulusInnerDiameterPix/2;
                   maskSpot.position = canvasSize/2;
                   maskSpot.color = obj.backgroundIntensity;
                   p.addStimulus(maskSpot);
                   
               end
            scene=stage.builtin.stimuli.Image(uint8(obj.startMatrix));
            scene.size = [apertureDiameterPix  apertureDiameterPix]; %scale up to canvas size
            scene.position=canvasSize/2;
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            
            sceneController = stage.builtin.controllers.PropertyController(scene, 'imageMatrix',...
                @(state) obj.getImgMatrix( state.time));
            p.addController(sceneController);
            % add aperture
            if obj.apertureDiameter>0
                aperture=stage.builtin.stimuli.Rectangle();
                aperture.position=canvasSize/2;
                aperture.size=[apertureDiameterPix apertureDiameterPix];
                mask=stage.core.Mask.createCircularAperture(1,1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
                aperture.color=obj.backgroundIntensity;
            end
            
        end
 
        
        function [imgMat] = getImgMatrix(obj,time)
            if time<obj.preTime*1e-3 || time>(obj.preTime+obj.stimTime)*1e-3
                adaptMat=obj.adaptMatrix.base;
            else
                adaptMat=obj.adaptMatrix.step;
            end
            testMat=obj.testMatrix.base;
            for i=1:length(obj.flashTimes)
                if time>obj.flashTimes(i)*1e-3 && time< (obj.flashTimes(i)+obj.flashDuration)*1e-3
                    testMat=obj.testMatrix.step;
                end
            end
            imgMat=adaptMat+testMat;
            imgMat(imgMat>255)=255; imgMat(imgMat<0)=0;
            if max(imgMat(:))>255 || min(imgMat(:))<0
                disp(['max__' num2str(max(imgMat(:))) '__min__' num2str(min(imgMat(:)))]);
                error('img matrix intensity out of range');
            end
            imgMat=uint8(imgMat);
        end
        
        function [img] = normImg(obj,img,meanIntensity)
            img=double(img);
            img=img/max(img(:));
            img=obj.naturalImageContrastScale*(img-mean(img(:)))/mean(img(:)); % contrast image
            img=img*meanIntensity+ meanIntensity;
            img=img*255;
            
        end
        
        function [intensity]= getSurroundIntensity(obj,time)
            if time<obj.preTime*1e-3 || time>(obj.preTime+obj.stimTime)*1e-3
                intensity=obj.backgroundIntensity;
            else
                intensity=obj.stepIntensity;
            end
        end
        
        
        
        function [sinewave2D] = createGrateMat(obj,meanIntensity,contrast,phase,mode)
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            currentBarWidthPix=ceil(obj.rig.getDevice('Stage').um2pix(obj.currentBarWidth));
            x =pi*meshgrid(linspace(-apertureDiameterPix/2,apertureDiameterPix/2,size(obj.patchAdapt,1)));
            sinewave2D =sin(x/currentBarWidthPix +phase/180*pi);
            if strcmp(mode,'seesaw')
                sinewave2D=sign(sinewave2D);
            end
            sinewave2D=(1+sinewave2D*contrast) *meanIntensity*255;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < 7*2*obj.numberOfAverage*length(obj.patterns)*length(obj.barWidth)*length(obj.variableFlashTime);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted <7*2*obj.numberOfAverage*length(obj.patterns)*length(obj.barWidth)*length(obj.variableFlashTime);
        end
        
    end
    
    
end


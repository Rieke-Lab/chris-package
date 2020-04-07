classdef spatialAdaptNaturalImage < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        baseTime=100
        preTime=1000  % ms
        stimTime=1000
        tailTime=1000
         imgID='img029' % van hateren image ID
        meanIntensity=0.5
        apertureDiameter=200 %um
        whiteningDuration=100  % ms
        firstFlashTime=500; % ms
        flashDuration=100;
        numberOfReps=uint16(5)
        psth=false
        amp
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        imgIDType=symphonyui.core.PropertyType('char','row',{'img029','img031','img032','img046','img058','img080','img084'});
        picture
        patchAdapt
        patchTest
        currentSpatialCorr
        currentPatchID
        patchesToTestInfo
        patchAdaptLocs
        patchOrder
        flashTimes
        imgMatDir='C:\Users\Fred Rieke\Documents\chris-package\+edu\+washington\+riekelab\+chris\+resources\subjectTrajectory';
        interpulseInterval = 0          % Duration between pulses (s)
        currentPatchRotation
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            % load the img patch
            imgData=load(fullfile(obj.imgMatDir, obj.imgID));
            obj.picture=imgData.information.picture;
            obj.patchAdaptLocs=round(imgData.information.patchToAdapt.fixLocs);
            obj.patchesToTestInfo=imgData.information.patchToTest; % struct array for testing patch
            obj.patchOrder=1:numel(imgData.information.patchToTest);
            obj.patchOrder=obj.patchOrder(randperm(numel(imgData.information.patchToTest)));
            obj.flashTimes=[obj.firstFlashTime  obj.preTime+obj.stimTime+obj.whiteningDuration]; % s
            
            if length(obj.patchOrder) > 1
                colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.patchOrder)+2,'CubicYF');
            else
                colors = [0 0 0];
            end
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.spatialCorrAdaptFigure',...
                obj.rig.getDevice(obj.amp),'psth',obj.psth,'baseTime',obj.baseTime, ...,
                'flashDuration',obj.flashDuration,'flashTimes',obj.flashTimes); % base time is the selected regions to compute
        
            
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            % 6.6 tranlsate the um to VH pixels
            obj.patchAdapt=obj.picture(obj.patchAdaptLocs(1)-round(apertureDiameterPix/(2)): obj.patchAdaptLocs(1)+round(apertureDiameterPix/(2)), ...,
                obj.patchAdaptLocs(2)-round(apertureDiameterPix/(2)): obj.patchAdaptLocs(2)+round(apertureDiameterPix/(2)));
            obj.patchAdapt=obj.normImg(obj.patchAdapt);
            
            index = mod(obj.numEpochsCompleted, numel(obj.patchOrder))+1;
            
            patchTestLocs=floor(obj.patchesToTestInfo(obj.patchOrder(index)).fixLocs);
            obj.patchTest=obj.picture(patchTestLocs(1)-round(apertureDiameterPix/(2)):patchTestLocs(1)+round(apertureDiameterPix/(2)), ...,
                patchTestLocs(2)-round(apertureDiameterPix/(2)):patchTestLocs(2)+round(apertureDiameterPix/(2)));
            obj.patchTest=obj.normImg(obj.patchTest);
            testPatchAngle= obj.patchesToTestInfo(obj.patchOrder(index)).angles;
            obj.patchTest=imrotate(obj.patchTest, testPatchAngle);
    
            epoch.addParameter('currentSpatialCorr', corr2(obj.patchAdapt, obj.patchTest));
        end
        
        function p=createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            apertureDiameterPix=2*round(apertureDiameterPix/2);
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.meanIntensity); % Set background intensity
            
            % create gray background spot
            spot=stage.builtin.stimuli.Ellipse();
            spot.radiusX=apertureDiameterPix/2;
            spot.radiusY=apertureDiameterPix/2;
            spot.position=canvasSize/2;
            spot.color=obj.meanIntensity;
            p.addStimulus(spot);
            spotVisible=stage.builtin.controllers.PropertyController(spot,'visible', @(state) ...,
                state.time>0 && state.time< (obj.preTime+obj.stimTime+obj.tailTime)/1e3);
            p.addController(spotVisible);
            
            
            % create scene of the img patch
            
            scene=stage.builtin.stimuli.Image(obj.patchTest);  % initiate the scene, this would be invisible though given the opacity control
            scene.size=[apertureDiameterPix apertureDiameterPix];
            scene.position=canvasSize/2;
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            scenePattern=stage.builtin.controllers.PropertyController(scene,'imageMatrix', @(state) ...,
                obj.getImgPattern(state.time));
            p.addController(scenePattern);
            adaptSceneOpa=stage.builtin.controllers.PropertyController(scene,'opacity', @(state) ...,
                obj.getPatchOpacity(state.time));
            p.addController(adaptSceneOpa);
            
       
            % apply the aperture
            if apertureDiameterPix>0
                aperture=stage.builtin.stimuli.Rectangle();
                aperture.position=canvasSize/2;
                aperture.color=obj.meanIntensity;
                aperture.size=[max(canvasSize) max(canvasSize)];
                mask=stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize));
                aperture.setMask(mask);
                p.addStimulus(aperture);
                
            end
            
        end
        
        function [opa] = getPatchOpacity(obj,time)
            opa=0;
            for i=1:numel(obj.flashTimes)
                if time>obj.flashTimes(i)/1e3 && time< (obj.flashTimes(i)+obj.flashDuration)/1e3
                    opa=1;
                end
            end
            
            if   time>obj.preTime/1e3 &&time< (obj.preTime+obj.stimTime)/1e3
                opa=1;
            end
            
        end
        
        
        function [img]=getImgPattern(obj, time)
            if time> obj.preTime/1e3 && time<(obj.preTime+obj.stimTime)/1e3
                img=obj.patchAdapt;
            else
                img=obj.patchTest;
            end
            
        end
        
        function [img] = normImg(obj,img)
            img=double(img);
            img=img/max(img(:));
            img=(img-mean(img(:)))/mean(img(:)); % contrast image
            img=img*obj.meanIntensity+obj.meanIntensity;
            img=img*255;
            img=uint8(img);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfReps*numel(obj.patchOrder);
            
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfReps*numel(obj.patchOrder);
        end
    end
end


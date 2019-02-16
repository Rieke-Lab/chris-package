classdef NatImageSaccade < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        preTime = 200 % ms
        stimTime = 420 % ms
        tailTime = 200 % ms
        saccadeTime = 20 % ms, subset of stim time
        
        imageName = '00152' %van hateren image names
        saccadeTrajectory = 'full' 
        seed = 1 % rand seed for trajectory start/end points
        apertureDiameter = 0 % um
        maskDiameter = 0 % um
        scalingFactor = 2 % arcmin/pixel of VH image
        
        onlineAnalysis = 'none'
        numberOfAverages = uint16(20) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        imageNameType = symphonyui.core.PropertyType('char', 'row', {'00152','00377','00405','00459','00657','01151','01154',...
            '01192','01769','01829','02265','02281','02733','02999','03093',...
            '03347','03447','03584','03758','03760'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        saccadeTrajectoryType = symphonyui.core.PropertyType('char', 'row', {'full','jump'})
        backgroundIntensity
        imageMatrix
        xTraj
        yTraj
        xFixations
        yFixations
        currentStimSet
        saccadeDistance
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            %load appropriate image...
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            obj.currentStimSet = '/VHsubsample_20160105';
            fileId=fopen([resourcesDir, obj.currentStimSet, '/imk', obj.imageName,'.iml'],'rb','ieee-be');
            img = fread(fileId, [1536,1024], 'uint16');
           
            img = double(img');
            img = (img./max(img(:))); %rescale s.t. brightest point is maximum monitor level
            obj.backgroundIntensity = mean(img(:));%set the mean to the mean over the image
            img = img.*255; %rescale s.t. brightest point is maximum monitor level
            obj.imageMatrix = uint8(img);
            
            %size of the stimulus on the prep:
            stimSize = obj.rig.getDevice('Stage').getCanvasSize() .* obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'); %um
            %scalingFactor: 3.3 for 1 arcmin/VH pixel (like DOVES), based
            %on 198 um/degree on monkey retina
            
            %size of the stimulus, in original image pixels:
            stimSize_VHpix = stimSize ./ (obj.scalingFactor .* 3.3); %um / (um/pixel) -> pixel
            radX = stimSize_VHpix(1) / 2; %boundaries for fixation draws depend on stimulus size
            radY = stimSize_VHpix(2) / 2;
            rng(obj.seed); %set random seed for fixation draw
            obj.xFixations = randsample((radX + 1):(1536 - radX),2); %[start end], in VH pixels
            obj.yFixations = randsample((radY + 1):(1024 - radY),2);

            distance = sqrt((obj.xFixations(2)-obj.xFixations(1))^2 + (obj.yFixations(2)-obj.yFixations(1))^2);
            obj.saccadeDistance = distance; %degrees
%             display(num2str(distance/60)) %degrees
%             display(num2str((distance/60)/(obj.saccadeTime./1e3))) %degrees/second
            
            %make the trajectory from start to finish
            saccadePoints = (obj.saccadeTime / 1e3) * obj.sampleRate; %msec -> datapts
            fixPoints = ((obj.stimTime - obj.saccadeTime) / 1e3) * obj.sampleRate;
            if strcmp(obj.saccadeTrajectory,'full')
                obj.xTraj = [obj.xFixations(1) .* ones(1,round(fixPoints/2)),...
                    linspace(obj.xFixations(1),obj.xFixations(2),saccadePoints),...
                    obj.xFixations(2) .* ones(1,round(fixPoints/2))];
                obj.yTraj = [obj.yFixations(1) .* ones(1,round(fixPoints/2)),...
                    linspace(obj.yFixations(1),obj.yFixations(2),saccadePoints),...
                    obj.yFixations(2) .* ones(1,round(fixPoints/2))];
            elseif strcmp(obj.saccadeTrajectory,'jump') %cut halfway through the saccade
                obj.xTraj = [obj.xFixations(1) .* ones(1,round(fixPoints/2)),...
                    obj.xFixations(1) .* ones(1,round(saccadePoints/2)),...
                    obj.xFixations(2) .* ones(1,round(saccadePoints/2)),...
                    obj.xFixations(2) .* ones(1,round(fixPoints/2))];
                obj.yTraj = [obj.yFixations(1) .* ones(1,round(fixPoints/2)),...
                    obj.yFixations(1) .* ones(1,round(saccadePoints/2)),...
                    obj.yFixations(2) .* ones(1,round(saccadePoints/2)),...
                    obj.yFixations(2) .* ones(1,round(fixPoints/2))];
            end

            %need to make eye trajectories for PRESENTATION relative to the center of the image and
            %flip them across the x axis: to shift scene right, move
            %position left, same for y axis
            obj.xTraj = -(obj.xTraj - 1536/2); %units=VH pixels
            obj.yTraj = -(obj.yTraj - 1024/2);
            %also scale them to canvas pixels
            %canvasPix = (VHpix) * (um/VHpix)/(um/canvasPix)
            obj.xTraj = obj.xTraj .* (obj.scalingFactor .* 3.3)/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');
            obj.yTraj = obj.yTraj .* (obj.scalingFactor .* 3.3)/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            maskDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.maskDiameter);
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            scene = stage.builtin.stimuli.Image(obj.imageMatrix);
            %scale up image for canvas. Now image pixels and canvas pixels
            %are the same size. Also image size is in rows (y), cols (x)
            %but stage sizes are in x, y
            
            %canvasPix = (VHpix) * (um/VHpix)/(um/canvasPix)
            scene.size = [size(obj.imageMatrix,2) * (obj.scalingFactor .* 3.3)/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'),...
                size(obj.imageMatrix,1) * (obj.scalingFactor .* 3.3)/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel')];
            p0 = canvasSize/2;
            scene.position = p0;
            
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);

%             figure(30); hold on; plot(obj.xTraj,'r-'); hold on; plot(obj.yTraj,'r-')
            %apply eye trajectories to move image around
            scenePosition = stage.builtin.controllers.PropertyController(scene,...
                'position', @(state)getScenePosition(obj, state.time - obj.preTime/1e3, p0));
            
            function p = getScenePosition(obj, time, p0)
                time_dataPoints = time * obj.sampleRate;
                if time_dataPoints < 0
                    p = p0;
                elseif time_dataPoints > length(obj.xTraj) %out of eye trajectory, hang on last frame
                    p(1) = p0(1) + obj.xTraj(end);
                    p(2) = p0(2) + obj.yTraj(end);
                else %within eye trajectory and stim time
                    dx = interp1(1:length(obj.xTraj),obj.xTraj,time_dataPoints);
                    dy = interp1(1:length(obj.xTraj),obj.yTraj,time_dataPoints);
                    p(1) = p0(1) + dx;
                    p(2) = p0(2) + dy;
                end
            end                 
            p.addStimulus(scene);
            p.addController(scenePosition);

            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);
            
            if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [apertureDiameterPix, apertureDiameterPix];
                mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
            if (obj.maskDiameter > 0) % Create mask
                mask = stage.builtin.stimuli.Ellipse();
                mask.position = canvasSize/2;
                mask.color = obj.backgroundIntensity;
                mask.radiusX = maskDiameterPix/2;
                mask.radiusY = maskDiameterPix/2;
                p.addStimulus(mask); %add mask
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('saccadeDistance', obj.saccadeDistance);
            epoch.addParameter('xFixations', obj.xFixations);
            epoch.addParameter('yFixations', obj.yFixations);
        end
        
        %same presentation each epoch in a run. Replay.
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            if (obj.numEpochsCompleted >= 1) && (obj.numEpochsCompleted < obj.numberOfAverages)
                obj.rig.getDevice('Stage').replay
            else
                obj.rig.getDevice('Stage').play(obj.createPresentation());
            end
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end

    end
    
end
classdef DOVEScsAdditivity < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        preTime = 250 % ms
        stimTime = 5500 % ms
        tailTime = 250 % ms
        stimulusIndex = 1 % DOVES stim, 1-74, nearby from same image
        
        centerDiameter = 200 % um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 700 % um
        
        onlineAnalysis = 'none'
        numberOfAverages = uint16(15) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        backgroundIntensity
        imageMatrix
        xTraj
        yTraj
        timeTraj
        currentStimSet
        currentStimulus
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            colors = edu.washington.riekelab.turner.utils.pmkmp(3,'CubicYF');
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentStimulus'},'sweepColor',colors);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            %load eye movement stimulus data
            %Change to resources directory
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            obj.currentStimSet = 'dovesFEMstims_20160422.mat';
            load([resourcesDir, obj.currentStimSet]);
            imageName = FEMdata(obj.stimulusIndex).ImageName;
            
            %load indicated image...
            fileId=fopen([resourcesDir, 'NaturalImages\', imageName],'rb','ieee-be');
            img = fread(fileId, [1536,1024], 'uint16');
           
            img = double(img');
            img = (img./max(img(:))); %rescale s.t. brightest point is maximum monitor level
            obj.backgroundIntensity = mean(img(:));%set the mean to the mean over the image
            img = img.*255; %rescale s.t. brightest point is maximum monitor level
            obj.imageMatrix = uint8(img);
            
            %get appropriate eye trajectories, at 200Hz
            obj.xTraj = FEMdata(obj.stimulusIndex).eyeX;
            obj.yTraj = FEMdata(obj.stimulusIndex).eyeY;

            obj.timeTraj = (0:(length(obj.xTraj)-1)) ./ 200; %sec
           
            %need to make eye trajectories for PRESENTATION relative to the center of the image and
            %flip them across the x axis: to shift scene right, move
            %position left, same for y axis - but y axis definition is
            %flipped for DOVES data (uses MATLAB image convention) and
            %stage (uses positive Y UP/negative Y DOWN), so flips cancel in
            %Y direction
            obj.xTraj = -(obj.xTraj - 1536/2); %units=VH pixels
            obj.yTraj = (obj.yTraj - 1024/2);
            
            %also scale them to canvas pixels. 1 VH pixel = 1 arcmin = 3.3
            %um on monkey retina
            %canvasPix = (VHpix) * (um/VHpix)/(um/canvasPix)
            obj.xTraj = obj.xTraj .* 3.3/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');
            obj.yTraj = obj.yTraj .* 3.3/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');

            %now eye trajectories ready for presentation by stage
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            stimInd = mod(obj.numEpochsCompleted,3);
            if stimInd == 0
                obj.currentStimulus = 'Center';
            elseif stimInd == 1
                obj.currentStimulus = 'Surround';
            elseif stimInd == 2
                obj.currentStimulus = 'Center-Surround';
            end
            
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('currentStimSet', obj.currentStimSet);
            epoch.addParameter('currentStimulus', obj.currentStimulus);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            centerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.centerDiameter);
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            scene = stage.builtin.stimuli.Image(obj.imageMatrix);
            %scale up image for canvas. Now image pixels and canvas pixels
            %are the same size. Also image size is in rows (y), cols (x)
            %but stage sizes are in x, y
            
            %canvasPix = (VHpix) * (um/VHpix)/(um/canvasPix)
            scene.size = [size(obj.imageMatrix,2) * 3.3/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'),...
                size(obj.imageMatrix,1) * 3.3/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel')];
            p0 = canvasSize/2;
            scene.position = p0;
            
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            
            %apply eye trajectories to move image around
            scenePosition = stage.builtin.controllers.PropertyController(scene,...
                'position', @(state)getScenePosition(obj, state.time - obj.preTime/1e3, p0));
            
            function p = getScenePosition(obj, time, p0)
                if time < 0
                    p = p0;
                elseif time > obj.timeTraj(end) %out of eye trajectory, hang on last frame
                    p(1) = p0(1) + obj.xTraj(end);
                    p(2) = p0(2) + obj.yTraj(end);
                else %within eye trajectory and stim time
                    dx = interp1(obj.timeTraj,obj.xTraj,time);
                    dy = interp1(obj.timeTraj,obj.yTraj,time);
                    p(1) = p0(1) + dx;
                    p(2) = p0(2) + dy;
                end
            end            
            
            p.addStimulus(scene);
            p.addController(scenePosition);

            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);
            
            % occlude with appropriate aperture / mask / annulus
            if strcmp(obj.currentStimulus,'Center') %aperture around center
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                tempSz = 1.5*max(canvasSize);
                aperture.size = [tempSz tempSz];
                mask = stage.core.Mask.createCircularAperture(centerDiameterPix/tempSz, 1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
            elseif strcmp(obj.currentStimulus,'Surround') %aperture in far surround + mask in center
                % big aperture:
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                tempSz = 1.5*max(canvasSize);
                aperture.size = [tempSz tempSz];
                mask = stage.core.Mask.createCircularAperture(annulusOuterDiameterPix/tempSz, 1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
                % center mask:
                maskSpot = stage.builtin.stimuli.Ellipse();
                maskSpot.radiusX = annulusInnerDiameterPix/2;
                maskSpot.radiusY = annulusInnerDiameterPix/2;
                maskSpot.position = canvasSize/2;
                maskSpot.color = obj.backgroundIntensity;
                p.addStimulus(maskSpot);
            elseif strcmp(obj.currentStimulus,'Center-Surround') %annulus between center & surround
                % big aperture:
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                tempSz = 1.5*max(canvasSize);
                aperture.size = [tempSz tempSz];
                mask = stage.core.Mask.createCircularAperture(annulusOuterDiameterPix/tempSz, 1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
                
                %annulus between center & surround:
                annulus = stage.builtin.stimuli.Rectangle();
                annulus.position = canvasSize/2;
                annulus.color = obj.backgroundIntensity;
                annulus.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createAnnulus(centerDiameterPix/max(canvasSize),...
                    annulusInnerDiameterPix/max(canvasSize),1024);
                annulus.setMask(mask);
                p.addStimulus(annulus);
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
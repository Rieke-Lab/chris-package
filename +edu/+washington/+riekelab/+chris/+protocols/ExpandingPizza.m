classdef ExpandingPizza< edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        preTime = 200 % ms
        stimTime = 400 % ms
        tailTime = 400 % ms
        apertureDiameter = 200 % um
        backgroundIntensity = 0.3; %0-1
        meanIntensity=0.3;
        contrast=0.9
        slices=[2 4 8 16 32];
        onlineAnalysis = 'extracellular'
        amp % Output amplifier
        numberOfAverages = uint16(100) % number of epochs to queue
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        %saved out to each epoch...
        currentImageMatrix
        canvasSize
        currentSliceNumber
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            % pre-generate the imageMatrix
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            % to do, add expanding skewness figure; similar to expanding
            % spots figures
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));

            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.chris.figures.ExpandingPizzaFigure',...
                    obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                    'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            pizzaInd=mod(obj.numEpochsCompleted, numel(obj.slices))+1;
            obj.currentSliceNumber=obj.slices(pizzaInd);
            currentIntensitySequence= repmat(obj.contrast*[1 -1],1, obj.currentSliceNumber/2)*obj.meanIntensity+obj.meanIntensity;
            obj.currentImageMatrix =edu.washington.riekelab.chris.utils.makeSplitPizzas(max(obj.canvasSize),obj.currentSliceNumber,0,currentIntensitySequence);
            obj.currentImageMatrix = obj.currentImageMatrix.*255; %rescale s.t. brightest point is maximum monitor level
            obj.currentImageMatrix = uint8(obj.currentImageMatrix);
            epoch.addParameter('currentSliceNumber', obj.currentSliceNumber);

        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            scene = stage.builtin.stimuli.Image(obj.currentImageMatrix);
            scene.size = obj.canvasSize; %scale up to canvas size
            scene.position = obj.canvasSize/2;
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);

            if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = obj.canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(obj.canvasSize) max(obj.canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(obj.canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
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
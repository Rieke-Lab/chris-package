classdef ExpandingSpots < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 250 % ms
        stimTime = 500 % ms
        tailTime = 250 % ms
        spotIntensity = 0.3 % (0-1)
        spotSizes = [40 80 120 160 180 200 220  280 360 460 600 720 800] % um
        randomizeOrder = false
        backgroundIntensity = 0.1 % (0-1)
        onlineAnalysis = 'extracellular'
        numberOfAverages = uint16(2) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})        
        spotSizeSequence
        currentSpotSize
    end
    
    properties (Hidden, Transient)
        
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            if length(obj.spotSizes) > 1
                colors = edu.washington.riekelab.chris.utils.pmkmp(length(obj.spotSizes),'CubicYF');
            else
                colors = [0 0 0];
            end
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.chris.figures.AreaSummationFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
            if strcmp(obj.onlineAnalysis,'extracellular')
                psth=true;
            else
                psth=false;
             
            end
            obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'psth', psth,...
                'groupBy',{'currentSpotSize'},...
                'sweepColor',colors);
            % Create spot size sequence.
            obj.spotSizeSequence = obj.spotSizes;
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            spotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.currentSpotSize);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create spot stimulus.            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = obj.spotIntensity;
            spot.radiusX = spotDiameterPix/2;
            spot.radiusY = spotDiameterPix/2;
            spot.position = canvasSize/2;
            p.addStimulus(spot);
            
            % hide during pre & post
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);

        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            index = mod(obj.numEpochsCompleted, length(obj.spotSizeSequence)) + 1;
            % Randomize the spot size sequence order at the beginning of each sequence.
            if index == 1 && obj.randomizeOrder
                obj.spotSizeSequence = randsample(obj.spotSizeSequence, length(obj.spotSizeSequence));
            end
            obj.currentSpotSize = obj.spotSizeSequence(index);
            epoch.addParameter('currentSpotSize', obj.currentSpotSize);
        end


        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.spotSizes);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.spotSizes);
        end
        
    end
    
end
classdef VariableMeanSpatialNoise < manookinlab.protocols.ManookinLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 250                   % Pre-stimulus time (ms)
        stimTime = 30000                % Total stimulus duration (ms)
        tailTime = 250                  % Post-stimulus time (ms)
        meanSwitchInterval = 3000       % Time between mean switches (ms)
        meanIntensities = [0.03 0.3]    % Array of mean intensities to cycle through
        contrast = 1                    % Contrast of noise
        stixelSizes = [90,90]           % Edge length of stixel (microns)
        gridSize = 30                   % Size of underlying grid
        filterSdStixels = 1.0           % Gaussian filter standard dev in stixels
        frameDwells = uint16([1,1])     % Frame dwell
        onlineAnalysis = 'none'
        numberOfAverages = uint16(10)  % Number of epochs
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        stixelSizesType = symphonyui.core.PropertyType('denserealdouble','matrix')
        frameDwellsType = symphonyui.core.PropertyType('denserealdouble','matrix')
        meanIntensitiesType = symphonyui.core.PropertyType('denserealdouble','matrix')
        stixelSize
        stepsPerStixel
        numXStixels
        numYStixels
        numXChecks
        numYChecks
        seed
        stixelSizePix
        stixelShiftPix
        noiseStream
        positionStream
        monitor_gamma
        frameDwell
        time_multiple
        frameRate = 60
        
        % Variable mean specific properties
        totalFrames
        preFrames
        stimFrames
        tailFrames
        framesPerSwitch
        numSwitches
        meanSequence        % Mean intensity for each frame
        intensityTrace      % Pre-computed intensity trace for all frames
        positionTrace       % Pre-computed position values for all frames
    end

    methods
        function didSetRig(obj)
            didSetRig@manookinlab.protocols.ManookinLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            
            obj.totalFrames = ceil(obj.stimTime * 1e-3 * obj.frameRate);
            obj.framesPerSwitch = round(obj.meanSwitchInterval * 1e-3 * obj.frameRate);
            obj.numSwitches = ceil(obj.totalFrames / obj.framesPerSwitch);
            
            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                obj.frameDwells = uint16(ones(size(obj.frameDwells)));
            end
            
            try
                obj.time_multiple = obj.rig.getDevice('Stage').getExpectedRefreshRate() / obj.rig.getDevice('Stage').getMonitorRefreshRate();
            catch
                obj.time_multiple = 1.0;
            end
            
            if ~obj.isMeaRig
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            end
            
    
        end
        
        
        function precomputeTraces(obj)
            % Pre-compute the mean intensity sequence
            obj.meanSequence = zeros(1, obj.totalFrames);
            meanIndices = repmat(1:length(obj.meanIntensities), 1, ceil(obj.numSwitches/length(obj.meanIntensities)));
            
            for switchIdx = 1:obj.numSwitches
                startFrame = (switchIdx-1) * obj.framesPerSwitch + 1;
                endFrame = min(switchIdx * obj.framesPerSwitch, obj.totalFrames);
                obj.meanSequence(startFrame:endFrame) = obj.meanIntensities(meanIndices(switchIdx));
            end
            
            % Pre-compute the complete intensity trace with frame dwell
            obj.intensityTrace = zeros(obj.numYStixels, obj.numXStixels, obj.totalFrames, 'uint8');
            
            currentNoisePattern = [];
            for frame = 1:obj.totalFrames
                % Generate new noise pattern according to frame dwell
                if mod(frame-1, obj.frameDwell) == 0 || isempty(currentNoisePattern)
                    currentNoisePattern = 2*(obj.noiseStream.rand(obj.numYStixels, obj.numXStixels) > 0.5) - 1;
                end
                
                % Apply contrast and mean
                meanIntensity = obj.meanSequence(frame);
                M = obj.contrast * currentNoisePattern * meanIntensity + meanIntensity;
                
                % Convert to uint8
                obj.intensityTrace(:,:,frame) = uint8(255 * M);
            end
            
            % Pre-compute positions if using jitter
            if obj.stepsPerStixel > 1
                obj.positionTrace = zeros(2, obj.totalFrames);
                currentPosition = [];
                for frame = 1:obj.totalFrames
                    if mod(frame-1, obj.frameDwell) == 0 || isempty(currentPosition)
                        currentPosition = obj.stixelShiftPix * round((obj.stepsPerStixel-1) * obj.positionStream.rand(1,2));
                    end
                    obj.positionTrace(:,frame) = currentPosition;
                end
            end
            
            disp(['Pre-computed ' num2str(obj.totalFrames) ' frames with frame dwell of ' num2str(obj.frameDwell)]);
        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3 * obj.time_multiple);
            
            % Set initial background to first mean intensity
            p.setBackgroundColor(obj.meanIntensities(1));

            % Create initial image matrix
            imageMatrix = obj.meanIntensities(1) * ones(obj.numYStixels, obj.numXStixels);
            checkerboard = stage.builtin.stimuli.Image(uint8(imageMatrix * 255));
            checkerboard.position = obj.canvasSize / 2;
            checkerboard.size = [obj.numXStixels, obj.numYStixels] * obj.stixelSizePix;

            % Set the minifying and magnifying functions to form discrete stixels
            checkerboard.setMinFunction(GL.NEAREST);
            checkerboard.setMagFunction(GL.NEAREST);

            % Add the stimulus to the presentation
            p.addStimulus(checkerboard);
            
            % Visibility controller
            gridVisible = stage.builtin.controllers.PropertyController(checkerboard, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3 * 1.011);
            p.addController(gridVisible);
            
            % Calculate preFrames
            preF = floor(obj.preTime/1000 * obj.frameRate);
            
            % Image matrix controller based on stage type
            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state)getFrameIntensityPatternMode(obj, state.time - obj.preTime*1e-3));
            else
                imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state)getFrameIntensity(obj, state.frame - preF));
            end
            p.addController(imgController);
            
            % Position controller for jitter
            if obj.stepsPerStixel > 1
                if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter')) % Pattern mode
                    xyController = stage.builtin.controllers.PropertyController(checkerboard, 'position',...
                        @(state)getPositionPatternMode(obj, state.time - obj.preTime*1e-3));
                else
                    xyController = stage.builtin.controllers.PropertyController(checkerboard, 'position',...
                        @(state)getFramePosition(obj, state.frame - preF));
                end
                p.addController(xyController);
            end
            
            % Background color controller to match current mean
            bgController = stage.builtin.controllers.PropertyController(p, 'backgroundColor',...
                @(state)getBackgroundColor(obj, state.frame - preF));
            p.addController(bgController);
            
            function s = getFrameIntensity(obj, frame)
                if frame > 0 && frame <= obj.totalFrames
                    s = obj.intensityTrace(:,:,frame);
                else
                    s = uint8(obj.meanIntensities(1) * 255 * ones(obj.numYStixels, obj.numXStixels));
                end
            end
            
            function s = getFrameIntensityPatternMode(obj, time)
                if time > 0
                    frame = min(ceil(time * obj.frameRate), obj.totalFrames);
                    s = obj.intensityTrace(:,:,frame);
                else
                    s = uint8(obj.meanIntensities(1) * 255 * ones(obj.numYStixels, obj.numXStixels));
                end
            end
            
            function p = getFramePosition(obj, frame)
                if frame > 0 && frame <= obj.totalFrames && obj.stepsPerStixel > 1
                    p = obj.positionTrace(:,frame) + obj.canvasSize / 2;
                else
                    p = obj.canvasSize / 2;
                end
            end
            
            function p = getPositionPatternMode(obj, time)
                if time > 0 && obj.stepsPerStixel > 1
                    frame = min(ceil(time * obj.frameRate), obj.totalFrames);
                    p = obj.positionTrace(:,frame) + obj.canvasSize / 2;
                else
                    p = obj.canvasSize / 2;
                end
            end
            
            function c = getBackgroundColor(obj, frame)
                if frame > 0 && frame <= obj.totalFrames
                    c = obj.meanSequence(frame);
                else
                    c = obj.meanIntensities(1);
                end
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            
            % Remove the Amp responses if it's an MEA rig
            if obj.isMeaRig
                amps = obj.rig.getDevices('Amp');
                for ii = 1:numel(amps)
                    if epoch.hasResponse(amps{ii})
                        epoch.removeResponse(amps{ii});
                    end
                    if epoch.hasStimulus(amps{ii})
                        epoch.removeStimulus(amps{ii});
                    end
                end
            end
            
            % Get the current stixel size and frame dwell
            obj.stixelSize = obj.stixelSizes(mod(obj.numEpochsCompleted, length(obj.stixelSizes))+1);
            obj.frameDwell = obj.frameDwells(mod(obj.numEpochsCompleted, length(obj.frameDwells))+1);
            
            % Set the seed
            if obj.numEpochsCompleted == 0
                obj.seed = RandStream.shuffleSeed;
            else
                obj.seed = obj.seed + 1;
            end
            
            % Calculate stixel dimensions
            obj.stepsPerStixel = max(round(obj.stixelSize / obj.gridSize), 1);
            
            gridSizePix = obj.rig.getDevice('Stage').um2pix(obj.gridSize);
            obj.stixelSizePix = gridSizePix * obj.stepsPerStixel;
            obj.stixelShiftPix = obj.stixelSizePix / obj.stepsPerStixel;
            
            % Calculate the number of X/Y stixels
            obj.numXStixels = ceil(obj.canvasSize(1)/obj.stixelSizePix) + 1;
            obj.numYStixels = ceil(obj.canvasSize(2)/obj.stixelSizePix) + 1;
            obj.numXChecks = ceil(obj.canvasSize(1)/gridSizePix);
            obj.numYChecks = ceil(obj.canvasSize(2)/gridSizePix);
            
            % Seed the generators
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);
            obj.positionStream = RandStream('mt19937ar', 'Seed', obj.seed + 1000);
            
            % Pre-compute all intensity values for this epoch
            obj.precomputeTraces();
            
            % Add parameters to epoch
            epoch.addParameter('seed', obj.seed);
            epoch.addParameter('numXChecks', obj.numXChecks);
            epoch.addParameter('numYChecks', obj.numYChecks);
            epoch.addParameter('numXStixels', obj.numXStixels);
            epoch.addParameter('numYStixels', obj.numYStixels);
            epoch.addParameter('stixelSize', obj.gridSize * obj.stepsPerStixel);
            epoch.addParameter('stepsPerStixel', obj.stepsPerStixel);
            epoch.addParameter('frameDwell', obj.frameDwell);
            epoch.addParameter('meanSwitchInterval', obj.meanSwitchInterval);
            epoch.addParameter('meanIntensities', obj.meanIntensities);
            epoch.addParameter('totalFrames', obj.totalFrames);
            epoch.addParameter('framesPerSwitch', obj.framesPerSwitch);
            
            % Display info
            disp(['Epoch ' num2str(obj.numEpochsCompleted + 1) ' of ' num2str(obj.numberOfAverages)]);
            disp(['Seed: ', num2str(obj.seed)]);
            disp(['Stixel size: ', num2str(obj.stixelSize), ' µm']);
            disp(['Frame dwell: ', num2str(obj.frameDwell)]);
            disp(['Mean intensities: ', num2str(obj.meanIntensities)]);
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end

    end
end
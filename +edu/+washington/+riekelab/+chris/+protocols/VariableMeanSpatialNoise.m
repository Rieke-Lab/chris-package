classdef VariableMeanSpatialNoise < manookinlab.protocols.ManookinLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 250                   % Noise leading duration (ms)
        stimTime = 30000                % Duration of entire long epoch (ms) - increased default
        tailTime = 250                  % Noise trailing duration (ms)
        contrast = 1
        stixelSizes = [90,90]           % Edge length of stixel (microns)
        gridSize = 30                   % Size of underling grid
        gaussianFilter = false          % Whether to use a Gaussian filter
        filterSdStixels = 1.0           % Gaussian filter standard dev in stixels.
        meanLightLevels = [0.06, 0.5]  % Mean light intensity levels to alternate between (0-1)
        switchTime = 3000               % Time to switch between means within epoch (ms)
        frameDwells = uint16([1,1])     % Frame dwell.
        useRepeatSeed = false           % Use same seed across all epochs for identical sequences
        chromaticClass = 'achromatic'   % Chromatic type
        onlineAnalysis = 'none'
        numberOfAverages = uint16(10)   % Number of long epochs (reduced default)
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        chromaticClassType = symphonyui.core.PropertyType('char','row',{'achromatic','RGB','BY','B','Y','S-iso','LM-iso'})
        stixelSizesType = symphonyui.core.PropertyType('denserealdouble','matrix')
        frameDwellsType = symphonyui.core.PropertyType('denserealdouble','matrix')
        meanLightLevelsType = symphonyui.core.PropertyType('denserealdouble','matrix')
        useRepeatSeedType = symphonyui.core.PropertyType('logical', 'scalar')
        backgroundIntensity             % Current epoch's background intensity
        meanIndex                       % Current mean level index
        stixelSize
        stepsPerStixel
        numXStixels
        numYStixels
        numXChecks
        numYChecks
        seed
        epochSeed                       % Seed for this specific epoch
        numFrames
        switchFrames                    % Frames at which to switch means
        totalSwitches                   % Total number of switches in epoch
        intensityTrace                  % Frame-by-frame intensity trace
        stixelSizePix
        stixelShiftPix
        imageMatrix
        noiseStream
        positionStream
        monitor_gamma
        frameDwell
        pre_frames
        stim_frames
        time_multiple
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    methods
        function didSetRig(obj)
            didSetRig@manookinlab.protocols.ManookinLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            
            % Get the number of frames.
            obj.numFrames = floor(obj.stimTime * 1e-3 * obj.frameRate)+15;
            obj.pre_frames = round(obj.preTime * 1e-3 * 60.0);
            obj.stim_frames = round(obj.stimTime * 1e-3 * 60.0);
            
            % Calculate switch frames
            switchTimeFrames = round(obj.switchTime * 1e-3 * 60.0);
            obj.totalSwitches = floor(obj.stim_frames / switchTimeFrames);
            obj.switchFrames = (1:obj.totalSwitches) * switchTimeFrames;
            
            % Initialize intensity trace
            obj.intensityTrace = zeros(1, obj.stim_frames);

            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                obj.chromaticClass = 'achromatic';
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
            
            % Generate base seed for the run
            if obj.useRepeatSeed
                obj.seed = 1; % Fixed seed for all epochs
            else
                obj.seed = RandStream.shuffleSeed;
            end
            
            if obj.gaussianFilter
                % Get the gamma ramps.
                [r,g,b] = obj.rig.getDevice('Stage').getMonitorGammaRamp();
                obj.monitor_gamma = [r;g;b];
                gamma_scale = 0.5/(0.5539*exp(-0.8589*obj.filterSdStixels)+0.05732);
                new_gamma = 65535*(0.5*gamma_scale*linspace(-1,1,256)+0.5);
                new_gamma(new_gamma < 0) = 0;
                new_gamma(new_gamma > 65535) = 65535;
                obj.rig.getDevice('Stage').setMonitorGammaRamp(new_gamma, new_gamma, new_gamma);
            end            
        end
        
        % Get current mean intensity based on frame number
        function intensity = getCurrentMeanIntensity(obj, frame)
            if frame <= 0
                intensity = obj.meanLightLevels(1);
                return;
            end
            
            % Determine which switch period we're in
            switchTimeFrames = round(obj.switchTime * 1e-3 * 60.0);
            switchIndex = floor((frame - 1) / switchTimeFrames);
            meanIndex = mod(switchIndex, length(obj.meanLightLevels)) + 1;
            intensity = obj.meanLightLevels(meanIndex);
        end
        
        % Create a Gaussian filter for the stimulus.
        function h = get_gaussian_filter(obj)
            p2 = (2*ceil(2*obj.filterSdStixels)+1) * ones(1,2);
            siz   = (p2-1)/2;
            std   = obj.filterSdStixels;

            [x,y] = meshgrid(-siz(2):siz(2),-siz(1):siz(1));
            arg   = -(x.*x + y.*y)/(2*std*std);

            h     = exp(arg);
            h(h<eps*max(h(:))) = 0;

            sumh = sum(h(:));
            if sumh ~= 0
                h  = h/sumh;
            end
        end

 
        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3 * obj.time_multiple);
            
            % Start with first mean level
            initialIntensity = obj.meanLightLevels(1);
            p.setBackgroundColor(initialIntensity);

            obj.imageMatrix = initialIntensity * ones(obj.numYStixels,obj.numXStixels);
            checkerboard = stage.builtin.stimuli.Image(uint8(obj.imageMatrix));
            checkerboard.position = obj.canvasSize / 2;
            checkerboard.size = [obj.numXStixels, obj.numYStixels] * obj.stixelSizePix;

            % Set the minifying and magnifying functions to form discrete stixels.
            checkerboard.setMinFunction(GL.NEAREST);
            checkerboard.setMagFunction(GL.NEAREST);
            
            % Get the filter.
            if obj.gaussianFilter
                kernel = obj.get_gaussian_filter(); 

                filter = stage.core.Filter(kernel);
                checkerboard.setFilter(filter);
                checkerboard.setWrapModeS(GL.MIRRORED_REPEAT);
                checkerboard.setWrapModeT(GL.MIRRORED_REPEAT);
            end
            
            % Add the stimulus to the presentation.
            p.addStimulus(checkerboard);
            
            gridVisible = stage.builtin.controllers.PropertyController(checkerboard, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3 * 1.011);
            p.addController(gridVisible);
            
            % Calculate preFrames
            preF = floor(obj.preTime/1000 * 60);

            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state)setStixelsPatternMode(obj, state.time - obj.preTime*1e-3, state.frame - preF));
            elseif ~strcmp(obj.chromaticClass,'achromatic')
                if strcmp(obj.chromaticClass,'BY')
                    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                        @(state)setBYStixels(obj, state.frame - preF));
                elseif strcmp(obj.chromaticClass,'B')
                    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                        @(state)setBStixels(obj, state.frame - preF));
                elseif strcmp(obj.chromaticClass,'RGB')
                    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                        @(state)setRGBStixels(obj, state.frame - preF));
                else  
                    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                        @(state)setIsoStixels(obj, state.frame - preF));
                end
            else
                imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state)setStixels(obj, state.frame - preF));
            end
            p.addController(imgController);
            
            % Background controller to change mean intensity
            backgroundController = stage.builtin.controllers.PropertyController(p, 'backgroundColor',...
                @(state)obj.getCurrentMeanIntensity(state.frame - preF));
            p.addController(backgroundController);
            
            % Position controller
            if obj.stepsPerStixel > 1
                if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter')) % Pattern mode
                    xyController = stage.builtin.controllers.PropertyController(checkerboard, 'position',...
                        @(state)setJitterPatternMode(obj, state.time - obj.preTime*1e-3, state.frame - preF));
                else
                    xyController = stage.builtin.controllers.PropertyController(checkerboard, 'position',...
                        @(state)setJitter(obj, state.frame - preF));
                end
                p.addController(xyController);
            end
            
            function s = setStixels(obj, frame)
                persistent M;
                if frame > 0 && frame <= obj.stim_frames
                    currentIntensity = obj.getCurrentMeanIntensity(frame);
                    obj.intensityTrace(frame) = currentIntensity;
                    
                    if mod(frame, obj.frameDwell) == 0
                        M = 2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels)>0.5)-1;
                        M = obj.contrast*M*currentIntensity + currentIntensity;
                    end
                else
                    M = obj.imageMatrix;
                end
                s = uint8(255*M);
            end

            function s = setStixelsPatternMode(obj, time, frame)
                if time > 0 && frame > 0 && frame <= obj.stim_frames
                    currentIntensity = obj.getCurrentMeanIntensity(frame);
                    obj.intensityTrace(frame) = currentIntensity;
                    
                    M = 2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels)>0.5)-1;
                    M = obj.contrast*M*currentIntensity + currentIntensity;
                else
                    M = obj.imageMatrix;
                end
                s = uint8(255*M);
            end
            
            % RGB noise
            function s = setRGBStixels(obj, frame)
                persistent M;
                if frame > 0 && frame <= obj.stim_frames
                    currentIntensity = obj.getCurrentMeanIntensity(frame);
                    obj.intensityTrace(frame) = currentIntensity;
                    
                    if mod(frame, obj.frameDwell) == 0
                        M = 2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels,3)>0.5)-1;
                    end
                    M = obj.contrast*M*currentIntensity + currentIntensity;
                else
                    M = obj.imageMatrix;
                end
                s = single(M);
            end
            
            % Blue-Yellow noise
            function s = setBYStixels(obj, frame)
                persistent M;
                if frame > 0 && frame <= obj.stim_frames
                    currentIntensity = obj.getCurrentMeanIntensity(frame);
                    obj.intensityTrace(frame) = currentIntensity;
                    
                    if mod(frame, obj.frameDwell) == 0
                        M = zeros(obj.numYStixels,obj.numXStixels,3);
                        tmpM = obj.contrast*(2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels,2)>0.5)-1);
                        tmpM = tmpM*currentIntensity + currentIntensity;
                        M(:,:,1:2) = repmat(tmpM(:,:,1),[1,1,2]);
                        M(:,:,3) = tmpM(:,:,2);
                    end
                else
                    M = obj.imageMatrix;
                end
                s = single(M);
            end
            
            % Blue noise
            function s = setBStixels(obj, frame)
                persistent M;
                w = [0.8648,-0.3985,1];
                if frame > 0 && frame <= obj.stim_frames
                    currentIntensity = obj.getCurrentMeanIntensity(frame);
                    obj.intensityTrace(frame) = currentIntensity;
                    
                    if mod(frame, obj.frameDwell) == 0
                        M = zeros(obj.numYStixels,obj.numXStixels,3);
                        tmpM = obj.contrast*(2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels)>0.5)-1);
                        M(:,:,1) = tmpM*w(1);
                        M(:,:,2) = tmpM*w(2);
                        M(:,:,3) = tmpM*w(3);
                        M = M*currentIntensity + currentIntensity;
                    end
                else
                    M = obj.imageMatrix;
                end
                s = single(M);
            end
            
            % Cone-iso noise
            function s = setIsoStixels(obj, frame)
                persistent M;
                if frame > 0 && frame <= obj.stim_frames
                    currentIntensity = obj.getCurrentMeanIntensity(frame);
                    obj.intensityTrace(frame) = currentIntensity;
                    
                    if mod(frame, obj.frameDwell) == 0
                        M = zeros(obj.numYStixels,obj.numXStixels,3);
                        tmpM = obj.contrast*(2*(obj.noiseStream.rand(obj.numYStixels,obj.numXStixels)>0.5)-1);
                        M(:,:,1) = tmpM*obj.colorWeights(1);
                        M(:,:,2) = tmpM*obj.colorWeights(2);
                        M(:,:,3) = tmpM*obj.colorWeights(3);
                        M = M * currentIntensity + currentIntensity;
                    end
                else
                    M = obj.imageMatrix;
                end
                s = single(M);
            end
            
            function p = setJitter(obj, frame)
                persistent xy;
                if frame > 0
                    if mod(frame, obj.frameDwell) == 0
                        xy = obj.stixelShiftPix*round((obj.stepsPerStixel-1)*(obj.positionStream.rand(1,2))) ...
                            + obj.canvasSize / 2;
                    end
                else
                    xy = obj.canvasSize / 2;
                end
                p = xy;
            end

            function p = setJitterPatternMode(obj, time, frame)
                if time > 0
                    xy = obj.stixelShiftPix*round((obj.stepsPerStixel-1)*(obj.positionStream.rand(1,2))) ...
                        + obj.canvasSize / 2;
                else
                    xy = obj.canvasSize / 2;
                end
                p = xy;
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            
            % Remove the Amp responses if it's an MEA rig.
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
            
            if strcmpi(obj.chromaticClass, 'S-iso') || strcmpi(obj.chromaticClass, 'LM-iso')
                obj.setColorWeights();
            elseif strcmpi(obj.chromaticClass, 'Y')
                obj.colorWeights = [1;1;0];
            end
            
            % Initialize intensity trace for this epoch
            obj.intensityTrace = zeros(1, obj.stim_frames);
            
            % Get the current stixel size.
            obj.stixelSize = obj.stixelSizes(mod(obj.numEpochsCompleted, length(obj.stixelSizes))+1);
            obj.frameDwell = obj.frameDwells(mod(obj.numEpochsCompleted, length(obj.frameDwells))+1);
            
            % Set the seed for this epoch
            if obj.useRepeatSeed
                % Use same seed for all epochs - creates identical sequences
                obj.epochSeed = obj.seed;
            else
                % Different seed for each epoch
                obj.epochSeed = obj.seed + obj.numEpochsCompleted;
            end
            
            obj.stepsPerStixel = max(round(obj.stixelSize / obj.gridSize), 1);
            
            gridSizePix = obj.rig.getDevice('Stage').um2pix(obj.gridSize);
            obj.stixelSizePix = gridSizePix * obj.stepsPerStixel;
            obj.stixelShiftPix = obj.stixelSizePix / obj.stepsPerStixel;
            
            % Calculate the number of X/Y checks.
            obj.numXStixels = ceil(obj.canvasSize(1)/obj.stixelSizePix) + 1;
            obj.numYStixels = ceil(obj.canvasSize(2)/obj.stixelSizePix) + 1;
            obj.numXChecks = ceil(obj.canvasSize(1)/gridSizePix);
            obj.numYChecks = ceil(obj.canvasSize(2)/gridSizePix);
            
            disp(['num checks, x: ',num2str(obj.numXChecks),'; y: ',num2str(obj.numYChecks)]);
            disp(['num stixels, x: ',num2str(obj.numXStixels),'; y: ',num2str(obj.numYStixels)]);
            disp(['total switches: ',num2str(obj.totalSwitches),'; switch time: ',num2str(obj.switchTime),'ms']);
            disp(['epoch seed: ',num2str(obj.epochSeed),'; use repeat: ',num2str(obj.useRepeatSeed)]);
            
            % Seed the generator
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.epochSeed);
            obj.positionStream = RandStream('mt19937ar', 'Seed', obj.epochSeed);
             
            epoch.addParameter('seed', obj.epochSeed);
            epoch.addParameter('baseSeed', obj.seed);
            epoch.addParameter('switchTime', obj.switchTime);
            epoch.addParameter('switchFrames', obj.switchFrames);
            epoch.addParameter('totalSwitches', obj.totalSwitches);
            epoch.addParameter('meanLightLevels', obj.meanLightLevels);
            epoch.addParameter('useRepeatSeed', obj.useRepeatSeed);
            epoch.addParameter('numXChecks', obj.numXChecks);
            epoch.addParameter('numYChecks', obj.numYChecks);
            epoch.addParameter('numFrames', obj.numFrames);
            epoch.addParameter('numXStixels', obj.numXStixels);
            epoch.addParameter('numYStixels', obj.numYStixels);
            epoch.addParameter('stixelSize', obj.gridSize*obj.stepsPerStixel);
            epoch.addParameter('stepsPerStixel', obj.stepsPerStixel);
            epoch.addParameter('frameDwell', obj.frameDwell);
            epoch.addParameter('pre_frames', obj.pre_frames);
            epoch.addParameter('stim_frames', obj.stim_frames);
        end
        
        function completeEpoch(obj, epoch)
            completeEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            
            % Save the intensity trace for this epoch
            epoch.addParameter('intensityTrace', obj.intensityTrace);
        end
        
        function a = get.amp2(obj)
            amps = obj.rig.getDeviceNames('Amp');
            if numel(amps) < 2
                a = '(None)';
            else
                i = find(~ismember(amps, obj.amp), 1);
                a = amps{i};
            end
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
        function completeRun(obj)
            completeRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            % Reset the Gamma back to the original.
            if obj.gaussianFilter
                obj.rig.getDevice('Stage').setMonitorGammaRamp(obj.monitor_gamma(1,:), obj.monitor_gamma(2,:), obj.monitor_gamma(3,:));
            end
        end
    end
end
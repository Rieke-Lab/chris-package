classdef ledSinusoidNoiseEpochs < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        led                             % Output LED
        preTime = 0                     % ms
        stimTime = 2000                 % ms
        tailTime = 0                    % ms
        noiseStdv = 0.3                 % contrast, as fraction of mean
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        temporalContrast = 0.5          % contrast of sinusoidal modulation (0-1)
        temporalFrequency = 2           % Hz
        meanIntensity = 0.4             % LED mean (V or norm. [0-1] depending on LED units)
        useRandomSeed = true            % false = repeated noise trajectory (seed 0)
        onlineAnalysis = 'extracellular'
        amp                             % Input amplifier
        numberOfAverages = uint16(100)  % number of epochs to queue
        interpulseInterval = 0          % Duration between stimuli (s)
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties (Hidden)
        ledType
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        noiseSeed
        stimulusTag
        sinusoidValues
        noiseValues
        combinedValues
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()createPreviewStimuli(obj));
            function s = createPreviewStimuli(obj)
                s = cell(1, 3); % One for each stimulus type
                
                % Create sinusoid only
                s{1} = obj.createStimulusForType('sinusoidOnly', 0);
                
                % Create noise only
                s{2} = obj.createStimulusForType('noiseOnly', 0);
                
                % Create combined
                s{3} = obj.createStimulusForType('sinusoidPlusNoise', 0);
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            colors = [0.8 0 0; 0 0.8 0; 0 0 0.8]; % Red, Green, Blue for different stimulus types
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                    'groupBy', {'stimulusTag'}, 'sweepColor', colors);
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.stimTime], ...
                    'measurementRegion', [0 obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2), ...
                    'groupBy1', {'stimulusTag'}, ...
                    'groupBy2', {'stimulusTag'}, ...
                    'sweepColor', colors);
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', ...
                    obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.stimTime], ...
                    'measurementRegion1', [0 obj.stimTime], ...
                    'baselineRegion2', [0 obj.stimTime], ...
                    'measurementRegion2', [0 obj.stimTime]);
            end


            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.showFigure('edu.washington.riekelab.figures.LedPhaseLinearFilterFigure', ...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.led), ...
                    'recordingType', obj.onlineAnalysis, 'preTime', obj.preTime, ...
                    'stimTime', obj.stimTime, 'sampleRate', obj.sampleRate, ...
                    'figureTitle', 'LED Phase-separated Noise Analysis');
            end


            % Set LED background
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.meanIntensity, device.background.displayUnits);
        end
        
        function stim = createStimulusForType(obj, stimType, seed)
            % Function to create stimulus for specific type
            device = obj.rig.getDevice(obj.led);
            
            % Generate sinusoid component if needed
            if strcmp(stimType, 'sinusoidOnly') || strcmp(stimType, 'sinusoidPlusNoise')
                sineGen = symphonyui.builtin.stimuli.SineGenerator();
                sineGen.preTime = obj.preTime;
                sineGen.stimTime = obj.stimTime;
                sineGen.tailTime = obj.tailTime;
                sineGen.amplitude = obj.temporalContrast * obj.meanIntensity;
                sineGen.period = 1000 / obj.temporalFrequency; % Convert Hz to period in ms
                sineGen.phase = 0;
                sineGen.mean = obj.meanIntensity;
                sineGen.sampleRate = obj.sampleRate;
                sineGen.units = device.background.displayUnits;
                
                sineStim = sineGen.generate();
                obj.sinusoidValues = sineStim.getData();
            else
                % Create flat line at mean for noise-only
                obj.sinusoidValues = ones(1, obj.sampleRate * (obj.preTime + obj.stimTime + obj.tailTime) / 1000) * obj.meanIntensity;
            end
            
            % Generate noise component if needed
            if strcmp(stimType, 'noiseOnly') || strcmp(stimType, 'sinusoidPlusNoise')
                noiseGen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
                
                noiseGen.preTime = obj.preTime;
                noiseGen.stimTime = obj.stimTime;
                noiseGen.tailTime = obj.tailTime;
                noiseGen.stDev = obj.noiseStdv * obj.meanIntensity;
                noiseGen.freqCutoff = obj.frequencyCutoff;
                noiseGen.numFilters = obj.numberOfFilters;
                noiseGen.mean = obj.meanIntensity;
                noiseGen.seed = seed;
                noiseGen.sampleRate = obj.sampleRate;
                noiseGen.units = device.background.displayUnits;
                
                % Set limits based on units
                if strcmp(device.background.displayUnits, symphonyui.core.Measurement.NORMALIZED)
                    noiseGen.upperLimit = 1;
                    noiseGen.lowerLimit = 0;
                else
                    noiseGen.upperLimit = 10.239;
                    noiseGen.lowerLimit = -10.24;
                end
                
                noiseStim = noiseGen.generate();
                obj.noiseValues = noiseStim.getData();
            else
                % For sinusoid only, create zero noise
                obj.noiseValues = zeros(1, obj.sampleRate * (obj.preTime + obj.stimTime + obj.tailTime) / 1000) + obj.meanIntensity;
            end
            
            % Create combined stimulus based on type
            switch stimType
                case 'sinusoidOnly'
                    obj.combinedValues = obj.sinusoidValues;
                case 'noiseOnly'
                    obj.combinedValues = obj.noiseValues;
                case 'sinusoidPlusNoise'
                    % Remove mean from noise (as mean is already in sinusoid)
                    noiseWithoutMean = obj.noiseValues - obj.meanIntensity;
                    % Add noise to sinusoid
                    obj.combinedValues = obj.sinusoidValues + noiseWithoutMean;
                    
                    % Clip if necessary
                    if strcmp(device.background.displayUnits, symphonyui.core.Measurement.NORMALIZED)
                        obj.combinedValues(obj.combinedValues < 0) = 0;
                        obj.combinedValues(obj.combinedValues > 1) = 1;
                    else
                        obj.combinedValues(obj.combinedValues < -10.24) = -10.24;
                        obj.combinedValues(obj.combinedValues > 10.239) = 10.239;
                    end
            end
            
            % Create stimulus from combined values
            stim = symphonyui.core.Stimulus(obj.combinedValues, device.background.displayUnits);
            
            % Set stimulus sample rate
            if ~isempty(stim.sampleRate)
                stim = stim.sampleRate(obj.sampleRate);
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            % Determine stimulus type based on epoch number
            stimTypes = {'sinusoidOnly', 'noiseOnly', 'sinusoidPlusNoise'};
            currentStimType = stimTypes{mod(obj.numEpochsCompleted, 3) + 1};
            
            % Set seed for noise
            if ~obj.useRandomSeed
                seed = 0;
            else
                seed = RandStream.shuffleSeed;
            end
            obj.noiseSeed = seed;
            
            % Create stimulus
            stim = obj.createStimulusForType(currentStimType, seed);
            
            % Add stimulus and metadata to epoch
            epoch.addParameter('noiseSeed', seed);
            epoch.addParameter('stimulusTag', currentStimType);
            epoch.addParameter('sinusoidValues', obj.sinusoidValues);
            epoch.addParameter('noiseValues', obj.noiseValues);
            epoch.addParameter('combinedValues', obj.combinedValues);
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
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
    end
end
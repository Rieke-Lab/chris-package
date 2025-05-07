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
    
    
    properties (Hidden)
        ledType
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        stimulusTag
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()createPreviewStimuli(obj));
            function s = createPreviewStimuli(obj)
                s = cell(1, 3); % One for each stimulus type
                
                % Create sinusoid only
                s{1} = obj.createStimulus(0, 'sinusoidOnly');
                
                % Create noise only
                s{2} = obj.createStimulus(0, 'noiseOnly');
                
                % Create combined
                s{3} = obj.createStimulus(0, 'sinusoidPlusNoise');
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            colors = [0.8 0 0; 0 0.8 0; 0 0 0.8]; % Red, Green, Blue for different stimulus types

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                'groupBy', {'stimulusTag'}, 'sweepColor', colors);
       
            
            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.showFigure('edu.washington.riekelab.chris.figures.LedPhaseLinearFilterFigure', ...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.led), ...
                    'recordingType', obj.onlineAnalysis, 'preTime', obj.preTime, ...
                    'stimTime', obj.stimTime, 'sampleRate', obj.sampleRate, ...
                    'figureTitle', 'LED Phase-separated Noise Analysis');
            end
          
            % Set LED background
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.meanIntensity, device.background.displayUnits);
        end
        
        function stim = createStimulus(obj, seed, stimulusType)
            % Unified stimulus creation function using SinusoidPlusNoiseGenerator
            device = obj.rig.getDevice(obj.led);
            
            % Use the SinusoidPlusNoiseGenerator for all stimulus types
            gen = edu.washington.riekelab.chris.stimuli.SinusoidPlusNoiseGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.mean = obj.meanIntensity;
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            gen.units = device.background.displayUnits;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.temporalFrequency = obj.temporalFrequency;

            % Set parameters based on stimulus type
            switch stimulusType
                case 'sinusoidOnly'
                    gen.noiseStdv = 0; % No noise
                    gen.temporalContrast = obj.temporalContrast;
                case 'noiseOnly'
                    gen.noiseStdv = obj.noiseStdv;
                    gen.temporalContrast = 0; % No sinusoid
                case 'sinusoidPlusNoise'
                    gen.noiseStdv = obj.noiseStdv;
                    gen.temporalContrast = obj.temporalContrast;
            end
            
            % Set limits based on units
            if strcmp(device.background.displayUnits, symphonyui.core.Measurement.NORMALIZED)
                gen.upperLimit = 1;
                gen.lowerLimit = 0;
            else
                gen.upperLimit = 10.239;
                gen.lowerLimit = -10.24;
            end 
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            % Determine stimulus type based on epoch number
            % First three epochs are sinusoid only
            % Then alternating between sinusoid+noise and noise only
            if obj.numEpochsCompleted < 2
                currentStimType = 'sinusoidOnly';
            else
                remainingEpochs = mod(obj.numEpochsCompleted - 2, 2);
                if remainingEpochs == 0
                    currentStimType = 'sinusoidPlusNoise';
                else
                    currentStimType = 'noiseOnly';
                end
            end
            obj.stimulusTag = currentStimType;
            % Print epoch count and stimulus type
            fprintf('Epoch %d out of %d, Stimulus Type: %s\n', ...
                obj.numEpochsCompleted, obj.numberOfAverages, currentStimType);
            
            % Set seed for noise
            if ~obj.useRandomSeed
                seed = 0;
            else
                seed = RandStream.shuffleSeed;
            end
            
            % Create stimulus
            stim = obj.createStimulus(seed, currentStimType);
           
%             sinusoidValues = stim.parameters('sinusoidValues');
%             noiseValues = stim.parameters('noiseValues');
            % Add stimulus and metadata to epoch
            epoch.addParameter('noiseSeed', seed);
            epoch.addParameter('stimulusTag', currentStimType);
%             epoch.addParameter('sinusoidValues', sinusoidValues);
%             epoch.addParameter('noiseValues', noiseValues);
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
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
        
    end
end
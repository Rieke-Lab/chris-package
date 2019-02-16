classdef TwoLedNoise < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents gaussian noise stimuli from two LEDs, first individually and then simultaneously. A
    % single cycle is composed of three epochs, each falling into a different stimulus group: first,
    % noise is presented with LED 1, then different noise is presented with LED 2, then both of these
    % noise stimuli are repeated simultaneously. Two random seeds can optionally be used for the first
    % cycle, otherwise constant seeds are used for the first cycle any time the protocol is run. New
    % random seeds can optionally be used during each subsequent cycle, otherwise the seeds from the
    % first cycle will be repeated. This option is available regardless of whether a random seed is used
    % on the first cycle.

    % Extra parameters written to each epoch: 
    %   - stimulus group
    %   - seed 1
    %   - seed 2

    properties
        led1                            % Output LED 1
        led2                            % Output LED 2
        preTime = 100                   % Noise leading duration (ms)
        stimTime = 600                  % Noise duration (ms)
        tailTime = 100                  % Noise trailing duration (ms)
        frequencyCutoff1 = 60           % Noise frequency cutoff for smoothing, LED 1 (Hz)
        frequencyCutoff2 = 60           % Noise frequency cutoff for smoothing, LED 2 (Hz)
        numberOfFilters1 = 4            % Number of filters in cascade for noise smoothing, LED 1
        numberOfFilters2 = 4            % Number of filters in cascade for noise smoothing, LED 2
        
        stdv1 = 0.005                   % Noise standard deviation, post-smoothing, LED 1 (V or norm. [0-1] depending on LED units)
        stdv2 = 0.005                   % Noise standard deviation, post-smoothing, LED 2 (V or norm. [0-1] depending on LED units)
        mean1 = 0.1                     % Noise and LED background mean, LED 1 (V or norm. [0-1] depending on LED units)
        mean2 = 0.1                     % Noise and LED background mean, LED 2 (V or norm. [0-1] depending on LED units)
        useRandomFirstSeed = false      % Use random first seed?
        useRepeatedSeed = false         % Repeat first seed?
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties 
        psth = false                    % Toggle PSTH
        numberOfCycles = uint16(5)      % Number of cycles
        interpulseInterval = 0          % Duration between noise stimuli (s)
    end
    
    properties (Hidden)
        led1Type
        led2Type
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led1, obj.led1Type] = obj.createDeviceNamesProperty('LED');
            [obj.led2, obj.led2Type] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        % function p = getPreview(obj, panel)
        % 
        % end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

                if obj.useRepeatedSeed
                    obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                        'psth', obj.psth, 'groupBy', {'stimulusGroup'});
                else
                    % TODO: Should overlay PSTHs for 3 epochs in cycle and then start over for next cycle
                    % obj.showFigure('edu.washington.riekelab.mardoum.figures.ResponseFigure', obj.rig.getDevice(obj.amp), ...
                    %     'psth',obj.psth);
                    obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
                end

                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.preTime], ...
                    'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.preTime], ...
                    'measurementRegion1', [obj.preTime obj.preTime+obj.stimTime], ...
                    'baselineRegion2', [0 obj.preTime], ...
                    'measurementRegion2', [obj.preTime obj.preTime+obj.stimTime]);
            end
            
            if strcmp(obj.led1, obj.led2)
                error('ERROR: LEDs 1 and 2 must be different');
            end

            device1 = obj.rig.getDevice(obj.led1);
            device2 = obj.rig.getDevice(obj.led2);
            device1.background = symphonyui.core.Measurement(obj.mean1, device1.background.displayUnits);
            device2.background = symphonyui.core.Measurement(obj.mean2, device2.background.displayUnits);
        end
        
        function stim = createLedStimulus(obj, ledNum, seed)
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();

            if ledNum == 1
                gen.stDev = obj.stdv1;
                gen.freqCutoff = obj.frequencyCutoff1;
                gen.numFilters = obj.numberOfFilters1;
                gen.mean = obj.mean1;
                gen.units = obj.rig.getDevice(obj.led1).background.displayUnits;
            elseif ledNum == 2
                gen.stDev = obj.stdv2;
                gen.freqCutoff = obj.frequencyCutoff2;
                gen.numFilters = obj.numberOfFilters2;
                gen.mean = obj.mean2;
                gen.units = obj.rig.getDevice(obj.led2).background.displayUnits;
            end
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            if strcmp(gen.units, symphonyui.core.Measurement.NORMALIZED)
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
            
            stimulusGroup = obj.getStimulusGroup();
            epoch.addParameter('stimulusGroup', stimulusGroup);

            persistent seed1;
            persistent seed2;
            if obj.numEpochsPrepared == 1  % note obj.numEpochsPrepared starts at 1 (before first epoch is prepared)
                if obj.useRandomFirstSeed
                    seed1 = RandStream.shuffleSeed;
                    seed2 = RandStream.shuffleSeed;
                else
                    seed1 = 0;
                    seed2 = 1;
                end
            else
                if ~obj.useRepeatedSeed && stimulusGroup == 1  % only change seed at start of cycle
                    seed1 = RandStream.shuffleSeed;
                    seed2 = RandStream.shuffleSeed;
                end
            end
            epoch.addParameter('seed1', seed1);
            epoch.addParameter('seed2', seed2);
            
            if stimulusGroup == 1                           % LED 1 alone
                stim = obj.createLedStimulus(1, seed1);
                epoch.addStimulus(obj.rig.getDevice(obj.led1), stim);
            elseif stimulusGroup == 2                       % LED 2 alone
                stim = obj.createLedStimulus(2, seed2);
                epoch.addStimulus(obj.rig.getDevice(obj.led2), stim);
            elseif stimulusGroup == 3                       % LEDs 1 and 2 simultaneously
                stim1 = obj.createLedStimulus(1, seed1);
                stim2 = obj.createLedStimulus(2, seed2);
                epoch.addStimulus(obj.rig.getDevice(obj.led1), stim1);
                epoch.addStimulus(obj.rig.getDevice(obj.led2), stim2);
            end

            epoch.addResponse(obj.rig.getDevice(obj.amp));
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device1 = obj.rig.getDevice(obj.led1);
            interval.addDirectCurrentStimulus(device1, device1.background, obj.interpulseInterval, obj.sampleRate);
            device2 = obj.rig.getDevice(obj.led2);
            interval.addDirectCurrentStimulus(device2, device2.background, obj.interpulseInterval, obj.sampleRate);
        end

        function stimulusGroup = getStimulusGroup(obj)
            stimulusGroup = int8(mod(obj.numEpochsPrepared - 1, 3) + 1);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < 3 * obj.numberOfCycles;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < 3 * obj.numberOfCycles;
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
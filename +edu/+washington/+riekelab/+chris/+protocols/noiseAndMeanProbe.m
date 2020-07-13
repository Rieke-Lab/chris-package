classdef noiseAndMeanProbe < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents segments of gaussian noise stimuli with constant contrast while randomly and periodically
    % altering mean light level.
    
    properties
        led                             % Output LED
        stimTime = 1000                  % Noise duration (ms)
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        contrast = [0 0.9]                  % Noise contrast
        useRandomSeed = true            % Use a random seed for each standard deviation multiple?
        lightMean = [ 0.05 0.5]       % Noise and LED background mean (V or norm. [0-1] depending on LED units)
        switchingEpochs=60   % each epoch is 1s, means stay in one mean at 60s
        amp
        numberOfAverages = uint16(3)    % Number of families
        % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties
        interpulseInterval = 0          % Duration between noise stimuli (s)
    end
    
    properties (Hidden)
        ledType
        ampType
        currentMean
        currentContrast
        currentRound
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
        
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                    'groupBy', {'stdv'});
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.stimTime], ...
                    'measurementRegion', [0 obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2), ...
                    'groupBy1', {'stdv'}, ...
                    'groupBy2', {'stdv'});
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', ...,
                    obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.stimTime], ...
                    'measurementRegion1', [0 obj.stimTime], ...
                    'baselineRegion2', [0 obj.stimTime], ...
                    'measurementRegion2', [0 obj.stimTime]);
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lightMean(1), device.background.displayUnits);
        end
        
        function [stim, stdv] = createLedStimulus(obj, meanIndex, contrastIndex, seed)
            cMean = obj.lightMean(meanIndex);
            cContrast = obj.Contrast(contrastIndex);
            stdv = cMean * cContrast;
            
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            
            gen.preTime = 0;
            gen.stimTime = obj.stimTime;
            gen.tailTime = 0;
            gen.stDev = stdv;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = lightMean;
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
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
            
            persistent seed;
            if ~obj.useRandomSeed
                seed = 0;
            else
                seed = RandStream.shuffleSeed;
            end
            periodIndex=(obj.numEpochsPrepared-mod(obj.numEpochsPrepared, obj.switchingEpochs))/obj.switchingEpochs+1;
            meanIndex=mod(periodIndex, numel(obj.lightMean));
            contrastIndex=numel(obj.contrast)-mod(obj.numEpochsPrepared,numel(obj.contrast));
            
            [stim, stdv] = obj.createLedStimulus(meanIndex, contrastIndex, seed);
            epoch.addParameter('stdv', stdv);
            epoch.addParameter('currentMean', obj.lightMean(meanIndex));
            epoch.addParameter('currentContrast', obj.contrast(contrastIndex));
            epoch.addParameter('currentRound', (periodIndex-mod(periodIndex,numel(obj.lightMean)))/(numel(obj.lightMean))+1);
            epoch.addParameter('seed', seed);
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
            tf = obj.numEpochsPrepared < obj.numberOfAverages*obj.switchingEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*obj.switchingEpochs;
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
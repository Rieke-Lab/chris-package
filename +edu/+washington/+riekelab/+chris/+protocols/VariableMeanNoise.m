classdef VariableMeanNoise < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents segments of gaussian noise stimuli with constant contrast while randomly and periodically
    % altering mean light level.  
    
    properties
        led                             % Output LED
        stimTime = 600                  % Noise duration (ms)
        frequencyCutoff = 60            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        Contrast = [0.125 0.25 0.5]                  % Noise contrast
        useRandomSeed = true            % Use a random seed for each standard deviation multiple?
        lightMean = [0.1 0.3 1 3]       % Noise and LED background mean (V or norm. [0-1] depending on LED units)
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties 
        numberOfAverages = uint16(5)    % Number of families
        interpulseInterval = 0          % Duration between noise stimuli (s)
    end
    
    properties (Hidden)
        ledType
        ampType
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
                s = cell(1, obj.numberOfAverages);
                for i = 1:numel(s)
                    if ~obj.useRandomSeed
                        seed = 0;
                    else
                        seed = RandStream.shuffleSeed;
                    end
                    s{i} = obj.createLedStimulus(i, seed);
                end
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
        
        function [stim, stdv] = createLedStimulus(obj, pulseNum, seed)
            lightMean = obj.lightMean(randi([1 length(obj.lightMean)]));
            lightContrast = obj.Contrast(randi([1 length(obj.Contrast)]));
            stdv = lightMean * lightContrast;
            
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
            
            [stim, stdv] = obj.createLedStimulus(obj.numEpochsPrepared, seed);
            epoch.addParameter('stdv', stdv);
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


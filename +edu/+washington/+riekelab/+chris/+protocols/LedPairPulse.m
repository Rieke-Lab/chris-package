classdef LedPairPulse < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents families of rectangular pulse stimuli to a specified LED and records responses from a specified
    % amplifier paired led
    
    properties
        led                             % Output LED
        preTime = 500                    % Pulse leading duration (ms)
        pulseDuration=20                % Pulse duration (ms)
        tailTime = 2000                  % Pulse trailing duration (ms)
        intervalFamily = [50 100 200 400 800 1200]   % ms interval of pairs
        pulseIntensity=0.05  % pulse amplitude (V or norm. [0-1] depending on LED units)
        meanIntensity = 0.2                  % Pulse and LED background mean (V or norm. [0-1] depending on LED units)
        numberOfAverages = uint16(3)      % Number of reps in family
        interpulseInterval = 0          % Duration between pulses (s)
        psth=true
        amp                             % Input amplifier
    end
    
    
    
    properties (Hidden)
        ledType
        ampType
        currentInterval
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
                s = cell(1, numel(obj.intervalFamily));
                for i = 1:numel(s)
                    s{i} = obj.createLedStimulus(i);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                'groupBy', {'currentInterval'},'psth',obj.psth);
            obj.showFigure('edu.washington.riekelab.chris.figures.pairPulseFigure', ...
                obj.rig.getDevice(obj.amp),'psth',obj.psth,...
                'preTime',obj.preTime,'pulseTime',obj.pulseDuration);
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.meanIntensity, device.background.displayUnits);
        end
        
        function [stim] = createLedStimulus(obj,pulseNum)
            gen = symphonyui.builtin.stimuli.PulseTrainGenerator();
            gen.preTime = obj.preTime;
            gen.pulseTime = obj.pulseDuration;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.pulseIntensity;
            gen.mean = obj.meanIntensity;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            gen.intervalTime=obj.intervalFamily(pulseNum);
            gen.numPulses=2;
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            pulseNum = mod(obj.numEpochsPrepared - 1, numel(obj.intervalFamily)) + 1;
            stim= obj.createLedStimulus(pulseNum);
            
            epoch.addParameter('currentInterval', obj.intervalFamily(pulseNum));
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages *numel(obj.intervalFamily);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages *numel(obj.intervalFamily);
        end
        
    end
    
end

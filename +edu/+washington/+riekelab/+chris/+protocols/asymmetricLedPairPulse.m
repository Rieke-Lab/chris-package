classdef asymmetricLedPairPulse < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Paired-pulse LED protocol with fixed inter-pulse interval and
    % variable second-pulse amplitude.
    %
    % Pulse 1 amplitude is fixed at pulseIntensity.
    % Pulse 2 starts at the same amplitude and increases in absolute value
    % until the LED output reaches its allowed limit.
    
    properties
        led                              % Output LED
        preTime = 500                    % ms before first pulse
        pulseDuration = 20               % ms
        pairInterval = 500               % ms gap between pulse 1 end and pulse 2 start
        tailTime = 2000                  % ms after second pulse
        
        pulseIntensity = 0.05            % first pulse amplitude
        secondPulseStep = 0.05           % increment for second pulse amplitude
        meanIntensity = 0.2              % LED background mean
        numberOfPulseFamily=10
        numberOfAverages = uint16(5)     % repetitions per family member
        interpulseInterval = 0           % s between epochs
        psth = true
        amp                              % Input amplifier
    end
    
    properties (Hidden)
        ledType
        ampType
        
        currentSecondPulseAmplitude
        currentSecondPulseContrast
        
        secondPulseFamily
        ledUpperLimit
        ledLowerLimit
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
            p = symphonyui.builtin.previews.StimuliPreview(panel, @createPreviewStimuli);
            
            function s = createPreviewStimuli()
                obj.setLedLimits();
                fam = obj.getSecondPulseFamily();
                s = cell(1, numel(fam));
                for i = 1:numel(fam)
                    s{i} = obj.createLedStimulus(fam(i));
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.setLedLimits();
            obj.secondPulseFamily = obj.getSecondPulseFamily();
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', ...
                obj.rig.getDevice(obj.amp));
            
            obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure', ...
                obj.rig.getDevice(obj.amp), ...
                'groupBy', {'currentSecondPulseAmplitude'}, ...
                'psth', obj.psth);
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement( ...
                obj.meanIntensity, device.background.displayUnits);
            
            fprintf('\nStarting protocol: %s\n', class(obj));
            fprintf('Pulse 1 amplitude: %g\n', obj.pulseIntensity);
            fprintf('Fixed pair interval: %g ms\n', obj.pairInterval);
            fprintf('Second pulse amplitudes: ');
            fprintf('%g ', obj.secondPulseFamily);
            fprintf('\n\n');
        end
        
        function stim = createLedStimulus(obj, secondPulseAmplitude)
            device = obj.rig.getDevice(obj.led);
            
            gen = edu.washington.riekelab.chris.stimuli.asymmetricPairPulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.pulseTime = obj.pulseDuration;
            gen.intervalTime = obj.pairInterval;
            gen.tailTime = obj.tailTime;
            
            gen.amplitude1 = obj.pulseIntensity;
            gen.amplitude2 = secondPulseAmplitude;
            
            gen.mean = obj.meanIntensity;
            gen.sampleRate = obj.sampleRate;
            gen.units = device.background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if isempty(obj.secondPulseFamily)
                obj.setLedLimits();
                obj.secondPulseFamily = obj.getSecondPulseFamily();
            end
            
            familyIndex = mod(obj.numEpochsPrepared, numel(obj.secondPulseFamily)) + 1;
            secondAmp = obj.secondPulseFamily(familyIndex);
            
            stim = obj.createLedStimulus(secondAmp);
            
            if obj.meanIntensity ~= 0
                secondContrast = secondAmp / obj.meanIntensity;
            else
                secondContrast = NaN;
            end
            
            obj.currentSecondPulseAmplitude = secondAmp;
            obj.currentSecondPulseContrast = secondContrast;
            
            epoch.addParameter('currentSecondPulseAmplitude', secondAmp);
            epoch.addParameter('currentSecondPulseContrast', secondContrast);
            epoch.addParameter('pairInterval', obj.pairInterval);
            epoch.addParameter('pulse1Amplitude', obj.pulseIntensity);
            epoch.addParameter('pulse2Amplitude', secondAmp);
            
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            fprintf('Preparing epoch %d / %d | pulse1 = %g | pulse2 = %g | interval = %g ms\n', ...
                obj.numEpochsPrepared, ...
                obj.numberOfAverages * numel(obj.secondPulseFamily), ...
                obj.pulseIntensity, secondAmp, obj.pairInterval);
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus( ...
                device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages * numel(obj.secondPulseFamily);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages * numel(obj.secondPulseFamily);
        end
        
    end
    
    methods (Access = private)
        
        function setLedLimits(obj)
            device = obj.rig.getDevice(obj.led);
            
            if strcmp(device.background.displayUnits, symphonyui.core.Measurement.NORMALIZED)
                obj.ledUpperLimit = 1;
                obj.ledLowerLimit = 0;
            else
                obj.ledUpperLimit = 10.239;
                obj.ledLowerLimit = -10.24;
            end
        end
        
        function fam = getSecondPulseFamily(obj)
            % Build second-pulse amplitude family.
            %
            % Starts at pulseIntensity and increases in absolute value in the
            % same direction until either:
            %   1) numberOfPulseFamily is reached
            %   2) LED intensity limit is reached
            
            a1 = obj.pulseIntensity;
            step = abs(obj.secondPulseStep);
            maxN = obj.numberOfPulseFamily;
            
            if step == 0 || maxN <= 1
                fam = a1;
                return;
            end
            
            fam = a1;
            
            if a1 > 0
                limit = obj.ledUpperLimit - obj.meanIntensity;
                direction = +1;
            elseif a1 < 0
                limit = obj.ledLowerLimit - obj.meanIntensity;
                direction = -1;
            else
                fam = 0;
                return;
            end
            
            current = a1;
            
            while length(fam) < maxN
                nextAmp = current + direction * step;
                
                % stop if LED limit would be exceeded
                if direction > 0
                    if nextAmp > limit
                        break
                    end
                else
                    if nextAmp < limit
                        break
                    end
                end
                
                fam(end+1) = nextAmp;
                current = nextAmp;
            end
            
            fam = unique(fam,'stable');
        end
    end
end
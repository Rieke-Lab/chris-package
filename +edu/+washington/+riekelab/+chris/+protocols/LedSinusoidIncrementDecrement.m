classdef LedSinusoidIncrementDecrement < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Full-field LED sinusoids for excitatory increment/decrement analysis.

    properties
        led
        preTime = 500                         % ms
        stimTime = 2000                       % ms
        tailTime = 500                        % ms
        temporalFrequencies = 2               % Hz
        sinusoidContrasts = [0.1 0.25 0.5 1]  % fraction of mean
        lightMeans = [0.05 0.4]               % LED units
        onlineAnalysis = 'exc'
        amp
        numberOfAverages = uint16(5)          % averages per condition
        interpulseInterval = 0                % s
    end

    properties (Hidden)
        ledType
        ampType
        temporalFrequenciesType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        sinusoidContrastsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        lightMeansType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'exc'})
        stimulusSequence
        currentTemporalFrequency
        currentSinusoidContrast
        currentLightMean
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            obj.validateParameters();
            obj.stimulusSequence = obj.makeStimulusSequence();

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', ...
                obj.rig.getDevice(obj.amp));
            if strcmp(obj.onlineAnalysis, 'exc')
                obj.showFigure( ...
                    'edu.washington.riekelab.chris.figures.LedSinusoidMeanTraceFigure', ...
                    obj.rig.getDevice(obj.amp), ...
                    'preTime', obj.preTime, ...
                    'lightMeans', obj.lightMeans, ...
                    'sinusoidContrasts', obj.sinusoidContrasts, ...
                    'temporalFrequencies', obj.temporalFrequencies);
                obj.showFigure( ...
                    'edu.washington.riekelab.chris.figures.LedSinusoidIncrementDecrementFigure', ...
                    obj.rig.getDevice(obj.amp), ...
                    'preTime', obj.preTime, ...
                    'stimTime', obj.stimTime, ...
                    'lightMeans', obj.lightMeans, ...
                    'sinusoidContrasts', obj.sinusoidContrasts, ...
                    'temporalFrequencies', obj.temporalFrequencies);
            end

            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement( ...
                obj.lightMeans(1), device.background.displayUnits);
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            condition = obj.stimulusSequence(obj.numEpochsPrepared + 1, :);
            obj.currentLightMean = condition(1);
            obj.currentSinusoidContrast = condition(2);
            obj.currentTemporalFrequency = condition(3);

            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus());
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            epoch.addParameter('currentLightMean', obj.currentLightMean);
            epoch.addParameter('currentSinusoidContrast', obj.currentSinusoidContrast);
            epoch.addParameter('currentTemporalFrequency', obj.currentTemporalFrequency);
        end

        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            device = obj.rig.getDevice(obj.led);
            background = symphonyui.core.Measurement( ...
                obj.currentLightMean, device.background.displayUnits);
            interval.addDirectCurrentStimulus( ...
                device, background, obj.interpulseInterval, obj.sampleRate);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < size(obj.stimulusSequence, 1);
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < size(obj.stimulusSequence, 1);
        end

    end

    methods (Access = private)

        function stim = createLedStimulus(obj)
            device = obj.rig.getDevice(obj.led);
            gen = edu.washington.riekelab.chris.stimuli.SinusoidPlusNoiseGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.mean = obj.currentLightMean;
            gen.noiseStdv = 0;
            gen.freqCutoff = 60;
            gen.numFilters = 1;
            gen.temporalContrast = obj.currentSinusoidContrast;
            gen.temporalFrequency = obj.currentTemporalFrequency;
            gen.seed = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = device.background.displayUnits;
            if strcmp(device.background.displayUnits, symphonyui.core.Measurement.NORMALIZED)
                gen.lowerLimit = 0;
                gen.upperLimit = 1;
            else
                gen.lowerLimit = -10.24;
                gen.upperLimit = 10.239;
            end
            stim = gen.generate();
        end

        function sequence = makeStimulusSequence(obj)
            [means, contrasts, frequencies] = ndgrid( ...
                obj.lightMeans(:), obj.sinusoidContrasts(:), ...
                obj.temporalFrequencies(:));
            conditions = [means(:), contrasts(:), frequencies(:)];
            sequence = zeros(size(conditions, 1) * double(obj.numberOfAverages), 3);
            n = size(conditions, 1);
            for repeat = 1:double(obj.numberOfAverages)
                rows = (repeat - 1) * n + (1:n);
                sequence(rows, :) = conditions(randperm(n), :);
            end
        end

        function validateParameters(obj)
            if obj.preTime <= 0
                error('preTime must be greater than zero for baseline subtraction.');
            end
            if obj.stimTime <= 0 || obj.tailTime < 0
                error('stimTime must be positive and tailTime cannot be negative.');
            end
            if isempty(obj.temporalFrequencies) || any(obj.temporalFrequencies(:) <= 0)
                error('temporalFrequencies must contain positive values.');
            end
            if isempty(obj.sinusoidContrasts) || any(obj.sinusoidContrasts(:) < 0) || ...
                    any(obj.sinusoidContrasts(:) > 1)
                error('sinusoidContrasts must contain fractions from zero to one.');
            end
            if isempty(obj.lightMeans) || any(~isfinite(obj.lightMeans(:))) || ...
                    any(obj.lightMeans(:) < 0)
                error('lightMeans must contain finite, nonnegative values.');
            end
            if double(obj.numberOfAverages) < 1
                error('numberOfAverages must be at least one per condition.');
            end
            if obj.stimTime / 1000 * min(obj.temporalFrequencies(:)) < 1
                error('stimTime must contain at least one cycle at every temporal frequency.');
            end
            device = obj.rig.getDevice(obj.led);
            maxima = obj.lightMeans(:) * (1 + max(obj.sinusoidContrasts(:)));
            if strcmp(device.background.displayUnits, symphonyui.core.Measurement.NORMALIZED) && ...
                    any(maxima > 1)
                error('A lightMean/contrast combination exceeds normalized LED output 1.');
            elseif any(maxima > 10.239)
                error('A lightMean/contrast combination exceeds LED output 10.239.');
            end
        end

    end
end

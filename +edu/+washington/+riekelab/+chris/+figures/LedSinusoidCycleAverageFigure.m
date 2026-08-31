classdef LedSinusoidCycleAverageFigure < symphonyui.core.FigureHandler
    % Baseline-subtracted cycle averages for full-field LED sinusoids.

    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
        lightMeans
    end

    properties (Access = private)
        axesHandles
        conditionData
        lineHandles
    end

    methods

        function obj = LedSinusoidCycleAverageFigure(ampDevice, varargin)
            ip = inputParser();
            ip.addParameter('recordingType', 'extracellular', @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isnumeric(x) && isscalar(x));
            ip.addParameter('stimTime', [], @(x)isnumeric(x) && isscalar(x));
            ip.addParameter('lightMeans', [], @isnumeric);
            ip.parse(varargin{:});
            obj.ampDevice = ampDevice;
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.lightMeans = ip.Results.lightMeans(:)';
            obj.conditionData = containers.Map();
            obj.lineHandles = containers.Map();
            obj.createUi();
        end

        function createUi(obj)
            n = numel(obj.lightMeans);
            obj.axesHandles = gobjects(1, n);
            for i = 1:n
                obj.axesHandles(i) = subplot(n, 1, i, 'Parent', obj.figureHandle);
                hold(obj.axesHandles(i), 'on');
                xlabel(obj.axesHandles(i), 'sinusoid phase (degrees)');
                ylabel(obj.axesHandles(i), obj.responseUnits());
                title(obj.axesHandles(i), sprintf('LED mean = %g', obj.lightMeans(i)));
                xlim(obj.axesHandles(i), [0 360]);
            end
            set(obj.figureHandle, 'Name', 'LED sinusoid cycle averages');
        end

        function clear(obj)
            for i = 1:numel(obj.axesHandles)
                cla(obj.axesHandles(i));
                hold(obj.axesHandles(i), 'on');
                xlim(obj.axesHandles(i), [0 360]);
            end
            obj.conditionData = containers.Map();
            obj.lineHandles = containers.Map();
        end

        function handleEpoch(obj, epoch)
            response = epoch.getResponse(obj.ampDevice);
            trace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            lightMean = double(epoch.parameters('currentLightMean'));
            contrast = double(epoch.parameters('currentSinusoidContrast'));
            frequency = double(epoch.parameters('currentTemporalFrequency'));

            [cycle, phase] = obj.epochCycleAverage( ...
                trace, sampleRate, obj.preTime, obj.stimTime, frequency, ...
                obj.recordingType);
            if isempty(cycle)
                warning('Stimulus contains no complete sinusoid cycle; skipping epoch.');
                return;
            end

            key = obj.conditionKey(lightMean, contrast, frequency);
            if isKey(obj.conditionData, key)
                datum = obj.conditionData(key);
                datum.meanCycle = (datum.meanCycle * datum.count + cycle) / (datum.count + 1);
                datum.count = datum.count + 1;
            else
                datum.meanCycle = cycle;
                datum.count = 1;
                datum.lightMean = lightMean;
                datum.contrast = contrast;
                datum.frequency = frequency;
            end
            obj.conditionData(key) = datum;
            obj.redrawCondition(key, phase);
        end

    end

    methods (Access = private)

        function redrawCondition(obj, key, phase)
            datum = obj.conditionData(key);
            meanIndex = find(abs(obj.lightMeans - datum.lightMean) < 1e-12, 1);
            if isempty(meanIndex)
                return;
            end
            modulation = max(datum.meanCycle) - min(datum.meanCycle);
            label = sprintf('C=%g, f=%g Hz, p-p=%g (n=%d)', ...
                datum.contrast, datum.frequency, modulation, datum.count);
            if isKey(obj.lineHandles, key)
                h = obj.lineHandles(key);
                set(h, 'YData', datum.meanCycle, 'DisplayName', label);
            else
                h = line(phase, datum.meanCycle, ...
                    'Parent', obj.axesHandles(meanIndex), ...
                    'LineWidth', 1.25, 'DisplayName', label);
                obj.lineHandles(key) = h;
            end
            legend(obj.axesHandles(meanIndex), 'show', 'Location', 'best');
        end

        function units = responseUnits(obj)
            if strcmp(obj.recordingType, 'extracellular')
                units = 'baseline-subtracted spike rate (Hz)';
            else
                units = 'baseline-subtracted response';
            end
        end

    end

    methods (Static)

        function [cycle, phase] = epochCycleAverage(trace, sampleRate, ...
                preTime, stimTime, frequency, recordingType)
            trace = double(trace(:)');
            prePts = min(round(preTime / 1000 * sampleRate), numel(trace));
            stimPts = round(stimTime / 1000 * sampleRate);
            firstStim = prePts + 1;
            lastStim = min(prePts + stimPts, numel(trace));
            if prePts < 1 || lastStim < firstStim || frequency <= 0
                cycle = [];
                phase = [];
                return;
            end

            if strcmp(recordingType, 'extracellular')
                detected = edu.washington.riekelab.chris.utils.spikeDetectorOnline( ...
                    trace, [], sampleRate);
                binary = zeros(size(trace));
                binary(detected.sp) = 1;
                sigmaPts = max(round(0.01 * sampleRate), 1);
                kernelX = -5*sigmaPts:5*sigmaPts;
                kernel = exp(-0.5 * (kernelX / sigmaPts).^2);
                kernel = kernel / sum(kernel);
                signal = sampleRate * conv(binary, kernel, 'same');
            else
                signal = trace;
                if strcmp(recordingType, 'exc')
                    signal = -signal;
                end
            end
            signal = signal - mean(signal(1:prePts));
            stimulus = signal(firstStim:lastStim);

            pointsPerCycle = sampleRate / frequency;
            numberOfCycles = floor(numel(stimulus) / pointsPerCycle);
            if numberOfCycles < 1
                cycle = [];
                phase = [];
                return;
            end
            phase = (0:199) / 200 * 360;
            cycles = zeros(numberOfCycles, numel(phase));
            for i = 1:numberOfCycles
                cycleStart = (i - 1) * pointsPerCycle;
                samplePositions = cycleStart + (0:numel(phase)-1) / numel(phase) * pointsPerCycle;
                cycles(i, :) = interp1(0:numel(stimulus)-1, stimulus, ...
                    samplePositions, 'linear');
            end
            cycle = mean(cycles, 1);
        end

    end

    methods (Static, Access = private)

        function key = conditionKey(lightMean, contrast, frequency)
            key = sprintf('m%.12g_c%.12g_f%.12g', lightMean, contrast, frequency);
        end

    end
end

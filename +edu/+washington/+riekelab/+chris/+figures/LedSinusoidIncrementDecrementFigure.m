classdef LedSinusoidIncrementDecrementFigure < symphonyui.core.FigureHandler
    % Excitatory cycle averages and increment/decrement inward-current ratio.

    properties (SetAccess = private)
        ampDevice
        preTime
        stimTime
        lightMeans
        sinusoidContrasts
        temporalFrequencies
    end

    properties (Access = private)
        cycleAxes
        ratioAxes
        conditionData
        cycleLines
        ratioLines
        contrastColors
    end

    methods

        function obj = LedSinusoidIncrementDecrementFigure(ampDevice, varargin)
            ip = inputParser();
            ip.addParameter('preTime', [], @(x)isnumeric(x) && isscalar(x));
            ip.addParameter('stimTime', [], @(x)isnumeric(x) && isscalar(x));
            ip.addParameter('lightMeans', [], @isnumeric);
            ip.addParameter('sinusoidContrasts', [], @isnumeric);
            ip.addParameter('temporalFrequencies', [], @isnumeric);
            ip.parse(varargin{:});
            obj.ampDevice = ampDevice;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.lightMeans = ip.Results.lightMeans(:)';
            obj.sinusoidContrasts = ip.Results.sinusoidContrasts(:)';
            obj.temporalFrequencies = ip.Results.temporalFrequencies(:)';
            obj.conditionData = containers.Map();
            obj.cycleLines = containers.Map();
            obj.ratioLines = containers.Map();
            obj.contrastColors = obj.makeColors(numel(obj.sinusoidContrasts));
            obj.createUi();
        end

        function createUi(obj)
            n = numel(obj.lightMeans);
            obj.cycleAxes = gobjects(1, n);
            obj.ratioAxes = gobjects(1, n);
            for i = 1:n
                obj.cycleAxes(i) = subplot(2, n, i, 'Parent', obj.figureHandle);
                hold(obj.cycleAxes(i), 'on');
                xlabel(obj.cycleAxes(i), 'sinusoid phase (degrees)');
                ylabel(obj.cycleAxes(i), 'excitatory current (-pA)');
                title(obj.cycleAxes(i), sprintf('mean = %g: cycle average', obj.lightMeans(i)));
                xlim(obj.cycleAxes(i), [0 360]);

                obj.ratioAxes(i) = subplot(2, n, n + i, 'Parent', obj.figureHandle);
                hold(obj.ratioAxes(i), 'on');
                xlabel(obj.ratioAxes(i), 'increment / decrement inward amplitude');
                ylabel(obj.ratioAxes(i), 'sinusoid contrast');
                title(obj.ratioAxes(i), sprintf('mean = %g: inc/dec ratio', obj.lightMeans(i)));
            end
            set(obj.figureHandle, 'Name', 'LED sinusoid increment/decrement analysis');
        end

        function clear(obj)
            for i = 1:numel(obj.lightMeans)
                cla(obj.cycleAxes(i));
                hold(obj.cycleAxes(i), 'on');
                xlim(obj.cycleAxes(i), [0 360]);
                cla(obj.ratioAxes(i));
                hold(obj.ratioAxes(i), 'on');
            end
            obj.conditionData = containers.Map();
            obj.cycleLines = containers.Map();
            obj.ratioLines = containers.Map();
        end

        function handleEpoch(obj, epoch)
            response = epoch.getResponse(obj.ampDevice);
            trace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            lightMean = double(epoch.parameters('currentLightMean'));
            contrast = double(epoch.parameters('currentSinusoidContrast'));
            frequency = double(epoch.parameters('currentTemporalFrequency'));

            % The shared routine subtracts the preTime baseline and flips exc
            % current, so inward current is positive in the plotted cycle.
            [cycle, phase] = ...
                edu.washington.riekelab.chris.figures.LedSinusoidCycleAverageFigure.epochCycleAverage( ...
                trace, sampleRate, obj.preTime, obj.stimTime, frequency, 'exc');
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
            obj.redraw(phase);
        end

    end

    methods (Access = private)

        function redraw(obj, phase)
            keys = obj.conditionData.keys();
            for k = 1:numel(keys)
                key = keys{k};
                datum = obj.conditionData(key);
                meanIndex = find(abs(obj.lightMeans - datum.lightMean) < 1e-12, 1);
                contrastIndex = find(abs(obj.sinusoidContrasts - datum.contrast) < 1e-12, 1);
                if isempty(meanIndex) || isempty(contrastIndex)
                    continue;
                end
                color = obj.contrastColors(contrastIndex, :);
                style = obj.frequencyLineStyle(datum.frequency);
                label = sprintf('C=%g, f=%g Hz (n=%d)', ...
                    datum.contrast, datum.frequency, datum.count);
                if isKey(obj.cycleLines, key)
                    set(obj.cycleLines(key), 'YData', datum.meanCycle, ...
                        'DisplayName', label);
                else
                    obj.cycleLines(key) = line(phase, datum.meanCycle, ...
                        'Parent', obj.cycleAxes(meanIndex), 'Color', color, ...
                        'LineStyle', style, 'LineWidth', 1.25, ...
                        'DisplayName', label);
                end
            end

            for meanIndex = 1:numel(obj.lightMeans)
                for frequencyIndex = 1:numel(obj.temporalFrequencies)
                    frequency = obj.temporalFrequencies(frequencyIndex);
                    ratios = nan(size(obj.sinusoidContrasts));
                    for contrastIndex = 1:numel(obj.sinusoidContrasts)
                        key = obj.conditionKey(obj.lightMeans(meanIndex), ...
                            obj.sinusoidContrasts(contrastIndex), frequency);
                        if isKey(obj.conditionData, key)
                            datum = obj.conditionData(key);
                            ratios(contrastIndex) = obj.inwardRatio(datum.meanCycle);
                        end
                    end
                    ratioKey = sprintf('m%.12g_f%.12g', ...
                        obj.lightMeans(meanIndex), frequency);
                    label = sprintf('%g Hz', frequency);
                    if isKey(obj.ratioLines, ratioKey)
                        set(obj.ratioLines(ratioKey), 'XData', ratios);
                    else
                        obj.ratioLines(ratioKey) = line(ratios, obj.sinusoidContrasts, ...
                            'Parent', obj.ratioAxes(meanIndex), ...
                            'Marker', 'o', 'LineStyle', obj.frequencyLineStyle(frequency), ...
                            'DisplayName', label);
                    end
                end
                legend(obj.cycleAxes(meanIndex), 'show', 'Location', 'best');
                legend(obj.ratioAxes(meanIndex), 'show', 'Location', 'best');
            end
        end

        function style = frequencyLineStyle(obj, frequency)
            styles = {'-', '--', ':', '-.'};
            index = find(abs(obj.temporalFrequencies - frequency) < 1e-12, 1);
            if isempty(index)
                index = 1;
            end
            style = styles{mod(index - 1, numel(styles)) + 1};
        end

    end

    methods (Static, Access = private)

        function ratio = inwardRatio(cycle)
            % The stimulus generator starts at the mean and then rises. The
            % first half-cycle is therefore the increment and the second is
            % the decrement. With exc sign-flipped, inward current is positive.
            halfway = floor(numel(cycle) / 2);
            incrementAmplitude = max([cycle(1:halfway), 0]);
            decrementAmplitude = max([cycle(halfway+1:end), 0]);
            if decrementAmplitude <= eps
                ratio = NaN;
            else
                ratio = incrementAmplitude / decrementAmplitude;
            end
        end

        function colors = makeColors(n)
            if n <= 1
                colors = [0 0 0];
            else
                colors = edu.washington.riekelab.chris.utils.pmkmp(n, 'CubicL');
            end
        end

        function key = conditionKey(lightMean, contrast, frequency)
            key = sprintf('m%.12g_c%.12g_f%.12g', lightMean, contrast, frequency);
        end

    end
end

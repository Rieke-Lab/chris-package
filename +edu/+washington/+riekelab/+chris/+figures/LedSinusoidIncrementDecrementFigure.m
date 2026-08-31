classdef LedSinusoidIncrementDecrementFigure < symphonyui.core.FigureHandler
    % Excitatory cycle averages and outward/inward current amplitude ratio.

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

            ip.addParameter('preTime', [], ...
                @(x)isnumeric(x) && isscalar(x));

            ip.addParameter('stimTime', [], ...
                @(x)isnumeric(x) && isscalar(x));

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

            obj.contrastColors = ...
                obj.makeColors(numel(obj.sinusoidContrasts));

            obj.createUi();
        end


        function createUi(obj)

            n = numel(obj.lightMeans);

            obj.cycleAxes = gobjects(1, n);
            obj.ratioAxes = gobjects(1, n);

            for i = 1:n

                % Cycle-average panel.
                obj.cycleAxes(i) = subplot( ...
                    2, n, i, ...
                    'Parent', obj.figureHandle);

                hold(obj.cycleAxes(i), 'on');

                xlabel(obj.cycleAxes(i), ...
                    'sinusoid phase (degrees)');

                ylabel(obj.cycleAxes(i), ...
                    'excitatory current (-pA)');

                title(obj.cycleAxes(i), ...
                    sprintf('mean = %g: cycle average', ...
                    obj.lightMeans(i)));

                xlim(obj.cycleAxes(i), [0 360]);


                % Outward/inward ratio panel.
                obj.ratioAxes(i) = subplot( ...
                    2, n, n + i, ...
                    'Parent', obj.figureHandle);

                hold(obj.ratioAxes(i), 'on');

                xlabel(obj.ratioAxes(i), ...
                    'outward / inward current amplitude');

                ylabel(obj.ratioAxes(i), ...
                    'sinusoid contrast');

                title(obj.ratioAxes(i), ...
                    sprintf('mean = %g: outward/inward ratio', ...
                    obj.lightMeans(i)));
            end

            set(obj.figureHandle, ...
                'Name', ...
                'LED sinusoid outward/inward analysis');
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

            sampleRate = ...
                response.sampleRate.quantityInBaseUnits;

            lightMean = ...
                double(epoch.parameters('currentLightMean'));

            contrast = ...
                double(epoch.parameters('currentSinusoidContrast'));

            frequency = ...
                double(epoch.parameters('currentTemporalFrequency'));


            % Shared routine:
            % 1) subtracts preTime baseline
            % 2) flips excitatory current
            %
            % Therefore:
            % inward current  -> positive
            % outward current -> negative
            [cycle, phase] = ...
                edu.washington.riekelab.chris.figures. ...
                LedSinusoidCycleAverageFigure.epochCycleAverage( ...
                trace, ...
                sampleRate, ...
                obj.preTime, ...
                obj.stimTime, ...
                frequency, ...
                'exc');

            if isempty(cycle)

                warning( ...
                    ['Stimulus contains no complete sinusoid cycle; ', ...
                    'skipping epoch.']);

                return;
            end


            key = obj.conditionKey( ...
                lightMean, ...
                contrast, ...
                frequency);


            if isKey(obj.conditionData, key)

                datum = obj.conditionData(key);

                datum.meanCycle = ...
                    (datum.meanCycle * datum.count + cycle) / ...
                    (datum.count + 1);

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

            % ============================================================
            % Update all cycle-average traces.
            % ============================================================
            keys = obj.conditionData.keys();

            for k = 1:numel(keys)

                key = keys{k};

                datum = obj.conditionData(key);

                meanIndex = find( ...
                    abs(obj.lightMeans - datum.lightMean) < 1e-12, ...
                    1);

                contrastIndex = find( ...
                    abs(obj.sinusoidContrasts - datum.contrast) < 1e-12, ...
                    1);


                if isempty(meanIndex) || isempty(contrastIndex)
                    continue;
                end


                color = ...
                    obj.contrastColors(contrastIndex, :);

                style = ...
                    obj.frequencyLineStyle(datum.frequency);

                label = sprintf( ...
                    'C=%g, f=%g Hz (n=%d)', ...
                    datum.contrast, ...
                    datum.frequency, ...
                    datum.count);


                if isKey(obj.cycleLines, key)

                    set(obj.cycleLines(key), ...
                        'YData', datum.meanCycle, ...
                        'DisplayName', label);

                else

                    obj.cycleLines(key) = line( ...
                        phase, ...
                        datum.meanCycle, ...
                        'Parent', obj.cycleAxes(meanIndex), ...
                        'Color', color, ...
                        'LineStyle', style, ...
                        'LineWidth', 1.25, ...
                        'DisplayName', label);
                end
            end


            % ============================================================
            % Update outward/inward ratio panels.
            % ============================================================
            for meanIndex = 1:numel(obj.lightMeans)

                for frequencyIndex = 1:numel(obj.temporalFrequencies)

                    frequency = ...
                        obj.temporalFrequencies(frequencyIndex);

                    ratios = ...
                        nan(size(obj.sinusoidContrasts));


                    for contrastIndex = 1:numel(obj.sinusoidContrasts)

                        key = obj.conditionKey( ...
                            obj.lightMeans(meanIndex), ...
                            obj.sinusoidContrasts(contrastIndex), ...
                            frequency);


                        if isKey(obj.conditionData, key)

                            datum = ...
                                obj.conditionData(key);

                            ratios(contrastIndex) = ...
                                obj.outwardInwardRatio( ...
                                datum.meanCycle);
                        end
                    end


                    ratioKey = sprintf( ...
                        'm%.12g_f%.12g', ...
                        obj.lightMeans(meanIndex), ...
                        frequency);

                    label = sprintf('%g Hz', frequency);


                    if isKey(obj.ratioLines, ratioKey)

                        set(obj.ratioLines(ratioKey), ...
                            'XData', ratios, ...
                            'YData', obj.sinusoidContrasts, ...
                            'DisplayName', label);

                    else

                        obj.ratioLines(ratioKey) = line( ...
                            ratios, ...
                            obj.sinusoidContrasts, ...
                            'Parent', obj.ratioAxes(meanIndex), ...
                            'Marker', 'o', ...
                            'LineStyle', ...
                            obj.frequencyLineStyle(frequency), ...
                            'DisplayName', label);
                    end
                end


                % ========================================================
                % Explicitly rebuild cycle-average legend.
                % ========================================================
                legendHandles = gobjects(0);
                legendLabels = {};


                for contrastIndex = 1:numel(obj.sinusoidContrasts)

                    for frequencyIndex = ...
                            1:numel(obj.temporalFrequencies)

                        key = obj.conditionKey( ...
                            obj.lightMeans(meanIndex), ...
                            obj.sinusoidContrasts(contrastIndex), ...
                            obj.temporalFrequencies(frequencyIndex));


                        if isKey(obj.cycleLines, key)

                            h = obj.cycleLines(key);

                            legendHandles(end + 1) = h;

                            legendLabels{end + 1} = ...
                                get(h, 'DisplayName');
                        end
                    end
                end


                if ~isempty(legendHandles)

                    legend( ...
                        obj.cycleAxes(meanIndex), ...
                        legendHandles, ...
                        legendLabels, ...
                        'Location', 'best');
                end


                % ========================================================
                % Explicitly rebuild ratio legend.
                % Each ratio curve corresponds to one temporal frequency.
                % ========================================================
                ratioLegendHandles = gobjects(0);
                ratioLegendLabels = {};


                for frequencyIndex = ...
                        1:numel(obj.temporalFrequencies)

                    frequency = ...
                        obj.temporalFrequencies(frequencyIndex);

                    ratioKey = sprintf( ...
                        'm%.12g_f%.12g', ...
                        obj.lightMeans(meanIndex), ...
                        frequency);


                    if isKey(obj.ratioLines, ratioKey)

                        h = obj.ratioLines(ratioKey);

                        ratioLegendHandles(end + 1) = h;

                        ratioLegendLabels{end + 1} = ...
                            get(h, 'DisplayName');
                    end
                end


                if ~isempty(ratioLegendHandles)

                    legend( ...
                        obj.ratioAxes(meanIndex), ...
                        ratioLegendHandles, ...
                        ratioLegendLabels, ...
                        'Location', 'best');
                end

            end
        end


        function style = frequencyLineStyle(obj, frequency)

            styles = {'-', '--', ':', '-.'};

            index = find( ...
                abs(obj.temporalFrequencies - frequency) < 1e-12, ...
                1);

            if isempty(index)
                index = 1;
            end

            style = ...
                styles{mod(index - 1, numel(styles)) + 1};
        end

    end


    methods (Static, Access = private)

        function ratio = outwardInwardRatio(cycle)

            % The cycle has already been baseline-subtracted and
            % excitatory current has been sign-flipped.
            %
            % Therefore:
            %   inward current  = positive deflection
            %   outward current = negative deflection
            %
            % We measure peak amplitudes relative to zero baseline,
            % independent of stimulus phase.

            inwardAmplitude = max(cycle);

            outwardAmplitude = abs(min(cycle));


            if inwardAmplitude <= eps

                ratio = NaN;

            else

                ratio = ...
                    outwardAmplitude / inwardAmplitude;
            end
        end


        function colors = makeColors(n)

            if n <= 1

                colors = [0 0 0];

            else

                colors = ...
                    edu.washington.riekelab.chris.utils. ...
                    pmkmp(n, 'CubicL');
            end
        end


        function key = conditionKey( ...
                lightMean, ...
                contrast, ...
                frequency)

            key = sprintf( ...
                'm%.12g_c%.12g_f%.12g', ...
                lightMean, ...
                contrast, ...
                frequency);
        end

    end

end
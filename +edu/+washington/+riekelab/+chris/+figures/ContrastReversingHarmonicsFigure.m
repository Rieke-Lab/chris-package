classdef ContrastReversingHarmonicsFigure < symphonyui.core.FigureHandler
    % Online F1/F2 against negative (dark-bar) contrast.
    %
    % One point per dark contrast, one line per (bar width, temporal
    % frequency) group, with F1 solid and F2 dashed in the group's colour.
    % F2 is the quantity of interest for a contrast-reversing grating: a
    % linear receptive field integrates the two bars to nothing and answers
    % at the reversal rate only through its nonlinear subunits, which
    % respond to both phases and so at twice the frequency.
    %
    % Mirrors the offline analysis in analyzeCenterContrastReversingGrating
    % (retinanalysis.SCutils.protocols.spot_annular_crg) so the two can be
    % compared: the amplitudes are a direct sine/cosine projection of the
    % mean-subtracted stimulus window rather than an FFT bin, which does not
    % need the window to hold a whole number of cycles, and the window is
    % the stimulus shifted by a response latency.
    %
    % Recording types:
    %   'extracellular' - spikes detected online, binned and smoothed to a
    %                     firing rate in Hz.
    %   'exc' / 'inh'   - baseline-subtracted current, sign-flipped for exc
    %                     so an inward (excitatory) current reads positive.
    % Anything else is treated as a raw trace.

    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
        latencyMs
        psthSigmaMs
        smoothMs
    end

    properties (Access = private)
        axesHandle
        legendHandle
        epochDark          % dark contrast per epoch
        epochBar           % bar width per epoch
        epochFreq          % temporal frequency per epoch
        epochF1
        epochF2
        lineHandles        % containers.Map from group key -> [f1Line f2Line]
        groupColors
    end

    methods

        function obj = ContrastReversingHarmonicsFigure(ampDevice, varargin)
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            % 30 ms of spike latency, and 10 ms for the whole-cell trace, are
            % the offline defaults (300 and 100 samples at 10 kHz) written as
            % times so they do not change meaning with the amplifier rate.
            ip.addParameter('latencyMs', [], @(x)isnumeric(x));
            ip.addParameter('psthSigmaMs', 10, @(x)isnumeric(x));
            ip.addParameter('smoothMs', 5, @(x)isnumeric(x));
            ip.parse(varargin{:});

            obj.ampDevice = ampDevice;
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.psthSigmaMs = ip.Results.psthSigmaMs;
            obj.smoothMs = ip.Results.smoothMs;
            if isempty(ip.Results.latencyMs)
                if strcmp(obj.recordingType, 'extracellular')
                    obj.latencyMs = 30;
                else
                    obj.latencyMs = 10;
                end
            else
                obj.latencyMs = ip.Results.latencyMs;
            end

            obj.epochDark = [];
            obj.epochBar = [];
            obj.epochFreq = [];
            obj.epochF1 = [];
            obj.epochF2 = [];
            obj.lineHandles = containers.Map();

            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            clearButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Clear harmonics', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedClear);
            try
                iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+utils\+icons\'];
                setIconImage(clearButton, [iconDir, 'Xout.png']);
            catch
                % An icon is decoration; never let a missing file stop the rig.
            end

            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'negative (dark bar) contrast');
            ylabel(obj.axesHandle, obj.responseUnits());
            title(obj.axesHandle, 'F1 (solid) and F2 (dashed) vs negative contrast');
            set(obj.figureHandle, 'Name', 'Contrast-reversing harmonics');
            hold(obj.axesHandle, 'on');
        end

        function clear(obj)
            cla(obj.axesHandle);
            obj.epochDark = [];
            obj.epochBar = [];
            obj.epochFreq = [];
            obj.epochF1 = [];
            obj.epochF2 = [];
            obj.lineHandles = containers.Map();
            obj.legendHandle = [];
        end

        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.ampDevice)
                error(['Epoch does not contain a response for ' obj.ampDevice.name]);
            end
            response = epoch.getResponse(obj.ampDevice);
            trace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;

            darkContrast = obj.epochParameter(epoch, 'currentDarkContrast', NaN);
            % Defaults to 0 rather than NaN: grouping compares bar widths with
            % ==, and NaN is equal to nothing, so a missing bar width would put
            % every epoch in its own single-point group.
            barWidth = obj.epochParameter(epoch, 'currentBarWidth', 0);
            frequency = obj.epochParameter(epoch, 'currentTemporalFrequency', NaN);
            if ~isfinite(frequency) || frequency <= 0
                warning('No usable currentTemporalFrequency on this epoch; skipping.');
                return;
            end

            [signal, signalRate] = obj.responseSignal(trace, sampleRate);

            % Window the stimulus, shifted by the response latency. Computed on
            % the signal's own rate, which is 1 kHz for the spike PSTH and the
            % amplifier rate otherwise.
            lo = round((obj.preTime + obj.latencyMs) / 1000 * signalRate) + 1;
            hi = round((obj.preTime + obj.stimTime + obj.latencyMs) / 1000 * signalRate);
            lo = max(lo, 1);
            hi = min(hi, numel(signal));
            if hi <= lo
                warning('Stimulus window is empty; skipping this epoch.');
                return;
            end
            window = signal(lo:hi);

            [f1, f2] = obj.harmonicAmplitudes(window, signalRate, frequency);

            obj.epochDark(end+1, 1) = darkContrast;
            obj.epochBar(end+1, 1) = barWidth;
            obj.epochFreq(end+1, 1) = frequency;
            obj.epochF1(end+1, 1) = f1;
            obj.epochF2(end+1, 1) = f2;

            obj.redraw();
        end

    end

    methods (Access = private)

        function units = responseUnits(obj)
            switch obj.recordingType
                case 'extracellular'
                    units = 'spike rate amplitude (Hz)';
                case 'exc'
                    units = 'excitatory current amplitude (pA)';
                case 'inh'
                    units = 'inhibitory current amplitude (pA)';
                otherwise
                    units = 'response amplitude';
            end
        end

        function [signal, signalRate] = responseSignal(obj, trace, sampleRate)
            % Turn the amplifier trace into the quantity the harmonics are
            % measured on, matching the offline analysis per recording type.
            trace = trace(:)';
            if strcmp(obj.recordingType, 'extracellular')
                res = edu.washington.riekelab.chris.utils.spikeDetectorOnline( ...
                    trace, [], sampleRate);
                binary = zeros(size(trace));
                binary(res.sp) = 1;
                % Firing rate in Hz, Gaussian-smoothed on the amplifier's own
                % clock, then decimated to 1 kHz to match the offline PSTH.
                sigmaPts = (obj.psthSigmaMs / 1000) * sampleRate;
                kernel = normpdf(1:ceil(10*sigmaPts), ceil(10*sigmaPts)/2, sigmaPts);
                kernel = kernel / sum(kernel);
                rate = sampleRate * conv(binary, kernel, 'same');
                signalRate = 1000;
                step = sampleRate / signalRate;
                if step >= 1 && abs(step - round(step)) < 1e-9
                    signal = rate(1:round(step):end);
                else
                    signal = rate;
                    signalRate = sampleRate;
                end
            else
                prePts = round(obj.preTime / 1000 * sampleRate);
                prePts = max(min(prePts, numel(trace)), 1);
                signal = trace - mean(trace(1:prePts));
                width = max(round(obj.smoothMs / 1000 * sampleRate), 1);
                signal = conv(signal, ones(1, width) / width, 'same');
                if strcmp(obj.recordingType, 'exc')
                    % Excitation is an inward (negative) current; flip it so a
                    % larger response is a larger positive number.
                    signal = -signal;
                end
                signalRate = sampleRate;
            end
        end

        function redraw(obj)
            groups = unique([obj.epochBar, obj.epochFreq], 'rows');
            obj.assignGroupColors(groups);
            for g = 1:size(groups, 1)
                barWidth = groups(g, 1);
                frequency = groups(g, 2);
                inGroup = obj.epochBar == barWidth & obj.epochFreq == frequency;
                contrasts = unique(obj.epochDark(inGroup));
                meanF1 = zeros(size(contrasts));
                meanF2 = zeros(size(contrasts));
                for c = 1:numel(contrasts)
                    pick = inGroup & obj.epochDark == contrasts(c);
                    meanF1(c) = mean(obj.epochF1(pick));
                    meanF2(c) = mean(obj.epochF2(pick));
                end
                key = obj.groupKey(barWidth, frequency);
                color = obj.groupColors(key);
                if isKey(obj.lineHandles, key)
                    handles = obj.lineHandles(key);
                    set(handles(1), 'XData', contrasts, 'YData', meanF1);
                    set(handles(2), 'XData', contrasts, 'YData', meanF2);
                else
                    f1Line = line(contrasts, meanF1, 'Parent', obj.axesHandle, ...
                        'Color', color, 'Marker', 'o', 'LineStyle', '-', ...
                        'DisplayName', sprintf('F1  %gum %gHz', barWidth, frequency));
                    f2Line = line(contrasts, meanF2, 'Parent', obj.axesHandle, ...
                        'Color', color, 'Marker', 's', 'LineStyle', '--', ...
                        'DisplayName', sprintf('F2  %gum %gHz', barWidth, frequency));
                    obj.lineHandles(key) = [f1Line f2Line];
                end
            end
            ylabel(obj.axesHandle, obj.responseUnits());
            try
                obj.legendHandle = legend(obj.axesHandle, 'show');
                set(obj.legendHandle, 'Location', 'best', 'Box', 'off', ...
                    'FontSize', 7);
            catch
                % A legend is decoration; never let it stop the rig.
            end
        end

        function assignGroupColors(obj, groups)
            % Colour by group, built once over every group seen so far so a
            % given (bar width, frequency) keeps its colour as groups arrive.
            n = size(groups, 1);
            if n > 1
                palette = edu.washington.riekelab.chris.utils.pmkmp(n, 'CubicL');
            else
                palette = [0 0 0];
            end
            obj.groupColors = containers.Map();
            for g = 1:n
                obj.groupColors(obj.groupKey(groups(g, 1), groups(g, 2))) = ...
                    palette(g, :);
            end
            % Groups already drawn keep their line handles but take the new
            % colour, so the mapping stays consistent after a group appears.
            keys = obj.lineHandles.keys();
            for k = 1:numel(keys)
                if isKey(obj.groupColors, keys{k})
                    handles = obj.lineHandles(keys{k});
                    set(handles(1), 'Color', obj.groupColors(keys{k}));
                    set(handles(2), 'Color', obj.groupColors(keys{k}));
                end
            end
        end

        function onSelectedClear(obj, ~, ~)
            obj.clear();
        end

    end

    methods (Static)

        function [f1, f2] = harmonicAmplitudes(trace, sampleRate, frequency)
            % Amplitude at the reversal frequency and at twice it, by direct
            % projection onto sine and cosine. Equivalent to the DFT bins when
            % the window holds a whole number of cycles, but correct when it
            % does not, which is why the offline analysis uses it too.
            trace = double(trace(:))';
            if isempty(trace)
                f1 = NaN; f2 = NaN;
                return;
            end
            t = (0:numel(trace)-1) / sampleRate;
            centred = trace - mean(trace);
            out = zeros(1, 2);
            frequencies = [frequency, 2*frequency];
            for i = 1:2
                c = mean(centred .* cos(2*pi*frequencies(i)*t));
                s = mean(centred .* sin(2*pi*frequencies(i)*t));
                out(i) = 2 * hypot(c, s);
            end
            f1 = out(1);
            f2 = out(2);
        end

    end

    methods (Static, Access = private)

        function key = groupKey(barWidth, frequency)
            key = sprintf('bw%g_tf%g', barWidth, frequency);
        end

        function value = epochParameter(epoch, name, default)
            p = epoch.parameters;
            if isKey(p, name)
                value = double(p(name));
            else
                value = default;
            end
        end

    end

end

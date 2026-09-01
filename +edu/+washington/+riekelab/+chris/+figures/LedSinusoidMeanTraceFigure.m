classdef LedSinusoidMeanTraceFigure < symphonyui.core.FigureHandler
    % Mean baseline-subtracted excitatory traces, separated by LED mean.
    
    properties (SetAccess = private)
        ampDevice
        preTime
        lightMeans
        sinusoidContrasts
        temporalFrequencies
        stimulusLabel
    end
    
    properties (Access = private)
        axesHandles
        conditionData
        lineHandles
        contrastColors
    end
    
    methods
        
        function obj = LedSinusoidMeanTraceFigure(ampDevice, varargin)
            ip = inputParser();
            ip.addParameter('preTime', [], @(x)isnumeric(x) && isscalar(x));
            ip.addParameter('lightMeans', [], @isnumeric);
            ip.addParameter('sinusoidContrasts', [], @isnumeric);
            ip.addParameter('temporalFrequencies', [], @isnumeric);
            ip.addParameter('stimulusLabel', 'LED', ...
                @(x)ischar(x) || (isstring(x) && isscalar(x)));
            ip.parse(varargin{:});
            obj.ampDevice = ampDevice;
            obj.preTime = ip.Results.preTime;
            obj.lightMeans = ip.Results.lightMeans(:)';
            obj.sinusoidContrasts = ip.Results.sinusoidContrasts(:)';
            obj.temporalFrequencies = ip.Results.temporalFrequencies(:)';
            obj.stimulusLabel = char(ip.Results.stimulusLabel);
            obj.conditionData = containers.Map();
            obj.lineHandles = containers.Map();
            obj.contrastColors = obj.makeColors(numel(obj.sinusoidContrasts));
            obj.createUi();
        end
        
        function createUi(obj)
            n = numel(obj.lightMeans);
            obj.axesHandles = gobjects(1, n);
            for i = 1:n
                obj.axesHandles(i) = subplot(n, 1, i, 'Parent', obj.figureHandle);
                hold(obj.axesHandles(i), 'on');
                xlabel(obj.axesHandles(i), 'time (s)');
                ylabel(obj.axesHandles(i), 'excitatory current (-pA)');
                title(obj.axesHandles(i), sprintf('%s mean = %g', ...
                    obj.stimulusLabel, obj.lightMeans(i)));
            end
            set(obj.figureHandle, 'Name', sprintf('%s sinusoid mean traces', ...
                obj.stimulusLabel));
        end
        
        function clear(obj)
            for i = 1:numel(obj.axesHandles)
                cla(obj.axesHandles(i));
                hold(obj.axesHandles(i), 'on');
            end
            obj.conditionData = containers.Map();
            obj.lineHandles = containers.Map();
        end
        
        function handleEpoch(obj, epoch)
            response = epoch.getResponse(obj.ampDevice);
            trace = double(response.getData());
            sampleRate = response.sampleRate.quantityInBaseUnits;
            lightMean = double(epoch.parameters('currentLightMean'));
            contrast = double(epoch.parameters('currentSinusoidContrast'));
            frequency = double(epoch.parameters('currentTemporalFrequency'));
            prePts = min(round(obj.preTime / 1000 * sampleRate), numel(trace));
            if prePts < 1
                warning('No preTime samples are available; skipping epoch.');
                return;
            end
            
            % Subtract the pre-stimulus baseline and flip excitation so inward
            % current is plotted upward.
            trace = -(trace - mean(trace(1:prePts)));
            key = obj.conditionKey(lightMean, contrast, frequency);
            if isKey(obj.conditionData, key)
                datum = obj.conditionData(key);
                if numel(datum.meanTrace) ~= numel(trace)
                    warning('Trace length changed within a condition; skipping epoch.');
                    return;
                end
                datum.meanTrace = (datum.meanTrace * datum.count + trace) / (datum.count + 1);
                datum.count = datum.count + 1;
            else
                datum.meanTrace = trace;
                datum.count = 1;
                datum.lightMean = lightMean;
                datum.contrast = contrast;
                datum.frequency = frequency;
                datum.sampleRate = sampleRate;
            end
            obj.conditionData(key) = datum;
            obj.redrawCondition(key);
        end
        
    end
    
    methods (Access = private)
        
        function redrawCondition(obj, key)
            
            datum = obj.conditionData(key);
            
            meanIndex = find( ...
                abs(obj.lightMeans - datum.lightMean) < 1e-12, 1);
            
            contrastIndex = find( ...
                abs(obj.sinusoidContrasts - datum.contrast) < 1e-12, 1);
            
            if isempty(meanIndex) || isempty(contrastIndex)
                return;
            end
            
            x = (0:numel(datum.meanTrace)-1) / datum.sampleRate;
            
            label = sprintf( ...
                'C=%g, f=%g Hz (n=%d)', ...
                datum.contrast, ...
                datum.frequency, ...
                datum.count);
            
            if isKey(obj.lineHandles, key)
                
                set(obj.lineHandles(key), ...
                    'YData', datum.meanTrace, ...
                    'DisplayName', label);
                
            else
                
                obj.lineHandles(key) = line( ...
                    x, datum.meanTrace, ...
                    'Parent', obj.axesHandles(meanIndex), ...
                    'Color', obj.contrastColors(contrastIndex, :), ...
                    'LineStyle', obj.frequencyLineStyle(datum.frequency), ...
                    'LineWidth', 1.25, ...
                    'DisplayName', label);
            end
            
            % Explicitly rebuild legend so newly added contrasts appear.
            legendHandles = gobjects(0);
            legendLabels = {};
            
            for contrastIndex = 1:numel(obj.sinusoidContrasts)
                
                for frequencyIndex = 1:numel(obj.temporalFrequencies)
                    
                    conditionKey = obj.conditionKey( ...
                        obj.lightMeans(meanIndex), ...
                        obj.sinusoidContrasts(contrastIndex), ...
                        obj.temporalFrequencies(frequencyIndex));
                    
                    if isKey(obj.lineHandles, conditionKey)
                        
                        h = obj.lineHandles(conditionKey);
                        
                        legendHandles(end+1) = h;
                        legendLabels{end+1} = get(h, 'DisplayName');
                    end
                end
            end
            
            if ~isempty(legendHandles)
                legend( ...
                    obj.axesHandles(meanIndex), ...
                    legendHandles, ...
                    legendLabels, ...
                    'Location', 'best');
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

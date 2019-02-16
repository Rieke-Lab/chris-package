classdef DualResponseStatisticsFigure < symphonyui.core.FigureHandler
    % Plots statistics calculated from the response of two specified devices for each epoch run.
    
    properties (SetAccess = private)
        device1
        measurementCallbacks1
        measurementRegion1
        baselineRegion1
        
        device2
        measurementCallbacks2
        measurementRegion2
        baselineRegion2
    end
    
    properties (Access = private)
        axesHandles1
        markers1
        
        axesHandles2
        markers2
    end
    
    methods
        
        function obj = DualResponseStatisticsFigure(device1, measurementCallbacks1, device2, measurementCallbacks2, varargin)
            if ~iscell(measurementCallbacks1)
                measurementCallbacks1 = {measurementCallbacks1};
            end
            if ~iscell(measurementCallbacks2)
                measurementCallbacks2 = {measurementCallbacks2};
            end
            
            ip = inputParser();
            ip.addParameter('measurementRegion1', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('baselineRegion1', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('measurementRegion2', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('baselineRegion2', [], @(x)isnumeric(x) || isvector(x));
            ip.parse(varargin{:});
            
            obj.device1 = device1;
            obj.measurementCallbacks1 = measurementCallbacks1;
            obj.measurementRegion1 = ip.Results.measurementRegion1;
            obj.baselineRegion1 = ip.Results.baselineRegion1;
            
            obj.device2 = device2;
            obj.measurementCallbacks2 = measurementCallbacks2;
            obj.measurementRegion2 = ip.Results.measurementRegion2;
            obj.baselineRegion2 = ip.Results.baselineRegion2;
            
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            
            nPlots = numel(obj.measurementCallbacks1) + numel(obj.measurementCallbacks2);
            
            for i = 1:numel(obj.measurementCallbacks1)
                obj.axesHandles1(i) = subplot(nPlots, 1, i, ...
                    'Parent', obj.figureHandle, ...
                    'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'), ...
                    'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto', ...
                    'XColor', 'none');
                ylabel(obj.axesHandles1(i), func2str(obj.measurementCallbacks1{i}));
            end
            set(obj.axesHandles1(end), 'XColor', get(groot, 'defaultAxesXColor'));
            xlabel(obj.axesHandles1(end), 'epoch');
            title(obj.axesHandles1(1), [obj.device1.name ' Response Statistics']);
            
            for i = 1:numel(obj.measurementCallbacks2)
                obj.axesHandles2(i) = subplot(nPlots, 1, i + numel(obj.measurementCallbacks1), ...
                    'Parent', obj.figureHandle, ...
                    'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'), ...
                    'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto', ...
                    'XColor', 'none');
                ylabel(obj.axesHandles2(i), func2str(obj.measurementCallbacks2{i}));
            end
            set(obj.axesHandles2(end), 'XColor', get(groot, 'defaultAxesXColor'));
            xlabel(obj.axesHandles2(end), 'epoch');
            title(obj.axesHandles2(1), [obj.device2.name ' Response Statistics']);
            
            set(obj.figureHandle, 'Name', [obj.device1.name ' and ' obj.device2.name ' Response Statistics']);
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device1) || ~epoch.hasResponse(obj.device2)
                error(['Epoch does not contain a response for ' obj.device1.name ' or ' obj.device2.name]);
            end
            
            obj.markers1 = plotResponse(epoch.getResponse(obj.device1), obj.baselineRegion1, obj.measurementRegion1, ...
                obj.measurementCallbacks1, obj.axesHandles1, obj.markers1);
            obj.markers2 = plotResponse(epoch.getResponse(obj.device2), obj.baselineRegion2, obj.measurementRegion2, ...
                obj.measurementCallbacks2, obj.axesHandles2, obj.markers2);
            
            function markers = plotResponse(response, baselineRegion, measurementRegion, measurementCallbacks, axesHandles, markers)
                quantities = response.getData();
                rate = response.sampleRate.quantityInBaseUnits;

                msToPts = @(t)max(round(t / 1e3 * rate), 1);

                if ~isempty(baselineRegion)
                    x1 = msToPts(baselineRegion(1));
                    x2 = msToPts(baselineRegion(2));
                    baseline = quantities(x1:x2);
                    quantities = quantities - mean(baseline);
                end

                if ~isempty(measurementRegion)
                    x1 = msToPts(measurementRegion(1));
                    x2 = msToPts(measurementRegion(2));
                    quantities = quantities(x1:x2);
                end           

                for i = 1:numel(measurementCallbacks)
                    fcn = measurementCallbacks{i};
                    result = fcn(quantities);
                    if numel(markers) < i
                        colorOrder = get(groot, 'defaultAxesColorOrder');
                        color = colorOrder(mod(i - 1, size(colorOrder, 1)) + 1, :);
                        markers(i) = line(1, result, 'Parent', axesHandles(i), ...
                            'LineStyle', 'none', ...
                            'Marker', 'o', ...
                            'MarkerEdgeColor', color, ...
                            'MarkerFaceColor', color);
                    else
                        x = get(markers(i), 'XData');
                        y = get(markers(i), 'YData');
                        set(markers(i), 'XData', [x x(end)+1], 'YData', [y result]);
                    end
                end
            end
        end
        
    end
        
end
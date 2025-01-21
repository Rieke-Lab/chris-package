classdef IntensityTraceFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        frameMonitor
        stageDevice
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
    end
    
    methods
        
        function obj = IntensityTraceFigure(frameMonitor, stageDevice, varargin)
            obj.frameMonitor = frameMonitor;
            obj.stageDevice = stageDevice;
            
            ip = inputParser();
            ip.parse(varargin{:});
            
            obj.createUi();
        end
        
        function createUi(obj)
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'Frame Number');
            ylabel(obj.axesHandle, 'Intensity');
            title(obj.axesHandle, 'Intensity Over Frames');
        end
        
        function handleEpoch(obj, epoch)
            
            % Get intensity values from epoch parameters
            intensityValues = epoch.parameters('intensityOverFrame');
            frameNumbers = 1:length(intensityValues);
            
            if isempty(obj.lineHandle)
                obj.lineHandle = line(frameNumbers, intensityValues, ...
                    'Parent', obj.axesHandle, ...
                    'LineWidth', 1.5, ...
                    'Color', 'b');
            else
                set(obj.lineHandle, 'XData', frameNumbers, 'YData', intensityValues);
            end
            
            % Update axis limits to accommodate all data
            xlim(obj.axesHandle, [1 length(intensityValues)]);
            ylim(obj.axesHandle, [min(intensityValues)*0.9 max(intensityValues)*1.1]);
            
            % Add current mean intensity to title
            currentMean = epoch.parameters('currentMean');
            title(obj.axesHandle, sprintf('Intensity Over Frames (Mean: %.3f)', currentMean));
        end
        
    end
    
end
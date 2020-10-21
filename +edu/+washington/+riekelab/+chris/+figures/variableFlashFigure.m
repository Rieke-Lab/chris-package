classdef variableFlashFigure < symphonyui.core.FigureHandler
    properties (SetAccess = private)
        device
        barWidth
        variableFlashTimes
        psth
    end
    properties (Access = private)
        axesHandle
        lineHandle
        resp
    end
    methods
        function obj = variableFlashFigure(device, varargin)
            
            ip = inputParser();
            ip.addParameter('psth', false, @(x)islogical(x));
            ip.addParameter('barWidth', [], @(x)isvector(x));
            ip.addParameter('variableFlashTimes', [], @(x)isvector(x));
            ip.parse(varargin{:});
            
            obj.device = device;
            obj.psth = ip.Results.psth;
            obj.barWidth=ip.Results.barWidth;
            obj.variableFlashTimes=ip.Results.variableFlashTimes;
            
            for i=1:length(obj.barWidth)
                for k=1:length(obj.variableFlashTimes)
                    obj.resp.trace{i,k}=0;   % create the globle variable to store the mean response,
                    obj.resp.count(i,k)=0;
                end
            end
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
%             colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.colorstr),'CubicYF');
            colors=[0 0 0; 1 0 0; 0 0 1];
            for i=1:length(obj.barWidth)
                obj.axesHandle(i) = subplot(length(obj.barWidth),1,i, ...
                    'Parent', obj.figureHandle, ...
                    'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto');
                title(obj.axesHandle(i),strcat('barWidth ',' ', num2str(obj.barWidth(i))));
                xlabel(obj.axesHandle(i), 'Time (sec)');
                if obj.psth
                    ylabel(obj.axesHandle(i), 'spikeRate(Hz)');
                else
                    ylabel(obj.axesHandle(i), 'PSC(pA)');
                end

                for k=1:length(obj.variableFlashTimes)
                    obj.lineHandle(i,k)=line(0,0,'Parent', obj.axesHandle(i), ...,
                        'Color',colors(1,:),'marker','none','linestyle','-','linewidth',1.5);
                end
                % for each subplot, add legend, weel this is not a neat code                
            end
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
            currentDelay=epoch.parameters('currentFlashDelay');
            currentBarWidth=epoch.parameters('currentBarWidth');
            delayIndex=find(currentDelay== obj.variableFlashTimes);
            barIndex=find(currentBarWidth==obj.barWidth);
          
            
            %%%% sort each epoch accordingly
            
            
            %%%%%%%%%%%
            response = epoch.getResponse(obj.device);
            [epochResponseTrace,~] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            x = (1:numel(epochResponseTrace)) / sampleRate;
            y=epochResponseTrace;
            if obj.psth
                sigma = 10e-3 * sampleRate;
                filter = normpdf(1:10*sigma, 10*sigma/2, sigma);
                results = edu.washington.riekelab.util.spikeDetectorOnline(epochResponseTrace, [], sampleRate);
                y = zeros(size(epochResponseTrace));
                y(results.sp) = 1;
                y = sampleRate * conv(y, filter, 'same');
            end
            % downsample for plotting
            x=x(1:10:end); y=y(1:10:end);
            
            obj.resp.count(barIndex,delayIndex)=obj.resp.count(barIndex,delayIndex)+1;
            obj.resp.trace{barIndex,delayIndex}=obj.resp.trace{barIndex,delayIndex}+y;
            set(obj.lineHandle(barIndex,patternIndex,delayIndex),'XData',x,'YData', obj.resp.trace{barIndex,delayIndex}./ ...,
                obj.resp.count(barIndex,delayIndex));
        end
    end
end
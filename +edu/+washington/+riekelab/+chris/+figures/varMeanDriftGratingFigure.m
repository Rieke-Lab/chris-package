classdef varMeanDriftGratingFigure < symphonyui.core.FigureHandler
    properties (SetAccess = private)
        device
        barWidths
        meanIntensities
        onlineAnalysis
        colorstr
    end
    properties (Access = private)
        axesHandle
        lineHandle
        resp
    end
    methods
        function obj = varMeanDriftGratingFigure(device, varargin)
            
            ip = inputParser();
            ip.addParameter('barWidths', [], @(x)isvector(x));
            ip.addParameter('meanIntensities', [], @(x)isvector(x));
            ip.addParameter('coloredBy', [], @(x)isstring(x) || isvector(x));
            ip.addParameter('onlineAnalysis', false, @(x)ischar(x));

            ip.parse(varargin{:});
            
            obj.device = device;
            obj.onlineAnalysis = ip.Results.onlineAnalysis;
            obj.barWidths=ip.Results.barWidths;
            obj.meanIntensities=ip.Results.meanIntensities;
            obj.colorstr=ip.Results.coloredBy;
            if ~iscellstr(obj.colorstr)
                obj.colorstr=strsplit(num2str(obj.colorstr));
            end
            
            if ~iscellstr(obj.colorstr)
                obj.colorstr=strsplit(num2str(obj.colorstr));
            end
            for i=1:length(obj.barWidths)
                for j=1:length(obj.meanIntensities)
                    obj.resp.trace{i,j}=0;   % create the globle variable to store the mean response,
                    obj.resp.count(i,j)=0;
                end
                
            end
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.colorstr),'CubicYF');
            for i=1:length(obj.barWidths)
                obj.axesHandle(i) = subplot(length(obj.barWidths),1,i, ...
                    'Parent', obj.figureHandle, ...
                    'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto');
                title(obj.axesHandle(i),strcat('barWidth ',' ', num2str(obj.barWidths(i))));
                xlabel(obj.axesHandle(i), 'Time (sec)');
                if strcmp(obj.onlineAnalysis,'extracellular')
                    ylabel(obj.axesHandle(i), 'spikeRate(Hz)');
                else
                    ylabel(obj.axesHandle(i), 'PSC(pA)');
                end
                linesForLegends=[];
                for j=1:length(obj.meanIntensities)
                        obj.lineHandle(i,j)=line(0,0,'Parent', obj.axesHandle(i), ...,
                            'Color',colors(j,:),'marker','none','linestyle','-','linewidth',1.5);
                end
                % for each subplot, add legend, weel this is not a neat code
                legend(linesForLegends,obj.colorstr); legend boxoff;
                
            end
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
            currentMeanIntensity=epoch.parameters('currentMeanIntensity');
            currentBarWidth=epoch.parameters('currentBarWidth');
            lumIndex=find(currentMeanIntensity== obj.meanIntensities);
            barIndex=find(currentBarWidth==obj.barWidths);
            %%%%%%%%%%%
            response = epoch.getResponse(obj.device);
            [epochResponseTrace,~] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            x = (1:numel(epochResponseTrace)) / sampleRate;
            y=epochResponseTrace;
            if strcmp(obj.onlineAnalysis,'extracellular')
                sigma = 10e-3 * sampleRate;
                filter = normpdf(1:10*sigma, 10*sigma/2, sigma);
                results = edu.washington.riekelab.util.spikeDetectorOnline(epochResponseTrace, [], sampleRate);
                y = zeros(size(epochResponseTrace));
                y(results.sp) = 1;
                y = sampleRate * conv(y, filter, 'same');
            end
            % downsample for plotting
            x=x(1:10:end); y=y(1:10:end);
            
            obj.resp.count(barIndex,lumIndex)=obj.resp.count(barIndex,lumIndex)+1;
            obj.resp.trace{barIndex,lumIndex}=obj.resp.trace{barIndex,lumIndex}+y;
            set(obj.lineHandle(barIndex,lumIndex),'XData',x,'YData', obj.resp.trace{barIndex,lumIndex}./ ...,
                obj.resp.count(barIndex,lumIndex));
        end
    end
end

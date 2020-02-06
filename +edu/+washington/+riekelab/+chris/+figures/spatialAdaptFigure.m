classdef spatialAdaptFigure < symphonyui.core.FigureHandler
    properties (SetAccess = private)
        device
        barWidth
        variableFlashTimes
        psth
        colorstr
    end
    properties (Access = private)
        axesHandle
        lineHandle
        resp
    end
    methods
        function obj = spatialAdaptFigure(device, varargin)
            
            ip = inputParser();
            ip.addParameter('psth', false, @(x)islogical(x));
            ip.addParameter('barWidth', [], @(x)isvector(x));
            ip.addParameter('variableFlashTimes', [], @(x)isvector(x));
            ip.addParameter('coloredBy', [], @(x)iscellstr(x) || isvector(x));
            ip.parse(varargin{:});
            
            obj.device = device;
            obj.psth = ip.Results.psth;
            obj.barWidth=ip.Results.barWidth;
            obj.variableFlashTimes=ip.Results.variableFlashTimes;
            obj.colorstr=ip.Results.coloredBy;
            %             if isvector(obj.colorstr)
            %                 obj.colorstr=cellstr(string(obj.colorstr));
            %             end
            
            for i=1:length(obj.barWidth)
                for j=1:length(obj.colorstr) % number of color groups in each plot
                    for k=1:length(obj.variableFlashTimes)
                        obj.resp.trace{i,j,k}=0;   % create the globle variable to store the mean response,
                        obj.resp.count(i,j,k)=0;
                    end
                end
            end
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.colorstr),'CubicYF');
            for i=1:length(obj.barWidth)
                obj.axesHandle(i) = subplot(length(obj.barWidth),1,i, ...
                    'Parent', obj.figureHandle, ...
                    'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto');
                title(obj.axesHandle(i),strcat('barWidth ',' ', num2str(obj.barWidth)));
                xlabel(obj.axesHandle(i), 'Time (sec)');
                if obj.psth
                    ylabel(obj.axesHandle(i), 'spikeRate(Hz)');
                else
                    ylabel(obj.axesHandle(i), 'PSC(pA)');
                end
                linesForLegends=[];
                for j=1:length(obj.colorstr)
                    for k=1:length(obj.variableFlashTimes)
                        obj.lineHandle(i,j,k)=line(0,0,'Parent', obj.axesHandle(i), ...,
                            'Color',colors(j,:),'marker','none','linestyle','-');
                        if k==1
                            linesForLegends=[linesForLegends obj.lineHandle(i,j,1)];
                        end
                    end
                end
                % for each subplot, add legend, weel this is not a neat code
                %                legend(linesForLegends,obj.colorstr); legend boxoff;
                legend(linesForLegends,''); legend boxoff;
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
            if length(obj.colorstr)==3
                pattern=epoch.parameters('currentPattern');
                IndexC = strfind(obj.colorstr,pattern);
                patternIndex = find(not(cellfun('isempty',IndexC)));
                
            elseif length(obj.colorstr)==2
                pattern=epoch.parameters('currentPhase');
                patternIndex=find(obj.colorstr==pattern);
                %                 pattern=string(pattern); % translte the doulbe into string
            end
            
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
            
            
            obj.resp.count(barIndex,patternIndex,delayIndex)=obj.resp.count(barIndex,patternIndex,delayIndex)+1;
            obj.resp.trace{barIndex,patternIndex,delayIndex}=obj.resp.trace{barIndex,patternIndex,delayIndex}+y;
            set(obj.lineHandle(barIndex,patternIndex,delayIndex),'XData',x,'YData', obj.resp.trace{barIndex,patternIndex,delayIndex}./ ...,
                obj.resp.count(barIndex,patternIndex,delayIndex));
        end
    end
end

classdef VariableMeanContrastFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        lightMean
        lightContrast
        recordingType
        preTime
        stimTime
        tailTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        unityHandle
        summaryData
    end
    
    methods
        
        function obj = VariableMeanContrastFigure(ampDevice, lightMean, lightContrast, varargin)
            obj.ampDevice = ampDevice;
            obj.lightMean = lightMean;
            obj.lightContrast = lightContrast;
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('tailTime', [], @(x)isvector(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.tailTime = ip.Results.tailTime;
            %response matrices are ( # light mean ., # contrast )
            obj.summaryData.responseMatrix = zeros(numel(lightMean), numel(lightContrast));
            obj.summaryData.countMatrix = zeros(numel(lightMean), numel(lightContrast));
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            colors=[0 0 0; 1 0 0; 0 0 1];
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'contrast');
            ylabel(obj.axesHandle, 'Response to contrast step');
            title(obj.axesHandle,'Variable Mean - contrast response');
            
            linesForLegends=[];
            
            for k=1:length(obj.lightMean)
                obj.lineHandle(k)=line(0,0,'Parent', obj.axesHandle, ...,
                    'Color',colors(k,:),'marker','none','linestyle','-','linewidth',1.5);
                linesForLegends=[linesForLegends obj.lineHandle(k)];
            end
            % for each subplot, add legend, weel this is not a neat code
            legend(strcat('meanIntensity=',string(num2cell(1:2)))); legend boxoff;
            
        end
        
        
        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            currentMean=epoch.parameters('lightMean');
            currentContrast=epoch.parameters('lightContrast');
            meanIndex=find(currentMean==obj.lightMean);
            contrastIndex=find(currentContrast==obj.lightContrast);
            %process data and pull out epoch response
            if strcmp(obj.recordingType,'extracellular') %spike recording
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime+obj.tailTime)/1000));
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                newEpochResponse = length(S.sp); %spike count
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:sampleRate*obj.preTime/1000)); %baseline
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime+obj.tailTime)/1000));
                %charge transfer
                if strcmp(obj.recordingType,'exc') %measuring exc
                    chargeMult = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    chargeMult = 1;
                end
                newEpochResponse = chargeMult*trapz(epochResponseTrace(1:sampleRate*obj.stimTime/1000)); %pA*datapoint
                newEpochResponse = newEpochResponse/sampleRate; %pA*sec = pC
            end
            
            
            obj.summaryData.responseMatrix(meanIndex,contrastIndex) =obj.summaryData.responseMatrix(meanIndex,contrastIndex)+newEpochResponse;
            obj.summaryData.countMatrix(meanIndex,contrastIndex)=obj.summaryData.countMatrix(meanIndex,contrastIndex)+1;
            
            %plot summary data...
            %data lines:
            meanMatrix = obj.summaryData.responseMatrix ./ obj.summaryData.countMatrix;
            
            for i=1:numel(obj.lightMean)
                set(obj.lineHandle(meanIndex),'XData',obj.lightContrast,'YData', meanMatrix(meanIndex,:));
            end
            
            %unity line:
            limDown = min(meanMatrix(:));
            limUp = max(meanMatrix(:));
            if isempty(obj.unityHandle)
                obj.unityHandle = line([limDown limUp] , [limDown limUp],...
                    'Parent', obj.axesHandle,'Color','k','Marker','none','LineStyle','--');
            else
                set(obj.unityHandle, 'XData', [limDown limUp],...
                    'YData', [limDown limUp]);
            end   
        end
    end
end
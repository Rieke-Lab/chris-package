classdef spatialCorrAdaptFigure< symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        psth
        preTime
        tailTime
        baseTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        allEpochResponses
        baselines
        allSpaCorrs
        allEpochRatios
        summaryData
    end
    
    methods
        
        function obj = spatialCorrAdaptFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;
            ip = inputParser();
            ip.addParameter('psth', [], @(x)islogical(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('tailTime', [], @(x)isvector(x));
            ip.addParameter('baseTime', [], @(x)isvector(x));
            ip.parse(varargin{:});
            obj.psth = ip.Results.psth;
            obj.preTime = ip.Results.preTime;
            obj.tailTime = ip.Results.tailTime;
            obj.baseTime=ip.Results.baseTime;
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'spatial Correlation');
            ylabel(obj.axesHandle, 'Adaptation ratio');
            title(obj.axesHandle,'adaptation vs spatial corr');
        end
        
        
        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            currentSpatialCorr= epoch.parameters('currentSpatialCorr');
            prePts = sampleRate*obj.preTime/1000;
            tailPts = sampleRate*obj.tailTime/1000;
            basePts=sampleRate*obj.baseTime/1000;
            preScaleFactor = tailPts / prePts;
            
            epochResponseTrace = epochResponseTrace([1:prePts, end-tailPts:end]);
           
            if obj.psth  %spike recording
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                trace=S.sp;
            else 
                trace=epochResponseTrace;
      
            end
  

            newEpochResponse = (sum(trace > prePts)- (tailPts/basePts)*sum(trace < basePts));  %spike count during stim
            newBaseline =(preScaleFactor * (sum(trace < prePts)-(prePts/basePts)*sum(trace < basePts))); %spike count before stim, scaled by length
            
            newRatio= newEpochResponse/newBaseline;
            if newBaseline<0.1
                newRatio=0;
            end
            
            obj.allSpaCorrs =cat(1,obj.allSpaCorrs, currentSpatialCorr);
            obj.allEpochRatios = cat(1,obj.allEpochRatios,newRatio);
            
            
            obj.summaryData.spaCorr = unique(obj.allSpaCorrs);  % sorted ascendingly
            obj.summaryData.meanRatios = zeros(size(obj.summaryData.spaCorr));
            for i = 1:length(obj.summaryData.spaCorr)
                pullIndices = (obj.summaryData.spaCorr(i) == obj.allSpaCorrs);
                obj.summaryData.meanRatios(i) = mean(obj.allEpochRatios(pullIndices));
            end
            
            if isempty(obj.lineHandle)
                obj.lineHandle = line(obj.summaryData.spaCorr, obj.summaryData.meanRatios,...
                    'Parent', obj.axesHandle,'Color','k','Marker','o');
            else
                set(obj.lineHandle, 'XData', obj.summaryData.spaCorr,...
                    'YData', obj.summaryData.meanRatios);
            end
        end
        
    end
    
end
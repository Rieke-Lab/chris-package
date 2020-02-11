classdef spatialCorrAdaptFigure< symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        psth
        flashTimes
        flashDuration
        baseTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        allEpochResponses
        allSpaCorrs
        allEpochRatios
        summaryData
    end
    
    methods
        
        function obj = spatialCorrAdaptFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;
            ip = inputParser();
            ip.addParameter('psth', [], @(x)islogical(x));
            ip.addParameter('flashDuration', [], @(x)isnumeric(x));
            ip.addParameter('flashTimes', [], @(x)isvector(x));
            ip.addParameter('baseTime', [], @(x)isnumeric(x));
            ip.parse(varargin{:});
            obj.psth = ip.Results.psth;
            obj.flashDuration = 10000*ip.Results.flashDuration/1000;
            obj.baseTime = 10000*ip.Results.baseTime/1000;
            obj.flashTimes = 10000*ip.Results.flashTimes/1000;
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
            trace=epochResponseTrace;
            if obj.psth
                sigma = 10e-3 * sampleRate;
                filter = normpdf(1:10*sigma, 10*sigma/2, sigma);
                results = edu.washington.riekelab.util.spikeDetectorOnline(epochResponseTrace, [], sampleRate);
                trace = zeros(size(epochResponseTrace));
                trace(results.sp) = 1;
                trace = sampleRate * conv(trace, filter, 'same');
            end
            if ~isempty(trace)
                trace=trace-mean(trace(1:obj.baseTime));
                newRatio= max(abs(trace(obj.flashTimes(2):obj.flashTimes(2)+obj.flashDuration+500)))./ ...,
                    max(abs(trace(obj.flashTimes(1):obj.flashTimes(1)+obj.flashDuration+500)));
                
                obj.allSpaCorrs =cat(1,obj.allSpaCorrs, currentSpatialCorr);
                obj.allEpochRatios = cat(1,obj.allEpochRatios,newRatio);
            end
            
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
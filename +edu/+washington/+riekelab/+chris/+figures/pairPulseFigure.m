classdef pairPulseFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        psth
        preTime
        pulseTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        fitLineHandle
        allIntervals
        allRatios
        summaryData
    end
    
    methods
        
        function obj = pairPulseFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;
            ip = inputParser();
            ip.addParameter('psth', [], @(x)islogical(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('pulseTime', [], @(x)isvector(x));
            ip.addParameter('intervalTime', [], @(x)isvector(x));
            ip.parse(varargin{:});
            obj.psth = ip.Results.psth;
            obj.preTime = ip.Results.preTime;
            obj.pulseTime = ip.Results.pulseTime;
            
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+utils\+icons\'];
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            fitGaussianButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Fit Gaussian', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedFitGaussian);
            setIconImage(fitGaussianButton, [iconDir, 'Gaussian.png']);
            
            
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'pair pulse interval (ms)');
            ylabel(obj.axesHandle, 'ratio');
            title(obj.axesHandle,'pair pulse curve');
            
        end
        
        
        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            currentInterval = epoch.parameters('currentInterval');
            timeToPts=@(t) round(t*sampleRate/1000);
            prePts = timeToPts(obj.preTime);
            intervalPts=timeToPts(currentInterval);
            pulsePts=timeToPts(obj.pulseTime);
            y=epochResponseTrace;
            if obj.psth
                y = zeros(size(epochResponseTrace));
                sigma = 10e-3 * sampleRate;
                filter = normpdf(1:10*sigma, 10*sigma/2, sigma);
                results = edu.washington.riekelab.util.spikeDetectorOnline(epochResponseTrace, [], sampleRate);
                y(results.sp) = 1;
                y = sampleRate * conv(y, filter, 'same');
            end

            y=y-mean(y(1:prePts));  % subtract the baseline
            currentRatio= max(abs(y(prePts+intervalPts+pulsePts:end)))/max(abs(y(prePts:prePts+intervalPts)));
            
            obj.allIntervals = cat(1,obj.allIntervals,currentInterval);
            obj.allRatios = cat(1,obj.allRatios,currentRatio);
            
            obj.summaryData.intervals = unique(obj.allIntervals);
            obj.summaryData.meanRatios = zeros(size(obj.summaryData.intervals));
            for intervalIndex = 1:length(obj.summaryData.intervals)
                pullIndices = (obj.summaryData.intervals(intervalIndex) == obj.allIntervals);
                obj.summaryData.meanRatios(intervalIndex) = mean(obj.allRatios(pullIndices));
            end
            
            if isempty(obj.lineHandle)
                obj.lineHandle = line(obj.summaryData.intervals, obj.summaryData.meanRatios,...
                    'Parent', obj.axesHandle,'Color','k','Marker','o');
            else
                set(obj.lineHandle, 'XData', obj.summaryData.intervals,...
                    'YData', obj.summaryData.meanRatios);
            end
        end
        
    end
    
    methods (Access = private)
        
        function onSelectedFitGaussian(obj, ~, ~)
            params0 = [max(obj.summaryData.meanResponses) / 2, 50];
            [Kc, sigmaC] = ...
                edu.washington.riekelab.turner.utils.fitGaussianRFAreaSummation(obj.summaryData.spotSizes,obj.summaryData.meanResponses,params0);
            fitX = 0:(1.1*max(obj.summaryData.spotSizes));
            fitY = edu.washington.riekelab.turner.utils.GaussianRFAreaSummation([Kc sigmaC],fitX);
            
            if isempty(obj.fitLineHandle)
                obj.fitLineHandle = line(fitX, fitY, 'Parent', obj.axesHandle);
            else
                set(obj.fitLineHandle, 'XData', fitX,...
                    'YData', fitY);
            end
            set(obj.fitLineHandle,'Color',[1 0 0],'LineWidth',2,'Marker','none');
            str = {['SigmaC = ',num2str(sigmaC)]};
            title(obj.axesHandle,str);
            
        end
        
    end
    
end
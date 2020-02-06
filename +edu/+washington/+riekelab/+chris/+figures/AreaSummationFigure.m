classdef AreaSummationFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        fitLineHandle
        allEpochResponses
        baselines
        allSpotSizes
        summaryData
    end
    
    methods
        
        function obj = AreaSummationFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;            
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            
            
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
            
            fitDoGButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Fit DoG', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedFitDoG);
            setIconImage(fitDoGButton, [iconDir, 'DoG.png']);
            
            
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'Spot Diameter (um)');
            ylabel(obj.axesHandle, 'Response');
            title(obj.axesHandle,'Area summation curve');
            
        end

        
        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            currentSpotSize = epoch.parameters('currentSpotSize');
            prePts = sampleRate*obj.preTime/1000;
            stimPts = sampleRate*obj.stimTime/1000;
            preScaleFactor = stimPts / prePts;
            
            if strcmp(obj.recordingType,'extracellular') %spike recording
                epochResponseTrace = epochResponseTrace(1:prePts+stimPts);
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                newEpochResponse = sum(S.sp > prePts); %spike count during stim
                newBaseline = preScaleFactor * sum(S.sp < prePts); %spike count before stim, scaled by length
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:prePts)); %baseline
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((prePts+1):(prePts+stimPts));
                %charge transfer
                if strcmp(obj.recordingType,'exc') %measuring exc
                    chargeMult = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    chargeMult = 1;
                end
                newEpochResponse = chargeMult*trapz(epochResponseTrace(1:sampleRate*obj.stimTime/1000)); %pA*datapoint
                newEpochResponse = newEpochResponse/sampleRate; %pA*sec = pC
                newBaseline = 0;
            end

            obj.allSpotSizes = cat(1,obj.allSpotSizes,currentSpotSize);
            obj.allEpochResponses = cat(1,obj.allEpochResponses,newEpochResponse);
            obj.baselines = cat(1,obj.baselines,newBaseline);
            
            obj.summaryData.spotSizes = unique(obj.allSpotSizes);
            obj.summaryData.meanResponses = zeros(size(obj.summaryData.spotSizes));
            for SpotSizeIndex = 1:length(obj.summaryData.spotSizes)
                pullIndices = (obj.summaryData.spotSizes(SpotSizeIndex) == obj.allSpotSizes);
                obj.summaryData.meanResponses(SpotSizeIndex) = mean(obj.allEpochResponses(pullIndices));
            end
            
            if isempty(obj.lineHandle)
                obj.lineHandle = line(obj.summaryData.spotSizes, obj.summaryData.meanResponses,...
                    'Parent', obj.axesHandle,'Color','k','Marker','o');
            else
                set(obj.lineHandle, 'XData', obj.summaryData.spotSizes,...
                    'YData', obj.summaryData.meanResponses);
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
        
        function onSelectedFitDoG(obj, ~, ~)
            params0 = [max(obj.summaryData.meanResponses) / 2,50,...
                max(obj.summaryData.meanResponses) / 2, 150,0];
            [Kc, sigmaC, Ks, sigmaS, baseFiring] = ...
                edu.washington.riekelab.turner.utils.fitDoGAreaSummation(obj.summaryData.spotSizes,obj.summaryData.meanResponses,params0);
            fitX = 0:(1.1*max(obj.summaryData.spotSizes));
            fitY = edu.washington.riekelab.turner.utils.DoGAreaSummation([Kc sigmaC Ks sigmaS baseFiring], fitX);
            
            if isempty(obj.fitLineHandle)
                obj.fitLineHandle = line(fitX, fitY, 'Parent', obj.axesHandle);
            else
                set(obj.fitLineHandle, 'XData', fitX,...
                    'YData', fitY);
            end
            set(obj.fitLineHandle,'Color',[1 0 0],'LineWidth',2,'Marker','none');
            tempKc = Kc / (Kc + Ks);
            str = {['SigmaC = ',num2str(sigmaC)],['sigmaS = ',num2str(sigmaS)],...
            ['Kc = ',num2str(tempKc)]};
            title(obj.axesHandle,str);
        end

    end
    
end


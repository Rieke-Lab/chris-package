classdef PhaseLinearFilterFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        frameMonitor
        stageDevice
        recordingType
        preTime
        stimTime
        frameDwell
        figureTitle
    end
    
    properties (Access = private)
        axesHandle
        risingLineHandle
        fallingLineHandle
        risingLnDataHandle
        fallingLnDataHandle
        allRisingStimuli
        allRisingResponses
        allFallingStimuli
        allFallingResponses
        risingFilter
        fallingFilter
        epochCount
    end
    
    methods
        
        function obj = PhaseLinearFilterFigure(ampDevice, frameMonitor, stageDevice, varargin)
            obj.ampDevice = ampDevice;
            obj.frameMonitor = frameMonitor;
            obj.stageDevice = stageDevice;
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('frameDwell', [], @(x)isvector(x));
            ip.addParameter('figureTitle','Phase-separated Linear-Nonlinear analysis', @(x)ischar(x));
            ip.parse(varargin{:});
            
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameDwell = ip.Results.frameDwell;
            obj.figureTitle = ip.Results.figureTitle;

            obj.allRisingStimuli = [];
            obj.allRisingResponses = [];
            obj.allFallingStimuli = [];
            obj.allFallingResponses = [];
            obj.epochCount = 0;
            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+utils\+icons\'];
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            plotLNButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Plot nonlinearity', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedFitLN);
            setIconImage(plotLNButton, [iconDir, 'exp.png']);

            obj.axesHandle(1) = subplot(2,1,1,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(1), 'Time (ms)');
            ylabel(obj.axesHandle(1), 'Amp.');
            title(obj.axesHandle(1),'Linear filters');
            
            obj.axesHandle(2) = subplot(2,1,2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(2), 'Generator Signal');
            ylabel(obj.axesHandle(2), 'Measured');

            title(obj.axesHandle(2),'Phase-specific nonlinearities');
            
            obj.figureHandle.Name = obj.figureTitle;
        end

        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = sampleRate*obj.preTime/1000;
            
            % Get parameters from epoch
            noiseOverFrame = epoch.parameters('intensityOverFrame');
            
            % Extract sinusoid from epoch parameters and calculate derivative
            sinusoidOverFrame = epoch.parameters('sinusoidOverFrame');
            sinusoidDiff = [0, diff(sinusoidOverFrame)];
            % Define rising and falling phases based on derivative
            isRising = sinusoidDiff > 0;
            
            if strcmp(obj.recordingType,'extracellular') %spike recording
                newResponse = zeros(size(epochResponseTrace));
                %count spikes
                S = edu.washington.riekelab.weber.utils.spikeDetectorOnline(epochResponseTrace);
                newResponse(S.sp) = 1;
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:prePts)); %baseline
                if strcmp(obj.recordingType,'exc') %measuring exc
                    polarity = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    polarity = 1;
                end
                newResponse = polarity * epochResponseTrace;
            end
            
            %load frame monitor data
            if isa(obj.stageDevice,'edu.washington.riekelab.devices.LightCrafterDevice')
                lightCrafterFlag = 1;
            else %OLED stage device
                lightCrafterFlag = 0;
            end
            frameRate = obj.stageDevice.getMonitorRefreshRate();
            FMresponse = epoch.getResponse(obj.frameMonitor);
            FMdata = FMresponse.getData();
            frameTimes = edu.washington.riekelab.weber.utils.getFrameTiming(FMdata,lightCrafterFlag);
            preFrames = frameRate*(obj.preTime/1000);
            firstStimFrameFlip = frameTimes(preFrames+1);
            newResponse = newResponse(firstStimFrameFlip:end); %cut out pre-frames
            
            % Split noise and response by phase
            chunkLen = obj.frameDwell*mean(diff(frameTimes));  % in ms units
            risingNoise = noiseOverFrame(isRising);
            fallingNoise = noiseOverFrame(~isRising);
            
            risingResponse = [];
            fallingResponse = [];
            for ii = 1:length(isRising)
                responseChunk = newResponse(round((ii-1)*chunkLen + 1) : round(ii*chunkLen));
                if isRising(ii)
                    risingResponse = [risingResponse, mean(responseChunk)];
                else
                    fallingResponse = [fallingResponse, mean(responseChunk)];
                end
            end
            
            % Accumulate data
            obj.allRisingStimuli = cat(1, obj.allRisingStimuli, risingNoise);
            obj.allRisingResponses = cat(1, obj.allRisingResponses, risingResponse);
            obj.allFallingStimuli = cat(1, obj.allFallingStimuli, fallingNoise);
            obj.allFallingResponses = cat(1, obj.allFallingResponses, fallingResponse);
            
            % Compute linear filters for both phases
            updateRate = (frameRate/obj.frameDwell); %hz
            filterLen = 800; %msec
            freqCutoffFraction = 1;
            
            obj.risingFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                obj.allRisingStimuli, obj.allRisingResponses, updateRate, freqCutoffFraction*updateRate);
            obj.fallingFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                obj.allFallingStimuli, obj.allFallingResponses, updateRate, freqCutoffFraction*updateRate);
            
            filterPts = (filterLen/1000)*updateRate;
            filterTimes = linspace(0,filterLen,filterPts); %msec
            
            obj.risingFilter = obj.risingFilter(1:filterPts);
            obj.fallingFilter = obj.fallingFilter(1:filterPts);

            % Update plots
            if isempty(obj.risingLineHandle)
                obj.risingLineHandle = line(filterTimes, obj.risingFilter,...
                    'Parent', obj.axesHandle(1),'LineWidth',2,'Color','r','DisplayName','Rising Phase');
                obj.fallingLineHandle = line(filterTimes, obj.fallingFilter,...
                    'Parent', obj.axesHandle(1),'LineWidth',2,'Color','b','DisplayName','Falling Phase');
                ht = line([filterTimes(1) filterTimes(end)],[0 0],...
                    'Parent', obj.axesHandle(1),'Color','k',...
                    'Marker','none','LineStyle','--','DisplayName','Baseline');
                legend(obj.axesHandle(1),'show','Location','northeast');
            else
                set(obj.risingLineHandle, 'YData', obj.risingFilter);
                set(obj.fallingLineHandle, 'YData', obj.fallingFilter);
            end
        end

        function onSelectedFitLN(obj, ~, ~)
            % Compute nonlinearity for rising phase
            measuredRisingResponse = reshape(obj.allRisingResponses',1,numel(obj.allRisingResponses));
            risingStimArray = reshape(obj.allRisingStimuli',1,numel(obj.allRisingStimuli));
            risingPrediction = conv(risingStimArray, obj.risingFilter);
            risingPrediction = risingPrediction(1:length(risingStimArray));
            [~,edges,bin] = histcounts(risingPrediction,'BinMethod','auto');
            binCtrs = edges(1:end-1) + diff(edges);

            binRisingResp = zeros(size(binCtrs));
            for bb = 1:length(binCtrs)
               binRisingResp(bb) = mean(measuredRisingResponse(bin == bb)); 
            end
            
            % Compute nonlinearity for falling phase
            measuredFallingResponse = reshape(obj.allFallingResponses',1,numel(obj.allFallingResponses));
            fallingStimArray = reshape(obj.allFallingStimuli',1,numel(obj.allFallingStimuli));
            fallingPrediction = conv(fallingStimArray, obj.fallingFilter);
            fallingPrediction = fallingPrediction(1:length(fallingStimArray));
            [~,edges,bin] = histcounts(fallingPrediction,'BinMethod','auto');
            binCtrs = edges(1:end-1) + diff(edges);
            
            binFallingResp = zeros(size(binCtrs));
            for bb = 1:length(binCtrs)
               binFallingResp(bb) = mean(measuredFallingResponse(bin == bb)); 
            end
            
            % Update plots
            if isempty(obj.risingLnDataHandle)
                obj.risingLnDataHandle = line(binCtrs, binRisingResp,...
                    'Parent', obj.axesHandle(2),'LineStyle','none','Marker','o','Color','r',...
                    'DisplayName','Rising Phase');
                obj.fallingLnDataHandle = line(binCtrs, binFallingResp,...
                    'Parent', obj.axesHandle(2),'LineStyle','none','Marker','o','Color','b',...
                    'DisplayName','Falling Phase');
                limDown = min([risingPrediction fallingPrediction measuredRisingResponse measuredFallingResponse]);
                limUp = max([risingPrediction fallingPrediction measuredRisingResponse measuredFallingResponse]);
                htx = line([limDown limUp],[0 0],...
                    'Parent', obj.axesHandle(2),'Color','k',...
                    'Marker','none','LineStyle','--','DisplayName','Zero Line');
                hty = line([0 0],[limDown limUp],...
                    'Parent', obj.axesHandle(2),'Color','k',...
                    'Marker','none','LineStyle','--','HandleVisibility','off');
                legend(obj.axesHandle(2),'show','Location','northwest');
            else
                set(obj.risingLnDataHandle, 'YData', binRisingResp, 'XData', binCtrs);
                set(obj.fallingLnDataHandle, 'YData', binFallingResp, 'XData', binCtrs);
            end
        end
    end
end
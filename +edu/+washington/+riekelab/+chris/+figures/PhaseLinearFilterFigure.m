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
        % Line handles for filters
        risingLineHandle
        fallingLineHandle
        noiseOnlyLineHandle

        % Line handles for nonlinearities
        risingLnDataHandle
        fallingLnDataHandle
        noiseOnlyLnDataHandle

        % Storage for stimuli and responses
        allRisingStimuli
        allRisingResponses
        allFallingStimuli
        allFallingResponses
        allNoiseOnlyStimuli  % Consistent naming
        allNoiseOnlyResponses % Consistent naming

        % Filters
        risingFilter
        fallingFilter
        noiseOnlyFilter

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


            if isempty(ip.Results.recordingType)
                error('recordingType parameter is required');
            end
            if isempty(ip.Results.preTime)
                error('preTime parameter is required');
            end
            if isempty(ip.Results.stimTime)
                error('stimTime parameter is required');
            end
            if isempty(ip.Results.frameDwell)
                error('frameDwell parameter is required');
            end

            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameDwell = ip.Results.frameDwell;
            obj.figureTitle = ip.Results.figureTitle;

            obj.allRisingStimuli = [];
            obj.allRisingResponses = [];
            obj.allFallingStimuli = [];
            obj.allFallingResponses = [];
            obj.allNoiseOnlyStimuli = [];
            obj.allNoiseOnlyResponses = [];
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

            % Get stimulus type from epoch parameters
            stimulusTag = epoch.parameters('stimulusTag');
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = sampleRate*obj.preTime/1000;


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


            if strcmp(stimulusTag, 'SinusoidNoise')
                % Extract sinusoid and noise from epoch parameters
                noiseOverFrame = epoch.parameters('noiseOverFrame');
                sinusoidOverFrame = epoch.parameters('sinusoidOverFrame');
                sinusoidDiff = [0, diff(sinusoidOverFrame)];
                isRising = sinusoidDiff > 0;

                % Split noise and response by phase
                chunkLen = obj.frameDwell*mean(diff(frameTimes));
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

                % Accumulate phase-specific data
                obj.allRisingStimuli = cat(1, obj.allRisingStimuli, risingNoise);
                obj.allRisingResponses = cat(1, obj.allRisingResponses, risingResponse);
                obj.allFallingStimuli = cat(1, obj.allFallingStimuli, fallingNoise);
                obj.allFallingResponses = cat(1, obj.allFallingResponses, fallingResponse);

            elseif strcmp(stimulusTag, 'NoiseOnly')
                % Process noise-only epochs
                noiseOverFrame = epoch.parameters('noiseOverFrame');
                chunkLen = obj.frameDwell*mean(diff(frameTimes));

                noiseResponse = zeros(1, length(noiseOverFrame));
                for ii = 1:length(noiseOverFrame)
                    responseChunk = newResponse(round((ii-1)*chunkLen + 1) : round(ii*chunkLen));
                    noiseResponse(ii) = mean(responseChunk);
                end

                % Accumulate noise-only data
                obj.allNoiseOnlyStimuli = cat(1, obj.allNoiseOnlyStimuli, noiseOverFrame);
                obj.allNoiseOnlyResponses = cat(1, obj.allNoiseOnlyResponses, noiseResponse);
            end


            % Compute linear filters for both phases
            updateRate = (frameRate/obj.frameDwell); %hz
            filterLen = 800; %msec
            freqCutoffFraction = 1;
            filterPts = (filterLen/1000)*updateRate;
            filterTimes = linspace(0,filterLen,filterPts); %msec

            % Compute filters if we have data
            if ~isempty(obj.allRisingStimuli)
                obj.risingFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                    obj.allRisingStimuli, obj.allRisingResponses, updateRate, freqCutoffFraction*updateRate);
                obj.risingFilter = obj.risingFilter(1:filterPts);

                obj.fallingFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                    obj.allFallingStimuli, obj.allFallingResponses, updateRate, freqCutoffFraction*updateRate);
                obj.fallingFilter = obj.fallingFilter(1:filterPts);
            end

            if ~isempty(obj.allNoiseStimuli)
                obj.noiseFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                    obj.allNoiseStimuli, obj.allNoiseResponses, updateRate, freqCutoffFraction*updateRate);
                obj.noiseFilter = obj.noiseFilter(1:filterPts);
            end

            % Update filter plot
            if isempty(obj.risingLineHandle)
                hold(obj.axesHandle(1), 'on');
                if ~isempty(obj.risingFilter)
                    obj.risingLineHandle = line(filterTimes, obj.risingFilter,...
                        'Parent', obj.axesHandle(1),'LineWidth',2,'Color','r',...
                        'DisplayName','Rising Phase');
                    obj.fallingLineHandle = line(filterTimes, obj.fallingFilter,...
                        'Parent', obj.axesHandle(1),'LineWidth',2,'Color','b',...
                        'DisplayName','Falling Phase');
                end
                if ~isempty(obj.noiseFilter)
                    obj.noiseLineHandle = line(filterTimes, obj.noiseFilter,...
                        'Parent', obj.axesHandle(1),'LineWidth',2,'Color','k',...
                        'DisplayName','Noise Only');
                end
                ht = line([filterTimes(1) filterTimes(end)],[0 0],...
                    'Parent', obj.axesHandle(1),'Color',[0.5 0.5 0.5],...
                    'Marker','none','LineStyle','--','DisplayName','Baseline');
                legend(obj.axesHandle(1),'show','Location','northeast');
                hold(obj.axesHandle(1), 'off');
            else
                if ~isempty(obj.risingFilter)
                    set(obj.risingLineHandle, 'YData', obj.risingFilter);
                    set(obj.fallingLineHandle, 'YData', obj.fallingFilter);
                end
                if ~isempty(obj.noiseFilter)
                    set(obj.noiseLineHandle, 'YData', obj.noiseFilter);
                end
            end

        end

        function onSelectedFitLN(obj, ~, ~)
            % Clear existing plot and enable hold
            cla(obj.axesHandle(2));
            hold(obj.axesHandle(2), 'on');

            % Initialize arrays to store all predictions and responses for axis scaling
            allPredictions = [];
            allResponses = [];

            % Process sinusoid+noise data if available
            if ~isempty(obj.allRisingStimuli)
                % Rising phase nonlinearity
                measuredRisingResponse = reshape(obj.allRisingResponses', [], 1);
                risingStimArray = reshape(obj.allRisingStimuli', [], 1);
                risingPrediction = conv(risingStimArray, obj.risingFilter);
                risingPrediction = risingPrediction(1:length(risingStimArray));
                [~, edges, bin] = histcounts(risingPrediction, 'BinMethod', 'auto');
                binCtrs = edges(1:end-1) + diff(edges)/2;

                binRisingResp = zeros(size(binCtrs));
                for bb = 1:length(binCtrs)
                    respInBin = measuredRisingResponse(bin == bb);
                    binRisingResp(bb) = mean(respInBin);
                end

                % Falling phase nonlinearity
                measuredFallingResponse = reshape(obj.allFallingResponses', [], 1);
                fallingStimArray = reshape(obj.allFallingStimuli', [], 1);
                fallingPrediction = conv(fallingStimArray, obj.fallingFilter);
                fallingPrediction = fallingPrediction(1:length(fallingStimArray));
                [~, edges, bin] = histcounts(fallingPrediction, 'BinMethod', 'auto');
                binCtrs = edges(1:end-1) + diff(edges)/2;

                binFallingResp = zeros(size(binCtrs));
                for bb = 1:length(binCtrs)
                    respInBin = measuredFallingResponse(bin == bb);
                    binFallingResp(bb) = mean(respInBin);
                end

                % Store for axis scaling
                allPredictions = [allPredictions; risingPrediction; fallingPrediction];
                allResponses = [allResponses; measuredRisingResponse; measuredFallingResponse];
            end

            % Process noise-only data if available
            if ~isempty(obj.allNoiseStimuli)
                measuredNoiseResponse = reshape(obj.allNoiseResponses', [], 1);
                noiseStimArray = reshape(obj.allNoiseStimuli', [], 1);
                noisePrediction = conv(noiseStimArray, obj.noiseFilter);
                noisePrediction = noisePrediction(1:length(noiseStimArray));
                [~, edges, bin] = histcounts(noisePrediction, 'BinMethod', 'auto');
                noiseBinCtrs = edges(1:end-1) + diff(edges)/2;

                binNoiseResp = zeros(size(noiseBinCtrs));
                for bb = 1:length(noiseBinCtrs)
                    respInBin = measuredNoiseResponse(bin == bb);
                    binNoiseResp(bb) = mean(respInBin);
                end

                % Store for axis scaling
                allPredictions = [allPredictions; noisePrediction];
                allResponses = [allResponses; measuredNoiseResponse];
            end

            % Plot nonlinearities
            if ~isempty(obj.allRisingStimuli)
                plot(binCtrs, binRisingResp, 'ro-', ...
                    'LineWidth', 1.5, 'MarkerFaceColor', 'r', ...
                    'DisplayName', 'Rising Phase');
                plot(binCtrs, binFallingResp, 'bo-', ...
                    'LineWidth', 1.5, 'MarkerFaceColor', 'b', ...
                    'DisplayName', 'Falling Phase');
            end

            if ~isempty(obj.allNoiseStimuli)
                plot(noiseBinCtrs, binNoiseResp, 'ko-', ...
                    'LineWidth', 1.5, 'MarkerFaceColor', 'k', ...
                    'DisplayName', 'Noise Only');
            end



            % Add unity line and zero crossings
            limDown = min(min([allPredictions, allResponses]));
            limUp = max(max([allPredictions, allResponses]));
            padding = (limUp - limDown) * 0.1;
            limDown = limDown - padding;
            limUp = limUp + padding;

            % Plot zero crossings
            line([limDown limUp], [0 0], 'Color', [0.5 0.5 0.5], ...
                'LineStyle', '--', 'DisplayName', 'Zero Line');
            line([0 0], [limDown limUp], 'Color', [0.5 0.5 0.5], ...
                'LineStyle', '--', 'HandleVisibility', 'off');

            % Add unity line for reference
            line([limDown limUp], [limDown limUp], 'Color', [0.7 0.7 0.7], ...
                'LineStyle', ':', 'DisplayName', 'Unity');

            % Set axis limits and labels
            xlim([limDown limUp]);
            ylim([limDown limUp]);

            % Update legend and grid
            legend('show', 'Location', 'northwest');
            grid on;

            % Release hold
            hold(obj.axesHandle(2), 'off');
        end
    end
end
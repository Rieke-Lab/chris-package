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

        % Nonlinearity data
        risingBinCenters
        risingBinResponses
        fallingBinCenters
        fallingBinResponses
        noiseOnlyBinCenters
        noiseOnlyBinResponses

        updateRate
        filterPts
        filterTimes
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

            % Precalculate filter parameters
            frameRate = obj.stageDevice.getMonitorRefreshRate();
            obj.updateRate = (frameRate/obj.frameDwell);
            filterLen = 800; % msec
            obj.filterPts = (filterLen/1000)*obj.updateRate;
            obj.filterTimes = linspace(0, filterLen, obj.filterPts);
            
            obj.createUi();
        end

        function createUi(obj)

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

            legend(obj.axesHandle(1), 'show');
            legend(obj.axesHandle(2), 'show');

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
                S = edu.washington.riekelab.chris.utils.spikeDetectorOnline(epochResponseTrace);
                newResponse(S.sp) = 1;
            else 
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:10)); %baseline
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
            frameTimes = edu.washington.riekelab.chris.utils.getFrameTiming(FMdata,lightCrafterFlag);
            preFrames = frameRate*(obj.preTime/1000);
            firstStimFrameFlip = frameTimes(preFrames+1);
            newResponse = newResponse(firstStimFrameFlip:end); %cut out pre-frames

            noiseOverFrame = epoch.parameters('noiseOverFrame');
            sinusoidOverFrame = epoch.parameters('sinusoidOverFrame');
            chunkLen = obj.frameDwell*mean(diff(frameTimes));

            if strcmp(stimulusTag, 'sinusoidPlusNoise')
                % Extract sinusoid and noise from epoch parameters
                sinusoidDiff = [0, diff(sinusoidOverFrame)];
                isRising = sinusoidDiff > 0;

                % Split noise and response by phase
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

            elseif strcmp(stimulusTag, 'noiseOnly')
                % Process noise-only epochs

                noiseResponse = zeros(1, length(noiseOverFrame));
                for ii = 1:length(noiseOverFrame)
                    responseChunk = newResponse(round((ii-1)*chunkLen + 1) : round(ii*chunkLen));
                    noiseResponse(ii) = mean(responseChunk);
                end

                % Accumulate noise-only data
                obj.allNoiseOnlyStimuli = cat(1, obj.allNoiseOnlyStimuli, noiseOverFrame);
                obj.allNoiseOnlyResponses = cat(1, obj.allNoiseOnlyResponses, noiseResponse);
            end


            freqCutoffFraction = 1;

            % Initialize plot handles if needed
            if isempty(obj.risingLineHandle)
                hold(obj.axesHandle(1), 'on');
                hold(obj.axesHandle(2), 'on');
            end


            % Compute filters if we have data
            if ~isempty(obj.allRisingStimuli)
                obj.risingFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                    obj.allRisingStimuli, obj.allRisingResponses, obj.updateRate, freqCutoffFraction*obj.updateRate);
                obj.risingFilter = obj.risingFilter(1:obj.filterPts);

                obj.fallingFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                    obj.allFallingStimuli, obj.allFallingResponses, obj.updateRate, freqCutoffFraction*obj.updateRate);
                obj.fallingFilter = obj.fallingFilter(1:obj.filterPts);

                % Update filter plots
                if isempty(obj.risingLineHandle)
                    hold(obj.axesHandle(1), 'on');
                    obj.risingLineHandle = line(obj.filterTimes, obj.risingFilter,...
                        'Parent', obj.axesHandle(1),'LineWidth',2,'Color','r',...
                        'DisplayName','Rising Phase');
                    obj.fallingLineHandle = line(obj.filterTimes, obj.fallingFilter,...
                        'Parent', obj.axesHandle(1),'LineWidth',2,'Color','b',...
                        'DisplayName','Falling Phase');
                else
                    set(obj.risingLineHandle, 'YData', obj.risingFilter);
                    set(obj.fallingLineHandle, 'YData', obj.fallingFilter);
                end

                % Calculate nonlinearities
                measuredRisingResponse = reshape(obj.allRisingResponses',1,numel(obj.allRisingResponses));
                risingStimArray = reshape(obj.allRisingStimuli',1,numel(obj.allRisingStimuli));
                risingPrediction = conv(risingStimArray,obj.risingFilter);
                risingPrediction = risingPrediction(1:length(risingStimArray));
                [~,edges,bin] = histcounts(risingPrediction,'BinMethod','auto');
                obj.risingBinCenters = edges(1:end-1) + diff(edges);

                obj.risingBinResponses = zeros(size(obj.risingBinCenters));
                for bb = 1:length(obj.risingBinCenters)
                    obj.risingBinResponses(bb) = mean(measuredRisingResponse(bin == bb));
                end

                measuredFallingResponse = reshape(obj.allFallingResponses',1,numel(obj.allFallingResponses));
                fallingStimArray = reshape(obj.allFallingStimuli',1,numel(obj.allFallingStimuli));
                fallingPrediction = conv(fallingStimArray,obj.fallingFilter);
                fallingPrediction = fallingPrediction(1:length(fallingStimArray));
                [~,edges,bin] = histcounts(fallingPrediction,'BinMethod','auto');
                obj.fallingBinCenters = edges(1:end-1) + diff(edges);

                obj.fallingBinResponses = zeros(size(obj.fallingBinCenters));
                for bb = 1:length(obj.fallingBinCenters)
                    obj.fallingBinResponses(bb) = mean(measuredFallingResponse(bin == bb));
                end

                % Update nonlinearity plots
                if isempty(obj.risingLnDataHandle)
                    hold(obj.axesHandle(2), 'on');
                    obj.risingLnDataHandle = line(obj.risingBinCenters, obj.risingBinResponses,...
                        'Parent', obj.axesHandle(2),'Color','r','LineStyle','-','Marker','o',...
                        'DisplayName','Rising Phase');
                    obj.fallingLnDataHandle = line(obj.fallingBinCenters, obj.fallingBinResponses,...
                        'Parent', obj.axesHandle(2),'Color','b','LineStyle','-','Marker','o',...
                        'DisplayName','Falling Phase');
                else
                    set(obj.risingLnDataHandle, 'XData', obj.risingBinCenters, 'YData', obj.risingBinResponses);
                    set(obj.fallingLnDataHandle, 'XData', obj.fallingBinCenters, 'YData', obj.fallingBinResponses);
                end


                if ~isempty(obj.allNoiseOnlyStimuli)
                    % Noise-only filter
                    obj.noiseOnlyFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                        obj.allNoiseOnlyStimuli, obj.allNoiseOnlyResponses, obj.updateRate, freqCutoffFraction*obj.updateRate);
                    obj.noiseOnlyFilter = obj.noiseOnlyFilter(1:obj.filterPts);

                    % Update filter plot
                    if isempty(obj.noiseOnlyLineHandle)
                        obj.noiseOnlyLineHandle = line(obj.filterTimes, obj.noiseOnlyFilter,...
                            'Parent', obj.axesHandle(1),'LineWidth',2,'Color','k',...
                            'DisplayName','Noise Only');
                    else
                        set(obj.noiseOnlyLineHandle, 'YData', obj.noiseOnlyFilter);
    
                    end

                    % Calculate noise-only nonlinearity
                    measuredNoiseResponse = reshape(obj.allNoiseOnlyResponses',1,numel(obj.allNoiseOnlyResponses));
                    noiseStimArray = reshape(obj.allNoiseOnlyStimuli',1,numel(obj.allNoiseOnlyStimuli));
                    noisePrediction = conv(noiseStimArray,obj.noiseOnlyFilter);
                    noisePrediction = noisePrediction(1:length(noiseStimArray));
                    [~,edges,bin] = histcounts(noisePrediction,'BinMethod','auto');
                    obj.noiseOnlyBinCenters = edges(1:end-1) + diff(edges);

                    obj.noiseOnlyBinResponses = zeros(size(obj.noiseOnlyBinCenters));
                    for bb = 1:length(obj.noiseOnlyBinCenters)
                        obj.noiseOnlyBinResponses(bb) = mean(measuredNoiseResponse(bin == bb));
                    end

                    % Update noise-only nonlinearity plot
                    if isempty(obj.noiseOnlyLnDataHandle)
                        obj.noiseOnlyLnDataHandle = line(obj.noiseOnlyBinCenters, obj.noiseOnlyBinResponses,...
                            'Parent', obj.axesHandle(2),'Color','k','LineStyle','-','Marker','o',...
                            'DisplayName','Noise Only');
                    else
                        set(obj.noiseOnlyLnDataHandle, 'XData', obj.noiseOnlyBinCenters, 'YData', obj.noiseOnlyBinResponses);
                    end
                    
                    legend(obj.axesHandle(1), 'show');
                    legend(obj.axesHandle(2), 'show');
                end

            end

        end
    end
end
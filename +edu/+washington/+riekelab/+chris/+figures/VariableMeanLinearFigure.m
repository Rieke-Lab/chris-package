classdef VariableMeanLinearFigure < symphonyui.core.FigureHandler

    properties (SetAccess = private)
        ampDevice
        frameMonitor
        stageDevice
        recordingType
        preTime
        stimTime
        frameDwell
        noiseStdv
        seedID
        figureTitle
        groupBy
    end

    properties (Access = private)
        axesHandle
        lineHandles
        lnDataHandles
        noiseStream
        allStimuli
        allResponses
        filters
        epochCounts
        legendLabels
        colorOrder
    end

    methods

        function obj = VariableMeanLinearFigure(ampDevice, frameMonitor, stageDevice, varargin)
            obj.ampDevice = ampDevice;
            obj.frameMonitor = frameMonitor;
            obj.stageDevice = stageDevice;

            ip = inputParser();
            ip.addParameter('recordingType', [], @(x) ischar(x));
            ip.addParameter('preTime', [], @(x) isvector(x));
            ip.addParameter('stimTime', [], @(x) isvector(x));
            ip.addParameter('frameDwell', [], @(x) isvector(x));
            ip.addParameter('noiseStdv', 0.3, @(x) isvector(x));
            ip.addParameter('seedID', 'noiseSeed', @(x) ischar(x));
            ip.addParameter('figureTitle', 'Grouped LN Analysis', @(x) ischar(x));
            ip.addParameter('groupBy', {}, @(x) iscellstr(x));
            ip.parse(varargin{:});

            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameDwell = ip.Results.frameDwell;
            obj.noiseStdv = ip.Results.noiseStdv;
            obj.seedID = ip.Results.seedID;
            obj.figureTitle = ip.Results.figureTitle;
            obj.groupBy = ip.Results.groupBy;

            obj.allStimuli = containers.Map();
            obj.allResponses = containers.Map();
            obj.filters = containers.Map();
            obj.epochCounts = containers.Map();
            obj.lineHandles = containers.Map();
            obj.lnDataHandles = containers.Map();
            obj.legendLabels = {};
            obj.colorOrder = get(groot, 'defaultAxesColorOrder');

            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;

            obj.axesHandle(1) = subplot(2,1,1,...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
            xlabel(obj.axesHandle(1), 'Time (ms)');
            ylabel(obj.axesHandle(1), 'Amp.');
            title(obj.axesHandle(1), 'Linear Filters');

            obj.axesHandle(2) = subplot(2,1,2,...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
            xlabel(obj.axesHandle(2), 'Linear prediction');
            ylabel(obj.axesHandle(2), 'Measured');
            title(obj.axesHandle(2), 'Nonlinearities');

            obj.figureHandle.Name = obj.figureTitle;

            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+utils\+icons\'];
            plotLNButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Plot nonlinearity', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedFitLN);
            setIconImage(plotLNButton, [iconDir, 'exp.png']);
        end

        function handleEpoch(obj, epoch)
            % Get group key
            groupKey = obj.getGroupKey(epoch);
            if ~isKey(obj.allStimuli, groupKey)
                obj.allStimuli(groupKey) = [];
                obj.allResponses(groupKey) = [];
                obj.epochCounts(groupKey) = 0;
            end
            obj.epochCounts(groupKey) = obj.epochCounts(groupKey) + 1;

            % Get response
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = sampleRate * obj.preTime / 1000;

            if strcmp(obj.recordingType, 'extracellular')
                S = edu.washington.riekelab.chris.utils.spikeDetectorOnline(epochResponseTrace);
                newResponse = zeros(size(epochResponseTrace));
                newResponse(S.sp) = 1;
            else
                epochResponseTrace = epochResponseTrace - mean(epochResponseTrace(1:prePts));
                polarity = strcmp(obj.recordingType, 'inh') - strcmp(obj.recordingType, 'exc');
                newResponse = polarity * epochResponseTrace;
            end

            % Get frame monitor data
            lightCrafterFlag = isa(obj.stageDevice, 'edu.washington.riekelab.devices.LightCrafterDevice');
            frameRate = obj.stageDevice.getMonitorRefreshRate();
            FMdata = epoch.getResponse(obj.frameMonitor).getData();
            frameTimes = edu.washington.riekelab.chris.utils.getFrameTiming(FMdata, lightCrafterFlag);
            preFrames = frameRate * obj.preTime / 1000;
            firstStimFrameFlip = frameTimes(preFrames + 1);
            newResponse = newResponse(firstStimFrameFlip:end);

            % Reconstruct stimulus
            filterLen = 800; % ms
            stimFrames = round(frameRate * (obj.stimTime / 1000));
            chunkLen = obj.frameDwell * floor(mean(diff(frameTimes)));
            currentNoiseSeed = epoch.parameters(obj.seedID);
            obj.noiseStream = RandStream('mt19937ar', 'Seed', currentNoiseSeed);

            noise = zeros(1, floor(stimFrames / obj.frameDwell));
            responseBinned = zeros(1, floor(stimFrames / obj.frameDwell));
            for ii = 1:length(noise)
                noise(ii) = obj.noiseStdv * obj.noiseStream.randn;
                responseBinned(ii) = mean(newResponse(round((ii-1)*chunkLen + 1): round(ii*chunkLen)));
            end

            % Store
            obj.allStimuli(groupKey) = cat(1, obj.allStimuli(groupKey), noise);
            obj.allResponses(groupKey) = cat(1, obj.allResponses(groupKey), responseBinned);

            % Compute filter
            updateRate = frameRate / obj.frameDwell;
            freqCutoffFraction = 1;
            newFilter = edu.washington.riekelab.chris.utils.getLinearFilterOnline( ...
                obj.allStimuli(groupKey), obj.allResponses(groupKey), ...
                updateRate, freqCutoffFraction * updateRate);
            filterPts = (filterLen / 1000) * updateRate;
            newFilter = newFilter(1:filterPts);
            obj.filters(groupKey) = newFilter;

            % Plot
            filterTimes = linspace(0, filterLen, filterPts);
            colorIndex = mod(length(obj.legendLabels), size(obj.colorOrder, 1)) + 1;

            if ~isKey(obj.lineHandles, groupKey)
                obj.lineHandles(groupKey) = line(filterTimes, newFilter, ...
                    'Parent', obj.axesHandle(1), 'LineWidth', 2, 'Color', obj.colorOrder(colorIndex, :));
                obj.legendLabels{end+1} = groupKey;
            else
                set(obj.lineHandles(groupKey), 'YData', newFilter);
            end

            legend(obj.axesHandle(1), obj.legendLabels, 'Interpreter', 'none');
        end

        function onSelectedFitLN(obj, ~, ~)
            keys = obj.filters.keys;
            cla(obj.axesHandle(2));
            hold(obj.axesHandle(2), 'on');

            for i = 1:length(keys)
                groupKey = keys{i};
                filt = obj.filters(groupKey);
                stim = reshape(obj.allStimuli(groupKey)', 1, []);
                resp = reshape(obj.allResponses(groupKey)', 1, []);
                linPred = conv(stim, filt, 'same');
                [~, edges, bin] = histcounts(linPred, 'BinMethod', 'auto');
                binCtrs = edges(1:end-1) + diff(edges)/2;

                binResp = zeros(size(binCtrs));
                for b = 1:length(binCtrs)
                    binResp(b) = mean(resp(bin == b));
                end

                colorIndex = mod(i-1, size(obj.colorOrder, 1)) + 1;
                obj.lnDataHandles(groupKey) = line(binCtrs, binResp, ...
                    'Parent', obj.axesHandle(2), 'LineStyle', 'none', ...
                    'Marker', 'o', 'Color', obj.colorOrder(colorIndex, :));
            end

            legend(obj.axesHandle(2), obj.legendLabels, 'Interpreter', 'none');
        end
    end

    methods (Access = private)

        function key = getGroupKey(obj, epoch)
            if isempty(obj.groupBy)
                key = 'All';
            else
                parts = cell(1, length(obj.groupBy));
                p = epoch.parameters;
                for i = 1:length(obj.groupBy)
                    val = p(obj.groupBy{i});
                    if isnumeric(val)
                        val = num2str(val);
                    end
                    parts{i} = [obj.groupBy{i} '=' val];
                end
                key = strjoin(parts, ', ');
            end
        end

    end
end

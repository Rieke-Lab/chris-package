classdef SplitFieldFilterFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        frameMonitor
        stageDevice
        recordingType
        preTime
        stimTime
        frameDwell
        leftMeanIntensity
        figureTitle
    end
    
    properties (Access = private)
        axesHandle
        lineHandles
        lnDataHandles
        leftMeanValues
        rightFieldStimuli
        allResponses
        newFilters
        epochCount
        uniqueMeans
        colorMap
    end
    
    methods
        
        function obj = SplitFieldFilterFigure(ampDevice, frameMonitor, stageDevice, varargin)
            obj.ampDevice = ampDevice;
            obj.frameMonitor = frameMonitor;
            obj.stageDevice = stageDevice;
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('frameDwell', [], @(x)isvector(x));
            ip.addParameter('leftMeanIntensity', [0.08 0.65], @(x)isvector(x));
            ip.addParameter('figureTitle','Split Field Linear-Nonlinear analysis', @(x)ischar(x));
            ip.parse(varargin{:});
            
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameDwell = ip.Results.frameDwell;
            obj.leftMeanIntensity = ip.Results.leftMeanIntensity;
            obj.figureTitle = ip.Results.figureTitle;

            % Initialize data structures for each unique left mean intensity
            obj.uniqueMeans = unique(obj.leftMeanIntensity);
            numMeans = length(obj.uniqueMeans);
            
            % Create a colormap for different mean intensities
            obj.colorMap = hsv(numMeans);
            
            % Initialize data structures
            obj.rightFieldStimuli = cell(numMeans, 1);
            obj.allResponses = cell(numMeans, 1);
            obj.newFilters = cell(numMeans, 1);
            obj.lineHandles = cell(numMeans, 1);
            obj.lnDataHandles = cell(numMeans, 1);
            
            obj.leftMeanValues = [];
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
            title(obj.axesHandle(1),'Linear filters by left field intensity');
            
            obj.axesHandle(2) = subplot(2,1,2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(2), 'Linear prediction');
            ylabel(obj.axesHandle(2), 'Measured');
            title(obj.axesHandle(2),'Nonlinearities by left field intensity');
            
            % Add a legend
            legend_entries = cell(length(obj.uniqueMeans), 1);
            for i = 1:length(obj.uniqueMeans)
                legend_entries{i} = ['Left mean = ', num2str(obj.uniqueMeans(i))];
            end
            legend(obj.axesHandle(1), legend_entries, 'Location', 'northeast');
            
            obj.figureHandle.Name = obj.figureTitle;
        end

        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            
            % Get current left mean intensity for this epoch
            currentLeftMean = epoch.parameters('currentLeftMean');
            
            % Find which group this left mean belongs to
            meanIndex = find(obj.uniqueMeans == currentLeftMean);
            
            % Load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = sampleRate*obj.preTime/1000;
            
            % Process response based on recording type
            if strcmp(obj.recordingType,'extracellular') % spike recording
                newResponse = zeros(size(epochResponseTrace));
                % Count spikes
                S = edu.washington.riekelab.chris.utils.spikeDetectorOnline(epochResponseTrace);
                newResponse(S.sp) = 1;
            else % intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:prePts)); % baseline
                if strcmp(obj.recordingType,'exc') % measuring exc
                    polarity = -1;
                elseif strcmp(obj.recordingType,'inh') % measuring inh
                    polarity = 1;
                end
                newResponse = polarity * epochResponseTrace;
            end
            
            % Load frame monitor data
            if isa(obj.stageDevice,'edu.washington.riekelab.devices.LightCrafterDevice')
                lightCrafterFlag = 1;
            else % OLED stage device
                lightCrafterFlag = 0;
            end
            frameRate = obj.stageDevice.getMonitorRefreshRate();
            FMresponse = epoch.getResponse(obj.frameMonitor);
            FMdata = FMresponse.getData();
            frameTimes = edu.washington.riekelab.chris.utils.getFrameTiming(FMdata, lightCrafterFlag);
            preFrames = frameRate*(obj.preTime/1000);
            
            % Skip pre-frames
            if preFrames > 0
                firstStimFrameFlip = frameTimes(preFrames+1);
                newResponse = newResponse(firstStimFrameFlip:end);
            end
            
            % Get right field noise stimulus directly from epoch parameters
            rightFieldIntensityOverFrame = epoch.parameters('rightFieldIntensityOverFrame');
            
            % Downsample response to match stimulus update rate
            stimFrames = length(rightFieldIntensityOverFrame);
            response = zeros(1, stimFrames);
            
            % Get response at each noise update frame
            chunkLen = obj.frameDwell*mean(diff(frameTimes));
            for ii = 1:stimFrames
                if ii*chunkLen <= length(newResponse)
                    response(ii) = mean(newResponse(round((ii-1)*chunkLen + 1) : round(ii*chunkLen)));
                end
            end
            
            % Add to stored data for this mean intensity
            if isempty(obj.rightFieldStimuli{meanIndex})
                obj.rightFieldStimuli{meanIndex} = rightFieldIntensityOverFrame;
                obj.allResponses{meanIndex} = response;
            else
                obj.rightFieldStimuli{meanIndex} = cat(1, obj.rightFieldStimuli{meanIndex}, rightFieldIntensityOverFrame);
                obj.allResponses{meanIndex} = cat(1, obj.allResponses{meanIndex}, response);
            end
            
            % Calculate and update linear filter for this mean intensity
            updateRate = (frameRate/obj.frameDwell); % hz
            filterLen = 800; % msec, length of linear filter to compute
            freqCutoffFraction = 0.5; % fraction of noise update rate at which to cut off filter spectrum
            
            obj.newFilters{meanIndex} = edu.washington.riekelab.chris.utils.getLinearFilterOnline(...
                obj.rightFieldStimuli{meanIndex}, obj.allResponses{meanIndex}, ...
                updateRate, freqCutoffFraction*updateRate);
            
            filterPts = (filterLen/1000)*updateRate;
            filterTimes = linspace(0, filterLen, filterPts); % msec
            
            % Ensure the filter isn't longer than what we can display
            if length(obj.newFilters{meanIndex}) >= filterPts
                obj.newFilters{meanIndex} = obj.newFilters{meanIndex}(1:filterPts);
            else
                % Pad with zeros if needed
                padSize = filterPts - length(obj.newFilters{meanIndex});
                obj.newFilters{meanIndex} = [obj.newFilters{meanIndex}; zeros(padSize, 1)];
            end
            
            % Plot the filter
            if isempty(obj.lineHandles{meanIndex})
                % Create new line
                obj.lineHandles{meanIndex} = line(filterTimes, obj.newFilters{meanIndex}, ...
                    'Parent', obj.axesHandle(1), 'LineWidth', 2, 'Color', obj.colorMap(meanIndex,:));
                
                % Add zero line if it's the first one
                if meanIndex == 1
                    line([filterTimes(1) filterTimes(end)], [0 0], ...
                        'Parent', obj.axesHandle(1), 'Color', 'k', ...
                        'Marker', 'none', 'LineStyle', '--');
                end
            else
                % Update existing line
                set(obj.lineHandles{meanIndex}, 'YData', obj.newFilters{meanIndex});
            end
            
            % Update nonlinearity plot after every epoch
            obj.onSelectedFitLN();
        end
    end
    
    methods (Access = private)
        
        function onSelectedFitLN(obj, ~, ~)
            % Calculate and plot nonlinearity for each mean intensity
            for meanIndex = 1:length(obj.uniqueMeans)
                % Skip if no data for this mean
                if isempty(obj.rightFieldStimuli{meanIndex}) || isempty(obj.allResponses{meanIndex})
                    continue;
                end
                
                % Reshape data
                measuredResponse = reshape(obj.allResponses{meanIndex}', 1, numel(obj.allResponses{meanIndex}));
                stimulusArray = reshape(obj.rightFieldStimuli{meanIndex}', 1, numel(obj.rightFieldStimuli{meanIndex}));
                
                % Calculate linear prediction
                linearPrediction = conv(stimulusArray, obj.newFilters{meanIndex});
                linearPrediction = linearPrediction(1:length(stimulusArray));
                
                % Bin responses by linear prediction
                [~, edges, bin] = histcounts(linearPrediction, 'BinMethod', 'auto');
                binCtrs = edges(1:end-1) + diff(edges);
                
                binResp = zeros(size(binCtrs));
                for bb = 1:length(binCtrs)
                    binResp(bb) = mean(measuredResponse(bin == bb)); 
                end
                
                % Plot or update nonlinearity
                if isempty(obj.lnDataHandles{meanIndex})
                    % Create new plot
                    obj.lnDataHandles{meanIndex} = line(binCtrs, binResp, ...
                        'Parent', obj.axesHandle(2), 'LineStyle', '-', 'Marker', 'o', ...
                        'MarkerSize', 4, 'Color', obj.colorMap(meanIndex,:));
                    
                    % Add zero lines if it's the first one
                    if meanIndex == 1
                        limDown = min([linearPrediction measuredResponse]);
                        limUp = max([linearPrediction measuredResponse]);
                        
                        % Add horizontal and vertical zero lines
                        line([limDown limUp], [0 0], ...
                            'Parent', obj.axesHandle(2), 'Color', 'k', ...
                            'Marker', 'none', 'LineStyle', '--');
                        line([0 0], [limDown limUp], ...
                            'Parent', obj.axesHandle(2), 'Color', 'k', ...
                            'Marker', 'none', 'LineStyle', '--');
                    end
                else
                    % Update existing plot
                    set(obj.lnDataHandles{meanIndex}, 'YData', binResp, 'XData', binCtrs);
                end
            end
        end
    end
end
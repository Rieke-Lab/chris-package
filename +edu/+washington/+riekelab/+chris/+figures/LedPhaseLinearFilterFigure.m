classdef LedPhaseLinearFilterFigure < symphonyui.core.FigureHandler

    properties (SetAccess = private)
        ampDevice
        ledDevice
        recordingType
        preTime
        stimTime
        sampleRate  % Added sample rate property
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
        allNoiseOnlyStimuli
        allNoiseOnlyResponses

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

        filterPts
        filterTimes
        epochCount
    end

    methods

        function obj = LedPhaseLinearFilterFigure(ampDevice, ledDevice, varargin)
            obj.ampDevice = ampDevice;
            obj.ledDevice = ledDevice;
            
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('sampleRate', 1000, @(x)isnumeric(x)); % Default to 1000 Hz but allow override
            ip.addParameter('figureTitle','LED Phase-separated Linear-Nonlinear analysis', @(x)ischar(x));
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

            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.sampleRate = ip.Results.sampleRate;
            obj.figureTitle = ip.Results.figureTitle;

            obj.allRisingStimuli = [];
            obj.allRisingResponses = [];
            obj.allFallingStimuli = [];
            obj.allFallingResponses = [];
            obj.allNoiseOnlyStimuli = [];
            obj.allNoiseOnlyResponses = [];
            obj.epochCount = 0;

            % Precalculate filter parameters
            filterLen = 800; % msec
            obj.filterPts = (filterLen/1000)*obj.sampleRate;
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
            
            % Load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            responseSampleRate = response.sampleRate.quantityInBaseUnits;
            
            % Determine response type based on recording type
            if strcmp(obj.recordingType,'extracellular') % Spike recording
                newResponse = zeros(size(epochResponseTrace));
                % Count spikes
                % Check if function exists and call it, otherwise provide alternative
                try
                    S = edu.washington.riekelab.utils.spikeDetectorOnline(epochResponseTrace);
                    newResponse(S.sp) = 1;
                catch
                    % Simple threshold-based spike detection if custom function not available
                    threshold = mean(epochResponseTrace) + 5 * std(epochResponseTrace);
                    [~, spikeTimes] = findpeaks(epochResponseTrace, 'MinPeakHeight', threshold);
                    newResponse(spikeTimes) = 1;
                end
            else 
                % Subtract baseline
                baseline = mean(epochResponseTrace(1:round(responseSampleRate*obj.preTime/1000)));
                epochResponseTrace = epochResponseTrace - baseline;
                
                % Apply polarity adjustment based on recording type
                if strcmp(obj.recordingType,'exc') % Measuring excitation
                    polarity = -1;
                elseif strcmp(obj.recordingType,'inh') % Measuring inhibition
                    polarity = 1;
                else
                    polarity = 1; % Default
                end
                newResponse = polarity * epochResponseTrace;
            end
            
            % Get stimulus values from epoch parameters
            if isKey(epoch.parameters, 'sinusoidValues')
                sinusoidValues = epoch.parameters('sinusoidValues');
            else
                error('Epoch missing required sinusoidValues parameter');
            end
            
            if isKey(epoch.parameters, 'noiseValues')
                noiseValues = epoch.parameters('noiseValues');
            else
                error('Epoch missing required noiseValues parameter');
            end
            
            % Calculate time points for each sample
            responseTime = (1:length(newResponse))/responseSampleRate;
            
            % Remove pre-time from response
            prePts = round(responseSampleRate*obj.preTime/1000);
            if prePts > 0
                newResponse = newResponse(prePts+1:end);
                responseTime = responseTime(prePts+1:end) - obj.preTime/1000;
            end
            
            % For LED stimulus, resample the response to match the stimulus rate
            targetLength = round(obj.stimTime/1000 * obj.sampleRate);
            responseResample = interp1(responseTime, newResponse, linspace(0, obj.stimTime/1000, targetLength));
            
            if strcmp(stimulusTag, 'sinusoidPlusNoise')
                % Extract the sinusoid without the mean
                meanValue = mean(sinusoidValues);
                sinusoidOnly = sinusoidValues - meanValue;
                
                % Calculate derivative to determine rising and falling phases
                sinusoidDiff = [0, diff(sinusoidOnly)];
                isRising = sinusoidDiff > 0;
                
                % Remove pre and post time from stimuli
                stimSampleRate = length(sinusoidValues) / ((obj.preTime + obj.stimTime + obj.tailTime) / 1000);
                prePostPts = round(stimSampleRate*(obj.preTime)/1000);
                if prePostPts > 0
                    sinusoidOnly = sinusoidOnly(prePostPts+1:end-prePostPts);
                    noiseValues = noiseValues(prePostPts+1:end-prePostPts);
                    isRising = isRising(prePostPts+1:end-prePostPts);
                end
                
                % Resample stimulus to target sample rate
                stimResampleTimes = linspace(0, obj.stimTime/1000, targetLength);
                stimOriginalTimes = linspace(0, obj.stimTime/1000, length(isRising));
                
                isRisingResample = interp1(stimOriginalTimes, double(isRising), stimResampleTimes, 'nearest');
                isRisingResample = isRisingResample > 0.5; % Convert back to logical
                
                noiseResample = interp1(stimOriginalTimes, noiseValues - meanValue, stimResampleTimes);
                
                % Split noise and response by phase
                risingIndices = find(isRisingResample);
                fallingIndices = find(~isRisingResample);
                
                risingNoise = noiseResample(risingIndices);
                fallingNoise = noiseResample(fallingIndices);
                
                risingResponse = responseResample(risingIndices);
                fallingResponse = responseResample(fallingIndices);
                
                % Accumulate phase-specific data
                obj.allRisingStimuli = cat(2, obj.allRisingStimuli, risingNoise);
                obj.allRisingResponses = cat(2, obj.allRisingResponses, risingResponse);
                obj.allFallingStimuli = cat(2, obj.allFallingStimuli, fallingNoise);
                obj.allFallingResponses = cat(2, obj.allFallingResponses, fallingResponse);
                
            elseif strcmp(stimulusTag, 'noiseOnly')
                % Process noise-only epochs
                meanValue = mean(noiseValues);
                
                % Remove pre and post time from stimuli
                stimSampleRate = length(noiseValues) / ((obj.preTime + obj.stimTime + obj.tailTime) / 1000);
                prePostPts = round(stimSampleRate*(obj.preTime)/1000);
                if prePostPts > 0
                    noiseValues = noiseValues(prePostPts+1:end-prePostPts);
                end
                
                % Resample stimulus to target sample rate
                stimResampleTimes = linspace(0, obj.stimTime/1000, targetLength);
                stimOriginalTimes = linspace(0, obj.stimTime/1000, length(noiseValues));
                
                noiseResample = interp1(stimOriginalTimes, noiseValues - meanValue, stimResampleTimes);
                
                % Accumulate noise-only data
                obj.allNoiseOnlyStimuli = cat(2, obj.allNoiseOnlyStimuli, noiseResample);
                obj.allNoiseOnlyResponses = cat(2, obj.allNoiseOnlyResponses, responseResample);
            end
            
            % Only compute filters if we have enough data
            if obj.epochCount > 3
                freqCutoffFraction = 0.5 * obj.sampleRate; % Half the sample rate as cutoff
                
                % Initialize plot handles if needed
                if isempty(obj.risingLineHandle)
                    hold(obj.axesHandle(1), 'on');
                    hold(obj.axesHandle(2), 'on');
                end
                
                % Compute filters if we have data for both phases
                if ~isempty(obj.allRisingStimuli) && ~isempty(obj.allFallingStimuli)
                    % Use the provided function for filter calculation
                    obj.risingFilter = obj.getLinearFilterOnline(...
                        obj.allRisingStimuli, obj.allRisingResponses, obj.sampleRate, freqCutoffFraction);
                    
                    obj.fallingFilter = obj.getLinearFilterOnline(...
                        obj.allFallingStimuli, obj.allFallingResponses, obj.sampleRate, freqCutoffFraction);
                    
                    % Ensure filters are the correct length
                    if length(obj.risingFilter) >= obj.filterPts
                        obj.risingFilter = obj.risingFilter(1:obj.filterPts);
                        obj.fallingFilter = obj.fallingFilter(1:obj.filterPts);
                    else
                        % Pad with zeros if too short
                        obj.risingFilter = [obj.risingFilter, zeros(1, obj.filterPts - length(obj.risingFilter))];
                        obj.fallingFilter = [obj.fallingFilter, zeros(1, obj.filterPts - length(obj.fallingFilter))];
                    end
                    
                    % Update filter plots
                    if isempty(obj.risingLineHandle)
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
                    
                    % Calculate nonlinearities for rising phase
                    risingPrediction = obj.computePrediction(obj.allRisingStimuli, obj.risingFilter);
                    
                    % Get binned responses for rising phase
                    [obj.risingBinCenters, obj.risingBinResponses] = ...
                        obj.computeNonlinearity(risingPrediction, obj.allRisingResponses);
                    
                    % Calculate nonlinearities for falling phase
                    fallingPrediction = obj.computePrediction(obj.allFallingStimuli, obj.fallingFilter);
                    
                    % Get binned responses for falling phase
                    [obj.fallingBinCenters, obj.fallingBinResponses] = ...
                        obj.computeNonlinearity(fallingPrediction, obj.allFallingResponses);
                    
                    % Update nonlinearity plots
                    if isempty(obj.risingLnDataHandle)
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
                end
                
                % Process noise-only data if available
                if ~isempty(obj.allNoiseOnlyStimuli)
                    % Use the provided function for filter calculation
                    obj.noiseOnlyFilter = obj.getLinearFilterOnline(...
                        obj.allNoiseOnlyStimuli, obj.allNoiseOnlyResponses, obj.sampleRate, freqCutoffFraction);
                    
                    % Ensure filter is the correct length
                    if length(obj.noiseOnlyFilter) >= obj.filterPts
                        obj.noiseOnlyFilter = obj.noiseOnlyFilter(1:obj.filterPts);
                    else
                        % Pad with zeros if too short
                        obj.noiseOnlyFilter = [obj.noiseOnlyFilter, zeros(1, obj.filterPts - length(obj.noiseOnlyFilter))];
                    end
                    
                    % Update filter plot
                    if isempty(obj.noiseOnlyLineHandle)
                        obj.noiseOnlyLineHandle = line(obj.filterTimes, obj.noiseOnlyFilter,...
                            'Parent', obj.axesHandle(1),'LineWidth',2,'Color','k',...
                            'DisplayName','Noise Only');
                    else
                        set(obj.noiseOnlyLineHandle, 'YData', obj.noiseOnlyFilter);
                    end
                    
                    % Calculate noise-only nonlinearity
                    noisePrediction = obj.computePrediction(obj.allNoiseOnlyStimuli, obj.noiseOnlyFilter);
                    
                    % Get binned responses for noise-only
                    [obj.noiseOnlyBinCenters, obj.noiseOnlyBinResponses] = ...
                        obj.computeNonlinearity(noisePrediction, obj.allNoiseOnlyResponses);
                    
                    % Update noise-only nonlinearity plot
                    if isempty(obj.noiseOnlyLnDataHandle)
                        obj.noiseOnlyLnDataHandle = line(obj.noiseOnlyBinCenters, obj.noiseOnlyBinResponses,...
                            'Parent', obj.axesHandle(2),'Color','k','LineStyle','-','Marker','o',...
                            'DisplayName','Noise Only');
                    else
                        set(obj.noiseOnlyLnDataHandle, 'XData', obj.noiseOnlyBinCenters, 'YData', obj.noiseOnlyBinResponses);
                    end
                end
                
                % Update legends
                legend(obj.axesHandle(1), 'show');
                legend(obj.axesHandle(2), 'show');
            end
        end
        
        % Using the provided function for linear filter calculation
        function linearFilter = getLinearFilterOnline(obj, stimulus, response, sampleRate, freqCutoff)
            % This function will find the linear filter that changes row vector "signal" into a set of "responses" in rows. 
            % samplerate and freqCutoff (which should be the highest frequency in the signal) should be in Hz.
            % The linear filter is a cc normalized by the power spectrum of the signal.
            % JC 3/31/08
            % MHT 080814
            % For rows as trials.
            filterFft = mean((fft(response,[],2).*conj(fft(stimulus,[],2))),1)./mean(fft(stimulus,[],2).*conj(fft(stimulus,[],2)),1);
            freqcutoffAdjusted = round(freqCutoff/(sampleRate/length(stimulus))); % this adjusts the freq cutoff for the length
            filterFft(:, 1+freqcutoffAdjusted:length(stimulus)-freqcutoffAdjusted) = 0; 
            linearFilter = real(ifft(filterFft));
        end
        
        function prediction = computePrediction(obj, stimulus, filter)
            % Compute the linear prediction from stimulus and filter
            stimulus = reshape(stimulus, 1, []);
            prediction = conv(stimulus, filter);
            prediction = prediction(1:length(stimulus));
        end
        
        function [binCenters, binResponses] = computeNonlinearity(obj, prediction, response)
            % Calculate nonlinearity from prediction and response
            prediction = reshape(prediction, 1, []);
            response = reshape(response, 1, []);
            
            % Create bins
            numBins = min(30, ceil(length(prediction)/100)); % Adjust number of bins based on data size
            [counts, edges] = histcounts(prediction, numBins);
            binCenters = edges(1:end-1) + diff(edges)/2;
            
            % Calculate mean response in each bin
            binResponses = zeros(size(binCenters));
            for b = 1:length(binCenters)
                indices = (prediction >= edges(b)) & (prediction < edges(b+1));
                if any(indices)
                    binResponses(b) = mean(response(indices));
                else
                    binResponses(b) = 0;
                end
            end
            
            % Remove bins with no data
            validBins = counts > 0;
            binCenters = binCenters(validBins);
            binResponses = binResponses(validBins);
        end
    end
end
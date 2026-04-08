classdef LedPhaseLinearFilterFigure < symphonyui.core.FigureHandler
    % Online LN analysis for LED stimuli with phase-separated filters.
    %
    % This version reconstructs stimulus components from epoch parameters
    % instead of relying on sinusoidValues/noiseValues being directly stored
    % in the epoch.
    %
    % Required epoch parameters:
    %   stimulusTag
    %   noiseSeed
    %   preTime
    %   stimTime
    %   tailTime
    %   meanIntensity
    %   noiseStdv
    %   temporalContrast
    %   temporalFrequency
    %   frequencyCutoff
    %   numberOfFilters
    %   stimulusSampleRate
    %
    % Optional epoch parameters:
    %   sinusoidValues
    %   noiseValues
    %
    % stimulusTag should be one of:
    %   'sinusoidOnly'
    %   'noiseOnly'
    %   'sinusoidPlusNoise'

    properties (SetAccess = private)
        ampDevice
        ledDevice
        recordingType
        preTime
        stimTime
        sampleRate
        figureTitle
    end

    properties (Access = private)
        axesHandle

        % Linear-filter plot handles
        risingLineHandle
        fallingLineHandle
        noiseOnlyLineHandle

        % Nonlinearity plot handles
        risingLnDataHandle
        fallingLnDataHandle
        noiseOnlyLnDataHandle

        % Average sinusoid-only response for subtraction
        sinusoidOnlyResponses

        % Accumulated data (rows = trials)
        allRisingStimuli
        allRisingResponses
        allFallingStimuli
        allFallingResponses
        allNoiseOnlyStimuli
        allNoiseOnlyResponses

        % Current filters
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
            ip.addParameter('recordingType', [], @(x)ischar(x) || isstring(x));
            ip.addParameter('preTime', [], @(x)isnumeric(x) && isscalar(x));
            ip.addParameter('stimTime', [], @(x)isnumeric(x) && isscalar(x));
            ip.addParameter('sampleRate', 1000, @(x)isnumeric(x) && isscalar(x) && x > 0);
            ip.addParameter('figureTitle', 'LED Phase-separated Linear-Nonlinear analysis', @(x)ischar(x) || isstring(x));
            ip.parse(varargin{:});

            if isempty(ip.Results.recordingType)
                error('LedPhaseLinearFilterFigure:MissingParam', 'recordingType parameter is required');
            end
            if isempty(ip.Results.preTime)
                error('LedPhaseLinearFilterFigure:MissingParam', 'preTime parameter is required');
            end
            if isempty(ip.Results.stimTime)
                error('LedPhaseLinearFilterFigure:MissingParam', 'stimTime parameter is required');
            end

            obj.recordingType = char(ip.Results.recordingType);
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.sampleRate = ip.Results.sampleRate;
            obj.figureTitle = char(ip.Results.figureTitle);

            obj.sinusoidOnlyResponses = [];

            obj.allRisingStimuli = [];
            obj.allRisingResponses = [];
            obj.allFallingStimuli = [];
            obj.allFallingResponses = [];
            obj.allNoiseOnlyStimuli = [];
            obj.allNoiseOnlyResponses = [];

            obj.risingFilter = [];
            obj.fallingFilter = [];
            obj.noiseOnlyFilter = [];

            obj.risingBinCenters = [];
            obj.risingBinResponses = [];
            obj.fallingBinCenters = [];
            obj.fallingBinResponses = [];
            obj.noiseOnlyBinCenters = [];
            obj.noiseOnlyBinResponses = [];

            obj.epochCount = 0;

            filterLenMs = 800;
            obj.filterPts = max(1, round((filterLenMs / 1000) * obj.sampleRate));
            obj.filterTimes = (0:obj.filterPts-1) / obj.sampleRate * 1000;

            obj.createUi();
        end

        function createUi(obj)
            obj.axesHandle(1) = subplot(2,1,1, ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(1), 'Time (ms)');
            ylabel(obj.axesHandle(1), 'Filter amplitude');
            title(obj.axesHandle(1), 'Linear filters');
            hold(obj.axesHandle(1), 'on');

            obj.axesHandle(2) = subplot(2,1,2, ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(2), 'Generator signal');
            ylabel(obj.axesHandle(2), 'Measured response');
            title(obj.axesHandle(2), 'Phase-specific nonlinearities');
            hold(obj.axesHandle(2), 'on');

            obj.figureHandle.Name = obj.figureTitle;
        end

        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;

            % ----------------------------
            % Required epoch metadata
            % ----------------------------
            if ~isKey(epoch.parameters, 'stimulusTag')
                warning('LedPhaseLinearFilterFigure:MissingStimulusTag', ...
                    'Epoch missing stimulusTag. Skipping epoch.');
                return;
            end
            stimulusTag = char(epoch.parameters('stimulusTag'));

            % ----------------------------
            % Load response
            % ----------------------------
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = double(response.getData());
            responseSampleRate = response.sampleRate.quantityInBaseUnits;

            newResponse = obj.convertResponseTrace(epochResponseTrace, responseSampleRate);

            % Remove pre-time from response
            prePtsResp = round(responseSampleRate * obj.preTime / 1000);
            if prePtsResp >= numel(newResponse)
                warning('LedPhaseLinearFilterFigure:BadPreTime', ...
                    'preTime removes entire response trace. Skipping epoch.');
                return;
            end

            responseTime = (0:numel(newResponse)-1) / responseSampleRate;
            if prePtsResp > 0
                newResponse = newResponse(prePtsResp+1:end);
                responseTime = responseTime(prePtsResp+1:end) - obj.preTime / 1000;
            end

            targetLength = max(1, round(obj.stimTime / 1000 * obj.sampleRate));
            queryTimes = (0:targetLength-1) / obj.sampleRate;
            responseResample = interp1(responseTime, newResponse, queryTimes, 'linear', 'extrap');
            responseResample = responseResample(:)';

            % ----------------------------
            % Get or reconstruct stimulus components
            % ----------------------------
            sinusoidValues = [];
            noiseValues = [];

            if isKey(epoch.parameters, 'sinusoidValues')
                sinusoidValues = epoch.parameters('sinusoidValues');
            end
            if isKey(epoch.parameters, 'noiseValues')
                noiseValues = epoch.parameters('noiseValues');
            end

            if isempty(sinusoidValues) || isempty(noiseValues)
                [sinusoidValues, noiseValues] = obj.reconstructStimulusComponents(epoch);
            end

            if isempty(sinusoidValues) || isempty(noiseValues)
                warning('LedPhaseLinearFilterFigure:MissingStimulusComponents', ...
                    'Could not obtain sinusoidValues/noiseValues. Skipping epoch.');
                return;
            end

            sinusoidValues = double(sinusoidValues(:))';
            noiseValues = double(noiseValues(:))';

            % ----------------------------
            % Dispatch by stimulus type
            % ----------------------------
            switch stimulusTag
                case 'sinusoidOnly'
                    obj.handleSinusoidOnlyEpoch(epoch, responseResample, targetLength, sinusoidValues);

                case 'sinusoidPlusNoise'
                    obj.handleSinusoidPlusNoiseEpoch(epoch, responseResample, targetLength, sinusoidValues, noiseValues);

                case 'noiseOnly'
                    obj.handleNoiseOnlyEpoch(epoch, responseResample, targetLength, noiseValues);

                otherwise
                    warning('LedPhaseLinearFilterFigure:UnknownStimulusTag', ...
                        'Unknown stimulusTag "%s". Skipping epoch.', stimulusTag);
                    return;
            end

            obj.updateOnlineAnalysis();
        end

        function clearFigure(obj)
            cla(obj.axesHandle(1));
            cla(obj.axesHandle(2));

            obj.risingLineHandle = [];
            obj.fallingLineHandle = [];
            obj.noiseOnlyLineHandle = [];
            obj.risingLnDataHandle = [];
            obj.fallingLnDataHandle = [];
            obj.noiseOnlyLnDataHandle = [];

            obj.sinusoidOnlyResponses = [];

            obj.allRisingStimuli = [];
            obj.allRisingResponses = [];
            obj.allFallingStimuli = [];
            obj.allFallingResponses = [];
            obj.allNoiseOnlyStimuli = [];
            obj.allNoiseOnlyResponses = [];

            obj.risingFilter = [];
            obj.fallingFilter = [];
            obj.noiseOnlyFilter = [];

            obj.risingBinCenters = [];
            obj.risingBinResponses = [];
            obj.fallingBinCenters = [];
            obj.fallingBinResponses = [];
            obj.noiseOnlyBinCenters = [];
            obj.noiseOnlyBinResponses = [];

            obj.epochCount = 0;

            xlabel(obj.axesHandle(1), 'Time (ms)');
            ylabel(obj.axesHandle(1), 'Filter amplitude');
            title(obj.axesHandle(1), 'Linear filters');
            hold(obj.axesHandle(1), 'on');

            xlabel(obj.axesHandle(2), 'Generator signal');
            ylabel(obj.axesHandle(2), 'Measured response');
            title(obj.axesHandle(2), 'Phase-specific nonlinearities');
            hold(obj.axesHandle(2), 'on');
        end
    end

    methods (Access = private)

        function newResponse = convertResponseTrace(obj, epochResponseTrace, responseSampleRate)
            switch lower(obj.recordingType)
                case 'extracellular'
                    newResponse = zeros(size(epochResponseTrace));
                    
                    S = edu.washington.riekelab.chris.utils.spikeDetectorOnline(epochResponseTrace);
                    if isfield(S, 'sp') && ~isempty(S.sp)
                        sp = S.sp;
                        sp = sp(sp >= 1 & sp <= numel(newResponse));
                        newResponse(sp) = 1;
                    end


                otherwise
                    basePts = max(1, round(responseSampleRate * obj.preTime / 1000));
                    basePts = min(basePts, numel(epochResponseTrace));
                    baseline = mean(epochResponseTrace(1:basePts));
                    epochResponseTrace = epochResponseTrace - baseline;

                    switch lower(obj.recordingType)
                        case 'exc'
                            polarity = -1;
                        case 'inh'
                            polarity = 1;
                        otherwise
                            polarity = 1;
                    end
                    newResponse = polarity * epochResponseTrace;
            end

            newResponse = double(newResponse(:))';
        end

        function handleSinusoidOnlyEpoch(obj, epoch, responseResample, targetLength, sinusoidValues)
            tailTime = obj.getEpochParamOrDefault(epoch, 'tailTime', 0);
            [sinusoidStim, ~] = obj.trimStimulusToStimWindow(epoch, sinusoidValues, tailTime);

            stimResample = obj.resampleStimulus(epoch, sinusoidStim, targetLength); %#ok<NASGU>

            obj.sinusoidOnlyResponses = cat(1, obj.sinusoidOnlyResponses, responseResample);
        end

        function handleSinusoidPlusNoiseEpoch(obj, epoch, responseResample, targetLength, sinusoidValues, noiseValues)
            tailTime = obj.getEpochParamOrDefault(epoch, 'tailTime', 0);

            [sinusoidStim, stimSampleRate] = obj.trimStimulusToStimWindow(epoch, sinusoidValues, tailTime);
            [noiseStim, ~] = obj.trimStimulusToStimWindow(epoch, noiseValues, tailTime);

            if isempty(sinusoidStim) || isempty(noiseStim)
                warning('LedPhaseLinearFilterFigure:EmptyStimulus', ...
                    'Stimulus became empty after trimming. Skipping epoch.');
                return;
            end

            sinusoidStim = sinusoidStim - mean(sinusoidStim);
            noiseStim = noiseStim - mean(noiseStim);

            dSin = [0, diff(sinusoidStim)];
            isRising = dSin > 0;

            stimTimes = (0:numel(noiseStim)-1) / stimSampleRate;
            queryTimes = (0:targetLength-1) / obj.sampleRate;

            noiseResample = interp1(stimTimes, noiseStim, queryTimes, 'linear', 'extrap');
            isRisingResample = interp1(stimTimes, double(isRising), queryTimes, 'nearest', 'extrap') > 0.5;

            if ~isempty(obj.sinusoidOnlyResponses)
                avgSinusoidResponse = mean(obj.sinusoidOnlyResponses, 1, 'omitnan');
                if numel(avgSinusoidResponse) == numel(responseResample)
                    responseResample = responseResample - avgSinusoidResponse;
                else
                    warning('LedPhaseLinearFilterFigure:SinusoidResponseSizeMismatch', ...
                        'sinusoidOnlyResponse length mismatch. Skipping subtraction.');
                end
            end

            risingIdx = isRisingResample(:)' == 1;
            fallingIdx = ~risingIdx;

            risingNoise = noiseResample(risingIdx);
            risingResponse = responseResample(risingIdx);

            fallingNoise = noiseResample(fallingIdx);
            fallingResponse = responseResample(fallingIdx);

            if numel(risingNoise) >= 5 && numel(risingNoise) == numel(risingResponse)
                obj.allRisingStimuli = obj.appendTrialRow(obj.allRisingStimuli, risingNoise);
                obj.allRisingResponses = obj.appendTrialRow(obj.allRisingResponses, risingResponse);
            end

            if numel(fallingNoise) >= 5 && numel(fallingNoise) == numel(fallingResponse)
                obj.allFallingStimuli = obj.appendTrialRow(obj.allFallingStimuli, fallingNoise);
                obj.allFallingResponses = obj.appendTrialRow(obj.allFallingResponses, fallingResponse);
            end
        end

        function handleNoiseOnlyEpoch(obj, epoch, responseResample, targetLength, noiseValues)
            tailTime = obj.getEpochParamOrDefault(epoch, 'tailTime', 0);

            [noiseStim, stimSampleRate] = obj.trimStimulusToStimWindow(epoch, noiseValues, tailTime);
            if isempty(noiseStim)
                warning('LedPhaseLinearFilterFigure:EmptyNoiseStimulus', ...
                    'Noise-only stimulus became empty after trimming. Skipping epoch.');
                return;
            end

            noiseStim = noiseStim - mean(noiseStim);

            stimTimes = (0:numel(noiseStim)-1) / stimSampleRate;
            queryTimes = (0:targetLength-1) / obj.sampleRate;
            noiseResample = interp1(stimTimes, noiseStim, queryTimes, 'linear', 'extrap');

            if numel(noiseResample) ~= numel(responseResample)
                warning('LedPhaseLinearFilterFigure:NoiseResponseMismatch', ...
                    'noiseOnly stimulus/response length mismatch. Skipping epoch.');
                return;
            end

            obj.allNoiseOnlyStimuli = obj.appendTrialRow(obj.allNoiseOnlyStimuli, noiseResample);
            obj.allNoiseOnlyResponses = obj.appendTrialRow(obj.allNoiseOnlyResponses, responseResample);
        end

        function updateOnlineAnalysis(obj)
            if obj.epochCount < 1
                return;
            end

            freqCutoff = 0.5 * obj.sampleRate;

            if ~isempty(obj.allRisingStimuli) && ~isempty(obj.allRisingResponses) && ...
               ~isempty(obj.allFallingStimuli) && ~isempty(obj.allFallingResponses)

                obj.risingFilter = obj.getLinearFilterOnline( ...
                    obj.allRisingStimuli, obj.allRisingResponses, obj.sampleRate, freqCutoff);

                obj.fallingFilter = obj.getLinearFilterOnline( ...
                    obj.allFallingStimuli, obj.allFallingResponses, obj.sampleRate, freqCutoff);

                obj.risingFilter = obj.forceFilterLength(obj.risingFilter);
                obj.fallingFilter = obj.forceFilterLength(obj.fallingFilter);

                obj.updateFilterPlot('rising');
                obj.updateFilterPlot('falling');

                risingPrediction = obj.computePrediction(obj.allRisingStimuli, obj.risingFilter);
                [obj.risingBinCenters, obj.risingBinResponses] = ...
                    obj.computeNonlinearity(risingPrediction, obj.allRisingResponses);

                fallingPrediction = obj.computePrediction(obj.allFallingStimuli, obj.fallingFilter);
                [obj.fallingBinCenters, obj.fallingBinResponses] = ...
                    obj.computeNonlinearity(fallingPrediction, obj.allFallingResponses);

                obj.updateNonlinearityPlot('rising');
                obj.updateNonlinearityPlot('falling');
            end

            if ~isempty(obj.allNoiseOnlyStimuli) && ~isempty(obj.allNoiseOnlyResponses)
                obj.noiseOnlyFilter = obj.getLinearFilterOnline( ...
                    obj.allNoiseOnlyStimuli, obj.allNoiseOnlyResponses, obj.sampleRate, freqCutoff);

                obj.noiseOnlyFilter = obj.forceFilterLength(obj.noiseOnlyFilter);
                obj.updateFilterPlot('noiseOnly');

                noisePrediction = obj.computePrediction(obj.allNoiseOnlyStimuli, obj.noiseOnlyFilter);
                [obj.noiseOnlyBinCenters, obj.noiseOnlyBinResponses] = ...
                    obj.computeNonlinearity(noisePrediction, obj.allNoiseOnlyResponses);

                obj.updateNonlinearityPlot('noiseOnly');
            end

            legend(obj.axesHandle(1), 'show');
            legend(obj.axesHandle(2), 'show');
            drawnow limitrate;
        end

        function [trimmedStim, stimSampleRate] = trimStimulusToStimWindow(obj, epoch, stimValues, tailTime)
            stimValues = double(stimValues(:))';

            if isKey(epoch.parameters, 'stimulusSampleRate')
                stimSampleRate = double(epoch.parameters('stimulusSampleRate'));
            else
                totalTimeMs = obj.preTime + obj.stimTime + tailTime;
                stimSampleRate = numel(stimValues) / (totalTimeMs / 1000);
            end

            prePts = round(stimSampleRate * obj.preTime / 1000);
            tailPts = round(stimSampleRate * tailTime / 1000);

            startIdx = prePts + 1;
            endIdx = numel(stimValues) - tailPts;

            if startIdx > endIdx || startIdx < 1 || endIdx > numel(stimValues)
                trimmedStim = [];
                return;
            end

            trimmedStim = stimValues(startIdx:endIdx);
        end

        function stimResample = resampleStimulus(obj, epoch, stim, targetLength)
            if isempty(stim)
                stimResample = [];
                return;
            end

            if isKey(epoch.parameters, 'stimulusSampleRate')
                stimSampleRate = double(epoch.parameters('stimulusSampleRate'));
                originalTimes = (0:numel(stim)-1) / stimSampleRate;
            else
                originalTimes = linspace(0, obj.stimTime/1000, numel(stim));
            end

            queryTimes = (0:targetLength-1) / obj.sampleRate;
            stimResample = interp1(originalTimes, stim, queryTimes, 'linear', 'extrap');
            stimResample = stimResample(:)';
        end

        function paramValue = getEpochParamOrDefault(~, epoch, paramName, defaultValue)
            if isKey(epoch.parameters, paramName)
                paramValue = epoch.parameters(paramName);
            else
                paramValue = defaultValue;
            end
        end

        function M = appendTrialRow(~, M, rowVec)
            rowVec = double(rowVec(:))';
            if isempty(M)
                M = rowVec;
                return;
            end

            targetLen = min(size(M,2), numel(rowVec));
            M = M(:, 1:targetLen);
            rowVec = rowVec(1:targetLen);

            M = cat(1, M, rowVec);
        end

        function filt = forceFilterLength(obj, filt)
            filt = double(filt(:))';
            if numel(filt) >= obj.filterPts
                filt = filt(1:obj.filterPts);
            else
                filt = [filt, zeros(1, obj.filterPts - numel(filt))];
            end
        end

        function updateFilterPlot(obj, whichFilter)
            switch whichFilter
                case 'rising'
                    if isempty(obj.risingLineHandle) || ~isvalid(obj.risingLineHandle)
                        obj.risingLineHandle = line(obj.filterTimes, obj.risingFilter, ...
                            'Parent', obj.axesHandle(1), ...
                            'LineWidth', 2, ...
                            'Color', 'r', ...
                            'DisplayName', 'Rising phase');
                    else
                        set(obj.risingLineHandle, 'XData', obj.filterTimes, 'YData', obj.risingFilter);
                    end

                case 'falling'
                    if isempty(obj.fallingLineHandle) || ~isvalid(obj.fallingLineHandle)
                        obj.fallingLineHandle = line(obj.filterTimes, obj.fallingFilter, ...
                            'Parent', obj.axesHandle(1), ...
                            'LineWidth', 2, ...
                            'Color', 'b', ...
                            'DisplayName', 'Falling phase');
                    else
                        set(obj.fallingLineHandle, 'XData', obj.filterTimes, 'YData', obj.fallingFilter);
                    end

                case 'noiseOnly'
                    if isempty(obj.noiseOnlyLineHandle) || ~isvalid(obj.noiseOnlyLineHandle)
                        obj.noiseOnlyLineHandle = line(obj.filterTimes, obj.noiseOnlyFilter, ...
                            'Parent', obj.axesHandle(1), ...
                            'LineWidth', 2, ...
                            'Color', 'k', ...
                            'DisplayName', 'Noise only');
                    else
                        set(obj.noiseOnlyLineHandle, 'XData', obj.filterTimes, 'YData', obj.noiseOnlyFilter);
                    end
            end
        end

        function updateNonlinearityPlot(obj, whichNL)
            switch whichNL
                case 'rising'
                    if isempty(obj.risingBinCenters)
                        return;
                    end
                    if isempty(obj.risingLnDataHandle) || ~isvalid(obj.risingLnDataHandle)
                        obj.risingLnDataHandle = line(obj.risingBinCenters, obj.risingBinResponses, ...
                            'Parent', obj.axesHandle(2), ...
                            'Color', 'r', ...
                            'LineStyle', '-', ...
                            'Marker', 'o', ...
                            'DisplayName', 'Rising phase');
                    else
                        set(obj.risingLnDataHandle, 'XData', obj.risingBinCenters, 'YData', obj.risingBinResponses);
                    end

                case 'falling'
                    if isempty(obj.fallingBinCenters)
                        return;
                    end
                    if isempty(obj.fallingLnDataHandle) || ~isvalid(obj.fallingLnDataHandle)
                        obj.fallingLnDataHandle = line(obj.fallingBinCenters, obj.fallingBinResponses, ...
                            'Parent', obj.axesHandle(2), ...
                            'Color', 'b', ...
                            'LineStyle', '-', ...
                            'Marker', 'o', ...
                            'DisplayName', 'Falling phase');
                    else
                        set(obj.fallingLnDataHandle, 'XData', obj.fallingBinCenters, 'YData', obj.fallingBinResponses);
                    end

                case 'noiseOnly'
                    if isempty(obj.noiseOnlyBinCenters)
                        return;
                    end
                    if isempty(obj.noiseOnlyLnDataHandle) || ~isvalid(obj.noiseOnlyLnDataHandle)
                        obj.noiseOnlyLnDataHandle = line(obj.noiseOnlyBinCenters, obj.noiseOnlyBinResponses, ...
                            'Parent', obj.axesHandle(2), ...
                            'Color', 'k', ...
                            'LineStyle', '-', ...
                            'Marker', 'o', ...
                            'DisplayName', 'Noise only');
                    else
                        set(obj.noiseOnlyLnDataHandle, 'XData', obj.noiseOnlyBinCenters, 'YData', obj.noiseOnlyBinResponses);
                    end
            end
        end

        function [sinusoidValues, noiseValues] = reconstructStimulusComponents(obj, epoch)
            sinusoidValues = [];
            noiseValues = [];

            requiredParams = {'stimulusTag', 'noiseSeed', 'preTime', 'stimTime', ...
                'tailTime', 'meanIntensity', 'noiseStdv', 'temporalContrast', ...
                'temporalFrequency', 'frequencyCutoff', 'numberOfFilters', ...
                'stimulusSampleRate'};

            for i = 1:numel(requiredParams)
                if ~isKey(epoch.parameters, requiredParams{i})
                    warning('LedPhaseLinearFilterFigure:MissingEpochParameter', ...
                        'Missing epoch parameter: %s', requiredParams{i});
                    return;
                end
            end

            seed = epoch.parameters('noiseSeed');
            preTime = epoch.parameters('preTime');
            stimTime = epoch.parameters('stimTime');
            tailTime = epoch.parameters('tailTime');
            meanIntensity = epoch.parameters('meanIntensity');
            noiseStdv = epoch.parameters('noiseStdv');
            temporalContrast = epoch.parameters('temporalContrast');
            temporalFrequency = epoch.parameters('temporalFrequency');
            frequencyCutoff = epoch.parameters('frequencyCutoff');
            numberOfFilters = epoch.parameters('numberOfFilters');
            stimulusSampleRate = epoch.parameters('stimulusSampleRate');

            units = obj.ledDevice.background.displayUnits;
            [upperLimit, lowerLimit] = obj.getStimulusLimits(units);

            % Reconstruct sinusoid-only waveform
            try
                genSin = edu.washington.riekelab.chris.stimuli.SinusoidPlusNoiseGenerator();
                genSin.preTime = preTime;
                genSin.stimTime = stimTime;
                genSin.tailTime = tailTime;
                genSin.mean = meanIntensity;
                genSin.seed = seed;
                genSin.sampleRate = stimulusSampleRate;
                genSin.units = units;
                genSin.freqCutoff = frequencyCutoff;
                genSin.numFilters = numberOfFilters;
                genSin.temporalFrequency = temporalFrequency;
                genSin.noiseStdv = 0;
                genSin.temporalContrast = temporalContrast;
                genSin.upperLimit = upperLimit;
                genSin.lowerLimit = lowerLimit;

                stimSin = genSin.generate();
                sinusoidValues = obj.extractStimulusWaveform(stimSin);
            catch ME
                warning('LedPhaseLinearFilterFigure:SinusoidReconstructionFailed', ...
                    'Failed to reconstruct sinusoid waveform: %s', ME.message);
                sinusoidValues = [];
            end

            % Reconstruct noise-only waveform
            try
                genNoise = edu.washington.riekelab.chris.stimuli.SinusoidPlusNoiseGenerator();
                genNoise.preTime = preTime;
                genNoise.stimTime = stimTime;
                genNoise.tailTime = tailTime;
                genNoise.mean = meanIntensity;
                genNoise.seed = seed;
                genNoise.sampleRate = stimulusSampleRate;
                genNoise.units = units;
                genNoise.freqCutoff = frequencyCutoff;
                genNoise.numFilters = numberOfFilters;
                genNoise.temporalFrequency = temporalFrequency;
                genNoise.noiseStdv = noiseStdv;
                genNoise.temporalContrast = 0;
                genNoise.upperLimit = upperLimit;
                genNoise.lowerLimit = lowerLimit;

                stimNoise = genNoise.generate();
                noiseValues = obj.extractStimulusWaveform(stimNoise);
            catch ME
                warning('LedPhaseLinearFilterFigure:NoiseReconstructionFailed', ...
                    'Failed to reconstruct noise waveform: %s', ME.message);
                noiseValues = [];
            end

            if ~isempty(sinusoidValues)
                sinusoidValues = sinusoidValues(:)';
            end
            if ~isempty(noiseValues)
                noiseValues = noiseValues(:)';
            end
        end

        function data = extractStimulusWaveform(~, stim)
            data = [];

            % Try Symphony cobj output access
            try
                cobj = stim.cobj;
                output = cobj.OutputData;
                dataObj = output.Data;

                try
                    data = double(dataObj);
                catch
                    try
                        data = double(dataObj.Quantity);
                    catch
                    end
                end
            catch
            end

            % Alternate API path
            if isempty(data)
                try
                    cobj = stim.cobj;
                    output = cobj.getOutputData();
                    dataObj = output.Data;
                    try
                        data = double(dataObj);
                    catch
                        try
                            data = double(dataObj.Quantity);
                        catch
                        end
                    end
                catch
                end
            end

            % Fallback method if available
            if isempty(data)
                try
                    data = double(stim.getData());
                catch
                end
            end

            if isempty(data)
                error('Could not extract waveform data from stimulus.');
            end

            data = data(:)';
        end

        function [upperLimit, lowerLimit] = getStimulusLimits(~, units)
            if strcmp(units, symphonyui.core.Measurement.NORMALIZED)
                upperLimit = 1;
                lowerLimit = 0;
            else
                upperLimit = 10.239;
                lowerLimit = -10.24;
            end
        end

    end

    methods
        function linearFilter = getLinearFilterOnline(~, stimulus, response, sampleRate, freqCutoff)
            stimulus = double(stimulus);
            response = double(response);

            if isempty(stimulus) || isempty(response)
                linearFilter = [];
                return;
            end

            if size(stimulus,1) ~= size(response,1) || size(stimulus,2) ~= size(response,2)
                error('LedPhaseLinearFilterFigure:SizeMismatch', ...
                    'Stimulus and response must have identical size.');
            end

            nT = size(stimulus, 2);

            stimFft = fft(stimulus, [], 2);
            respFft = fft(response, [], 2);

            crossSpec = mean(respFft .* conj(stimFft), 1);
            stimPower = mean(stimFft .* conj(stimFft), 1);

            stimPower = stimPower + eps;
            filterFft = crossSpec ./ stimPower;

            freqcutoffAdjusted = round(freqCutoff / (sampleRate / nT));
            freqcutoffAdjusted = max(0, min(freqcutoffAdjusted, floor(nT/2)));

            if nT > 2 * freqcutoffAdjusted + 1
                filterFft(1 + freqcutoffAdjusted : nT - freqcutoffAdjusted) = 0;
            end

            linearFilter = real(ifft(filterFft));
            linearFilter = linearFilter(:)';
        end

        function prediction = computePrediction(~, stimulus, filterKernel)
            stimulus = double(stimulus);
            filterKernel = double(filterKernel(:))';

            if isempty(stimulus) || isempty(filterKernel)
                prediction = [];
                return;
            end

            if isvector(stimulus)
                stimulus = stimulus(:)';
            end

            nTrials = size(stimulus, 1);
            nPts = size(stimulus, 2);

            prediction = zeros(nTrials, nPts);
            for i = 1:nTrials
                tmp = conv(stimulus(i,:), filterKernel, 'full');
                prediction(i,:) = tmp(1:nPts);
            end
        end

        function [binCenters, binResponses] = computeNonlinearity(~, prediction, response)
            prediction = double(prediction(:));
            response = double(response(:));

            valid = isfinite(prediction) & isfinite(response);
            prediction = prediction(valid);
            response = response(valid);

            if isempty(prediction) || isempty(response)
                binCenters = [];
                binResponses = [];
                return;
            end

            if numel(unique(prediction)) < 3
                binCenters = [];
                binResponses = [];
                return;
            end

            numBins = min(30, max(8, ceil(numel(prediction) / 200)));

            [counts, edges] = histcounts(prediction, numBins);
            if isempty(edges) || numel(edges) < 2
                binCenters = [];
                binResponses = [];
                return;
            end

            binCenters = edges(1:end-1) + diff(edges) / 2;
            binResponses = nan(size(binCenters));

            for b = 1:numel(binCenters)
                if b < numel(binCenters)
                    idx = prediction >= edges(b) & prediction < edges(b+1);
                else
                    idx = prediction >= edges(b) & prediction <= edges(b+1);
                end
                if any(idx)
                    binResponses(b) = mean(response(idx), 'omitnan');
                end
            end

            validBins = counts > 0 & isfinite(binResponses);
            binCenters = binCenters(validBins);
            binResponses = binResponses(validBins);
        end
    end
end
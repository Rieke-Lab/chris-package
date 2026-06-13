classdef LMConeNoise < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % LMConeNoise
    %
    % Cone-isolating temporal noise stimulus cycling through:
    %   1) LNoise   - L-cone noise, M held at mean
    %   2) MNoise   - M-cone noise, L held at mean
    %   3) LMNoise  - independent L- and M-cone noise
    %
    % The stimulus is generated in L/M cone-isomerization units and then
    % converted to red/green monitor gun values using the inverse of the
    % 2x2 RG->LM calibration matrix. The blue gun is held at 0.
    %
    % This version precomputes each epoch's RGB time course in prepareEpoch,
    % then the Stage controller only indexes the precomputed values during
    % createPresentation. This follows the safer pattern used by many working
    % noise protocols and avoids advancing random streams inside the Stage
    % controller.

    properties
        preTime = 500                       % ms
        stimTime = 8000                     % ms
        tailTime = 500                      % ms
        centerDiameter = 200                % um

        % Separate L and M mean isomerizations. These defaults were selected
        % for the calibration below and 0.3 contrast to keep estimated R/G
        % clipping typically below the tolerated fraction.
        meanLIsomerization = 29542          % R*/sec
        meanMIsomerization = 16827          % R*/sec

        % Cone-isomerization contrast: noise std / mean isomerization.
        LNoiseContrast = 0.3
        MNoiseContrast = 0.3

        % Display calibration: isomerizations per unit 0-1 gun intensity.
        % Matrix convention:
        %   [L; M] = [red->L, green->L; red->M, green->M] * [R; G]
        redChannelIsomPerUnitL = 50255      % R*/sec per unit red gun, L-cone
        redChannelIsomPerUnitM = 13750      % R*/sec per unit red gun, M-cone
        greenChannelIsomPerUnitL = 113478   % R*/sec per unit green gun, L-cone
        greenChannelIsomPerUnitM = 126433   % R*/sec per unit green gun, M-cone

        frameDwell = 2                      % monitor frames per noise update
        useRandomSeed = true                % false => fixed seeds 0/1

        % Practical clipping check. Epochs with <=10% clipped red/green
        % samples are treated as acceptable. The trace figure and epoch
        % metadata report the actual clipping fraction.
        maxToleratedClipFraction = 0.10     % fraction of R/G samples; 0.10 = 10%
        estimateClippingInPrepareEpoch = true

        onlineAnalysis = 'none'
        numberOfAverages = uint16(30)       % use multiples of 3 for full L/M/LM cycles
        amp
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char','row',{'none','extracellular','exc','inh'})
        lNoiseSeed
        mNoiseSeed
        currentStimulus
        backgroundRGB                       % 1x3 [R G 0]
        rgbOverUpdate                       % nUpdates x 3, clipped delivered RGB
        rawRGOverUpdate                     % nUpdates x 2, unclipped R/G request
        lIsomOverUpdate                     % 1 x nUpdates, intended L isom
        mIsomOverUpdate                     % 1 x nUpdates, intended M isom
    end

    properties (Hidden, Dependent)
        rgToLm
        lmToRg
    end

    methods
        function value = get.rgToLm(obj)
            value = [obj.redChannelIsomPerUnitL, obj.greenChannelIsomPerUnitL; ...
                     obj.redChannelIsomPerUnitM, obj.greenChannelIsomPerUnitM];
        end

        function value = get.lmToRg(obj)
            value = inv(obj.rgToLm);
        end

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            if abs(det(obj.rgToLm)) < 1e-9
                error(['LMConeNoise: rgToLm calibration matrix is singular. ', ...
                       'Check redChannel*/greenChannel* calibration values.']);
            end

            if mod(double(obj.numberOfAverages), 3) ~= 0
                warning('LMConeNoise:IncompleteCycle', ...
                    ['numberOfAverages=%d is not a multiple of 3. ', ...
                     'The final L/M/LM cycle will be incomplete.'], ...
                    double(obj.numberOfAverages));
            end

            meanRG = obj.lmToRg * [obj.meanLIsomerization; obj.meanMIsomerization];
            obj.backgroundRGB = [max(0, min(1, meanRG(1))), max(0, min(1, meanRG(2))), 0];

            if any(meanRG < 0) || any(meanRG > 1)
                warning('LMConeNoise:MeanGunOutOfRange', ...
                    ['Mean red/green gun values are outside [0,1]: R=%.3f G=%.3f. ', ...
                     'Change meanLIsomerization/meanMIsomerization or recheck calibration.'], ...
                    meanRG(1), meanRG(2));
            end

            % Put the stimulus trace figure first so it is available even
            % when onlineAnalysis is off.
            obj.showFigure('edu.washington.riekelab.chris.figures.LMConeNoiseTraceFigure', ...
                obj.rig.getDevice('Stage'), ...
                'preTime', obj.preTime, ...
                'stimTime', obj.stimTime, ...
                'frameDwell', obj.frameDwell, ...
                'meanLIsom', obj.meanLIsomerization, ...
                'meanMIsom', obj.meanMIsomerization, ...
                'LNoiseContrast', obj.LNoiseContrast, ...
                'MNoiseContrast', obj.MNoiseContrast, ...
                'rgToLm', obj.rgToLm, ...
                'maxToleratedClipFraction', obj.maxToleratedClipFraction);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure', ...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));

            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.LinearFilterFigure', ...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice('Frame Monitor'), ...
                    obj.rig.getDevice('Stage'), ...
                    'recordingType', obj.onlineAnalysis, ...
                    'preTime', obj.preTime, 'stimTime', obj.stimTime, ...
                    'frameDwell', obj.frameDwell, ...
                    'seedID', 'lNoiseSeed', ...
                    'updatePattern', [1, 3], ...
                    'noiseStdv', obj.LNoiseContrast, ...
                    'figureTitle', 'L cone (LN)');

                obj.showFigure('edu.washington.riekelab.turner.figures.LinearFilterFigure2', ...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice('Frame Monitor'), ...
                    obj.rig.getDevice('Stage'), ...
                    'recordingType', obj.onlineAnalysis, ...
                    'preTime', obj.preTime, 'stimTime', obj.stimTime, ...
                    'frameDwell', obj.frameDwell, ...
                    'seedID', 'mNoiseSeed', ...
                    'updatePattern', [2, 3], ...
                    'noiseStdv', obj.MNoiseContrast, ...
                    'figureTitle', 'M cone (LN)');

                obj.showFigure('edu.washington.riekelab.chris.figures.LM2DNonlinearityFigure', ...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice('Frame Monitor'), ...
                    obj.rig.getDevice('Stage'), ...
                    'recordingType', obj.onlineAnalysis, ...
                    'preTime', obj.preTime, 'stimTime', obj.stimTime, ...
                    'frameDwell', obj.frameDwell, ...
                    'lSeedID', 'lNoiseSeed', ...
                    'mSeedID', 'mNoiseSeed', ...
                    'stimulusKey', 'currentStimulus', ...
                    'lNoiseStdv', obj.LNoiseContrast, ...
                    'mNoiseStdv', obj.MNoiseContrast, ...
                    'figureTitle', 'L+M 2D nonlinearity');
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;

            % Use numEpochsPrepared, not numEpochsCompleted, so queued epochs
            % cycle properly through LNoise, MNoise, LMNoise.
            index = mod(obj.numEpochsPrepared, 3);
            if index == 0
                obj.currentStimulus = 'LNoise';
                if obj.useRandomSeed
                    obj.lNoiseSeed = RandStream.shuffleSeed;
                    obj.mNoiseSeed = RandStream.shuffleSeed;
                else
                    obj.lNoiseSeed = 0;
                    obj.mNoiseSeed = 1;
                end
            elseif index == 1
                obj.currentStimulus = 'MNoise';
            else
                obj.currentStimulus = 'LMNoise';
            end

            [obj.lIsomOverUpdate, obj.mIsomOverUpdate, obj.rawRGOverUpdate, obj.rgbOverUpdate] = ...
                obj.precomputeStimulus(obj.currentStimulus, obj.lNoiseSeed, obj.mNoiseSeed);

            rawRG = obj.rawRGOverUpdate;
            clipMask = rawRG < 0 | rawRG > 1;
            clipFrac = mean(clipMask(:));
            rawMin = min(rawRG(:));
            rawMax = max(rawRG(:));

            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            meanRG = obj.lmToRg * [obj.meanLIsomerization; obj.meanMIsomerization];
            obj.backgroundRGB = [max(0, min(1, meanRG(1))), max(0, min(1, meanRG(2))), 0];

            epoch.addParameter('lNoiseSeed', obj.lNoiseSeed);
            epoch.addParameter('mNoiseSeed', obj.mNoiseSeed);
            epoch.addParameter('currentStimulus', obj.currentStimulus);
            epoch.addParameter('meanLIsomerization', obj.meanLIsomerization);
            epoch.addParameter('meanMIsomerization', obj.meanMIsomerization);
            epoch.addParameter('meanLMIsomerization', mean([obj.meanLIsomerization, obj.meanMIsomerization]));
            epoch.addParameter('LNoiseContrast', obj.LNoiseContrast);
            epoch.addParameter('MNoiseContrast', obj.MNoiseContrast);
            epoch.addParameter('redChannelIsomPerUnitL', obj.redChannelIsomPerUnitL);
            epoch.addParameter('redChannelIsomPerUnitM', obj.redChannelIsomPerUnitM);
            epoch.addParameter('greenChannelIsomPerUnitL', obj.greenChannelIsomPerUnitL);
            epoch.addParameter('greenChannelIsomPerUnitM', obj.greenChannelIsomPerUnitM);
            epoch.addParameter('meanRedGun', meanRG(1));
            epoch.addParameter('meanGreenGun', meanRG(2));

            if obj.estimateClippingInPrepareEpoch
                epoch.addParameter('estimatedClippedGunSampleFraction', clipFrac);
                epoch.addParameter('estimatedRawGunMin', rawMin);
                epoch.addParameter('estimatedRawGunMax', rawMax);
                epoch.addParameter('maxToleratedClipFraction', obj.maxToleratedClipFraction);

                if clipFrac > obj.maxToleratedClipFraction
                    warning('LMConeNoise:EpochClippingAboveTolerance', ...
                        ['%s epoch seed L=%d M=%d has estimated %.2f%% clipped R/G samples, ', ...
                         'above the tolerated %.2f%%.'], ...
                        obj.currentStimulus, obj.lNoiseSeed, obj.mNoiseSeed, ...
                        100 * clipFrac, 100 * obj.maxToleratedClipFraction);
                end
            end
        end

        function p = createPresentation(obj)
            stageDevice = obj.rig.getDevice('Stage');
            canvasSize = stageDevice.getCanvasSize();
            centerDiameterPix = stageDevice.um2pix(obj.centerDiameter);

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundRGB);

            try
                frameRate = stageDevice.getMonitorRefreshRate();
            catch
                frameRate = 60;
            end
            preFrames = round(frameRate * (obj.preTime / 1e3));

            centerSpot = stage.builtin.stimuli.Ellipse();
            centerSpot.radiusX = centerDiameterPix / 2;
            centerSpot.radiusY = centerDiameterPix / 2;
            centerSpot.position = canvasSize / 2;
            centerSpot.color = obj.backgroundRGB;
            p.addStimulus(centerSpot);

            rgbTrace = obj.rgbOverUpdate;
            backgroundRGB = obj.backgroundRGB;
            frameDwellLocal = obj.frameDwell;
            nUpdates = size(rgbTrace, 1);

            colorCtrl = stage.builtin.controllers.PropertyController(centerSpot, 'color', ...
                @(state)getNoiseRGB(state.frame - preFrames, frameDwellLocal, rgbTrace, backgroundRGB, nUpdates));
            p.addController(colorCtrl);

            visCtrl = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(visCtrl);

            function rgb = getNoiseRGB(frame, frameDwell, rgbArray, bgRGB, n)
                if frame < 0 || n < 1
                    rgb = bgRGB;
                    return;
                end
                updateIndex = floor(double(frame) / double(frameDwell)) + 1;
                if updateIndex < 1
                    updateIndex = 1;
                elseif updateIndex > n
                    updateIndex = n;
                end
                rgb = rgbArray(updateIndex, :);
            end
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end

    methods (Access = private)
        function [lIsom, mIsom, rawRG, clippedRGB] = precomputeStimulus(obj, stimType, lSeed, mSeed)
            try
                frameRate = obj.rig.getDevice('Stage').getMonitorRefreshRate();
            catch
                frameRate = 60;
            end
            stimFrames = round(frameRate * obj.stimTime / 1e3);
            nUpdates = floor(stimFrames / obj.frameDwell);

            lStream = RandStream('mt19937ar', 'Seed', lSeed);
            mStream = RandStream('mt19937ar', 'Seed', mSeed);

            lIsom = zeros(1, nUpdates);
            mIsom = zeros(1, nUpdates);
            rawRG = zeros(nUpdates, 2);
            clippedRGB = zeros(nUpdates, 3);

            for ii = 1:nUpdates
                switch stimType
                    case 'LNoise'
                        lVal = obj.meanLIsomerization * (1 + obj.LNoiseContrast * lStream.randn);
                        mVal = obj.meanMIsomerization;
                    case 'MNoise'
                        lVal = obj.meanLIsomerization;
                        mVal = obj.meanMIsomerization * (1 + obj.MNoiseContrast * mStream.randn);
                    case 'LMNoise'
                        lVal = obj.meanLIsomerization * (1 + obj.LNoiseContrast * lStream.randn);
                        mVal = obj.meanMIsomerization * (1 + obj.MNoiseContrast * mStream.randn);
                    otherwise
                        lVal = obj.meanLIsomerization;
                        mVal = obj.meanMIsomerization;
                end

                lIsom(ii) = lVal;
                mIsom(ii) = mVal;

                rg = obj.lmToRg * [lVal; mVal];
                rawRG(ii, :) = rg(:)';
                clippedRG = [max(0, min(1, rg(1))), max(0, min(1, rg(2)))];
                clippedRGB(ii, :) = [clippedRG, 0];
            end
        end
    end
end

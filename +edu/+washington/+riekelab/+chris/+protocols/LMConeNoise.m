classdef LMConeNoise < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % LMConeNoise
    %
    % Cone-isolating temporal noise stimulus cycling through:
    %   1) LNoise   - L-cone noise, M held at mean
    %   2) MNoise   - M-cone noise, L held at mean
    %   3) LMNoise  - independent L- and M-cone noise
    %
    % L/M cone isomerization trajectories are converted to red/green gun
    % intensities by inverting a 2x2 RG->LM calibration matrix. The blue gun
    % is held at 0 and S-cones are intentionally ignored.

    properties
        preTime = 500                       % ms
        stimTime = 8000                     % ms
        tailTime = 500                      % ms
        centerDiameter = 200                % um

        % Mean L and M isomerization can be different. These defaults were
        % estimated for the calibration below and 0.3 L/M cone contrast to
        % reduce clipping compared with equal L/M means. They correspond to
        % mean red/green gun values of approximately R=0.381, G=0.092.
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
        greenChannelIsomPerUnitL = 113478    % R*/sec per unit green gun, L-cone
        greenChannelIsomPerUnitM = 126433    % R*/sec per unit green gun, M-cone

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
        lNoiseStream
        mNoiseStream
        currentStimulus
        backgroundRGB                       % [R; G; 0]
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
            obj.backgroundRGB = [max(0, min(1, meanRG)); 0];

            if any(meanRG < 0) || any(meanRG > 1)
                warning('LMConeNoise:BgOutOfRange', ...
                    ['Mean background gun values out of [0,1]: R=%.3f G=%.3f. ', ...
                     'Change meanLIsomerization/meanMIsomerization or check calibration.'], ...
                    meanRG(1), meanRG(2));
            end

            % Put the stimulus diagnostic figure first, so it is always created
%             % independently of optional online analysis figures.
%             obj.showFigure('edu.washington.riekelab.chris.figures.LMConeNoiseTraceFigure', ...
%                 obj.rig.getDevice('Stage'), ...
%                 'preTime', obj.preTime, ...
%                 'stimTime', obj.stimTime, ...
%                 'frameDwell', obj.frameDwell, ...
%                 'meanLIsom', obj.meanLIsomerization, ...
%                 'meanMIsom', obj.meanMIsomerization, ...
%                 'LNoiseContrast', obj.LNoiseContrast, ...
%                 'MNoiseContrast', obj.MNoiseContrast, ...
%                 'rgToLm', obj.rgToLm, ...
%                 'maxToleratedClipFraction', obj.maxToleratedClipFraction);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure', ...
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
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            index = mod(obj.numEpochsCompleted, 3);
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

            obj.lNoiseStream = RandStream('mt19937ar', 'Seed', obj.lNoiseSeed);
            obj.mNoiseStream = RandStream('mt19937ar', 'Seed', obj.mNoiseSeed);

            meanRG = obj.lmToRg * [obj.meanLIsomerization; obj.meanMIsomerization];
            obj.backgroundRGB = [max(0, min(1, meanRG)); 0];

            epoch.addParameter('lNoiseSeed', obj.lNoiseSeed);
            epoch.addParameter('mNoiseSeed', obj.mNoiseSeed);
            epoch.addParameter('currentStimulus', obj.currentStimulus);
            epoch.addParameter('meanLIsomerization', obj.meanLIsomerization);
            epoch.addParameter('meanMIsomerization', obj.meanMIsomerization);
            epoch.addParameter('LNoiseContrast', obj.LNoiseContrast);
            epoch.addParameter('MNoiseContrast', obj.MNoiseContrast);
            epoch.addParameter('redChannelIsomPerUnitL', obj.redChannelIsomPerUnitL);
            epoch.addParameter('redChannelIsomPerUnitM', obj.redChannelIsomPerUnitM);
            epoch.addParameter('greenChannelIsomPerUnitL', obj.greenChannelIsomPerUnitL);
            epoch.addParameter('greenChannelIsomPerUnitM', obj.greenChannelIsomPerUnitM);
            epoch.addParameter('meanRedGun', meanRG(1));
            epoch.addParameter('meanGreenGun', meanRG(2));
            epoch.addParameter('meanLMIsomerization', mean([obj.meanLIsomerization, obj.meanMIsomerization]));

            if obj.estimateClippingInPrepareEpoch
                [clipFrac, rawMin, rawMax] = obj.estimateEpochClipping(obj.currentStimulus, obj.lNoiseSeed, obj.mNoiseSeed);
                epoch.addParameter('estimatedClippedGunSampleFraction', clipFrac);
                epoch.addParameter('estimatedRawGunMin', rawMin);
                epoch.addParameter('estimatedRawGunMax', rawMax);
                epoch.addParameter('maxToleratedClipFraction', obj.maxToleratedClipFraction);

                if clipFrac > obj.maxToleratedClipFraction
                    warning('LMConeNoise:EpochClippingAboveTolerance', ...
                        ['%s epoch seed L=%d M=%d has estimated %.2f%% clipped R/G samples, ', ...
                         'above the tolerated %.2f%%. Delivered L/M traces may differ from intended cone traces.'], ...
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

            colorCtrl = stage.builtin.controllers.PropertyController(centerSpot, 'color', ...
                @(state)getNoiseRGB(obj, state.frame - preFrames));
            p.addController(colorCtrl);

            visCtrl = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(visCtrl);

            function rgb = getNoiseRGB(obj, frame)
                persistent currentRGB
                if isempty(currentRGB)
                    currentRGB = obj.backgroundRGB;
                end

                if frame < 0
                    currentRGB = obj.backgroundRGB;
                else
                    if mod(frame, obj.frameDwell) == 0
                        [lIsom, mIsom] = obj.nextConeIsomerizations();
                        rawRG = obj.lmToRg * [lIsom; mIsom];
                        clippedRG = max(0, min(1, rawRG));
                        currentRGB = [clippedRG; 0];
                    end
                end
                rgb = currentRGB;
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
        function [lIsom, mIsom] = nextConeIsomerizations(obj)
            switch obj.currentStimulus
                case 'LNoise'
                    lIsom = obj.meanLIsomerization * (1 + obj.LNoiseContrast * obj.lNoiseStream.randn);
                    mIsom = obj.meanMIsomerization;
                case 'MNoise'
                    lIsom = obj.meanLIsomerization;
                    mIsom = obj.meanMIsomerization * (1 + obj.MNoiseContrast * obj.mNoiseStream.randn);
                case 'LMNoise'
                    lIsom = obj.meanLIsomerization * (1 + obj.LNoiseContrast * obj.lNoiseStream.randn);
                    mIsom = obj.meanMIsomerization * (1 + obj.MNoiseContrast * obj.mNoiseStream.randn);
                otherwise
                    lIsom = obj.meanLIsomerization;
                    mIsom = obj.meanMIsomerization;
            end
        end

        function [clipFrac, rawMin, rawMax] = estimateEpochClipping(obj, stimType, lSeed, mSeed)
            try
                frameRate = obj.rig.getDevice('Stage').getMonitorRefreshRate();
            catch
                frameRate = 60;
            end
            stimFrames = round(frameRate * obj.stimTime / 1e3);
            nUpdates = floor(stimFrames / obj.frameDwell);

            lStream = RandStream('mt19937ar', 'Seed', lSeed);
            mStream = RandStream('mt19937ar', 'Seed', mSeed);
            rawRG = zeros(2, nUpdates);

            for ii = 1:nUpdates
                switch stimType
                    case 'LNoise'
                        lIsom = obj.meanLIsomerization * (1 + obj.LNoiseContrast * lStream.randn);
                        mIsom = obj.meanMIsomerization;
                    case 'MNoise'
                        lIsom = obj.meanLIsomerization;
                        mIsom = obj.meanMIsomerization * (1 + obj.MNoiseContrast * mStream.randn);
                    case 'LMNoise'
                        lIsom = obj.meanLIsomerization * (1 + obj.LNoiseContrast * lStream.randn);
                        mIsom = obj.meanMIsomerization * (1 + obj.MNoiseContrast * mStream.randn);
                    otherwise
                        lIsom = obj.meanLIsomerization;
                        mIsom = obj.meanMIsomerization;
                end
                rawRG(:, ii) = obj.lmToRg * [lIsom; mIsom];
            end

            rawMin = min(rawRG(:));
            rawMax = max(rawRG(:));
            clipFrac = mean(rawRG(:) < 0 | rawRG(:) > 1);
        end
    end
end

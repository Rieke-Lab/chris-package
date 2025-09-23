classdef SpatialNoiseMultiMeans < manookinlab.protocols.ManookinLabStageProtocol
    % Achromatic spatiotemporal checkerboard noise with mean steps.
    % - Unique noise only
    % - No chromatic modes, no Gaussian filter, no jitter, no gamma edits
    % - Fresh random seed each epoch
    % - Mean alternates between two values; if >2 values provided, picks randomly each block
    %
    % Logged:
    %   seed (noise), meanSeed, frameDwell, refreshRate, geometry, pre/stim frames,
    %   meanIntensities, meanStepMs/Frames, meanScheduleStartFrames, meanScheduleValues,
    %   backgroundMean

    properties
        amp                             % Output amplifier
        preTime = 250                   % ms
        stimTime = 160000               % ms
        tailTime = 250                  % ms

        % Stimulus (achromatic)
        contrast = 1                    % 0..1; scales modulation amplitude around mean (safe-clamped)
        stixelSize = 90                 % microns edge length of a stixel

        % Temporal
        frameDwell = uint16(1)          % update noise every N frames

        % Mean schedule
        meanIntensities = [0.3 0.7]     % if exactly 2, alternates; if >2, randomly selects per block
        meanStepMs = 3000               % change mean every 3000 ms

        % Run control
        numberOfAverages = uint16(20)
    end

    properties (Hidden)
        ampType

        % Geometry & timing
        stixelSizePix
        numXStixels
        numYStixels
        refreshRate
        preFrames
        stimFrames
        meanStepFrames

        % RNG
        seed           % for noise
        meanSeed       % for mean schedule (when random >2)
        noiseStream
        meanStream

        % Precomputed mean schedule (per-epoch)
        backgroundMean
        meanScheduleStartFrames    % row vector
        meanScheduleValues         % row vector

        % Work buffer
        imageMatrix
    end

    methods
        function didSetRig(obj)
            didSetRig@manookinlab.protocols.ManookinLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);

            % Display refresh
            try
                obj.refreshRate = obj.rig.getDevice('Stage').getExpectedRefreshRate();
            catch
                obj.refreshRate = 60; % fallback
            end

            % Frame counts
            obj.preFrames      = round(obj.preTime  * 1e-3 * obj.refreshRate);
            obj.stimFrames     = round(obj.stimTime * 1e-3 * obj.refreshRate);
            obj.meanStepFrames = max(1, round(obj.meanStepMs * 1e-3 * obj.refreshRate));

            if ~obj.isMeaRig
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            end
        end

        function p = createPresentation(obj)
            totalDurSec = (obj.preTime + obj.stimTime + obj.tailTime) * 1e-3;
            p = stage.core.Presentation(totalDurSec);

            % Background = minimum of provided means
            obj.backgroundMean = min(obj.meanIntensities);
            p.setBackgroundColor(obj.backgroundMean);

            % Initial image (background); sized in createEpoch
            obj.imageMatrix = obj.backgroundMean * ones(obj.numYStixels, obj.numXStixels, 'single');
            checker = stage.builtin.stimuli.Image(uint8(255 * obj.imageMatrix));
            checker.position = obj.canvasSize / 2;
            checker.size = [obj.numXStixels, obj.numYStixels] * obj.stixelSizePix;

            % Keep hard stixel edges
            checker.setMinFunction(GL.NEAREST);
            checker.setMagFunction(GL.NEAREST);

            p.addStimulus(checker);

            % Visible only during stim window
            visCtrl = stage.builtin.controllers.PropertyController( ...
                checker, 'visible', ...
                @(s) s.time >= obj.preTime * 1e-3 && s.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(visCtrl);

            % Frame-based image updates with precomputed mean schedule
            preF = obj.preFrames;
            imgCtrl = stage.builtin.controllers.PropertyController( ...
                checker, 'imageMatrix', ...
                @(s) setStixels(obj, s.frame - preF));
            p.addController(imgCtrl);

            % ------- nested helper -------
            function im = setStixels(obj_, relFrame)
                % relFrame: 0 at first stim frame; >0 during stim
                persistent S M lastBlockIdx
                if relFrame > 0
                    % Determine current mean from precomputed schedule
                    blockIdx = floor(double(relFrame) / double(obj_.meanStepFrames)); % 0-based
                    % Clamp to last block if relFrame overruns due to rounding
                    maxBlock = numel(obj_.meanScheduleValues) - 1;
                    if blockIdx > maxBlock, blockIdx = maxBlock; end
                    currMean = obj_.meanScheduleValues(blockIdx + 1);

                    % Update noise on dwell boundaries OR when entering a new block
                    needNewNoise = isempty(S) || (mod(double(relFrame), double(obj_.frameDwell)) == 0);
                    blockChanged = isempty(lastBlockIdx) || (blockIdx ~= lastBlockIdx);

                    if needNewNoise || blockChanged
                        if isempty(S) || needNewNoise
                            S = 2 * (obj_.noiseStream.rand(obj_.numYStixels, obj_.numXStixels) > 0.5) - 1; % {-1,+1}
                        end
                        % Safe amplitude so µ±A stays in [0,1]
                        A = obj_.contrast * min(currMean, 1 - currMean);
                        M = currMean + A * S;
                        % Clamp to [0,1]
                        M(M < 0) = 0; M(M > 1) = 1;

                        lastBlockIdx = blockIdx;
                    end
                else
                    % PreTime: background
                    if isempty(M)
                        M = obj_.backgroundMean * ones(obj_.numYStixels, obj_.numXStixels, 'single');
                    end
                end
                im = uint8(255 * M);
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);

            % Remove Amp responses on MEA rigs
            if obj.isMeaRig
                amps = obj.rig.getDevices('Amp');
                for ii = 1:numel(amps)
                    if epoch.hasResponse(amps{ii}), epoch.removeResponse(amps{ii}); end
                    if epoch.hasStimulus(amps{ii}), epoch.removeStimulus(amps{ii}); end
                end
            end

            % Geometry
            um2pix = obj.rig.getDevice('Stage').um2pix(1);
            obj.stixelSizePix = max(1, round(obj.stixelSize * um2pix));
            obj.numXStixels = ceil(obj.canvasSize(1) / obj.stixelSizePix) + 1;
            obj.numYStixels = ceil(obj.canvasSize(2) / obj.stixelSizePix) + 1;

            % Seeds
            obj.seed     = RandStream.shuffleSeed;             % noise seed
            obj.meanSeed = obj.seed + 1;                       % separate stream for mean schedule
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);
            obj.meanStream  = RandStream('mt19937ar', 'Seed', obj.meanSeed);

            % --- Build mean schedule for the whole stim (per block) ---
            nBlocks = max(1, ceil(obj.stimFrames / obj.meanStepFrames));
            obj.meanScheduleStartFrames = (0:(nBlocks-1)) * obj.meanStepFrames;

            nMeans = numel(obj.meanIntensities);
            vals = zeros(1, nBlocks);
            if nMeans == 1
                vals(:) = obj.meanIntensities(1);
            elseif nMeans == 2
                % Alternate deterministically: [m1, m2, m1, m2, ...]
                vals = obj.meanIntensities(mod(0:nBlocks-1, 2) + 1);
            else
                % Random pick per block (reproducible via meanSeed)
                lastIdx = 0;
                for k = 1:nBlocks
                    idx = 1 + floor(nMeans * obj.meanStream.rand());
                    % Optional: avoid immediate repeats if possible
                    if nMeans > 1 && k > 1 && idx == lastIdx
                        idx = 1 + mod(idx, nMeans);
                    end
                    vals(k) = obj.meanIntensities(idx);
                    lastIdx = idx;
                end
            end
            obj.meanScheduleValues = vals;

            % --- Log everything needed for offline reconstruction ---
            epoch.addParameter('seed', obj.seed);
            epoch.addParameter('meanSeed', obj.meanSeed);
            epoch.addParameter('stixelSize_um', obj.stixelSize);
            epoch.addParameter('stixelSize_pix', obj.stixelSizePix);
            epoch.addParameter('numXStixels', obj.numXStixels);
            epoch.addParameter('numYStixels', obj.numYStixels);
            epoch.addParameter('frameDwell', obj.frameDwell);
            epoch.addParameter('refreshRate', obj.refreshRate);
            epoch.addParameter('preFrames', obj.preFrames);
            epoch.addParameter('stimFrames', obj.stimFrames);
            epoch.addParameter('contrast', obj.contrast);

            % Mean stepping params
            epoch.addParameter('meanIntensities', obj.meanIntensities);
            epoch.addParameter('meanStepMs', obj.meanStepMs);
            epoch.addParameter('meanStepFrames', obj.meanStepFrames);
            epoch.addParameter('meanScheduleStartFrames', obj.meanScheduleStartFrames);
            epoch.addParameter('meanScheduleValues', obj.meanScheduleValues);
            epoch.addParameter('backgroundMean', obj.backgroundMean);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end

        function completeRun(obj)
            completeRun@manookinlab.protocols.ManookinLabStageProtocol(obj);
            % No gamma changes to restore.
        end
    end
end

function SpatialNoiseTwoMeans_offline_demo()
% Standalone offline recreation of the SpatialNoiseTwoMeans stimulus.
% - Uses Stage VSS to display the stimulus in a window
% - Logs reconstruction info and plots mean schedule + example frames
%
% Requirements: Stage on MATLAB path (import stage.core.* works)

    import stage.core.*

    %% ---------- USER PARAMS ----------
    windowSize      = [1024, 768];  % display window in pixels
    stixelSizePix   = 16;           % stixel edge length in *pixels*
    preTimeMs       = 250;
    stimTimeMs      = 16000;        % shorter for demo; set 160000 for full
    tailTimeMs      = 250;
    frameDwell      = 1;            % update noise every N frames
    meanStepMs      = 3000;         % change mean every block
    meanIntensities = [0.3, 0.7];   % if exactly 2, alternates; if >2, random per block
    contrast        = 1.0;          % scales amplitude around the mean
    refreshRate     = 60;           % Hz (override if you know your display rate)

    % Seeds for reproducibility (set [] to randomize)
    seedNoise = [];   % noise (stixel signs) RNG seed
    seedMean  = [];   % mean schedule RNG seed (used only if numel(meanIntensities) > 2)

    %% ---------- DERIVED PARAMS ----------
    preFrames       = round(preTimeMs  * 1e-3 * refreshRate);
    stimFrames      = round(stimTimeMs * 1e-3 * refreshRate);
    meanStepFrames  = max(1, round(meanStepMs * 1e-3 * refreshRate));
    backgroundMean  = min(meanIntensities);

    % Open Stage window/canvas
    window = Window(windowSize, false);         %#ok<NASGU> % windowed mode
    canvas = Canvas(window, 'disableDwm', false);

    % Geometry: number of stixels to cover canvas (+1 for edge coverage)
    numXStixels = ceil(canvas.size(1) / stixelSizePix) + 1;
    numYStixels = ceil(canvas.size(2) / stixelSizePix) + 1;

    % Initial image (background)
    imageMatrix0 = uint8(255 * backgroundMean * ones(numYStixels, numXStixels, 'single'));

    % Stimulus
    checker = stage.builtin.stimuli.Image(imageMatrix0);
    checker.position = canvas.size / 2;
    checker.size = [numXStixels, numYStixels] * stixelSizePix;
    checker.setMinFunction(GL.NEAREST);
    checker.setMagFunction(GL.NEAREST);

    % Presentation
    totalDurSec = (preTimeMs + stimTimeMs + tailTimeMs) * 1e-3;
    pres = Presentation(totalDurSec);
    pres.setBackgroundColor(backgroundMean);
    pres.addStimulus(checker);

    % Visible only during stim window
    visCtrl = stage.builtin.controllers.PropertyController( ...
        checker, 'visible', @(s) s.time >= preTimeMs*1e-3 && s.time < (preTimeMs+stimTimeMs)*1e-3);
    pres.addController(visCtrl);

    %% ---------- RNG & MEAN SCHEDULE (precompute & log) ----------
    % Seeds
    if isempty(seedNoise), seedNoise = RandStream.shuffleSeed; end
    if isempty(seedMean),  seedMean  = seedNoise + 1; end
    noiseStream = RandStream('mt19937ar','Seed', seedNoise);
    meanStream  = RandStream('mt19937ar','Seed', seedMean);

    % Mean schedule: start frames and values for the entire stim
    [meanStarts, meanValues] = buildMeanSchedule(stimFrames, meanStepFrames, meanIntensities, meanStream);

    % Pack a log (you can save this to .mat if you like)
    logInfo = struct( ...
        'seedNoise',              seedNoise, ...
        'seedMean',               seedMean, ...
        'refreshRate',            refreshRate, ...
        'preFrames',              preFrames, ...
        'stimFrames',             stimFrames, ...
        'meanStepFrames',         meanStepFrames, ...
        'meanIntensities',        meanIntensities, ...
        'meanScheduleStartFrames',meanStarts, ...
        'meanScheduleValues',     meanValues, ...
        'frameDwell',             frameDwell, ...
        'stixelSizePix',          stixelSizePix, ...
        'numXStixels',            numXStixels, ...
        'numYStixels',            numYStixels, ...
        'backgroundMean',         backgroundMean, ...
        'contrast',               contrast ...
    );

    % Controller: imageMatrix (achromatic, binary ±1 signs with mean steps)
    preF = preFrames;
    imgCtrl = stage.builtin.controllers.PropertyController(checker, 'imageMatrix', ...
        @(s) setStixels(s.frame - preF, noiseStream, logInfo));
    pres.addController(imgCtrl);

    %% ---------- PLAY ----------
    disp('Playing stimulus (Stage)...');
    pres.play(canvas);
    disp('Done.');

    %% ---------- OFFLINE RECONSTRUCTION FOR PLOTS ----------
    % Rebuild a few frames to visualize (no Stage, pure MATLAB)
    sampleFrames = min(3 * logInfo.meanStepFrames, logInfo.stimFrames);
    [cube, meansPerFrame] = reconstructFrames(sampleFrames, logInfo, seedNoise);

    % Plot mean schedule (full stim) & example frames
    plotSummary(logInfo, meansPerFrame, cube);

    % ---- nested helpers ----

    function im = setStixels(relFrame, noiseStream_, L)
        % relFrame: 0 at first stim frame; >0 during stim
        persistent S M lastBlockIdx
        if relFrame > 0
            % Block index (0-based), clamped to final
            blockIdx = floor(double(relFrame) / double(L.meanStepFrames));
            maxBlock = numel(L.meanScheduleValues) - 1;
            if blockIdx > maxBlock, blockIdx = maxBlock; end
            currMean = L.meanScheduleValues(blockIdx + 1);

            % Update on dwell boundary OR block change
            needNewNoise = isempty(S) || (mod(double(relFrame), double(L.frameDwell)) == 0);
            blockChanged = isempty(lastBlockIdx) || (blockIdx ~= lastBlockIdx);

            if needNewNoise || blockChanged
                if isempty(S) || needNewNoise
                    S = 2 * (noiseStream_.rand(L.numYStixels, L.numXStixels) > 0.5) - 1; % {-1,+1}
                end
                % Safe amplitude so μ±A in [0,1]
                A = L.contrast * min(currMean, 1 - currMean);
                M = currMean + A * S;
                M(M < 0) = 0; M(M > 1) = 1;
                lastBlockIdx = blockIdx;
            end
        else
            % Pre-time: background
            if isempty(M)
                M = L.backgroundMean * ones(L.numYStixels, L.numXStixels, 'single');
            end
        end
        im = uint8(255 * M);
    end

    function [starts, vals] = buildMeanSchedule(stimF, stepF, mu, mStream)
        nBlocks = max(1, ceil(stimF / stepF));
        starts  = (0:(nBlocks-1)) * stepF;   % 0-based frame indices
        nMeans  = numel(mu);
        vals    = zeros(1, nBlocks);
        if nMeans == 1
            vals(:) = mu(1);
        elseif nMeans == 2
            vals = mu(mod(0:nBlocks-1, 2) + 1); % alternate
        else
            lastIdx = 0;
            for k = 1:nBlocks
                idx = 1 + floor(nMeans * mStream.rand());
                if nMeans > 1 && k > 1 && idx == lastIdx
                    idx = 1 + mod(idx, nMeans); % avoid immediate repeat
                end
                vals(k) = mu(idx);
                lastIdx = idx;
            end
        end
    end

    function [cube, meansPerFrame] = reconstructFrames(nF, L, seedN)
        % Deterministically rebuild first nF stim frames (no Stage)
        % Returns: cube (H x W x nF) uint8, and mean applied for each frame
        rs = RandStream('mt19937ar','Seed', seedN);
        H = L.numYStixels; W = L.numXStixels;
        cube = zeros(H, W, nF, 'uint8');
        S = []; lastBlock = -1;
        meansPerFrame = zeros(1, nF);
        for f = 1:nF
            blockIdx = floor(double(f) / double(L.meanStepFrames));
            maxBlock = numel(L.meanScheduleValues) - 1;
            if blockIdx > maxBlock, blockIdx = maxBlock; end
            mu = L.meanScheduleValues(blockIdx + 1);
            meansPerFrame(f) = mu;
            needNewNoise = isempty(S) || (mod(double(f), double(L.frameDwell)) == 0);
            blockChanged = (blockIdx ~= lastBlock);
            if needNewNoise || blockChanged
                if isempty(S) || needNewNoise
                    S = 2 * (rs.rand(H, W) > 0.5) - 1;
                end
                A = L.contrast * min(mu, 1 - mu);
                M = mu + A * S;
                M(M < 0) = 0; M(M > 1) = 1;
                lastBlock = blockIdx;
            end
            cube(:,:,f) = uint8(255 * M);
        end
    end

    function plotSummary(L, meansPerFrame, cube)
        figure('Color','w','Name','SpatialNoiseTwoMeans: Offline Summary');

        % Plot the mean schedule over time (first few frames reconstructed)
        subplot(2,2,1);
        tms = (0:numel(meansPerFrame)-1) * (1000 / L.refreshRate);
        stairs(tms, meansPerFrame, 'LineWidth', 1.5);
        xlabel('Time (ms)'); ylabel('Mean intensity');
        title('Reconstructed mean schedule (first segment)');
        ylim([0 1]); grid on;

        % Show first frame of each of the first ~3 blocks (if available)
        nShow = min(3, size(cube,3));
        for i = 1:nShow
            subplot(2,2,1+i);
            imagesc(cube(:,:,i)); axis image off;
            colormap(gray(256));
            title(sprintf('Example frame %d', i));
        end

        % Text panel with key params
        subplot(2,2,4);
        axis off;
        txt = {
            sprintf('Noise seed: %d', L.seedNoise)
            sprintf('Mean seed:  %d', L.seedMean)
            sprintf('Refresh: %.1f Hz', L.refreshRate)
            sprintf('pre/stim frames: %d / %d', L.preFrames, L.stimFrames)
            sprintf('Mean step frames: %d', L.meanStepFrames)
            sprintf('Means: [%s]', num2str(L.meanIntensities))
            sprintf('frameDwell: %d', L.frameDwell)
            sprintf('stixel: %d px; grid: %dx%d', L.stixelSizePix, L.numXStixels, L.numYStixels)
            sprintf('backgroundMean: %.3f', L.backgroundMean)
            sprintf('contrast: %.3f', L.contrast)
            };
        text(0, 1, txt, 'VerticalAlignment','top', 'FontName','monospace');
    end
end

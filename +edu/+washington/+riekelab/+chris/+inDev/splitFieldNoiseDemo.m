function splitFieldNoiseDemo()
    import stage.core.*;
    
    % Open a window in windowed-mode and create a canvas. 'disableDwm' = false for demo only!
    window = Window([640, 480], false);
    canvas = Canvas(window, 'disableDwm', false);
    
    % Experiment parameters
    params = struct();
    params.meanIntensity = [0.3, 0.7];   % Two mean intensity values for the left field
    params.noiseStdv = 0.2;              % Standard deviation of noise for right field
    params.stimTime = 5000;              % Stimulus duration in ms
    params.frameDwell = 1;               % Number of monitor frames per update
    params.gapSize = 30;                 % Size of the middle gap in pixels
    params.middleIntensity = 0.2;        % Fixed intensity for the middle gap
    params.epochsToRun = 4;              % Number of epochs to run
    
    % Run the specified number of epochs
    for epochNum = 1:params.epochsToRun
        fprintf('Running epoch %d of %d\n', epochNum, params.epochsToRun);
        runEpoch(canvas, epochNum, params);
        
        % Wait a bit between epochs
        if epochNum < params.epochsToRun
            pause(1);
        end
    end
    
    % Window automatically closes when the window object is deleted.
end

function runEpoch(canvas, epochNum, params)
    % Create the split field rectangle stimulus
    rect = stage.builtin.stimuli.SplitFieldRectangle();
    rect.position = canvas.size/2;                  % Center on screen
    rect.size = [400, 200];                         % Overall rectangle size (width, height)
    rect.gapSize = params.gapSize;                  % Set fixed gap size in pixels
    rect.middleColor = [params.middleIntensity, params.middleIntensity, params.middleIntensity]; % Set fixed middle intensity
    
    % Set up the random noise for this epoch
    noiseSeed = RandStream.shuffleSeed;
    fprintf('%s %d\n', 'current epoch::', epochNum);
    
    % Determine mean intensity for this epoch
    if numel(params.meanIntensity) > 2
        epochMean = params.meanIntensity(randi(numel(params.meanIntensity)));
    else
        epochMean = params.meanIntensity(2 - mod(epochNum, 2));
    end
    fprintf('Left field mean intensity: %f\n', epochMean);
    
    % Set initial left field color based on the epoch mean
    rect.leftColor = [epochMean, epochMean, epochMean];
    
    % Generate right field noise pattern
    % Assuming frame rate at 60 Hz
    updateRate = 60 / params.frameDwell;
    framePerPeriod = ceil(updateRate * params.stimTime / 1e3);  % note that the frame here is not the monitor frame rate
    
    % Generate noise intensity values
    noiseStream = RandStream('mt19937ar', 'Seed', noiseSeed);
    intensityOverFrame = epochMean + params.noiseStdv * epochMean * noiseStream.randn(1, framePerPeriod);
    
    % Clamp values between 0 and 1
    intensityOverFrame(intensityOverFrame < 0) = 0;
    intensityOverFrame(intensityOverFrame > 1) = 1;
    
    % Duration of presentation in seconds
    duration = params.stimTime / 1000;
    
    % Create controller for left field intensity - simply alternate between the two mean values
    leftIntensityController = stage.builtin.controllers.PropertyController(rect, 'leftColor', ...
        @(state)getLeftIntensity(state.time, duration, params.meanIntensity));
    
    % Create controller for right field intensity - follow the precomputed noise pattern
    rightIntensityController = stage.builtin.controllers.PropertyController(rect, 'rightColor', ...
        @(state)getRightIntensity(state.frame, params.frameDwell, intensityOverFrame, framePerPeriod));
    
    % Create a presentation and add the stimulus and controllers
    presentation = stage.core.Presentation(duration);
    presentation.addStimulus(rect);
    presentation.addController(leftIntensityController);
    presentation.addController(rightIntensityController);
    
    % Play the presentation on the canvas!
    presentation.play(canvas);
end

% Function to determine left field intensity based on time
function color = getLeftIntensity(time, duration, meanIntensities)
    % Simply use the first mean for first half of epoch, second mean for second half
    if time < duration/2
        intensity = meanIntensities(1);
    else
        intensity = meanIntensities(2);
    end
    
    % Return as RGB
    color = [intensity, intensity, intensity];
end

% Function to determine right field intensity based on precomputed noise pattern
function color = getRightIntensity(frame, frameDwell, intensityOverFrame, framePerPeriod)
    % Calculate which frame we are in
    persistent intensity;
    if frame == 0
        % Initialize intensity for the first frame
        intensity = intensityOverFrame(1);
    elseif mod(frame, frameDwell) == 0
        % Update intensity at appropriate frames based on frameDwell
        frameIndex = (frame - mod(frame, frameDwell)) / frameDwell + 1;
        if frameIndex <= length(intensityOverFrame)
            intensity = intensityOverFrame(frameIndex);
        end
    end
    
    % Return as RGB
    color = [intensity, intensity, intensity];
end
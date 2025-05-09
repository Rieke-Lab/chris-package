function splitFieldDemo()
    import stage.core.*;
    
    % Open a window in windowed-mode and create a canvas. 'disableDwm' = false for demo only!
    window = Window([640, 480], false);
    canvas = Canvas(window, 'disableDwm', false);
    
    % Create the split field rectangle stimulus
    rect = SplitFieldRectangle();
    rect.position = canvas.size/2;       % Center on screen
    rect.size = [400, 200];              % Overall rectangle size (width, height)
    rect.gapSize = 20;                   % Initial gap size
    rect.leftColor = [0.8, 0, 0];        % Initial left section color (red)
    rect.middleColor = [0.2, 0.2, 0.2];  % Initial middle section color (dark gray)
    rect.rightColor = [0, 0, 0.8];       % Initial right section color (blue)
    
    % Duration of presentation in seconds
    duration = 6;
    
    % Create controllers to animate the split field rectangle
    
    % Controller for gap size (middle section) - oscillates between 10 and 50 pixels
    gapSizeController = stage.builtin.controllers.PropertyController(rect, 'gapSize', ...
        @(state)oscillateValue(state.time, 10, 50, duration));
    
    % Controllers for left section intensity - gradually increases from 0.2 to 1.0
    leftIntensityController = stage.builtin.controllers.PropertyController(rect, 'leftColor', ...
        @(state)[linearValue(state.time, 0.2, 1.0, duration), 0, 0]);
    
    % Controllers for right section intensity - gradually decreases from 1.0 to 0.2
    rightIntensityController = stage.builtin.controllers.PropertyController(rect, 'rightColor', ...
        @(state)[0, 0, linearValue(state.time, 1.0, 0.2, duration)]);
    
    % Controller for middle section opacity - oscillates between 0.3 and 1.0
    middleOpacityController = stage.builtin.controllers.PropertyController(rect, 'middleOpacity', ...
        @(state)oscillateValue(state.time, 0.3, 1.0, duration/2));
    
    % Create a presentation and add the stimulus and controllers
    presentation = Presentation(duration);
    presentation.addStimulus(rect);
    presentation.addController(gapSizeController);
    presentation.addController(leftIntensityController);
    presentation.addController(rightIntensityController);
    presentation.addController(middleOpacityController);
    
    % Play the presentation on the canvas!
    presentation.play(canvas);
    
    % Window automatically closes when the window object is deleted.
end

% Helper function to create a linearly changing value over time
function value = linearValue(time, startValue, endValue, duration)
    % Ensure time doesn't exceed duration
    time = min(time, duration);
    
    % Calculate how far we are through the animation (0 to 1)
    progress = time / duration;
    
    % Calculate current value
    value = startValue + (endValue - startValue) * progress;
end

% Helper function to create an oscillating value over time
function value = oscillateValue(time, minValue, maxValue, period)
    % Calculate oscillation based on sine wave
    % sin varies from -1 to 1, so we add 1 and divide by 2 to get 0 to 1
    oscillation = (sin(2 * pi * time / period) + 1) / 2;
    
    % Scale oscillation to the range we want
    value = minValue + (maxValue - minValue) * oscillation;
end
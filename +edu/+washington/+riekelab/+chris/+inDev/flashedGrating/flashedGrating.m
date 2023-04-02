% flashed gratings
window=stage.core.Window([1500 1500],false);
canvas=stage.core.Canvas(window);

obj.backgroundIntensity=0.1;
obj.stepIntensity=0.5;
obj.apertureDiameter=1000;
obj.currentBarWidth=250;
obj.spatialContrast=0.5;
obj.fixFlashTime=100;
obj.currentFlashDelay=500;
obj.flashDuration=100;

obj.preTime=500;
obj.stimTime=1000;
obj.tailTime=500;


obj.flashTimes=[obj.fixFlashTime obj.preTime+obj.currentFlashDelay obj.preTime+obj.stimTime-obj.fixFlashTime ...,
    obj.preTime+obj.stimTime+obj.currentFlashDelay  obj.preTime+obj.stimTime+obj.tailTime-obj.fixFlashTime];

for ind=1:2
    p=stage.core.Presentation((obj.preTime+obj.stimTime+obj.tailTime)/1e3);
    p.setBackgroundColor(obj.backgroundIntensity);
    
    % step background spot for specified time
    if ind==1
        spot = stage.builtin.stimuli.Ellipse();
        spot.radiusX = obj.apertureDiameter/2;
        spot.radiusY = obj.apertureDiameter/2;
        spot.position = canvas.size/2;
        p.addStimulus(spot);
        spotMean = stage.builtin.controllers.PropertyController(spot, 'color',...
            @(state)getSpotMean(obj, state.time));
        p.addController(spotMean); %add the controller
    else
        grate = stage.builtin.stimuli.Grating('square'); %square wave grating
        grate.orientation = 0;
        grate.size = [obj.apertureDiameter, obj.apertureDiameter];
        grate.position = canvas.size/2;
        grate.spatialFreq = 1/(2*obj.currentBarWidth);
        grate.color =(1+obj.spatialContrast)*obj.backgroundIntensity; %amplitude of square wave
        grate.contrast = obj.spatialContrast; %multiplier on square wave
        zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
        offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
        [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
        phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
        phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
        grate.phase = phaseShift; %keep contrast reversing boundary in center
        p.addStimulus(grate); %add grating to the presentation
        grateMean = stage.builtin.controllers.PropertyController(grate, 'color',...
            @(state)getGrateMean(obj, state.time));
        p.addController(grateMean); %add the controller
        % hide during pre & post
        grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
            @(state) getVisibility(obj,state.time));
        p.addController(grateVisible);
    end
    
    if (obj.apertureDiameter > 0) %% Create aperture
        aperture = stage.builtin.stimuli.Rectangle();
        aperture.position = canvas.size/2;
        aperture.color = obj.backgroundIntensity;
        aperture.size = [max(canvas.size) max(canvas.size)];
        mask = stage.core.Mask.createCircularAperture(obj.apertureDiameter/max(canvas.size), 1024); %circular aperture
        aperture.setMask(mask);
        p.addStimulus(aperture); %add aperture
    end
    
    p.play(canvas)
end
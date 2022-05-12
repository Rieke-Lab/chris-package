clearvars;
import stage.core.*;
obj.preTime = 500;                   % Grating leading duration (ms)
obj.stimTime = 1000;                 % Grating duration (ms)
obj.tailTime =500;                  % Grating trailing duration (ms)
obj.contrast = 0.3;                  % Grating contrast (0-1)
obj.barWidthList = [10 20 40 80 160];         % Bar width (microns)
obj.driftSpeed = 400;               % Center drift speed (pix/sec)
obj.meanIntensity = 0.5;       % Background light intensity (0-1)
obj.apertureRadius = 300;            % Aperature radius between inner and outer gratings.
obj.useRandomSeed = true;            % Random or repeated seed?
obj.preDir=30;
obj.um2pix=1;
obj.frameRate=60;

obj.dirList=mod([0 90 180 270]+obj.preDir,360);
window=Window([1800 1200],false);
canvas=Canvas(window);
obj.canvasSize=[1800 1200];

for b=1:numel(obj.barWidthList)
    obj.barWidth=obj.barWidthList(b);
    for d=1:numel(obj.dirList)
        obj.orientation=obj.dirList(d);
        p=Presentation((obj.preTime+obj.stimTime+obj.tailTime)*1e-3);
        p.setBackgroundColor(obj.meanIntensity);
        
        obj.driftSpeedPix = obj.driftSpeed/obj.um2pix;
        obj.apertureRadiusPix = obj.apertureRadius/obj.um2pix;
        obj.barWidthPix = obj.barWidth/obj.um2pix;
        
        grate = stage.builtin.stimuli.Grating('sine');
        grate.orientation = obj.orientation;
        grate.size = 2*obj.apertureRadiusPix*ones(1,2);
        grate.position = obj.canvasSize/2;
        grate.spatialFreq = 1/(2*obj.barWidthPix); %convert from bar width to spatial freq
        grate.contrast = obj.contrast;
        grate.color = 2*obj.meanIntensity;
        
        zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
        offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
        [shiftPix, ~] = min(offsets); % min(offsets(offsets>0)); %positive shift in pixels
        phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
        obj.phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
        grate.phase = obj.phaseShift ; %keep contrast reversing boundary in center
        
        gMask = stage.core.Mask.createCircularEnvelope(1024);
        grate.setMask(gMask);
        p.addStimulus(grate);
        
        phaseController = stage.builtin.controllers.PropertyController(grate, 'phase',...
            @(state) objectDriftTrajectory(obj, state.time - obj.preTime* 1e-3));
        p.addController(phaseController);
        
        %  Make the grating visible only during the stimulus time.
        grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
            @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
        p.addController(grateVisible);
        
        % add aperture
        if obj.apertureRadius>0
            aperture=stage.builtin.stimuli.Rectangle();
            aperture.position=obj.canvasSize/2;
            aperture.size=[obj.apertureRadiusPix*2 obj.apertureRadiusPix*2];
            mask=Mask.createCircularAperture(1,1024);
            aperture.setMask(mask);
            p.addStimulus(aperture);
            aperture.color=obj.meanIntensity;
        end
        p.play(canvas);
    end
end
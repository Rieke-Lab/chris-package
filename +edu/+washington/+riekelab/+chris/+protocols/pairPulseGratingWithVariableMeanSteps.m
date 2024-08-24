classdef pairPulseGratingWithVariableMeanSteps < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % Presents a pair of flash, intervened with opposing steps ( i.e. 0.9
    % contrast pairs intervened with -0.9 contrast, etc). 
    
    properties
        amp                             % Output amplifier
        preTime = 600                   % Spot leading duration (ms)
        stimTime = 2000                 % Spot duration (ms)
        tailTime = 400                  % Spot trailing duration (ms)
        spotDiameter = 200             % Spot diameter size (um)
        apertureDiameter=0
        grateContrast=0.9   % spatial contrast for grating
        grateDuration=300      % ms
        stepContrasts = [0.3 0.9]  % the opposing step with be just -flashContrast for simplicity
        meanIntensity = 0.1     % Background light intensity (0-1)
        pulseIntervals=0.5
        psth=true 
        numberOfAverages = uint16(3)    % Number of repeats 
        interpulseInterval = 0          % Duration between spots (s)
    end
    
    properties (Hidden)
        ampType
        currentStepContrast
        contrastIndex
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            colors = edu.washington.riekelab.turner.utils.pmkmp(numel(obj.stepContrasts),'CubicYF');
            obj.showFigure('edu.washington.riekelab.figures.FrameTimingFigure', obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            if obj.psth
                obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure',...
                    obj.rig.getDevice(obj.amp),'psth', obj.psth,...
                    'groupBy',{'currentStepContrast'},...
                    'sweepColor',colors);
            end
            % randomize the intervals 
            tpIndex=repmat(1:numel(obj.stepContrasts), 1, obj.numberOfAverages);
            obj.currentStepContrast=tpIndex(randperm(numel(tpIndex)));
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;

            obj.currentStepContrast=obj.stepContrasts(obj.contrastIndex(obj.numEpochsPrepared)); 
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            epoch.addParameter('currentStepContrast', obj.currentStepContrast)
        end
        
        
        function p = createPresentation(obj)
            try
                device = obj.rig.getDevice('Stage');
                canvasSize = device.getCanvasSize();
                
                spotDiameterPix = device.um2pix(obj.spotDiameter);
                apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);

                p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
                p.setBackgroundColor(obj.meanIntensity);
                
                step = stage.builtin.stimuli.Ellipse();
                step.color = obj.meanIntensity*(1+obj.currentStepContrast);
                step.radiusX = spotDiameterPix/2;
                step.radiusY = spotDiameterPix/2;
                step.position = canvasSize/2;
                p.addStimulus(step);
                stepController = stage.builtin.controllers.PropertyController(step, 'visible', ...
                     @(state) state.time >= (obj.preTime + obj.grateDuration) * 1e-3 && state.time < (obj.preTime + obj.grateDuration+obj.pulseIntervals) * 1e-3);
                p.addController(stepController);

                % overlay the grating flash 
                grate = stage.builtin.stimuli.Grating('square'); %square wave grating
                grate.orientation = 0;
                grate.size = [spotDiameterPix, spotDiameterPix];
                grate.position = canvasSize/2;
                grate.spatialFreq = 1/spotDiameterPix;
                grate.color =2*obj.meanIntensity; %amplitude of square wave
                grate.contrast = obj.grateContrast; %multiplier on square wave
                zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
                offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
                [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
                phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
                phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
                grate.phase = phaseShift; %keep grating boundary in center
                p.addStimulus(grate); %add grating to the presentation

                % show grating only a specific time 
                grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                    @(state) obj.getGrateVisibility(state.time));
                p.addController(grateVisible);

                if (obj.apertureDiameter > 0) %% Create aperture
                    aperture = stage.builtin.stimuli.Rectangle();
                    aperture.position = canvasSize/2;
                    aperture.color = 0;
                    aperture.size = [max(canvasSize) max(canvasSize)];
                    mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
                    aperture.setMask(mask);
                    p.addStimulus(aperture); %add aperture
                end
            catch ME
                disp(getReport(ME));
            end
        end


        function [visibility] = getGrateVisibility(obj,time)
            visibility=false;
            if (time>obj.preTime*1e-3 &&  time< (obj.preTime +obj.flashDuration) *1e-3)|| ...    % first flash
                    (time>(obj.preTime+obj.flashDuration+obj.pulseIntervals)*1e-3 &&  time< (obj.preTime+obj.flashDuration*2+obj.pulseIntervals) *1e-3)     % second flash
                visibility=true;
            end

        end


        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.stepContrasts);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.stepContrasts);
        end
        
    end
    
end
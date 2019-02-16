classdef CSEyeMovementLuminance < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 250                   % ms
        stimTime = 5200                 % ms, 5200 is longest trajectory in database
        tailTime = 250                  % ms
        stimulusIndex = 1               % 1-433
        centerDiameter = 200            % um
        numberOfAverages = uint16(15)   % Number of epochs to queue
        amp                             % Output amplifier
    end

    properties (Hidden)
        ampType
        centerTrajectory
        timeTraj
        currentStimSet
        backgroundIntensity
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            % Load data and get luminance trajectories.  Data stored in struct array luminanceData
            % with each luminanceData(i) having fields: ImageIndex SubjectIndex ImageName ImageMin 
            % ImageMax ImageMean centerTrajectory surroundTrajectory
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            obj.currentStimSet = 'SaccadeLuminanceTrajectoryStimuli_20160919.mat';
            S = load([resourcesDir, obj.currentStimSet]);

            % Pull appropriate stimuli. Scale such that brightest point in original image is 1.0 on the monitor
            obj.centerTrajectory = S.luminanceData(obj.stimulusIndex).centerTrajectory ...
                 ./ S.luminanceData(obj.stimulusIndex).ImageMax;
            
            obj.timeTraj = (0:(length(obj.centerTrajectory)-1)) ./ 200;     % sec
             
            % Set background intensity to the mean over the original image
            obj.backgroundIntensity = S.luminanceData(obj.stimulusIndex).ImageMean /...
                S.luminanceData(obj.stimulusIndex).ImageMax;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('currentStimSet', obj.currentStimSet);
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            % Convert from microns to pixels...
            centerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.centerDiameter);
            
            % Create presentation of specified duration
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity

            centerSpot = stage.builtin.stimuli.Ellipse();
            centerSpot.radiusX = centerDiameterPix/2;
            centerSpot.radiusY = centerDiameterPix/2;
            centerSpot.position = canvasSize/2;
            p.addStimulus(centerSpot);
            centerSpotIntensity = stage.builtin.controllers.PropertyController(centerSpot, 'color',...
                @(state)getNextIntensity(obj, state.time - obj.preTime/1e3, obj.centerTrajectory));
            p.addController(centerSpotIntensity);

            % Hide during pre & post
            centerSpotVisible = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(centerSpotVisible);
            
            function i = getNextIntensity(obj, time, trajectoryToUse)
                if time < 0                     % pre-time, start at mean
                    i = obj.backgroundIntensity;
                elseif time > obj.timeTraj(end) % out of eye trajectory, back to mean
                    i = obj.backgroundIntensity;
                else                            % within eye trajectory and stim time
                    i = interp1(obj.timeTraj,trajectoryToUse,time);
                end
            end            
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
    
end
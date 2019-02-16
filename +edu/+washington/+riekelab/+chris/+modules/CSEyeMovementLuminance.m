classdef CSEyeMovementLuminance < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 250 % ms
        stimTime = 5200 % ms, 5200 is longest trajectory in database
        tailTime = 250 % ms
        stimulusIndex = 1 % 1-433
        centerDiameter = 200 % um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 600 % um
        onlineAnalysis = 'none'
        numberOfAverages = uint16(15) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        currentStimulus
        centerTrajectory
        surroundTrajectory
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
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.CSAdditivityFigure',...
                    obj.rig.getDevice(obj.amp),...
                    'recordingType',obj.onlineAnalysis,...
                    'stimulusIndex',obj.stimulusIndex,...
                    'preTime',obj.preTime,'tailTime',obj.tailTime);
            end
            
            %load data and get luminance trajectories
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            obj.currentStimSet = 'SaccadeLuminanceTrajectoryStimuli_20160919.mat';
            load([resourcesDir, obj.currentStimSet]);
            %pull the appropriate center & surround stimuli. Scale such
            %that the brightest point in the original image is 1.0 on the
            %monitor
            obj.centerTrajectory = luminanceData(obj.stimulusIndex).centerTrajectory ...
                 ./ luminanceData(obj.stimulusIndex).ImageMax;
             
            obj.surroundTrajectory = luminanceData(obj.stimulusIndex).surroundTrajectory ...
                 ./ luminanceData(obj.stimulusIndex).ImageMax;
             
            obj.timeTraj = (0:(length(obj.centerTrajectory)-1)) ./ 200; %sec
             
            %set the background intensity to the mean over the original
            %image
            obj.backgroundIntensity = luminanceData(obj.stimulusIndex).ImageMean /...
                luminanceData(obj.stimulusIndex).ImageMax;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            %determine which stimulus to play this epoch
            %cycles thru center,surround, center + surround
            index = mod(obj.numEpochsCompleted,3);
            if index == 0
                obj.currentStimulus = 'Center';
            elseif index == 1
                obj.currentStimulus = 'Surround';
            elseif index == 2
                obj.currentStimulus = 'Center-Surround';
            end
            
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('currentStimSet', obj.currentStimSet);
            epoch.addParameter('currentStimulus', obj.currentStimulus);
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            centerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.centerDiameter);
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            if or(strcmp(obj.currentStimulus, 'Surround'), strcmp(obj.currentStimulus, 'Center-Surround'))
                surroundSpot = stage.builtin.stimuli.Ellipse();
                surroundSpot.radiusX = annulusOuterDiameterPix/2;
                surroundSpot.radiusY = annulusOuterDiameterPix/2;
                surroundSpot.position = canvasSize/2;
                p.addStimulus(surroundSpot);
                surroundSpotIntensity = stage.builtin.controllers.PropertyController(surroundSpot, 'color',...
                    @(state)getNextIntensity(obj, state.time - obj.preTime/1e3, obj.surroundTrajectory));
                p.addController(surroundSpotIntensity);
                % hide during pre & post
                surroundSpotVisible = stage.builtin.controllers.PropertyController(surroundSpot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(surroundSpotVisible);
                %mask / annulus...
                maskSpot = stage.builtin.stimuli.Ellipse();
                maskSpot.radiusX = annulusInnerDiameterPix/2;
                maskSpot.radiusY = annulusInnerDiameterPix/2;
                maskSpot.position = canvasSize/2;
                maskSpot.color = obj.backgroundIntensity;
                p.addStimulus(maskSpot);
            end
            if or(strcmp(obj.currentStimulus, 'Center'), strcmp(obj.currentStimulus, 'Center-Surround'))
                centerSpot = stage.builtin.stimuli.Ellipse();
                centerSpot.radiusX = centerDiameterPix/2;
                centerSpot.radiusY = centerDiameterPix/2;
                centerSpot.position = canvasSize/2;
                p.addStimulus(centerSpot);
                centerSpotIntensity = stage.builtin.controllers.PropertyController(centerSpot, 'color',...
                    @(state)getNextIntensity(obj, state.time - obj.preTime/1e3, obj.centerTrajectory));
                p.addController(centerSpotIntensity);
                % hide during pre & post
                centerSpotVisible = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(centerSpotVisible);
            end
            
            function i = getNextIntensity(obj, time, trajectoryToUse)
                if time < 0 %pre-time, start at mean
                    i = obj.backgroundIntensity;
                elseif time > obj.timeTraj(end) %out of eye trajectory, back to mean
                    i = obj.backgroundIntensity;
                else %within eye trajectory and stim time
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
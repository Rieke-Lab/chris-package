classdef CenterSurroundNoise < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 500 % ms
        stimTime = 8000 % ms
        tailTime = 500 % ms
        centerDiameter = 200 % um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 600 % um
        noiseStdv = 0.3 %contrast, as fraction of mean
        backgroundIntensity = 0.5 % (0-1)
        frameDwell = 2 % Frames per noise update
        useRandomSeed = true % false = repeated noise trajectory (seed 0)
        onlyIndependentTrials = false; %false = also do C+S. True = just get c and s indep for filters

        onlineAnalysis = 'none'
        numberOfAverages = uint16(30) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        centerNoiseSeed
        surroundNoiseSeed
        centerNoiseStream
        surroundNoiseStream
        currentStimulus
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
                if (obj.onlyIndependentTrials) %c, s
                    updatePatternC = [1,2];
                    updatePatternS = [2,2];
                else %c, s, c+s
                    updatePatternC = [1,3];
                    updatePatternS = [2,3];
                   
                end
                
                obj.showFigure('edu.washington.riekelab.turner.figures.LinearFilterFigure',...
                    obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
                    obj.rig.getDevice('Stage'),...
                    'recordingType',obj.onlineAnalysis,...
                    'preTime',obj.preTime,'stimTime',obj.stimTime,...
                    'frameDwell',obj.frameDwell,'seedID','centerNoiseSeed',...
                    'updatePattern',updatePatternC,'figureTitle','Center');
            
                obj.showFigure('edu.washington.riekelab.turner.figures.LinearFilterFigure2',...
                    obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
                    obj.rig.getDevice('Stage'),...
                    'recordingType',obj.onlineAnalysis,...
                    'preTime',obj.preTime,'stimTime',obj.stimTime,...
                    'frameDwell',obj.frameDwell,'seedID','surroundNoiseSeed',...
                    'updatePattern',updatePatternS,'figureTitle','Surround','noiseStdv',obj.noiseStdv);
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            %determine which stimulus to play this epoch
            if (obj.onlyIndependentTrials)
                %cycles thru center, surround
                index = mod(obj.numEpochsCompleted,2);
            else %do c, s, and c+s
                %cycles thru center, surround, center + surround
                index = mod(obj.numEpochsCompleted,3);
            end
            if index == 0
                obj.currentStimulus = 'Center';
                % Determine seed values.
                if obj.useRandomSeed
                    obj.centerNoiseSeed = RandStream.shuffleSeed;
                    obj.surroundNoiseSeed = RandStream.shuffleSeed;
                else
                    obj.centerNoiseSeed = 0;
                    obj.surroundNoiseSeed = 1;
                end
            elseif index == 1
                obj.currentStimulus = 'Surround';
            elseif index == 2
                obj.currentStimulus = 'Center-Surround';
            end
            %at start of epoch, set random streams using this cycle's seeds
            obj.centerNoiseStream = RandStream('mt19937ar', 'Seed', obj.centerNoiseSeed);
            obj.surroundNoiseStream = RandStream('mt19937ar', 'Seed', obj.surroundNoiseSeed);

            epoch.addParameter('centerNoiseSeed', obj.centerNoiseSeed);
            epoch.addParameter('surroundNoiseSeed', obj.surroundNoiseSeed);
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
            preFrames = round(60 * (obj.preTime/1e3));
            if or(strcmp(obj.currentStimulus, 'Surround'), strcmp(obj.currentStimulus, 'Center-Surround'))
                surroundSpot = stage.builtin.stimuli.Ellipse();
                surroundSpot.radiusX = annulusOuterDiameterPix/2;
                surroundSpot.radiusY = annulusOuterDiameterPix/2;
                surroundSpot.position = canvasSize/2;
                p.addStimulus(surroundSpot);
                surroundSpotIntensity = stage.builtin.controllers.PropertyController(surroundSpot, 'color',...
                    @(state)getSurroundIntensity(obj, state.frame - preFrames));
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
                    @(state)getCenterIntensity(obj, state.frame - preFrames));
                p.addController(centerSpotIntensity);
                % hide during pre & post
                centerSpotVisible = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(centerSpotVisible);
            end

            function i = getCenterIntensity(obj, frame)
                persistent intensity;
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = obj.backgroundIntensity;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = obj.backgroundIntensity + ... 
                            obj.noiseStdv * obj.backgroundIntensity * obj.centerNoiseStream.randn;
                    end
                end
                i = intensity;
            end
            
            function i = getSurroundIntensity(obj, frame)
                persistent intensity;
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = obj.backgroundIntensity;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = obj.backgroundIntensity + ... 
                            obj.noiseStdv * obj.backgroundIntensity * obj.surroundNoiseStream.randn;
                    end
                end
                i = intensity;
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
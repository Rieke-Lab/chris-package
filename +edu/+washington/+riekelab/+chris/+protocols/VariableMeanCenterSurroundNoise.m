classdef VariableMeanCenterSurroundNoise < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 0 % ms
        stimTime = 50000 % ms
        tailTime = 0 % ms
        centerDiameter = 160 % um
        annulusInnerDiameter = 200 % um
        annulusOuterDiameter = 800 % um
        noiseStdv = 0.3 %contrast, as fraction of mean
        meanInternsity = [0.05 0.5] % (0-1)
        frameDwell = 2 % Frames per noise update
        useRandomSeed = true % false = repeated noise trajectory (seed 0)
        numberOfAverages = uint16(30) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        centerNoiseSeed
        centerNoiseStream
        centerMean
        surroundMean
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
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            centerIndex= mod(obj.numEpochsCompleted,2)+1;
            surroundIndex= mod(obj.numEpochsCompleted,6)+1;
            obj.centerNoiseSeed = RandStream.shuffleSeed;
            if centerIndex == 1
                obj.centerMean=obj.meanIntensity(1);
                % Determine seed values.
                obj.centerMean=obj.meanIntensity(2);
            end
            switch surroundIndex
                case 1
                    obj.surroundMean=obj.meanIntensity(1);
                case 2
                    obj.surroundMean=obj.meanIntensity(1);
                case 3
                    obj.surroundMean=obj.meanIntensity(1);
                case 4
                    obj.surroundMean=obj.meanIntensity(2);
                case 5
                    obj.surroundMean=obj.meanIntensity(2);
                case 6
                    obj.surroundMean=obj.meanIntensity(1);
            end
            
            %at start of epoch, set random streams using this cycle's seeds
            obj.centerNoiseStream = RandStream('mt19937ar', 'Seed', obj.centerNoiseSeed);
            epoch.addParameter('centerNoiseSeed', obj.centerNoiseSeed);
            epoch.addParameter('currentMean', obj.currentStimulus);
            epoch.addParameter('surroundtMean', obj.obj.surroundMean);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            centerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.centerDiameter);
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.surroundMean); % Set background intensity as the lower meanIntensity
            preFrames = round(60 * (obj.preTime/1e3));
            
            % center noise
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
            
            % surround spot
            surroundSpot = stage.builtin.stimuli.Ellipse();
            surroundSpot.radiusX = annulusOuterDiameterPix/2;
            surroundSpot.radiusY = annulusOuterDiameterPix/2;
            surroundSpot.position = canvasSize/2;
            surroundSpot.color=obj.surroundMean;
            p.addStimulus(surroundSpot);
            % hide during pre & post
            surroundSpotVisible = stage.builtin.controllers.PropertyController(surroundSpot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(surroundSpotVisible);
            %mask / annulus...
            maskSpot = stage.builtin.stimuli.Ellipse();
            maskSpot.radiusX = annulusInnerDiameterPix/2;
            maskSpot.radiusY = annulusInnerDiameterPix/2;
            maskSpot.position = canvasSize/2;
            maskSpot.color = obj.meanIntensity(1);
            p.addStimulus(maskSpot);
                  
            function i = getCenterIntensity(obj, frame)
                persistent intensity;
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = obj.meanIntensity;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = obj.meanIntensity + ...
                            obj.noiseStdv * obj.meanIntensity * obj.centerNoiseStream.randn;
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
classdef FullFieldNoise < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 500                   % ms
        stimTime = 8000                 % ms
        tailTime = 500                  % ms
        apertureDiameter = 0            % um
        noiseStdv = 0.3                 % Contrast, as fraction of mean
        backgroundIntensity = 0.5       % (0-1)
        frameDwell = 1                  % Frames per noise update
        useRandomSeed = true            % false = repeated noise trajectory (seed 0)

        onlineAnalysis = 'none'
        numberOfAverages = uint16(10)   % Number of epochs to queue
        amp                             % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        noiseSeed
        noiseStream
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
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.LinearFilterFigure',...
                    obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
                    obj.rig.getDevice('Stage'),...
                    'recordingType',obj.onlineAnalysis,'preTime',obj.preTime,...
                    'stimTime',obj.stimTime,'frameDwell',obj.frameDwell,...
                    'noiseStdv',obj.noiseStdv);
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            % Determine seed values.
            if obj.useRandomSeed
                obj.noiseSeed = RandStream.shuffleSeed;
            else
                obj.noiseSeed = 0;
            end
            
            %at start of epoch, set random stream
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            % Convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create noise stimulus.            
            noiseRect = stage.builtin.stimuli.Rectangle();
            noiseRect.size = canvasSize;
            noiseRect.position = canvasSize/2;
            p.addStimulus(noiseRect);
            preFrames = round(60 * (obj.preTime/1e3));
            noiseValue = stage.builtin.controllers.PropertyController(noiseRect, 'color',...
                @(state)getNoiseIntensity(obj, state.frame - preFrames));
            p.addController(noiseValue);  % add the controller

            function i = getNoiseIntensity(obj, frame)
                persistent intensity;
                if frame<0  % pre frames. frame 0 starts stimPts
                    intensity = obj.backgroundIntensity;
                else        % in stim frames
                    if mod(frame, obj.frameDwell) == 0  % noise update
                        intensity = obj.backgroundIntensity + ...
                            obj.noiseStdv * obj.backgroundIntensity * obj.noiseStream.randn;
                    end
                end
                i = intensity;
            end

            if (obj.apertureDiameter > 0)  % create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture);  % add aperture
            end
            
            % Hide during pre & post
            noiseRectVisible = stage.builtin.controllers.PropertyController(noiseRect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(noiseRectVisible);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
    
end
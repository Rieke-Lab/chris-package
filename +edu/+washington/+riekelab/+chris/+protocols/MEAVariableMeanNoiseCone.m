classdef MEAVariableMeanNoiseCone < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 0 % ms
        stimTime = 500 % ms, change mean intensity every xxx
        tailTime = 0 % ms
        apertureDiameter = 0 % um
        noiseStdv = 0.3 %contrast, as fraction of mean
        meanIntensity = [0.03 0.06 0.09 0.12 0.18 0.3]
        frameDwell = 1 % Frames per noise update
        numberOfAverages = uint16(1200) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        meanIntensityType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        noiseSeed
        currentMean
        fixedSeeds
        intensityOverFrame
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);      
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            obj.fixedSeeds=1:obj.numberOfAverages;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;

            obj.noiseSeed = obj.fixSeeds(obj.numEpochsPrepared);
            %at start of epoch, set random stream
            epochMean=obj.meanIntensity(randi(numel(obj.meanIntensity)));    
 
            % assuming frame rate at 60 Hz 
            updateRate=60/obj.frameDwell;
            framePerPeriod=ceil(updateRate*obj.stimTime/1e3);  % note that the frame here is not the monitor frame rate
            obj.intensityOverFrame=zeros(1,framePerPeriod);
            noiseStream= RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            obj.intensityOverFrame(1:framePerPeriod)= epochMean+ ...
                obj.noiseStdv * epochMean * noiseStream.randn(1, framePerPeriod);
            
            obj.intensityOverFrame(obj.intensityOverFrame<0)=0;
            obj.intensityOverFrame(obj.intensityOverFrame>1)=1;
            
            epoch.addDirectCurrentStimulus(device, device.background,duration , obj.sampleRate);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
            epoch.addParameter('currentMean', epochMean);
            epoch.addResponse(device);       
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter); 
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.currentMean); % Set background intensity
            
            % Create noise stimulus.            
            noiseRect = stage.builtin.stimuli.Rectangle();
            noiseRect.size = canvasSize;
            noiseRect.position = canvasSize/2;
            p.addStimulus(noiseRect);
            preFrames = round(60 * (obj.preTime/1e3));
            noiseValue = stage.builtin.controllers.PropertyController(noiseRect, 'color',...
                @(state)getNoiseIntensity(obj,state.frame - preFrames, obj.intensityOverFrame));
            p.addController(noiseValue); %add the controller
 
            function i = getNoiseIntensity(obj, frame,internsityArrays)
                persistent intensity;
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = obj.meanIntensityArray(1);
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = internsityArrays((frame-mod(frame,obj.frameDwell))/obj.frameDwell+1) ;
                    end                  
                end
                i = intensity;
            end

            if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = 0;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            % hide during pre & post
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
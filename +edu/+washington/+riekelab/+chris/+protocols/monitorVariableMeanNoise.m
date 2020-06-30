classdef monitorVariableMeanNoise < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 500 % ms
        epochDuration = 2000 % ms, change mean intensity every xxx
        tailTime = 500 % ms
        apertureDiameter = 300 % um
        noiseStdv = 0.9 %contrast, as fraction of mean
        meanIntensity = [0.05 0.2 0.5]
        frameDwell = 1 % Frames per noise update
        useRandomSeed = true % false = repeated noise trajectory (seed 0)
        onlineAnalysis = 'none'
        numberOfReps = uint16(50) % number of switching period each epoch
        numberOfEpochs = uint16(1) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        noiseSeed
        intensitySeed
        meanIntensityArray
        intensityOverFrame
        stimTime
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);      
            obj.stimTime=obj.epochDuration*numel(obj.meanIntensity)*obj.numberOfReps;
            % Determine seed values.
            for i=1:numel(obj.meanIntensity)*obj.numberOfReps
                obj.noiseSeed(i) = RandStream.shuffleSeed;
            end
            obj.intensitySeed=RandStream.shuffleSeed;   
            %at start of epoch, set random stream
            intensityStream = RandStream('mt19937ar', 'Seed', obj.intensitySeed);
            intensities=intensityStream.randi(numel(obj.meanIntensity),1,numel(obj.meanIntensity)*obj.numberOfReps);
            for i=1:numel(intensities)
                obj.meanIntensityArray(i)=obj.meanIntensity(intensities(i));
            end
            
            % assuming frame rate at 60 Hz 
            updateRate=60/obj.frameDwell;
            framePerPeriod=ceil(updateRate*obj.epochDuration/1e3);  % note that the frame here is not the monitor frame rate
            obj.intensityOverFrame=zeros(1,framePerPeriod*numel(obj.meanIntensityArray));
            for i=1:numel(obj.meanIntensityArray)
                noiseStream= RandStream('mt19937ar', 'Seed', obj.noiseSeed(i));
                obj.intensityOverFrame((i-1)*framePerPeriod+1: i*framePerPeriod)= obj.meanIntensityArray(i)+ ...
                    obj.noiseStdv * obj.meanIntensityArray(i) * noiseStream.randn(1, framePerPeriod);
            end
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
%             if ~strcmp(obj.onlineAnalysis,'none')
%                 obj.showFigure('edu.washington.riekelab.chris.figures.LinearFilterFigure',...
%                 obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
%                 obj.rig.getDevice('Stage'),...
%                 'recordingType',obj.onlineAnalysis,'preTime',obj.preTime,...
%                 'stimTime',obj.stimTime,'frameDwell',obj.frameDwell,...
%                 'noiseStdv',obj.noiseStdv);
%             end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, double(duration) , obj.sampleRate);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
            epoch.addParameter('intensitySeed', obj.intensitySeed);
            epoch.addParameter('intensityOverFrame', obj.intensityOverFrame);
            epoch.addResponse(device);                     
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter); 
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.meanIntensityArray(1)); % Set background intensity
            
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
            tf = obj.numEpochsPrepared < obj.numberOfEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfEpochs;
        end
    end
    
end
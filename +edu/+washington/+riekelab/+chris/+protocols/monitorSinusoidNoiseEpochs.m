classdef monitorSinusoidNoiseEpochs < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 0 % ms
        stimTime = 2000 % ms
        tailTime = 0 % ms
        apertureDiameter = 0 % um
        noiseStdv = 0.3 % contrast, as fraction of mean
        temporalContrast = 0.5 % contrast of sinusoidal modulation (0-1)
        temporalFrequency = 2 % Hz
        meanIntensity = 0.4 % (0-1)
        frameDwell = 1 % Frames per noise update
        useRandomSeed = true % false = repeated noise trajectory (seed 0)
        onlineAnalysis = 'extracellular'
        numberOfAverages = uint16(100) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        meanIntensityType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        noiseSeed
        currentMean
        intensityOverFrame
        noiseOverFrame  % Store just the noise component for LN model 
        sinusoidOverFrame  % Store just the sinusoidal component ( to decice rising and decay phase)
        stimulusTag
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);      

            colors=edu.washington.riekelab.chris.utils.pmkmp(3,'IsoL');
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));

            % Add mean response figure grouped by stimulus type
            obj.showFigure('edu.washington.riekelab.chris.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'stimulusTag'},'sweepColor',colors);

            % Add intensity trace online analysis
            obj.showFigure('edu.washington.riekelab.chris.figures.IntensityTraceFigure',...
                obj.rig.getDevice('Frame Monitor'),...
                obj.rig.getDevice('Stage'));

            % add online analysis
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.chris.figures.PhaseLinearFilterFigure',...
                    obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
                    obj.rig.getDevice('Stage'),...
                    'recordingType',obj.onlineAnalysis,'preTime',obj.preTime,...
                    'stimTime',obj.stimTime,'frameDwell',obj.frameDwell,...
                    'figureTitle','Phase-separated Noise Analysis');
            end
            %%%%%%%%%%%%%%%%%%
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;

            % Automatically determine stimulus type based on epoch number
            stimTypes = {'sinusoidOnly', 'noiseOnly', 'sinusoidPlusNoise'};
            currentStimType = stimTypes{mod(obj.numEpochsCompleted, 3) + 1};

            obj.noiseSeed = RandStream.shuffleSeed;
            fprintf('%s %d\n', 'current epoch::', obj.numEpochsPrepared);
            
            epochMean = obj.meanIntensity;

            % Calculate frames needed based on 60Hz monitor and frameDwell
            updateRate = 60/obj.frameDwell;
            framePerPeriod = ceil(updateRate*obj.stimTime/1e3);

            % Generate base sinusoidal modulation
            timePoints = linspace(0, obj.stimTime/1e3, framePerPeriod);
            obj.sinusoidOverFrame = epochMean + epochMean * obj.temporalContrast * ...
                sin(2 * pi * obj.temporalFrequency * timePoints);

            % Calculate sinusoid derivative to determine rising/falling phases
            sinusoidDiff = [0, diff(obj.sinusoidOverFrame)];
            isRising = sinusoidDiff > 0;

            % Generate noise for one phase
            noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            uniqueNoiseValues = obj.noiseStdv * epochMean * noiseStream.randn(1, ceil(framePerPeriod/2));

            % Create noise trace by mapping the unique noise values to both phases
            obj.noiseOverFrame = zeros(1, framePerPeriod);
            risingCount = 1;
            fallingCount = 1;

            for i = 1:framePerPeriod
                if isRising(i)
                    if risingCount <= length(uniqueNoiseValues)
                        obj.noiseOverFrame(i) = uniqueNoiseValues(risingCount);
                        risingCount = risingCount + 1;
                    end
                else
                    if fallingCount <= length(uniqueNoiseValues)
                        obj.noiseOverFrame(i) = uniqueNoiseValues(fallingCount);
                        fallingCount = fallingCount + 1;
                    end
                end
            end


            % Generate stimulus based on current stimulus type
            switch currentStimType
                case 'sinusoidOnly'
                    obj.noiseOverFrame = zeros(1, framePerPeriod);  % Explicitly set noise to zeros
                    obj.intensityOverFrame = obj.sinusoidOverFrame;

                case 'noiseOnly'
                    obj.sinusoidOverFrame = epochMean * ones(1, framePerPeriod); % flat line at mean
                    obj.intensityOverFrame = epochMean + obj.noiseOverFrame;

                case 'sinusoidPlusNoise'
                    obj.intensityOverFrame = obj.sinusoidOverFrame + obj.noiseOverFrame;
            end
    
            % Clip values to valid range [0,1]
            obj.intensityOverFrame(obj.intensityOverFrame < 0) = 0;
            obj.intensityOverFrame(obj.intensityOverFrame > 1) = 1;
      
            % save epoch parameters 
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
            epoch.addParameter('currentMean', obj.meanIntensity);
            epoch.addParameter('intensityOverFrame', obj.intensityOverFrame);
            epoch.addParameter('noiseOverFrame', obj.noiseOverFrame);  % Save noise component separately
            epoch.addParameter('sinusoidOverFrame', obj.sinusoidOverFrame);  % Save sinusoidal component separately
            epoch.addParameter('stimulusTag', currentStimType);
            epoch.addResponse(device);       
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.meanIntensity);
            
            % Create stimulus
            noiseRect = stage.builtin.stimuli.Rectangle();
            noiseRect.size = canvasSize;
            noiseRect.position = canvasSize/2;
            p.addStimulus(noiseRect);
            
            preFrames = round(60 * (obj.preTime/1e3));
            noiseValue = stage.builtin.controllers.PropertyController(noiseRect, 'color',...
                @(state)getNoiseIntensity(obj, state.frame - preFrames, obj.intensityOverFrame));
            p.addController(noiseValue);
 
            function i = getNoiseIntensity(obj, frame, intensityArrays)
                persistent intensity;
                if frame < 0 % pre frames
                    intensity = obj.meanIntensity;
                else % in stim frames
                    if mod(frame, obj.frameDwell) == 0 % update
                        frameIndex = (frame-mod(frame,obj.frameDwell))/obj.frameDwell + 1;
                        if frameIndex <= length(intensityArrays)
                            intensity = intensityArrays(frameIndex);
                        end
                    end                  
                end
                i = intensity;
            end

            if (obj.apertureDiameter > 0) % Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.meanIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
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
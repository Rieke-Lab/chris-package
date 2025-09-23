classdef splitFieldAlternatingProtocol < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 0 % ms
        stimTime = 2000 % ms, time for each mean intensity before switching
        tailTime = 0 % ms
        apertureDiameter = 0 % um
        noiseStdv = 0.3 % contrast, as fraction of mean for right field
        leftMeanIntensity = [0.08 0.65] % intensity values to alternate between for left field
        rightFieldMean = 0.4 % fixed mean intensity for the right field noise
        gapSize = 30 % um, Size of the middle gap
        frameDwell = 2 % Frames per noise update
        useRandomSeed = true % false = repeated noise trajectory (seed 0)
        onlineAnalysis = 'extracellular'
        numberOfAverages = uint16(200) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        leftMeanIntensityType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        noiseSeed
        currentLeftMean
        rightFieldIntensityOverFrame
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);      

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.chris.figures.SplitFieldFilterFigure',...
                obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
                obj.rig.getDevice('Stage'),...
                'recordingType',obj.onlineAnalysis,'preTime',obj.preTime,...
                'stimTime',obj.stimTime,'frameDwell',obj.frameDwell,...
                'leftMeanIntensity',obj.leftMeanIntensity);
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;

            obj.noiseSeed = RandStream.shuffleSeed;
            fprintf('%s %d\n', 'current epoch::', obj.numEpochsPrepared);
            
            % Determine mean intensity for this epoch
            if numel(obj.leftMeanIntensity) > 2
                epochMean = obj.leftMeanIntensity(randi(numel(obj.leftMeanIntensity)));
            else 
                epochMean = obj.leftMeanIntensity(2 - mod(obj.numEpochsPrepared, 2));
            end
            obj.currentLeftMean = epochMean;
            
            % Generate noise for right field
            % assuming frame rate at 60 Hz 
            updateRate = 60 / obj.frameDwell;
            framePerPeriod = ceil(updateRate * obj.stimTime / 1e3);  % note that the frame here is not the monitor frame rate
            obj.rightFieldIntensityOverFrame = zeros(1, framePerPeriod);
            
            % Generate random noise for right field using the fixed rightFieldMean
            noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            obj.rightFieldIntensityOverFrame(1:framePerPeriod) = obj.rightFieldMean + ...
                obj.noiseStdv * obj.rightFieldMean * noiseStream.randn(1, framePerPeriod);
            
            % Clamp values between 0 and 1
            obj.rightFieldIntensityOverFrame(obj.rightFieldIntensityOverFrame < 0) = 0;
            obj.rightFieldIntensityOverFrame(obj.rightFieldIntensityOverFrame > 1) = 1;
            
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
            epoch.addParameter('currentLeftMean', epochMean);
            epoch.addParameter('rightFieldIntensityOverFrame', obj.rightFieldIntensityOverFrame);
            epoch.addResponse(device);       
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            % Convert from microns to pixels
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            gapSizePix = obj.rig.getDevice('Stage').um2pix(obj.gapSize);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(min(obj.leftMeanIntensity));
            
            % Calculate field dimensions and positions
            if obj.apertureDiameter > 0
                totalWidth = apertureDiameterPix;
                totalHeight = apertureDiameterPix;
            else
                totalWidth = canvasSize(1);
                totalHeight = canvasSize(2);
            end
            
            halfGapWidth = gapSizePix / 2;
            leftWidth = (totalWidth - gapSizePix) / 2;
            rightWidth = leftWidth;
            
            % Create left field rectangle
            leftField = stage.builtin.stimuli.Rectangle();
            leftField.position = [canvasSize(1)/2 - (rightWidth/2 + halfGapWidth), canvasSize(2)/2];
            leftField.size = [leftWidth, totalHeight];
            leftField.color = [obj.currentLeftMean, obj.currentLeftMean, obj.currentLeftMean];
            p.addStimulus(leftField);
            

            
            % Create right field rectangle
            rightField = stage.builtin.stimuli.Rectangle();
            rightField.position = [canvasSize(1)/2 + (leftWidth/2 + halfGapWidth), canvasSize(2)/2];
            rightField.size = [rightWidth, totalHeight];
            rightField.color = [obj.rightFieldMean, obj.rightFieldMean, obj.rightFieldMean];
            p.addStimulus(rightField);
            
           
            % Controller for right field intensity (follows noise pattern based on frame)
            rightIntensityController = stage.builtin.controllers.PropertyController(rightField, 'color', ...
                @(state)getRightFieldIntensity(obj, state.frame - round(60 * (obj.preTime/1e3)), obj.rightFieldIntensityOverFrame));
            p.addController(rightIntensityController);
            
            % Controller for stimulus visibility
            function visible = getVisible(state, preTime, stimTime)
                visible = (state.time >= preTime * 1e-3) && ...
                          (state.time < (preTime + stimTime) * 1e-3);
            end
            
            leftFieldVisible = stage.builtin.controllers.PropertyController(leftField, 'visible', ...
                @(state)getVisible(state, obj.preTime, obj.stimTime));
            rightFieldVisible = stage.builtin.controllers.PropertyController(rightField, 'visible', ...
                @(state)getVisible(state, obj.preTime, obj.stimTime));
            
            p.addController(leftFieldVisible);
            p.addController(rightFieldVisible);
            
            % Create aperture if specified
            if (obj.apertureDiameter > 0)
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = 0;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
            end
           

            function c = getRightFieldIntensity(obj, frame, intensityArray)
                persistent intensity;
                
                if frame < 0 % pre frames
                    intensity = obj.rightFieldMean;
                else % in stim frames
                    if mod(frame, obj.frameDwell) == 0 % noise update
                        frameIndex = (frame - mod(frame, obj.frameDwell)) / obj.frameDwell + 1;
                        % Ensure valid index
                        if frameIndex <= length(intensityArray)
                            intensity = intensityArray(frameIndex);
                        end
                    end
                end         
                c = [intensity, intensity, intensity];
            end
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.leftMeanIntensity);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.leftMeanIntensity);
        end
    end
    
end
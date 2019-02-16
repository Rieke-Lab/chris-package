classdef UniformSpotSeries < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        % parameters for noise
        preTime = 500                   % ms
        stimTime = 5200                 % ms
        tailTime = 500                  % ms
        apertureDiameter = 200          % um
        noiseMean = 0.5                 % (0-1)
        noiseStdv = 0.3                 % Contrast, as fraction of mean
        frameDwell = 1                  % Frames per noise update
        useRandomFirstSeed = true       % false = repeated noise trajectory (seed 0)

        % Parameters for image-derived sequences
        stimulusFile = 'luminanceSequenceDataset_20181203.mat';
        firstStimulusNum = 1;

        % onlineAnalysis = 'none'
        repeatCycle = false;
        numberOfCycles = uint16(10)     % Number of epochs to queue
        amp                             % Output amplifier
    end

    properties (Hidden)
        % onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        stimulusFileType = symphonyui.core.PropertyType('char', 'row', {'luminanceSequenceDataset_20181109.mat'})
        ampType
        backgroundIntensity

        noiseSeed
        noiseStream

        stimulusDataset
        entriesPerImage
        randOrder
        currSequence
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
            % if ~strcmp(obj.onlineAnalysis,'none')
            %     obj.showFigure('edu.washington.riekelab.turner.figures.LinearFilterFigure',...
            %         obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
            %         obj.rig.getDevice('Stage'),...
            %         'recordingType',obj.onlineAnalysis,'preTime',obj.preTime,...
            %         'stimTime',obj.stimTime,'frameDwell',obj.frameDwell,...
            %         'noiseStdv',obj.noiseStdv);
            % end

            % Load data and get luminance trajectories.  Data stored in struct array
            % with each struct(i) having fields: ImageIndex SubjectIndex ImageName ImageMin 
            % ImageMax ImageMean centerTrajectory surroundTrajectory
            resourcesDir = 'C:\Users\Public\Documents\mardoum-package\resources\';
            S = load([resourcesDir, obj.stimulusFile]);
            obj.stimulusDataset = S.DS;

            % Get random ordering. Assumption: each image has data for same number of 'subjects'
            obj.entriesPerImage = length(obj.stimulusDataset(1).doves.sequence);
            obj.randOrder = randperm(length(obj.stimulusDataset) * obj.entriesPerImage);
            switchPlace = find(obj.randOrder == obj.firstStimulusNum);  % shift designated first stim to front of order
            obj.randOrder([1; switchPlace]) = obj.randOrder([switchPlace; 1]);
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            stimulusGroup = obj.getStimulusGroup();
            epoch.addParameter('stimulusGroup', stimulusGroup);

            if stimulusGroup == 1  % noise epoch
                obj.backgroundIntensity = obj.noiseMean;

                if obj.numEpochsPrepared == 1
                    if obj.useRandomFirstSeed
                        obj.noiseSeed = RandStream.shuffleSeed;
                    else
                        obj.noiseSeed = 0;
                    end
                else
                    if ~obj.repeatCycle
                        obj.noiseSeed = RandStream.shuffleSeed;
                    end
                end
                obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
                epoch.addParameter('noiseSeed', obj.noiseSeed);

            else
                if obj.repeatCycle
                    stimNum = obj.firstStimulusNum;
                else
                    stimNum = obj.randOrder(obj.getCycleNumber());
                end
                [imgNum, runNum] = obj.getImgAndRunNums(stimNum);

                if stimulusGroup == 2  % image-derived brownian FEM
                    % Pull appropriate stimuli. Scale such that brightest point in original image is 1.0 on the monitor
                    obj.currSequence = obj.stimulusDataset(imgNum).brownian.sequence(runNum).center / ...
                         obj.stimulusDataset(imgNum).img.max;
                elseif stimulusGroup == 3  % image-derived synthetic saccades
                    obj.currSequence = obj.stimulusDataset(imgNum).synthSaccades.sequence(runNum).center / ...
                         obj.stimulusDataset(imgNum).img.max;
                end

                % Set background intensity to the mean over the original image
                obj.backgroundIntensity = obj.stimulusDataset(imgNum).img.mean / ...
                    obj.stimulusDataset(imgNum).img.max;

                epoch.addParameter('stimulusNum', stimNum)
                epoch.addParameter('sequenceVector', obj.currSequence);
                epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            end

        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            % Convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            % Create presentation of specified duration
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create noise stimulus.            
            rect = stage.builtin.stimuli.Rectangle();
            rect.size = canvasSize;
            rect.position = canvasSize/2;
            p.addStimulus(rect);
            preFrames = round(60 * (obj.preTime/1e3));
            
            stimulusGroup = obj.getStimulusGroup();
            if stimulusGroup == 1
                controller = stage.builtin.controllers.PropertyController(rect, 'color',...
                    @(state)getNoiseIntensity(obj, state.frame - preFrames));
            else
                timeVector = (0:(length(obj.currSequence)-1)) / 60;  % sec  % TODO optional compatibility with doves which is 200 Hz
                controller = stage.builtin.controllers.PropertyController(rect, 'color',...
                    @(state)getSeqIntensity(obj, state.time - obj.preTime/1e3, timeVector));
            end
            p.addController(controller);  % add the controller

            function next = getNoiseIntensity(obj, frame)
                persistent intensity;  % store intensity for potential reuse next frame
                if frame < 0  % pre frames. frame 0 starts stimPts
                    intensity = obj.noiseMean;
                else          % in stim frames
                    if mod(frame, obj.frameDwell) == 0  % noise update
                        intensity = obj.noiseMean + obj.noiseStdv * obj.noiseMean * obj.noiseStream.randn;
                    end
                end
                next = intensity;  
            end

            function next = getSeqIntensity(obj, time, timeVector)
                if time < 0  || time > timeVector(end)  % pre time or sequence finished but still in stimTime
                    next = obj.backgroundIntensity;
                else
                    next = interp1(timeVector, obj.currSequence, time);
                end
            end

            if (obj.apertureDiameter > 0)  % create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024);  % circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture);  % add aperture
            end
            
            % Hide during pre & post
            rectVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(rectVisible);
        end

        function stimulusGroup = getStimulusGroup(obj)
            stimulusGroup = int8(mod(obj.numEpochsPrepared - 1, 3) + 1);
        end

        function cycleNum = getCycleNumber(obj)
            cycleNum = int8(floor((obj.numEpochsPrepared - 1) / 3) + 1);
        end

        function [imgNum, runNum] = getImgAndRunNums(obj, stimNum)
            imgNum = floor((stimNum - 1) / obj.entriesPerImage) + 1;
            runNum = rem(stimNum - 1, obj.entriesPerImage) + 1;
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < 3 * obj.numberOfCycles;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < 3 * obj.numberOfCycles;
        end

    end
    
end
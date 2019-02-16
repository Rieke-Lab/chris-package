classdef CSNaturalImageLuminance < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 500 % ms
        stimTime = 8000 % ms
        tailTime = 500 % ms
        fixationDuration = 200 % ms
        imageIndex = 1 % 1-20
        centerDiameter = 200 % um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 600 % um
        
        trajectorySeed = 1 % for center and surround
        useRandomSeed = false % false = repeated trajectory
        shuffleCenterSurround = false % false = maintain spatial correlations. True = mix s

        onlineAnalysis = 'none'
        numberOfAverages = uint16(15) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        centerStream
        surroundStream
        
        %image data, initialized at beginning of run:
        ScaledCenterIntensity
        ScaledSurroundIntensity

        %saved out to each epoch:
        currentStimSet
        currentStimulus
        centerSeed
        surroundSeed
        CenterLocationIndex
        SurroundLocationIndex
        CenterIntensity
        SurroundIntensity
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
                colors = edu.washington.riekelab.turner.utils.pmkmp(3,'CubicYF');
                obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentStimulus'},...
                'sweepColor',colors);
            end

            %load data and get luminance trajectories
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            obj.currentStimSet = 'VanHaterenCSLuminances_20170127.mat';
            load([resourcesDir, obj.currentStimSet]);
            
            obj.ScaledCenterIntensity = luminanceData(obj.imageIndex).CenterIntensity ./ luminanceData(obj.imageIndex).ImageMax;
            obj.ScaledSurroundIntensity = luminanceData(obj.imageIndex).SurroundIntensity ./ luminanceData(obj.imageIndex).ImageMax;
            obj.backgroundIntensity = luminanceData(obj.imageIndex).ImageMean / luminanceData(obj.imageIndex).ImageMax;
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
                % Determine seed values. Center and surround have same seed
                if obj.useRandomSeed
                    obj.centerSeed = RandStream.shuffleSeed;
                    obj.surroundSeed = obj.centerSeed;
                else %repeated-seed trials
                    obj.centerSeed = obj.trajectorySeed;
                    obj.surroundSeed = obj.trajectorySeed;
                end
                obj.centerStream = RandStream('mt19937ar', 'Seed', obj.centerSeed);
                obj.surroundStream = RandStream('mt19937ar', 'Seed', obj.surroundSeed);

                %pre-generate arrays for c and s
                noFixations = ceil(obj.stimTime / obj.fixationDuration);
                tempC = obj.centerStream.randperm(length(obj.ScaledCenterIntensity));
                obj.CenterLocationIndex = tempC(1:noFixations);
                obj.CenterIntensity = obj.ScaledCenterIntensity(obj.CenterLocationIndex);

                tempS = obj.surroundStream.randperm(length(obj.ScaledCenterIntensity));
                obj.SurroundLocationIndex = tempS(1:noFixations);
                if (obj.shuffleCenterSurround) %mix up surround intensities
                    tempMixInds = obj.surroundStream.randperm(length(obj.SurroundLocationIndex));
                    obj.SurroundLocationIndex = obj.SurroundLocationIndex(tempMixInds);
                end
                obj.SurroundIntensity = obj.ScaledSurroundIntensity(obj.SurroundLocationIndex);

                
            elseif index == 1
                obj.currentStimulus = 'Surround';
            elseif index == 2
                obj.currentStimulus = 'Center-Surround';
            end
            
            epoch.addParameter('currentStimSet', obj.currentStimSet);
            epoch.addParameter('currentStimulus', obj.currentStimulus);
            epoch.addParameter('centerSeed', obj.centerSeed);
            epoch.addParameter('surroundSeed', obj.surroundSeed);
            epoch.addParameter('CenterLocationIndex', obj.CenterLocationIndex);
            epoch.addParameter('SurroundLocationIndex', obj.SurroundLocationIndex);
            epoch.addParameter('CenterIntensity', obj.CenterIntensity);
            epoch.addParameter('SurroundIntensity', obj.SurroundIntensity);
            epoch.addParameter('backgroundIntensity',obj.backgroundIntensity);
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
                    @(state)getNextIntensity(obj, state.time - obj.preTime/1e3, obj.SurroundIntensity));
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
                    @(state)getNextIntensity(obj, state.time - obj.preTime/1e3, obj.CenterIntensity));
                p.addController(centerSpotIntensity);
                % hide during pre & post
                centerSpotVisible = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(centerSpotVisible);
            end
            
            function i = getNextIntensity(obj, time, trajectoryToUse)
                saccadeTimes = 0:(obj.fixationDuration/1e3):((obj.stimTime-obj.fixationDuration)/1e3);
                if time < 0 %pre-time, start at mean
                    i = obj.backgroundIntensity;
                elseif time > obj.stimTime/1e3 %out of eye trajectory, back to mean
                    i = obj.backgroundIntensity;
                else %within eye trajectory and stim time
                    tempInd = find(time >= saccadeTimes);
                    tempInd = tempInd(end);
                    i = trajectoryToUse(tempInd);
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
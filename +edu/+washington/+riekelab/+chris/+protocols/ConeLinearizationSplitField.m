classdef ConeLinearizationSplitField < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        stimulusDataPath = 'enter path here'; % string of path to
        isomerizationsAtMonitorValue1 = 0;
        inputStimulusFrameRate = 60;
        preFrames = 30
        postFrames = 30
        rotation = 0; % degrees
        maskDiameter = 0; % um
        onlineAnalysis = 'none';
        averagesPerStimulus = uint16(20);
        amp
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        stimuli
        currentStimuli
        stimulusDurationSeconds
        backgroundIsomerizations
    end
    
    properties (Hidden, Transient)
        analysisFigure
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function constructStimuli(obj)
            obj.stimuli = struct;
            obj.stimuli.names = {'positive corrected', ...
                'negative corrected', ...
                'both corrected', ...
                'positive uncorrected', ...
                'negative uncorrected', ...
                'both uncorrected'};
            
            stimulusData = load(obj.stimulusDataPath);
            obj.backgroundIsomerizations = stimulusData.positiveCorrected(1);
            meanVector = obj.backgroundIsomerizations ...
                * ones(1, numel(stimulusData.positiveCorrected));
            
            obj.stimuli.lookup = containers.Map(obj.stimuli.names, ...
                {{stimulusData.positiveCorrected, meanVector}, ...
                {meanVector, stimulusData.negativeCorrected}, ...
                {stimulusData.positiveCorrected, stimulusData.negativeCorrected}, ...
                {stimulusData.positiveUncorrected, meanVector}, ...
                {meanVector, stimulusData.negativeUncorrected}, ...
                {stimulusData.positiveUncorrected, stimulusData.negativeUncorrected}});
            
            obj.stimulusDurationSeconds = (obj.preFrames + numel(stimulusData.positiveCorrected) + obj.postFrames) ...
                / obj.inputStimulusFrameRate;
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.constructStimuli();
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'stimulus type'},...
                'sweepColor',[0 0 0]);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
        end
        
        function intensityController = createIntensityController(obj, rectangle, stimulus)
            paddedStimulus = [obj.backgroundIsomerizations * ones(1, obj.preFrames) ...
                stimulus ...
                obj.backgroundIsomerizations * ones(1, obj.postFrames)];
            
            intensityController = stage.builtin.controllers.PropertyController( ...
                rectangle, ...
                'color', ...
                @(state) obj.isomerizationsToColor(paddedStimulus(state.frame + 1)));
        end
        
        function color = isomerizationsToColor(obj, isomerizations)
            color = (isomerizations / obj.isomerizationsAtMonitorValue1);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            leftStimulus = obj.getLeftStimulus();
            rightStimulus = obj.getRightStimulus();

            p = stage.core.Presentation( ...
                obj.stimulusDurationSeconds); %create presentation of specified duration
            p.setBackgroundColor(obj.isomerizationsToColor(obj.backgroundIsomerizations)); % Set background intensity
            
            leftRectangle = stage.builtin.stimuli.Rectangle();
            leftRectangle.size = canvasSize .* [0.5 1];
            leftRectangle.position = canvasSize .* [0.25 0.5];
            leftRectangle.color = obj.isomerizationsToColor(obj.backgroundIsomerizations);
            p.addStimulus(leftRectangle);
            p.addController(obj.createIntensityController(leftRectangle, leftStimulus));
            
            rightRectangle = stage.builtin.stimuli.Rectangle();
            rightRectangle.size = canvasSize .* [0.5 1];
            rightRectangle.position = canvasSize .* [0.75 0.5];
            rightRectangle.color = obj.isomerizationsToColor(obj.backgroundIsomerizations);
            p.addStimulus(rightRectangle);
            p.addController(obj.createIntensityController(rightRectangle, rightStimulus));
            
            if (obj.maskDiameter > 0) %% Create aperture
                maskDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.maskDiameter);
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.isomerizationsToColor(mean([leftStimulus(1), rightStimulus(1)]));
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(maskDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            index = mod(obj.numEpochsCompleted, numel(obj.stimuli.names)) + 1;
            
            obj.currentStimuli = obj.stimuli.lookup(obj.stimuli.names{index});
            
            ampDevice = obj.rig.getDevice(obj.amp);
            duration = obj.stimulusDurationSeconds;
            epoch.addDirectCurrentStimulus(ampDevice, ampDevice.background, duration, obj.sampleRate);
            epoch.addResponse(ampDevice);
            
            epoch.addParameter('stimulus type', obj.stimuli.names{index});
            epoch.addParameter('left stimulus', obj.getLeftStimulus());
            epoch.addParameter('right stimulus', obj.getRightStimulus());
        end
        
        function stimulus = getLeftStimulus(obj)
            stimulus = obj.currentStimuli{1};
        end
        
        function stimulus = getRightStimulus(obj)
            stimulus = obj.currentStimuli{2};
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.averagesPerStimulus * numel(obj.stimuli.names);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.averagesPerStimulus * numel(obj.stimuli.names);
        end
    end
end

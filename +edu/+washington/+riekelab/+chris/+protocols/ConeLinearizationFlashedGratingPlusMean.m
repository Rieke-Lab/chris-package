classdef ConeLinearizationFlashedGratingPlusMean < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        stimulusDataPath = 'flash_plus_mean'; % string of path to
        isomerizationsAtMonitorValue1 = 20000;
        inputStimulusFrameRate = 60;
        apertureDiameter = 200; % um
        backgroundDiameter = 800;
        onlineAnalysis = 'none';
        averagesPerStimulus = uint16(4);
        amp
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        stimuli
        currentStimuli
        stimulusDurationSeconds
        backgroundIsomerizations
        ResourceFolderPath = 'C:\Users\Public\Documents\baudin-package\+edu\+washington\+riekelab\+baudin\+resources\'
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

            obj.stimuli.names = {'stepCorrected', ...
                'stepUncorrected', ...
                'spotCorrectedHighAmp', ...
                'spotUncorrectedHighAmp' ...
                'gratingCorrectedHighAmp' ...
                'gratingCorrectedHighAmp' ...
                'gratingUncorrectedLowAmp'
                'gratingUncorrectedLowAmp'};

            stimulusData = load(strcat(obj.ResourceFolderPath, obj.stimulusDataPath));
            
            obj.backgroundIsomerizations = stimulusData.stepCorrected(1);
  
            obj.stimuli.lookup = containers.Map(obj.stimuli.names, ...
                {{stimulusData.stepCorrected, stimulusData.stepCorrected, stimulusData.stepCorrected}, ...
                {stimulusData.stepUncorrected, stimulusData.stepUncorrected, stimulusData.stepUncorrected}, ...
                {stimulusData.stepCorrected, stimulusData.spotCorrectedHighAmp, stimulusData.spotCorrectedHighAmp}, ...
                {stimulusData.stepUncorrected, stimulusData.spotUncorrectedHighAmp, stimulusData.spotUncorrectedHighAmp}, ...
                {stimulusData.stepCorrected, stimulusData.spotCorrectedHighAmp, stimulusData.spotNegCorrectedHighAmp}, ...
                {stimulusData.stepUncorrected, stimulusData.spotUnCorrectedHighAmp, stimulusData.spotNegUnCorrectedHighAmp}, ...
                {stimulusData.stepCorrected, stimulusData.spotCorrectedHighAmp, stimulusData.spotNegCorrectedHighAmp}, ...
                {stimulusData.stepUncorrected, stimulusData.spotUnCorrectedLowAmp, stimulusData.spotNegUnCorrectedLowAmp}});

            obj.stimulusDurationSeconds = (numel(stimulusData.stepCorrected)) ...
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
               
        function color = isomerizationsToColor(obj, isomerizations)
            color = (isomerizations / obj.isomerizationsAtMonitorValue1);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            leftStimulus = obj.getLeftStimulus();
            rightStimulus = obj.getRightStimulus();
            backgroundStimulus = obj.getBackgroundStimulus();
            % convert them to per frame 
            
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            p = stage.core.Presentation(obj.stimulusDurationSeconds); %create presentation of specified duration
            p.setBackgroundColor(obj.isomerizationsToColor(obj.backgroundIsomerizations)); % Set background intensity
            
            % step background spot for specified time 
            spotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.backgroundDiameter);            
            background = stage.builtin.stimuli.Ellipse();
            background.radiusX = spotDiameterPix/2;
            background.radiusY = spotDiameterPix/2;
            background.position = canvasSize/2;
            p.addStimulus(background);            
            backgroundMean = stage.builtin.controllers.PropertyController(background, 'color',...
                @(state)getRegionMean(obj, backgroundStimulus, state.frame));
            p.addController(backgroundMean); %add the controller                       

            leftRectangle = stage.builtin.stimuli.Rectangle();
            leftRectangle.size = apertureDiameterPix .* [0.5 1];
            leftRectangle.position = canvasSize .* [0.5 0.5] + [apertureDiameterPix/4 0];
            leftRectangle.color = obj.isomerizationsToColor(leftStimulus(1));
            p.addStimulus(leftRectangle);
            leftMean = stage.builtin.controllers.PropertyController(leftRectangle, 'color',...
                @(state)getRegionMean(obj, leftStimulus, state.frame));
            p.addController(leftMean);
            
            rightRectangle = stage.builtin.stimuli.Rectangle();
            rightRectangle.size = apertureDiameterPix .* [0.5 1];
            rightRectangle.position = canvasSize .* [0.5 0.5] - [apertureDiameterPix/4 0];
            rightRectangle.color = obj.isomerizationsToColor(rightStimulus(1));
            p.addStimulus(rightRectangle);
            rightMean = stage.builtin.controllers.PropertyController(rightRectangle, 'color',...
                @(state)getRegionMean(obj, rightStimulus, state.frame));
            p.addController(rightMean);
 
            aperture = stage.builtin.stimuli.Rectangle();
            aperture.position = canvasSize/2;
            aperture.size = [apertureDiameterPix, apertureDiameterPix];
            mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
            aperture.setMask(mask);
            p.addStimulus(aperture); %add aperture
            apertureMean = stage.builtin.controllers.PropertyController(aperture, 'color',...
                @(state)getRegionMean(obj, backgroundStimulus, state.frame));
            p.addController(apertureMean); %add the controller                       
            
            % mean of background spot
            function m = getRegionMean(obj, meanValues, currentFrame)
                 m = obj.isomerizationsToColor(meanValues(currentFrame+1));
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
         end
        
        function stimulus = getBackgroundStimulus(obj)
            stimulus = obj.currentStimuli{1};
        end
        
        function stimulus = getLeftStimulus(obj)
            stimulus = obj.currentStimuli{2};
        end
        
        function stimulus = getRightStimulus(obj)
            stimulus = obj.currentStimuli{3};
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.averagesPerStimulus * numel(obj.stimuli.names);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.averagesPerStimulus * numel(obj.stimuli.names);
        end
    end
end
classdef CenterF2PlusSurround < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 100 % ms
        stimTime = 1000 % ms
        tailTime = 100 % ms
        flashDelay = 500 %ms after preTime, surround flash
        flashDuration = 100 % ms, surround flash duration
        
        temporalFrequency = 8 % Hz
        spotDiameter = 200; % um
        centerContrast = 0.5 %relative to mean
        
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 600 % um
        surroundContrast = 0.75 %relative to mean
        
        rotation = 0;  % deg
        backgroundIntensity = 0.5 % (0-1)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(10) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        currentStimulus
    end
       
    properties (Hidden, Transient)
        analysisFigure
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.ModF2Figure',...
                    obj.rig.getDevice(obj.amp),...
                    'recordingType',obj.onlineAnalysis,...
                    'preTime',obj.preTime,'stimTime',obj.stimTime,...
                    'flashDelay',obj.flashDelay,'flashDuration',obj.flashDuration,...
                    'temporalFrequency',obj.temporalFrequency);
            end
        end
 
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            stimIndex = mod(obj.numEpochsCompleted,2);
            if stimIndex == 0
                obj.currentStimulus = 'FullField';
            elseif stimIndex == 1
                obj.currentStimulus = 'SplitField';
            end
            epoch.addParameter('currentStimulus', obj.currentStimulus);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            spotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.spotDiameter);
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create grating stimulus.            
            grate = stage.builtin.stimuli.Grating('square'); %square wave grating
            grate.orientation = obj.rotation;
            grate.size = [spotDiameterPix, spotDiameterPix];
            grate.position = canvasSize/2;
            grate.spatialFreq = 1/(2*spotDiameterPix);
            grate.color = 2*obj.backgroundIntensity; %amplitude of square wave
            grate.contrast = obj.centerContrast; %multiplier on square wave
            if strcmp(obj.currentStimulus,'SplitField')
                grate.phase = 90;
            elseif strcmp(obj.currentStimulus,'FullField')
                grate.phase = 0;
            end
            p.addStimulus(grate); %add grating to the presentation
            
            %make it contrast-reversing
            if (obj.temporalFrequency > 0) 
                grateContrast = stage.builtin.controllers.PropertyController(grate, 'contrast',...
                    @(state)getGrateContrast(obj, state.time - obj.preTime/1e3));
                p.addController(grateContrast); %add the controller
            end
            function c = getGrateContrast(obj, time)
                c = obj.centerContrast.*sin(2 * pi * obj.temporalFrequency * time);
            end
            
            % Create aperture
            aperture = stage.builtin.stimuli.Rectangle();
            aperture.position = canvasSize/2;
            aperture.color = obj.backgroundIntensity;
            aperture.size = [spotDiameterPix, spotDiameterPix];
            mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
            aperture.setMask(mask);
            p.addStimulus(aperture); %add aperture
            
            %hide during pre & post
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);
            
            % Make annulus in surround
            rect = stage.builtin.stimuli.Rectangle();
            rect.position = canvasSize/2;
            rect.color = obj.surroundContrast * obj.backgroundIntensity + obj.backgroundIntensity;
            rect.size = [max(canvasSize) max(canvasSize)];

            distanceMatrix = createDistanceMatrix(1024);
            annulus = uint8((distanceMatrix < annulusOuterDiameterPix/max(canvasSize) & ...
                distanceMatrix > annulusInnerDiameterPix/max(canvasSize)) * 255);
            mask = stage.core.Mask(annulus);

            rect.setMask(mask);
            p.addStimulus(rect);
            %show during flash period
            rectVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= (obj.preTime + obj.flashDelay) * 1e-3 && state.time <...
                (obj.preTime + obj.flashDelay + obj.flashDuration) * 1e-3);
            p.addController(rectVisible);
            
            function m = createDistanceMatrix(size)
                step = 2 / (size - 1);
                [xx, yy] = meshgrid(-1:step:1, -1:step:1);
                m = sqrt(xx.^2 + yy.^2);
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
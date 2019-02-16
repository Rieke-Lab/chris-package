classdef ContrastF1F2 < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        preTime = 250 % ms
        stimTime = 4000 % ms
        tailTime = 250 % ms
        temporalFrequency = 4 % Hz
        apertureDiameter = 300 % um
        maskDiameter = 0 % um
        contrast = [0.125, 0.25, 0.5, 0.75, 0.9] % relative to mean (0-1)
        gratingPhase = 'Alternate'
        rotation = 0 % deg
        backgroundIntensity = 0.5 % (0-1)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(20) % number of epochs to queue
        amp
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        gratingPhaseType = symphonyui.core.PropertyType('char', 'row', {'Alternate', 'Full', 'Split'})

        contrastSequence
        phaseSequence
        currentContrast
        currentPhase
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
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentContrast','currentPhase'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            % Create contrast and phase sequences         
            if strcmp(obj.gratingPhase,'Alternate')
                obj.phaseSequence = repmat([0 90],1,length(obj.contrast));
                obj.contrastSequence = kron(obj.contrast,ones(1,2));
            else %either split or full field only
                obj.contrastSequence = obj.contrast;
                if strcmp(obj.gratingPhase,'Full')
                    obj.phaseSequence = zeros(size(obj.contrastSequence));
                elseif strcmp(obj.gratingPhase,'Split')
                    obj.phaseSequence = 90 .* ones(size(obj.contrastSequence));
                end
            end
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            maskDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.maskDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create grating stimulus.            
            grate = stage.builtin.stimuli.Grating('square'); %square wave grating
            grate.orientation = obj.rotation;
            grate.size = [apertureDiameterPix, apertureDiameterPix];
            grate.position = canvasSize/2;
            grate.spatialFreq = 1/(2*apertureDiameterPix);
            grate.color = 2*obj.backgroundIntensity; %amplitude of square wave
            grate.contrast = obj.currentContrast;
            grate.phase = obj.currentPhase;
            p.addStimulus(grate); %add grating to the presentation
            
            %make it contrast-reversing
            if (obj.temporalFrequency > 0) 
                grateContrast = stage.builtin.controllers.PropertyController(grate, 'contrast',...
                    @(state)getGrateContrast(obj, state.time - obj.preTime/1e3));
                p.addController(grateContrast); %add the controller
            end
            function c = getGrateContrast(obj, time)
                c = obj.currentContrast.*sin(2 * pi * obj.temporalFrequency * time);
            end
            
            if  (obj.apertureDiameter > 0) % Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [apertureDiameterPix, apertureDiameterPix];
                mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
            if (obj.maskDiameter > 0) % Create mask
                mask = stage.builtin.stimuli.Ellipse();
                mask.position = canvasSize/2;
                mask.color = obj.backgroundIntensity;
                mask.radiusX = maskDiameterPix/2;
                mask.radiusY = maskDiameterPix/2;
                p.addStimulus(mask); %add mask
            end
            
            % hide during pre & post
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);

        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            index = mod(obj.numEpochsCompleted, length(obj.contrastSequence)) + 1;
            %get current phase & contrast, save them out...
            obj.currentContrast = obj.contrastSequence(index);
            obj.currentPhase = obj.phaseSequence(index);
            
            epoch.addParameter('currentContrast', obj.currentContrast);
            epoch.addParameter('currentPhase', obj.currentPhase);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
    
end
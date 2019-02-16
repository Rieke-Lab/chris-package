classdef TextureCSAdditivity < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        centerSigmas = [2 4 8 12 16 20]; %um
        surroundSigmas = [2 4 8 12 16 20]; %um
        contrast = 0.5; % Fraction of background intensity +/-

        centerDiameter = 200 % 
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 600 % um
        backgroundIntensity = 0.5       % Background light intensity (0-0.5)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(108) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        
        centerTexture
        surroundTexture
        sigmaPairsList
        
        %saved out to each epoch...
        currentCenterSeed
        currentCenterSigma
        currentSurroundSeed
        currentSurroundSigma
        currentStimulus
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
                'groupBy',{'currentStimulus'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.CSSpatialTuningFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime,...
                'centerSigmas',obj.centerSigmas,'surroundSigmas',obj.surroundSigmas);
            end
            
            %get a list of all center, surround sigma pairs and randomize
            %its order
            [cc, ss] = meshgrid(obj.centerSigmas, obj.surroundSigmas);
            pairs = [cc(:) ss(:)];
            obj.sigmaPairsList = pairs(randperm(size(pairs,1)),:);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            % get stim type:
            stimInd = mod(obj.numEpochsCompleted,3);
            if stimInd == 0
                obj.currentStimulus = 'Center';
                %start of a new triplet. Get new textures...
                % sigmas:
                sigmaInd = mod(floor(obj.numEpochsCompleted/3), size(obj.sigmaPairsList,1)) + 1;
                obj.currentCenterSigma = obj.sigmaPairsList(sigmaInd,1);
                obj.currentSurroundSigma = obj.sigmaPairsList(sigmaInd,2);

                %convert to canvas pixels
                currentCenterSigmaPix = obj.rig.getDevice('Stage').um2pix(obj.currentCenterSigma);
                currentSurroundSigmaPix = obj.rig.getDevice('Stage').um2pix(obj.currentSurroundSigma);
                
                % seeds:
                obj.currentCenterSeed = RandStream.shuffleSeed;
                obj.currentSurroundSeed = RandStream.shuffleSeed;

                centerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.centerDiameter);
                obj.centerTexture = edu.washington.riekelab.turner.utils.makeTextureMatrix(centerDiameterPix,...
                    currentCenterSigmaPix, obj.currentCenterSeed, obj.backgroundIntensity, obj.contrast);
                obj.centerTexture = uint8(obj.centerTexture .* 255);
                
                annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
                obj.surroundTexture = edu.washington.riekelab.turner.utils.makeTextureMatrix(annulusOuterDiameterPix,...
                    currentSurroundSigmaPix, obj.currentSurroundSeed, obj.backgroundIntensity, obj.contrast);
                obj.surroundTexture = uint8(obj.surroundTexture .* 255);

            elseif stimInd == 1
                obj.currentStimulus = 'Surround';
            elseif stimInd == 2
                obj.currentStimulus = 'Center-Surround';
            end

            epoch.addParameter('currentCenterSigma', obj.currentCenterSigma);
            epoch.addParameter('currentSurroundSigma', obj.currentSurroundSigma);
            epoch.addParameter('currentCenterSeed', obj.currentCenterSeed);
            epoch.addParameter('currentSurroundSeed', obj.currentSurroundSeed);
            epoch.addParameter('currentStimulus', obj.currentStimulus);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            centerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.centerDiameter);
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);

            if strcmp(obj.currentStimulus,'Center')
                makeCenterTexture;
            elseif strcmp(obj.currentStimulus,'Surround')
                makeSurroundTexture

            elseif strcmp(obj.currentStimulus,'Center-Surround')
                makeCenterTexture
                makeSurroundTexture
            end
            
            function makeCenterTexture
                %make center texture:
                cTexture = stage.builtin.stimuli.Image(obj.centerTexture);
                cTexture.size = [centerDiameterPix, centerDiameterPix];
                cTexture.position = canvasSize/2;
                p.addStimulus(cTexture);
                sceneVisible = stage.builtin.controllers.PropertyController(cTexture, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(sceneVisible);
                %add an aperture to it:
                distanceMatrix = createDistanceMatrix(1024);
                aperture = uint8((distanceMatrix < 1) * 255);
                apertureMask = stage.core.Mask(aperture);
                cTexture.setMask(apertureMask);
            end
            
            function makeSurroundTexture
                %make surround texture:
                sTexture = stage.builtin.stimuli.Image(obj.surroundTexture);
                sTexture.size = [annulusOuterDiameterPix, annulusOuterDiameterPix];
                sTexture.position = canvasSize/2;
                p.addStimulus(sTexture);
                sceneVisible = stage.builtin.controllers.PropertyController(sTexture, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(sceneVisible);
                %add an annulus aperture to it:
                distanceMatrix = createDistanceMatrix(1024);
                annulus = uint8((distanceMatrix < 1 & ...
                    distanceMatrix > annulusInnerDiameterPix/annulusOuterDiameterPix) * 255);
                annulusMask = stage.core.Mask(annulus);
                sTexture.setMask(annulusMask);
            end
            
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
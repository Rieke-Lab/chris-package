classdef FlashedSkewPizza< edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        preTime = 200 % ms
        stimTime = 400 % ms
        tailTime = 400 % ms
        
        apertureDiameter = 200 % um
        backgroundIntensity = 0.3; %0-1
        meanIntensity=0.5;
        contrast=0.3
        numOfSlices=8;
        numOfRankedSkewness=10;
        rotationJitter=[0 90 180 270 360] % degrees
        onlineAnalysis = 'extracellular'
        amp % Output amplifier
        numberOfAverages = uint16(3) % number of epochs to queue
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        %saved out to each epoch...
        currentIntensitySequence
        skewList
        currentSkewness
        intensitySequences
        currentRotation
        currentImageMatrix
        canvasSize
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            % pre-generate the imageMatrix 

            [obj.intensitySequences, obj.skewList] = edu.washington.riekelab.chris.utils.generateSkewedIntensitySeq(obj.meanIntensity, obj.contrast, obj.numOfSlices,obj.numOfRankedSkewness);
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentSkewness'});
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();

        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            rotInd=mod(obj.numEpochsCompleted, numel(obj.rotationJitter))+1;
            obj.currentRotation=obj.rotationJitter(rotInd);
            % set the current intensity sequence for the pizzas
            skewInd=(obj.numEpochsPrepared-rotInd)/numel(obj.rotationJitter)+1;
            skewInd=mod(skewInd,obj.numOfRankedSkewness); if skewInd==0 skewInd=obj.numOfRankedSkewness; end
            obj.currentIntensitySequence=obj.intensitySequences(:,skewInd);
            obj.currentImageMatrix =edu.washington.riekelab.chris.utils.makeSplitPizzas(max(obj.canvasSize),obj.numOfSlices, obj.currentRotation,obj.currentIntensitySequence);
            obj.currentImageMatrix = obj.currentImageMatrix.*255; %rescale s.t. brightest point is maximum monitor level
            obj.currentImageMatrix = uint8(obj.currentImageMatrix);

            epoch.addParameter('currentRotation', obj.currentRotation);
            epoch.addParameter('currentIntensitySequence', obj.currentIntensitySequence);
            epoch.addParameter('currentSkewness', obj.skewList(skewInd));
            fprintf('%s %d %s %d %s %d %s %f %s %f %s %f \n','epoch:', obj.numEpochsPrepared, ' skew#:', skewInd, ' rot #', rotInd, ' mean::', mean( obj.currentIntensitySequence), ...
                ' var::', var( obj.currentIntensitySequence), ' skew::', skewness( obj.currentIntensitySequence));
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);


            scene = stage.builtin.stimuli.Image(obj.currentImageMatrix);
            scene.size = obj.canvasSize; %scale up to canvas size
            scene.position = obj.canvasSize/2;
            % Use linear interpolation when scaling the image.
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);

            if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = obj.canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(obj.canvasSize) max(obj.canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(obj.canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end

        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*obj.numOfRankedSkewness*numel(obj.rotationJitter);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*obj.numOfRankedSkewness*numel(obj.rotationJitter);
        end

    end
    
end
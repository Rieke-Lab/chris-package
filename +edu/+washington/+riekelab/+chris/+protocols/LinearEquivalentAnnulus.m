classdef LinearEquivalentAnnulus < edu.washington.riekelab.turner.protocols.NaturalImageFlashProtocol

    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        
        annulusInnerDiameter = 250 % um
        annulusOuterDiameter = 400 % um
        linearIntegrationFunction = 'gaussian'
        rfSigmaSurround = 180 % (um) Enter from fit RF
        centerSpotDiameter = 150; % um
        centerSpotContrast = 0.5;
        linearizeCones = false;
        WeberConstant = 2000;
        maxIntensity = 25000;
        numberOfAverages = uint16(90) % number of epochs to queue
    end
    
    properties (Hidden)
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian','uniform'})

        allEquivalentIntensityValues
        allEquivalentIntensityValuesConeLin
        
        %saved out to each epoch...
        imagePatchIndex
        currentPatchLocation
        equivalentIntensity
        equivalentIntensityConeLin
        stimulusTag
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.turner.protocols.NaturalImageFlashProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'stimulusTag'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.ImageVsIntensityConeLinFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
            
            obj.allEquivalentIntensityValuesConeLin = ...
                edu.washington.riekelab.turner.protocols.NaturalImageFlashProtocol.getEquivalentIntensityValuesConeLin(...
                obj, obj.annulusInnerDiameter, obj.annulusOuterDiameter, obj.rfSigmaSurround);
            obj.allEquivalentIntensityValues = ...
                edu.washington.riekelab.turner.protocols.NaturalImageFlashProtocol.getEquivalentIntensityValues(...
                obj, obj.annulusInnerDiameter, obj.annulusOuterDiameter, obj.rfSigmaSurround);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.turner.protocols.NaturalImageFlashProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            %pull patch location and equivalent contrast:
            if (obj.linearizeCones == 0)
                obj.imagePatchIndex = floor(mod(obj.numEpochsCompleted/2,obj.noPatches) + 1);
                evenInd = mod(obj.numEpochsCompleted,2);
                if evenInd == 1 %even, show uniform linear equivalent intensity
                    obj.stimulusTag = 'intensity';
                elseif evenInd == 0 %odd, show image
                    obj.stimulusTag = 'image';
                end
            else
                obj.imagePatchIndex = floor(mod(obj.numEpochsCompleted/3,obj.noPatches) + 1);
                stimInd = mod(obj.numEpochsCompleted,3);
                if stimInd == 1 %even, show uniform linear equivalent intensity
                    obj.stimulusTag = 'intensity';
                elseif stimInd == 0 %odd, show image
                    obj.stimulusTag = 'image';
                else
                    obj.stimulusTag = 'lin cone intensity';
                end
            end
           
            obj.currentPatchLocation(1) = obj.patchLocations(1,obj.imagePatchIndex); %in VH pixels
            obj.currentPatchLocation(2) = obj.patchLocations(2,obj.imagePatchIndex);
            obj.equivalentIntensity = obj.allEquivalentIntensityValues(obj.imagePatchIndex);
            obj.equivalentIntensityConeLin = obj.allEquivalentIntensityValuesConeLin(obj.imagePatchIndex);

            obj.imagePatchMatrix = ...
                edu.washington.riekelab.turner.protocols.NaturalImageFlashProtocol.getImagePatchMatrix(...
                obj, obj.currentPatchLocation);

            epoch.addParameter('imagePatchIndex', obj.imagePatchIndex);
            epoch.addParameter('currentPatchLocation', obj.currentPatchLocation);
            epoch.addParameter('equivalentIntensity', obj.equivalentIntensity);
            epoch.addParameter('equivalentIntensityConeLin', obj.equivalentIntensityConeLin);
            epoch.addParameter('stimulusTag', obj.stimulusTag);
 %           fprintf(1, '%s %d %d %d\n', obj.stimulusTag, obj.imagePatchIndex, obj.equivalentIntensity, obj.equivalentIntensityConeLin);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
            centerSpotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.centerSpotDiameter);

            if strcmp(obj.stimulusTag,'image')
                scene = stage.builtin.stimuli.Image(obj.imagePatchMatrix);
                scene.size = canvasSize; %scale up to canvas size
                scene.position = canvasSize/2;
                % Use linear interpolation when scaling the image.
                scene.setMinFunction(GL.LINEAR);
                scene.setMagFunction(GL.LINEAR);
                p.addStimulus(scene);
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(sceneVisible);
            elseif strcmp(obj.stimulusTag,'intensity')
                scene = stage.builtin.stimuli.Rectangle();
                scene.size = canvasSize;
                scene.color = obj.equivalentIntensity;
                scene.position = canvasSize/2;
                p.addStimulus(scene);
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(sceneVisible);
            else
                scene = stage.builtin.stimuli.Rectangle();
                scene.size = canvasSize;
                scene.color = obj.equivalentIntensityConeLin;
                scene.position = canvasSize/2;
                p.addStimulus(scene);
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(sceneVisible);
            end
                 
            if (obj.annulusOuterDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(annulusOuterDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
            if (obj.annulusInnerDiameter > 0) % Create mask
                mask = stage.builtin.stimuli.Ellipse();
                mask.position = canvasSize/2;
                mask.color = obj.backgroundIntensity;
                mask.radiusX = annulusInnerDiameterPix/2;
                mask.radiusY = annulusInnerDiameterPix/2;
                p.addStimulus(mask); %add mask
            end
            
            if (obj.centerSpotDiameter > 0) %create flashing spot in the center
                spot = stage.builtin.stimuli.Ellipse();
                spot.color = obj.backgroundIntensity + ...
                    obj.backgroundIntensity * obj.centerSpotContrast;
                spot.radiusX = centerSpotDiameterPix/2;
                spot.radiusY = centerSpotDiameterPix/2;
                spot.position = canvasSize/2;
                p.addStimulus(spot);
                
                spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(spotVisible);
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
classdef SkewedTexture < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    %SKEWEDTEXTURE 
    % Show textures that wrapped in the same pixel value distribution as
    % natural images
    % tags displayed in sequence as: natural image, equivalent disc,
    % s_texture(textures that have the same distribution as natural
    % images), texture(original texture).
    % Detailed explanation
    % Parameters to set:
    % 1. textureSeed
    % 2. centerSigma
    % limited for ussing stored image patches from 00152 and 01151
    %
    properties
        preTime = 200 % ms
        stimTime = 200 % ms
        tailTime = 200 % ms
        imageName = '00152' %van hateren image names
        linearIntegrationFunction = 'gaussian center'
        textureSeed = 1
        centerSigma = 30 % texture sigma
        apertureDiameter = 200 % um
        rfSigmaCenter = 50 % (um) Enter from fit RF
        onlineAnalysis = 'none'
        numberOfAverages = uint16(120) % number of epochs to queue
        maskDiameter = 0; % place holder
        amp
    end
    
    properties (Hidden)
        ampType
        imageNameType = symphonyui.core.PropertyType('char', 'row',...
            {'00152','01151'});
        linearIntegrationFunctionType = symphonyui.core.PropertyType('char', 'row', {'gaussian center','uniform'})
        stimulusTag % image, disc, s_texture, texture
        % image related
        wholeImageMatrix
        allEquivalentIntensityValues
        patchLocations
        % for each image patch
        backgroundIntensity
        currentStimSet
        imagePatchIndex
        currentPatchLocation
        equivalentIntensity
        
        % the one to display
        imagePatchMatrix
        
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
                'groupBy',{'stimulusTag'});
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.ImageVsIntensityFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
            % TODO : get 30 patch locations (used Max's code)
            %load appropriate image...
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            obj.currentStimSet = '/VHsubsample_20160105';
            fileId=fopen([resourcesDir, obj.currentStimSet, '/imk', obj.imageName,'.iml'],'rb','ieee-be');
            img = fread(fileId, [1536,1024], 'uint16');
           
            img = double(img);
            img = (img./max(img(:))); %rescale s.t. brightest point is maximum monitor level
            obj.backgroundIntensity = mean(img(:));%set the mean to the mean over the image
            contrastImage = (img - obj.backgroundIntensity) ./ obj.backgroundIntensity;
            obj.wholeImageMatrix = img;
            %img = img.*255; %rescale s.t. brightest point is maximum monitor level
            %obj.wholeImageMatrix = uint8(img);
            
            %size of the stimulus on the prep:
            stimSize = obj.rig.getDevice('Stage').getCanvasSize() .* ...
                obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'); %um
            stimSize_VHpix = stimSize ./ (3.3); %um / (um/pixel) -> pixel
            radX = round(stimSize_VHpix(1) / 2); %boundaries for fixation draws depend on stimulus size
            radY = round(stimSize_VHpix(2) / 2);
            
            %get patch locations:
            load([resourcesDir,'NaturalImageFlashLibrary_072216.mat']);
            fieldName = ['imk', obj.imageName];
            % onlly select positive and ranked indexes
            LnResp = imageData.(fieldName).LnModelResponse;
            inds = find(LnResp > 0);
            xLoc = imageData.(fieldName).location(inds,1);
            yLoc = imageData.(fieldName).location(inds,2);
            subunitResp = imageData.(fieldName).SubunitModelResponse(inds);
            LnResp = imageData.(fieldName).LnModelResponse(inds);
            responseDifferences = subunitResp - LnResp;
            % only take 30 patches
            obj_noPatches = 30;
            %pull more than needed to account for empty bins at tail
            [~, ~, bin] = histcounts(responseDifferences,1.5*obj_noPatches);
            populatedBins = unique(bin);
            %pluck one patch from each bin
            pullInds = arrayfun(@(b) find(b == bin,1),populatedBins);
            %get patch indices:
            pullInds = randsample(pullInds,obj_noPatches);
            obj.patchLocations(1,1:obj_noPatches) = xLoc(pullInds); %in VH pixels
            obj.patchLocations(2,1:obj_noPatches) = yLoc(pullInds);
            % TODO : caclulate equivalent intensity
            sigmaC = obj.rfSigmaCenter ./ 3.3; %microns -> VH pixels
            RF = fspecial('gaussian',2.*[radX radY] + 1,sigmaC);
            [rr, cc] = meshgrid(1:(2*radX+1),1:(2*radY+1));
            if obj.apertureDiameter > 0
                apertureMatrix = sqrt((rr-radX).^2 + ...
                    (cc-radY).^2) < (obj.apertureDiameter/2) ./ 3.3;
                apertureMatrix = apertureMatrix';
            else
                apertureMatrix = ones(2.*[radX radY] + 1);
            end
            if strcmp(obj.linearIntegrationFunction,'gaussian center')
                weightingFxn = apertureMatrix .* RF; %set to zero mean gray pixels
            elseif strcmp(obj.linearIntegrationFunction,'uniform')
                weightingFxn = apertureMatrix;
            end
            weightingFxn = weightingFxn ./ sum(weightingFxn(:)); %sum to one
            
            for ff = 1:obj_noPatches
                tempPatch = contrastImage(round(obj.patchLocations(1,ff)-radX):round(obj.patchLocations(1,ff)+radX),...
                    round(obj.patchLocations(2,ff)-radY):round(obj.patchLocations(2,ff)+radY));
                equivalentContrast = sum(sum(weightingFxn .* tempPatch));
                obj.allEquivalentIntensityValues(ff) = obj.backgroundIntensity + ...
                    equivalentContrast * obj.backgroundIntensity;
            end
        end
        
         function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            % TODO
            % retrive the base image index
            obj_noPatches = 30;
            obj.imagePatchIndex = floor(mod(obj.numEpochsCompleted/4,obj_noPatches) + 1);
            obj.currentPatchLocation(1) = obj.patchLocations(1,obj.imagePatchIndex); %in VH pixels
            obj.currentPatchLocation(2) = obj.patchLocations(2,obj.imagePatchIndex);
            obj.equivalentIntensity = obj.allEquivalentIntensityValues(obj.imagePatchIndex);
            %imagePatchMatrix is in VH pixels
            %size of the stimulus on the prep:
            stimSize = obj.rig.getDevice('Stage').getCanvasSize() .* ...
                obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'); %um
            stimSize_VHpix = stimSize ./ (3.3); %um / (um/pixel) -> pixel
            radX = stimSize_VHpix(1) / 2; %boundaries for fixation draws depend on stimulus size
            radY = stimSize_VHpix(2) / 2;
            imageMatrix = obj.wholeImageMatrix(round(obj.currentPatchLocation(1)-radX):round(obj.currentPatchLocation(1)+radX),...
                round(obj.currentPatchLocation(2)-radY):round(obj.currentPatchLocation(2)+radY));
            imageMatrix = imageMatrix';
            eventInd = mod(obj.numEpochsCompleted,4);
            % according to stimulusTag, generate the image to display
            if eventInd == 0
                obj.stimulusTag = 'image';
                obj.imagePatchMatrix = imageMatrix;
            elseif eventInd == 1
                obj.stimulusTag = 'disc';
                obj.imagePatchMatrix = [];
            elseif eventInd == 2
                obj.stimulusTag = 's_texture';
                obj.imagePatchMatrix = edu.washington.riekelab.chris.utils.getImageTexture(imageMatrix, obj.centerSigma, obj.textureSeed, 1);
            elseif eventInd ==3
                obj.stimulusTag = 'texture';
                obj.imagePatchMatrix = edu.washington.riekelab.chris.utils.getImageTexture(imageMatrix, obj.centerSigma, obj.textureSeed, 0);
            end
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            % save parameters
            epoch.addParameter('currentStimSet', obj.currentStimSet);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('imagePatchIndex', obj.imagePatchIndex);
            epoch.addParameter('currentPatchLocation', obj.currentPatchLocation);
            epoch.addParameter('equivalentIntensity', obj.equivalentIntensity);
            epoch.addParameter('stimulusTag', obj.stimulusTag);
         end
        
         function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            if strcmp(obj.stimulusTag, 'disc')
                scene = stage.builtin.stimuli.Rectangle();
                scene.color = obj.equivalentIntensity;
            else
                scene = stage.builtin.stimuli.Image(uint8(obj.imagePatchMatrix*255));
                scene.setMinFunction(GL.LINEAR);
                scene.setMagFunction(GL.LINEAR);
            end
            scene.size = canvasSize;
            scene.position = canvasSize/2;
            p.addStimulus(scene);
            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);
            
           if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
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


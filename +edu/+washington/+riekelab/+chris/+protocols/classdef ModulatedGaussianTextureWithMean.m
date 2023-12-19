classdef ModulatedGaussianTextureWithMean < manookinlab.protocols.ManookinLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 0                   % Stimulus leading duration (ms)
        stimTime = 5000                  % Stimulus duration (ms)
        tailTime = 0                  % Stimulus trailing duration (ms)
        spatialContrast = 0.3                  % Contrast (0 - 1)
        temporalContrast=0.3
        textureSigma = 30:80:500           % Standard deviations (um)
        meanIntensities=[0.04 0.4]
        frameDwell=2
        numberOfAverages = uint16(200)   % Number of epochs
    end
    
    properties (Hidden)
        ampType
        seed
        noiseSeed
        textureMatrix
        currentTexture
        currentMean
        sigmaSequence
        currentIntensitySequence
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);     
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@manookinlab.protocols.ManookinLabStageProtocol(obj);      
            % create the array of texture matrix, ( each matrix is already contrast image with mean at 0.5 of max intensity and defined spatial contrast)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            canvasSizePix=obj.rig.getDevice('Stage').um2pix(max(canvasSize));
            for i=1:numel(obj.textureSigma)
                currentSigmaPix=obj.rig.getDevice('Stage').um2pix(obj.textureSigma(i));
                textureMatrix{i} = util.generateTexture(canvasSizePix,currentSigmaPix, obj.spatialContrast)+0.5;
            end
            obj.sigmaSequence=randperm(numel(obj.textureSigma));
                        % assuming frame rate at 60 Hz 
            updateRate=60/obj.frameDwell;
            framePerPeriod=ceil(updateRate*obj.stimTime/1e3);  % note that the frame here is not the monitor frame rate
            obj.intensityOverFrame=zeros(numel(meanIntensities),framePerPeriod);
            noiseStream= RandStream('mt19937ar', 'Seed', 1);
            for i=1:numel(obj.meanIntensities)
                obj.intensityOverFrame(i,1:framePerPeriod)= obj.meanIntensities(i)*(1+...
                    obj.temporalContrast * noiseStream.randn(1, framePerPeriod));
            end
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.currentMean);
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            % Generate the texture.
            
            % Create your noise image.
            checkerboard = stage.builtin.stimuli.Image(obj.currentTexture);
            checkerboard.position = canvasSize / 2;
            checkerboard.size = min(canvasSize)*ones(1,2);
            
            % Set the minifying and magnifying functions to form discrete
            % stixels.
            checkerboard.setMinFunction(GL.NEAREST);
            checkerboard.setMagFunction(GL.NEAREST);
            
            % Add the stimulus to the presentation.
            p.addStimulus(checkerboard);     
            %--------------------------------------------------------------
            gridVisible = stage.builtin.controllers.PropertyController(checkerboard, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3,'color', obj.getImgIntensity(state.time));
            p.addController(gridVisible);
          
        end
        noiseValue = stage.builtin.controllers.PropertyController(noiseRect, 'color',...
            @(state)getNoiseIntensity(obj,state.frame - preFrames, obj.intensityOverFrame));
        p.addController(noiseValue); %add the controller

        function i = getNoiseIntensity(obj, frame,internsityArrays)
            persistent intensity;
            if frame<0 %pre frames. frame 0 starts stimPts
                intensity = obj.meanIntensityArray(1);
            else %in stim frames
                if mod(frame, obj.frameDwell) == 0 %noise update
                    intensity = internsityArrays((frame-mod(frame,obj.frameDwell))/obj.frameDwell+1) ;
                end                  
            end
            i = intensity;
        end

        
        function prepareEpoch(obj, epoch)
            prepareEpoch@manookinlab.protocols.ManookinLabStageProtocol(obj, epoch);
            currentSigmaIndex
            currentMeanIndex 
            obj.currentTexture=obj.textureMatrix{currentSigmaIndex}; 
            obj.currentTexture=uint8(obj.currentTexture*255)
            obj.currentIntensitySequence=obj.intensityOverFrame(currentMeanIndex,:);
            % Save the seed.
            epoch.addParameter('currentSigma', obj.currentSigmaIndex(currentSigmaIndex));
            epoch.addParameter('currentMean', obj.meanIntensities(currentMeanIndex));
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end
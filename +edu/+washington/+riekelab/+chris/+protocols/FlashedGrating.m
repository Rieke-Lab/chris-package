classdef FlashedGrating < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        preTime = 200 % ms
        stimTime = 400 % ms
        tailTime = 400 % ms
        
        apertureDiameter = 200 % um
        barWidth=70;
        backgroundIntensity = 0.3; %0-1
        eqvContrast = [-0.1 0.1 0.3 0.5 0.7 0.9]
        grateSpatialContrast=0.9
        onlineAnalysis = 'none'
        amp % Output amplifier
        numberOfAverages = uint16(3) % number of epochs to queue
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        %saved out to each epoch...
        currentStimulusTag
%         tags=symphonyui.core.PropertyType('char', 'row', {'grate', 'disc'})
        tags={'grate', 'disc'}
        currentEqvContrast
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentStimulusTag'});
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
%             if ~strcmp(obj.onlineAnalysis,'none')
%                 obj.showFigure('edu.washington.riekelab.chris.figures.FlashedGrateVsIntensityFigure',...
%                 obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,'barWidth', obj.barWidth,...
%                 'preTime',obj.preTime,'stimTime',obj.stimTime,'eqvContrast',obj.eqvContrast,'tags',obj.tags);
%             end

        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            evenInd = mod(obj.numEpochsCompleted,2);
            if evenInd == 1 %even, show null
                obj.currentStimulusTag = 'disc';
            elseif evenInd == 0 %odd, show grating
                obj.currentStimulusTag = 'grate';
            end    
            pairInd=(obj.numEpochsCompleted-mod(obj.numEpochsCompleted,2))/2+1;
            contrastInd=mod(pairInd-1,numel(obj.eqvContrast))+1;
            obj.currentEqvContrast=obj.eqvContrast(contrastInd);
            epoch.addParameter('currentStimulusTag', obj.currentStimulusTag);
            epoch.addParameter('currentEqvContrast', obj.currentEqvContrast);
        end
        
        function p = createPresentation(obj)            
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);

            
            if strcmp(obj.currentStimulusTag,'grate')
                % Create grating stimulus.
                grate = stage.builtin.stimuli.Grating('square'); %square wave grating
                grate.orientation = 0;
                grate.size = [apertureDiameterPix, apertureDiameterPix];
                grate.position = canvasSize/2;
                grate.spatialFreq = 1/(2*obj.rig.getDevice('Stage').um2pix(obj.barWidth));
                grate.color = 2*(1+obj.currentEqvContrast)*obj.backgroundIntensity; %amplitude of square wave
                grate.contrast = obj.grateSpatialContrast; %multiplier on square wave
                zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
                offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
                [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
                phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
                phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
                grate.phase = phaseShift; %keep contrast reversing boundary in center
                p.addStimulus(grate); %add grating to the presentation
                
                %hide during pre & post
                grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(grateVisible);
            elseif strcmp(obj.currentStimulusTag,'disc')
                scene = stage.builtin.stimuli.Rectangle();
                scene.size = canvasSize;
                scene.color = (1+obj.currentEqvContrast)*obj.backgroundIntensity;
                scene.position = canvasSize/2;
                p.addStimulus(scene);
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(sceneVisible);
            end
             
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
            tf = obj.numEpochsPrepared < 2*obj.numberOfAverages*numel(obj.eqvContrast);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < 2*obj.numberOfAverages*numel(obj.eqvContrast);
        end

    end
    
end
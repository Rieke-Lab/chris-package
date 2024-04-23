classdef ExpandingGratingMasks < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 250 % ms
        stimTime = 250 % ms
        tailTime = 250 % ms
        spotIntensity = 0.3 % (0-1)
        spotSizes = 1000 % um
        maskSize = 100:100:1000 %mask diamater um
        barSize = 60;
        randomizeOrder = false
        backgroundIntensity = 0.5 % (0-1)
        onlineAnalysis = 'extracellular'
        numberOfAverages = uint16(2) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        spotSizeSequence
        currentSpotSize
    end
    
    properties (Hidden, Transient)
        
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            if length(obj.spotSizes) > 1
                colors = edu.washington.riekelab.chris.utils.pmkmp(length(obj.spotSizes),'CubicYF');
            else
                colors = [0 0 0];
            end
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.chris.figures.AreaSummationFigure',...
                    obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                    'preTime',obj.preTime,'stimTime',obj.stimTime);
            end
            if strcmp(obj.onlineAnalysis,'extracellular')
                psth=true;
            else
                psth=false;
                
            end
            obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'psth', psth,...
                'groupBy',{'currentSpotSize'},...
                'sweepColor',colors);
            % Create spot size sequence.
            obj.spotSizeSequence = obj.maskSize;
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            spotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.spotSizes);
            maskDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.currentSpotSize);
            barSizePix = obj.rig.getDevice('Stage').um2pix(obj.barSize);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create grate stimulus.
            grate = stage.builtin.stimuli.Grating('square'); %square wave grating
            grate.size = [spotDiameterPix spotDiameterPix];
            grate.position = canvasSize/2;
            grate.spatialFreq = 1/(2*barSizePix); %convert from bar width to spatial freq
            grate.color = 2*obj.backgroundIntensity;
            grate.contrast = 0.9;
            %calc to apply phase shift s.t. a contrast-reversing boundary
            %is in the center regardless of spatial frequency. Arbitrarily
            %say boundary should be positve to right and negative to left
            %crosses x axis from neg to pos every period from 0
            zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
            offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
            [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
            phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
            phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
            grate.phase = phaseShift; %keep contrast reversing boundary in center
            p.addStimulus(grate);
            
            aperture = stage.builtin.stimuli.Rectangle();
            aperture.position = canvasSize/2;
            aperture.color = obj.backgroundIntensity;
            aperture.size = [max(canvasSize) max(canvasSize)];
            mask1 = stage.core.Mask.createCircularAperture(spotDiameterPix/max(canvasSize), 1024); %circular aperture
            aperture.setMask(mask1);
            p.addStimulus(aperture); %add aperture
            
            mask = stage.builtin.stimuli.Ellipse();
            mask.position = canvasSize/2;
            mask.color = obj.backgroundIntensity;
            mask.radiusX = maskDiameterPix/2;
            mask.radiusY = maskDiameterPix/2;
            p.addStimulus(mask); %add mask
            
            
            %hide during pre & post
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
            
            index = mod(obj.numEpochsCompleted, length(obj.spotSizeSequence)) + 1;
            % Randomize the spot size sequence order at the beginning of each sequence.
            if index == 1 && obj.randomizeOrder
                obj.spotSizeSequence = randsample(obj.spotSizeSequence, length(obj.spotSizeSequence));
            end
            obj.currentSpotSize = obj.spotSizeSequence(index);
            epoch.addParameter('currentSpotSize', obj.currentSpotSize);
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.spotSizes);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.spotSizes);
        end
        
    end
    
end
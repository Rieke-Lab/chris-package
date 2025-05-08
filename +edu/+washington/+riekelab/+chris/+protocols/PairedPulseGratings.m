classdef PairedPulseGratings < edu.washington.riekelab.protocols.RiekeLabStageProtocol
% EXPANDINGSPOTS
%
% From turner-package
%
% 27Mar2019 - SSP - Added OnsetOffsetFigure
% -------------------------------------------------------------------------    
    properties
        preTime = 1000 % ms
        stimTime = 2000 % ms
        tailTime = 1000 % ms
        meanIntensity = 0.2 % (0-1)
        
        backgroundIntensity = 0.1 % (0-1)        
        apertureDiameter=300   % um
        flashDuration=50 % ms
        fixFlashTime=100
        barWidth=60
        FlashTimes=[100 200 400 800 1500 1900]
        downSample=4
        psth=true
        numberOfAverages = uint16(3) % number of epochs to queue
        amp
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})        
        currentFlashTime
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
%             if length(obj.spotSizes) > 1
%                 colors = edu.washington.riekelab.patterson.utils.pmkmp(length(obj.spotSizes),'CubicYF');
%             else
%                 colors = [0 0 0];
%             end
                 colors = [0 0 0];
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure',... 
                obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentSpotSize'},...
                'sweepColor',colors);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.showFigure('edu.washington.riekelab.turner.figures.AreaSummationFigure',...
                    obj.rig.getDevice(obj.amp), 'recordingType',obj.onlineAnalysis,...
                    'preTime', obj.preTime, 'stimTime', obj.stimTime);
%                 obj.showFigure('edu.washington.riekelab.patterson.figures.OnsetOffsetFigure',...
%                     obj.rig.getDevice(obj.amp), obj.preTime, obj.stimTime,...
%                     obj.spotSizes, 'recordingType', obj.onlineAnalysis,...
%                     'xName', 'currentSpotSize');
            end
            % Create spot size sequence.
            obj.spotSizeSequence = obj.spotSizes;
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            spotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.currentSpotSize);
            centerOffsetPix = obj.rig.getDevice('Stage').um2pix(obj.centerOffset);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create spot stimulus.            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = obj.spotIntensity;
            spot.radiusX = spotDiameterPix/2;
            spot.radiusY = spotDiameterPix/2;
            spot.position = canvasSize/2 + centerOffsetPix;
            p.addStimulus(spot);
            
            % hide during pre & post
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);

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
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
    
end
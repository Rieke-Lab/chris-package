classdef ContrastResponseSpots < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 250 % ms
        stimTime = 250 % ms
        tailTime = 250 % ms
        spotContrast = [-0.9 -0.75 -0.5 -0.25 -0.125 0.125 0.25 0.5 0.75 0.9] % relative to mean
        spotDiameter = 300 % um
        maskDiameter = 0 % um
        randomizeOrder = false
        backgroundIntensity = 0.5 % (0-1)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(40) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        
        
        spotContrastSequence
        currentSpotContrast
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
            if length(obj.spotContrast) > 1
                colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.spotContrast),'CubicYF');
            else
                colors = [0 0 0];
            end
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentSpotContrast'},...
                'sweepColor',colors);
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                % custom figure handler
                if isempty(obj.analysisFigure) || ~isvalid(obj.analysisFigure)
                    obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.contrastResponseAnalysis);
                    f = obj.analysisFigure.getFigureHandle();
                    set(f, 'Name', 'Contrast response function');
                    obj.analysisFigure.userData.countByContrast = zeros(size(obj.spotContrast));
                    obj.analysisFigure.userData.responseByContrast = zeros(size(obj.spotContrast));
                    obj.analysisFigure.userData.axesHandle = axes('Parent', f);
                else
                    obj.analysisFigure.userData.countByContrast = zeros(size(obj.spotContrast));
                    obj.analysisFigure.userData.responseByContrast = zeros(size(obj.spotContrast));
                end
                
            end
            % Create spot contrast sequence.
            obj.spotContrastSequence = obj.spotContrast;
        end
        
        function contrastResponseAnalysis(obj, ~, epoch) %online analysis function
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            axesHandle = obj.analysisFigure.userData.axesHandle;
            countByContrast = obj.analysisFigure.userData.countByContrast;
            responseByContrast = obj.analysisFigure.userData.responseByContrast;
            
            if strcmp(obj.onlineAnalysis,'extracellular') %spike recording
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                prePts = sampleRate*obj.preTime/1e3;
                stimPts = sampleRate*obj.stimTime/1e3;
                S.sp(S.sp < prePts) = [];
                S.sp(S.sp > stimPts + prePts) = [];
                
                newEpochResponse = length(S.sp); %spike count
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:sampleRate*obj.preTime/1000)); %baseline
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
                %charge transfer
                if strcmp(obj.onlineAnalysis,'exc') %measuring exc
                    chargeMult = -1;
                elseif strcmp(obj.onlineAnalysis,'inh') %measuring inh
                    chargeMult = 1;
                end
                newEpochResponse = chargeMult*trapz(epochResponseTrace(1:sampleRate*obj.stimTime/1000)); %pA*datapoint
                newEpochResponse = newEpochResponse/sampleRate; %pA*sec = pC
            end
            contrastInd = find(obj.currentSpotContrast == obj.spotContrast);
            countByContrast(contrastInd) = countByContrast(contrastInd) + 1;
            responseByContrast(contrastInd) = responseByContrast(contrastInd) + newEpochResponse;
            
            cla(axesHandle);
            h = line(obj.spotContrast, responseByContrast./countByContrast, 'Parent', axesHandle);
            set(h,'Color',[0 0 0],'LineWidth',2,'Marker','o');
            xlabel(axesHandle,'Contrast')
            if strcmp(obj.onlineAnalysis,'extracellular')
                ylabel(axesHandle,'Spike count')
            else
                ylabel(axesHandle,'Charge transfer (pC)')
            end
            obj.analysisFigure.userData.countByContrast = countByContrast;
            obj.analysisFigure.userData.responseByContrast = responseByContrast;
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            spotDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.spotDiameter);
            maskDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.maskDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            % Create spot stimulus.            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = obj.backgroundIntensity + (obj.backgroundIntensity*obj.currentSpotContrast);
            spot.radiusX = spotDiameterPix/2;
            spot.radiusY = spotDiameterPix/2;
            spot.position = canvasSize/2;
            p.addStimulus(spot);
            
            if (obj.maskDiameter > 0) % Create mask
                mask = stage.builtin.stimuli.Ellipse();
                mask.position = canvasSize/2;
                mask.color = obj.backgroundIntensity;
                mask.radiusX = maskDiameterPix/2;
                mask.radiusY = maskDiameterPix/2;
                p.addStimulus(mask); %add mask
            end
            
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
            
            index = mod(obj.numEpochsCompleted, length(obj.spotContrastSequence)) + 1;
            % Randomize the spot contrast sequence order at the beginning of each sequence.
            if index == 1 && obj.randomizeOrder
                obj.spotContrastSequence = randsample(obj.spotContrastSequence, length(obj.spotContrastSequence));
            end
            obj.currentSpotContrast = obj.spotContrastSequence(index);
            epoch.addParameter('currentSpotContrast', obj.currentSpotContrast);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
    
end
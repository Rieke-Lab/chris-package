classdef ExpandingGratingPlusMean < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 400 % ms
        stimTime = 250 % ms
        tailTime = 400 % ms
        apertureDiameter = [120 240 360 480 600] % um
        barWidth=60;
        meanOffset = [0 0.13 0.26 0.4];
        backgroundIntensity = 0.3; %0-1
        spatialContrast=0.3
        onlineAnalysis = 'extracellular'
        amp % Output amplifier
        numberOfAverages = uint16(3) % number of epochs to queue
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        currentApertureDiameter
        currentGratingSwtich
        currentMeanOffset
        stimIndex
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)% online analysis
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.apertureDiameter),'CubicYF');
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            %%%%%%%%% need a new online analysis figure later
%             obj.showFigure('edu.washington.riekelab.chris.figures.variableFlashFigure',...
%                 obj.rig.getDevice(obj.amp),'barWidth',obj.barWidth,'variableFlashTimes',obj.variableFlashTimes, ...
%                 'psth',obj.psth);
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            obj.showFigure('edu.washington.riekelab.turner.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentApertureDiameter'},...
                'sweepColor',colors);
        end
        
 
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.currentApertureDiameter);
            %keyboard
            % step background spot for specified time
            if obj.currentGratingSwtich==0  % show step spot
                spot = stage.builtin.stimuli.Ellipse();
                spot.radiusX =apertureDiameterPix/2;
                spot.radiusY =apertureDiameterPix/2;
                spot.position = canvasSize/2;
                p.addStimulus(spot);
                
                spotMean = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)obj.getSpotMean(state.time));
                
                p.addController(spotMean); %add the controller
                
            else
               
                grate = stage.builtin.stimuli.Grating('square'); %square wave grating
                grate.orientation = 0;
                grate.size = [apertureDiameterPix, apertureDiameterPix];
                grate.position = canvasSize/2;
                grate.spatialFreq = 1/(2*obj.rig.getDevice('Stage').um2pix(obj.barWidth));
                grate.color =2*obj.backgroundIntensity; %amplitude of square wave
                grate.contrast = obj.spatialContrast; %multiplier on square wave
                zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
                offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
                [shiftPix, ~] = min(offsets(offsets>0)); %positive shift in pixels
                phaseShift_rad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
                phaseShift = 360*(phaseShift_rad)/(2*pi); %phaseshift in degrees
                grate.phase = phaseShift; %keep contrast reversing boundary in center
                p.addStimulus(grate); %add grating to the presentation
                grateMean = stage.builtin.controllers.PropertyController(grate, 'color',...
                    @(state) obj.getGrateMean(state.time));
                p.addController(grateMean); %add the controller
                % hide during pre & post
                grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                    @(state) obj.getVisibility(state.time));
                p.addController(grateVisible);
            end
%             
            if (obj.currentApertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
        end
        
               function prepareEpoch(obj, epoch)%things get update through different epoch
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            % capture step response for first 3 epochs
            %this is where we update the parameters
%             if obj.numEpochsCompleted<1
%                 obj.currentBarWidth=0;
%             else
%                 barIndex=mod(obj.numEpochsCompleted-3,numel(obj.barWidth))+1;
%                 obj.currentBarWidth=obj.barWidth(barIndex);
%             end
            % parameters we are changing here is the 
            
            parameter_triplet =  [];
            %generate the stimlus parameter trilet
            for i = 1:length(obj.meanOffset)
                meanOffsetValue = obj.meanOffset(i);
                temp_aperture = reshape([(obj.apertureDiameter);(obj.apertureDiameter);(obj.apertureDiameter)],[],1); %apature diameter
                temp_grating  = reshape(repmat([ 0 ;1; 1],1,length(obj.apertureDiameter)),[],1); % have grating yes or no?
                temp_offset = reshape(repmat([meanOffsetValue ;0;meanOffsetValue],1,length(obj.apertureDiameter)),[],1);
                temp_triplet = [temp_aperture temp_grating temp_offset];
                parameter_triplet = [parameter_triplet; temp_triplet];
            end
            %update each parameter through each epoch
            obj.stimIndex = obj.numEpochsCompleted+1;
            obj.currentApertureDiameter = parameter_triplet(obj.stimIndex,1);
            obj.currentGratingSwtich =  parameter_triplet(obj.stimIndex,2);
            obj.currentMeanOffset  =  parameter_triplet(obj.stimIndex,3);
            
            %this is for book keep add the parameter to the symphony 
            epoch.addParameter('currentApertureDiameter', parameter_triplet(obj.stimIndex,1));
            epoch.addParameter('currentGratingSwtich', parameter_triplet(obj.stimIndex,2));
            epoch.addParameter('currentMeanOffset', parameter_triplet(obj.stimIndex,3));
            
        end
        
        function [spotMean] = getSpotMean(obj,time)
            
            spotMean=obj.backgroundIntensity;
            if time>obj.preTime/1e3 && time< (obj.preTime+obj.stimTime)/1e3
                spotMean=obj.currentMeanOffset+obj.backgroundIntensity;
            end
        end
        
        function [grateMean] = getGrateMean(obj,time)
            
            grateMean=0;
            if time>obj.preTime/1e3 && time< (obj.preTime+obj.stimTime)/1e3
                grateMean=2*(obj.currentMeanOffset+obj.backgroundIntensity);
            end
        end
        
        function [visibility] = getVisibility(obj,time)
            visibility=false;
            
            if time>obj.preTime/1e3 && time< (obj.preTime+obj.stimTime)/1e3
                visibility=true;
            end
            
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.meanOffset)*numel(obj.apertureDiameter);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.meanOffset)*numel(obj.apertureDiameter);
        end
        
    end
    
end
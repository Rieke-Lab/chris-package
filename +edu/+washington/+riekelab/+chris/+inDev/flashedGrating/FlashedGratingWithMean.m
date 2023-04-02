classdef FlashedGratingWithMean < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 1000 % ms
        stimTime = 2000 % ms
        tailTime = 2000 % ms
        apertureDiameter = 240 % um
        barWidth=[10 20 40 60 90 120];
        fixedFlashTime=100
        variableFlashTimes=[50 100 200 400 800]
        backgroundIntensity = 0.05; %0-1
        stepIntensity=0.5
        spatialContrast=0.9
        psth=true;
        amp % Output amplifier
        numberOfAverages = uint16(3) % number of epochs to queue
    end
    
    properties (Hidden)
        ampType
        currentBarWidth
        currentFlashDelay
        flashTimes
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            %%%%%%%%% need a new online analysis figure later
            obj.showFigure('edu.washington.riekelab.chris.figures.variableFlashFigure',...
                obj.rig.getDevice(obj.amp),'barWidth',obj.barWidth,'variableFlashTimes',obj.variableFlashTime, ...
                'psth',obj.psth);
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            % capture step response for first 3 epochs
            if obj.numEpochsCompleted<3
                obj.currentBarWidth=0;
                obj.currentFlashDelay=0;
            else
                flashIndex=mod(obj.numEpochsCompleted-3,numel(obj.variableFlashTimes))+1;
                tempInd=(obj.numEpochsCompleted-3-mod(obj.numEpochsCompleted-3,numel(obj.variableFlashTimes)))/numel(obj.variableFlashTimes)+1;
                barIndex=mod(tempInd-1,numel(obj.barWidth))+1;
                obj.currentFlashDelay=obj.variableFlashTime(flashIndex);
                obj.currentBarWidth=obj.barWidth(barIndex);
            end
            obj.flashTimes=[obj.fixFlashTime obj.preTime+obj.currentFlashDelay obj.preTime+obj.stimTime-obj.fixFlashTime ...,
                obj.preTime+obj.stimTime+obj.currentFlashDelay  obj.preTime+obj.stimTime+obj.tailTime-obj.fixFlashTime];
            epoch.addParameter('currentFlashDelay', obj.currentFlashDelay);
            epoch.addParameter('currentFlashTimes', obj.flashTimes);
            epoch.addParameter('currentBarWidth', obj.currentBarWidth);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            % step background spot for specified time
            if obj.currentBarWidth==0  % show step spot
                spot = stage.builtin.stimuli.Ellipse();
                spot.radiusX =apertureDiameterPix/2;
                spot.radiusY =apertureDiameterPix/2;
                spot.position = canvaSize/2;
                p.addStimulus(spot);
                spotMean = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)obj.getSpotMean(state.time));
                p.addController(spotMean); %add the controller
            else
                grate = stage.builtin.stimuli.Grating('square'); %square wave grating
                grate.orientation = 0;
                grate.size = [apertureDiameterPix, apertureDiameterPix];
                grate.position = canvaSize/2;
                grate.spatialFreq = 1/(2*obj.rig.getDevice('Stage').um2pix(obj.currentBarWidth));
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
                    @(state) obj.getGrateMean(obj));
                p.addController(grateMean); %add the controller
                % hide during pre & post
                grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                    @(state) obj.getVisibility(state.time));
                p.addController(grateVisible);
            end
            
            if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvaSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = [max(canvaSize) max(canvaSize)];
                mask = stage.core.Mask.createCircularAperture(obj.rig.getDevice('Stage').um2pix(max(canvaSize)), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
        end
        
        function [spotMean] = getSpotMean(obj,time)
            
            spotMean=obj.backgroundIntensity;
            if time>obj.preTime/1e3 && time< (obj.preTime+obj.stimTime)/1e3
                spotMean=obj.stepIntensity;
            end
        end
        
        function [grateMean] = getGrateMean(obj,time)
            
            grateMean=2*obj.backgroundIntensity;
            if time>obj.preTime/1e3 && time< (obj.preTime+obj.stimTime)/1e3
                grateMean=2*obj.stepIntensity;
            end
        end
        
        function [visibility] = getVisibility(obj,time)
            visibility=false;
            for i=1:length(obj.flashTimes)
                if time>obj.flashTimes(i)*1e-3 && time< (obj.flashTimes(i)+obj.flashDuration)*1e-3
                    visibility=true;
                end
            end
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.barWidth)*numel(obj.variableFlashTimes)+3;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.barWidth)*numel(obj.variableFlashTimes)+3;
        end
        
    end
    
end
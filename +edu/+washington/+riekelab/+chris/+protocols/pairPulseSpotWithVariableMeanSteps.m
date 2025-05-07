classdef pairPulseSpotWithVariableMeanSteps < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % Presents a pair of flash, intervened with opposing steps ( i.e. 0.9
    % contrast pairs intervened with -0.9 contrast, etc). 
    
    properties
        amp                             % Output amplifier
        preTime = 600                   % Spot leading duration (ms)
        stimTime = 2000                 % Spot duration (ms)
        tailTime = 400                  % Spot trailing duration (ms)
        spotDiameter = 200             % Spot diameter size (um)
        apertureDiameter=0
        flashContrast = -0.9  % probing spot contrast
        stepContrasts=[0 0.3 0.6 0.9]
        flashDuration=300      % ms
        meanIntensity = 0.5   % Background light intensity (0-1)
        pulseIntervals=0.5
        psth=false 
        numberOfAverages = uint16(3)    % Number of repeats 
        interpulseInterval = 0          % Duration between spots (s)
    end
    
    properties (Hidden)
        ampType
        stepContrastsType = symphonyui.core.PropertyType('denserealdouble','matrix')
        currentStepContrast
        contrastIndex
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);    
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            colors = edu.washington.riekelab.chris.utils.pmkmp(numel(obj.stepContrasts),'CubicYF');
            obj.showFigure('edu.washington.riekelab.figures.FrameTimingFigure', obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            if obj.psth
                obj.showFigure('edu.washington.riekelab.figures.MeanResponseFigure',...
                    obj.rig.getDevice(obj.amp),'psth', obj.psth,...
                    'groupBy',{'currentStepContrast'},...
                    'sweepColor',colors);
            end
            % randomize 
            tpIndex=repmat(1:numel(obj.stepContrasts), 1, obj.numberOfAverages);
            obj.contrastIndex=tpIndex(randperm(numel(tpIndex)));
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;

            obj.currentStepContrast=obj.stepContrasts(obj.contrastIndex(obj.numEpochsPrepared)); 
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            epoch.addParameter('currentStepContrast', obj.currentStepContrast)
        end
        
        
        function p = createPresentation(obj)
            
            device = obj.rig.getDevice('Stage');
            canvasSize = device.getCanvasSize();
            
            spotDiameterPix = device.um2pix(obj.spotDiameter);
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.meanIntensity);
            
            flash = stage.builtin.stimuli.Ellipse();
            flash.color = obj.meanIntensity;
            flash.radiusX = spotDiameterPix/2;
            flash.radiusY = spotDiameterPix/2;
            flash.position = canvasSize/2;
            p.addStimulus(flash);
            flashController = stage.builtin.controllers.PropertyController(flash, 'color', ...
                @(state) obj.getFlashColor(state.time));
            p.addController(flashController);
            
            if (obj.apertureDiameter > 0) %% Create aperture
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = canvasSize/2;
                aperture.color = 0;
                aperture.size = [max(canvasSize) max(canvasSize)];
                mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
            
        end
        
        function color=getFlashColor(obj,time)
            if (time>obj.preTime*1e-3 &&  time< (obj.preTime +obj.flashDuration) *1e-3)|| ...    % first flash 
                    (time>(obj.preTime+obj.flashDuration+obj.pulseIntervals)*1e-3 &&  time< (obj.preTime+obj.flashDuration*2+obj.pulseIntervals) *1e-3)     % second flash
                color=obj.meanIntensity*(obj.flashContrast+1);
            elseif time>(obj.preTime+obj.flashDuration)*1e-3 &&  time< (obj.preTime+obj.flashDuration+obj.pulseIntervals)*1e-3   % opossing flash interval
                color=obj.meanIntensity*(obj.currentStepContrast+1);
            else 
                color=obj.meanIntensity;
            end

        end 
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.stepContrasts);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.stepContrasts);
        end
        
    end
    
end
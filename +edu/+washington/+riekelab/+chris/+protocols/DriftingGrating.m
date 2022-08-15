classdef DriftingGrating < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        preTime = 100;                   % Grating leading duration (ms)
        stimTime = 6000;                 % Grating duration (ms)
        tailTime =100;                  % Grating trailing duration (ms)
        contrast = 0.3;                  % Grating contrast (0-1)
        barWidth = 100;                  % Bar width (microns)
        driftSpeed = 400;               % Center drift speed (pix/sec)
        meanIntensity = 0.5;       % Background light intensity (0-1)
        apertureRadius = 300;            % Aperature radius between inner and outer gratings.
        numDirs=12;
        onlineAnalysis = 'none';
        numberOfAverages = uint16(3)   % Number of repetitions
        amp
    end
    
    properties(Hidden)
        ampType
        currentDir
        dirList
        driftSpeedPix
        apertureRadiusPix
        barWidthPix
        phaseShift
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            import stage.core.*
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            %             obj.showFigure('edu.washington.riekelab.chris.figures.motionFigure',...
            %                 obj.rig.getDevice(obj.amp),'onlineAnalysis',obj.onlineAnalysis,'preTime',obj.preTime,'stimTime',obj.stimTime);

            obj.showFigure('edu.washington.riekelab.chris.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp), 'recordingType',obj.onlineAnalysis);
            obj.dirList=0: 360/obj.numDirs: (360-360/obj.numDirs);  obj.dirList=obj.dirList(randperm(numel(obj.dirList)));
            obj.driftSpeedPix =  obj.rig.getDevice('Stage').um2pix(obj.driftSpeed);
            obj.apertureRadiusPix =  obj.rig.getDevice('Stage').um2pix(obj.apertureRadius);
            obj.barWidthPix =  obj.rig.getDevice('Stage').um2pix(obj.barWidth);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            dirIndex = mod(obj.numEpochsCompleted,numel(obj.dirList))+1;
            obj.currentDir=obj.dirList(dirIndex);
            epoch.addParameter('currentDir', obj.currentDir);
        end
        
        function p=createPresentation(obj)
            % Open a window in windowed-mode and create a canvas. 'disableDwm' = false for demo only!
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p=stage.core.Presentation((obj.preTime+obj.stimTime+obj.tailTime)*1e-3);
            p.setBackgroundColor(obj.meanIntensity);
            grate = stage.builtin.stimuli.Grating('sine');
            grate.orientation = obj.currentDir;
            grate.size = 2*obj.apertureRadiusPix*ones(1,2);
            grate.position = canvasSize/2;
            grate.spatialFreq = 1/(2*obj.barWidthPix); %convert from bar width to spatial freq
            grate.contrast = obj.contrast;
            grate.color = 2*obj.meanIntensity;
            
            
            zeroCrossings = 0:(grate.spatialFreq^-1):grate.size(1);
            offsets = zeroCrossings-grate.size(1)/2; %difference between each zero crossing and center of texture, pixels
            [shiftPix, ~] = min(offsets); % min(offsets(offsets>0)); %positive shift in pixels
            phaseShiftRad = (shiftPix/(grate.spatialFreq^-1))*(2*pi); %phaseshift in radians
            obj.phaseShift = 360*(phaseShiftRad)/(2*pi); %phaseshift in degrees
            grate.phase = obj.phaseShift; %keep contrast reversing boundary in center
            
            gMask = stage.core.Mask.createCircularEnvelope(1024);
            grate.setMask(gMask);
            p.addStimulus(grate);
            
            phaseController = stage.builtin.controllers.PropertyController(grate, 'phase',...
                @(state) driftTrajectory(obj, state.time - obj.preTime* 1e-3));
            p.addController(phaseController);
            
            %  Make the grating visible only during the stimulus time.
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);
            
            % add aperture
            if obj.apertureRadius>0
                aperture=stage.builtin.stimuli.Rectangle();
                aperture.position=canvasSize/2;
                aperture.size=[obj.apertureRadiusPix*2 obj.apertureRadiusPix*2];
                mask=stage.core.Mask.createCircularAperture(1,1024);
                aperture.setMask(mask);
                aperture.color=obj.meanIntensity;
                p.addStimulus(aperture);
            end
            
        end
        
        function phase = driftTrajectory(obj, time)
            if time >= 0
                phase = time*obj.driftSpeedPix/obj.barWidthPix * 2 * pi;
            else
                phase = 0;
            end
            phase = phase*180/pi + obj.phaseShift;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*obj.numDirs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*obj.numDirs;
        end
        
    end
end



classdef DovesMoviePlusLedFlash < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        amp                             % Output amplifier
        led                             % Output LED
        preTime = 200                   % Stimulus leading duration (ms)
        stimTime = 6000                 % Stimulus duration (ms)
        tailTime = 300                  % Stimulus trailing duration (ms)
        stepStartTime=2000               % relative to the stimTime
        stepDurTime=300                     %  um
        stepPeakIntensity=1            % use either OLED/LCR or LED
        stimulusIndices = 1:100        % Stimulus number (1:161)
        maskDiameter = 0                % Mask diameter in pixels
        apertureDiameter = 800        % Aperture diameter in um.
        freezeFEMs = false
        onlineAnalysis = 'extracellular'% Type of online analysis
        numberOfAverages = uint16(1)   % Number of epochs
    end
    
    properties (Hidden)
        ampType
        ledType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        imageMatrix
        backgroundIntensity
        xTraj
        yTraj
        timeTraj
        imageName
        subjectName
        magnificationFactor
        currentStimSet
        stimulusIndex
        pkgDir
        im
        typeIndex
        canvasSize
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            %             obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
            %                 obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            % Get the resources directory.
            obj.pkgDir ='C:\Users\Fred Rieke\Documents\chris-package\+edu\+washington\+riekelab\+chris\+resources';
            obj.currentStimSet = 'dovesFEMstims20160826.mat';
            
            % Load the current stimulus set.
            obj.im = load([obj.pkgDir,'\',obj.currentStimSet]);
            
            % Get the image and subject names.
            if length(unique(obj.stimulusIndices)) == 1
                obj.stimulusIndex = unique(obj.stimulusIndices);
                obj.getImageSubject();
            end
            
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(0, device.background.displayUnits);
            
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.chris.figures.DovesMoviePlusMeanFigure',...
                    obj.rig.getDevice(obj.amp),[length(obj.stimulusIndices), 3],...
                    'recordingType',obj.onlineAnalysis,'stepDurTime',obj.stepDurTime,...
                    'preTime',obj.preTime,'stimTime',obj.stimTime,'stepStartTime',obj.stepStartTime);
            end
        end
        
        function getImageSubject(obj)
            % Get the image name.
            obj.imageName = obj.im.FEMdata(obj.stimulusIndex).ImageName;
            
            % Load the image.
            fileId = fopen([obj.pkgDir,'\doves\images\', obj.imageName],'rb','ieee-be');
            img = fread(fileId, [1536 1024], 'uint16');
            fclose(fileId);
            
            img = double(img');
            img = (img./max(img(:))); %rescale s.t. brightest point is maximum monitor level
            obj.backgroundIntensity = mean(img(:));%set the mean to the mean over the image
            img = img.*255; %rescale s.t. brightest point is maximum monitor level
            obj.imageMatrix = uint8(img);
            
            freezeTrajStart=floor(200*(obj.stepStartTime)/1e3);
            freezeTrajDur=floor(200*(obj.stepDurTime)/1e3);
            %get appropriate eye trajectories, at 200Hz
            if (obj.freezeFEMs) %freeze FEMs, hang on fixations
                xT = obj.im.FEMdata(obj.stimulusIndex).frozenX;
                yT = obj.im.FEMdata(obj.stimulusIndex).frozenY;
            else %full FEM trajectories during fixations
                xT = obj.im.FEMdata(obj.stimulusIndex).eyeX;
                yT = obj.im.FEMdata(obj.stimulusIndex).eyeY;
            end
            % so add some time of freezing of the frame
            obj.xTraj=[xT(1:freezeTrajStart) ones(1, freezeTrajDur)*xT(freezeTrajStart) xT(freezeTrajStart+1:end)];
            obj.yTraj=[yT(1:freezeTrajStart) ones(1, freezeTrajDur)*yT(freezeTrajStart) yT(freezeTrajStart+1:end)];
            obj.timeTraj = (0:(length(obj.xTraj)-1)) ./ 200; %sec
            
            %need to make eye trajectories for PRESENTATION relative to the center of the image and
            %flip them across the x axis: to shift scene right, move
            %position left, same for y axis - but y axis definition is
            %flipped for DOVES data (uses MATLAB image convention) and
            %stage (uses positive Y UP/negative Y DOWN), so flips cancel in
            %Y direction
            obj.xTraj = -(obj.xTraj - 1536/2); %units=VH pixels
            obj.yTraj = (obj.yTraj - 1024/2);
            
            %also scale them to canvas pixels. 1 VH pixel = 1 arcmin = 3.3
            %um on monkey retina
            %canvasPix = (VHpix) * (um/VHpix)/(um/canvasPix)
            obj.xTraj = obj.xTraj .* 3.3/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');
            obj.yTraj = obj.yTraj .* 3.3/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');
            
            % Load the fixations for the image.
            f = load([obj.pkgDir,'\doves\fixations\', obj.imageName, '.mat']);
            obj.subjectName = f.subj_names_list{obj.im.FEMdata(obj.stimulusIndex).SubjectIndex};
            
            % Get the magnification factor. Exps were done with each pixel
            % = 1 arcmin == 1/60 degree; 200 um/degree...
            obj.magnificationFactor = round(1/60*200/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'));
        end
        
        function [stim] = createLedStimulus(obj)
            % make step
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = obj.preTime+obj.stepStartTime;
            gen.stimTime = obj.stepDurTime;
            gen.tailTime = obj.tailTime+obj.stimTime-obj.stepStartTime;
            gen.mean = 0;
            if obj.typeIndex<3
                gen.amplitude = obj.stepPeakIntensity;
            else
                gen.amplitude=0;
            end
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            stim = gen.generate();
        end
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime+obj.stepDurTime) * 1e-3);
            obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p.setBackgroundColor(obj.backgroundIntensity);
            % Create your scene.
            scene = stage.builtin.stimuli.Image(obj.imageMatrix);
            scene.size = [size(obj.imageMatrix,2) size(obj.imageMatrix,1)]*obj.magnificationFactor;
            p0 = obj.canvasSize/2;
            scene.position = p0;
            
            scene.setMinFunction(GL.NEAREST);
            scene.setMagFunction(GL.NEAREST);
            
            % Add the stimulus to the presentation.
            p.addStimulus(scene);
            
            %apply eye trajectories to move image around
            scenePosition = stage.builtin.controllers.PropertyController(scene,...
                'position', @(state)getScenePosition(obj, state.time - (obj.preTime)/1e3, p0));
            % Add the controller.
            p.addController(scenePosition);
            
            
            if obj.typeIndex>1
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state) (state.time >= obj.preTime * 1e-3 &&  state.time <= (obj.preTime+obj.stepStartTime) * 1e-3) || ...,
                    (state.time >= (obj.preTime+obj.stepStartTime+obj.stepDurTime) * 1e-3 && state.time < (obj.preTime + obj.stimTime+obj.stepDurTime) * 1e-3));
            else
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state)  state.time <= (obj.preTime+obj.stepStartTime) * 1e-3);
            end
            p.addController(sceneVisible);
            
            function p = getScenePosition(obj, time, p0)
                if time < 0
                    p = p0;
                elseif time > obj.timeTraj(end) %out of eye trajectory, hang on last frame
                    p(1) = p0(1) + obj.xTraj(end);
                    p(2) = p0(2) + obj.yTraj(end);
                else %within eye trajectory and stim time
                    dx = interp1(obj.timeTraj,obj.xTraj,time);
                    dy = interp1(obj.timeTraj,obj.yTraj,time);
                    p(1) = p0(1) + dx;
                    p(2) = p0(2) + dy;
                end
            end
            
            % Size is 0 to 1
            sz = (obj.apertureDiameter)/min(obj.canvasSize);
            % Create the outer mask.
            if sz < 1
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = obj.canvasSize/2;
                aperture.color = obj.backgroundIntensity;
                aperture.size = obj.canvasSize;
                [x,y] = meshgrid(linspace(-obj.canvasSize(1)/2,obj.canvasSize(1)/2,obj.canvasSize(1)), ...
                    linspace(-obj.canvasSize(2)/2,obj.canvasSize(2)/2,obj.canvasSize(2)));
                distanceMatrix = sqrt(x.^2 + y.^2);
                circle = uint8((distanceMatrix >= obj.apertureDiameter/2) * 255);
                mask = stage.core.Mask(circle);
                aperture.setMask(mask);
                p.addStimulus(aperture); %add aperture
            end
            
            if (obj.maskDiameter > 0) % Create mask
                mask = stage.builtin.stimuli.Ellipse();
                mask.position = obj.canvasSize/2;
                mask.color = obj.backgroundIntensity;
                mask.radiusX = obj.maskDiameter/2;
                mask.radiusY = obj.maskDiameter/2;
                p.addStimulus(mask); %add mask
            end
        end
        
        function prepareEpoch(obj, epoch)
            if length(unique(obj.stimulusIndices)) > 1
                % Set the current stimulus trajectory.
                obj.stimulusIndex = obj.stimulusIndices(mod(obj.numEpochsCompleted,...
                    length(obj.stimulusIndices)) + 1);
                obj.getImageSubject();
            end
            % type index  1 for spot only, 2 for adapting flash, 3 for mean
            % flash
            % Save the parameters.
            if obj.numEpochsCompleted<3
                obj.typeIndex=1;
            else
                obj.typeIndex=mod(obj.numEpochsCompleted-3,2)+2;
            end
            epoch.addParameter('stimulusIndex', obj.stimulusIndex);
            epoch.addParameter('imageName', obj.imageName);
            epoch.addParameter('subjectName', obj.subjectName);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('magnificationFactor', obj.magnificationFactor);
            epoch.addParameter('currentStimSet',obj.currentStimSet);
            epoch.addParameter('typeIndex',obj.typeIndex);
            
            stim = obj.createLedStimulus();
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            device = obj.rig.getDevice(obj.amp);
            epoch.addDirectCurrentStimulus(device, device.background, 2, obj.sampleRate); % spatial stimuli
            epoch.addResponse(device);
        end
        
        % Same presentation each epoch in a run. Replay.
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            if (obj.numEpochsCompleted >= 1) && (obj.numEpochsCompleted < obj.numberOfAverages) && (length(unique(obj.stimulusIndices)) == 1)
                obj.rig.getDevice('Stage').replay
            else
                obj.rig.getDevice('Stage').play(obj.createPresentation());
            end
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*length(obj.stimulusIndices)*3;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*length(obj.stimulusIndices)*3;
        end
    end
end
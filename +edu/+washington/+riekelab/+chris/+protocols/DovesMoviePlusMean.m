classdef DovesMoviePlusMean < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 200                   % Stimulus leading duration (ms)
        stimTime = 5000                 % Stimulus duration (ms)
        tailTime = 300                  % Stimulus trailing duration (ms)
        waitTime = 0                 % Stimulus wait duration (ms)
        stepStartTime=2000               % relative to the stimTime
        stepDurTime=300                     %  um
        stepPeakIntensity=1            % use either OLED/LCR or LED
        meanIntensity=0.1
        contrastScale=0.9;
        stimulusIndices = 1:120       % Stimulus number (1:161) 
        maskDiameter = 0                % Mask diameter in pixels
        apertureDiameter = 800        % Aperture diameter in um.
        freezeFEMs = false
        spatialScaling=2
        onlineAnalysis = 'extracellular'% Type of online analysis
        numberOfAverages = uint16(1)   % Number of epochs
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
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
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
%             obj.showFigure('edu.washington.riekelab.turner.figures.FrameTimingFigure',...
%                 obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
%  
%             
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
            img=(img-mean(img(:)))/mean(img(:)); % contrast image
            img=obj.contrastScale*img*obj.meanIntensity+ obj.meanIntensity;
            img=img*255;
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
            obj.magnificationFactor = obj.spatialScaling*round(1/60*200/obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel'));
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime+obj.stepDurTime) * 1e-3);
            obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p.setBackgroundColor(obj.meanIntensity);
            apertureDiameterPix =obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);

            if obj.typeIndex>1
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
                    'position', @(state)getScenePosition(obj, state.time - (obj.preTime+obj.waitTime)/1e3, p0));
                % Add the controller.
                p.addController(scenePosition);
                       
                sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                    @(state) (state.time >= obj.preTime * 1e-3 &&  state.time <= (obj.preTime+obj.stepStartTime) * 1e-3) || ...,
                    (state.time >= (obj.preTime+obj.stepStartTime+obj.stepDurTime) * 1e-3 && state.time < (obj.preTime + obj.stimTime+obj.stepDurTime) * 1e-3));
                p.addController(sceneVisible);
            end
        
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
             
            % Create spot stimulus.
            spot = stage.builtin.stimuli.Ellipse();
            if obj.typeIndex<3
                spot.color = obj.stepPeakIntensity;
            else
                spot.color = obj.meanIntensity;
            end
            spot.radiusX = size(obj.imageMatrix,1)/2;
            spot.radiusY = size(obj.imageMatrix,2)/2;
            spot.position = obj.canvasSize/2;
            p.addStimulus(spot);
            
            % show only during step
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= (obj.preTime+obj.stepStartTime) * 1e-3 && ...,
                state.time < ((obj.preTime+obj.stepStartTime)+obj.stepDurTime) * 1e-3);
            p.addController(spotVisible);
            
               % Size is 0 to 1
            sz = (apertureDiameterPix)/min(obj.canvasSize);
            % Create the outer mask.
            if sz < 1
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = obj.canvasSize/2;
                aperture.color = obj.meanIntensity;
                aperture.size = obj.canvasSize;
                [x,y] = meshgrid(linspace(-obj.canvasSize(1)/2,obj.canvasSize(1)/2,obj.canvasSize(1)), ...
                    linspace(-obj.canvasSize(2)/2,obj.canvasSize(2)/2,obj.canvasSize(2)));
                distanceMatrix = sqrt(x.^2 + y.^2);
                circle = uint8((distanceMatrix >= apertureDiameterPix/2) * 255);
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
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            if length(unique(obj.stimulusIndices)) > 1
                % Set the current stimulus trajectory.
                obj.stimulusIndex = obj.stimulusIndices(mod((obj.numEpochsCompleted-3-rem(obj.numEpochsCompleted-3,2))/2,...
                    length(obj.stimulusIndices))+1);
                obj.getImageSubject();
            end
            sInd=obj.stimulusIndex;
            fprintf('%s %d\n', 'stimulus index ::', sInd);
            % type index  1 for spot only, 2 for adapting flash, 3 for mean
            % flash
            if obj.numEpochsCompleted<3
                obj.typeIndex=1;
            else
                obj.typeIndex=mod(obj.numEpochsCompleted-3,2)+2;
            end
            % Save the parameters.
            epoch.addParameter('stimulusIndex', obj.stimulusIndex);
            epoch.addParameter('imageName', obj.imageName);
            epoch.addParameter('subjectName', obj.subjectName);
            epoch.addParameter('backgroundIntensity', obj.backgroundIntensity);
            epoch.addParameter('magnificationFactor', obj.magnificationFactor);
            epoch.addParameter('currentStimSet',obj.currentStimSet);
            epoch.addParameter('typeIndex',obj.typeIndex);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*length(obj.stimulusIndices)*2+3;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*length(obj.stimulusIndices)*2+3;
        end
    end
end
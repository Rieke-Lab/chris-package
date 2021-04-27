classdef LinearDiscNaturalMovies < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        % Stimulus timing
        preTime     = 250  % in ms
        stimTime    = 5500 % in ms
        tailTime    = 250  % in ms
        
        rfSigma   = 50;  % (um) enter from difference of gaussians fit for overlaying receptive field.
              
        imageName = '00152' %van hateren image names
        startPatchMean='negative'
        D = 5; % Drift diffusion coefficient, in microns
        % Additional parameters
        onlineAnalysis      = 'extracellular'
        numberOfAverages    = uint16(5) % number of repeats
        randomSeed=1
        amp % Output amplifier
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'}) 
        backgroundIntensity
        directory
        filename
        imageNameType = symphonyui.core.PropertyType('char', 'row', {'00152','00377','00405','00459','00657','01151','01154',...
            '01192','01769','01829','02265','02281','02733','02999','03093',...
            '03347','03447','03584','03758','03760'})
         patchMeanType = symphonyui.core.PropertyType('char', 'row', {'all','negative','positive'})
        
        wholeImageMatrix
        contrastImage
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
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis);
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            % Load generic settings
            settings.canvasSize=obj.rig.getDevice('Stage').getCanvasSize();
            settings.monitorFrameRate=obj.rig.getDevice('Stage').getConfigurationSetting('monitorRefreshRate');

            
            % Directory to export movies
            obj.directory = 'Documents/freedland-package/+edu/+washington/+riekelab/+chris/+movies/';
            
            % generate the movie
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            obj.currentImageSet = '\VHsubsample_20160105';
            obj.currentStimSet = 'SaccadeLocationsLibrary_20171011';
            load([resourcesDir,obj.currentStimSet,'.mat']);
            fieldName = ['imk', obj.imageName];
            
              % get the image and scale it:
            obj.currentStimSet = '\VHsubsample_20160105';
            fileId=fopen([resourcesDir, obj.currentImageSet, '\imk', obj.imageName,'.iml'],'rb','ieee-be');
            img = fread(fileId, [1536,1024], 'uint16');
            img = double(img);
            img = (img./max(img(:))); %rescale s.t. brightest point is maximum monitor level
                  obj.backgroundIntensity = mean(img(:));%set the mean to the mean over the image
            obj.contrastImage = (img - obj.backgroundIntensity) ./ obj.backgroundIntensity;
            img = img.*255; %rescale s.t. brightest point is maximum monitor level
            obj.wholeImageMatrix = uint8(img');

            imageMean = imageData.(fieldName).imageMean;
            obj.backgroundIntensity = imageMean;%set the mean to the mean over the image
            locationMean = imageData.(fieldName).patchMean;
            
            if strcmp(obj.startPatchMean,'all')
                inds = 1:length(locationMean);
            elseif strcmp(obj.patchMean,'positive')
                inds = find((locationMean-imageMean) > 0);
            elseif strcmp(obj.patchMean,'negative')
                inds = find((locationMean-imageMean) <= 0);
            end
            
            rng(obj.randomSeed); %set random seed for fixation draw
            drawInd = randsample(inds,1);
            obj.p0(1) = imageData.(fieldName).location(drawInd,1);
            obj.p0(2) = imageData.(fieldName).location(drawInd,2);


            % make eye movement trajectory.
            rng(obj.randomSeed); %set random seed for fixation draw
            noFrames = obj.rig.getDevice('Stage').getMonitorRefreshRate() * (obj.stimTime/1e3);
            %generate random walk out
 
            tempX_1 = obj.D .* randn(1,round(noFrames/2));
            tempY_1 = obj.D .* randn(1,round(noFrames/2));
            %hold off first step to subtract later
            tempX_1_a = tempX_1(2:end);
            tempY_1_b = tempY_1(2:end);
            %randomize walk back
            tempX_2 = [-tempX_1_a(randperm(length(tempX_1_a))), -tempX_1(1)];
            tempY_2 = [-tempY_1_b(randperm(length(tempY_1_b))), -tempY_1(1)];
            
            %cumulative sum, flip to start at 0
            obj.xTraj = fliplr(cumsum([tempX_1, tempX_2]));
            obj.yTraj = fliplr(cumsum([tempY_1, tempY_2]));

            obj.timeTraj = (0:(length(obj.xTraj)-1)) ./...
                obj.rig.getDevice('Stage').getMonitorRefreshRate(); %sec
            
            obj.xTraj = obj.xTraj ./obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');
            obj.yTraj = obj.yTraj ./obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');
            
            obj.xTraj= obj.p0(1)+obj.xTraj;
            obj.yTraj= obj.p0(2)+obj.yTraj;
            
            %create the original natural movie and weighted movie
            [rawMovie,discMovie]=makeMovie();
            obj.filename{1,1} = 'movie';
            obj.filename{2,1} = 'disc';
            exportMovie(obj, rawMovie, obj.filename{1,1});
            exportMovie(obj, discMovie, obj.filename{2,1});

          
            function [rawMovie,discMovie] = makeMovie(obj)
                rfSigmaPix = obj.rig.getDevice('Stage').um2pix(obj.rfSigma);

                % Pixels on each side of the trajectory.
                xLength = floor(rfSigmaPix);
                yLength = floor(rfSigmaPix);
                
                % Calculate movie frames with DOVES eye trajectories
                xRange = zeros(length(obj.xTraj),xLength*2+1);
                yRange = zeros(length(obj.yTraj),yLength*2+1);
                for i = 1:length(obj.xTraj)
                    xRange(i,:) = round(obj.xTraj(i) - xLength : obj.xTraj(i) + xLength);
                    yRange(i,:) = round(obj.yTraj(i) - yLength : obj.yTraj(i) + yLength);
                end
                
                % Make movies
                rawMovie = zeros(size(yRange,2),size(xRange,2),1,length(obj.xTraj));
                for i = 1:length(obj.xTraj)
                    rawMovie(:,:,1,i) = obj.wholeImageMatrix(yRange(i,:),xRange(i,:)); % raw movie
                end
                
                
                RF = fspecial('gaussian',2.*[xLength yLength],rfSigmaPix);
                [rr, cc] = meshgrid(1:(2*xLength),1:(2*yLength));
                apertureMatrix = sqrt((rr-radX).^2 + ...
                    (cc-radY).^2) < rfSigmaPix;
                
                weightingFxn = apertureMatrix .* RF; %set to zero mean gray pixels
                weightingFxn = weightingFxn ./ sum(weightingFxn(:)); %sum to one
                discMovie=zeros(size(rawMovie));
                for i = 1:length(obj.xTraj)
                     tempPatch = obj.contrastImage(yRange(i,:),xRange(i,:));
                     equivalentContrast = sum(sum(weightingFxn .* tempPatch));
                    EqvInt=obj.backgroundIntensity +equivalentContrast * obj.backgroundIntensity; 
                discMovie(:,:,1,i) = ones(size(rawMovie,1),size(rawMovie,2))*EqvInt;
                end
                
            end
            
           
            function exportMovie(obj, movieFile, filename)      
                refreshRate = obj.rig.getDevice('Stage').getConfigurationSetting('monitorRefreshRate');
                % Append blank frames for preTime/tailTime
                blankFrames = ones(size(movieFile(:,:,1,1))) .* 255 .* obj.backgroundIntensity;
                preFrames = repmat(blankFrames,1,1,1,round(refreshRate * (obj.preTime/1e3)));
                postFrames = repmat(blankFrames,1,1,1,round(refreshRate * (obj.tailTime/1e3)));
                
                % Append last frame
                lastFrame = repmat(movieFile(:,:,1,end),1,1,1,round(refreshRate * (obj.stimTime/1e3)) - size(movieFile,4));
                movieExport = uint8(cat(4,preFrames,movieFile,lastFrame,postFrames));
                
                % Export movies
                v = VideoWriter(strcat(obj.directory,filename),'Uncompressed AVI');
                v.FrameRate = refreshRate;
                open(v)
                for b = 1:size(movieExport,4)
                    writeVideo(v,movieExport(:,:,1,b));
                end
                close(v)
            end
        end
        
        function prepareEpoch(obj, epoch)
            
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            evenInd = mod(obj.numEpochsCompleted,2);
            if evenInd == 1 %even, show uniform linear equivalent intensity
                obj.stimulusTag = 'disc';
            elseif evenInd == 0 %odd, show image
                obj.stimulusTag = 'movie';
            end
        end
        
        function p = createPresentation(obj)
            rfSigmaPix = obj.rig.getDevice('Stage').um2pix(obj.rfSigma);
            % Stage presets
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize(); 
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity)   % Set background intensity
            evenInd = mod(obj.numEpochsCompleted,2);
            % Prep to display image
            scene = stage.builtin.stimuli.Movie(fullfile(obj.directory,strcat(obj.filename{evenInd},'.avi')));
            scene.size = [floor(rfSigmaPix)*2+1, floor(rfSigmaPix)*2+1];
            p0 = canvasSize/2;
            scene.position = p0;
            scene.setMinFunction(GL.LINEAR); % Linear scaling to monitor
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            
            %% add aperture 
            aperture = stage.builtin.stimuli.Rectangle();
            aperture.position = canvasSize/2;
            aperture.color = obj.backgroundIntensity;
            aperture.size = 2.*[max(canvasSize) max(canvasSize)];
            mask = stage.core.Mask.createCircularAperture(rfSigmaPix*2/(2*max(canvasSize)), 1024); %circular aperture
            aperture.setMask(mask);
            p.addStimulus(aperture); %add aperture
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared <  obj.numberOfAverages*2;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted <  obj.numberOfAverages*2;
        end
    end
end
classdef StrfFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        frameMonitor
        stageDevice
        recordingType
        preTime
        stimTime
        frameDwell
        seedID
        binaryNoise
    end
    
    properties (Access = private)
        axesHandle
        imHandle
        noiseStream
        newFilter
        epochCount
    end
    
    methods
        
        function obj = StrfFigure(ampDevice, frameMonitor, stageDevice, varargin)
            obj.ampDevice = ampDevice;
            obj.frameMonitor = frameMonitor;
            obj.stageDevice = stageDevice;
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('frameDwell', [], @(x)isvector(x));
            ip.addParameter('seedID', 'noiseSeed', @(x)ischar(x));
            ip.addParameter('binaryNoise', true, @(x)islogical(x));
            ip.parse(varargin{:});
            
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameDwell = ip.Results.frameDwell;
            obj.seedID = ip.Results.seedID;
            obj.binaryNoise = ip.Results.binaryNoise;

            obj.epochCount = 0;
            obj.newFilter = 0;
            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            playStrfButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Play Strf movie', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedPlayStrf);
            setIconImage(playStrfButton, symphonyui.app.App.getResource('icons/view_only.png'));

            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, '');
            ylabel(obj.axesHandle, '');
            

            obj.figureHandle.Name ='STRF';
        end

        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = sampleRate*obj.preTime/1000;
            if strcmp(obj.recordingType,'extracellular') %spike recording
                newResponse = zeros(size(epochResponseTrace));
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                newResponse(S.sp) = 1;
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:prePts)); %baseline
                if strcmp(obj.recordingType,'exc') %measuring exc
                    polarity = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    polarity = 1;
                end
                newResponse = polarity * epochResponseTrace;
            end
            %load frame monitor data
            if isa(obj.stageDevice,'edu.washington.riekelab.devices.LightCrafterDevice')
                lightCrafterFlag = 1;
            else %OLED stage device
                lightCrafterFlag = 0;
            end
            frameRate = obj.stageDevice.getMonitorRefreshRate();
            FMresponse = epoch.getResponse(obj.frameMonitor);
            FMdata = FMresponse.getData();
            frameTimes = edu.washington.riekelab.turner.utils.getFrameTiming(FMdata,lightCrafterFlag);
            preFrames = frameRate*(obj.preTime/1000);
            firstStimFrameFlip = frameTimes(preFrames+1);
            newResponse = newResponse(firstStimFrameFlip:end); %cut out pre-frames
            
            %reconstruct noise stimulus
            filterLen = 800; %msec, length of linear filter to compute
            %fraction of noise update rate at which to cut off filter spectrum
            freqCutoffFraction = 0.8;
            
            currentNoiseSeed = epoch.parameters(obj.seedID);
            numChecksX = epoch.parameters('numChecksX');
            numChecksY = epoch.parameters('numChecksY');
            %reconstruct stimulus trajectories...
            stimFrames = round(frameRate * (obj.stimTime/1e3));
            response = zeros(1, floor(stimFrames/obj.frameDwell));
            %reset random stream to recover stim trajectories
            obj.noiseStream = RandStream('mt19937ar', 'Seed', currentNoiseSeed);
            % get stim trajectories and response in frame updates
            chunkLen = obj.frameDwell*mean(diff(frameTimes));
            noiseMatrix = zeros(numChecksY,numChecksX,floor(stimFrames/obj.frameDwell));
            for ii = 1:floor(stimFrames/obj.frameDwell)
                if (obj.binaryNoise)
                    noiseMatrix(:,:,ii) = ... 
                        obj.noiseStream.rand(numChecksY,numChecksX) > 0.5;
                else
                    noiseMatrix(:,:,ii) = ... 
                        obj.noiseStream.randn(numChecksY,numChecksX);
                end
                response(ii) = mean(newResponse(round((ii-1)*chunkLen + 1) : round(ii*chunkLen)));
            end
            updateRate = (frameRate/obj.frameDwell); %hz
            
            filterPts = (filterLen/1000)*updateRate;
            
            filterTmp = zeros(numChecksY,numChecksX,filterPts);
            for b = 1 : size(noiseMatrix,1)
                for c = 1 : size(noiseMatrix,2)
                    tmp = edu.washington.riekelab.turner.utils.getLinearFilterOnline(...
                        squeeze(noiseMatrix(b,c,:))',...
                        response,updateRate, freqCutoffFraction*updateRate);
                    filterTmp(b,c,:) = tmp(1:filterPts);
                end
            end
            %normalize within each epoch
            filterTmp = filterTmp ./ max(filterTmp(:));
            obj.newFilter = ((obj.epochCount - 1)*obj.newFilter + filterTmp) / obj.epochCount;
            
            filterTimes = linspace(0,filterLen,filterPts); %msec
            targetTime = 30; %msec
            [~, snapShotInd] = min(abs(filterTimes - targetTime));
            if isempty(obj.imHandle)
                obj.imHandle = imagesc(obj.newFilter(:,:,snapShotInd),...
                    'Parent', obj.axesHandle);
                title(obj.axesHandle,['Strf at ', num2str(filterTimes(snapShotInd)) ' msec']);
                colormap(obj.axesHandle, gray)
            else
                set(obj.imHandle, 'CData', obj.newFilter(:,:,snapShotInd));
            end
        end
        
    end
    
    methods (Access = private)
        
        function onSelectedPlayStrf(obj, ~, ~)
            implay(obj.newFilter);
        end
    end

end


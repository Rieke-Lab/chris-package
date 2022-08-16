classdef motionFigure < symphonyui.core.FigureHandler
    properties (SetAccess = private)
        device
        onlineAnalysis
        preTime
        stimTime
    end
    
    properties (Access = private)
        axesHandle
        allDirs
        allEpochResponses
        baselines
        summaryData
    end
    
    methods
        function obj = motionFigure(device, varargin)
            ip = inputParser();
            ip.addParameter('onlineAnalysis', 'extracellular', @(x)ischar(x));
            ip.addParameter('preTime',0.0, @(x)isfloat(x));
            ip.addParameter('stimTime',0.0, @(x)isfloat(x));
            ip.parse(varargin{:});
            
            obj.device = device;
            obj.onlineAnalysis = ip.Results.onlineAnalysis;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            
            obj.createUi();
        end
        
        function createUi(obj)

            import appbox.*;           
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
        end
        
        function handleEpoch(obj, epoch)         
            currentDir=epoch.parameters('currentDir');
            %%%%%%%%%%%
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = sampleRate*obj.preTime/1000;
            stimPts = sampleRate*obj.stimTime/1000;
            preScaleFactor = stimPts / prePts;

            if strcmp(obj.onlineAnalysis,'extracellular')
                epochResponseTrace = epochResponseTrace(1:prePts+stimPts);
                %count spikes
                S = edu.washington.riekelab.chris.utils.spikeDetectorOnline(epochResponseTrace,[],sampleRate);
                newEpochResponse = sum(S.sp > prePts); %spike count during stim
                newBaseline = preScaleFactor * sum(S.sp < prePts); %spike count before stim, scaled by length
            else
                if strcmp(obj.onlineAnalysis,'exc')  %measuring exc
                    chargeMult = -1;
                elseif  strcmp(obj.onlineAnalysis,'inh') %measuring inh
                    chargeMult = 1;
                end
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:prePts)); %baseline adjustment
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((prePts+1):(prePts+stimPts));
                %charge transfer
                if strcmp(obj.recordingType,'exc') %measuring exc
                    chargeMult = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    chargeMult = 1;
                end
                newEpochResponse = chargeMult*trapz(epochResponseTrace(1:sampleRate*obj.stimTime/1000)); %pA*datapoint
                newEpochResponse = newEpochResponse/sampleRate; %pA*sec = pC
                newBaseline = 0;
            end
            
            obj.allDirs = cat(1,obj.allDirs,currentDir);
            obj.allEpochResponses = cat(1,obj.allEpochResponses,newEpochResponse);
            obj.baselines = cat(1,obj.baselines,newBaseline);

            obj.summaryData.dirList = unique(obj.allDirs);
            obj.summaryData.meanResponses = zeros(size(obj.summaryData.dirList));
            for dirIndex = 1:length(obj.summaryData.dirList)
                pullIndices = (obj.summaryData.dirList(dirIndex) == obj.allDirs);
                obj.summaryData.meanResponses(dirIndex) = mean(obj.allEpochResponses(pullIndices));
            end
            
            if isempty(obj.lineHandle)
                obj.lineHandle = polarplot(deg2rad(obj.summaryData.dirList), obj.summaryData.meanResponses,...
                    'Parent', obj.axesHandle,'linewidth',2,'color','r');
            else
                set(obj.lineHandle, 'XData', obj.summaryData.dirList,...
                    'YData', obj.summaryData.meanResponses);
            end
        end
    end
end

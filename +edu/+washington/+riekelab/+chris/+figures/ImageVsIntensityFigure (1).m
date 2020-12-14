classdef ImageVsIntensityFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        unityHandle
        
        allEpochResponses
        allPatchIndices
        summaryData
    end
    
    methods
        
        function obj = ImageVsIntensityFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;            
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            
            obj.summaryData.imageResponses = [];
            obj.summaryData.linearResponses = [];

            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;

            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'Response to image');
            ylabel(obj.axesHandle, 'Response to linear equivalent');
            title(obj.axesHandle,'Image -vs- Linear equivalent stimulus');
        end

        
        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            imagePatchIndex = epoch.parameters('imagePatchIndex');
            stimulusTag = epoch.parameters('stimulusTag');
            
            if strcmp(obj.recordingType,'extracellular') %spike recording
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                newEpochResponse = length(S.sp); %spike count
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:sampleRate*obj.preTime/1000)); %baseline
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime)/1000));
                %charge transfer
                if strcmp(obj.recordingType,'exc') %measuring exc
                    chargeMult = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    chargeMult = 1;
                end
                newEpochResponse = chargeMult*trapz(epochResponseTrace(1:sampleRate*obj.stimTime/1000)); %pA*datapoint
                newEpochResponse = newEpochResponse/sampleRate; %pA*sec = pC
            end
            obj.allPatchIndices = cat(1,obj.allPatchIndices,imagePatchIndex);
            obj.allEpochResponses = cat(1,obj.allEpochResponses,newEpochResponse);
            
            if strcmp(stimulusTag,'image')
                %nothing
            elseif strcmp(stimulusTag,'intensity') %update summary data
                tempInds = obj.allPatchIndices(1:2:end);
                imageResps = obj.allEpochResponses(1:2:end);
                linearResps = obj.allEpochResponses(2:2:end);
                unInds = unique(tempInds);
                for uu = 1:length(unInds)
                    pullBinary = (tempInds == unInds(uu));
                    obj.summaryData.imageResponses(uu) = mean(imageResps(pullBinary));
                    obj.summaryData.linearResponses(uu) = mean(linearResps(pullBinary));
                end
            end
            limDown = min([obj.summaryData.imageResponses obj.summaryData.linearResponses]);
            limUp = max([obj.summaryData.imageResponses obj.summaryData.linearResponses]);

            if isempty(obj.lineHandle)
                obj.lineHandle = line(obj.summaryData.imageResponses, obj.summaryData.linearResponses,...
                    'Parent', obj.axesHandle,'Color','k','Marker','o','LineStyle','none');
            else
                set(obj.lineHandle, 'XData', obj.summaryData.imageResponses,...
                    'YData', obj.summaryData.linearResponses);
            end
            if isempty(obj.unityHandle)
                obj.unityHandle = line([limDown limUp] , [limDown limUp],...
                    'Parent', obj.axesHandle,'Color','k','Marker','none','LineStyle','--');
            else
                set(obj.unityHandle, 'XData', [limDown limUp],...
                    'YData', [limDown limUp]);
            end
            
        end
        
    end 
end
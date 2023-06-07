classdef MeanPlusGratingFigure  < symphonyui.core.FigureHandler
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        corrLineHandle
        unityHandle
        
        allEpochResponses
        allWidthIndices
        summaryData
    end
    
    methods
         function obj = MeanPlusGratingFigure(ampDevice, varargin)
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
            obj.summaryData.contrastResponses = [];

            obj.createUi();
         end
         
         function createUi(obj)
            import appbox.*;

            obj.axesHandle(1) = subplot(2,1,1,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(1), 'R(Image)');
            ylabel(obj.axesHandle(1), 'R(Linear) + R(Contrast)');
            title(obj.axesHandle(1),'Full image -vs- decomposed image');
            
            obj.axesHandle(2) = subplot(2,1,2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(2), 'R(Image) - R(Linear)');
            ylabel(obj.axesHandle(2), 'R(spatial contrast)');
            title(obj.axesHandle(2),'Difference correlation with spatial contrast');
            
         end
        
                 function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            barWidthIndex = epoch.parameters('currentBarWidth');
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
            obj.allWidthIndices = cat(1,obj.allWidthIndices,barWidthIndex);
            obj.allEpochResponses = cat(1,obj.allEpochResponses,newEpochResponse);
            
            if strcmp(stimulusTag,'intensity')
                %nothing
            elseif strcmp(stimulusTag,'contrast')
                %nothing
            elseif strcmp(stimulusTag,'image') %update summary data
                tempInds = obj.allWidthIndices(1:3:end);
                linearResps = obj.allEpochResponses(1:3:end);
                contrastResps = obj.allEpochResponses(2:3:end);
                imageResps = obj.allEpochResponses(3:3:end);
                
                unInds = unique(tempInds);
                for uu = 1:length(unInds)
                    pullBinary = (tempInds == unInds(uu));
                    obj.summaryData.linearResponses(uu) = mean(linearResps(pullBinary));
                    obj.summaryData.contrastResponses(uu) = mean(contrastResps(pullBinary));
                    obj.summaryData.imageResponses(uu) = mean(imageResps(pullBinary));
                end
            end
            sumOfDecomposedStimuli = obj.summaryData.linearResponses + obj.summaryData.contrastResponses;
            limDown = min([obj.summaryData.imageResponses sumOfDecomposedStimuli]);
            limUp = max([obj.summaryData.imageResponses sumOfDecomposedStimuli]);

            if isempty(obj.lineHandle)
                obj.lineHandle = line(obj.summaryData.imageResponses, sumOfDecomposedStimuli,...
                    'Parent', obj.axesHandle(1),'Color','k','Marker','o','LineStyle','none');
            else
                set(obj.lineHandle, 'XData', obj.summaryData.imageResponses,...
                    'YData', sumOfDecomposedStimuli);
            end
            if isempty(obj.unityHandle)
                obj.unityHandle = line([limDown limUp] , [limDown limUp],...
                    'Parent', obj.axesHandle(1),'Color','k','Marker','none','LineStyle','--');
            else
                set(obj.unityHandle, 'XData', [limDown limUp],...
                    'YData', [limDown limUp]);
            end
            
            if isempty(obj.corrLineHandle)
                obj.corrLineHandle = line(obj.summaryData.imageResponses - obj.summaryData.linearResponses,...
                    obj.summaryData.contrastResponses,...
                    'Parent', obj.axesHandle(2),'Color','k','Marker','o','LineStyle','none');
            else
                set(obj.corrLineHandle, 'XData', obj.summaryData.imageResponses - obj.summaryData.linearResponses,...
                    'YData', obj.summaryData.contrastResponses);
            end
            
           end
        
    end
    
end


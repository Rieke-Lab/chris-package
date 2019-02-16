classdef ModImageVsIntensityFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        responseDimensions
        recordingType
        preTime
        stimTime
        stimType
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        unityHandle
        
        summaryData
        colorMat
    end
    
    methods
        
        function obj = ModImageVsIntensityFigure(ampDevice, responseDimensions, varargin)
            obj.ampDevice = ampDevice;
            obj.responseDimensions = responseDimensions; %3D response matrix
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('stimType', 'NaturalImage', @(x)ischar(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.stimType = ip.Results.stimType;
            
            %response matrices are (2, image/equiv) x (surround contrast) x (image patch)
            obj.summaryData.responseMatrix = zeros(responseDimensions);
            obj.summaryData.countMatrix = zeros(responseDimensions);
            obj.summaryData.surroundContrast = nan(responseDimensions);
            
            obj.colorMat = edu.washington.riekelab.turner.utils.pmkmp(responseDimensions(2),'CubicYF');

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
            
            %get epoch info to know where to store response in summary data
            if strcmp(obj.stimType,'NaturalImage')
                imagePatchIndex = epoch.parameters('imagePatchIndex');
            elseif strcmp(obj.stimType,'grating')
                imagePatchIndex = 1;
            elseif strcmp(obj.stimType,'SinglePatchMixedSurround')
                imagePatchIndex = 1;
            elseif strcmp(obj.stimType,'NaturalImageMixedSurround')
                imagePatchIndex = epoch.parameters('imagePatchIndex');
            elseif strcmp(obj.stimType,'gratingCorrSurround')
                imagePatchIndex = epoch.parameters('intensityIndex');
            end
            stimulusTag = epoch.parameters('stimulusTag');
            
            if strcmp(stimulusTag,'image')
                stimInd = 1;
            elseif strcmp(stimulusTag,'intensity') %update summary data
                stimInd = 2;
            end
            
            if strcmp(obj.stimType,'SinglePatchMixedSurround')
                surroundIndex = epoch.parameters('imagePatchIndex');
                plotColor = 'k';
            elseif strcmp(obj.stimType,'NaturalImageMixedSurround')
                tempTag = epoch.parameters('surroundTag');
                if strcmp(tempTag,'none')
                    surroundIndex = 1;
                    plotColor = 'k';
                elseif strcmp(tempTag,'nat')
                    surroundIndex = 2;
                    plotColor = 'g';
                elseif strcmp(tempTag,'mixed')
                    surroundIndex = 3;
                    plotColor = 'r';
                end
            elseif strcmp(obj.stimType,'gratingCorrSurround')
                tempTag = epoch.parameters('surroundTag');
                if strcmp(tempTag,'none')
                    surroundIndex = 1;
                    plotColor = 'k';
                elseif strcmp(tempTag,'corr')
                    surroundIndex = 2;
                    plotColor = 'g';
                elseif strcmp(tempTag,'acorr')
                    surroundIndex = 3;
                    plotColor = 'r';
                end
            else %grating mod surround
                
                currentSurroundContrast = epoch.parameters('currentSurroundContrast');
                surroundIndex = find(obj.summaryData.surroundContrast(1,:,imagePatchIndex) == currentSurroundContrast,1);
                if isempty(surroundIndex)
                    surroundIndex = find(isnan(obj.summaryData.surroundContrast(1,:,imagePatchIndex)),1);
                end
                obj.summaryData.surroundContrast(stimInd,surroundIndex,imagePatchIndex) = ...
                currentSurroundContrast;
                plotColor = obj.colorMat(surroundIndex,:);
            end
  
            %process data and pull out epoch response
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
            
            %update summary data...
            obj.summaryData.responseMatrix(stimInd,surroundIndex,imagePatchIndex) = ...
                obj.summaryData.responseMatrix(stimInd,surroundIndex,imagePatchIndex) + newEpochResponse;
            obj.summaryData.countMatrix(stimInd,surroundIndex,imagePatchIndex) = ...
                obj.summaryData.countMatrix(stimInd,surroundIndex,imagePatchIndex) + 1;
            
            
            %plot summary data...
            %data lines:
            meanMatrix = obj.summaryData.responseMatrix ./ obj.summaryData.countMatrix;
            if isempty(obj.lineHandle)
                obj.lineHandle = line(squeeze(meanMatrix(1,surroundIndex,:)),...
                    squeeze(meanMatrix(2,surroundIndex,:)),...
                    'Parent', obj.axesHandle,'Marker','o','LineStyle','none','Color',plotColor);
            elseif surroundIndex > length(obj.lineHandle)
                obj.lineHandle(surroundIndex) = line(squeeze(meanMatrix(1,surroundIndex,:)),...
                    squeeze(meanMatrix(2,surroundIndex,:)),...
                    'Parent', obj.axesHandle,'Marker','o','LineStyle','none','Color',plotColor);
            else
                set(obj.lineHandle(surroundIndex), 'XData', squeeze(meanMatrix(1,surroundIndex,:)),...
                    'YData', squeeze(meanMatrix(2,surroundIndex,:)),'Color',plotColor);
            end
            %unity line:
            limDown = min(meanMatrix(:));
            limUp = max(meanMatrix(:));
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
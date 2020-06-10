classdef DovesMoviePlusMeanFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        responseDimensions
        recordingType
        preTime
        stepStartTime
        stepDurTime
        stimTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        unityHandle   
        summaryData
    end
    
    methods
        
        function obj = DovesMoviePlusMeanFigure(ampDevice, responseDimensions, varargin)
            obj.ampDevice = ampDevice;
            obj.responseDimensions = responseDimensions; %3D response matrix
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stepStartTime', [], @(x)isvector(x));
            ip.addParameter('stepDurTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stepStartTime = ip.Results.stepStartTime;
            obj.stepDurTime = ip.Results.stepDurTime;
            obj.stimTime = ip.Results.stimTime;
            %response matrices are (2, image/equiv) x (surround contrast) x (image patch)
            obj.summaryData.responseMatrix = zeros(responseDimensions);
            obj.summaryData.countMatrix = zeros(responseDimensions);
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;

            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'Response to Freeze Trajectory');
            ylabel(obj.axesHandle, 'Response to Flash Insertion');
            title(obj.axesHandle,'Flash-NoFlash Natural Movie');
        end

        
        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            typeIndex=epoch.parameters('typeIndex');
            stimIndex=epoch.parameters('stimulusIndex');

            %process data and pull out epoch response
            if strcmp(obj.recordingType,'extracellular') %spike recording
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime+obj.stepDurTime)/1000));
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                newEpochResponse = length(S.sp); %spike count
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:sampleRate*obj.preTime/1000)); %baseline
                %take (prePts+1:prePts+stimPts)
                epochResponseTrace = epochResponseTrace((sampleRate*obj.preTime/1000)+1:(sampleRate*(obj.preTime + obj.stimTime+obj.stepDurTime)/1000));
                %charge transfer
                if strcmp(obj.recordingType,'exc') %measuring exc
                    chargeMult = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    chargeMult = 1;
                end
                newEpochResponse = chargeMult*trapz(epochResponseTrace(1:sampleRate*obj.stimTime/1000)); %pA*datapoint
                newEpochResponse = newEpochResponse/sampleRate; %pA*sec = pC
            end
            
            if typeIndex==1
                obj.summaryData.responseMatrix(:,typeIndex) =obj.summaryData.responseMatrix(:,typeIndex)+newEpochResponse;
                obj.summaryData.countMatrix(:,typeIndex)=obj.summaryData.countMatrix(:,typeIndex)+1;
            else
                %update summary data...
                obj.summaryData.responseMatrix(stimIndex,typeIndex) = ...
                    obj.summaryData.responseMatrix(stimIndex,typeIndex) + newEpochResponse;
                obj.summaryData.countMatrix(stimIndex,typeIndex)= ...
                    obj.summaryData.countMatrix(stimIndex,typeIndex) + 1;
            end
            %plot summary data...
            %data lines:
            meanMatrix = obj.summaryData.responseMatrix ./ obj.summaryData.countMatrix;
            % subtract the step response 
            meanMatrix(:,2)= meanMatrix(:,2)- meanMatrix(:,1); meanMatrix(:,3)= meanMatrix(:,3)- meanMatrix(:,1);
            if typeIndex>1
                if isempty(obj.lineHandle)
                    obj.lineHandle = line(meanMatrix(stimIndex,3), meanMatrix(stimIndex,2),...
                        'Parent', obj.axesHandle,'Marker','o','LineStyle','none','Color','k');
                else
                  obj.lineHandle(stimIndex) = line(meanMatrix(stimIndex,3), meanMatrix(stimIndex,2),...
                        'Parent', obj.axesHandle,'Marker','o','LineStyle','none','Color','k');
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
end
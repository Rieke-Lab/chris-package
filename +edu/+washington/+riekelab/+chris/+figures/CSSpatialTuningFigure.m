classdef CSSpatialTuningFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
        centerSigmas
        surroundSigmas
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        
        center
        surround
        centerSurround
    end
    
    methods
        
        function obj = CSSpatialTuningFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;            
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('centerSigmas', [], @(x)isvector(x));
            ip.addParameter('surroundSigmas', [], @(x)isvector(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.centerSigmas = ip.Results.centerSigmas;
            obj.surroundSigmas = ip.Results.surroundSigmas;
            
            obj.center.response = zeros(1,length(obj.centerSigmas));
            obj.center.count = zeros(1,length(obj.centerSigmas));
            
            obj.surround.response = zeros(length(obj.surroundSigmas),1);
            obj.surround.count = zeros(length(obj.surroundSigmas),1);
            
            obj.centerSurround.response = zeros(length(obj.surroundSigmas),length(obj.centerSigmas));
            obj.centerSurround.count = zeros(length(obj.surroundSigmas),length(obj.centerSigmas));

            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            
            obj.axesHandle(1) = subplot(3,1,1,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(1), 'Sigma (microns)');
            ylabel(obj.axesHandle(1), 'Response');
            title(obj.axesHandle(1), 'Center alone');
            
            obj.axesHandle(2) = subplot(3,1,2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(2), 'Sigma (microns)');
            ylabel(obj.axesHandle(2), 'Response');
            title(obj.axesHandle(2), 'Surround alone');

             obj.axesHandle(3) = subplot(3,1,3,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(3), 'Center Sigma (microns)');
            ylabel(obj.axesHandle(3), 'Surround Sigma (microns)');
            zlabel(obj.axesHandle(3), 'Response');
            title(obj.axesHandle(3), 'Center + Surround');

            colors = edu.washington.riekelab.turner.utils.pmkmp(3,'CubicYF');

            obj.lineHandle.center = line(0, 0,...
                'Parent', obj.axesHandle(1),'Color',colors(1,:),'Marker','o','LineStyle','-');
            obj.lineHandle.surround = line(0, 0,...
                'Parent', obj.axesHandle(2),'Color',colors(2,:),'Marker','o','LineStyle','-');
            obj.lineHandle.centerSurround = imagesc(0, 0, 0, 'Parent',obj.axesHandle(3));
            colormap(obj.axesHandle(3),gray);
        end

        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            currentStimulus = epoch.parameters('currentStimulus');
            currentCenterSigma = epoch.parameters('currentCenterSigma');
            currentSurroundSigma = epoch.parameters('currentSurroundSigma');
            centerInd = find(currentCenterSigma == obj.centerSigmas);
            surroundInd = find(currentSurroundSigma == obj.surroundSigmas);
            
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

            if strcmp(currentStimulus,'Center')
                obj.center.count(centerInd) = obj.center.count(centerInd) + 1;
                obj.center.response(centerInd) = obj.center.response(centerInd) + newEpochResponse;
                                
                set(obj.lineHandle.center, 'XData', obj.centerSigmas,...
                    'YData', obj.center.response ./ obj.center.count);
            elseif strcmp(currentStimulus,'Surround')
                obj.surround.count(surroundInd) = obj.surround.count(surroundInd) + 1;
                obj.surround.response(surroundInd) = obj.surround.response(surroundInd) + newEpochResponse;
                                
                set(obj.lineHandle.surround, 'XData', obj.surroundSigmas,...
                    'YData', obj.surround.response ./ obj.surround.count);
            elseif  strcmp(currentStimulus,'Center-Surround')
                obj.centerSurround.count(surroundInd,centerInd) = ...
                    obj.centerSurround.count(surroundInd,centerInd) + 1;
                obj.centerSurround.response(surroundInd,centerInd) = ...
                    obj.centerSurround.response(surroundInd,centerInd) + newEpochResponse;

                obj.lineHandle.centerSurround = imagesc(obj.centerSigmas, obj.surroundSigmas,...
                    obj.centerSurround.response ./ obj.centerSurround.count,...
                    'Parent',obj.axesHandle(3));
            end
        end
        
    end 
end
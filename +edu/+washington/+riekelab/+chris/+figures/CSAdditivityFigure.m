classdef CSAdditivityFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        tailTime
        stimulusIndex
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        
        resp
        count
    end
    
    methods
        
        function obj = CSAdditivityFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;            
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('tailTime', [], @(x)isvector(x));
            ip.addParameter('stimulusIndex', [], @(x)isvector(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.tailTime = ip.Results.tailTime;
            obj.stimulusIndex = ip.Results.stimulusIndex;
            
            obj.resp.center = 0;
            obj.resp.surround = 0;
            obj.resp.centerSurround = 0;
            
            obj.count.center = 0;
            obj.count.surround = 0;
            obj.count.centerSurround = 0;

            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            
            obj.axesHandle(1) = subplot(3,1,1,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(1), 'Time (sec)');
            ylabel(obj.axesHandle(1), 'Intensity');

            obj.axesHandle(2) = subplot(3,1,2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            ylabel(obj.axesHandle(2), 'Resp');
            title(obj.axesHandle(2), 'Center, surround');

            obj.axesHandle(3) = subplot(3,1,3,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(3), 'Time (sec)');
            ylabel(obj.axesHandle(3), 'Resp');
            title(obj.axesHandle(3), 'Center + Surround');

            colors = edu.washington.riekelab.turner.utils.pmkmp(3,'CubicYF');
            %load data and get luminance trajectories
            resourcesDir = 'C:\Users\Public\Documents\turner-package\resources\';
            currentStimSet = 'SaccadeLuminanceTrajectoryStimuli_20160919.mat';
            load([resourcesDir, currentStimSet]);
            centerTrajectory = luminanceData(obj.stimulusIndex).centerTrajectory ...
                 ./ luminanceData(obj.stimulusIndex).ImageMax;
            surroundTrajectory = luminanceData(obj.stimulusIndex).surroundTrajectory ...
                 ./ luminanceData(obj.stimulusIndex).ImageMax;
            prePts = (obj.preTime / 1000) * 200;
            tailPts = (obj.tailTime / 1000) * 200;
            timeTraj = (1:(prePts + length(centerTrajectory) + tailPts)) / 200; %sec

            backgroundIntensity = luminanceData(obj.stimulusIndex).ImageMean /...
                luminanceData(obj.stimulusIndex).ImageMax;
            
            centerTrajectory = [backgroundIntensity .* ones(1,prePts),...
                centerTrajectory,...
                backgroundIntensity .* ones(1,tailPts)];
            surroundTrajectory = [backgroundIntensity .* ones(1,prePts),...
                surroundTrajectory,...
                backgroundIntensity .* ones(1,tailPts)];
            
            line(timeTraj, centerTrajectory,...
                'Parent', obj.axesHandle(1),'Color',colors(1,:),'Marker','none','LineStyle','-');
            line(timeTraj, surroundTrajectory,...
                'Parent', obj.axesHandle(1),'Color',colors(2,:),'Marker','none','LineStyle','-');
            line([timeTraj(1) timeTraj(end)], [backgroundIntensity backgroundIntensity],...
                'Parent', obj.axesHandle(1),'Color','k','Marker','none','LineStyle','--');
            
            obj.lineHandle.center = line(0, 0,...
                'Parent', obj.axesHandle(2),'Color',colors(1,:),'Marker','none','LineStyle','-');
            obj.lineHandle.surround = line(0, 0,...
                'Parent', obj.axesHandle(2),'Color',colors(2,:),'Marker','none','LineStyle','-');
            obj.lineHandle.centerSurround = line(0, 0,...
                'Parent', obj.axesHandle(3),'Color',colors(3,:),'Marker','none','LineStyle','-');
            obj.lineHandle.linSum = line(0, 0,...
                'Parent', obj.axesHandle(3),'Color','k','Marker','none','LineStyle','-');
        end

        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            stimulusTag = epoch.parameters('currentStimulus');
            
            if strcmp(obj.recordingType,'extracellular') %spike recording
                filterSigma = (15/1000)*sampleRate; %15 msec -> dataPts
                newFilt = normpdf(1:10*filterSigma,10*filterSigma/2,filterSigma);
                %count spikes
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                newEpochResponse = zeros(size(epochResponseTrace));
                newEpochResponse(S.sp) = 1; %spike binary
                newEpochResponse = sampleRate*conv(newEpochResponse,newFilt,'same'); %inst firing rate, Hz
            else %intracellular - Vclamp
                newEpochResponse = epochResponseTrace-mean(epochResponseTrace(1:sampleRate*obj.preTime/1000)); %baseline
            end
            
            timeVector = (1:length(newEpochResponse)) / sampleRate;
            if strcmp(stimulusTag,'Center')
                obj.count.center = obj.count.center + 1;
                obj.resp.center = obj.resp.center + newEpochResponse;
                
                set(obj.lineHandle.center, 'XData', timeVector,...
                    'YData', obj.resp.center ./ obj.count.center);
            elseif strcmp(stimulusTag,'Surround')
                obj.count.surround = obj.count.surround + 1;
                obj.resp.surround = obj.resp.surround + newEpochResponse;
                
                set(obj.lineHandle.surround, 'XData', timeVector,...
                    'YData', obj.resp.surround ./ obj.count.surround);
            elseif  strcmp(stimulusTag,'Center-Surround')
                obj.count.centerSurround = obj.count.centerSurround + 1;
                obj.resp.centerSurround = obj.resp.centerSurround + newEpochResponse;
                
                set(obj.lineHandle.centerSurround, 'XData', timeVector,...
                    'YData', obj.resp.centerSurround ./ obj.count.centerSurround);
                
                set(obj.lineHandle.linSum, 'XData', timeVector,...
                    'YData', (obj.resp.center ./ obj.count.center) + (obj.resp.surround ./ obj.count.surround));
            end
        end
        
    end 
end
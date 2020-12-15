classdef FlashedGrateVsIntensityFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
        barWidth
        eqvContrast
        tags
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        unityHandle
        summaryData
    end
    
    methods
        
        function obj = FlashedGrateVsIntensityFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;            
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('barWidth', [], @(x)isvector(x));
            ip.addParameter('eqvContrast', [], @(x)isvector(x));
            ip.addParameter('tags', [], @(x)iscellstr(x) || isvector(x));

            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.barWidth=ip.Results.barWidth;
            obj.eqvContrast=ip.Results.eqvContrast;
            obj.tags=ip.Results.tags;

            obj.summaryData.resp=zeros(numel(obj.barWidth),numel(obj.eqvContrast), numel(obj.tags));
            obj.summaryData.count=zeros(numel(obj.barWidth),numel(obj.eqvContrast), numel(obj.tags));
            
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            for i=1:length(obj.barWidth)
                obj.axesHandle(i) = subplot(1, ceil(length(obj.barWidth)),i, ...
                    'Parent', obj.figureHandle, ...
                    'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto');
                title(obj.axesHandle(i),strcat('barWidth ','::', num2str(obj.barWidth(i))));
                
                xlabel(obj.axesHandle(i), 'Response to grating');
                ylabel(obj.axesHandle(i), 'Response to linear equivalent');
                if strcmp(obj.recordingType,'extracellular')
                    ylabel(obj.axesHandle(i), 'spikeRate(Hz)');
                else
                    ylabel(obj.axesHandle(i), 'PSC(pA)');
                end
                for j=1:numel(obj.eqvContrast)
                    obj.lineHandle(i,j)=line(0, 0,...
                    'Parent', obj.axesHandle(i),'Color','k','Marker','o','LineStyle','none');
                end
                obj.unityHandle(i) = line([0 0] , [1 1],...
                    'Parent', obj.axesHandle(i),'Color','r','Marker','none','LineStyle','--');
            end
        end 
        
        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            currentEqvContrast=epoch.parameters('currentEqvContrast');
            currentBarWidth=epoch.parameters('currentBarWidth');
            stimulusTag = epoch.parameters('currentStimulusTag');
            barInd=find(currentBarWidth==obj.barWidth);
            contrastInd=find(currentEqvContrast==obj.eqvContrast);
            switch stimulusTag
                case 'grate'
                    tagInd=1;
                case 'disc'
                    tagInd=2;
            end
                    
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
            obj.summaryData.resp(barInd, contrastInd, tagInd)= obj.summaryData.resp(barInd, contrastInd, tagInd)+newEpochResponse;
            obj.summaryData.count(barInd, contrastInd, tagInd)= obj.summaryData.count(barInd, contrastInd, tagInd)+1;
      
            limDown = min(obj.summaryData.resp(:)./obj.summaryData.count(:));
            limUp = max(obj.summaryData.resp(:)./obj.summaryData.count(:));
            
            set(obj.lineHandle(barInd,contrastInd),'XData',obj.summaryData.resp(barInd, contrastInd, 1)./ ...,
                obj.summaryData.count(barInd, contrastInd, 1),'YData', obj.summaryData.resp(barInd, contrastInd, 2)./ ...,
                obj.summaryData.count(barInd, contrastInd, 2));
            set(obj.unityHandle(barInd), 'XData', [limDown limUp],...
                'YData', [limDown limUp]);
        end
        
    end 
end
classdef motionFigureSets < symphonyui.core.FigureHandler
    properties (SetAccess = private)
        device
        psth
        preTime
        stimTime
        barWidthList
        dirList
    end
    
    properties (Access = private)
        axesHandle
        resp
    end
    
    methods
        function obj = motionFigureSets(device, varargin)
            ip = inputParser();
            ip.addParameter('psth', true, @(x)islogical(x));
            ip.addParameter('preTime',0.0, @(x)isfloat(x));
            ip.addParameter('stimTime',0.0, @(x)isfloat(x));
            ip.addParameter('barWidthList', [], @(x)isvector(x));
            ip.parse(varargin{:});
            
            obj.device = device;
            obj.psth = ip.Results.psth;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.barWidthList=ip.Results.barWidthList;
            
            for i=1:length(obj.barWidthList)
                for j=1:length(obj.dirList) % number of color groups in each plot
                    obj.resp.mean(i,j)=0;
                    obj.resp.count(i,j)=0;
                end
            end
            
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.barWidthList),'CubicYF');
            
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            lineLegends=cell(1,numel(obj.barWidthList));
            for i=1:length(obj.barWidthList)
                obj.lineHandle(i)=line(0,0,'Parent', obj.axesHandle, ...,
                    'Colors',colors(i,:),'marker','none','linestyle','-');
                lineLegends{i}=['Bar width' '  ' num2str(obj.barWidthList(i))];
            end
            % for each subplot, add legend, weel this is not a neat code
            legend( obj.lineHandle,lineLegends); legend boxoff;
        end
        
        function handleEpoch(obj, epoch)
            currentDir=epoch.parameters('currentDir');
            currentBarWidth=epoch.parameters('currentBarWidth');
            %%%%%%%%%%%
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = sampleRate*obj.preTime/1000;
            stimPts = sampleRate*obj.stimTime/1000;
            preScaleFactor = stimPts / prePts;
            
            if obj.psth
                epochResponseTrace = epochResponseTrace(1:prePts+stimPts);
                %count spikes
                S = edu.washington.riekelab.chris.utils.spikeDetectorOnline(epochResponseTrace);
                newEpochResponse = sum(S.sp > prePts); %spike count during stim
                newBaseline = preScaleFactor * sum(S.sp < prePts); %spike count before stim, scaled by length
            else
                if mean(epochResponseTrace)<0  %measuring exc
                    chargeMult = -1;
                elseif  mean(epochResponseTrace)>0%measuring inh
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
            
            %%%% sort each epoch accordingly
            %%%% sort each epoch accordingly
            dirIndex=find(currentDir== obj.dirList);
            barIndex=find(currentBarWidth==obj.barWidthList);            
            obj.resp.count(barIndex,dirIndex)=obj.resp.count(barIndex,dirIndex)+1;
            obj.resp.mean(barIndex,dirIndex)=obj.resp.mean(barIndex,dirIndex)+newEpochResponse-newBaseline;    
            set(obj.lineHandle(barIndex), 'XData', deg2rad(obj.dirList),...
                'YData', obj.resp.mean(barIndex,:)./obj.resp.count(barIndex,:));
        end
    end
end

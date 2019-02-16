classdef CycleAverageFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        device
        groupBy
        sweepColor
        recordingType
        storedSweepColor
        temporalFrequency
        preTime
        stimTime
    end
    
    properties (Access = private)
        axesHandle
        sweeps
        sweepIndex
        storedSweep
        baselineSubtractedFlag
    end
    
    methods
        
        function obj = CycleAverageFigure(device, varargin)
            co = get(groot, 'defaultAxesColorOrder');

            ip = inputParser();
            ip.addParameter('groupBy', [], @(x)iscellstr(x));
            ip.addParameter('sweepColor', co(1,:), @(x)ischar(x) || ismatrix(x));
            ip.addParameter('storedSweepColor', 'r', @(x)ischar(x) || isvector(x));
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('temporalFrequency', [], @(x)isvector(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.parse(varargin{:});
            
            obj.device = device;
            obj.groupBy = ip.Results.groupBy;
            obj.sweepColor = ip.Results.sweepColor;
            obj.storedSweepColor = ip.Results.storedSweepColor;
            obj.recordingType = ip.Results.recordingType;
            obj.temporalFrequency = ip.Results.temporalFrequency;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.baselineSubtractedFlag = 0;
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+utils\+icons\'];
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            storeSweepButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Store Sweep', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedStoreSweep);
            setIconImage(storeSweepButton, symphonyui.app.App.getResource('icons/sweep_store.png'));
            
            clearStoredButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Clear saved sweep', ...
                'Separator', 'off', ...
                'ClickedCallback', @obj.onSelectedClearStored);
            setIconImage(clearStoredButton, [iconDir, 'Xout.png']);
            
            subtractBaselineButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Toggle baseline subtraction', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedSubtractBaseline);
            setIconImage(subtractBaselineButton, [iconDir, 'sine.png']);
            
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'sec');
            obj.sweeps = {};
            obj.setTitle([obj.device.name ' Cycle average']);
        end
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axesHandle, t);
        end
        
        function clear(obj)
            cla(obj.axesHandle);
            obj.sweeps = {};
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
            response = epoch.getResponse(obj.device);
            [quantities, units] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            if numel(quantities) > 0
                y = quantities;
                
                if strcmp(obj.recordingType,'extracellular')
                    filterSigma = (15/1000)*sampleRate; %15 msec -> dataPts
                    newFilt = normpdf(1:10*filterSigma,10*filterSigma/2,filterSigma);
                    res = edu.washington.riekelab.turner.utils.spikeDetectorOnline(y,[],sampleRate);
                    y = zeros(size(y));
                    y(res.sp) = 1; %spike binary
                    y = sampleRate*conv(y,newFilt,'same'); %inst firing rate, Hz
                else
                    %analog; Baseline subtract
                    y = y - mean(y(1:(sampleRate*obj.preTime/1000)));
                end
                
                noCycles = floor(obj.temporalFrequency*obj.stimTime/1000);
                period = (1/obj.temporalFrequency)*sampleRate; %data points
                y(1:(sampleRate*obj.preTime/1000)) = []; %cut out prePts
                cycleAvgResp = 0;
                for c = 2:noCycles %SKIP FIRST CYCLE
                    cycleAvgResp = cycleAvgResp + y((c-1)*period+1:c*period);
                end
                y = cycleAvgResp./(noCycles-1);
                x = (1:length(cycleAvgResp))./sampleRate; %sec
                
            else
                x = [];
                y = [];
            end
            
            p = epoch.parameters;
            if isempty(obj.groupBy) && isnumeric(obj.groupBy)
                parameters = p;
            else
                parameters = containers.Map();
                for i = 1:length(obj.groupBy)
                    key = obj.groupBy{i};
                    parameters(key) = p(key);
                end
            end
            
            if isempty(parameters)
                t = 'All epochs grouped together';
            else
                t = ['Grouped by ' strjoin(parameters.keys, ', ')];
            end
            obj.setTitle([obj.device.name ' Cycle Average (' t ')']);
            
            obj.sweepIndex = [];
            for i = 1:numel(obj.sweeps)
                if isequal(obj.sweeps{i}.parameters, parameters)
                    obj.sweepIndex = i;
                    break;
                end
            end

            if isempty(obj.sweepIndex)
                if size(obj.sweepColor,1) == 1
                    cInd = 1;
                else
                    cInd = length(obj.sweeps)+1;
                end
                if (~isempty(obj.sweeps)) && (obj.baselineSubtractedFlag)
                    baseline = get(obj.sweeps{1}.line, 'YData');
                    y = y - baseline;
                end

                sweep.line = line(x, y, 'Parent', obj.axesHandle,...
                    'Color', obj.sweepColor(cInd,:));
                sweep.parameters = parameters;
                obj.sweeps{end + 1} = sweep; %new sweep
            else
                sweep = obj.sweeps{obj.sweepIndex};
                if (obj.sweepIndex == 1)
                    for ss = 2:numel(obj.sweeps)
                        set(obj.sweeps{ss}.line, 'Visible', 'off');
                    end
                elseif (obj.sweepIndex > 1) && (obj.baselineSubtractedFlag)
                   baseline = get(obj.sweeps{1}.line, 'YData');
                   y = y - baseline;
                end
                set(sweep.line, 'YData', y);
                set(sweep.line, 'Visible', 'on');
                obj.sweeps{obj.sweepIndex} = sweep;
            end
            
            %check for stored data to plot...
            storedData = obj.storedAverages();
            if ~isempty(storedData)
                if ~isempty(obj.storedSweep) %Handle still there
                    if obj.storedSweep.line.isvalid %Line still there
                        
                    else
                        obj.storedSweep.line = line(storedData(1,:), storedData(2,:),...
                        'Parent', obj.axesHandle, 'Color', obj.storedSweepColor);
                    end                 
                else %no handle
                    obj.storedSweep.line = line(storedData(1,:), storedData(2,:),...
                        'Parent', obj.axesHandle, 'Color', obj.storedSweepColor);
                end
            end

            ylabel(obj.axesHandle, units, 'Interpreter', 'none');
        end
        
    end
    
    methods (Access = private)
        
        function onSelectedStoreSweep(obj, ~, ~)
            if isempty(obj.sweepIndex)
                sweepPull = 1;
            else
                sweepPull = obj.sweepIndex;
            end
            if ~isempty(obj.storedSweep) %Handle still there
                if obj.storedSweep.line.isvalid %Line still there
                    %delete the old storedSweep
                    obj.onSelectedClearStored(obj)
                end
            end
            
            %save out stored data
            obj.storedSweep.line = obj.sweeps{sweepPull}.line;
            obj.storedAverages([obj.storedSweep.line.XData; obj.storedSweep.line.YData]);
            %set the saved trace to storedSweepColor to indicate that it has been saved
            obj.storedSweep.line = line(obj.storedSweep.line.XData, obj.storedSweep.line.YData,...
                        'Parent', obj.axesHandle, 'Color', obj.storedSweepColor);
        end

        function onSelectedClearStored(obj, ~, ~)
            obj.storedAverages('Clear');
            obj.storedSweep.line.delete
        end
        
        function onSelectedSubtractBaseline(obj, ~, ~)
            baseline = get(obj.sweeps{1}.line, 'YData');
            if (obj.baselineSubtractedFlag == 0)
                for ss = 2:numel(obj.sweeps)
                    sweep = obj.sweeps{ss};
                    cy = get(sweep.line, 'YData');
                    set(sweep.line, 'YData', cy - baseline);
                    obj.sweeps{ss} = sweep;
                end
            elseif (obj.baselineSubtractedFlag == 1)
                for ss = 2:numel(obj.sweeps)
                    sweep = obj.sweeps{ss};
                    cy = get(sweep.line, 'YData');
                    set(sweep.line, 'YData', cy + baseline);
                    obj.sweeps{ss} = sweep;
                end
            end
            obj.baselineSubtractedFlag = ~obj.baselineSubtractedFlag;
        end

    end
    
    methods (Static)

        function averages = storedAverages(averages)
            % This method stores means across figure handlers.
            persistent stored;
            if (nargin == 0) %retrieve stored data
               averages = stored;
            else %set or clear stored data
                if strcmp(averages,'Clear')
                    stored = [];
                else
                    stored = averages;
                    averages = stored;
                end
            end
        end
    end
        
end


classdef ModF2Figure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
        flashDelay
        flashDuration
        temporalFrequency
        figureTitle
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        F1amplitudes
        F2amplitudes
    end
    
    methods
        
        function obj = ModF2Figure(ampDevice, varargin)
            obj.ampDevice = ampDevice;
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', 100, @(x)isvector(x));
            ip.addParameter('stimTime', 1000, @(x)isvector(x));
            ip.addParameter('flashDelay', 500, @(x)isvector(x));
            ip.addParameter('flashDuration', 100, @(x)isvector(x));
            ip.addParameter('temporalFrequency', 10, @(x)isvector(x));
            ip.addParameter('figureTitle','F2:F1 disruption', @(x)ischar(x));
            ip.parse(varargin{:});
            
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.flashDelay = ip.Results.flashDelay;
            obj.flashDuration = ip.Results.flashDuration;
            obj.temporalFrequency = ip.Results.temporalFrequency;
            obj.figureTitle = ip.Results.figureTitle;

            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;
            obj.axesHandle(1) = subplot(2,1,1,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(1), 'Time (s)');
            ylabel(obj.axesHandle(1), 'Amplitude');
            title(obj.axesHandle(1),'F1 & F2');
            
            obj.axesHandle(2) = subplot(2,1,2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(2), 'Time (s)');
            ylabel(obj.axesHandle(2), 'F2/F1');
            obj.figureHandle.Name = obj.figureTitle;
            obj.lineHandle = cell(1,3);
        end

        function handleEpoch(obj, epoch)
            %load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = sampleRate*obj.preTime/1000;
            if strcmp(obj.recordingType,'extracellular') %spike recording
                filterSigma = (10/1000)*sampleRate; %msec -> dataPts
                newFilt = normpdf(1:10*filterSigma,10*filterSigma/2,filterSigma);
                res = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace,[],sampleRate);
                newResponse = zeros(size(epochResponseTrace));
                newResponse(res.sp) = 1; %spike binary
                newResponse = sampleRate*conv(newResponse,newFilt,'same'); %inst firing rate
            else %intracellular - Vclamp
                epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:prePts)); %baseline
                if strcmp(obj.recordingType,'exc') %measuring exc
                    polarity = -1;
                elseif strcmp(obj.recordingType,'inh') %measuring inh
                    polarity = 1;
                end
                newResponse = polarity * epochResponseTrace;
            end
            
            onsetDelay = (100/1000) * sampleRate; %msec -> data points
            noCycles = floor(obj.temporalFrequency*obj.stimTime/1000);
            period = round((1/obj.temporalFrequency)*sampleRate); %data points
            newResponse(1:(sampleRate*obj.preTime/1000)) = []; %cut out prePts
            
            %fit a sine to each cycle and pull out amplitude
            if strcmp(epoch.parameters('currentStimulus'),'FullField')
                %Measure F1 amplitude
                tF = obj.temporalFrequency;
            elseif strcmp(epoch.parameters('currentStimulus'),'SplitField')
                %Measure F2 amplitude
                tF = 2 .* obj.temporalFrequency;
            end
            % b(1) is amplitude. Freq is fixed. Offset & phase allowed to
            % vary
            modelFun = @(b,t)(b(1).*(sin(2*pi*t.*tF + b(2))) + b(3));
            timeVec = (0:(period-1)) ./ sampleRate; %sec
            newAmp = zeros(1,noCycles);
            for c = 1:noCycles
                startPt = onsetDelay + (c-1)*period + 1;
                endPt = startPt + period - 1;
                currentChunk = newResponse(startPt:endPt);
                beta0 = [max(currentChunk);0;0];
                beta = nlinfit(timeVec,currentChunk,modelFun,beta0);
                newAmp(c) = abs(beta(1));
            end
            if strcmp(epoch.parameters('currentStimulus'),'FullField')
                obj.F1amplitudes = cat(1,obj.F1amplitudes,newAmp);
                timeVector = (1:size(obj.F1amplitudes,2)) .* 1/obj.temporalFrequency; %sec
                if isempty(obj.lineHandle{1})
                    obj.lineHandle{1} = line(timeVector, mean(obj.F1amplitudes,1),...
                    'Parent', obj.axesHandle(1),'LineWidth',2,'Color','k');
                else
                    set(obj.lineHandle{1}, 'YData', mean(obj.F1amplitudes,1));
                end
            elseif strcmp(epoch.parameters('currentStimulus'),'SplitField')
                obj.F2amplitudes = cat(1,obj.F2amplitudes,newAmp);
                timeVector = (1:size(obj.F1amplitudes,2)) .* 1/obj.temporalFrequency; %sec
                if isempty(obj.lineHandle{2})
                    obj.lineHandle{2} = line(timeVector, mean(obj.F2amplitudes,1),...
                    'Parent', obj.axesHandle(1),'LineWidth',2,'Color','r');
                else
                    set(obj.lineHandle{2}, 'YData', mean(obj.F2amplitudes,1));
                end
                
                F2F1ratio = mean(obj.F2amplitudes,1) ./ mean(obj.F1amplitudes,1);
                if isempty(obj.lineHandle{3})
                    obj.lineHandle{3} = line(timeVector, F2F1ratio,...
                    'Parent', obj.axesHandle(2),'LineWidth',2,'Color','k');
                else
                    set(obj.lineHandle{3}, 'YData', F2F1ratio);
                end
            end
        end
    end
end


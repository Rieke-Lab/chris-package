classdef ImageVsIntensityConeLinFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        recordingType
        preTime
        stimTime
    end
    
    properties (Access = private)
        axesHandle
        lineHandleLinear
        lineHandleConeLin
        unityHandle
        legendHandle
        
        patchData
    end
    
    methods
        
        function obj = ImageVsIntensityConeLinFigure(ampDevice, varargin)
            obj.ampDevice = ampDevice;
            
            ip = inputParser();
            ip.addParameter('recordingType', 'none', @(x)ischar(x));
            ip.addParameter('preTime', 0, @(x)isnumeric(x) && isscalar(x));
            ip.addParameter('stimTime', 0, @(x)isnumeric(x) && isscalar(x));
            ip.parse(varargin{:});
            
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            
            obj.patchData = struct();

            obj.createUi();
        end
        
        function createUi(obj)
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'Response to image');
            ylabel(obj.axesHandle, 'Response to equivalent disc');
            title(obj.axesHandle, 'Image vs standard/cone-linearized equivalent disc');
            hold(obj.axesHandle, 'on');
            axis(obj.axesHandle, 'square');
        end
        
        function handleEpoch(obj, epoch)
            % load amp data
            response = epoch.getResponse(obj.ampDevice);
            epochResponseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            imagePatchIndex = epoch.parameters('imagePatchIndex');
            stimulusTag = epoch.parameters('stimulusTag');
            
            newEpochResponse = obj.getEpochMetric(epochResponseTrace, sampleRate);

            fieldName = sprintf('patch_%d', imagePatchIndex);
            if ~isfield(obj.patchData, fieldName)
                obj.patchData.(fieldName) = struct( ...
                    'image', [], ...
                    'intensity', [], ...
                    'linConeIntensity', []);
            end

            switch stimulusTag
                case 'image'
                    obj.patchData.(fieldName).image(end+1) = newEpochResponse;
                case 'intensity'
                    obj.patchData.(fieldName).intensity(end+1) = newEpochResponse;
                case 'lin cone intensity'
                    obj.patchData.(fieldName).linConeIntensity(end+1) = newEpochResponse;
                otherwise
                    error('Unknown stimulusTag: %s', stimulusTag);
            end
            
            [imageLinearX, imageLinearY, imageConeX, imageConeY] = obj.buildSummary();

            allVals = [imageLinearX, imageLinearY, imageConeX, imageConeY];
            if isempty(allVals)
                limDown = 0;
                limUp = 1;
            else
                limDown = min(allVals);
                limUp = max(allVals);
                if limDown == limUp
                    limDown = limDown - 1;
                    limUp = limUp + 1;
                end
            end

            if isempty(obj.lineHandleLinear) || ~isvalid(obj.lineHandleLinear)
                obj.lineHandleLinear = line( ...
                    imageLinearX, imageLinearY, ...
                    'Parent', obj.axesHandle, ...
                    'Color', 'k', ...
                    'Marker', 'o', ...
                    'LineStyle', 'none', ...
                    'DisplayName', 'standard disc');
            else
                set(obj.lineHandleLinear, 'XData', imageLinearX, 'YData', imageLinearY);
            end

            if isempty(obj.lineHandleConeLin) || ~isvalid(obj.lineHandleConeLin)
                obj.lineHandleConeLin = line( ...
                    imageConeX, imageConeY, ...
                    'Parent', obj.axesHandle, ...
                    'Color', 'r', ...
                    'Marker', 'o', ...
                    'LineStyle', 'none', ...
                    'DisplayName', 'cone-linearized disc');
            else
                set(obj.lineHandleConeLin, 'XData', imageConeX, 'YData', imageConeY);
            end

            if isempty(obj.unityHandle) || ~isvalid(obj.unityHandle)
                obj.unityHandle = line( ...
                    [limDown limUp], [limDown limUp], ...
                    'Parent', obj.axesHandle, ...
                    'Color', 'k', ...
                    'LineStyle', '--', ...
                    'DisplayName', 'unity');
            else
                set(obj.unityHandle, 'XData', [limDown limUp], 'YData', [limDown limUp]);
            end
            
            xlim(obj.axesHandle, [limDown limUp]);
            ylim(obj.axesHandle, [limDown limUp]);

            if isempty(obj.legendHandle) || ~isvalid(obj.legendHandle)
                obj.legendHandle = legend(obj.axesHandle, 'show');
                obj.legendHandle.Location = 'best';
            end
        end
        
    end

    methods (Access = private)
        
        function newEpochResponse = getEpochMetric(obj, epochResponseTrace, sampleRate)
            prePts = round(sampleRate * obj.preTime / 1000);
            stimPts = round(sampleRate * obj.stimTime / 1000);

            if strcmp(obj.recordingType, 'extracellular')
                epochResponseTrace = epochResponseTrace(prePts+1 : prePts+stimPts);
                S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                newEpochResponse = length(S.sp);
            else
                epochResponseTrace = epochResponseTrace - mean(epochResponseTrace(1:prePts));
                epochResponseTrace = epochResponseTrace(prePts+1 : prePts+stimPts);

                if strcmp(obj.recordingType, 'exc')
                    chargeMult = -1;
                elseif strcmp(obj.recordingType, 'inh')
                    chargeMult = 1;
                else
                    error('Unsupported recordingType: %s', obj.recordingType);
                end

                newEpochResponse = chargeMult * trapz(epochResponseTrace);
                newEpochResponse = newEpochResponse / sampleRate;
            end
        end
        
        function [imageLinearX, imageLinearY, imageConeX, imageConeY] = buildSummary(obj)
            imageLinearX = [];
            imageLinearY = [];
            imageConeX = [];
            imageConeY = [];

            patchNames = fieldnames(obj.patchData);
            for i = 1:numel(patchNames)
                d = obj.patchData.(patchNames{i});

                if ~isempty(d.image) && ~isempty(d.intensity)
                    imageLinearX(end+1) = mean(d.image);
                    imageLinearY(end+1) = mean(d.intensity);
                end

                if ~isempty(d.image) && ~isempty(d.linConeIntensity)
                    imageConeX(end+1) = mean(d.image);
                    imageConeY(end+1) = mean(d.linConeIntensity);
                end
            end
        end
        
    end 
end
classdef LMConeNoiseTraceFigure < symphonyui.core.FigureHandler
    % LMConeNoiseTraceFigure
    %
    % Reconstructs one example epoch per stimulus type from stored seeds.
    % Row 1: intended and delivered L/M isomerization trajectories.
    % Row 2: raw red/green gun values plus clipped delivered values.
    % Row 3: combined L/M drive, usually (L + M) / 2.
    %
    % Compatible with MATLAB R2016b.

    properties (SetAccess = private)
        stageDevice
        preTime
        stimTime
        frameDwell
        meanLIsom
        meanMIsom
        LNoiseContrast
        MNoiseContrast
        rgToLm
        maxToleratedClipFraction
        lmDriveMode
    end

    properties (Access = private)
        plottedTypes
    end

    methods
        function obj = LMConeNoiseTraceFigure(stageDevice, varargin)
            obj.stageDevice = stageDevice;

            ip = inputParser();
            ip.addParameter('preTime', 500,        @(x)isnumeric(x));
            ip.addParameter('stimTime', 8000,      @(x)isnumeric(x));
            ip.addParameter('frameDwell', 2,       @(x)isnumeric(x));

            % Legacy parameter. If separate means are not supplied, both use this.
            ip.addParameter('meanIsom', 15000,     @(x)isnumeric(x));
            ip.addParameter('meanLIsom', [],       @(x)isnumeric(x) || isempty(x));
            ip.addParameter('meanMIsom', [],       @(x)isnumeric(x) || isempty(x));

            ip.addParameter('LNoiseContrast', 0.3, @(x)isnumeric(x));
            ip.addParameter('MNoiseContrast', 0.3, @(x)isnumeric(x));
            ip.addParameter('rgToLm', eye(2),      @(x)isnumeric(x) && isequal(size(x), [2,2]));
            ip.addParameter('maxToleratedClipFraction', 0.10, @(x)isnumeric(x));
            ip.addParameter('lmDriveMode', 'mean', @(x)ischar(x));
            ip.parse(varargin{:});

            obj.preTime        = ip.Results.preTime;
            obj.stimTime       = ip.Results.stimTime;
            obj.frameDwell     = ip.Results.frameDwell;

            if isempty(ip.Results.meanLIsom)
                obj.meanLIsom = ip.Results.meanIsom;
            else
                obj.meanLIsom = ip.Results.meanLIsom;
            end
            if isempty(ip.Results.meanMIsom)
                obj.meanMIsom = ip.Results.meanIsom;
            else
                obj.meanMIsom = ip.Results.meanMIsom;
            end

            obj.LNoiseContrast = ip.Results.LNoiseContrast;
            obj.MNoiseContrast = ip.Results.MNoiseContrast;
            obj.rgToLm         = ip.Results.rgToLm;
            obj.maxToleratedClipFraction = ip.Results.maxToleratedClipFraction;
            obj.lmDriveMode = ip.Results.lmDriveMode;

            obj.plottedTypes = {};
            obj.figureHandle.Name = 'LM cone noise: stimulus trace sanity check';
        end

        function handleEpoch(obj, epoch)
            stimType = epoch.parameters('currentStimulus');
            if any(strcmp(obj.plottedTypes, stimType))
                return;
            end
            obj.plottedTypes{end+1} = stimType;

            lSeed = epoch.parameters('lNoiseSeed');
            mSeed = epoch.parameters('mNoiseSeed');

            try
                frameRate = obj.stageDevice.getMonitorRefreshRate();
            catch
                frameRate = 60;
            end

            stimFrames = round(frameRate * obj.stimTime / 1e3);
            nUpdates = floor(stimFrames / obj.frameDwell);
            t = (0:nUpdates-1) * obj.frameDwell / frameRate;

            [lIsom, mIsom] = obj.reconstructConeTraces(stimType, lSeed, mSeed, nUpdates);
            lmToRgLocal = inv(obj.rgToLm);
            rgRaw = lmToRgLocal * [lIsom; mIsom];
            rgClip = max(0, min(1, rgRaw));
            lmDelivered = obj.rgToLm * rgClip;
            clipFrac = mean(rgRaw(:) < 0 | rgRaw(:) > 1);

            [lmDriveIntended, lmDriveDelivered, lmDriveBaseline, lmDriveLabel] = obj.computeLmDrive(lIsom, mIsom, lmDelivered);

            allTypes = {'LNoise', 'MNoise', 'LMNoise'};
            col = find(strcmp(allTypes, stimType), 1);
            if isempty(col); col = numel(obj.plottedTypes); end

            axIsom = subplot(3, 3, col, 'Parent', obj.figureHandle);
            cla(axIsom);
            hold(axIsom, 'on');
            plot(axIsom, t, lIsom, 'r-', t, mIsom, 'g-');
            plot(axIsom, t, lmDelivered(1,:), 'Color', [1.0 0.55 0.55], 'LineStyle', '--');
            plot(axIsom, t, lmDelivered(2,:), 'Color', [0.30 0.75 0.30], 'LineStyle', '--');
            addHorizontalLine(axIsom, obj.meanLIsom, 'r:');
            addHorizontalLine(axIsom, obj.meanMIsom, 'g:');
            hold(axIsom, 'off');
            title(axIsom, sprintf('%s: L/M cones', stimType));
            ylabel(axIsom, 'Isom (R*/sec)');
            xlabel(axIsom, 'Time (s)');
            xlim(axIsom, [t(1), t(end)]);
            lmAll = [lIsom(:); mIsom(:); lmDelivered(:); obj.meanLIsom; obj.meanMIsom];
            yPad = max(1000, 0.05 * (max(lmAll) - min(lmAll)));
            ylim(axIsom, [min(lmAll) - yPad, max(lmAll) + yPad]);
            legend(axIsom, {'L intended','M intended','L delivered','M delivered','L mean','M mean'}, 'Location', 'best');

            axGun = subplot(3, 3, col + 3, 'Parent', obj.figureHandle);
            cla(axGun);
            hold(axGun, 'on');
            plot(axGun, t, rgRaw(1,:), 'Color', [1.0 0.6 0.6], 'LineWidth', 0.5);
            plot(axGun, t, rgRaw(2,:), 'Color', [0.6 1.0 0.6], 'LineWidth', 0.5);
            plot(axGun, t, rgClip(1,:), 'r-', 'LineWidth', 1);
            plot(axGun, t, rgClip(2,:), 'g-', 'LineWidth', 1);
            addHorizontalLine(axGun, 0, 'k:');
            addHorizontalLine(axGun, 1, 'k:');
            hold(axGun, 'off');
            ylim(axGun, [min(-0.05, min(rgRaw(:)) - 0.05), max(1.05, max(rgRaw(:)) + 0.05)]);
            xlim(axGun, [t(1), t(end)]);
            xlabel(axGun, 'Time (s)');
            ylabel(axGun, 'Gun intensity');
            if clipFrac <= obj.maxToleratedClipFraction
                clipStatus = 'OK';
            else
                clipStatus = 'above tolerance';
            end
            title(axGun, sprintf('R/G clipped %.2f%% [%s; tol %.1f%%]', ...
                100 * clipFrac, clipStatus, 100 * obj.maxToleratedClipFraction));
            legend(axGun, {'R raw','G raw','R delivered','G delivered','0','1'}, 'Location', 'best');

            axDrive = subplot(3, 3, col + 6, 'Parent', obj.figureHandle);
            cla(axDrive);
            hold(axDrive, 'on');
            plot(axDrive, t, lmDriveIntended, 'k-', 'LineWidth', 1.25);
            plot(axDrive, t, lmDriveDelivered, 'Color', [0.45 0.45 0.45], 'LineStyle', '--', 'LineWidth', 1);
            addHorizontalLine(axDrive, lmDriveBaseline, 'k:');
            hold(axDrive, 'off');
            xlim(axDrive, [t(1), t(end)]);
            driveAll = [lmDriveIntended(:); lmDriveDelivered(:); lmDriveBaseline];
            dPad = max(1000, 0.05 * (max(driveAll) - min(driveAll)));
            ylim(axDrive, [min(driveAll) - dPad, max(driveAll) + dPad]);
            xlabel(axDrive, 'Time (s)');
            ylabel(axDrive, lmDriveLabel);
            title(axDrive, sprintf('Combined L/M drive; baseline %.0f', lmDriveBaseline));
            legend(axDrive, {'intended','delivered','baseline'}, 'Location', 'best');

            drawnow;
        end
    end

    methods (Access = private)
        function [lIsom, mIsom] = reconstructConeTraces(obj, stimType, lSeed, mSeed, nUpdates)
            lStream = RandStream('mt19937ar', 'Seed', lSeed);
            mStream = RandStream('mt19937ar', 'Seed', mSeed);

            lIsom = zeros(1, nUpdates);
            mIsom = zeros(1, nUpdates);
            for ii = 1:nUpdates
                switch stimType
                    case 'LNoise'
                        lIsom(ii) = obj.meanLIsom * (1 + obj.LNoiseContrast * lStream.randn);
                        mIsom(ii) = obj.meanMIsom;
                    case 'MNoise'
                        lIsom(ii) = obj.meanLIsom;
                        mIsom(ii) = obj.meanMIsom * (1 + obj.MNoiseContrast * mStream.randn);
                    case 'LMNoise'
                        lIsom(ii) = obj.meanLIsom * (1 + obj.LNoiseContrast * lStream.randn);
                        mIsom(ii) = obj.meanMIsom * (1 + obj.MNoiseContrast * mStream.randn);
                    otherwise
                        lIsom(ii) = obj.meanLIsom;
                        mIsom(ii) = obj.meanMIsom;
                end
            end
        end

        function [driveIntended, driveDelivered, driveBaseline, driveLabel] = computeLmDrive(obj, lIsom, mIsom, lmDelivered)
            if strcmpi(obj.lmDriveMode, 'sum')
                driveIntended = lIsom + mIsom;
                driveDelivered = lmDelivered(1,:) + lmDelivered(2,:);
                driveBaseline = obj.meanLIsom + obj.meanMIsom;
                driveLabel = 'L + M isom (R*/sec)';
            else
                driveIntended = (lIsom + mIsom) / 2;
                driveDelivered = (lmDelivered(1,:) + lmDelivered(2,:)) / 2;
                driveBaseline = (obj.meanLIsom + obj.meanMIsom) / 2;
                driveLabel = '(L + M) / 2 isom (R*/sec)';
            end
        end
    end
end

function addHorizontalLine(ax, y, lineSpec)
% R2016b-compatible replacement for yline.
if nargin < 3
    lineSpec = 'k:';
end
xl = get(ax, 'XLim');
line(xl, [y y], 'Parent', ax, 'LineStyle', parseLineStyle(lineSpec), 'Color', parseLineColor(lineSpec));
end

function style = parseLineStyle(lineSpec)
if ~isempty(strfind(lineSpec, '--'))
    style = '--';
elseif ~isempty(strfind(lineSpec, ':'))
    style = ':';
elseif ~isempty(strfind(lineSpec, '-.'))
    style = '-.';
else
    style = '-';
end
end

function color = parseLineColor(lineSpec)
if ~isempty(strfind(lineSpec, 'r'))
    color = 'r';
elseif ~isempty(strfind(lineSpec, 'g'))
    color = 'g';
elseif ~isempty(strfind(lineSpec, 'b'))
    color = 'b';
elseif ~isempty(strfind(lineSpec, 'w'))
    color = 'w';
else
    color = 'k';
end
end

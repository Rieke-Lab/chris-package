function out = visualizeLMConeNoiseStandalone(varargin)
% visualizeLMConeNoiseStandalone
%
% Standalone MATLAB sanity-check for LMConeNoise.m, with no Symphony/Stage
% dependency. Compatible with MATLAB R2016b: no yline, sgtitle, tiledlayout,
% or newer graphics helpers.
%
% It reconstructs one LNoise, one MNoise, and one LMNoise example using the
% same L/M isomerization equations and red/green conversion as the protocol.
% It plots intended L/M cone traces, raw/clipped red-green gun values, and
% the combined L/M drive seen by the ganglion cell.
%
% Example:
%   out = visualizeLMConeNoiseStandalone();
%   out = visualizeLMConeNoiseStandalone('lSeed', 123, 'mSeed', 456);
%   out = visualizeLMConeNoiseStandalone('meanLIsomerization', 28000, ...
%       'meanMIsomerization', 16000, 'LNoiseContrast', 0.3, 'MNoiseContrast', 0.3);

ip = inputParser();
ip.addParameter('preTime', 500, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('stimTime', 8000, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('tailTime', 500, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('frameRate', 60, @(x)isnumeric(x) && isscalar(x) && x > 0);
ip.addParameter('frameDwell', 2, @(x)isnumeric(x) && isscalar(x) && x >= 1);

% Current protocol defaults.
ip.addParameter('meanLIsomerization', 29542, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('meanMIsomerization', 16827, @(x)isnumeric(x) && isscalar(x));

% Legacy convenience: if supplied, it overrides both separate means.
ip.addParameter('meanIsomerization', [], @(x)isnumeric(x) && (isscalar(x) || isempty(x)));

ip.addParameter('LNoiseContrast', 0.3, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('MNoiseContrast', 0.3, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('maxToleratedClipFraction', 0.10, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('lmDriveMode', 'mean', @(x)ischar(x)); % 'mean' or 'sum'

% Matrix convention: [L; M] = rgToLm * [R; G]
ip.addParameter('redChannelIsomPerUnitL',   50255,  @(x)isnumeric(x) && isscalar(x));
ip.addParameter('redChannelIsomPerUnitM',   13750,  @(x)isnumeric(x) && isscalar(x));
ip.addParameter('greenChannelIsomPerUnitL', 113478, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('greenChannelIsomPerUnitM', 126433, @(x)isnumeric(x) && isscalar(x));

% Seeds used for all three displayed stimulus types, matching the protocol:
% LNoise assigns the seed pair; MNoise and LMNoise reuse the pair.
ip.addParameter('lSeed', 0, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('mSeed', 1, @(x)isnumeric(x) && isscalar(x));
ip.addParameter('showDeliveredConeTraces', true, @(x)islogical(x) || isnumeric(x));
ip.addParameter('makeFigures', true, @(x)islogical(x) || isnumeric(x));
ip.parse(varargin{:});
p = ip.Results;

if ~isempty(p.meanIsomerization)
    p.meanLIsomerization = p.meanIsomerization;
    p.meanMIsomerization = p.meanIsomerization;
end

rgToLm = [p.redChannelIsomPerUnitL, p.greenChannelIsomPerUnitL; ...
          p.redChannelIsomPerUnitM, p.greenChannelIsomPerUnitM];
if abs(det(rgToLm)) < 1e-9
    error('rgToLm calibration matrix is singular. Check red/green calibration values.');
end
lmToRg = inv(rgToLm);

stimFrames = round(p.frameRate * p.stimTime / 1e3);
nUpdates = floor(stimFrames / p.frameDwell);
tSec = (0:nUpdates-1) * p.frameDwell / p.frameRate;

meanLM = [p.meanLIsomerization; p.meanMIsomerization];
meanRG = lmToRg * meanLM;
backgroundRGB = [clip01(meanRG(1)), clip01(meanRG(2)), 0];

stimTypes = {'LNoise', 'MNoise', 'LMNoise'};
out = struct();
out.params = p;
out.rgToLm = rgToLm;
out.lmToRg = lmToRg;
out.meanLM = meanLM;
out.meanRG = meanRG;
out.backgroundRGB = backgroundRGB;

fprintf('\nLMConeNoise standalone visualization\n');
fprintf('  mean L/M isom: %.1f / %.1f R*/sec\n', meanLM(1), meanLM(2));
fprintf('  mean R/G gun:  %.4f / %.4f\n', meanRG(1), meanRG(2));
fprintf('  background RGB after clipping: [%.4f %.4f %.4f]\n', backgroundRGB(1), backgroundRGB(2), backgroundRGB(3));
fprintf('  tolerated clipping: %.2f%% of R/G samples\n\n', 100 * p.maxToleratedClipFraction);

for ii = 1:numel(stimTypes)
    stimType = stimTypes{ii};
    [lIsom, mIsom] = reconstructConeTraces(stimType, p.lSeed, p.mSeed, nUpdates, ...
        p.meanLIsomerization, p.meanMIsomerization, p.LNoiseContrast, p.MNoiseContrast);

    intendedLM = [lIsom; mIsom];
    rawRG = lmToRg * intendedLM;
    deliveredRG = clip01(rawRG);
    deliveredLM = rgToLm * deliveredRG;

    intendedLMContrast = [(lIsom - p.meanLIsomerization) ./ p.meanLIsomerization; ...
                          (mIsom - p.meanMIsomerization) ./ p.meanMIsomerization];
    deliveredLMContrast = [(deliveredLM(1,:) - p.meanLIsomerization) ./ p.meanLIsomerization; ...
                           (deliveredLM(2,:) - p.meanMIsomerization) ./ p.meanMIsomerization];

    clipMask = rawRG < 0 | rawRG > 1;
    clipFrac = mean(clipMask(:));

    [lmDriveIntended, lmDriveDelivered, lmDriveBaseline, lmDriveLabel] = ...
        computeLmDrive(lIsom, mIsom, deliveredLM, p.meanLIsomerization, p.meanMIsomerization, p.lmDriveMode);

    s = struct();
    s.tSec = tSec;
    s.intendedLM = intendedLM;
    s.intendedLMContrast = intendedLMContrast;
    s.rawRG = rawRG;
    s.deliveredRG = deliveredRG;
    s.deliveredLM = deliveredLM;
    s.deliveredLMContrast = deliveredLMContrast;
    s.clipMask = clipMask;
    s.clipFrac = clipFrac;
    s.rawRGMin = min(rawRG(:));
    s.rawRGMax = max(rawRG(:));
    s.lmDriveIntended = lmDriveIntended;
    s.lmDriveDelivered = lmDriveDelivered;
    s.lmDriveBaseline = lmDriveBaseline;
    s.lmDriveLabel = lmDriveLabel;
    out.(stimType) = s;

    if clipFrac <= p.maxToleratedClipFraction
        status = 'OK';
    else
        status = 'ABOVE TOLERANCE';
    end
    fprintf('  %-7s: clipped %.2f%% [%s], raw R/G range [%.3f, %.3f]\n', ...
        stimType, 100 * clipFrac, status, s.rawRGMin, s.rawRGMax);
end

if logical(p.makeFigures)
    plotMainFigure(out, stimTypes, logical(p.showDeliveredConeTraces));
    plotContrastFigure(out, stimTypes);
    plotLmDriveFigure(out, stimTypes);
end
end

function [lIsom, mIsom] = reconstructConeTraces(stimType, lSeed, mSeed, nUpdates, meanL, meanM, lContrast, mContrast)
lStream = RandStream('mt19937ar', 'Seed', lSeed);
mStream = RandStream('mt19937ar', 'Seed', mSeed);
lIsom = zeros(1, nUpdates);
mIsom = zeros(1, nUpdates);
for ii = 1:nUpdates
    switch stimType
        case 'LNoise'
            lIsom(ii) = meanL * (1 + lContrast * lStream.randn);
            mIsom(ii) = meanM;
        case 'MNoise'
            lIsom(ii) = meanL;
            mIsom(ii) = meanM * (1 + mContrast * mStream.randn);
        case 'LMNoise'
            lIsom(ii) = meanL * (1 + lContrast * lStream.randn);
            mIsom(ii) = meanM * (1 + mContrast * mStream.randn);
        otherwise
            lIsom(ii) = meanL;
            mIsom(ii) = meanM;
    end
end
end

function [driveIntended, driveDelivered, driveBaseline, driveLabel] = computeLmDrive(lIsom, mIsom, deliveredLM, meanL, meanM, mode)
if strcmpi(mode, 'sum')
    driveIntended = lIsom + mIsom;
    driveDelivered = deliveredLM(1,:) + deliveredLM(2,:);
    driveBaseline = meanL + meanM;
    driveLabel = 'L + M isom (R*/sec)';
else
    driveIntended = (lIsom + mIsom) / 2;
    driveDelivered = (deliveredLM(1,:) + deliveredLM(2,:)) / 2;
    driveBaseline = (meanL + meanM) / 2;
    driveLabel = '(L + M) / 2 isom (R*/sec)';
end
end

function plotMainFigure(out, stimTypes, showDelivered)
figure('Name', 'LMConeNoise standalone: cone and gun traces');
for ii = 1:numel(stimTypes)
    stimType = stimTypes{ii};
    s = out.(stimType);
    t = s.tSec;

    ax1 = subplot(2, 3, ii);
    cla(ax1); hold(ax1, 'on');
    plot(ax1, t, s.intendedLM(1,:), 'r-', 'LineWidth', 1);
    plot(ax1, t, s.intendedLM(2,:), 'g-', 'LineWidth', 1);
    if showDelivered
        plot(ax1, t, s.deliveredLM(1,:), 'Color', [1.0 0.55 0.55], 'LineStyle', '--');
        plot(ax1, t, s.deliveredLM(2,:), 'Color', [0.30 0.75 0.30], 'LineStyle', '--');
    end
    addHorizontalLine(ax1, out.params.meanLIsomerization, 'r:');
    addHorizontalLine(ax1, out.params.meanMIsomerization, 'g:');
    hold(ax1, 'off');
    title(ax1, [stimType ': L/M cones']);
    xlabel(ax1, 'Time (s)');
    ylabel(ax1, 'Isom (R*/sec)');
    xlim(ax1, [t(1), t(end)]);
    lmAll = [s.intendedLM(:); s.deliveredLM(:); out.params.meanLIsomerization; out.params.meanMIsomerization];
    pad = max(1000, 0.05 * (max(lmAll) - min(lmAll)));
    ylim(ax1, [min(lmAll) - pad, max(lmAll) + pad]);
    if showDelivered
        legend(ax1, {'L intended','M intended','L delivered','M delivered','L mean','M mean'}, 'Location', 'best');
    else
        legend(ax1, {'L intended','M intended','L mean','M mean'}, 'Location', 'best');
    end

    ax2 = subplot(2, 3, ii + 3);
    cla(ax2); hold(ax2, 'on');
    plot(ax2, t, s.rawRG(1,:), 'Color', [1.0 0.6 0.6], 'LineWidth', 0.5);
    plot(ax2, t, s.rawRG(2,:), 'Color', [0.6 1.0 0.6], 'LineWidth', 0.5);
    plot(ax2, t, s.deliveredRG(1,:), 'r-', 'LineWidth', 1);
    plot(ax2, t, s.deliveredRG(2,:), 'g-', 'LineWidth', 1);
    addHorizontalLine(ax2, 0, 'k:');
    addHorizontalLine(ax2, 1, 'k:');
    hold(ax2, 'off');
    title(ax2, sprintf('R/G guns; clipped %.2f%%', 100 * s.clipFrac));
    xlabel(ax2, 'Time (s)');
    ylabel(ax2, 'Gun intensity');
    xlim(ax2, [t(1), t(end)]);
    ylim(ax2, [min(-0.05, min(s.rawRG(:))-0.05), max(1.05, max(s.rawRG(:))+0.05)]);
    legend(ax2, {'R raw','G raw','R delivered','G delivered','0','1'}, 'Location', 'best');
end
addFigureTitle(sprintf('LMConeNoise: meanLM=[%.0f %.0f], meanRG=[%.4f %.4f], seeds L=%d M=%d', ...
    out.meanLM(1), out.meanLM(2), out.meanRG(1), out.meanRG(2), out.params.lSeed, out.params.mSeed));
end

function plotContrastFigure(out, stimTypes)
figure('Name', 'LMConeNoise standalone: L/M contrast traces');
for ii = 1:numel(stimTypes)
    stimType = stimTypes{ii};
    s = out.(stimType);
    t = s.tSec;
    ax = subplot(1, 3, ii);
    cla(ax); hold(ax, 'on');
    plot(ax, t, s.intendedLMContrast(1,:), 'r-', 'LineWidth', 1);
    plot(ax, t, s.intendedLMContrast(2,:), 'g-', 'LineWidth', 1);
    plot(ax, t, s.deliveredLMContrast(1,:), 'Color', [1.0 0.55 0.55], 'LineStyle', '--');
    plot(ax, t, s.deliveredLMContrast(2,:), 'Color', [0.30 0.75 0.30], 'LineStyle', '--');
    addHorizontalLine(ax, 0, 'k:');
    hold(ax, 'off');
    title(ax, [stimType ': L/M contrast']);
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Fractional contrast');
    xlim(ax, [t(1), t(end)]);
    ylim(ax, [-1.2 1.2]);
    legend(ax, {'L intended','M intended','L delivered','M delivered','zero'}, 'Location', 'best');
end
addFigureTitle('L/M contrast traces; dashed traces show effective contrast after R/G clipping');
end

function plotLmDriveFigure(out, stimTypes)
figure('Name', 'LMConeNoise standalone: combined L/M drive');
for ii = 1:numel(stimTypes)
    stimType = stimTypes{ii};
    s = out.(stimType);
    t = s.tSec;
    ax = subplot(1, 3, ii);
    cla(ax); hold(ax, 'on');
    plot(ax, t, s.lmDriveIntended, 'k-', 'LineWidth', 1.25);
    plot(ax, t, s.lmDriveDelivered, 'Color', [0.45 0.45 0.45], 'LineStyle', '--', 'LineWidth', 1);
    addHorizontalLine(ax, s.lmDriveBaseline, 'k:');
    hold(ax, 'off');
    title(ax, sprintf('%s: combined drive', stimType));
    xlabel(ax, 'Time (s)');
    ylabel(ax, s.lmDriveLabel);
    xlim(ax, [t(1), t(end)]);
    driveAll = [s.lmDriveIntended(:); s.lmDriveDelivered(:); s.lmDriveBaseline];
    pad = max(1000, 0.05 * (max(driveAll) - min(driveAll)));
    ylim(ax, [min(driveAll) - pad, max(driveAll) + pad]);
    legend(ax, {'intended','delivered','baseline'}, 'Location', 'best');
end
addFigureTitle(sprintf('Combined L/M drive mode: %s', out.params.lmDriveMode));
end

function y = clip01(x)
y = max(0, min(1, x));
end

function addHorizontalLine(ax, y, lineSpec)
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

function addFigureTitle(txt)
% R2016b-compatible replacement for sgtitle.
annotation('textbox', [0 0.965 1 0.03], 'String', txt, 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'Interpreter', 'none');
end

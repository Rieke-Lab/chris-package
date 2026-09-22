function tests = testNaturalImageContrastScalor
% Run from the repository root: addpath(pwd); runtests('tests')
tests = functiontests(localfunctions);
end

function testAllBundledImages(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
resourceDir = fullfile(root, '+edu', '+washington', '+riekelab', '+chris', ...
    '+resources', 'VHsubsample_20160105');
files = dir(fullfile(resourceDir, '*.iml'));
verifyEqual(testCase, numel(files), 20);
for k = 1:numel(files)
    fid = fopen(fullfile(resourceDir, files(k).name), 'rb', 'ieee-be');
    cleanup = onCleanup(@() fclose(fid));
    img = fread(fid, [1536 1024], 'uint16');
    img = img ./ max(img(:));
    mu = mean(img(:));
    originalContrast = (img - mu) ./ mu;
    for scalor = [0 0.25 0.5 1]
        [contrast, pixels] = edu.washington.riekelab.chris.utils.scaleNaturalImageContrast(img, mu, scalor);
        verifyEqual(testCase, contrast, scalor .* originalContrast);
        scaled = mu + mu .* contrast;
        verifyEqual(testCase, mean(scaled(:)), mu, 'AbsTol', 1e-12);
        verifyGreaterThanOrEqual(testCase, min(scaled(:)), -eps);
        verifyLessThanOrEqual(testCase, max(scaled(:)), 1 + eps);
        verifyEqual(testCase, std(scaled(:)), scalor * std(img(:)), 'AbsTol', 1e-12);
        if scalor == 1
            verifyEqual(testCase, pixels, uint8(img .* 255));
        elseif scalor == 0
            verifyEqual(testCase, unique(pixels), uint8(255 * mu));
        end
    end
    clear cleanup;
end
end

function testInvalidScalors(testCase)
for bad = {-0.1, 1.1, NaN, Inf, [], [0 1], 1i}
    rejected = false;
    try
        edu.washington.riekelab.chris.utils.scaleNaturalImageContrast([0 1], 0.5, bad{1});
    catch
        rejected = true;
    end
    verifyTrue(testCase, rejected);
end
end

function testLegacySequence(testCase)
tags = {'image', 'intensity', 'linConeIntensity'};
for cones = [false true]
    n = 2 + double(cones);
    for epoch = 0:179
        [patch, scalor, tag] = edu.washington.riekelab.chris.utils.naturalImageContrastCondition(epoch, 20, 1, cones);
        verifyEqual(testCase, patch, floor(mod(epoch / n, 20) + 1));
        verifyEqual(testCase, scalor, 1);
        verifyEqual(testCase, tag, tags{mod(epoch, n) + 1});
    end
end
end

function testCompleteCycles(testCase)
% Explicit expected ordering across two patches and three scalors.
for cones = [false true]
    tags = {'image', 'intensity'};
    if cones
        tags{3} = 'linConeIntensity';
    end
    epoch = 0;
    for repeat = 1:2
        for expectedPatch = 1:2
            for expectedScalor = 1:3
                for t = 1:numel(tags)
                    [patch, scalor, tag] = edu.washington.riekelab.chris.utils.naturalImageContrastCondition(epoch, 2, 3, cones);
                    verifyEqual(testCase, {patch, scalor, tag}, {expectedPatch, expectedScalor, tags{t}});
                    epoch = epoch + 1;
                end
            end
        end
    end
end
end

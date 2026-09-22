function [patchIndex, scalorIndex, stimulusTag] = naturalImageContrastCondition(epochIndex, noPatches, noScalors, linearizeCones)
% epochIndex is zero-based; matrices of scalors use MATLAB column-major order.
tags = {'image', 'intensity', 'linConeIntensity'};
conditionCount = 2 + double(linearizeCones);
groupIndex = floor(epochIndex / conditionCount);
scalorIndex = mod(groupIndex, noScalors) + 1;
patchIndex = mod(floor(groupIndex / noScalors), noPatches) + 1;
stimulusTag = tags{mod(epochIndex, conditionCount) + 1};
end

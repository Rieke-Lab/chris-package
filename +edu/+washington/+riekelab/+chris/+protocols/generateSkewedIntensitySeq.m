function [intensity] = generateSkewedIntensitySeq(meanInt, contrast, numSlices,numPatterns)
array = normrnd(meanInt,contrast*meanInt, numSlices,100000);
a=mean(array);
b=std(array);
c=skewness(array);
index= find(abs(a-meanInt)<0.01*meanInt & abs(b-contrast*meanInt)<0.01*contrast*meanInt);
sampleSkew=c(index);
[~, ~, bin] = histcounts(sampleSkew,2*numSlices);
populatedBins = unique(bin);
%pluck one patch from each bin
pullInds = arrayfun(@(b) find(b == bin,1),populatedBins);
%get patch indices:
indices = randsample(pullInds,numPatterns);
indices= index(indices);

% Access the corresponding elements using the indices
intensity=array(:,indices);
end
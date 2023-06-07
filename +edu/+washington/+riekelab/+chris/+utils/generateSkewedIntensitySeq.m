function [intensity, skewList] = generateSkewedIntensitySeq(meanInt, contrast, numSlices,numPatterns)
array = normrnd(meanInt,contrast*meanInt, numSlices,200000);
a=mean(array);
b=std(array);
c=skewness(array);
lowBnd=min(array); upBnd=max(array); 
index= find(abs(a-meanInt)<0.01*meanInt & abs(b-contrast*meanInt)<0.01*contrast*meanInt & lowBnd>-0.1 & upBnd<1.1);
sampleSkew=c(index);
[~, ~, bin] = histcounts(sampleSkew,2*numSlices);
populatedBins = unique(bin);
%pluck one patch from each bin
pullInds = arrayfun(@(b) find(b == bin,1),populatedBins);
%get patch indices:
indices = randsample(pullInds,numPatterns);
indices= index(indices);
skewList=c(indices);
% Access the corresponding elements using the indices
intensity=array(:,indices); 
% bound the intensity between [0 1]
intensity(intensity<0)=0; intensity(intensity>1)=1;
end
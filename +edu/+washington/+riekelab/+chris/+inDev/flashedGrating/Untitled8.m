clc
obj.variableFlashTimes=[30 100 100 ];
obj.barWidth=[10 20 30 100];
for i=3:20
    
flashIndex=mod(i-3,numel(obj.variableFlashTimes))+1;
tempInd=(i-3-mod(i-3,numel(obj.variableFlashTimes)))/numel(obj.variableFlashTimes)+1;
barIndex=mod(tempInd-1,numel(obj.barWidth))+1;
[flashIndex barIndex]
end
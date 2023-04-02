function [grateMean] = getGrateMean(obj,time)

grateMean=(1+obj.spatialContrast)*obj.backgroundIntensity;
if time>obj.preTime/1e3 && time< (obj.preTime+obj.stimTime)/1e3
    grateMean=(1+obj.spatialContrast)*obj.stepIntensity;
end
end


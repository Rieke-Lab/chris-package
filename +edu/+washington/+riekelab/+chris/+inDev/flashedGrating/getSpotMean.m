function [spotMean] = getSpotMean(obj,time)

spotMean=obj.backgroundIntensity;
if time>obj.preTime/1e3 && time< (obj.preTime+obj.stimTime)/1e3
    spotMean=obj.stepIntensity;
end
end


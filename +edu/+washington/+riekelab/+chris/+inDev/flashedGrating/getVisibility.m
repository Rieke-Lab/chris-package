function [visibility] = getVisibility(obj,time)
visibility=false;
for i=1:length(obj.flashTimes)
    if time>obj.flashTimes(i)*1e-3 && time< (obj.flashTimes(i)+obj.flashDuration)*1e-3
        visibility=true;
    end
end
end


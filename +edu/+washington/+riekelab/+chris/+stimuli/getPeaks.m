function [peaks, ind] = getPeaks(data, dir)
    if dir > 0 % local max
        ind = find(diff(diff(data)>0)<0)+1;
    else % local min
        ind = find(diff(diff(data)>0)>0)+1;
    end
    peaks = data(ind);
end
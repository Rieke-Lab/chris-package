function ind = getThresCross(data, th, dir)
    % dir 1 = up, -1 = down
    
    orig = data(1:end-1);
    shifted = data(2:end);

    if dir>0
        ind = find(orig<th & shifted>=th) + 1;
    else
        ind = find(orig>=th & shifted<th) + 1;
    end
end
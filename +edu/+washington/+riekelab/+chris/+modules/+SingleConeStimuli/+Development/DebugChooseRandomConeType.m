function coneType = DebugChooseRandomConeType()
    num = rand;
    if num < 0.5
        coneType = 's';
    elseif num < 0.525
        coneType = 'm';
    else
        coneType = 'l';
    end
end
function [value, date] = readMostRecentCalibration(logPath)
% logPath - path of the text file containing the calibration information -
% it will have data stored in sets of 2 lines; the first line will be the
% date and the second will be the value

fid = fopen(logPath);

% get the first calibration entry
first = fgetl(fid);
second = fgetl(fid);
date = datetime(first);
value = str2double(justValue(second));

% continue through the rest to find the latest
first = fgetl(fid);
second = fgetl(fid);
while first ~= -1
    currDate = datetime(first);
    if currDate > date
       date = currDate;
       value = str2double(justValue(second));
    end
    first = fgetl(fid);
    second = fgetl(fid);
end

fclose(fid);

    % The value will often be printed with units following it.  These units
    % will be separated by a space (if not, this method will not work).
    % This will take in the line that contains the value and  return
    % everything before the first space.
    function val = justValue(val)
        spaces = regexpi(val, ' ');
        if ~isempty(spaces)
           val = val(1:spaces(1) - 1); 
        end
    end

end
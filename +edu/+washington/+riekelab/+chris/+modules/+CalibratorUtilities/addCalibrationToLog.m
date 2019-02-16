function addCalibrationToLog(logPath, value, date, varargin)
% filePath - the path of the text file to add the value to
% value - the actual calibration value
% date - the datetime object
% varargin - allows for the specification of something to follow the value
% in its string (such as units).  It will be converted to a string and
% added after a space following the value.

% This function will add the provided calibration to the end of the file.
% It will print the date, then the value on two different lines
fid = fopen(logPath, 'at');
fprintf(fid, '\n%s', char(date));
if isempty(varargin)
    fprintf(fid, '\n%.8f', value);
else
    fprintf(fid, '\n%.8f %s', value, char(varargin{1}));
end
fclose(fid);

end
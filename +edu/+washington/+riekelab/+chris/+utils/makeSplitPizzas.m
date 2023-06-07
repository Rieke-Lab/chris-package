function [canvas] = makeSplitPizzas(sz,numSlices, rot,intensitySequence)
rot=rot/180*pi;  % deg to rad
% Wedge pattern parameters
% Image size and center
centerX = sz / 2;
centerY = sz / 2;

% Wedge angle
wedgeAngle = 2 * pi / numSlices;

% Create a blank canvas
canvas = zeros(sz, sz);

% Draw the wedges
for i = 1:numSlices
    % Calculate start and end angles for each wedge
    startAngle =(i - 1) * wedgeAngle;
    endAngle = i * wedgeAngle;

    % Generate a meshgrid for the current wedge
    [X, Y] = meshgrid(1:sz, 1:sz);

    % Calculate the angle for each pixel relative to the center
    angle = mod(atan2(Y - centerY, X - centerX)+pi+rot,2*pi);
    dist=sqrt((Y - centerY).^2+ (X - centerX).^2);

    % Determine the pixels within the current wedge
    wedgePixels = (angle > startAngle) & (angle <= endAngle);
    %         wedgePixels = (angle > startAngle) & (angle <= endAngle) & dist<sz/2;

    % Set the intensity value for the pixels within the wedge
    temp(wedgePixels) = intensitySequence(i);
end

end
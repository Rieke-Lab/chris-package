function [contrastImage, wholeImageMatrix] = scaleNaturalImageContrast(imageMatrix, backgroundIntensity, contrastScalor)
% Scale every pixel about the ORIGINAL whole-image mean, before uint8 conversion.
% The normalized double image has mean backgroundIntensity. Quantization can
% introduce sub-gray-level mean error, as in the original flash protocol.
validateattributes(contrastScalor, {'double'}, ...
    {'real', 'finite', 'scalar', '>=', 0, '<=', 1});
contrastImage = (imageMatrix - backgroundIntensity) ./ backgroundIntensity;
contrastImage = contrastScalor .* contrastImage;
if contrastScalor == 1
    % Preserve the original conversion exactly, including rounding boundaries.
    wholeImageMatrix = uint8(imageMatrix .* 255);
else
    scaledImage = backgroundIntensity + backgroundIntensity .* contrastImage;
    wholeImageMatrix = uint8(scaledImage .* 255);
end
end

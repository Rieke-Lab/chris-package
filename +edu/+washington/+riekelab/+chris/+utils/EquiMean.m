function Intensity = EquiMean( SigmaC, image, Tag, bg )
%EQUIMEAN equivalent intensity of a image
%   Detailed explanation goes here 
% calculate the equivalent intensity of image that has a aperture added
%   restrain: aperture diameter is set as the image size
   if strcmp(Tag,'gaussian center')
      RF = fspecial('gaussian',size(image),SigmaC);
      sz = size(image, 1);
      r = floor(sz/2);
      [rr, cc] = meshgrid(1:sz, 1:sz);
      apertureMatrix = sqrt((rr-r).^2 +(cc-r).^2) < r;
      weightingFxn = apertureMatrix .* RF;
      weightingFxn = weightingFxn ./ sum(weightingFxn(:)); %sum to one
      contrastImage = (image - bg)./bg;
      equiContrast = sum(sum(weightingFxn .* double(contrastImage)));
      Intensity = bg*equiContrast + bg;
   elseif strcmp(Tag,'uniform')
      Intensity = mean(image(:));
   end

end


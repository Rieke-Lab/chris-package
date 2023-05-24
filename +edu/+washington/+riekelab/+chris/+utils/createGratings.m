function gratingMatrix = createGratings(offset,height, barwidth,sz)
%CREATEGRATINGS Summary of this function goes here
%   Detailed explanation goes here
% offset is the mean of the intensity of bars
% sz is the pixel value
% barwidth is in pixel as well
 numBars = size(barwidth, 2);
 grating = ones(numBars,sz,sz); %  create an image array
 center = floor(sz/2)+1; % center of grating is 
  for i = 1:numBars
      width = barwidth (i);
      wave = sin((linspace(1,sz,sz)-center)*pi/(width));
      wave(wave>=0)=1;
      wave(wave<0)=-1;
      grating(i,:,:)= ones(sz,1)*wave;
  end      
  gratingMatrix = grating*height+offset;
  if (numBars == 1)
      gratingMatrix = squeeze(gratingMatrix(1,:,:));
  end
end


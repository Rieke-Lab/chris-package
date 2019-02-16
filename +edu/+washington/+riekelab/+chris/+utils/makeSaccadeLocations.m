%% Pull van Hateren natural images...
clear all; close all; clc;
% IMAGES_DIR = 'C:\Users\Public\Documents\turner-package\resources\VHsubsample_20160105\'; % RIG PC
IMAGES_DIR            = '~/Dropbox/RiekeLab/Analysis/MATLAB/turner-package/resources/VHsubsample_20160105/'; %MAC
temp_names                  = GetFilenames(IMAGES_DIR,'.iml');	
for file_num = 1:size(temp_names,1) 
    temp                    = temp_names(file_num,:);
    temp                    = deblank(temp);
    img_filenames_list{file_num}  = temp;
end

img_filenames_list = sort(img_filenames_list);

%% 
imageScalingFactor = 3.3; %microns on retina per image pixel (3.3 um/arcmin visual angle)
NumFixations = 10000;           % how many patches to sample

% Screen sizes (microns) on prep:
%     OLED on Old slice, Confocal = 1.2 .* [800 600]  = [960, 720]
%     OLED on 2P = 1.8 .* [800 600]  = [1440, 1080]
%     OLED on RigG = 3.3 .* [800 600]  = [2640, 1980]   <------------
%     Lcr on Confocal = 1.3 .* [1824 1140]  = [2371.2, 1482]
    
stimSize_microns = [2640, 1980];        % Based on biggest screen in microns, so no fixations take you outside of image edge
windowSize_microns = 300; %microns


%convert to pixels:
stimSize = round(stimSize_microns / imageScalingFactor);
windowSize = round(windowSize_microns / imageScalingFactor); %pixels

%% step 2: apply to random image patches to each image

for ImageIndex = 1:length(img_filenames_list)
    ImageID = img_filenames_list{ImageIndex}(1:8);
    % Load  and plot the image to analyze
    f1=fopen([IMAGES_DIR, img_filenames_list{ImageIndex}],'rb','ieee-be');
    w=1536;h=1024;
    my_image=fread(f1,[w,h],'uint16');
    [ImageX, ImageY] = size(my_image);
    my_image = my_image ./ max(my_image(:));

    
    xBound = round(stimSize(1)/2) : ...
        round(stimSize(1)/2 + (ImageX - stimSize(1)));
    yBound = round(stimSize(2)/2) : ...
        round(stimSize(2)/2 + (ImageY - stimSize(1)));
    imageMean = mean(mean(my_image(xBound,yBound)));


    clear patchMean patchContrast Location

    %set random seed
    randSeed = 1;
    rng(randSeed);
    % choose set of random patches and measure RF components
    patchMean = nan(NumFixations,1);
    patchContrast = nan(NumFixations,1);
    Location = nan(NumFixations,2);
    
    for patch = 1:NumFixations

        % choose location
        x = round(stimSize(1)/2 + (ImageX - stimSize(1))*rand);
        y = round(stimSize(2)/2 + (ImageY - stimSize(2))*rand);
        Location(patch,:) = [x, y];

        % get patch
        ImagePatch = my_image(x-round(windowSize/2+1):x+round(windowSize/2),...
            y-round(windowSize/2+1):y+round(windowSize/2));
        
        %calculate stats
        patchMean(patch) = mean(ImagePatch(:));
        patchContrast(patch) = std(ImagePatch(:));
        

        if (rem(patch, 500) == 0)
            fprintf(1, '%d ', patch);
        end
    end
    imageData.(ImageID).location = Location;
    imageData.(ImageID).patchMean = patchMean;
    imageData.(ImageID).patchContrast = patchContrast;
    imageData.(ImageID).imageMean = imageMean;
     clc; 
     disp(num2str(ImageIndex))
end
modelParameters.randSeed = randSeed;
modelParameters.imageScalingFactor = imageScalingFactor;
modelParameters.NumFixations = NumFixations;
modelParameters.stimSize = stimSize;
modelParameters.windowSize = windowSize;


save('SaccadeLocationsLibrary_20171011.mat','imageData','modelParameters');
%%

figure(10); clf; imagesc(my_image'); colormap(gray);
hold on;
plot(imageData.imk00152.location(:,1),imageData.imk00152.location(:,2),'ro')

figure(11); clf; hist(imageData.imk00152.patchMean,100)
figure(12); clf; hist(imageData.imk00152.patchContrast,100)


%% Code like the following in protocols to do biased sampling:
noBins = 50; %from no. image patches to show
figure(3); clf; subplot(2,2,1)
hist(imageData.(ImageID).responseDifferences,noBins);
subplot(2,2,2); plot(imageData.(ImageID).SubunitModelResponse,imageData.(ImageID).LnModelResponse,'ko')

[N, edges, bin] = histcounts(imageData.(ImageID).responseDifferences,noBins);
populatedBins = unique(bin);

%pluck one patch from each bin
pullInds = arrayfun(@(b) find(b == bin,1),populatedBins);

figure(3); subplot(2,2,3)
hist(imageData.(ImageID).responseDifferences(pullInds),noBins)
subplot(2,2,4); plot(imageData.(ImageID).SubunitModelResponse(pullInds),imageData.(ImageID).LnModelResponse(pullInds),'ko')

%%
figure(2); clf;  
imagesc((my_image').^0.3);colormap gray;axis image; axis off; hold on;
plot(imageData.(ImageID).location(:,1),imageData.(ImageID).location(:,2),'r.');
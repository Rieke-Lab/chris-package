% We use the DOVES database to produce an incident image with and without
% fixational eye movements, or drift.
%
% INPUT:    imageNo: natural image from DOVES database, #1-101.
%           observerNo: specific observer from DOVES database. #1-19.
%   varargin:       'offSetWidth', #: offset from focused point (in degrees)
%                   'offSetHeight', #: offset from focused point (in degrees)
%                   'show...', true: plays resulting movie.
%
% OUTPUT:   empiricalMotion: video with both saccades and drift.
%           saccadeMotion: video with only saccades. (drift removed).
%           randomMotion: video with saccades + random walk.
%           information: contains original image and helpful information for analysis.
%
% Created by JMF 09/2018
% Last edited by JMF 09/2018

function [empiricalPath, saccadePath, deltaPath, information] = pathDOVES(imageNo, observerNo, varargin) 
    
    ip = inputParser(); % Used to dictate settings.
    ip.addRequired('imageNo', @isnumeric);
    ip.addRequired('observerNo', @isnumeric);
    
    ip.addParameter('amplification', 1, @isnumeric); % Standard deviation of random walk in microns
    ip.addParameter('directory', true, @islogical);
    % If images are in the same folder, make false. If not, type path in 'directory' variable.
    
    ip.addParameter('offSetHeight', 0, @isnumeric); % Offset from center of eye in microns
    ip.addParameter('offSetWidth', 0, @isnumeric);
    
    ip.addParameter('mirroring', true, @islogical);
    
    ip.parse(imageNo, observerNo, varargin{:});
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % Format imageNumber into correct filename.
    imageString = num2str(imageNo);
    directory = '+edu/+washington/+riekelab/+freedland/+images/';
    
    while size(imageString,2) < 3
        imageString = strcat('0',imageString);
    end
    if ip.Results.directory
        filename = strcat(directory,'img',imageString,'.mat');
    else
        filename = strcat('img',imageString,'.mat');
    end
    
    load(filename)
    information.image = picture;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Assign data to easy-to-use variables.
    observer = eye_data{1,observerNo};
    empiricalPath.x = observer(1,:); % Assign x coordinate data
    empiricalPath.y = observer(2,:); % Assign y coordinate data
    
    % Pre-allocate memory. 
    saccadePath.x = empiricalPath.x;
    saccadePath.y = empiricalPath.y;
    
    saccadeTracking = ones(1,size(observer,2));
   
    xChange = zeros(1,size(observer,2)-1);
    yChange = zeros(1,size(observer,2)-1);
    
    deltaPath.x = zeros(1,size(observer,2));
    deltaPath.y = zeros(1,size(observer,2));
    
    counter = 1; % Keeps track of when a saccade occurs.
    
    for a = 1:size(observer,2)-1

        % Determines when pixels (in x and y directions) move drastically.
        xChange(1,a) = abs(empiricalPath.x(1,a) - empiricalPath.x(1,a+1));
        yChange(1,a) = abs(empiricalPath.y(1,a) - empiricalPath.y(1,a+1));

        saccadeCutoff = 1/12; % distinguishes how many degrees define a saccade

        % If a small fixational movement occurs...
        if sqrt((xChange(1,a)^2 + yChange(1,a))^2) < saccadeCutoff*60 % in original paper, 60px = 1 deg
            
            saccadeTracking(1,a+1) = 0;
            
            if saccadeTracking(1,a) == 1 % If the past few frames were saccades
                counter = a; % Start tracking the beginning of our fixational eye movements
            end
        else % If a saccade occurs
            if saccadeTracking(1,a) == 0 % If the past few frames were fixational
                saccadePath.x(1,counter:a) = empiricalPath.x(1,counter); % Make a single image
                saccadePath.y(1,counter:a) = empiricalPath.y(1,counter);
            end
        end
    end
    
    % Fill in the final frames of the movie we missed in our loop.
    saccadePath.x(1,counter:end) = median(empiricalPath.x(1,counter:end));
    saccadePath.y(1,counter:end) = median(empiricalPath.y(1,counter:end));
    
    % Isolate fixational eye movement                
    deltaPath.x = empiricalPath.x - saccadePath.x; % Save dx
    deltaPath.y = empiricalPath.y - saccadePath.y;
                     
    % Apply offset 
    empiricalPath.x = empiricalPath.x + ip.Results.offSetWidth;
    saccadePath.x = saccadePath.x + ip.Results.offSetWidth;
    empiricalPath.y = empiricalPath.y + ip.Results.offSetHeight;
    saccadePath.y = saccadePath.y + ip.Results.offSetHeight;
    
    if ip.Results.mirroring
        mirroredImage = [flip(flip(picture,2)) flip(picture) flip(flip(picture,2));
        flip(picture,2) picture flip(picture,2);
        flip(flip(picture,2)) flip(picture) flip(flip(picture,2))];
    
        information.image = mirroredImage;
    
        c = size(picture);
        
        empiricalPath.x = empiricalPath.x + c(2);
        saccadePath.x = saccadePath.x + c(2);

        empiricalPath.y = empiricalPath.y + c(1);
        saccadePath.y = saccadePath.y + c(1);
    end
        
    empiricalPath.x = round(empiricalPath.x);
    saccadePath.x = round(saccadePath.x);
    deltaPath.x = round(deltaPath.x * ip.Results.amplification);

    empiricalPath.y = round(empiricalPath.y);
    saccadePath.y = round(saccadePath.y);
    deltaPath.y = round(deltaPath.y * ip.Results.amplification);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Fill in with our information
    information.saccadeTracking = saccadeTracking; % Tracks when a saccade is made
    information.imageName = filename;
    information.observer = observerNo;
    information.fixationAmplification = ip.Results.amplification;
    
end

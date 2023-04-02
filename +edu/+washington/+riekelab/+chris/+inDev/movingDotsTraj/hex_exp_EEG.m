% % Experiment code for investigating prediction of smooth motion using EEG
% % 
% % This script presents circular stimuli on a hexagonal grid, either flashed
% % for a short time or moving at a constant speed through the grid. 
% % Participants respond when the stimulus turns from black to red for one 
% % frame by pressing "space". 
% % 
% % Block and trial number triggers are organised as follows:
% % Block number triggers range from 101-109.
% % All triggers denoting trial number will range between 110 - 139
% % Hundreds denoting trigger ranges from 100-109, e.g., 100 denotes trials 1-99, 101 denotes trials 101-199 etc.
% % Tens denoting triggers start from trigger 111 and go until 120.
% % E.g., trigger 110 denotes trial numbers 1-9, trigger 111 denotes trial numbers 11-19
% % Ones denoting triggers start from trigger 121 and go until 130
% % E.g., trigger 120 denotes trial numbers ending with 0, 121 denotes trial numbers ending with 1, etc.
% % So for example, trigger 100 followed by 114 and then 122 is trial 42.
% % 
% % Written by Philippa Johnson, parts based off code from Tessel Blom, Hinze Hogendoorn and Daniel Feuerriegel.

% clear the workspace and the screen
sca;
close all;
clearvars;
commandwindow;  
format shortG; % display results matrix as integers not in base 10

addpath(genpath('functions')); % add path to functions folder

subID = input('subject name? ','s');
runnumber = input('run number? ','s');
filename=[subID runnumber '.mat'];

if exist(filename) && ~isempty(subID)c
    error('file exists, aborting')
end

%% PARAMETERS

% set up mode - practice/experiment
showDots = 1; % to show hex grid on screen
practice = 1; % *** set to 0 for main exp *** 

if practice
    isCorrectMode = input('you are in practice mode, press 1 if correct: ');
    isRecording = 1;
    eyetracking = 0;
else
    isCorrectMode = input('you are in experiment mode, press 1 if correct: ');
    isRecording = input('press 1 if EEG is saving: ');
    eyetracking = 1;
end
  
if ~isCorrectMode
    error('incorrect mode');
elseif ~isRecording
    disp('START RECORDING NOW')
    isRecording = input('press 1 if EEG is saving: ');    
end

% screen
screenNumber = 0; % *** if double screen layout, then 1=subject screen, 2=experimenter screen; if 1 screen > 0 ***
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
grey = white / 2; %get_color('grey'); %[200 200 200]; 
frameRate = Screen('FrameRate',screenNumber); % Hz
resolution = Screen('Resolution',0);

% keyboard
responseKeyIdx = KbName({'space'});
quitKeyIdx = KbName({'q'});

% EEG port
Port = struct();
Port.type = 'USB'; % set to 'Parallel' if using parallel port directly
if practice
    Port.isOn = 0; % if 1, sends triggers to the parallel port
else
    Port.isOn = 1; % if 1, sends triggers to the parallel port
end
    
% if  Port.isOn && Screen('FrameRate',screenNumber) ~= 200
%    error('change the duration and target frames and second trigger delay!')
% end

% initialise EEG ports
if Port.isOn
    [Port, s, ch] = set_up_eeg_port_usb(Port);
end

% initialise eyetracker
if eyetracking
    el=EyelinkInitDefaults(window); %initialize eyelink defaults (pixel coordinates are sent to eye tracker)
    el.backgroundcolour=grey;
        
    if ~EyelinkInit %initialise eyelink system and connection (dummy initialization if regular init fails)
        sca;return
    end    
end

%grid properties
maxRow = 7;
minRow = maxRow/2 + .5;
xspacing = 112; % pixels
gridPositions = createHex(maxRow, xspacing); %pixels of hexagonal grid centred around (0,0)
nHex = size(gridPositions,2);
rows = [minRow:maxRow maxRow-1:-1:minRow];

% stationary stim parameters
circleRad = round(xspacing*.625/2); % 35 pixels
circleDur = round(.25 * frameRate); % 15 frames at 60Hz refresh rate, 50 frames at 200Hz - 250ms
%flashOrder = 1:37; %randperm(37);

% moving stim parameters
speed = circleRad*2 / circleDur; % pixels per frame, dependent on duration and size of stationary stim
distFromGrid = xspacing*1.7; % how far away from grid moving stim appears

% target parameters
red = [192 0 0];
targetDisplayFrames = round(0.04 * frameRate); % 40ms

% trial list
if practice
    nTargets = 75; % number of targets in one block 
else 
    nTargets = 45;
end    
trialList = createTrialList(nTargets,0); % create list of all trials in all blocks
if practice
    nBlocks = 1; % practice - 1 block
    nTrials = 20; % practice - 20 trials
else 
    nBlocks = size(trialList,1); % 7 blocks
    nTrials = size(trialList,2); % 375 trials
end

% initiate behavioural results
behavResults = [0 0 0 0 0 0]; %[blockNo, trialNo, flash(1)OrMove(2), location/vector, target(1)OrResponse(3), responseTime]

% isi
meanISI = 0.4; % seconds, 400ms

% triggers
targetTrigger = 150;
responseTrigger = 151;
flashTrigger = 201;
moveOnsetTrigger = 209;
moveOffsetTrigger = 253;
secondTriggerDelay = round(0.04 * frameRate); % 5 frames - ~40 ms after first trigger

try            
    %% PREPARATION
    
    % settings
    Screen('Preference', 'SkipSyncTests', 1); % skip sync tests to avoid sync problems FOR NOW
    PsychDefaultSetup(2);
        
    % screen stuff
    [win, windowRect] = PsychImaging('OpenWindow', screenNumber, grey); % open an on screen window
    [xCentre, yCentre] = RectCenter(windowRect);    % centre coordinate of the window in pixels.
    hexCentre = [xCentre yCentre]; % for drawing dots
    dotPositions = gridPositions;
    gridPositions(1,:) = gridPositions(1,:) + xCentre; %shift grid positions to the centre of the screen
    gridPositions(2,:) = gridPositions(2,:) + yCentre;
    [screenXpixels, screenYpixels] = Screen('WindowSize', win); % size of the on screen window
    topPriorityLevel = MaxPriority(win);
    Priority(topPriorityLevel);
    HideCursor(screenNumber);
       
    % frame stuff
    ifi = Screen('GetFlipInterval', win); % minimum possible time between drawing to the screen
    isiFrames = round(meanISI/ifi);  
    
    % fixation dot
    [fixationimage, map, alpha] = imread('fix_dot.png'); 
    fixationimage(:,:,4) = alpha; % adds transparency
    %fixationimage = imresize(fixationimage, .5);
    FixationTexture = Screen('MakeTexture', win, fixationimage);
    Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA'); % allows transparent picture
        
    %% PRESENTATION
     
    % Present Instructions and wait for keypress
    HH_centerText(win,'You will see a circle either appear in',windowRect,-1,-190);
    HH_centerText(win,'one position or move across the screen.',windowRect,-1,-160);
    HH_centerText(win,'Sometimes, this circle will flash red.',windowRect,-1,-100);
    HH_centerText(win,'When this happens, press "space" as fast as you can.',windowRect,-1,-70);
    HH_centerText(win,'It is important that you keep looking at the',windowRect,-1,-10);
    HH_centerText(win,'centre of the screen throughout the blocks',windowRect,-1,20);
    HH_centerText(win,'Press the "x" to continue',windowRect,-1,200);
    [VBLTimestamp ] = Screen('Flip', win);
    HH_waitForKeyPress({'x'});
    
    if practice
        HH_centerText(win,['You will complete a practice block of ' num2str(nTrials) ' trials first.'],windowRect,-1,-190);
        HH_centerText(win,'After this block, you will recieve feedback about',windowRect,-1,-130);
        HH_centerText(win,'how fast you responded on average.',windowRect,-1,-100);
    else
        HH_centerText(win,['You will complete ' num2str(nBlocks) ' blocks of 10 minutes each.'],windowRect,-1,-190);
        HH_centerText(win,'After each block, you will recieve feedback',windowRect,-1,-130);
        HH_centerText(win,'about how fast you responded on average.',windowRect,-1,-100);
    end
    HH_centerText(win,'Try to keep responding fast so your average is good!',windowRect,-1,-70);
    HH_centerText(win,'If anything is unclear, please talk to the experimenter.',windowRect,-1,-10);
    if practice
        HH_centerText(win,'Otherwise, you can get started with a practice block.',windowRect,-1,20);
    else
        HH_centerText(win,'Otherwise, you can get started with the experiment now.',windowRect,-1,20);
    end
    HH_centerText(win,'Good luck!',windowRect,-1,80);
    HH_centerText(win,'Press the "c" to continue',windowRect,-1,200);
    [VBLTimestamp ] = Screen('Flip', win);
    HH_waitForKeyPress({'c'});

    % calibrate eyetracker
    if eyetracking
        el=EyelinkInitDefaults(win);
        el.backgroundcolour=grey;
        if ~EyelinkInit
            sca;return
        end
    
        edfFile=[filename(1:end-4) '.edf'];
        Eyelink('OpenFile',edfFile);
        Eyelink('command', 'calibration_area_proportion = 0.3, 0.3'); %
        Eyelink('command', 'validation_area_proportion = 0.3, 0.3'); %
        Eyelink('command', 'active_eye = LEFT');
        
        EyelinkDoTrackerSetup(el);
%         EyelinkDoDriftCorrection(el);
        Eyelink('StartRecording');
    end
    
    %triggers for syncing eeg and eytracking
    if Port.isOn && eyetracking
        send_eeg_event_codes(Port, 98, s);
        Eyelink('Message',['Trigger_' num2str(98)]);
    end    

    % initiate time stuff
    TSTART = tic;
    %clockStart = clock;
    disp(['start time: ' num2str(TSTART)]);
    
%     videoPtr =Screen('OpenVideoCapture', win);
%     Screen('StartVideoCapture',videoPtr);
    gifname = 'flashes_dots.gif';

%       
    % experimental loop
    for b = 1:nBlocks
        % wait 1 second before presenting stimuli
        Screen('DrawTexture', win, FixationTexture);
        if showDots
            Screen('DrawDots', win, dotPositions, 5, black, hexCentre, 2); %draw dots in hexagonal grid
        end
        vbl = Screen('Flip', win);
        WaitSecs(0.9);
        
        % send triggers for block
        if Port.isOn
            send_eeg_event_codes(Port,100+b,s);
        end
        if eyetracking
            Eyelink('Message',['Block_' num2str(100+b)]);
        end
        WaitSecs(0.1);
        
        blockResults = [0 0 0 0 0 0];
        keyPressed = 0; % reset keyboard
        for t = 1:nTrials
            im = Screen('GetImage',win);
            [imind,cm] = rgb2ind(im,256);
            if t == 1
                imwrite(imind,cm,gifname,'gif','Loopcount',inf,'DelayTime',0.02);
            end

            stim = trialList(b,t,1); % flash = 1, moving = 2
            target = trialList(b,t,3); % target = 1, no target = 0
%             if eyetracking
%                 Eyelink('Message',['Trial_' num2str(t)]); % eyetracking trigger for trial number
%             end
            
            % FLASH STIM
            if stim == 1
                location = trialList(b,t,2); 
                locationTrigger = location;
                if target == 1
                    targetFrame = randi([secondTriggerDelay*4+1 circleDur-targetDisplayFrames]); % frame target starts being shown
                    endTargetFrame = targetFrame + targetDisplayFrames; % frame target stops being shown
                    locationTrigger = location + 50; % add 50 to location trigger when target is present
                end
                if showDots
                    Screen('DrawDots', win, dotPositions, 5, black, hexCentre, 2); %draw dots in hexagonal grid
                end
                Screen('DrawTexture', win, FixationTexture);
                vbl = Screen('Flip', win); % flip outside of the loop to get a time stamp
                for f = 1:circleDur
%                     %%%% TRIGGER TEST %%%%
%                     if f == 1 % first trigger
%                         disp(['flash location: ' num2str(location)]); % trigger for location
%                     elseif f == secondTriggerDelay % second trigger
%                         disp(['flash trigger: ' num2str(flashTrigger)]); % trigger for flash
%                     end
%                     %%%% END TRIGGER TEST %%%%
                    % send EEG triggers
                    if f == 1 && Port.isOn % first trigger
                        send_eeg_event_codes(Port,locationTrigger,s); % trigger for location
                    elseif f == secondTriggerDelay && Port.isOn % second trigger
                        send_eeg_event_codes(Port,flashTrigger,s); % trigger for flash
                    elseif f == secondTriggerDelay*2 && Port.isOn % trial number trigger 1
                        trial_hundredsCounter = floor(t ./ 100);
                        send_eeg_event_codes(Port,trial_hundredsCounter+110,s); % trigger for hundreds
                    elseif f == secondTriggerDelay*3 && Port.isOn % trial number trigger 2
                        trial_tensCounter = floor(mod(t, 100)/10);
                        send_eeg_event_codes(Port,trial_tensCounter+120,s); % trigger for hundreds
                    elseif f == secondTriggerDelay*4 && Port.isOn % trial number trigger 3
                       trial_onesCounter = mod(t, 10);
                       send_eeg_event_codes(Port,trial_onesCounter+130,s); % trigger for hundreds
                    end
                    % send eyetracking triggers
                    if f == 1 && eyetracking
                        Eyelink('Message',['Location_' num2str(locationTrigger)]); 
                    elseif f == secondTriggerDelay && eyetracking
                        Eyelink('Message',['Type_' num2str(flashTrigger)]);
                    elseif f == secondTriggerDelay*2 && eyetracking
                        Eyelink('Message',['Trial_' num2str(t)]);
                    end
                    
                    % target is red stimulus for x frames 
                    if target == 1 && f >= targetFrame && f < endTargetFrame
                        colour = red;
                    else
                        colour = black;
                    end
                    % present stimulus
                    if showDots
                    	Screen('DrawDots', win, dotPositions, 5, black, hexCentre, 2); %draw dots in hexagonal grid
                    end
                    Screen('DrawTexture', win, FixationTexture);
                    drawCircle(win,colour,gridPositions(1,location),gridPositions(2,location),circleRad);
                    vbl = Screen('Flip', win, vbl + 0.5 * ifi);
                    % record target
                    if target == 1 && f == targetFrame
                        targetTime = GetSecs; % record time target was shown [[etime(clock,clockStart)]]
%                         %%%% TRIGGER TEST %%%%
%                         disp(['target FLASH: ' num2str(targetTrigger)])
%                         %%%% END TRIGGER TEST %%%%
                        if Port.isOn
                            send_eeg_event_codes(Port,targetTrigger,s); % send trigger
                        end
                        if eyetracking
                            Eyelink('Message',['Target_' num2str(targetTrigger)]);
                        end
                        trialResults = [b t trialList(b,t,1) trialList(b,t,2) trialList(b,t,3) targetTime];
                        blockResults = [blockResults; trialResults]; % add to behavioural results
                    end
                    % check and record response
                    [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                    if keyCode(responseKeyIdx) && ~keyPressed % subject pressed space and it hasn't been recorded yet
%                         %%%% TRIGGER TEST %%%%
%                         disp(['response FLASH: ' num2str(responseTrigger)])
%                         %%%% END TRIGGER TEST %%%%
                        if Port.isOn
                            send_eeg_event_codes(Port,responseTrigger,s); % send trigger
                        end
                        if eyetracking
                            Eyelink('Message',['Response_' num2str(responseTrigger)]);
                        end
                        responseTime = secs; % record time of response
                        trialResults = [b t trialList(b,t,1) trialList(b,t,2) 3 responseTime];
                        blockResults = [blockResults; trialResults]; % add to behavioural results
                        keyPressed = 1;
                    elseif keyPressed && ~keyIsDown % subject released the button
                        keyPressed = 0;
                    elseif keyCode(quitKeyIdx)
                        error('pressed quit')
                    end
                    im = Screen('GetImage',win);
                    [imind,cm] = rgb2ind(im,256);
                     imwrite(imind,cm,gifname,'gif','WriteMode','append','DelayTime',ifi); 
                end % of flash              
                
            % MOVING STIM
            elseif stim == 2 
                continue;
                direction = ceil(trialList(b,t,2)/7); % 1-6
                startingHex = rem(trialList(b,t,2),7)+1; % 1-7
                hexPos = calcStartingHex(startingHex, direction, gridPositions, maxRow); % first hexagon on path
                startPos = calcStartingPos(hexPos(1), hexPos(2), direction, xspacing, distFromGrid); % starting position
                if target == 1
                    targetFrame = randi([secondTriggerDelay*4 round(xspacing/speed)-targetDisplayFrames]); % frame target starts being shown
                    endTargetFrame = targetFrame + targetDisplayFrames; % frame target stops being shown
                    targetStep = randi([2 rows(startingHex)]); % step in which target is shown (always on grid)
                    locTrigAdd = 50; % add 50 to the location trigger in target trials
                else
                    locTrigAdd = 0; % add nothing to location triggers in notarget trials
                end
                if showDots
                    Screen('DrawDots', win, dotPositions, 5, black, hexCentre, 2); %draw dots in hexagonal grid
                end
                Screen('DrawTexture', win, FixationTexture);
                vbl = Screen('Flip', win); % flip outside of the loop to get a time stamp
                for i = 1:rows(startingHex)+1
                    if i == 1 
                        whichHex = gridPositions(1,:) == hexPos(1) & gridPositions(2,:) == hexPos(2); 
                        currentIdx = find(whichHex); % reset current hex index to the first hex on grid
                        currentPos = startPos; % set current pos to position circle appears
                        stepDist = hexPos-startPos; % distance from starting position to first hex
                        stepFrames = (distFromGrid+(xspacing/2))/speed; % number of frames from starting position to first hex
                    elseif i == rows(startingHex)+1
                        location = currentIdx; % first trigger
                        trigger = 210 + ((direction-1)*7) + (i-1); % second trigger
                        currentPos = transpose(gridPositions(:,currentIdx));
                        endPos = calcEndingPos(currentPos(1), currentPos(2), direction, xspacing, distFromGrid);
                        stepDist = endPos - currentPos; % distance from last hex to ending position
                        stepFrames = (distFromGrid+(xspacing/2))/speed; % number of frames from starting position to first hex                       
                    else
                        stepFrames = xspacing/speed; % number of frames needed to travel to next hex
                        nextIdx = nextHex(gridPositions, rows, direction, currentIdx); % index of next hex
                        currentPos = transpose(gridPositions(:,currentIdx));
                        stepDist = transpose(gridPositions(:,nextIdx)) - currentPos; % distance to next hex
                        location = currentIdx; % first trigger
                        trigger = 210 + ((direction-1)*7) + (i-1); % second trigger
                        currentIdx = nextIdx;
                    end
                    for f = 1:stepFrames
                        % send triggers
%                         %%%% TRIGGER TEST %%%%
%                         if f == 1 % first trigger
%                             if i == 1
%                                 disp(['move onset: ' num2str(moveOnsetTrigger)]); % trigger at start of motion
%                             else % if hexagon is on the grid
%                                 disp(['move location: ' num2str(location)]); % trigger for location
%                             end
%                         elseif f == secondTriggerDelay % second trigger
%                             if i > 1 % if hexagon is on the grid
%                                 disp(['move dir + pos: ' num2str(trigger)]); % trigger for direction of motion and seq position
%                             end
%                         end
%                         %%%% END TRIGGER TEST %%%%
                        if f == 1 && Port.isOn % first trigger
                            if i == 1
                                send_eeg_event_codes(Port,moveOnsetTrigger,s); % trigger at start of motion
                                if eyetracking
                                    Eyelink('Message',['Trigger_' num2str(moveOnsetTrigger)]);
                                end
                            else % if hexagon is on the grid
                                send_eeg_event_codes(Port,location+locTrigAdd,s); % trigger for location
                                if eyetracking
                                    Eyelink('Message',['Location_' num2str(location+locTrigAdd)]);
                                end
                            end
                        elseif f == secondTriggerDelay && Port.isOn % second trigger
                            if i > 1 % if hexagon is on the grid
                                send_eeg_event_codes(Port,trigger,s); % trigger for direction of motion and seq position
                                if eyetracking
                                    Eyelink('Message',['Type_' num2str(trigger)]);
                                end
                            end
                        elseif f == secondTriggerDelay*2 && Port.isOn % trial number trigger 1
                            if i > 1 % if hexagon is on the grid
                                trial_hundredsCounter = floor(t ./ 100);
                                send_eeg_event_codes(Port,trial_hundredsCounter+110,s); % trigger for hundreds
                                if eyetracking
                                    Eyelink('Message',['Trial_' num2str(t)]);
                                end
                            end
                        elseif f == secondTriggerDelay*3 && Port.isOn % trial number trigger 2
                            if i > 1
                                trial_tensCounter = floor(mod(t, 100) / 10);
                                send_eeg_event_codes(Port,trial_tensCounter+120,s); % trigger for hundreds
                            end
                        elseif f == secondTriggerDelay*4 && Port.isOn % trial number trigger 3
                            if i > 1
                               trial_onesCounter = mod(t, 10);
                               send_eeg_event_codes(Port,trial_onesCounter+130,s); % trigger for hundreds
                            end
                        end
                        % target is red stimulus for x frames 
                        if (target == 1) && (i == targetStep) && (f >= targetFrame) && (f < endTargetFrame) 
                            colour = red;
                        else
                            colour = black;
                        end
                        % present stimulus
                        if showDots
                            Screen('DrawDots', win, dotPositions, 5, black, hexCentre, 2); %draw dots in hexagonal grid
                        end
                        Screen('DrawTexture', win, FixationTexture);
                        drawCircle(win,colour,currentPos(1),currentPos(2),circleRad);
                        vbl = Screen('Flip', win, vbl + 0.5 * ifi);
                        currentPos = currentPos + stepDist/stepFrames;
                        % record target
                        if (target == 1) && (i == targetStep) && (f == targetFrame)
                            targetTime = GetSecs; % record time target was shown
%                             %%%% TRIGGER TEST %%%%
%                             disp(['target MOVE: ' num2str(targetTrigger)])
%                             %%%% END TRIGGER TEST %%%%
                            if Port.isOn
                                send_eeg_event_codes(Port,targetTrigger,s); % send trigger
                            end
                            if eyetracking
                                Eyelink('Message',['Target_' num2str(targetTrigger)]);
                            end                            
                            trialResults = [b t trialList(b,t,1) trialList(b,t,2) trialList(b,t,3) targetTime];
                            blockResults = [blockResults; trialResults]; % add to behavioural results    
                        end
                        % check and record response
                        [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                        if keyCode(responseKeyIdx) && ~keyPressed % subject pressed space and it hasn't been recorded yet
%                             %%%% TRIGGER TEST %%%%
%                             disp(['response MOVE: ' num2str(responseTrigger)])
%                             %%%% END TRIGGER TEST %%%%
                            if Port.isOn
                                send_eeg_event_codes(Port,responseTrigger,s); % send trigger
                            end
                            if eyetracking
                                Eyelink('Message',['Response_' num2str(responseTrigger)]);
                            end                            
                            responseTime = secs; % record time of response
                            trialResults = [b t trialList(b,t,1) trialList(b,t,2) 3 responseTime];
                            blockResults = [blockResults; trialResults]; % add to behavioural results                            
                            keyPressed = 1;
                        elseif keyPressed && ~keyIsDown % subject released the button
                            keyPressed = 0;
                        elseif keyCode(quitKeyIdx)
                            error('pressed quit')
                        end
%             im = Screen('GetImage',win);
%             [imind,cm] = rgb2ind(im,256);
%                        imwrite(imind,cm,gifname,'gif','WriteMode','append','DelayTime',ifi); 

                    end % of step
                end % of movement
                if Port.isOn
                    send_eeg_event_codes(Port,moveOffsetTrigger,s); % trigger at end of motion
                end
                if eyetracking
                    Eyelink('Message',['Trigger_' num2str(moveOffsetTrigger)]);
                end                
%                 %%%% TRIGGER TEST %%%%
%                 disp(['move offset: ' num2str(moveOffsetTrigger)]); % trigger at end of motion  
%                 %%%% END TRIGGER TEST %%%%
            end % of trial
            
            % inter-stimulus interval
            if showDots
                Screen('DrawDots', win, dotPositions, 5, black, hexCentre, 2); %draw dots in hexagonal grid
            end
            Screen('DrawTexture', win, FixationTexture);
            vbl = Screen('Flip', win, vbl + 0.5 * ifi);
            im = Screen('GetImage',win);
            [imind,cm] = rgb2ind(im,256);
            imwrite(imind,cm,gifname,'gif','WriteMode','append','DelayTime',meanISI); 

            tEnd = GetSecs + randi([round((meanISI-0.1)*100) round((meanISI+0.1)*100)])/100; % end of isi, jitter 0.3 - 0.5 secs

            while GetSecs<tEnd
                [keyIsDown, secs, keyCode, deltaSecs] = KbCheck;
                if keyCode(responseKeyIdx) && ~keyPressed % subject pressed space and it hasn't been recorded yet
%                     %%%% TRIGGER TEST %%%%
%                     disp(['response ISI: ' num2str(responseTrigger)])
%                     %%%% END TRIGGER TEST %%%%
                    if Port.isOn
                        send_eeg_event_codes(Port,responseTrigger,s); % send trigger
                    end
                    if eyetracking
                        Eyelink('Message',['Response_' num2str(responseTrigger)]);
                    end                    
                    responseTime = secs; 
                    trialResults = [b t trialList(b,t,1) trialList(b,t,2) 3 responseTime];
                    blockResults = [blockResults; trialResults]; % add to behavioural results                            
                    keyPressed = 1;
                elseif keyPressed && ~keyIsDown % subject released the button
                    keyPressed = 0;
                elseif keyCode(quitKeyIdx)
                    error('pressed quit')
                end
            end % of isi while-loop
            
%             Screen('StopVideoCapture',videoPtr)
%             Screen('CloseVideoCapture',videoPtr);
            
            % short break after 54 trials (~1.3 mins)
            if rem(t,54) == 0
                if eyetracking
                    Eyelink('StopRecording');
                end
                HH_centerText(win,'Take a small break!',windowRect,-1,-190);
                HH_centerText(win,'Feel free to briefly relax but please DO NOT move from the chinrest.',windowRect,-1,-100);
                HH_centerText(win,'When you are ready to continue the block, press "x".',windowRect,-1,200);
                [VBLTimestamp ] = Screen('Flip', win);
                HH_waitForKeyPress({'x'});
                if eyetracking
                    EyelinkDoDriftCorrection(el);
                    Eyelink('StartRecording');
                end
                Screen('DrawTexture', win, FixationTexture);
                vbl = Screen('Flip', win);
                WaitSecs(1);
            end
            
        end % of block
        
        disp(['time elapsed: ' num2str(toc(TSTART))]);
        
        if eyetracking
            Eyelink('StopRecording');
        end
        
        % calc average response time
        [meanBlockRT, targWithResp, missedTargets] = calcBlockRT(blockResults); % calculate RT for block
        behavResults = [behavResults; blockResults];
        % display block feedback
        HH_centerText(win,['This is the end of block ' num2str(b) ' out of ' num2str(nBlocks) '.'],windowRect,-1,-190);
        HH_centerText(win,'Your average response time for this block is:',windowRect,-1,-100);
        HH_centerText(win,[num2str(meanBlockRT*1000) ' milliseconds.'],windowRect,-1,-70);
        HH_centerText(win,['You missed ' num2str(missedTargets) ' out of ' num2str(targWithResp+missedTargets) ' targets.'],windowRect,-1,20);
        HH_centerText(win,'Feel free to have a short break and sit back.',windowRect,-1,110);
        HH_centerText(win,'When you are ready, press "x" to continue!',windowRect,-1,200);
        [VBLTimestamp ] = Screen('Flip', win);
        HH_waitForKeyPress({'x'});
        if eyetracking && b < nBlocks % recalibrate every block
            EyelinkDoTrackerSetup(el);
%             EyelinkDoDriftCorrection(el);
            Eyelink('StartRecording');
        end
    end % of experimental loop
      
    % end screen
    if practice
        HH_centerText(win,'This is the end of the practice.',windowRect,-1,-190);
        HH_centerText(win,'If anything is unclear, you can do another practice.',windowRect,-1,-100);
    else
        HH_centerText(win,'This is the end of the session.',windowRect,-1,-190);
        HH_centerText(win,'Thank you for taking part!',windowRect,-1,-100);
    end
    
    %triggers for syncing eeg and eytracking
    if Port.isOn && eyetracking
        send_eeg_event_codes(Port, 99, s);
        Eyelink('Message',['Trigger_' num2str(99)]);
    end   
    
    HH_centerText(win,'Please call the experimenter now.',windowRect,-1,-10);
    [VBLTimestamp ] = Screen('Flip', win);
    HH_waitForKeyPress({'p'});
    
%     Screen('FinalizeMovie', moviePtr);
    
    %% CLEANUP
    
    Priority(0);
    Screen('CloseAll');
    disp('end of experiment!');
    
    % Ask user where to save MAT results:
    [filename,pathname] = uiputfile('*.mat','Save Results as .mat?');
    
    if isequal(filename,0) || practice == 1
        % user pressed cancel - do nothing
    else
        save([pathname filename]);
        disp('file saved!');
    end

    if Port.isOn
        send_eeg_event_codes(Port, 255, s);
        close_eeg_ports(Port, s);
    end
    
    if eyetracking
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        status= Eyelink('ReceiveFile',edfFile,[pwd '\edf-data'],1);
        Eyelink('Shutdown');   
    end
    
catch ER
    if Port.isOn && eyetracking
        send_eeg_event_codes(Port, 99, s);
        Eyelink('Message',['Block_' num2str(99)]);
    end 
    ER.getReport
    Priority(0);
    ShowCursor();
    if Port.isOn
        close_eeg_ports(Port, s);
    end
    if eyetracking
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        status= Eyelink('ReceiveFile',edfFile,[pwd '\edf-data'],1);
        Eyelink('Shutdown');   
    end
    sca;
end


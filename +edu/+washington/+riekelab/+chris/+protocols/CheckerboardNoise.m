classdef CheckerboardNoise < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    
    properties
        preTime = 500 % ms
        stimTime = 20000 % ms
        tailTime = 500 % ms
        stixelSize = 30 % um
        binaryNoise = true %binary checkers - overrides noiseStdv
        noiseStdv = 0.3 %contrast, as fraction of mean
        frameDwell = 1 % Frames per noise update
        useRandomSeed = true % false = repeated noise trajectory (seed 0)
        backgroundIntensity = 0.5 % (0-1)
        onlineAnalysis = 'none'
        numberOfAverages = uint16(20) % number of epochs to queue
        amp % Output amplifier
    end

    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        noiseSeed
        noiseStream
        numChecksX
        numChecksY
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
         
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.weber.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.weber.figures.StrfFigure',...
                obj.rig.getDevice(obj.amp),obj.rig.getDevice('Frame Monitor'),...
                obj.rig.getDevice('Stage'),...
                'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime,...
                'frameDwell',obj.frameDwell,'binaryNoise',obj.binaryNoise);
            end
            
            %get number of checkers...
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            %convert from microns to pixels...
            stixelSizePix = obj.rig.getDevice('Stage').um2pix(obj.stixelSize);
            obj.numChecksX = round(canvasSize(1) / stixelSizePix);
            obj.numChecksY = round(canvasSize(2) / stixelSizePix);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            
            % Determine seed values.
            if obj.useRandomSeed
                obj.noiseSeed = RandStream.shuffleSeed;
            else
                obj.noiseSeed = 0;
            end
            
            %at start of epoch, set random stream
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
            epoch.addParameter('numChecksX', obj.numChecksX);
            epoch.addParameter('numChecksY', obj.numChecksY);
        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity
            
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            % Create checkerboard
            initMatrix = uint8(255.*(obj.backgroundIntensity .* ones(obj.numChecksY,obj.numChecksX)));
            board = stage.builtin.stimuli.Image(initMatrix);
            board.size = canvasSize;
            board.position = canvasSize/2;
            board.setMinFunction(GL.NEAREST); %don't interpolate to scale up board
            board.setMagFunction(GL.NEAREST);
            p.addStimulus(board);
            preFrames = round(60 * (obj.preTime/1e3));
            checkerboardController = stage.builtin.controllers.PropertyController(board, 'imageMatrix',...
                @(state)getNewCheckerboard(obj, state.frame - preFrames));
            p.addController(checkerboardController); %add the controller
            function i = getNewCheckerboard(obj, frame)
                persistent boardMatrix;
                if frame<0 %pre frames. frame 0 starts stimPts
                    boardMatrix = obj.backgroundIntensity;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        if (obj.binaryNoise)
                            boardMatrix = 2*obj.backgroundIntensity * ...
                                (obj.noiseStream.rand(obj.numChecksY,obj.numChecksX) > 0.5);
                        else
                            boardMatrix = obj.backgroundIntensity + ...
                                obj.noiseStdv * obj.backgroundIntensity * ...
                                obj.noiseStream.randn(obj.numChecksY,obj.numChecksX);
                        end
                    end
                end
                i = uint8(255 * boardMatrix);
            end

            % hide during pre & post
            boardVisible = stage.builtin.controllers.PropertyController(board, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(boardVisible); 
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
    
end
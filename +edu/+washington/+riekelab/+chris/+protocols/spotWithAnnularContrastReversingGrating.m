classdef spotWithAnnularContrastReversingGrating < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        apertureDiameter = 300   % um (center spot)
        annulusInnerDiameter = 400  % um
        annulusOuterDiameter = 800  % um
        barWidth = [30 60]  % um

        backgroundIntensity = 0.15  % 0-1, background and gap intensity
        spotIntensity = 0.05  % 0-1, intensity of center spot
        brightBarContrast = [0.9]  % positive peak of asymmetric contrast waveform
        darkBarContrast = [-0.25 -0.5 -0.75 -1.0]  % negative peak of asymmetric contrast waveform
        temporalFrequency = [2 4]  % Hz, temporal frequency of contrast reversal
        %temporalClass = 'sinewave'  % temporal waveform: sinewave or squarewave

        preTime = 1000   % ms
        stimTime = 2000  % ms
        tailTime = 1000  % ms

        onlineAnalysis = 'extracellular'

        downSample = 1
        numberOfAverages = uint16(3)  % number of repeats to queue
        amp
    end

    properties(Hidden)
        ampType
        barWidthType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        brightBarContrastType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        darkBarContrastType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        temporalFrequencyType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        currentBarWidth
        currentBrightContrast
        currentDarkContrast
        currentTemporalFrequency
        stimSequence
        meanImage
        brightMaskScaled
        darkMaskScaled
        gratingImage
        gratingImageInv
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            % Create stimulus sequence combining all parameters
            obj.stimSequence = [];
            for bw = 1:length(obj.barWidth)
                for bc = 1:length(obj.brightBarContrast)
                    for dc = 1:length(obj.darkBarContrast)
                        for tf = 1:length(obj.temporalFrequency)
                            obj.stimSequence = [obj.stimSequence; ...
                                obj.barWidth(bw), obj.brightBarContrast(bc), ...
                                obj.darkBarContrast(dc), obj.temporalFrequency(tf)];
                        end
                    end
                end
            end

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));

            % Colour the mean-response sweeps by negative (dark-bar) contrast,
            % so the depth of the dark bar is readable off the trace colour.
            % MeanResponseFigure takes colours in the order groups first
            % appear, and groups appear in stimSequence order, so row i of
            % this matrix is the colour for stimSequence row i.
            darkValues = obj.stimSequence(:, 3);
            uniqueDark = unique(darkValues);                 % ascending: -1 first
            if numel(uniqueDark) > 1
                darkPalette = edu.washington.riekelab.chris.utils.pmkmp( ...
                    numel(uniqueDark), 'CubicL');
            else
                darkPalette = [0 0 0];
            end
            colors = zeros(size(obj.stimSequence, 1), 3);
            for k = 1:size(obj.stimSequence, 1)
                colors(k, :) = darkPalette(uniqueDark == darkValues(k), :);
            end

            obj.showFigure('edu.washington.riekelab.chris.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'groupBy',{'currentBarWidth','currentBrightContrast','currentDarkContrast','currentTemporalFrequency'},...
                'sweepColor',colors);

            % F1/F2 against negative contrast, the online counterpart of
            % analyzeCenterContrastReversingGrating section 3.
            obj.showFigure('edu.washington.riekelab.chris.figures.ContrastReversingHarmonicsFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'preTime',obj.preTime,'stimTime',obj.stimTime);
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);

            % Determine current stimulus parameters
            stimIndex = mod(obj.numEpochsCompleted, size(obj.stimSequence, 1)) + 1;
            obj.currentBarWidth = obj.stimSequence(stimIndex, 1);
            obj.currentBrightContrast = obj.stimSequence(stimIndex, 2);
            obj.currentDarkContrast = obj.stimSequence(stimIndex, 3);
            obj.currentTemporalFrequency = obj.stimSequence(stimIndex, 4);

            epoch.addParameter('currentBarWidth', obj.currentBarWidth);
            epoch.addParameter('currentBrightContrast', obj.currentBrightContrast);
            epoch.addParameter('currentDarkContrast', obj.currentDarkContrast);
            epoch.addParameter('currentTemporalFrequency', obj.currentTemporalFrequency);

            % Pre-compute grating matrices for frame-by-frame updates
            obj.precomputeGratingMatrices();
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);

            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);

            % Initial image: at t=0 cos=1 (positive), bright bars at bright peak, dark bars at dark trough
            Ap = obj.currentBrightContrast;
            An = abs(obj.currentDarkContrast);
            initImage = obj.meanImage + obj.brightMaskScaled * Ap + obj.darkMaskScaled * (-An);
            initialImage = uint8(max(0, min(255, round(initImage * 255))));
            obj.gratingImage = initialImage;
            initImage = obj.meanImage + obj.brightMaskScaled * (-An) + obj.darkMaskScaled * Ap;
            initialImage = uint8(max(0, min(255, round(initImage * 255))));
            obj.gratingImageInv = initialImage;
%             numPts = (obj.preTime+obj.stimTime+obj.tailTime)*1e-3*obj.sampleRate;
%             tme = [1:numPts]/obj.sampleRate - obj.preTime*1e-3;            
%             obj.gratePolarity = sign(cos(2 * pi * obj.currentTemporalFrequency *tme));
                        
            scene = stage.builtin.stimuli.Image(initialImage);
            scene.size = canvasSize;
            scene.position = canvasSize/2;
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);

            % Frame-by-frame imageMatrix controller for contrast reversal
            sceneController = stage.builtin.controllers.PropertyController(scene, 'imageMatrix', ...
                @(state) obj.getGratingFrame(state.time-obj.preTime*1e-3));
            p.addController(sceneController);

            % Control visibility during stimTime only
            sceneVisible = stage.builtin.controllers.PropertyController(scene, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(sceneVisible);

            % Add center spot
            spot = stage.builtin.stimuli.Ellipse();
            spot.position = canvasSize/2;
            spot.radiusX = apertureDiameterPix/2;
            spot.radiusY = apertureDiameterPix/2;
            spot.color = obj.spotIntensity;
            p.addStimulus(spot);

            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
        end

        function precomputeGratingMatrices(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            currentBarWidthPix = obj.rig.getDevice('Stage').um2pix(obj.currentBarWidth);
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);

            % Create coordinate system
            [x, y] = meshgrid(linspace(-canvasSize(1)/2, canvasSize(1)/2, canvasSize(1)/obj.downSample), ...
                              linspace(-canvasSize(2)/2, canvasSize(2)/2, canvasSize(2)/obj.downSample));

            % Create square wave grating spatial pattern
            grating = sign(sin(2*pi*x/currentBarWidthPix));
            brightBars = (grating > 0);
            darkBars = (grating <= 0);

            % Create annular mask
            r = sqrt(x.^2 + y.^2);
            annulusMask = (r >= annulusInnerDiameterPix/2) & (r <= annulusOuterDiameterPix/2);

            % Asymmetric contrast-reversing grating, square-wave in time.
            %
            % getGratingFrame switches on sign(cos(2*pi*f*t)), so the grating
            % only ever shows two images and each bar sits at one of its two
            % peaks -- it does not sweep through background. Written as the
            % waveform the display actually produces, for one set of bars:
            %
            %   cos >= 0: intensity = background * (1 + brightBarContrast)
            %   cos <  0: intensity = background * (1 - |darkBarContrast|)
            %
            % The other set of bars is the same waveform a half cycle later, so
            % at any instant one set is at its bright peak while the other is at
            % its dark trough. The asymmetry between the two peaks is the point
            % of the protocol: a linear receptive field cancels the two bars
            % only at the dark contrast that balances the bright one.

            % Mean image: background everywhere
            obj.meanImage = obj.backgroundIntensity * ones(size(grating));

            % Pre-scaled masks: background intensity at bar pixels in annulus
            obj.brightMaskScaled = zeros(size(grating));
            obj.brightMaskScaled(brightBars & annulusMask) = obj.backgroundIntensity;

            obj.darkMaskScaled = zeros(size(grating));
            obj.darkMaskScaled(darkBars & annulusMask) = obj.backgroundIntensity;

            % Warn if peak modulation would produce out-of-range values
            peakHigh = obj.backgroundIntensity * (1 + obj.currentBrightContrast);
            peakLow  = obj.backgroundIntensity * (1 - abs(obj.currentDarkContrast));
            if peakHigh > 1 || peakLow < 0
                warning('Grating intensity out of range: bright peak = %.3f, dark peak = %.3f', ...
                    peakHigh, peakLow);
            end
        end

        function imgMat = getGratingFrame(obj, time)
            % time is measured from stimulus onset, so cos = 1 at t = 0 and the
            % first half cycle must be gratingImage -- bright bars at the bright
            % peak, which is what gratingImage was built to be. The test was
            % inverted, which put the stimulus a half cycle out of phase with
            % its own definition and flipped the sign of the half-cycle
            % difference the offline analysis stores as resp_mean.
            s = sign(cos(2 * pi * obj.currentTemporalFrequency * time));
            if (s >= 0)
                imgMat = obj.gratingImage;
            else
                imgMat = obj.gratingImageInv;
            end
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages * size(obj.stimSequence, 1);
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages * size(obj.stimSequence, 1);
        end
    end
end

classdef spotWithAnnularGrating < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    properties
        apertureDiameter = 300   % um (center spot)
        annulusInnerDiameter = 400  % um
        annulusOuterDiameter = 800  % um
        barWidth = [30 60]  % um
        
        backgroundIntensity = 0.15  % 0-1, background and gap intensity
        spotIntensity = 0.05  % 0-1, intensity of center spot
        brightBarContrast = [0.9]  % contrast for bright bars
        darkBarContrast = [-0.25 -0.5 -0.75 -1.0]  % contrast for dark bars
        
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
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
        currentBarWidth
        currentBrightContrast
        currentDarkContrast
        stimSequence
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
                        obj.stimSequence = [obj.stimSequence; ...
                            obj.barWidth(bw), obj.brightBarContrast(bc), obj.darkBarContrast(dc)];
                    end
                end
            end
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.chris.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
            
            if length(obj.stimSequence) > 1
                colors = edu.washington.riekelab.chris.utils.pmkmp(length(obj.stimSequence),'CubicYF');
            else
                colors = [0 0 0];
            end
            
            obj.showFigure('edu.washington.riekelab.chris.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis',...
                'groupBy',{'currentBarWidth','currentBrightContrast','currentDarkContrast'},...
                'sweepColor',colors);
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
            
            epoch.addParameter('currentBarWidth', obj.currentBarWidth);
            epoch.addParameter('currentBrightContrast', obj.currentBrightContrast);
            epoch.addParameter('currentDarkContrast', obj.currentDarkContrast);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);
            annulusInnerDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.annulusOuterDiameter);
            currentBarWidthPix = obj.rig.getDevice('Stage').um2pix(obj.currentBarWidth);
            
            % Create the annular grating image
            gratingImage = obj.createAnnularGrating(canvasSize, apertureDiameterPix, ...
                annulusInnerDiameterPix, annulusOuterDiameterPix, currentBarWidthPix);
            
            % Display grating as image stimulus
            scene = stage.builtin.stimuli.Image(gratingImage);
            scene.size = canvasSize;
            scene.position = canvasSize/2;
            scene.setMinFunction(GL.LINEAR);
            scene.setMagFunction(GL.LINEAR);
            p.addStimulus(scene);
            
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
        
        function gratingImage = createAnnularGrating(obj, canvasSize, apertureDiameterPix, ...
                annulusInnerDiameterPix, annulusOuterDiameterPix, currentBarWidthPix)
            
            % Create coordinate system
            [x, y] = meshgrid(linspace(-canvasSize(1)/2, canvasSize(1)/2, canvasSize(1)/obj.downSample), ...
                              linspace(-canvasSize(2)/2, canvasSize(2)/2, canvasSize(2)/obj.downSample));
            
            % Create square wave grating
            grating = sign(sin(2*pi*x/currentBarWidthPix));
            
            % Apply contrasts to bright and dark bars
            brightBars = (grating > 0);
            darkBars = (grating <= 0);
            
            gratingImage = obj.backgroundIntensity * ones(size(grating));
            gratingImage(brightBars) = obj.backgroundIntensity * (1 + obj.currentBrightContrast);
            gratingImage(darkBars) = obj.backgroundIntensity * (1 + obj.currentDarkContrast);
            
            % Create annular mask
            [x, y] = meshgrid(linspace(-canvasSize(1)/2, canvasSize(1)/2, canvasSize(1)/obj.downSample), ...
                              linspace(-canvasSize(2)/2, canvasSize(2)/2, canvasSize(2)/obj.downSample));
            r = sqrt(x.^2 + y.^2);
            
            annulusMask = (r >= annulusInnerDiameterPix/2) & (r <= annulusOuterDiameterPix/2);
            
            % Apply mask: grating in annulus, background elsewhere
            finalImage = obj.backgroundIntensity * ones(size(gratingImage));
            finalImage(annulusMask) = gratingImage(annulusMask);
            
            % Check for out of range values and warn
            if max(finalImage(:)) > 1 || min(finalImage(:)) < 0
                warning('Image intensity out of range: max = %.3f, min = %.3f', ...
                    max(finalImage(:)), min(finalImage(:)));
            end
            
            % Convert to uint8
            gratingImage = uint8(finalImage * 255);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages * size(obj.stimSequence, 1);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages * size(obj.stimSequence, 1);
        end
    end
end
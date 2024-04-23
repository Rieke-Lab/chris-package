classdef variableMeanFlash < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % Presents a set of single spot stimuli to a Stage canvas and records from the specified amplifier.
    
    properties
        amp                             % Output amplifier
        preTime = 600                   % Spot leading duration (ms)
        stimTime = 200                  % Spot duration (ms)
        tailTime = 400                  % Spot trailing duration (ms)
        spotDiameter = 2000              % Spot diameter size (um)
        apertureDiameter=300
        flashContrast = [ -0.04 -0.08 -0.16 -0.02 0 0.02 0.04 0.08 0.16 ]
        meanIntensity = [0.03 0.06 0.12 0.18 0.24 0.36 0.54]       % Background light intensity (0-1)
        numberOfAverages = uint16(10)    % Number of epochs
        interpulseInterval = 0          % Duration between spots (s)
    end
    
    properties (Hidden)
        ampType
        currentMean
        currentContrast
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            % add the progress bar.
            obj.showFigure('edu.washington.riekelab.figures.FrameTimingFigure', obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            % compute the index of intensity and contrast
            obj.currentContrast=obj.flashContrast(randi(length(obj.flashContrast)));
            obj.currentMean=obj.meanIntensity(randi(length(obj.meanIntensity)));
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
            epoch.addParameter('currentMean', obj.currentMean)
            epoch.addParameter('currentContrast',obj.currentContrast)
        end
        
        
        function p = createPresentation(obj)
            try
                device = obj.rig.getDevice('Stage');
                canvasSize = device.getCanvasSize();
                
                spotDiameterPix = device.um2pix(obj.spotDiameter);
                apertureDiameterPix = obj.rig.getDevice('Stage').um2pix(obj.apertureDiameter);

                p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
                p.setBackgroundColor(obj.currentMean);
                
                spot = stage.builtin.stimuli.Ellipse();
                spot.color = obj.currentMean*(1+obj.currentContrast);
                spot.radiusX = spotDiameterPix/2;
                spot.radiusY = spotDiameterPix/2;
                spot.position = canvasSize/2;
                p.addStimulus(spot);
                spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(spotVisible);
                if (obj.apertureDiameter > 0) %% Create aperture
                    aperture = stage.builtin.stimuli.Rectangle();
                    aperture.position = canvasSize/2;
                    aperture.color = 0;
                    aperture.size = [max(canvasSize) max(canvasSize)];
                    mask = stage.core.Mask.createCircularAperture(apertureDiameterPix/max(canvasSize), 1024); %circular aperture
                    aperture.setMask(mask);
                    p.addStimulus(aperture); %add aperture
                end
            catch ME
                disp(getReport(ME));
            end
        end
        

        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.meanIntensity)*numel(obj.flashContrast);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.meanIntensity)*numel(obj.flashContrast);
        end
        
    end
    
end
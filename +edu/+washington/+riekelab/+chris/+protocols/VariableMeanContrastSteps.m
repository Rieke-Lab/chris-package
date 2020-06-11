classdef VariableMeanContrastSteps < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties
        led                             % Output LED
        preTime = 1000                   % Pulse leading duration (ms)
        stimTime = 100                 % Pulse duration (ms)
        tailTime = 1000                  % Pulse trailing duration (ms)
        lightContrast = [-100 -50 -25 -10 10 25 50 ]  % in percent
        lightMean = [0.02 0.5]          % LED background mean (V or norm. [0-1] depending on LED units)                           % Input amplifier
        numberOfAverages = uint16(3)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
        amp
        onlineAnalysis = 'extracellular'% Type of online analysis

    end
    
    properties (Hidden)
        ledType
        ampType
        contrastsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'})
                
    end

    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
%             
%             obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
%                 'groupBy', {'currentMean','currentContrast'});
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            
            if ~strcmp(obj.onlineAnalysis,'none')
                obj.showFigure('edu.washington.riekelab.chris.figures.VariableMeanContrastFigure',...
                    obj.rig.getDevice(obj.amp),obj.lightMean,obj.lightContrast,...
                    'recordingType',obj.onlineAnalysis,'preTime',obj.preTime,...
                    'stimTime',obj.stimTime,'tailTime',obj.tailTime);
            end
              device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lightMean(1), device.background.displayUnits);
        end
        
        function [stim, lightMean, lightContrast] = createLedStimulus(obj)
            lightMean = obj.lightMean(randi([1 length(obj.lightMean)]));
            lightContrast = obj.lightContrast(randi([1 length(obj.lightContrast)]))/100;
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude =lightMean*lightContrast;

            gen.mean = lightMean;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
            
            stim = gen.generate();
            
        end
        
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);          
            [stim, currentMean,currentContrast] = obj.createLedStimulus();
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));          
            epoch.addParameter('currentMean', currentMean);
            epoch.addParameter('currentContrast', currentContrast);
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages*numel(obj.lightMean)*numel(obj.lightContrast);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages*numel(obj.lightMean)*numel(obj.lightContrast);
        end    
    end
   
end
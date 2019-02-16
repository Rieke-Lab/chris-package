classdef VariableMeanNoiseCurInject < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Injects segments of gaussian noise stimuli while randomly varying mean and SD.  
    
    properties
        stimTime = 500                  % Noise duration (ms)
        frequencyCutoff = 200            % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing
        currentSD = [500 1500]                  % current SD
        useRandomSeed = true            % Use a random seed for each standard deviation multiple?
        currentMean = [-500 0 500]       % mean current 
        amp                             % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end
    
    properties 
        numberOfAverages = uint16(5)    % Number of families
        interpulseInterval = 0          % Duration between noise stimuli (s)
    end
    
    properties (Hidden)
        ampType
    end
    
    methods
                
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);
            
            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()createPreviewStimuli(obj));
            function s = createPreviewStimuli(obj)
                s = cell(1, obj.numberOfAverages);
                for i = 1:numel(s)
                    if obj.useRandomSeed
                        seed = RandStream.shuffleSeed;
                    else
                        seed = 0;
                    end
                    s{i} = obj.createNoiseStimulus(i, seed);
                end
            end
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                    'groupBy', {'stdv'});
                obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, ...
                    'baselineRegion', [0 obj.stimTime], ...
                    'measurementRegion', [0 obj.stimTime]);
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2), ...
                    'groupBy1', {'stdv'}, ...
                    'groupBy2', {'stdv'});
                obj.showFigure('edu.washington.riekelab.figures.DualResponseStatisticsFigure', obj.rig.getDevice(obj.amp), {@mean, @var}, obj.rig.getDevice(obj.amp2), {@mean, @var}, ...
                    'baselineRegion1', [0 obj.stimTime], ...
                    'measurementRegion1', [0 obj.stimTime], ...
                    'baselineRegion2', [0 obj.stimTime], ...
                    'measurementRegion2', [0 obj.stimTime]);
            end
            
        end
        
        function [stim, stdv] = createNoiseStimulus(obj, pulseNum, seed)
            currentMean = obj.currentMean(randi([1 length(obj.currentMean)]));
            stdv = obj.currentSD(randi([1 length(obj.currentSD)]));
            
            gen = edu.washington.riekelab.stimuli.GaussianNoiseGeneratorV2();
            
            gen.preTime = 0;
            gen.stimTime = obj.stimTime;
            gen.tailTime = 0;
            gen.stDev = stdv;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = currentMean;
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.amp).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            persistent seed;
            if obj.useRandomSeed
                seed = RandStream.shuffleSeed;
            else
                seed = 0;
            end
            
            [stim, stdv] = obj.createNoiseStimulus(obj.numEpochsPrepared, seed);
            
            epoch.addParameter('stdv', stdv);
            epoch.addParameter('seed', seed);
            epoch.addStimulus(obj.rig.getDevice(obj.amp), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
        function a = get.amp2(obj)
            amps = obj.rig.getDeviceNames('Amp');
            if numel(amps) < 2
                a = '(None)';
            else
                i = find(~ismember(amps, obj.amp), 1);
                a = amps{i};
            end
        end
        
    end
    
end


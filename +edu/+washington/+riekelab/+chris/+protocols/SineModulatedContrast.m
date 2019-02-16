classdef SineModulatedContrast < edu.washington.riekelab.protocols.RiekeLabProtocol

    % Presents a gaussian noise stimulus with amplitude modulated by a sine wave.
    
        
    properties
        led                             % Output LED
        
        lum = .5;                       % Mean luminance 
        contr = .36;                    % Contrast at peak of sinewave modulation
        sinFreq = 2;                    % Frequency of sinewave modulation (Hz)
        cyclesPerEpoch = 1;             % Cycles of sine stim in each epoch
        numEpochs = uint16(25)          % Number of epochs

        frequencyCutoff = 400           % Noise frequency cutoff for smoothing (Hz)
        numberOfFilters = 4             % Number of filters in cascade for noise smoothing

        amp                             % Input amplifier

        binSize = 50;                   % Size of histogram bin for PSTH (ms)
        numEpochsAvg = uint16(50);      % Number of epochs to average for each PSTH trace
        numAvgsPlot = uint16(3);        % Number of PSTHs to keep on plot

    end
    
    
    properties (Hidden)
        ledType
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()obj.createLedStimulus());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.weber.figures.SwitchingPeriodBasicFigure',obj.rig.getDevice(obj.amp),obj.binSize,obj.numEpochsAvg,obj.numAvgsPlot,obj.numEpochs);
           
            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement(obj.lum, device.background.displayUnits);
        end
        
        function [stim,seed] = createLedStimulus(obj, epochNum)
            
            gen = edu.washington.riekelab.weber.stimuli.SineModulatedNoiseGenerator();
            
            seed = RandStream.shuffleSeed;
            
            gen.preTime = 0; 
            gen.tailTime = 0;

            gen.stDev = obj.contr*obj.lum;
            gen.stimTime = 1/obj.sinFreq * obj.cyclesPerEpoch * 1000; % ms
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.sinFreq = obj.sinFreq;
            gen.mean = obj.lum;
            gen.seed = seed;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
                       
            stim = gen.generate();
            
        end
                
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            epochNum = obj.numEpochsPrepared;
            [stim,seed] = obj.createLedStimulus(epochNum);

            epoch.addParameter('seed', seed);
            epoch.addStimulus(obj.rig.getDevice(obj.led), stim);
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numEpochs;
        end
                

    end
    
end


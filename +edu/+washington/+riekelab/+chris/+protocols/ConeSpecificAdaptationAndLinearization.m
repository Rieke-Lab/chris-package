classdef ConeSpecificAdaptationAndLinearization <edu.washington.riekelab.protocols.RiekeLabProtocol
    properties
        % the values could be drawn from Isomerization converter on each
        % rig
        redLedIsomPerUnitL=1000;  % L cone isomerization per unit either normalized [0 1] or perVolt by red Led with given settings
        redLedIsomPerUnitM=1000;  % M cone isomerization per unit either normalized [0 1] or perVolt by red Led with given settings
        redLedIsomPerUnitS=1000;  % S cone isomerization per unit either normalized [0 1] or perVolt by red Led with given settings
        blueLedIsomPerUnitL=1000;  % L cone isomerization per unit either normalized [0 1] or perVolt by blue Led with given settings
        blueLedIsomPerUnitM=1000;  % M cone isomerization per unit either normalized [0 1] or perVolt by blue Led with given settings
        blueLedIsomPerUnitS=1000;  % S cone isomerization per unit either normalized [0 1] or perVolt by blue Led with given settings
        uvLedIsomPerUnitL=1000;  % L cone isomerization per unit either normalized [0 1] or perVolt by uv Led with given settings
        uvLedIsomPerUnitM=1000;  % M cone isomerization per unit either normalized [0 1] or perVolt by uv Led with given settings
        uvLedIsomPerUnitS=1000;  % S cone isomerization per unit either normalized [0 1] or perVolt by uv Led with given settings
        constantConeBackground=2000;  % isommerization
        coneOnChangingBackgroundToStim=edu.washington.riekelab.chris.protocols.ConeSpecificAdaptationModulatedLuminanceSteps.M_CONE;
        numberOfAverage=unit16(5);
        onlineAnalysis='none';
        amp;
        inputFrameRate=60;
        interpulseInterval=0;
    end
    properties(Hidden)
        coneOnConstantToStimulateType = symphonyui.core.PropertyType( ...
            'char', 'row', edu.washington.riekelab.chris.protocols.ConeSpecificAdaptationSinusoidsContrast.CONE_TYPES_LMS)
        coneForChangingBackgroundsType = symphonyui.core.PropertyType( ...
            'char', 'row', edu.washington.riekelab.chris.protocols.ConeSpecificAdaptationSinusoidsContrast.CONE_TYPES_LMS)
        ampType
        onlineAnalysisType=symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'exc', 'inh'});
        ResourceFolderPath = 'C:\Users\Public\Documents\baudin-package\+edu\+washington\+riekelab\+baudin\+resources\'
        adaptingWaveform
        stimulusDataPath = 'grating_plus_mean'; % string of path to
        stimulusDurationSeconds
    end
    properties (Hidden, Dependent)
        rguToLms
        lmsToRgu
        redLed
        blueLed
        uvLed
    end
    properties (Constant)
        RED_LED = 'Red LED';
        BLUE_LED = 'Blue LED';
        UV_LED = 'UV LED';
        S_CONE = 's cone';
        M_CONE = 'm cone';
        L_CONE = 'l cone';
        CONE_TYPES_LMS = {edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsContrast.L_CONE, ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsContrast.M_CONE, ...
            edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsContrast.S_CONE};
    end
    
    methods
        function value=get.rguToLms(obj)
            value=[obj.redLedIsomPerUnitL obj.blueLedIsomPerUnitL obj.uvLedIsoPerUnitL; ...;
                obj.redLedIsomPerUnitM obj.blueLedIsomPerUnitM obj.uvLedIsoPerUnitM; ...;
                obj.redLedIsomPerUnitS obj.blueLedIsomPerUnitS obj.uvLedIsoPerUnitS];
        end
        function value=get.lmsToRgu(obj)
            value=inv(obj.rgu2Lms);
        end
        
        function value = get.redLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.chris.protocols.ConeSpecificAdaptationSinusoidsContrast.RED_LED);
        end
        
        function value = get.blueLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.chris.protocols.ConeSpecificAdaptationSinusoidsContrast.BLUE_LED);
        end
        
        function value = get.uvLed(obj)
            value = obj.rig.getDevice(edu.washington.riekelab.chris.protocols.ConeSpecificAdaptationSinusoidsContrast.UV_LED);
        end
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
   
        function constructStimuli(obj)
            obj.stimuli = struct;
            obj.stimuli.names = {'stepCorrected', ...
                'stepUncorrected', ...
                'spotCorrected', ...
                'spotUncorrected' ...
                'spotCorrectedLowContrast' ...
                'spotUncorrectedLowContrast'};
            stimulusData = load(strcat(obj.ResourceFolderPath, obj.stimulusDataPath));
            obj.backgroundIsomerizations = stimulusData.stepCorrected(1);
            obj.stimuli.lookup = containers.Map(obj.stimuli.names, ...
                {stimulusData.stepCorrected, stimulusData.stepUncorrected, stimulusData.spotCorrected, ...
                stimulusData.spotUncorrected, stimulusData.spotCorrectedLowContrast, stimulusData.spotUncorrectedLowContrast});
        end      
        
        function stim = createLedStimulus(obj,device,waveform)
            gen = symphonyui.builtin.stimuli.WaveformGenerator();
            % sample the input to match the sampling rate of stimulus
            % device
            gen.waveshape=resample(waveform, gen.sampleRate, obj.inputFrameRate);
            gen.sampleRate=obj.sampleRate;
            gen.units=device.background.displayUnits;
            stim = gen.generate();
        end
        
        function [lmsWaves,coneWithStimulus] = getLmsWaves(obj, index)
            obj.adaptingWaveform=obj.stimuli.lookup(obj.stimuli.names{index});   
            lmsTypes = edu.washington.riekelab.baudin.protocols.ConeSpecificAdaptationSinusoidsContrast.CONE_TYPES_LMS;
            lmsWaves =  repmat(obj.constantConeBackground * cellfun(@(x) ~strcmp(x, obj.coneForChangingBackgrounds), ...,
            lmsTypes)',1,length(obj.adaptingWaveform))+ ...,
                + bsxfun(@times, obj.adaptingWaveform,cellfun(@(x) strcmp(x, obj.coneForChangingBackgrounds), lmsTypes)');
                       isCorrectConeType = @(x) strcmp(x, obj.coneOnConstantToStimulate) ...
                || (~strcmp(x, obj.coneForChangingBackgrounds));
            coneWithStimulus = lmsTypes{cellfun(isCorrectConeType, lmsTypes)};
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            if strcmp(obj.coneOnConstantToStimulate, obj.coneForChangingBackgrounds)
                error('Cone to stimulate and cone for changing backgrounds cannot be the same');
            end
            obj.constructStimuli();
            colors = edu.washington.riekelab.turner.utils.pmkmp(length(obj.stimuli.names)+2,'CubicYF');

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...,
                'recordingType',obj.onlineAnalysis,'groupBy',{'stimulus type'},...
                'sweepColor',colors);
            
            rguBackgrounds=obj.lmsToRgu * obj.getLmsWaves(1);
            rguBackgrounds=rguBackgrounds(:,1);
            obj.redLed.background = symphonyui.core.Measurement(rguBackgrounds(1), obj.redLed.background.displayUnits);
            obj.blueLed.background = symphonyui.core.Measurement(rguBackgrounds(2), obj.greenLed.background.displayUnits);
            obj.uvLed.background = symphonyui.core.Measurement(rguBackgrounds(3), obj.uvLed.background.displayUnits);
        end
 
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            epochNumber = obj.numEpochsCompleted; 
            index=mod(epochNumber,length(obj.stimuli.names))+1;
            [lmsWaves,coneWithStimulus]=obj.getLmsWaves(obj, index);
            rguWaves=obj.lmsToRgu*lmsWaves;
            epoch.addParameter('coneWithAdapting', coneWithStimulus);
            epoch.addStimulus(obj.redLed, rguWaves(1,:));
            epoch.addStimulus(obj.greenLed, rguWaves(2,:));
            epoch.addStimulus(obj.uvLed, rguWaves(3,:));
            epoch.addResponse(obj.rig.getDevice(obj.amp));
            epoch.addParameter('stimulus type', obj.stimuli.names{index});
        end
              
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);  
            interval.addDirectCurrentStimulus( ...
                obj.redLed, obj.redLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus( ...
                obj.greenLed, obj.greenLed.background, obj.interpulseInterval, obj.sampleRate);
            interval.addDirectCurrentStimulus( ...
                obj.uvLed, obj.uvLed.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverage * numel(obj.stimuli.names);
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverage * numel(obj.stimuli.names);
        end
    end
end
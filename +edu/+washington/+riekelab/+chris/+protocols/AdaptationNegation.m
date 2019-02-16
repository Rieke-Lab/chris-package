classdef AdaptationNegation < edu.washington.riekelab.protocols.RiekeLabProtocol
    % Presents a stimulus as well as a modified version of the stimulus in an effort to undo time-dependent
    % adaptation of a cone in response to the modified stimulus.

    properties
        led                                 % Output LED
        stimulusPath = 'enter path here'    % Path of .mat file containing original and modified stimulus vectors
        isomPerVolt = 1000                  % Isomerizations per volt on currently selected LED
        amp                                 % Input amplifier
    end
    
    properties (Dependent, SetAccess = private)
        amp2                            % Secondary amplifier
    end

    properties
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between pulses (s)
    end

    properties (Hidden)
        ledType
        ampType
        stimulusPathType = symphonyui.core.PropertyType('char', 'row');
        originalGenerator
        modifiedGenerator
    end

    properties (Dependent, Hidden = true)
        totalEpochs
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);

            [obj.led, obj.ledType] = obj.createDeviceNamesProperty('LED');
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, name);

            if strncmp(name, 'amp2', 4) && numel(obj.rig.getDeviceNames('Amp')) < 2
                d.isHidden = true;
            end
        end

        function p = getPreview(obj, panel)
            obj.createStimulusGenerators();
            p = symphonyui.builtin.previews.StimuliPreview(panel, ...
                {@()obj.createLedStimulus(false), @()obj.createLedStimulus(true)});
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);

            obj.createStimulusGenerators();

            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
                obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), ...
                    'groupBy', {'stimulusType'});
            else
                obj.showFigure('edu.washington.riekelab.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2));
                obj.showFigure('edu.washington.riekelab.figures.DualMeanResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp2), ...
                    'groupBy1', {'stimulusType'}, ...
                    'groupBy2', {'stimulusType'});
            end



            device = obj.rig.getDevice(obj.led);
            device.background = symphonyui.core.Measurement( ...
                obj.originalGenerator.waveshape(1), device.background.displayUnits);
        end

        function createStimulusGenerators(obj)
            stimulusVectors = load(obj.stimulusPath);
            obj.originalGenerator = obj.createGenerator(stimulusVectors.original);
            obj.modifiedGenerator = obj.createGenerator(stimulusVectors.modified);
        end

        function gen = createGenerator(obj, vector)
            gen = symphonyui.builtin.stimuli.WaveformGenerator;
            gen.waveshape = vector / obj.isomPerVolt;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.led).background.displayUnits;
        end

        function stim = createLedStimulus(obj, useModified)
            if useModified
                stim = obj.modifiedGenerator.generate();
            else
                stim = obj.originalGenerator.generate();
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);

            % boolean to control whether or not modified stimulus vector is
            % used (every other epoch, so if epochNum is even)
            % useModified = iseven(obj.numEpochsPrepared);
            useModified = mod(obj.numEpochsPrepared, 2) == 0;
            if useModified
                epoch.addParameter('stimulusType', 'modified');
            else
                epoch.addParameter('stimulusType', 'original');
            end

            epoch.addStimulus(obj.rig.getDevice(obj.led), obj.createLedStimulus(useModified));
            epoch.addResponse(obj.rig.getDevice(obj.amp));

            if numel(obj.rig.getDeviceNames('Amp')) >= 2
                epoch.addResponse(obj.rig.getDevice(obj.amp2));
            end
        end

        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);

            device = obj.rig.getDevice(obj.led);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalEpochs;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalEpochs;
        end

        function val = get.totalEpochs(obj)
            val = double(obj.numberOfAverages) * 2;
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

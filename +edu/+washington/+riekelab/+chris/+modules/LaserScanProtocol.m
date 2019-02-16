classdef (Abstract) LaserScanProtocol < edu.washington.riekelab.protocols.RiekeLabProtocol
    properties
        sendScanTrigger = true
    end
    
    methods

        function stim = createScanTriggerStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = 0;
            gen.stimTime = obj.preTime + obj.stimTime + obj.tailTime - 1;
            gen.tailTime = 1;
            gen.amplitude = 1;
            gen.mean = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = symphonyui.core.Measurement.UNITLESS;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            triggers = obj.rig.getDevices('scanTrigger');
            if ~isempty(triggers)
                if (obj.sendScanTrigger)
                    epoch.addStimulus(triggers{1}, obj.createScanTriggerStimulus());
                end
            end
            scanNumber = triggers{1}.scanNumber;
            epoch.addParameter('scanNumber', scanNumber);
            disp(scanNumber)
            
            %advance the scan count:
            triggers{1}.scanNumber = triggers{1}.scanNumber + 1; 
        end
        
        
    end
    
end
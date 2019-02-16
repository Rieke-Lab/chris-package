classdef ConfocalTwoAmp < edu.washington.riekelab.rigs.Confocal
    
    methods
        
        function obj = ConfocalTwoAmp()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            % Remove device bound to the analog output 1 channel
            for i = 1:numel(obj.devices)
                dev = obj.devices{i};
                s = dev.getOutputStreams();
                if ~isempty(s) && strcmp(s{1}.name, 'ao1')
                    dev.unbindStream('ao1');
                    obj.removeDevice(dev);
                    break;
                end
            end
            
            amp2 = MultiClampDevice('Amp2', 2).bindStream(daq.getStream('ao1')).bindStream(daq.getStream('ai3'));
            obj.addDevice(amp2);
        end
        
    end
    
end


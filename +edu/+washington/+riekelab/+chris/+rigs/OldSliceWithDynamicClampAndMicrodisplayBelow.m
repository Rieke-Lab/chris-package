classdef OldSliceWithDynamicClampAndMicrodisplayBelow < edu.washington.riekelab.rigs.OldSliceWithMicrodisplayBelow
    
    methods
        
        function obj = OldSliceWithDynamicClampAndMicrodisplayBelow()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = HekaDaqController();
            obj.daqController = daq;

            %DYNAMIC CLAMP STUFF
            currentInjected = UnitConvertingDevice('Injected current', 'V').bindStream(obj.daqController.getStream('ANALOG_IN.1'));
            obj.addDevice(currentInjected);
            
            gExc = UnitConvertingDevice('Excitatory conductance', 'V').bindStream(daq.getStream('ANALOG_OUT.2'));
            obj.addDevice(gExc);
            gInh = UnitConvertingDevice('Inhibitory conductance', 'V').bindStream(daq.getStream('ANALOG_OUT.3'));
            obj.addDevice(gInh);
            
        end
        
    end
end


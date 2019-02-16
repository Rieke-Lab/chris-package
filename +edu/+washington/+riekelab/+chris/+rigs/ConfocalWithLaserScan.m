classdef ConfocalWithLaserScan < edu.washington.riekelab.rigs.Confocal
    
    methods
        
        function obj = ConfocalWithLaserScan()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;
            
            scan = UnitConvertingDevice('Scan Trigger', Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(scan, 1);
            obj.addDevice(scan);   
        end
        
    end
    
end


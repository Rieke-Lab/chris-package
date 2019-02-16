classdef ConfocalWithPicospritzer < edu.washington.riekelab.rigs.Confocal
    
    properties (Constant)
        PICOSPRITZER = 'Picospritzer'
    end
        
    methods
        function obj = ConfocalWithPicospritzer()
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = obj.daqController;     
            
            picosprizter = UnitConvertingDevice( ...
                edu.washington.riekelab.baudin.rigs.ConfocalWithPicospritzer.PICOSPRITZER, ...
                Measurement.UNITLESS).bindStream(daq.getStream('DIGITAL_OUT.1'));
            daq.getStream('DIGITAL_OUT.1').setBitPosition(picosprizter, 1);
            obj.addDevice(picosprizter);   
        end
        
    end
    
end


classdef ScanTriggerDevice < symphonyui.core.Device
    % Device for TTL scan triggering
    
    properties (SetObservable)
        scanNumber = 1
    end
    
    methods
        
        function obj = ScanTriggerDevice()
            
            cobj = Symphony.Core.UnitConvertingExternalDevice('scanTrigger', 'none', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
        end

        
    end
    
end


classdef OldSliceWithDynamicClampAndGreenLed < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = OldSliceWithDynamicClampAndGreenLed()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            import edu.washington.*;
            
            daq = HekaDaqController();
            obj.daqController = daq;
            
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);
            
            temperature = UnitConvertingDevice('Temperature Controller', 'V', 'manufacturer', 'Warner Instruments').bindStream(daq.getStream('ai6'));
            obj.addDevice(temperature);
            
            trigger = UnitConvertingDevice('Oscilloscope Trigger', Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(trigger, 0);
            obj.addDevice(trigger);
            
            %DYNAMIC CLAMP STUFF
            currentInjected = UnitConvertingDevice('Injected current', 'V').bindStream(obj.daqController.getStream('ai1'));
            obj.addDevice(currentInjected);
            
            gExc = UnitConvertingDevice('Excitatory conductance', 'V').bindStream(daq.getStream('ao2'));
            obj.addDevice(gExc);
            gInh = UnitConvertingDevice('Inhibitory conductance', 'V').bindStream(daq.getStream('ao3'));
            obj.addDevice(gInh);
            
            % add green led
            green = UnitConvertingDevice('Green LED', 'V').bindStream(daq.getStream('ao1'));
            green.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'F1', 'F2', 'F3', 'F4', 'F5', 'F8', 'F9', 'F12'}));
            green.addResource('ndfAttenuations', containers.Map( ...
                {'F1', 'F2', 'F3', 'F4', 'F5', 'F8', 'F9', 'F12'}, ...
                {0.3059, 0.2862, 0.5869, 1.0955, 1.9804, 1.8555, 3.6936, 3.6}));
            green.addConfigurationSetting('gain', '', ...
                'type', PropertyType('char', 'row', {'', 'low', 'medium', 'high'}));
            green.addResource('fluxFactorPaths', containers.Map( ...
                {'low', 'medium', 'high'}, { ...
                riekelab.Package.getCalibrationResource('rigs', 'old_slice', 'green_led_low_flux_factors.txt'), ...
                riekelab.Package.getCalibrationResource('rigs', 'old_slice', 'green_led_medium_flux_factors.txt'), ...
                riekelab.Package.getCalibrationResource('rigs', 'old_slice', 'green_led_high_flux_factors.txt')}));
            green.addConfigurationSetting('lightPath', '', ...
                'type', PropertyType('char', 'row', {'', 'below', 'above'}));
            green.addResource('spectrum', importdata(riekelab.Package.getCalibrationResource('rigs', 'old_slice', 'green_led_spectrum.txt')));
            obj.addDevice(green);
        end
        
    end
    
end
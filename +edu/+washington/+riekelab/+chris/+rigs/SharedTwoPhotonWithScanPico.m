classdef SharedTwoPhotonWithScanPico < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = SharedTwoPhotonWithScanPico()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            import edu.washington.*;
            
            daq = HekaDaqController();
            obj.daqController = daq;
            
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);
            
            uvRamp = importdata(riekelab.Package.getCalibrationResource('rigs', 'shared_two_photon', 'uv_led_gamma_ramp.txt'));
            uv = CalibratedDevice('UV LED', Measurement.NORMALIZED, uvRamp(:, 1), uvRamp(:, 2)).bindStream(daq.getStream('ao2'));
            uv.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'G1', 'G2', 'G3', 'G4', 'G6', 'G7', 'G8', 'G9'}));
            uv.addResource('ndfAttenuations', containers.Map( ...
                {'G1', 'G2', 'G3', 'G4', 'G6', 'G7', 'G8', 'G9'}, ...
                {1.0060, 1.0524, 2.1342, 2.6278, 0.28, 0.59, 1.25, 2.23}));
            uv.addResource('fluxFactorPaths', containers.Map( ...
                {'none'}, {riekelab.Package.getCalibrationResource('rigs', 'shared_two_photon', 'uv_led_flux_factors.txt')}));
            uv.addConfigurationSetting('lightPath', '', ...
                'type', PropertyType('char', 'row', {'', 'below', 'above'}));
            uv.addResource('spectrum', importdata(riekelab.Package.getCalibrationResource('rigs', 'shared_two_photon', 'uv_led_spectrum.txt')));          
            obj.addDevice(uv);
            
            temperature = UnitConvertingDevice('Temperature Controller', 'V', 'manufacturer', 'Warner Instruments').bindStream(daq.getStream('ai6'));
            obj.addDevice(temperature);
            
            trigger = UnitConvertingDevice('Oscilloscope Trigger', Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(trigger, 0);
            obj.addDevice(trigger);
            
            scanTrigger = edu.washington.riekelab.turner.devices.ScanTriggerDevice();
            scanTrigger.bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(scanTrigger, 1);
            obj.addDevice(scanTrigger);
            
            picosprizter = UnitConvertingDevice('Picospritzer', Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(picosprizter, 2);
            obj.addDevice(picosprizter);
            
        end
        
    end
    
end


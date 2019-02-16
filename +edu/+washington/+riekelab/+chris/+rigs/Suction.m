classdef Suction < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = Suction()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            import edu.washington.*;
            
            daq = HekaDaqController();
            obj.daqController = daq;
            
            amp1 = AxopatchDevice('Amp1').bindStream(daq.getStream('ao0'));
            amp1.bindStream(daq.getStream('ai0'), AxopatchDevice.SCALED_OUTPUT_STREAM_NAME);
            amp1.bindStream(daq.getStream('ai1'), AxopatchDevice.GAIN_TELEGRAPH_STREAM_NAME);
            amp1.bindStream(daq.getStream('ai2'), AxopatchDevice.MODE_TELEGRAPH_STREAM_NAME);
            obj.addDevice(amp1);
            
            uvRamp = importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'uv_led_gamma_ramp.txt'));
            uv = CalibratedDevice('UV LED', Measurement.NORMALIZED, uvRamp(:, 1), uvRamp(:, 2)).bindStream(daq.getStream('ao1'));
            uv.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'C1', 'C2', 'C3', 'C4', 'C5'}));
            uv.addResource('ndfAttenuations', containers.Map( ...
                {'C1', 'C2', 'C3', 'C4', 'C5'}, ...
                {0.2768, 0.5076, 0.9281, 2.1275, 2.5022}));
            uv.addResource('fluxFactorPaths', containers.Map( ...
                {'none'}, {riekelab.Package.getCalibrationResource('rigs', 'suction', 'uv_led_flux_factors.txt')}));
            uv.addConfigurationSetting('lightPath', '', ...
                'type', PropertyType('char', 'row', {'', 'below', 'above'}));
            uv.addResource('spectrum', importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'uv_led_spectrum.txt')));          
            obj.addDevice(uv);
            
            blueRamp = importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'blue_led_gamma_ramp.txt'));
            blue = CalibratedDevice('Blue LED', Measurement.NORMALIZED, blueRamp(:, 1), blueRamp(:, 2)).bindStream(daq.getStream('ao2'));
            blue.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'C1', 'C2', 'C3', 'C4', 'C5'}));
            blue.addResource('ndfAttenuations', containers.Map( ...
                {'C1', 'C2', 'C3', 'C4', 'C5'}, ...
                {0.2663, 0.5389, 0.9569, 2.0810, 2.3747}));
            blue.addResource('fluxFactorPaths', containers.Map( ...
                {'none'}, {riekelab.Package.getCalibrationResource('rigs', 'suction', 'blue_led_flux_factors.txt')}));
            blue.addConfigurationSetting('lightPath', '', ...
                'type', PropertyType('char', 'row', {'', 'below', 'above'}));
            blue.addResource('spectrum', importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'blue_led_spectrum.txt')));                       
            obj.addDevice(blue);
            
            greenRamp = importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'green_led_gamma_ramp.txt'));
            green = CalibratedDevice('Green LED', Measurement.NORMALIZED, greenRamp(:, 1), greenRamp(:, 2)).bindStream(daq.getStream('ao3'));
            green.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'C1', 'C2', 'C3', 'C4', 'C5'}));
            green.addResource('ndfAttenuations', containers.Map( ...
                {'C1', 'C2', 'C3', 'C4', 'C5'}, ...
                {0.2866, 0.5933, 0.9675, 1.9279, 2.1372}));
            green.addResource('fluxFactorPaths', containers.Map( ...
                {'none'}, {riekelab.Package.getCalibrationResource('rigs', 'suction', 'green_led_flux_factors.txt')}));
            green.addConfigurationSetting('lightPath', '', ...
                'type', PropertyType('char', 'row', {'', 'below', 'above'}));
            green.addResource('spectrum', importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'green_led_spectrum.txt')));            
            obj.addDevice(green);
            
            temperature = UnitConvertingDevice('Temperature Controller', 'V', 'manufacturer', 'Warner Instruments').bindStream(daq.getStream('ai6'));
            obj.addDevice(temperature);
        end
        
    end
    
end


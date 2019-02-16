classdef ConfocalWithDynamicClampAndMicrodisplayBelow < symphonyui.core.descriptions.RigDescription

    methods

        function obj = ConfocalWithDynamicClampAndMicrodisplayBelow()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            import edu.washington.*;

            daq = HekaDaqController();
            obj.daqController = daq;

            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);

            ramps = containers.Map();
            ramps('minimum') = linspace(0, 65535, 256);
            ramps('low')     = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_low_gamma_ramp.txt'));
            ramps('medium')  = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_medium_gamma_ramp.txt'));
            ramps('high')    = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_high_gamma_ramp.txt'));
            ramps('maximum') = linspace(0, 65535, 256);
            microdisplay = riekelab.devices.MicrodisplayDevice('gammaRamps', ramps, 'micronsPerPixel', 1.2, 'comPort', 'COM3');
            microdisplay.bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(microdisplay, 15);
            microdisplay.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'E1', 'E2', 'E3', 'E4', 'E12'}));
            microdisplay.addResource('ndfAttenuations', containers.Map( ...
                {'white', 'red', 'green', 'blue'}, { ...
                containers.Map( ...
                    {'E1', 'E2', 'E3', 'E4', 'E12'}, ...
                    {0.26, 0.59, 0.94, 2.07, 0.30}), ...
                containers.Map( ...
                    {'E1', 'E2', 'E3', 'E4', 'E12'}, ...
                    {0.26, 0.61, 0.94, 2.05, 0.29}), ...
                containers.Map( ...
                    {'E1', 'E2', 'E3', 'E4', 'E12'}, ...
                    {0.26, 0.58, 0.94, 2.12, 0.29}), ...
                containers.Map( ...
                    {'E1', 'E2', 'E3', 'E4', 'E12'}, ...
                    {0.26, 0.57, 0.93, 2.13, 0.29})}));
            microdisplay.addResource('fluxFactorPaths', containers.Map( ...
                {'low', 'medium', 'high'}, { ...
                riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_low_flux_factors.txt'), ...
                riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_medium_flux_factors.txt'), ...
                riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_high_flux_factors.txt')}));
            microdisplay.addConfigurationSetting('lightPath', 'below', 'isReadOnly', true);
            microdisplay.addResource('spectrum', containers.Map( ...
                {'white', 'red', 'green', 'blue'}, { ...
                importdata(riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_white_spectrum.txt')), ...
                importdata(riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_red_spectrum.txt')), ...
                importdata(riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_green_spectrum.txt')), ...
                importdata(riekelab.Package.getCalibrationResource('rigs', 'confocal', 'microdisplay_below_blue_spectrum.txt'))}));
            obj.addDevice(microdisplay);
            
            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(daq.getStream('ai7'));
            obj.addDevice(frameMonitor);

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
            
        end

    end

end




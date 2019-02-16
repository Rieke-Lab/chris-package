classdef DeviceConfigurator < symphonyui.ui.Module
    
    properties (Access = private)
        log
        settings
        leds
        stage
        deviceListeners
    end
    
    properties (Access = private)
        mainLayout
        ndfsControls
        gainControls
        lightPathControls
    end
    
    methods
        
        function obj = DeviceConfigurator()
            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.settings = edu.washington.riekelab.modules.settings.DeviceConfiguratorSettings();
        end
        
        function createUi(obj, figureHandle)
            import appbox.*;
            
            set(figureHandle, ...
                'Name', 'Device Configurator', ...
                'Position', screenCenter(314, 300), ...
                'Resize', 'off');
            
            obj.mainLayout = uix.VBox( ...
                'Parent', figureHandle);
            
            obj.ndfsControls.box = uix.BoxPanel( ...
                'Parent', obj.mainLayout, ...
                'Title', 'NDFs', ...
                'BorderType', 'none', ...
                'FontUnits', get(figureHandle, 'DefaultUicontrolFontUnits'), ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            
            obj.gainControls.box = uix.BoxPanel( ...
                'Parent', obj.mainLayout, ...
                'Title', 'Gain', ...
                'BorderType', 'none', ...
                'FontUnits', get(figureHandle, 'DefaultUicontrolFontUnits'), ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            
            obj.lightPathControls.box = uix.BoxPanel( ...
                'Parent', obj.mainLayout, ...
                'Title', 'Light Path', ...
                'BorderType', 'none', ...
                'FontUnits', get(figureHandle, 'DefaultUicontrolFontUnits'), ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
        end
        
    end
    
    methods (Access = protected)
        
        function willGo(obj)
            obj.leds = obj.configurationService.getDevices('LED');
            stages = obj.configurationService.getDevices('Stage');
            if isempty(stages)
                obj.stage = [];
            else
                obj.stage = stages{1};
            end
            
            obj.populateNdfsBox();
            obj.populateGainBox();
            obj.populateLightPathBox();
            
            try
                obj.loadSettings();
            catch x
                obj.log.debug(['Failed to load settings: ' x.message], x);
            end
            
            obj.pack();
        end
        
        function willStop(obj)
            try
                obj.saveSettings();
            catch x
                obj.log.debug(['Failed to save settings: ' x.message], x);
            end
        end
        
        function bind(obj)
            bind@symphonyui.ui.Module(obj);
            
            obj.bindDevices();
            
            c = obj.configurationService;
            obj.addListener(c, 'InitializedRig', @obj.onServiceInitializedRig);
        end
        
    end
    
    methods (Access = private)
        
        function bindDevices(obj)
            d = obj.allDevices;
            for i = 1:numel(d)
                obj.deviceListeners{end + 1} = obj.addListener(d{i}, 'AddedConfigurationSetting', @obj.onDeviceChangedConfigurationSetting);
                obj.deviceListeners{end + 1} = obj.addListener(d{i}, 'SetConfigurationSetting', @obj.onDeviceChangedConfigurationSetting);
                obj.deviceListeners{end + 1} = obj.addListener(d{i}, 'RemovedConfigurationSetting', @obj.onDeviceChangedConfigurationSetting);
            end
        end
        
        function unbindDevices(obj)
            while ~isempty(obj.deviceListeners)
                obj.removeListener(obj.deviceListeners{1});
                obj.deviceListeners(1) = [];
            end
        end
        
        function d = allDevices(obj)
            d = obj.leds;
            if ~isempty(obj.stage)
                d = [{} d {obj.stage}];
            end
        end
        
        function populateNdfsBox(obj)
            import appbox.*;
            
            obj.ndfsControls.popupMenus = containers.Map();
            
            ndfsLayout = uix.VBox( ...
                'Parent', obj.ndfsControls.box, ...
                'Spacing', 7);
            
            for i = 1:numel(obj.allDevices)
                device = obj.allDevices{i};
                
                desc = device.getConfigurationSettingDescriptors().findByName('ndfs');
                if isempty(desc)
                    continue;
                end
                availableNdfs = desc.type.domain;
                activeNdfs = desc.value;
                
                if any(strcmp('ndfAttenuations', device.getResourceNames()))
                    attenuations = device.getResource('ndfAttenuations');
                    if attenuations.isKey('white')
                        attenuations = attenuations('white');
                    elseif attenuations.isKey('auto')
                        attenuations = attenuations('auto');
                    end
                else
                    attenuations = containers.Map();
                end
                for k = 1:numel(availableNdfs)
                    ndf = availableNdfs{k};
                    if attenuations.isKey(ndf)
                        availableNdfs{k} = [ndf ' (' num2str(attenuations(ndf)) ')'];
                    end
                end
                for k = 1:numel(activeNdfs)
                    ndf = activeNdfs{k};
                    if attenuations.isKey(ndf)
                        activeNdfs{k} = [ndf ' (' num2str(attenuations(ndf)) ')'];
                    end
                end
                
                deviceLayout = uix.HBox( ...
                    'Parent', ndfsLayout, ...
                    'Spacing', 7);
                Label( ...
                    'Parent', deviceLayout, ...
                    'String', [device.name ':']);
                obj.ndfsControls.popupMenus(device.name) = CheckBoxPopupMenu( ...
                    'Parent', deviceLayout, ...
                    'String', availableNdfs, ...
                    'Value', find(cellfun(@(n)any(strcmp(n, activeNdfs)), availableNdfs)), ...
                    'Callback', @(h,d)obj.onSelectedNdfs(h, struct('device', device, 'ndfs', {h.String(h.Value)})));
                
                set(deviceLayout, 'Widths', [60 -1]);
            end
            
            set(ndfsLayout, 'Heights', ones(1, numel(ndfsLayout.Children)) * 23);
            
            h = get(obj.mainLayout, 'Heights');
            set(obj.mainLayout, 'Heights', [25+11+layoutHeight(ndfsLayout)+11 h(2) h(3)]);
        end
        
        function updateNdfsBox(obj)
            for i = 1:numel(obj.allDevices)
                device = obj.allDevices{i};
                
                desc = device.getConfigurationSettingDescriptors().findByName('ndfs');
                if isempty(desc)
                    continue;
                end
                availableNdfs = desc.type.domain;
                activeNdfs = desc.value;
                
                menu = obj.ndfsControls.popupMenus(device.name);
                set(menu, 'Value', find(cellfun(@(n)any(strcmp(n, activeNdfs)), availableNdfs)));
            end
        end
        
        function onSelectedNdfs(obj, ~, event)
            device = event.device;
            ndfs = event.ndfs;
            
            for i = 1:numel(ndfs)
                k = strfind(ndfs{i}, ' (');
                if ~isempty(k)
                    ndf = ndfs{i};
                    ndfs{i} = ndf(1:k(end)-1);
                end
            end
            
            try
                device.setConfigurationSetting('ndfs', ndfs);
            catch x
                obj.view.showError(x.message);
                obj.updateNdfsBox();
                return;
            end
        end
        
        function populateGainBox(obj)
            import appbox.*;
            
            obj.gainControls.buttonGroups = containers.Map();
            
            gainLayout = uix.VBox( ...
                'Parent', obj.gainControls.box, ...
                'Spacing', 7);
            
            for i = 1:numel(obj.leds)
                led = obj.leds{i};
                
                desc = led.getConfigurationSettingDescriptors().findByName('gain');
                if isempty(desc)
                    continue;
                end
                availableGains = desc.type.domain;
                
                ledLayout = uix.HBox( ...
                    'Parent', gainLayout, ...
                    'Spacing', 7);
                Label( ...
                    'Parent', ledLayout, ...
                    'String', [led.name ':']);
                obj.gainControls.buttonGroups(led.name) = uix.HButtonGroup( ...
                    'Parent', ledLayout, ...
                    'ButtonStyle', 'toggle', ...
                    'Buttons', {'low', 'medium', 'high'}, ...
                    'ButtonSize', [75 23], ...
                    'Enable', { ...
                        onOff(any(strcmp('low', availableGains))), ...
                        onOff(any(strcmp('medium', availableGains))), ...
                        onOff(any(strcmp('high', availableGains)))}, ...
                    'HorizontalAlignment', 'left', ...
                    'Selection', find(strcmp(desc.value, {'low', 'medium', 'high'}), 1), ...
                    'SelectionChangeFcn', @(h,d)obj.onSelectedGain(h, struct('led', led, 'gain', h.Buttons{h.Selection})));
                
                set(ledLayout, 'Widths', [60 -1]);
            end
            
            set(gainLayout, 'Heights', ones(1, numel(gainLayout.Children)) * 23);
            
            h = get(obj.mainLayout, 'Heights');
            set(obj.mainLayout, 'Heights', [h(1) 25+11+layoutHeight(gainLayout)+11 h(3)]);
        end
        
        function updateGainBox(obj)
            for i = 1:numel(obj.leds)
                led = obj.leds{i};
                
                desc = led.getConfigurationSettingDescriptors().findByName('gain');
                if isempty(desc)
                    continue;
                end
                
                group = obj.gainControls.buttonGroups(led.name);
                set(group, 'Selection', find(strcmp(desc.value, {'low', 'medium', 'high'}), 1));
            end
        end
        
        function onSelectedGain(obj, ~, event)
            led = event.led;
            gain = event.gain;
            try
                led.setConfigurationSetting('gain', gain);
            catch x
                obj.view.showError(x.message);
                obj.updateGainBox();
                return;
            end
        end
        
        function populateLightPathBox(obj)
            import appbox.*;
            
            lightPathLayout = uix.VBox( ...
                'Parent', obj.lightPathControls.box, ...
                'Spacing', 7);
            
            commonPath = [];
            for i = 1:numel(obj.leds)
                led = obj.leds{i};
                
                desc = led.getConfigurationSettingDescriptors().findByName('lightPath');
                if isempty(desc)
                    commonPath = [];
                    break;
                end
                
                if ~ischar(commonPath)
                    commonPath = desc.value;
                end
                
                if ~strcmp(desc.value, commonPath)
                    commonPath = [];
                    break;
                end
            end
            
            allLayout = uix.HBox( ...
                'Parent', lightPathLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', allLayout, ...
                'String', 'All:');
            obj.lightPathControls.popupMenu = MappedPopupMenu( ...
                'Parent', allLayout, ...
                'Style', 'popupmenu', ...
                'String', {'', 'below', 'above'}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSelectedLightPath);
            set(obj.lightPathControls.popupMenu, 'Values', get(obj.lightPathControls.popupMenu, 'String'));
            if ischar(commonPath)
                set(obj.lightPathControls.popupMenu, 'Value', commonPath);
                set(obj.lightPathControls.popupMenu, 'Enable', 'on');
            else
                set(obj.lightPathControls.popupMenu, 'Value', '');
                set(obj.lightPathControls.popupMenu, 'Enable', 'off');
            end
            set(allLayout, 'Widths', [60 -1]);
            
            set(lightPathLayout, 'Heights', 23);
            
            h = get(obj.mainLayout, 'Heights');
            set(obj.mainLayout, 'Heights', [h(1) h(2) 25+11+layoutHeight(lightPathLayout)+11]);
        end
        
        function updateLightPathBox(obj)
            commonPath = [];
            for i = 1:numel(obj.leds)
                led = obj.leds{i};
                
                desc = led.getConfigurationSettingDescriptors().findByName('lightPath');
                if isempty(desc)
                    commonPath = [];
                    break;
                end
                
                if ~ischar(commonPath)
                    commonPath = desc.value;
                end
                
                if ~strcmp(desc.value, commonPath)
                    commonPath = [];
                    break;
                end
            end
            
            if ischar(commonPath)
                set(obj.lightPathControls.popupMenu, 'Value', commonPath);
                set(obj.lightPathControls.popupMenu, 'Enable', 'on');
            else
                set(obj.lightPathControls.popupMenu, 'Value', '');
                set(obj.lightPathControls.popupMenu, 'Enable', 'off');
            end
        end
        
        function onSelectedLightPath(obj, ~, ~)
            path = get(obj.lightPathControls.popupMenu, 'Value');           
            for i = 1:numel(obj.leds)
                try
                    obj.leds{i}.setConfigurationSetting('lightPath', path);
                catch x
                    obj.view.showError(x.message);
                    obj.updateLightPathBox();
                    return;
                end
            end
        end
        
        function pack(obj)
            f = obj.view.getFigureHandle();
            p = get(f, 'Position');
            h = appbox.layoutHeight(obj.mainLayout);
            delta = p(4) - h;
            set(f, 'Position', [p(1) p(2)+delta p(3) h]);
        end
        
        function onDeviceChangedConfigurationSetting(obj, ~, event)
            setting = event.data;
            switch setting.name
                case 'ndfs'
                    obj.updateNdfsBox();
                case 'gain'
                    obj.updateGainBox();
                case 'lightPath'
                    obj.updateLightPathBox();
            end
        end
        
        function onServiceInitializedRig(obj, ~, ~)
            obj.unbindDevices();
            
            obj.leds = obj.configurationService.getDevices('LED');
            stages = obj.configurationService.getDevices('Stage');
            if isempty(stages)
                obj.stage = [];
            else
                obj.stage = stages{1};
            end
            
            obj.populateNdfsBox();
            obj.populateGainBox();
            obj.populateLightPathBox();
            
            obj.pack();
            
            obj.bindDevices();
        end
        
        function loadSettings(obj)
            if ~isempty(obj.settings.viewPosition)
                obj.view.position = obj.settings.viewPosition;
            end
        end

        function saveSettings(obj)
            obj.settings.viewPosition = obj.view.position;
            obj.settings.save();
        end
        
    end
    
end

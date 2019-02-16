classdef BackgroundControl < symphonyui.ui.Module
    
    properties (Access = private)
        log
        settings
        toolbar
        turnLedsOffTool
        devices
        deviceListeners
        deviceGrid
    end
    
    methods
        
        function obj = BackgroundControl()
            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.settings = edu.washington.riekelab.modules.settings.BackgroundControlSettings();
        end
        
        function createUi(obj, figureHandle)
            import appbox.*;
            
            set(figureHandle, ...
                'Name', 'Background Control', ...
                'Position', screenCenter(290, 100));
            
            obj.toolbar = Menu(figureHandle);
            obj.turnLedsOffTool = obj.toolbar.addPushTool( ...
                'Label', 'Turn LEDs Off', ...
                'Callback', @obj.onSelectedTurnLedsOff);
            
            mainLayout = uix.VBox( ...
                'Parent', figureHandle);
            
            obj.deviceGrid = uiextras.jide.PropertyGrid(mainLayout, ...
                'BorderType', 'none', ...
                'Callback', @obj.onSetBackground);
        end
        
    end
    
    methods (Access = protected)

        function willGo(obj)
            obj.devices = obj.configurationService.getOutputDevices();
            obj.populateDeviceGrid();
            try
                obj.loadSettings();
            catch x
                obj.log.debug(['Failed to load settings: ' x.message], x);
            end
        end
        
        function willStop(obj)
            try
                obj.saveSettings();
            catch x
                obj.log.debug(['Failed to save settings: ' x.message], x);
            end
        end
        
        function didStop(obj)
            obj.toolbar.close();
            obj.deviceGrid.Close();
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
            for i = 1:numel(obj.devices)
                obj.deviceListeners{end + 1} = obj.addListener(obj.devices{i}, 'background', 'PostSet', @obj.onDeviceSetBackground);
            end
        end
        
        function unbindDevices(obj)
            while ~isempty(obj.deviceListeners)
                obj.removeListener(obj.deviceListeners{1});
                obj.deviceListeners(1) = [];
            end
        end
        
        function populateDeviceGrid(obj)
            try
                fields = device2field(obj.devices);
            catch x
                fields = uiextras.jide.PropertyGridField.empty(0, 1);
                obj.view.showError(x.message);
            end
            
            set(obj.deviceGrid, 'Properties', fields);
        end
        
        function updateDeviceGrid(obj)
            try
                fields = device2field(obj.devices);
            catch x
                fields = uiextras.jide.PropertyGridField.empty(0, 1);
                obj.view.showError(x.message);
            end
            
            obj.deviceGrid.UpdateProperties(fields);
        end
        
        function onSelectedTurnLedsOff(obj, ~, ~)
            obj.deviceGrid.StopEditing();
            leds = obj.configurationService.getDevices('LED');
            for i = 1:numel(leds)
                led = leds{i};
                if strcmp(led.background.baseUnits, 'V')
                    led.background = symphonyui.core.Measurement(-1, led.background.displayUnits);
                    led.applyBackground();
                else
                    led.background = symphonyui.core.Measurement(0, led.background.displayUnits);
                    led.applyBackground();
                end
            end
        end
        
        function onSetBackground(obj, ~, event)
            p = event.Property;
            device = obj.configurationService.getDevice(p.Name);
            background = device.background;
            device.background = symphonyui.core.Measurement(p.Value, device.background.displayUnits);
            try
                device.applyBackground();
            catch x
                device.background = background;
                obj.view.showError(x.message);
                return;
            end
            if ismethod(device, 'availableModes')
                for i = 1:numel(device.availableModes)
                    mode = device.availableModes{i};
                    b = device.getBackgroundForMode(mode);
                    device.setBackgroundForMode(mode, symphonyui.core.Measurement(p.Value, b.displayUnits));
                end
            end
        end
        
        function onServiceInitializedRig(obj, ~, ~)
            obj.unbindDevices();
            obj.devices = obj.configurationService.getOutputDevices();            
            obj.populateDeviceGrid();
            obj.bindDevices();
        end
        
        function onDeviceSetBackground(obj, ~, ~)
            obj.updateDeviceGrid();
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

function f = device2field(devices)
    f = uiextras.jide.PropertyGridField.empty(0, max(1, numel(devices)));
    for i = 1:numel(devices)
        d = devices{i};
        f(i) = uiextras.jide.PropertyGridField(d.name, d.background.quantity, ...
            'DisplayName', [d.name ' (' d.background.displayUnits ')']);
    end
end

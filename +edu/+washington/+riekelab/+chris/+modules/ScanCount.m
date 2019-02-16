classdef ScanCount < symphonyui.ui.Module
    
    properties (Access = private)
        toolbar
        updateButton
        scanDevice
        deviceListener
        deviceGrid
    end
    
    methods
        
        function createUi(obj, figureHandle)
            import appbox.*;
            
            set(figureHandle, ...
                'Name', 'Scan Counter', ...
                'Position', screenCenter(250, 20));
            
            obj.toolbar = Menu(figureHandle);
            obj.updateButton = obj.toolbar.addPushTool( ...
                'Label', 'Reset Scan Number to 1', ...
                'Callback', @obj.onSelectedReset);
            
            mainLayout = uix.VBox( ...
                'Parent', figureHandle);
            
            obj.deviceGrid = uiextras.jide.PropertyGrid(mainLayout, ...
                'BorderType', 'none', ...
                'Callback', @obj.onSetScanNumber);
        end
        
    end
    
    methods (Access = protected)

        function willGo(obj)
            devices = obj.configurationService.getDevices('scanTrigger');
            obj.scanDevice = devices{1};
            field = uiextras.jide.PropertyGridField(obj.scanDevice.name, ...
                obj.scanDevice.scanNumber, ...
                'DisplayName', 'Scan number:');
            set(obj.deviceGrid, 'Properties', field);
        end
        
        function bind(obj)
            bind@symphonyui.ui.Module(obj);
            obj.deviceListener = obj.addListener(obj.scanDevice,...
                'scanNumber', 'PostSet', @obj.onSelectedUpdate);
        end
   
    end
    
    methods (Access = private)
        
       
        function onSelectedUpdate(obj, ~, ~)
            obj.willGo();
        end
        
        function onSelectedReset(obj, ~, ~)
            obj.scanDevice.scanNumber = 1;
        end
        
        function onSetScanNumber(obj, ~, event)
            obj.scanDevice.scanNumber = event.Property.Value;
        end
        
    end
    
end


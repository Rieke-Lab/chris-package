classdef FilterWheelControl < symphonyui.ui.Module
    
    properties (Access = private)
        stage
        filterWheel
        ndf
        ndfSettingPopupMenu
    end
    
    methods
        
        function createUi(obj, figureHandle)
            import appbox.*;
            
            set(figureHandle, ...
                'Name', 'ND Wheel Control', ...
                'Position', screenCenter(200, 50));
            
            mainLayout = uix.HBox( ...
                'Parent', figureHandle, ...
                'Padding', 11, ...
                'Spacing', 7);
            
            filterWheelLayout = uix.Grid( ...
                'Parent', mainLayout, ...
                'Spacing', 2);
            Label( ...
                'Parent', filterWheelLayout, ...
                'String', 'NDF value:');

            obj.ndfSettingPopupMenu = MappedPopupMenu( ...
                'Parent', filterWheelLayout, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSelectedNdfSetting);

        end
        
    end
    
    methods (Access = protected)
        
        function willGo(obj)
            devices = obj.configurationService.getDevices('FilterWheel');
            if isempty(devices)
                error('No filterWheel device found');
            end
            
            obj.filterWheel = devices{1};
            
            obj.populateNdfSettingList();
            
            % Set the NDF to 4.0 on startup.
            obj.filterWheel.setNDF(4);
            set(obj.ndfSettingPopupMenu, 'Value', 4);
        end
        
    end
    
    methods (Access = private)
        function populateNdfSettingList(obj)
            ndfNums = {0.0, 0.5, 1.0, 2.0, 3.0, 4.0};
            ndfs = {'0.0', '0.5', '1.0', '2.0', '3.0', '4.0'}; 
            
            set(obj.ndfSettingPopupMenu, 'String', ndfs);
            set(obj.ndfSettingPopupMenu, 'Values', ndfNums);
        end
        
        function onSelectedNdfSetting(obj, ~, ~)
            position = get(obj.ndfSettingPopupMenu, 'Value');
            obj.filterWheel.setNDF(position);
        end
    end
end
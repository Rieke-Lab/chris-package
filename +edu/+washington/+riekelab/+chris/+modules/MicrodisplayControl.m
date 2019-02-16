classdef MicrodisplayControl < symphonyui.ui.Module
    
    properties (Access = private)
        log
        settings
        microdisplay
        brightnessPopupMenu
        centerOffsetFields
        prerenderCheckbox
    end
    
    methods
        
        function obj = MicrodisplayControl()
            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.settings = edu.washington.riekelab.modules.settings.MicrodisplayControlSettings();
        end
        
        function createUi(obj, figureHandle)
            import appbox.*;
            
            set(figureHandle, ...
                'Name', 'Microdisplay Control', ...
                'Position', screenCenter(350, 105), ...
                'Resize', 'off');
            
            mainLayout = uix.HBox( ...
                'Parent', figureHandle, ...
                'Padding', 11, ...
                'Spacing', 7);
            
            microdisplayLayout = uix.Grid( ...
                'Parent', mainLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', microdisplayLayout, ...
                'String', 'Brightness:');
            Label( ...
                'Parent', microdisplayLayout, ...
                'String', 'Center offset (um):');
            Label( ...
                'Parent', microdisplayLayout, ...
                'String', 'Prerender:');
            obj.brightnessPopupMenu = MappedPopupMenu( ...
                'Parent', microdisplayLayout, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSelectedBrightness);
            offsetLayout = uix.HBox( ...
                'Parent', microdisplayLayout, ...
                'Spacing', 5);
            obj.centerOffsetFields.x = uicontrol( ...
                'Parent', offsetLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSetCenterOffset);
            Label( ...
                'Parent', offsetLayout, ...
                'String', 'X');
            obj.centerOffsetFields.y = uicontrol( ...
                'Parent', offsetLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSetCenterOffset);
            Label( ...
                'Parent', offsetLayout, ...
                'String', 'Y');
            set(offsetLayout, ...
                'Widths', [-1 8+5 -1 8]);
            obj.prerenderCheckbox = uicontrol( ...
                'Parent', microdisplayLayout, ...
                'Style', 'checkbox', ...
                'String', '', ...
                'Callback', @obj.onSelectedPrerender);
            
            set(microdisplayLayout, ...
                'Widths', [100 -1], ...
                'Heights', [23 23 23]);
        end
        
    end
        
    methods (Access = protected)

        function willGo(obj)
            devices = obj.configurationService.getDevices('Microdisplay');
            if isempty(devices)
                error('No Microdisplay device found');
            end
            
            obj.microdisplay = devices{1};
            obj.populateBrightnessList();
            obj.populateCenterOffset();
            obj.populatePrerender();
            
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

    end
    
    methods (Access = private)
        
        function populateBrightnessList(obj)
            import edu.washington.riekelab.devices.MicrodisplayBrightness;
            
            names = {'Minimum', 'Low', 'Medium', 'High', 'Maximum'};
            values = {MicrodisplayBrightness.MINIMUM, MicrodisplayBrightness.LOW, MicrodisplayBrightness.MEDIUM, MicrodisplayBrightness.HIGH, MicrodisplayBrightness.MAXIMUM};
            set(obj.brightnessPopupMenu, 'String', names);
            set(obj.brightnessPopupMenu, 'Values', values);
            
            brightness = obj.microdisplay.getBrightness();
            set(obj.brightnessPopupMenu, 'Value', brightness);
        end
        
        function onSelectedBrightness(obj, ~, ~)
            brightness = get(obj.brightnessPopupMenu, 'Value');
            obj.microdisplay.setBrightness(brightness);
        end
        
        function populateCenterOffset(obj)
            offset = obj.microdisplay.pix2um(obj.microdisplay.getCenterOffset());
            set(obj.centerOffsetFields.x, 'String', num2str(offset(1)));
            set(obj.centerOffsetFields.y, 'String', num2str(offset(2)));
        end
        
        function onSetCenterOffset(obj, ~, ~)
            x = str2double(get(obj.centerOffsetFields.x, 'String'));
            y = str2double(get(obj.centerOffsetFields.y, 'String'));
            if isnan(x) || isnan(y)
                obj.view.showError('Could not parse x or y to a valid scalar value.');
                return;
            end
            obj.microdisplay.setCenterOffset(obj.microdisplay.um2pix([x, y]));
        end
        
        function populatePrerender(obj)
            set(obj.prerenderCheckbox, 'Value', obj.microdisplay.getPrerender());
        end
        
        function onSelectedPrerender(obj, ~, ~)
            prerender = get(obj.prerenderCheckbox, 'Value');
            obj.microdisplay.setPrerender(prerender);
        end
        
        function loadSettings(obj)
            if ~isempty(obj.settings.viewPosition)
                p1 = obj.view.position;
                p2 = obj.settings.viewPosition;
                obj.view.position = [p2(1) p2(2) p1(3) p1(4)];
            end
        end

        function saveSettings(obj)
            obj.settings.viewPosition = obj.view.position;
            obj.settings.save();
        end
        
    end
    
end


classdef GainSettingsRow < handle
    
    properties
        led
        ledName
        ledListener
        ledTitle
   
        gainNames
        currentlySelected
        gainButtons
        
        mainUiBox
        selectedColor
    end
    
    properties (Constant)
        RED_SELECTED = [1 0.2 0.2]
        GREEN_SELECTED = [0.2 1 0.2]
        BLUE_SELECTED = [0.2 0.2 1]
        UV_SELECTED = [0.8 0.5 1]   
        UNSELECTED = [0.94 0.94 0.94]
    end
    
    methods
        function obj = GainSettingsRow(led, uiParent)            
            obj.led = led;
            obj.ledName = led.name;
            obj.bindLed();
            obj.selectedColor = obj.determinSelectedColor();
            
            obj.setGainNames();
            
            obj.buildUIRow(uiParent);
        end
         
        function onLedSetConfigurationSetting(obj, ~, ~)
            obj.UpdateButtonsState();
        end
        
        function UpdateButtonsState(obj)
            % check the currently selected and see if it matches
            newSetting = obj.led.getConfigurationSetting('gain');
            for i = 1:numel(obj.gainNames)
                obj.setButtonState(obj.gainNames{i}, strcmp(newSetting, obj.gainNames{i}));
            end
        end

        function bindLed(obj)
            obj.ledListener = addlistener( ...
                obj.led, ...
                'SetConfigurationSetting', ...
                @obj.onLedSetConfigurationSetting);
        end
        
        function unbindLed(obj)
            delete(obj.ledListener);
            obj.ledListener = [];
        end
        
        function buildUIRow(obj, uiParent)
            import appbox.*;
            
            obj.mainUiBox = uix.HBox( ...
                'Parent', uiParent);
            
            % label the LED
            Label( ...
                'Parent', obj.mainUiBox, ...
                'String', obj.ledName);
            
            obj.addGainButtons(obj.mainUiBox);
        end
        
        function addGainButtons(obj, box)
            % this assumes that the gain can take one of up to three
            % values, which will work for us
            numGains = numel(obj.gainNames);
            
            % if there are less than three, fill with empty space
            if numGains < 3
               numBlank = 3 - numGains;
               for i = 1:numBlank
                    uix.Empty('Parent', box);
               end
            end
            
            % now put the real buttons in
            obj.gainButtons = containers.Map();
            tooltipString = ['Click here to apply this value as the ' ...
                'device''s gain'];
            for i = 1:numGains
                name = obj.gainNames{i};
                button = uicontrol(...
                    'Parent', box, ...
                    'Style', 'pushbutton', ...
                    'String', name, ...
                    'TooltipString', tooltipString, ...
                    'Callback', {@obj.onButtonPushed, name});
                obj.gainButtons(name) = button;
                if strcmp(name, obj.currentlySelected)
                    obj.setButtonState(name, true);
                end
            end
        end
        
        function onButtonPushed(obj, ~, ~, name)
            obj.led.setConfigurationSetting('gain', name);
        end
        
        function setButtonState(obj, name, state)
            button = obj.gainButtons(name);
            if state
                button.BackgroundColor = obj.selectedColor;
            else
                button.BackgroundColor = obj.UNSELECTED;
            end
        end
        
        function setGainNames(obj) 
            descriptors = obj.led.getConfigurationSettingDescriptors();
            gainOptions = descriptors.findByName('gain').type.domain;
            notEmpty = false(size(gainOptions));
            for i = 1:numel(gainOptions)
               if ~isempty(gainOptions{i})
                  notEmpty(i) = true; 
               end
            end

            obj.gainNames = gainOptions(notEmpty);
            
            obj.currentlySelected = ...
                obj.led.getConfigurationSetting('gain');
        end
        
        function clr = determinSelectedColor(obj)
           if sum(regexpi(obj.ledName, 'uv'))
               clr = obj.UV_SELECTED;
           elseif sum(regexpi(obj.ledName, 'blue'))
               clr = obj.BLUE_SELECTED;
           elseif sum(regexpi(obj.ledName, 'green'))
               clr = obj.GREEN_SELECTED;
           elseif sum(regexpi(obj.ledName, 'red'))
               clr = obj.RED_SELECTED;
           else
               clr = [0.8 0.8 0.8];
           end
        end
        
    end
    
end


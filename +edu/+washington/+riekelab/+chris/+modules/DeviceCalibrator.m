classdef DeviceCalibrator < symphonyui.ui.Module
    
    properties (Access = private)
        leds
        stage
        isLedOn
        isStageOn
        isCalibrating
        didShowWarning
        calibrations
        previousCalibrations
    end
    
    properties (Access = private)
        wizardCardPanel
        instructionsCard
        calibrationCard
        backButton
        nextButton
        cancelButton
    end
    
    methods
        
        function createUi(obj, figureHandle)
            import appbox.*;
            
            set(figureHandle, ...
                'Name', 'Device Calibrator', ...
                'Position', screenCenter(475, 324), ...
                'WindowStyle', 'modal', ...
                'Resize', 'off');
            
            mainLayout = uix.VBox( ...
                'Parent', figureHandle);
            
            wizardLayout = uix.VBox( ...
                'Parent', mainLayout);
            
            obj.wizardCardPanel = uix.CardPanel( ...
                'Parent', wizardLayout);
            
            % Instructions card.
            instructionsLayout = uix.VBox( ...
                'Parent', obj.wizardCardPanel, ...
                'Padding', 11);
            Label( ...
                'Parent', instructionsLayout, ...
                'String', sprintf(['<html><b>Instructions:</b><br>' ...
                    '&emsp;1. Take all NDFs out of the light path.<br>' ...
                    '&emsp;2. Make sure the spot is the correctly sized and reasonably well-centered.<br>' ...
                    '&emsp;3. Tape the wand to the stage, face down.<br>' ...
                    '&emsp;4. Connect the wand BNC cable to the light meter input on front of the box.<br>' ...
                    '&emsp;5. Close the curtains and dim the lights.<br>' ...
                    '&emsp;6. Turn on the power meter and set the gain to 10^-3.<br>' ...
                    '&emsp;7. Make sure the current (background) reading is ~0.01 or lower.<br>' ...
                    '&emsp;8. Turn on the stimulation device to a reasonably bright setting.<br>' ...
                    '&emsp;9. Center and focus the wand relative to the spot:<br>' ...
                    '&emsp;&emsp;9.1. Move the stage in the X direction until you find the peak power reading.<br>' ...
                    '&emsp;&emsp;9.2. Move the stage in the Y direction until you find the peak power reading.<br>' ...
                    '&emsp;&emsp;9.3. Move the stage in the Z direction until the power reading stops increasing.<br>' ...
                    '&emsp;&emsp;9.4. Move the stage up a bit so the wand is not pushing on the condenser.<br>' ...
                    '&emsp;10. Press "Next" to start calibrating.<br><br>']));
            
            % Calibration card.
            calibrationLayout = uix.HBox( ...
                'Parent', obj.wizardCardPanel, ...
                'Padding', 11, ...
                'Spacing', 7);
            
            masterLayout = uix.VBox( ...
                'Parent', calibrationLayout);
            
            obj.calibrationCard.deviceListBox = MappedListBox( ...
                'Parent', masterLayout, ...
                'Callback', @obj.onSelectedDevice);
            
            detailLayout = uix.VBox( ...
                'Parent', calibrationLayout, ...
                'Spacing', 7);
            
            obj.calibrationCard.detailCardPanel = uix.CardPanel( ...
                'Parent', detailLayout);
            
            % LED calibration card.
            ledLayout = uix.VBox( ...
                'Parent', obj.calibrationCard.detailCardPanel, ...
                'Spacing', 7);
            
            useCalibrationLayout = uix.HBox( ...
                'Parent', ledLayout);
            Label( ...
                'Parent', useCalibrationLayout, ...
                'String', 'Use calibration:');
            obj.calibrationCard.ledCard.useCalibrationPopupMenu = MappedPopupMenu( ...
                'Parent', useCalibrationLayout, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left');
            set(useCalibrationLayout, 'Widths', [90 -1]);
            
            useLayout = uix.HBox( ...
                'Parent', ledLayout, ...
                'Spacing', 7);
            uix.Empty('Parent', useLayout);
            obj.calibrationCard.ledCard.viewButton = uicontrol( ...
                'Parent', useLayout, ...
                'Style', 'pushbutton', ...
                'String', 'View', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedLedView);
            obj.calibrationCard.ledCard.useButton = uicontrol( ...
                'Parent', useLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Use', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedLedUse);
            set(useLayout, 'Widths', [-1 75 75]);
            
            javacomponent(com.jidesoft.swing.TitledSeparator('Or', com.jidesoft.swing.TitledSeparator.TYPE_PARTIAL_LINE, javax.swing.SwingConstants.CENTER), [], ledLayout);
            
            calibrateLayout = uix.HBox( ...
                'Parent', ledLayout, ...
                'Spacing', 5);
            Label( ...
                'Parent', calibrateLayout, ...
                'String', 'Calibrate using:');
            obj.calibrationCard.ledCard.calibrationIntensityField = uicontrol( ...
                'Parent', calibrateLayout, ...
                'Style', 'edit', ...
                'String', '1', ...
                'HorizontalAlignment', 'left');
            obj.calibrationCard.ledCard.calibrationUnitsField = uicontrol( ...
                'Parent', calibrateLayout, ...
                'Style', 'edit', ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'left');
            set(calibrateLayout, 'Widths', [85 -1 -1]);
            
            ledOnLayout = uix.HBox( ...
                'Parent', ledLayout, ...
                'Spacing', 5);
            uix.Empty('Parent', ledOnLayout);
            obj.calibrationCard.ledCard.resetButton = uicontrol( ...
                'Parent', ledOnLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Reset', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedLedReset);
            obj.calibrationCard.ledCard.ledOnButton = uicontrol( ...
                'Parent', ledOnLayout, ...
                'Style', 'togglebutton', ...
                'String', 'LED On', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedLedOn);
            set(ledOnLayout, 'Widths', [-1 75 75]);
            
            spotLayout = uix.HBox( ...
                'Parent', ledLayout, ...
                'Spacing', 5);
            Label( ...
                'Parent', spotLayout, ...
                'String', 'Spot diameter:');
            obj.calibrationCard.ledCard.spotDiameterField = uicontrol( ...
                'Parent', spotLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            obj.calibrationCard.ledCard.spotUnitsField = uicontrol( ...
                'Parent', spotLayout, ...
                'Style', 'edit', ...
                'String', 'um', ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'left');
            set(spotLayout, 'Widths', [85 -1 -1]);
            
            powerLayout = uix.HBox( ...
                'Parent', ledLayout, ...
                'Spacing', 5); 
            Label( ...
                'Parent', powerLayout, ...
                'String', 'Power reading:');
            obj.calibrationCard.ledCard.powerReadingField = uicontrol( ...
                'Parent', powerLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            obj.calibrationCard.ledCard.powerUnitsField = uicontrol( ...
                'Parent', powerLayout, ...
                'Style', 'edit', ...
                'String', 'nW', ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'left');
            set(powerLayout, 'Widths', [85 -1 -1]);
            
            noteLayout = uix.HBox( ...
                'Parent', ledLayout, ...
                'Spacing', 5);
            Label( ...
                'Parent', noteLayout, ...
                'String', 'Note (optional):');
            obj.calibrationCard.ledCard.noteField = uicontrol( ...
                'Parent', noteLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            set(noteLayout, 'Widths', [85 -1]);
            
            submitLayout = uix.HBox( ...
                'Parent', ledLayout);
            uix.Empty('Parent', submitLayout);
            obj.calibrationCard.ledCard.submitButton = uicontrol( ...
                'Parent', submitLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Submit', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedLedSubmit);
            set(submitLayout, 'Widths', [-1 75]);
            
            set(ledLayout, 'Heights', [23 23 17 23 23 23 23 23 23]);
            
            % Stage calibration card.
            stageLayout = uix.VBox( ...
                'Parent', obj.calibrationCard.detailCardPanel, ...
                'Spacing', 7);
            
            useCalibrationLayout = uix.HBox( ...
                'Parent', stageLayout);
            Label( ...
                'Parent', useCalibrationLayout, ...
                'String', 'Use calibration:');
            obj.calibrationCard.stageCard.useCalibrationPopupMenu = MappedPopupMenu( ...
                'Parent', useCalibrationLayout, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left');
            set(useCalibrationLayout, 'Widths', [90 -1]);
            
            useLayout = uix.HBox( ...
                'Parent', stageLayout, ...
                'Spacing', 7);
            uix.Empty('Parent', useLayout);
            obj.calibrationCard.stageCard.viewButton = uicontrol( ...
                'Parent', useLayout, ...
                'Style', 'pushbutton', ...
                'String', 'View', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedStageView);
            obj.calibrationCard.stageCard.useButton = uicontrol( ...
                'Parent', useLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Use', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedStageUse);
            set(useLayout, 'Widths', [-1 75 75]);
            
            javacomponent(com.jidesoft.swing.TitledSeparator('Or', com.jidesoft.swing.TitledSeparator.TYPE_PARTIAL_LINE, javax.swing.SwingConstants.CENTER), [], stageLayout);
            
            calibrateLayout = uix.HBox( ...
                'Parent', stageLayout, ...
                'Spacing', 5);
            Label( ...
                'Parent', calibrateLayout, ...
                'String', 'Calibrate using:');
            obj.calibrationCard.stageCard.calibrationIntensityField = uicontrol( ...
                'Parent', calibrateLayout, ...
                'Style', 'edit', ...
                'String', '1', ...
                'HorizontalAlignment', 'left');
            obj.calibrationCard.stageCard.calibrationUnitsField = uicontrol( ...
                'Parent', calibrateLayout, ...
                'Style', 'edit', ...
                'String', '_normalized_', ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'left');
            set(calibrateLayout, 'Widths', [85 -1 -1]);
            
            spotLayout = uix.HBox( ...
                'Parent', stageLayout, ...
                'Spacing', 5);
            Label( ...
                'Parent', spotLayout, ...
                'String', 'Spot diameter:');
            obj.calibrationCard.stageCard.spotDiameterField = uicontrol( ...
                'Parent', spotLayout, ...
                'Style', 'edit', ...
                'String', '500', ...
                'HorizontalAlignment', 'left');
            obj.calibrationCard.stageCard.spotUnitsField = uicontrol( ...
                'Parent', spotLayout, ...
                'Style', 'edit', ...
                'String', 'um', ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'left');
            set(spotLayout, 'Widths', [85 -1 -1]);
            
            stageOnLayout = uix.HBox( ...
                'Parent', stageLayout, ...
                'Spacing', 5);
            uix.Empty('Parent', stageOnLayout);
            obj.calibrationCard.stageCard.resetButton = uicontrol( ...
                'Parent', stageOnLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Reset', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedStageReset);
            obj.calibrationCard.stageCard.stageOnButton = uicontrol( ...
                'Parent', stageOnLayout, ...
                'Style', 'togglebutton', ...
                'String', 'Stage On', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedStageOn);
            set(stageOnLayout, 'Widths', [-1 75 75]);
            
            powerLayout = uix.HBox( ...
                'Parent', stageLayout, ...
                'Spacing', 5); 
            Label( ...
                'Parent', powerLayout, ...
                'String', 'Power reading:');
            obj.calibrationCard.stageCard.powerReadingField = uicontrol( ...
                'Parent', powerLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            obj.calibrationCard.stageCard.powerUnitsField = uicontrol( ...
                'Parent', powerLayout, ...
                'Style', 'edit', ...
                'String', 'nW', ...
                'Enable', 'off', ...
                'HorizontalAlignment', 'left');
            set(powerLayout, 'Widths', [85 -1 -1]);
            
            noteLayout = uix.HBox( ...
                'Parent', stageLayout, ...
                'Spacing', 5);
            Label( ...
                'Parent', noteLayout, ...
                'String', 'Note (optional):');
            obj.calibrationCard.stageCard.noteField = uicontrol( ...
                'Parent', noteLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left');
            set(noteLayout, 'Widths', [85 -1]);
            
            submitLayout = uix.HBox( ...
                'Parent', stageLayout);
            uix.Empty('Parent', submitLayout);
            obj.calibrationCard.stageCard.submitButton = uicontrol( ...
                'Parent', submitLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Submit', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedStageSubmit);
            set(submitLayout, 'Widths', [-1 75]);
            
            set(stageLayout, 'Heights', [23 23 17 23 23 23 23 23 23]);
            set(obj.calibrationCard.detailCardPanel, 'Selection', 1);
            
            set(calibrationLayout, 'Widths', [-1 -2]);
            set(obj.wizardCardPanel, 'Selection', 1);
                
            javacomponent('javax.swing.JSeparator', [], wizardLayout);
            
            set(wizardLayout, 'Heights', [-1 1]);
            
            controlsLayout = uix.HBox( ...
                'Parent', mainLayout, ...
                'Padding', 11);
            uix.Empty('Parent', controlsLayout);
            obj.backButton = uicontrol( ...
                'Parent', controlsLayout, ...
                'Style', 'pushbutton', ...
                'String', '< Back', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedBack);
            obj.nextButton = uicontrol( ...
                'Parent', controlsLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Next >', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedNext);
            uix.Empty('Parent', controlsLayout);
            obj.cancelButton = uicontrol( ...
                'Parent', controlsLayout, ...
                'Style', 'pushbutton', ...
                'String', 'Cancel', ...
                'Interruptible', 'off', ...
                'Callback', @obj.onSelectedCancel);
            set(controlsLayout, 'Widths', [-1 75 75 7 75]);
            
            set(mainLayout, 'Heights', [-1 11+23+11]);
            
            % Set next button to appear as the default button.
            try %#ok<TRYNC>
                h = handle(figureHandle);
                h.setDefaultButton(obj.nextButton);
            end
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
            
            obj.isLedOn = false;
            obj.isStageOn = false;
            obj.isCalibrating = false;
            obj.didShowWarning = false;
            
            obj.calibrations = containers.Map();
            obj.previousCalibrations = containers.Map();
            for i = 1:numel(obj.allDevices)
                device = obj.allDevices{i};
                
                if ~any(strcmp('fluxFactorPaths', device.getResourceNames()))
                    continue;
                end
                paths = device.getResource('fluxFactorPaths');
                
                m = containers.Map();
                settings = paths.keys;
                for k = 1:numel(settings)
                    setting = settings{k};
                    if ~exist(paths(setting), 'file')
                        continue;
                    end
                    t = readtable(paths(setting), 'Format', '%s %s %f %f %f %f %s');
                    t.date = datetime(t.date);
                    t = sortrows(t, 'date', 'descend');
                    m(setting) = t;
                end
                
                obj.previousCalibrations(device.name) = m;
            end
            
            obj.populateDeviceList();
            obj.updateStateOfControls();
        end
        
        function onViewSelectedClose(obj, ~, ~)
            obj.close();
        end
        
    end
    
    methods (Access = private)
        
        function populateDeviceList(obj)
            settingToDevices = containers.Map();            
            for i = 1:numel(obj.allDevices)
                device = obj.allDevices{i};
                
                if ~any(strcmp('fluxFactorPaths', device.getResourceNames()))
                    settings = {'none'};
                else
                    paths = device.getResource('fluxFactorPaths');
                    settings = paths.keys;
                end
                
                for k = 1:numel(settings)
                    setting = settings{k};
                    if settingToDevices.isKey(setting)
                        settingToDevices(setting) = [settingToDevices(setting) {device}];
                    else
                        settingToDevices(setting) = {device};
                    end
                end
            end
            
            % This allows the settings to be displayed in a preferred order.
            keys = settingToDevices.keys;
            settings = {'low', 'medium', 'high', 'auto', 'red', 'green', 'blue', 'none'};
            settings(cellfun(@(s)~any(strcmp(s, keys)), settings)) = [];
            for i = 1:numel(keys)
                if ~any(strcmp(keys{i}, settings))
                    settings{end + 1} = keys{i}; %#ok<AGROW>
                end
            end
            
            names = {};
            values = {};
            for i = 1:numel(settings)
                setting = settings{i};
                devices = settingToDevices(setting);
                for k = 1:numel(devices)
                    d = devices{k};
                    if obj.isDeviceCalibrated(d, setting)
                        n = ['<html><font color="green"><b>' d.name];
                    else
                        n = ['<html>' d.name];
                    end
                    if ~strcmp(setting, 'none')
                        n = [n ' - <i>' setting]; %#ok<AGROW>
                    end
                    names{end + 1} = n; %#ok<AGROW>
                    values{end + 1} = struct('device', d, 'setting', setting); %#ok<AGROW>
                end
            end
            set(obj.calibrationCard.deviceListBox, 'String', names);
            set(obj.calibrationCard.deviceListBox, 'Values', values);
        end
        
        function d = allDevices(obj)
            d = obj.leds;
            if ~isempty(obj.stage)
                d = [{} d {obj.stage}];
            end
        end
        
        function onSelectedDevice(obj, ~, ~)            
            [device, setting] = obj.getSelectedDevice();
            obj.selectDevice(device, setting);
        end
        
        function selectDevice(obj, device, setting)
            turnOn = obj.isLedOn || obj.isStageOn;
            obj.turnOffAllDevices();
            
            obj.setSelectedDevice(device, setting);
            if device == obj.stage
                if turnOn
                    intensity = str2double(get(obj.calibrationCard.stageCard.calibrationIntensityField, 'String'));
                    diameter = str2double(get(obj.calibrationCard.stageCard.spotDiameterField, 'String'));
                    obj.turnOnStage(device, setting, intensity, diameter);
                end
                obj.populateDetailsForStage(device, setting);
                uicontrol(obj.calibrationCard.stageCard.powerReadingField);
            else
                if turnOn
                    intensity = str2double(get(obj.calibrationCard.ledCard.calibrationIntensityField, 'String'));
                    obj.turnOnLed(device, setting, intensity);
                end
                obj.populateDetailsForLed(device, setting);
                if isempty(get(obj.calibrationCard.ledCard.spotDiameterField, 'String'))
                    uicontrol(obj.calibrationCard.ledCard.spotDiameterField);
                else
                    uicontrol(obj.calibrationCard.ledCard.powerReadingField);
                end
            end
            obj.updateStateOfControls();
        end
        
        function selectNextDevice(obj)
            old = get(obj.calibrationCard.deviceListBox, 'Value');
            old = old{1};
            
            values = get(obj.calibrationCard.deviceListBox, 'Values');
            i = find(cellfun(@(v)isequal(v, old), values), 1) + 1;
            new = values{mod(i - 1, numel(values)) + 1};
            
            obj.selectDevice(new.device, new.setting);
        end
        
        function setSelectedDevice(obj, device, setting)
            v = struct('device', device, 'setting', setting);
            set(obj.calibrationCard.deviceListBox, 'Value', v);
        end
        
        function [device, setting] = getSelectedDevice(obj)
            v = get(obj.calibrationCard.deviceListBox, 'Value');
            if isempty(v)
                device = [];
                setting = [];
                return;
            end
            v = v{1};
            device = v.device;
            setting = v.setting;
        end
        
        function populateDetailsForLed(obj, led, setting)
            [names, values, table] = obj.getPreviousCalibrationDisplayNames(led, setting);
            set(obj.calibrationCard.ledCard.useCalibrationPopupMenu, 'String', names);
            set(obj.calibrationCard.ledCard.useCalibrationPopupMenu, 'Values', values);
            set(obj.calibrationCard.ledCard.useCalibrationPopupMenu, 'Enable', appbox.onOff(~isempty(table)));
            set(obj.calibrationCard.ledCard.viewButton, 'Enable', appbox.onOff(~isempty(table)));
            set(obj.calibrationCard.ledCard.useButton, 'Enable', appbox.onOff(~isempty(table)));
            if isempty(led)
                set(obj.calibrationCard.ledCard.calibrationUnitsField, 'String', '');
            else
                set(obj.calibrationCard.ledCard.calibrationUnitsField, 'String', led.background.displayUnits);
            end
            
            calibration = [];
            if ~isempty(led) && obj.calibrations.isKey(led.name) && obj.calibrations(led.name).isKey(setting)
                m = obj.calibrations(led.name);
                calibration = m(setting);
            end
            if isempty(calibration)
                set(obj.calibrationCard.ledCard.powerReadingField, 'String', '');
                set(obj.calibrationCard.ledCard.noteField, 'String', '');
            else
                set(obj.calibrationCard.ledCard.spotDiameterField, 'String', num2str(calibration.diameter));
                set(obj.calibrationCard.ledCard.powerReadingField, 'String', num2str(calibration.power));
                set(obj.calibrationCard.ledCard.noteField, 'String', calibration.note);
            end
            
            set(obj.calibrationCard.detailCardPanel, 'Selection', 1);
        end
        
        function populateDetailsForStage(obj, stage, setting)
            [names, values, table] = obj.getPreviousCalibrationDisplayNames(stage, setting);
            set(obj.calibrationCard.stageCard.useCalibrationPopupMenu, 'String', names);
            set(obj.calibrationCard.stageCard.useCalibrationPopupMenu, 'Values', values);
            set(obj.calibrationCard.stageCard.useCalibrationPopupMenu, 'Enable', appbox.onOff(~isempty(table)));
            set(obj.calibrationCard.stageCard.viewButton, 'Enable', appbox.onOff(~isempty(table)));
            set(obj.calibrationCard.stageCard.useButton, 'Enable', appbox.onOff(~isempty(table)));
            
            calibration = [];
            if obj.calibrations.isKey(stage.name) && obj.calibrations(stage.name).isKey(setting)
                m = obj.calibrations(stage.name);
                calibration = m(setting);
            end
            if isempty(calibration)
                set(obj.calibrationCard.stageCard.powerReadingField, 'String', '');
                set(obj.calibrationCard.stageCard.noteField, 'String', '');
            else
                set(obj.calibrationCard.stageCard.powerReadingField, 'String', num2str(calibration.power));
                set(obj.calibrationCard.stageCard.noteField, 'String', calibration.note);
            end
            
            set(obj.calibrationCard.detailCardPanel, 'Selection', 2);
        end
        
        function [n, v, t] = getPreviousCalibrationDisplayNames(obj, device, setting)
            t = obj.getPreviousCalibrationTable(device, setting);
            if isempty(t)
                n = {'(None)'};
                v = {[]};
            else
                n = cell(1, height(t));
                v = cell(1, height(t));
                for i = 1:height(t)
                    n{i} = [datestr(t.date(i), 'dd-mmm-yyyy HH:MM PM') ' (' t.user{i}];
                    if iscellstr(t.note(i)) && ~isempty(t.note{i})
                        n{i} = [n{i} ': ' t.note{i}];
                    end
                    n{i} = [n{i} ')'];
                    v{i} = t(i, :);
                end
            end
        end
        
        function t = getPreviousCalibrationTable(obj, device, setting)
            t = table;
            if ~isempty(device) && obj.previousCalibrations.isKey(device.name) && obj.previousCalibrations(device.name).isKey(setting)
                m = obj.previousCalibrations(device.name);
                t = m(setting);
            end
        end
        
        function viewPreviousCalibrationTable(obj, device, setting, selectedDate)
            if nargin < 4
                selectedDate = [];
            end
            
            import appbox.*;
            
            f = figure( ...
                'Name', [device.name ' Previous Calibration Table'], ...
                'Position', screenCenter(800, 400), ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Toolbar', 'none', ...
                'HandleVisibility', 'off', ...
                'Visible', 'off', ...
                'DockControls', 'off', ...
                'Interruptible', 'off');
            
            mainLayout = uix.VBox( ...
                'Parent', f);
            
            table = obj.getPreviousCalibrationTable(device, setting);
            if isempty(selectedDate)
                selectedRow = [];
            else
                selectedRow = find(table.date == selectedDate, 1);
            end
            table.date = datestr(table.date, 'dd-mmm-yyyy HH:MM PM');
            table.factor = [];
            columnNames = cellfun(@(n)humanize(n), table.Properties.VariableNames, 'UniformOutput', false);
            uiextras.jTable.Table( ...
                'Parent', mainLayout, ...
                'ColumnName', columnNames, ...
                'Data', table2cell(table), ...
                'SelectedRows', selectedRow, ...
                'BorderType', 'none', ...
                'Editable', 'off');
            
            set(f, 'Visible', 'on');
        end
        
        function onSelectedLedView(obj, ~, ~)
            [device, setting] = obj.getSelectedDevice();
            entry = get(obj.calibrationCard.ledCard.useCalibrationPopupMenu, 'Value');
            obj.viewPreviousCalibrationTable(device, setting, entry.date);
        end
        
        function onSelectedLedUse(obj, ~, ~)
            [device, setting] = obj.getSelectedDevice();
            if device == obj.stage
                return;
            end
            
            entry = get(obj.calibrationCard.ledCard.useCalibrationPopupMenu, 'Value');
            success = obj.calibrateDevice(device, setting, entry.intensity, entry.diameter, entry.power, entry.note, true);
            if ~success
                return;
            end
            
            obj.selectNextDevice();
            obj.updateStateOfControls();
        end
        
        function success = calibrateDevice(obj, device, setting, intensity, diameter, power, note, reused)
            if nargin < 8
                reused = false;
            end
            
            if obj.isDeviceCalibrated(device, setting)
                result = obj.view.showMessage( ...
                    'This device has already been calibrated. Are you sure you want overwrite the current value?', ...
                    'Overwrite', ...
                    'button1', 'Cancel', ...
                    'button2', 'Overwrite');
                if ~strcmp(result, 'Overwrite')
                    success = false;
                    return;
                end
            end
            
            ssize = pi * diameter * diameter / 4;
            factor = power / (ssize * intensity);
            
            prevTable = obj.getPreviousCalibrationTable(device, setting);
            if ~isempty(prevTable)
                old = prevTable.factor(1);
                diff = abs(factor - old) / ((factor + old) / 2);
                if diff > 0.1
                    percent = diff * 100;
                    result = obj.view.showMessage(['The calculated photon flux conversion factor is ' ...
                        num2str(round(10*percent)/10) '% different than the most recent calibrated value. ' ...
                        'Are you sure you want to submit this value?'], ...
                        'Warning', ...
                        'button1', 'Cancel', ...
                        'button2', 'Submit');
                    if ~strcmp(result, 'Submit')
                        success = false;
                        return;
                    end
                end
            end
            
            if obj.calibrations.isKey(device.name)
                m = obj.calibrations(device.name);
            else
                m = containers.Map();
            end
            m(setting) = struct( ...
                'date', datetime(), ...
                'user', char(System.Environment.UserName), ...
                'intensity', intensity, ...
                'diameter', diameter, ...
                'power', power, ...
                'factor', factor, ...
                'note', note, ...
                'reused', reused);
            obj.calibrations(device.name) = m;
            obj.setDeviceCalibrated(device, setting);
            success = true;
        end
        
        function tf = isDeviceCalibrated(obj, device, setting)
            tf = any(strcmp('fluxFactors', device.getResourceNames())) || ...
                (obj.calibrations.isKey(device.name) && obj.calibrations(device.name).isKey(setting));
        end
        
        function setDeviceCalibrated(obj, device, setting)
            names = get(obj.calibrationCard.deviceListBox, 'String');
            values = get(obj.calibrationCard.deviceListBox, 'Values');
            
            i = cellfun(@(v)isequal(v, struct('device', device, 'setting', setting)), values);
            n = ['<html><font color="green"><b>' device.name];
            if ~strcmp(setting, 'none')
                n = [n ' - <i>' setting];
            end
            names{i} = n;
            
            set(obj.calibrationCard.deviceListBox, 'String', names);
            set(obj.calibrationCard.deviceListBox, 'Values', values);
        end
        
        function onSelectedLedReset(obj, ~, ~)
            obj.turnOffAllDevices();
            set(obj.calibrationCard.ledCard.powerReadingField, 'String', '');
            obj.isCalibrating = false;
            obj.updateStateOfControls();
        end
        
        function onSelectedLedOn(obj, ~, ~)
            obj.turnOffAllDevices();
            
            turnOn = get(obj.calibrationCard.ledCard.ledOnButton, 'Value');
            if turnOn
                [led, setting] = obj.getSelectedDevice();
                intensity = str2double(get(obj.calibrationCard.ledCard.calibrationIntensityField, 'String'));
                obj.turnOnLed(led, setting, intensity);                
                obj.isCalibrating = true;
            end
            
            obj.updateStateOfControls();
        end
        
        function turnOnLed(obj, led, setting, intensity) %#ok<INUSL>
%             if ~obj.didShowWarning && ~strcmpi(setting, 'none')
%                 obj.view.showMessage(['Make sure you manually change the LED gain according to the setting you are ' ...
%                     'calibrating. It should currently be ''' setting ''' for the ''' led.name '''. This warning ' ...
%                     'will not appear again.'], 'Warning');
%                 obj.didShowWarning = true;
%             end
            
            try
                led.background = symphonyui.core.Measurement(intensity, led.background.displayUnits);
                led.applyBackground();
                obj.isLedOn = true;
            catch x
                obj.view.showError(['Unable to turn on LED: ' x.message]);
                if strcmp(led.background.baseUnits, 'V')
                    led.background = symphonyui.core.Measurement(-1, led.background.displayUnits);
                    led.applyBackground();
                else
                    led.background = symphonyui.core.Measurement(0, led.background.displayUnits);
                    led.applyBackground();
                end
                obj.isLedOn = false;
                return;
            end
        end
        
        function turnOffLeds(obj, force)
            if ~obj.isLedOn && ~force
                return;
            end
            for i = 1:numel(obj.leds)
                led = obj.leds{i};
                if strcmp(led.background.baseUnits, 'V')
                    led.background = symphonyui.core.Measurement(-1, led.background.displayUnits);
                    led.applyBackground();
                else
                    led.background = symphonyui.core.Measurement(0, led.background.displayUnits);
                    led.applyBackground();
                end
            end
            obj.isLedOn = false;
        end
        
        function onSelectedStageView(obj, ~, ~)
            [device, setting] = obj.getSelectedDevice();
            entry = get(obj.calibrationCard.stageCard.useCalibrationPopupMenu, 'Value');
            obj.viewPreviousCalibrationTable(device, setting, entry.date);
        end
        
        function onSelectedStageUse(obj, ~, ~)
            [device, setting] = obj.getSelectedDevice();
            if device ~= obj.stage
                return;
            end
            
            entry = get(obj.calibrationCard.stageCard.useCalibrationPopupMenu, 'Value');
            success = obj.calibrateDevice(device, setting, entry.intensity, entry.diameter, entry.power, entry.note, true);
            if ~success
                return;
            end
            
            obj.selectNextDevice();
            obj.updateStateOfControls();
        end
        
        function onSelectedStageReset(obj, ~, ~)
            obj.turnOffAllDevices();
            set(obj.calibrationCard.stageCard.powerReadingField, 'String', '');
            obj.isCalibrating = false;
            obj.updateStateOfControls();
        end
        
        function onSelectedStageOn(obj, ~, ~)
            obj.turnOffAllDevices();
            
            turnOn = get(obj.calibrationCard.stageCard.stageOnButton, 'Value');
            if turnOn
                [device, setting] = obj.getSelectedDevice();
                intensity = str2double(get(obj.calibrationCard.stageCard.calibrationIntensityField, 'String'));
                diameter = str2double(get(obj.calibrationCard.stageCard.spotDiameterField, 'String'));
                obj.turnOnStage(device, setting, intensity, diameter);
                obj.isCalibrating = true;
            end
            
            obj.updateStateOfControls();
        end
        
        function turnOnStage(obj, device, setting, intensity, diameter)
            try
                if ~strcmpi(setting, 'none')
                    if ~isempty(regexpi(obj.stage.name, 'Microdisplay', 'once'))
                        obj.stage.setBrightness(setting);
                    elseif ~isempty(regexpi(obj.stage.name, 'LightCrafter', 'once'))
                        obj.stage.setSingleLedEnable(setting);
                    end
                end
                
                p = stage.core.Presentation(1/device.getMonitorRefreshRate()); %#ok<PROPLC>

                spot = stage.builtin.stimuli.Ellipse(); %#ok<PROPLC>
                spot.position = device.getCanvasSize()/2;
                spot.color = intensity;
                spot.radiusX = device.um2pix(diameter/2);
                spot.radiusY = device.um2pix(diameter/2);
                p.addStimulus(spot);
                
                device.play(p);
                info = device.getPlayInfo();
                if isa(info, 'MException')
                    error(info.message);
                end
                obj.isStageOn = true;
            catch x
                obj.view.showError(['Unable to turn on stage: ' x.message]);
                device.play(stage.core.Presentation(1/device.getMonitorRefreshRate())); %#ok<PROPLC>
                device.getPlayInfo();
                obj.isStageOn = false;
                return;
            end
        end
        
        function turnOffStage(obj, force)
            if isempty(obj.stage) || (~obj.isStageOn && ~force)
                return;
            end
            if ~isempty(regexpi(obj.stage.name, 'Microdisplay', 'once'))
                obj.stage.setBrightness('minimum');
            elseif ~isempty(regexpi(obj.stage.name, 'LightCrafter', 'once'))
                obj.stage.setSingleLedEnable('auto');
            end
            obj.stage.play(stage.core.Presentation(1/obj.stage.getMonitorRefreshRate())); %#ok<PROPLC>
            obj.stage.getPlayInfo();
            obj.isStageOn = false;
        end
        
        function turnOffAllDevices(obj, force)
            if nargin < 2
                force = false;
            end
            obj.turnOffLeds(force);
            obj.turnOffStage(force);
        end
        
        function onSelectedLedSubmit(obj, ~, ~)            
            [device, setting] = obj.getSelectedDevice();
            if device == obj.stage
                return;
            end
            
            intensity = str2double(get(obj.calibrationCard.ledCard.calibrationIntensityField, 'String'));
            diameter = str2double(get(obj.calibrationCard.ledCard.spotDiameterField, 'String'));
            power = str2double(get(obj.calibrationCard.ledCard.powerReadingField, 'String'));
            if isnan(intensity) || isnan(diameter) || isnan(power)
                obj.view.showError('Could not parse intensity, diameter, or power to a valid scalar value.');
                return;
            end
            note = get(obj.calibrationCard.ledCard.noteField, 'String');
            
            obj.submit(device, setting, intensity, diameter, power, note);
        end
        
        function onSelectedStageSubmit(obj, ~, ~)
            [device, setting] = obj.getSelectedDevice();
            if device ~= obj.stage
                return;
            end
            
            intensity = str2double(get(obj.calibrationCard.stageCard.calibrationIntensityField, 'String'));
            diameter = str2double(get(obj.calibrationCard.stageCard.spotDiameterField, 'String'));
            power = str2double(get(obj.calibrationCard.stageCard.powerReadingField, 'String'));
            if isnan(intensity) || isnan(diameter) || isnan(power)
                obj.view.showError('Could not parse intensity, diameter, or power to a valid scalar value.');
                return;
            end
            note = get(obj.calibrationCard.stageCard.noteField, 'String');
            
            obj.submit(device, setting, intensity, diameter, power, note);
        end
        
        function submit(obj, device, setting, intensity, diameter, power, note)            
            success = obj.calibrateDevice(device, setting, intensity, diameter, power, note);
            if ~success
                return;
            end
            
            obj.selectNextDevice();
            obj.updateStateOfControls();
        end
        
        function onSelectedBack(obj, ~, ~)
            selection = get(obj.wizardCardPanel, 'Selection');
            set(obj.wizardCardPanel, 'Selection', selection - 1);
            
            obj.updateStateOfControls();
        end
        
        function onSelectedNext(obj, ~, ~)
            selection = get(obj.wizardCardPanel, 'Selection');
            if selection < numel(get(obj.wizardCardPanel, 'Children'))
                set(obj.wizardCardPanel, 'Selection', selection + 1);
            end
            
            if strcmp(get(obj.nextButton, 'String'), 'Finish')
                obj.saveCalibration();
                obj.turnOffAllDevices();
                obj.stop();
            else
                obj.turnOffAllDevices(true);
                [device, setting] = obj.getSelectedDevice();
                obj.selectDevice(device, setting);
            end
        end
        
        function saveCalibration(obj)
            keys = obj.calibrations.keys;
            for i = 1:numel(keys)
                name = keys{i};
                device = obj.allDevices{cellfun(@(l)strcmp(l.name, name), obj.allDevices)};
                
                if any(strcmp('fluxFactors', device.getResourceNames()))
                    device.removeResource('fluxFactors');
                end
                if ~obj.calibrations.isKey(name)
                    continue;
                end
                cal = obj.calibrations(name);
                settings = cal.keys;
                factors = containers.Map();
                for k = 1:numel(settings)
                    factors(settings{k}) = cal(settings{k}).factor;
                end
                if device == obj.stage && ~isempty(regexpi(obj.stage.name, 'Microdisplay', 'once'))
                    factors('minimum') = 0;
                    factors('maximum') = 0;
                    factors = calculateFactorsFromSpectrum(factors, device.getResource('spectrum'));
                end
                device.addResource('fluxFactors', factors);
                
                if ~obj.previousCalibrations.isKey(name)
                    continue;
                end
                prevCal = obj.previousCalibrations(name);
                
                if ~any(strcmp('fluxFactorPaths', device.getResourceNames()))
                    continue;
                end
                paths = device.getResource('fluxFactorPaths');
                
                for k = 1:numel(settings)
                    setting = settings{k};
                    if prevCal.isKey(setting)
                        t = prevCal(setting);
                    else
                        t = table();
                    end
                    entry = struct2table(cal(setting), 'AsArray', true);
                    if entry.reused
                        continue;
                    end
                    entry.reused = [];
                    t(end + 1, :) = entry; %#ok<AGROW>
                    writetable(t, paths(setting), 'Delimiter', 'tab');
                    prevCal(setting) = t;
                end
                
                obj.previousCalibrations(name) = prevCal;
            end
        end
        
        function onSelectedCancel(obj, ~, ~)
            obj.close();
        end
        
        function close(obj)
            shouldClose = true;
            if ~isempty(obj.calibrations)
                result = obj.view.showMessage( ...
                    ['You have calibrated some devices. You will lose these values if you close the calibrator. ' ...
                    'Are you sure you want to close?'], 'Close', ...
                    'button1', 'Cancel', ...
                    'button2', 'Close');
                shouldClose = strcmp(result, 'Close');
            end
            if shouldClose
                obj.stop();
            end
        end
        
        function updateStateOfControls(obj)
            import appbox.*;
            
            device = obj.getSelectedDevice();
            
            hasDevice = ~isempty(device);
            isLastCard = get(obj.wizardCardPanel, 'Selection') >= numel(get(obj.wizardCardPanel, 'Children'));
            allCalibrated = all(cellfun(@(s)obj.isDeviceCalibrated(s.device, s.setting), ...
                get(obj.calibrationCard.deviceListBox, 'Values')));
            
            set(obj.calibrationCard.ledCard.calibrationIntensityField, 'Enable', onOff(hasDevice && ~obj.isCalibrating));
            set(obj.calibrationCard.ledCard.resetButton, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.calibrationCard.ledCard.ledOnButton, 'Enable', onOff(hasDevice));
            set(obj.calibrationCard.ledCard.ledOnButton, 'Value', obj.isLedOn);
            set(obj.calibrationCard.ledCard.spotDiameterField, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.calibrationCard.ledCard.powerReadingField, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.calibrationCard.ledCard.noteField, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.calibrationCard.ledCard.submitButton, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.calibrationCard.stageCard.calibrationIntensityField, 'Enable', onOff(hasDevice && ~obj.isCalibrating));
            set(obj.calibrationCard.stageCard.resetButton, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.calibrationCard.stageCard.spotDiameterField, 'Enable', onOff(hasDevice && ~obj.isCalibrating));
            set(obj.calibrationCard.stageCard.stageOnButton, 'Enable', onOff(hasDevice));
            set(obj.calibrationCard.stageCard.stageOnButton, 'Value', obj.isStageOn);
            set(obj.calibrationCard.stageCard.powerReadingField, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.calibrationCard.stageCard.noteField, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.calibrationCard.stageCard.submitButton, 'Enable', onOff(hasDevice && obj.isCalibrating));
            set(obj.backButton, 'Enable', onOff(isLastCard));
            set(obj.nextButton, 'Enable', onOff(~isLastCard || allCalibrated));
            if isLastCard
                set(obj.nextButton, 'String', 'Finish');
            else
                set(obj.nextButton, 'String', 'Next >');
            end
        end
        
    end
    
end

function factors = calculateFactorsFromSpectrum(factors, spectrum)
    import edu.washington.*;

    r = spectrum('red');
    g = spectrum('green');
    b = spectrum('blue');
    
    r(:,2) = riekelab.util.lowPassFilter(r(:,2), 25, 1/numel(r(:,2)));
    g(:,2) = riekelab.util.lowPassFilter(g(:,2), 25, 1/numel(g(:,2)));
    b(:,2) = riekelab.util.lowPassFilter(b(:,2), 25, 1/numel(b(:,2)));
    
    ri = trapz(r(:,1), r(:,2));
    gi = trapz(g(:,1), g(:,2));
    bi = trapz(b(:,1), b(:,2));
    wi = ri + gi + bi;
    
    keys = factors.keys;
    for i = 1:numel(keys)
        k = keys{i};
        f = factors(k);
        factors(k) = containers.Map( ...
            {'white', 'red', 'green', 'blue'}, ...
            {f*(wi/wi), f*(ri/wi), f*(gi/wi), f*(bi/wi)});
    end
end
classdef IsomerizationsConverter < symphonyui.ui.Module

    properties (Access = private)
        log
        settings
        leds
        stage
        deviceListeners
        epochGroup
        epochGroupListeners
        species
        speciesListeners
        preparation
        preparationListeners
    end

    properties (Access = private)
        mainLayout
        parametersControls
        converterControls
    end

    methods
        
        function obj = IsomerizationsConverter()
            obj.log = log4m.LogManager.getLogger(class(obj));
            obj.settings = edu.washington.riekelab.modules.settings.IsomerizationsConverterSettings();
        end

        function createUi(obj, figureHandle)
            import appbox.*;
            import symphonyui.app.App;

            set(figureHandle, ...
                'Name', 'Isomerizations Converter', ...
                'Position', screenCenter(273, 313), ...
                'Resize', 'off');

            obj.mainLayout = uix.VBox( ...
                'Parent', figureHandle);

            obj.parametersControls.box = uix.BoxPanel( ...
                'Parent', obj.mainLayout, ...
                'Title', 'Parameters', ...
                'BorderType', 'none', ...
                'FontUnits', get(figureHandle, 'DefaultUicontrolFontUnits'), ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);
            
            parametersLayout = uix.VBox( ...
                'Parent', obj.parametersControls.box, ...
                'Spacing', 7);
            
            deviceLayout = uix.HBox( ...
                'Parent', parametersLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', deviceLayout, ...
                'String', 'Device:');
            obj.parametersControls.devicePopupMenu = MappedPopupMenu( ...
                'Parent', deviceLayout, ...
                'String', {' '}, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @obj.onSelectedDevice);
            Button( ...
                'Parent', deviceLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'TooltipString', 'Device Help', ...
                'Callback', @obj.onSelectedDeviceHelp);
            set(deviceLayout, 'Widths', [70 -1 22]);
            
            ndfsLayout = uix.HBox( ...
                'Parent', parametersLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', ndfsLayout, ...
                'String', 'NDFs:');
            obj.parametersControls.ndfsField = uicontrol( ...
                'Parent', ndfsLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            Button( ...
                'Parent', ndfsLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'TooltipString', 'NDFs Help', ...
                'Callback', @obj.onSelectedNdfsHelp);
            set(ndfsLayout, 'Widths', [70 -1 22]);
            
            obj.parametersControls.settingCardPanel = uix.CardPanel( ...
                'Parent', parametersLayout);
            
            gainLayout = uix.HBox( ...
                'Parent', obj.parametersControls.settingCardPanel, ...
                'Spacing', 7);
            Label( ...
                'Parent', gainLayout, ...
                'String', 'Gain:');
            obj.parametersControls.gainField = uicontrol( ...
                'Parent', gainLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            Button( ...
                'Parent', gainLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'TooltipString', 'Gain Help', ...
                'Callback', @obj.onSelectedGainHelp);
            set(gainLayout, 'Widths', [70 -1 22]);
            
            brightnessLayout = uix.HBox( ...
                'Parent', obj.parametersControls.settingCardPanel, ...
                'Spacing', 7);
            Label( ...
                'Parent', brightnessLayout, ...
                'String', 'Brightness:');
            obj.parametersControls.brightnessField = uicontrol( ...
                'Parent', brightnessLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            Button( ...
                'Parent', brightnessLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'TooltipString', 'Brightness Help', ...
                'Callback', @obj.onSelectedBrightnessHelp);
            set(brightnessLayout, 'Widths', [70 -1 22]);
            
            pathLayout = uix.HBox( ...
                'Parent', parametersLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', pathLayout, ...
                'String', 'Light Path:');
            obj.parametersControls.lightPathField = uicontrol( ...
                'Parent', pathLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            Button( ...
                'Parent', pathLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'TooltipString', 'Light Path Help', ...
                'Callback', @obj.onSelectedLightPathHelp);
            set(pathLayout, 'Widths', [70 -1 22]);
            
            speciesLayout = uix.HBox( ...
                'Parent', parametersLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', speciesLayout, ...
                'String', 'Species:');
            obj.parametersControls.speciesField = uicontrol( ...
                'Parent', speciesLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            Button( ...
                'Parent', speciesLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'TooltipString', 'Species Help', ...
                'Callback', @obj.onSelectedSpeciesHelp);
            set(speciesLayout, 'Widths', [70 -1 22]);
            
            preparationLayout = uix.HBox( ...
                'Parent', parametersLayout, ...
                'Spacing', 7);
            Label( ...
                'Parent', preparationLayout, ...
                'String', 'Preparation:');
            obj.parametersControls.preparationField = uicontrol( ...
                'Parent', preparationLayout, ...
                'Style', 'edit', ...
                'HorizontalAlignment', 'left', ...
                'Enable', 'off');
            Button( ...
                'Parent', preparationLayout, ...
                'Icon', App.getResource('icons', 'help.png'), ...
                'TooltipString', 'Preparation Help', ...
                'Callback', @obj.onSelectedPreparationHelp);
            set(preparationLayout, 'Widths', [70 -1 22]);
            
            set(parametersLayout, 'Heights', [23 23 23 23 23 23]);

            obj.converterControls.box = uix.BoxPanel( ...
                'Parent', obj.mainLayout, ...
                'Title', 'Converter', ...
                'BorderType', 'none', ...
                'FontUnits', get(figureHandle, 'DefaultUicontrolFontUnits'), ...
                'FontName', get(figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(figureHandle, 'DefaultUicontrolFontSize'), ...
                'Padding', 11);

            set(obj.mainLayout, 'Heights', [25+11+layoutHeight(parametersLayout)+11 -1]);
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
            if obj.documentationService.hasOpenFile()
                obj.epochGroup = obj.documentationService.getCurrentEpochGroup();
            else
                obj.epochGroup = [];
            end
            obj.species = obj.findSpecies();
            obj.preparation = obj.findPreparation();
            
            obj.populateParametersBox();
            obj.populateConverterBox();
            
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
            obj.bindEpochGroup();
            obj.bindSpecies();
            obj.bindPreparation();

            d = obj.documentationService;
            obj.addListener(d, 'BeganEpochGroup', @obj.onServiceBeganEpochGroup);
            obj.addListener(d, 'EndedEpochGroup', @obj.onServiceEndedEpochGroup);
            obj.addListener(d, 'ClosedFile', @obj.onServiceClosedFile);

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
                obj.deviceListeners{end + 1} = obj.addListener(d{i}, 'AddedResource', @obj.onDeviceAddedResource);
            end
            
            if ~isempty(obj.stage) && ~isempty(regexpi(obj.stage.name, 'Microdisplay', 'once'))
                obj.deviceListeners{end + 1} = obj.addListener(d{i}, 'SetBrightness', @obj.onStageSetBrightness);
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
        
        function populateParametersBox(obj)
            obj.populateDeviceList();
            obj.populateNdfs();
            obj.populateGainOrBrightness();
            obj.populateLightPath();
            obj.populateSpecies();
            obj.populatePreparation();
        end

        function populateDeviceList(obj)
            names = cell(1, numel(obj.leds));
            values = cell(1, numel(obj.leds));
            for i = 1:numel(obj.leds)
                led = obj.leds{i};
                names{i} = led.name;
                values{i} = struct('device', led, 'setting', 'none');
            end
            
            if ~isempty(obj.stage)
                if ~isempty(regexpi(obj.stage.name, 'Microdisplay', 'once'))
                    colors = {'white', 'red', 'green', 'blue'};
                elseif ~isempty(regexpi(obj.stage.name, 'LightCrafter', 'once'))
                    colors = {'auto', 'red', 'green', 'blue'};
                else
                    colors = {'none'};
                end
                for i = 1:numel(colors)
                    c = colors{i};
                    names{end + 1} = [obj.stage.name ' - ' c]; %#ok<AGROW>
                    values{end + 1} = struct('device', obj.stage, 'setting', c); %#ok<AGROW>
                end
            end

            if numel(obj.allDevices) > 0
                set(obj.parametersControls.devicePopupMenu, 'String', names);
                set(obj.parametersControls.devicePopupMenu, 'Values', values);
            else
                set(obj.parametersControls.devicePopupMenu, 'String', {'(None)'});
                set(obj.parametersControls.devicePopupMenu, 'Values', {[]});
            end
            set(obj.parametersControls.devicePopupMenu, 'Enable', appbox.onOff(numel(obj.allDevices) > 0));
        end

        function onSelectedDevice(obj, ~, ~)
            obj.populateNdfs();
            obj.populateGainOrBrightness();
            obj.populateLightPath();
            obj.populateConverterBox();
            obj.pack();
        end

        function onSelectedDeviceHelp(obj, ~, ~)
            obj.view.showMessage(['Select the device for which to perform isomerizations conversions. This popup menu ' ...
                'is populated based on the devices in the currently initialized rig.'], 'Device Help');
        end

        function populateNdfs(obj)
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            if isempty(v)
                set(obj.parametersControls.ndfsField, 'String', '');
            else
                ndfs = v.device.getConfigurationSetting('ndfs');
                set(obj.parametersControls.ndfsField, 'String', strjoin(ndfs, '; '));
            end
        end

        function onSelectedNdfsHelp(obj, ~, ~)
            obj.view.showMessage(['The ndfs field is auto-populated by the value of the ''ndfs'' configuration ' ...
                'setting on the selected device. Device configuration settings may be changed through the ''Device ' ...
                'Configurator'' module.'], 'NDFs Help');
        end

        function populateGainOrBrightness(obj)
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            if isempty(v)
                set(obj.parametersControls.brightnessField, 'String', '');
                set(obj.parametersControls.brightnessField, 'String', '');
                set(obj.parametersControls.settingCardPanel, 'Selection', 2);
            elseif v.device == obj.stage
                set(obj.parametersControls.gainField, 'String', '');
                if ismethod(v.device, 'getBrightness')
                    set(obj.parametersControls.brightnessField, 'String', char(v.device.getBrightness()));
                else
                    set(obj.parametersControls.brightnessField, 'String', 'N/A');
                end
                set(obj.parametersControls.settingCardPanel, 'Selection', 2);
            else
                if v.device.hasConfigurationSetting('gain')
                    set(obj.parametersControls.gainField, 'String', v.device.getConfigurationSetting('gain'));
                else
                    set(obj.parametersControls.gainField, 'String', 'N/A');
                end
                set(obj.parametersControls.brightnessField, 'String', '');
                set(obj.parametersControls.settingCardPanel, 'Selection', 1);
            end
        end
        
        function onStageSetBrightness(obj, handle, ~)
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            if handle ~= v.device
                return;
            end
            
            obj.populateGainOrBrightness();
            obj.populateConverterBox();
            obj.pack();
        end

        function onSelectedGainHelp(obj, ~, ~)
            obj.view.showMessage(['The gain field is auto-populated by the value of the ''gain'' configuration ' ...
                'setting on the selected device. Device configuration settings may be changed through the ''Device ' ...
                'Configurator'' module.'], 'Gain Help');
        end
        
        function onSelectedBrightnessHelp(obj, ~, ~)
            obj.view.showMessage(['The brightness field is auto-populated by the value of the ''brightness'' ' ...
                'setting on the Stage device. Brightness settings may be changed through the specific ''Stage ' ...
                'Control'' module.'], 'Brightness Help');
        end
        
        function populateLightPath(obj)
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            if isempty(v)
                set(obj.parametersControls.lightPathField, 'String', '');
            else
                path = v.device.getConfigurationSetting('lightPath');
                set(obj.parametersControls.lightPathField, 'String', path);
            end
        end

        function onSelectedLightPathHelp(obj, ~, ~)
            obj.view.showMessage(['The light path field is auto-populated by the value of the ''lightPath'' configuration ' ...
                'setting on the selected device. Device configuration settings may be changed through the ''Device ' ...
                'Configurator'' module.'], 'Light Path Help');
        end
        
        function bindEpochGroup(obj)
            if ~obj.documentationService.hasOpenFile()
                return;
            end
            group = obj.documentationService.getCurrentEpochGroup();
            if ~isempty(group)
                obj.epochGroupListeners{end + 1} = obj.addListener(group, 'source', 'PostSet', @obj.onEpochGroupSetSource);
            end
        end
        
        function unbindEpochGroup(obj)
            while ~isempty(obj.epochGroupListeners)
                obj.removeListener(obj.epochGroupListeners{1});
                obj.epochGroupListeners(1) = [];
            end
        end
        
        function onEpochGroupSetSource(obj, ~, ~)
            obj.unbindSpecies();
            obj.species = obj.findSpecies();
            obj.bindSpecies();
            
            obj.unbindPreparation();
            obj.preparation = obj.findPreparation();
            obj.bindPreparation();
            
            obj.populateSpecies();
            obj.populatePreparation();
            obj.populateConverterBox();
            
            obj.pack();
        end
        
        function populateSpecies(obj)
            if isempty(obj.species)
                set(obj.parametersControls.speciesField, 'String', '');
            else
                set(obj.parametersControls.speciesField, 'String', obj.species.label);
            end
        end

        function s = findSpecies(obj)
            s = [];
            if isempty(obj.epochGroup)
                return;
            end

            source = obj.epochGroup.source;
            while ~isempty(source) && ~any(strcmp(source.getResourceNames(), 'photoreceptors'))
                source = source.parent;
            end
            s = source;
        end
        
        function bindSpecies(obj)
            if ~isempty(obj.species)
                obj.speciesListeners{end + 1} = obj.addListener(obj.species, 'label', 'PostSet', @obj.onSpeciesSetLabel);
            end
        end
        
        function unbindSpecies(obj)
            while ~isempty(obj.speciesListeners)
                obj.removeListener(obj.speciesListeners{1});
                obj.speciesListeners(1) = [];
            end
        end
        
        function onSpeciesSetLabel(obj, ~, ~)
            obj.populateSpecies();
        end

        function onSelectedSpeciesHelp(obj, ~, ~)
            obj.view.showMessage(['The species field is auto-populated based on the species of the source of the ' ...
                'current epoch group. If there is no current epoch group, this field will be empty.'], 'Species Help');
        end
        
        function populatePreparation(obj)
            if isempty(obj.preparation) || isempty(obj.preparation.getProperty('preparation'))
                set(obj.parametersControls.preparationField, 'String', '');
            else
                set(obj.parametersControls.preparationField, 'String', obj.preparation.getProperty('preparation'));
            end
        end

        function s = findPreparation(obj)
            s = [];
            if isempty(obj.epochGroup)
                return;
            end

            source = obj.epochGroup.source;
            while ~isempty(source) ...
                    && isempty(source.getPropertyDescriptors().findByName('preparation')) ...
                    && ~any(strcmp(source.getResourceNames(), 'photoreceptorOrientations'))
                source = source.parent;
            end
            s = source;
        end
        
        function bindPreparation(obj)
            if ~isempty(obj.preparation)
                obj.preparationListeners{end + 1} = obj.addListener(obj.preparation, 'SetProperty', @obj.onPreparationSetProperty);
            end
        end
        
        function unbindPreparation(obj)
            while ~isempty(obj.preparationListeners)
                obj.removeListener(obj.preparationListeners{1});
                obj.preparationListeners(1) = [];
            end
        end
        
        function onPreparationSetProperty(obj, ~, event)
            property = event.data;
            if strcmp(property.name, 'preparation')
                obj.populatePreparation();
                obj.populateConverterBox();
                obj.pack();
            end
        end
        
        function onSelectedPreparationHelp(obj, ~, ~)
            obj.view.showMessage(['The preparation field is auto-populated based on the preparation of the source of the ' ...
                'current epoch group. If there is no current epoch group, this field will be empty.'], 'Preparation Help');
        end
        
        function populateConverterBox(obj)
            import appbox.*;
            
            converterLayout = uix.VBox( ...
                'Parent', obj.converterControls.box, ...
                'Spacing', 7);
            
            obj.converterControls.fields = containers.Map();            
            
            [tf, msg] = obj.isValid();
            if ~tf
                Label( ...
                    'Parent', converterLayout, ...
                    'String', msg, ...
                    'HorizontalAlignment', 'center');
                set(converterLayout, 'Heights', 23);
                
                h = get(obj.mainLayout, 'Heights');
                set(obj.mainLayout, 'Heights', [h(1) 25+11+23+11]);
                return;
            end
            
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            units = v.device.background.baseUnits;
            if strcmp(units, 'V')
                units = 'volts';
            else strcmp(units, symphonyui.core.Measurement.UNITLESS);
                units = 'intensity';
            end
            
            photoreceptors = obj.species.getResource('photoreceptors');
            keys = [{} {units} photoreceptors.keys];
            for i = 1:numel(keys)
                k = keys{i};
                layout = uix.HBox( ...
                    'Parent', converterLayout, ...
                    'Spacing', 7);
                if i == 1
                    label = [capitalize(humanize(k)) ':']; 
                else
                    label = [capitalize(humanize(k)) ' R*/s:'];
                end
                Label( ...
                    'Parent', layout, ...
                    'String', label);
                f.control = uicontrol( ...
                    'Parent', layout, ...
                    'Style', 'edit', ...
                    'String', '0', ...
                    'HorizontalAlignment', 'left', ...
                    'KeyPressFcn', @(h,d)obj.onFieldKeyPress(h, struct('fieldName', k)));
                obj.converterControls.fields(k) = f; 
                Button( ...
                    'Parent', layout, ...
                    'Icon', symphonyui.app.App.getResource('icons', 'copy.png'), ...
                    'TooltipString', 'Copy To Clipboard', ...
                    'Callback', @(h,d)obj.onSelectedCopy(h, struct('fieldName', k)));
                set(layout, 'Widths', [70 -1 22]);
            end
            set(converterLayout, 'Heights', ones(1, numel(keys))*23);
            
            h = get(obj.mainLayout, 'Heights');
            set(obj.mainLayout, 'Heights', [h(1) 25+11+layoutHeight(converterLayout)+11]);
        end
        
        function [tf, msg] = isValid(obj)
            msg = '';
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            if isempty(v) || isempty(v.device)
                msg = 'Device must not be empty';
            elseif ~any(strcmp('spectrum', v.device.getResourceNames()))
                msg = 'Device is missing spectrum';
            elseif ~any(strcmp('ndfAttenuations', v.device.getResourceNames()))
                msg = 'Device is missing ndf attenuations';
            elseif ~any(strcmp('fluxFactors', v.device.getResourceNames()))
                msg = 'Device must be calibrated';
            elseif ~v.device.hasConfigurationSetting('ndfs')
                msg = 'Device is missing ndfs setting';
            elseif v.device.hasConfigurationSetting('gain') && isempty(v.device.getConfigurationSetting('gain'))
                msg = 'Gain must not be empty';
            elseif ~v.device.hasConfigurationSetting('lightPath')
                msg = 'Device is missing light path setting';
            elseif isempty(v.device.getConfigurationSetting('lightPath'))
                msg = 'Light path must not be empty';
            elseif isempty(obj.species)
                msg = 'Species must not be empty';
            elseif isempty(obj.preparation) || isempty(obj.preparation.getProperty('preparation'))
                msg = 'Preparation must not be empty';
            end
            tf = isempty(msg);
        end
        
        function onFieldKeyPress(obj, ~, event)
            field = obj.converterControls.fields(event.fieldName);
            if ~isfield(field, 'jcontrol')
                field.jcontrol = findjobj(field.control);
                obj.converterControls.fields(event.fieldName) = field;
            end
            value = char(field.jcontrol.getText());
            
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            spectrum = v.device.getResource('spectrum');
            attenuations = v.device.getResource('ndfAttenuations');
            fluxFactors = v.device.getResource('fluxFactors');
            ndfs = v.device.getConfigurationSetting('ndfs');
            path = v.device.getConfigurationSetting('lightPath');
            photoreceptors = obj.species.getResource('photoreceptors');
            prep = obj.preparation.getProperty('preparation');
            orientations = obj.preparation.getResource('photoreceptorOrientations');
            if orientations.isKey(prep)
                orientation = orientations(prep);
            else
                orientation = '';
            end
            units = v.device.background.baseUnits;
            if strcmp(units, 'V')
                units = 'volts';
            else strcmp(units, symphonyui.core.Measurement.UNITLESS);
                units = 'intensity';
            end
            
            if v.device == obj.stage
                spectrum = spectrum(v.setting);
                attenuations = attenuations(v.setting);
                if ismethod(v.device, 'getBrightness')
                    fluxFactors = fluxFactors(char(v.device.getBrightness));
                end
                factor = fluxFactors(v.setting);
            else
                if v.device.hasConfigurationSetting('gain')
                    factor = fluxFactors(v.device.getConfigurationSetting('gain'));
                else
                    factor = fluxFactors('none');
                end
            end
            
            function a = getCollectingArea(map, path, orientation)
                if (strcmpi(path, 'below') && any(strcmpi(orientation, {'down', 'lateral'}))) ...
                        || (strcmpi(path, 'above') && any(strcmpi(orientation, {'up', 'lateral'})))
                    a = map('photoreceptorSide');
                elseif (strcmpi(path, 'below') && strcmpi(orientation, 'up')) ...
                        || (strcmpi(path, 'above') && strcmpi(orientation, 'down'))
                    a = map('ganglionCellSide');
                else
                    warning('Unexpected light path or photoreceptor orientation. Using 0 for collecting area.');
                    a = 0;
                end
            end
            
            if strcmp(event.fieldName, units)
                voltsOrIntensity = str2double(value);
            else
                isom = str2double(value);
                collectingArea = getCollectingArea(photoreceptors(event.fieldName).collectingArea, path, orientation);
                voltsOrIntensity = edu.washington.riekelab.util.convisom(isom, 'isom', factor, spectrum, ...
                    photoreceptors(event.fieldName).spectrum, collectingArea, ndfs, attenuations);
                set(obj.converterControls.fields(units).control, 'String', num2str(voltsOrIntensity, '%.4f'));
            end
            
            names = photoreceptors.keys;
            names(strcmp(names, event.fieldName)) = [];
            for i = 1:numel(names)
                n = names{i};
                collectingArea = getCollectingArea(photoreceptors(n).collectingArea, path, orientation);
                isom = edu.washington.riekelab.util.convisom(voltsOrIntensity, units, factor, spectrum, ...
                    photoreceptors(n).spectrum, collectingArea, ndfs, attenuations);
                set(obj.converterControls.fields(n).control, 'String', num2str(isom, '%.0f'));
            end
        end
        
        function onSelectedCopy(obj, ~, event)
            field = obj.converterControls.fields(event.fieldName);
            if ~isfield(field, 'jcontrol')
                field.jcontrol = findjobj(field.control);
                obj.converterControls.fields(event.fieldName) = field;
            end
            value = char(field.jcontrol.getText());
            clipboard('copy', value);
        end
        
        function pack(obj)
            f = obj.view.getFigureHandle();
            p = get(f, 'Position');
            h = appbox.layoutHeight(obj.mainLayout);
            delta = p(4) - h;
            set(f, 'Position', [p(1) p(2)+delta p(3) h]);
        end
        
        function onDeviceChangedConfigurationSetting(obj, handle, event)
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            if handle ~= v.device
                return;
            end
            
            setting = event.data;
            if any(strcmp(setting.name, {'ndfs', 'gain', 'lightPath'}))
                obj.populateNdfs();
                obj.populateGainOrBrightness();
                obj.populateLightPath();
                obj.populateConverterBox();
                obj.pack();
            end
        end
        
        function onDeviceAddedResource(obj, handle, event)
            v = get(obj.parametersControls.devicePopupMenu, 'Value');
            if handle ~= v.device
                return;
            end
            
            resource = event.data;
            if strcmp(resource.name, 'fluxFactors')
                obj.populateConverterBox();
                obj.pack();
            end
        end

        function onServiceBeganEpochGroup(obj, ~, ~)
            obj.unbindEpochGroup();
            obj.epochGroup = obj.documentationService.getCurrentEpochGroup();
            obj.bindEpochGroup();
            
            obj.unbindSpecies();
            obj.species = obj.findSpecies();
            obj.bindSpecies();
            
            obj.unbindPreparation();
            obj.preparation = obj.findPreparation();
            obj.bindPreparation();
            
            obj.populateSpecies();
            obj.populatePreparation();
            obj.populateConverterBox();
            
            obj.pack();
        end

        function onServiceEndedEpochGroup(obj, ~, ~)
            obj.unbindEpochGroup();
            obj.epochGroup = obj.documentationService.getCurrentEpochGroup();
            obj.bindEpochGroup();
            
            obj.unbindSpecies();
            obj.species = obj.findSpecies();
            obj.bindSpecies();
            
            obj.unbindPreparation();
            obj.preparation = obj.findPreparation();
            obj.bindPreparation();
            
            obj.populateSpecies();
            obj.populatePreparation();
            obj.populateConverterBox();
            
            obj.pack();
        end

        function onServiceClosedFile(obj, ~, ~)
            obj.unbindEpochGroup();
            obj.epochGroup = [];
            
            obj.unbindSpecies();
            obj.species = [];
            
            obj.unbindPreparation();
            obj.preparation = [];
            
            obj.populateSpecies();
            obj.populatePreparation();
            obj.populateConverterBox();
            
            obj.pack();
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
            
            obj.populateParametersBox();
            obj.populateConverterBox();
            
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

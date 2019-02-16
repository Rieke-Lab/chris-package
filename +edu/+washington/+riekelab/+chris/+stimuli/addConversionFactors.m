function addConversionFactors(entity)
    if isa(entity, 'symphonyui.core.persistent.Experiment')
        addConversionFactorsToExperiment(entity);
    elseif isa(entity, 'symphonyui.core.persistent.EpochGroup')
        deviceMap = getDeviceMap(entity.experiment);
        addConversionFactorsToEpochGroup(entity, deviceMap);
    elseif isa(entity, 'symphonyui.core.persistent.EpochBlock')
        deviceMap = getDeviceMap(entity.epochGroup.experiment);
        photoreceptors = getPhotoreceptors(entity.epochGroup);
        orientation = getOrientation(entity.epochGroup);
        addConversionFactorsToEpochBlock(entity, deviceMap, photoreceptors, orientation);
    elseif isa(entity, 'symphonyui.core.persistent.Epoch')
        deviceMap = getDeviceMap(entity.epochBlock.epochGroup.experiment);
        photoreceptors = getPhotoreceptors(entity.epochBlock.epochGroup);
        orientation = getOrientation(entity.epochBlock.epochGroup);
        addConversionFactorsToEpoch(entity, deviceMap, photoreceptors, orientation);
    else
        error('Entity must be a persistent experiment, epoch group, epoch block or epoch')
    end
end

function addConversionFactorsToExperiment(experiment)
    deviceMap = getDeviceMap(experiment);
    
    exception = [];
    groups = experiment.getEpochGroups();
    for i = 1:numel(groups)
        group = groups{i};
        try
            addConversionFactorsToEpochGroup(group, deviceMap);
        catch x
            if isempty(exception)
                exception = MException('riekelab:util:addConversionFactors', ...
                    'Failed to add conversion factors to one or more epoch groups');
            end
            exception = exception.addCause(newException([group.label ' (' group.source.label '): ' x.message], x));
        end
    end
    if ~isempty(exception)
        throw(exception);
    end
end

function m = getDeviceMap(experiment)
    m = containers.Map();
    devices = experiment.getDevices();
    for i = 1:numel(devices)
        device = devices{i};
        
        if isempty(regexpi(device.name, 'LED', 'once')) && isempty(regexpi(device.name, 'Stage', 'once'))
            continue;
        end
        
        if ~any(strcmp('spectrum', device.getResourceNames()))
            error([device.name ' is missing spectrum']);
        end
        d.spectrum = device.getResource('spectrum');
        
        if ~any(strcmp('ndfAttenuations', device.getResourceNames()))
            error([device.name ' is missing ndf attenuations']);
        end
        d.ndfAttenuations = device.getResource('ndfAttenuations');
        
        if ~any(strcmp('fluxFactors', device.getResourceNames()))
            error([device.name ' is not calibrated']);
        end
        d.fluxFactors = device.getResource('fluxFactors');
        
        m(device.name) = d;
    end
end

function addConversionFactorsToEpochGroup(group, deviceMap)
    photoreceptors = getPhotoreceptors(group);
    orientation = getOrientation(group);
    
    exception = [];
    blocks = group.getEpochBlocks();
    for i = 1:numel(blocks)
        block = blocks{i};
        try
            addConversionFactorsToEpochBlock(block, deviceMap, photoreceptors, orientation);
        catch x
            if isempty(exception)
                exception = MException('riekelab:util:addConversionFactors', ...
                    'Failed to add conversion factors to one or more epoch blocks');
            end
            split = strsplit(block.protocolId, '.');
            exception = exception.addCause(newException([appbox.humanize(split{end}) ' [' datestr(block.startTime, 13) ']: ' x.message], x));
        end
    end
    children = group.getEpochGroups();
    for i = 1:numel(children)
        child = children{i};
        try
            addConversionFactorsToEpochGroup(children{i}, deviceMap);
        catch x
            if isempty(exception)
                exception = MException('riekelab:util:addConversionFactors', ...
                    'Failed to add conversion factors to one or more epoch groups');
            end
            exception = exception.addCause(newException([child.label ' (' child.source.label '): ' x.message], x));
        end
    end
    if ~isempty(exception)
        throw(exception);
    end
end

function p = getPhotoreceptors(group)
    species = group.source;
    while ~isempty(species) && ~any(strcmp(species.getResourceNames(), 'photoreceptors'))
        species = species.parent;
    end
    if isempty(species)
        error('Unable to determine species');
    end
    
    p = species.getResource('photoreceptors');
end

function o = getOrientation(group)
    preparation = group.source;
    while ~isempty(preparation) ...
            && isempty(preparation.getPropertyDescriptors().findByName('preparation')) ...
            && ~any(strcmp(preparation.getResourceNames(), 'photoreceptorOrientations'))
        preparation = preparation.parent;
    end
    if isempty(preparation)
        error('Unable to determine preparation');
    end
    
    prep = preparation.getProperty('preparation');
    if isempty(prep)
        error('Unable to determine preparation');
    end
    
    orientations = preparation.getResource('photoreceptorOrientations');
    if ~orientations.isKey(prep)
        error('Unable to determine preparation orientation');
    end
    o = orientations(prep);
end

function addConversionFactorsToEpochBlock(block, deviceMap, photoreceptors, orientation)
    exception = [];
    epochs = block.getEpochs();
    for i = 1:numel(epochs)
        epoch = epochs{i};
        try
            addConversionFactorsToEpoch(epoch, deviceMap, photoreceptors, orientation);
        catch x
            if isempty(exception)
                exception = MException('riekelab:util:addConversionFactors', ...
                    'Failed to add conversion factors to one or more epochs');
            end
            exception = exception.addCause(newException([datestr(epoch.startTime, 'HH:MM:SS:FFF') ': ' x.message], x));
        end
    end
    if ~isempty(exception)
        throw(exception);
    end
end

function addConversionFactorsToEpoch(epoch, deviceMap, photoreceptors, orientation)
    exception = [];
    propertyMap = containers.Map();
    signals = [{} epoch.getStimuli() epoch.getBackgrounds()];
    for i = 1:numel(signals)
        signal = signals{i};
        if ~deviceMap.isKey(signal.device.name)
            continue;
        end
        try
            d = deviceMap(signal.device.name);
            spectrum = d.spectrum;
            attenuations = d.ndfAttenuations;
            fluxFactors = d.fluxFactors;

            m = getConversionFactorsForSignal(signal, spectrum, attenuations, fluxFactors, photoreceptors, orientation);
            deviceName = strrep(signal.device.name, ' ', '_');
            keys = m.keys;
            for k = 1:numel(keys)
                n = keys{k};
                propertyMap([deviceName ':' n 'ConversionFactor']) = m(n);
            end
        catch x
            if isempty(exception)
                exception = MException('riekelab:util:addConversionFactors', ...
                    'Failed to add conversion factors to one or more signals');
            end
            exception = exception.addCause(newException([signal.device.name ': ' x.message], x));
        end
    end
    epoch.setPropertyMap(propertyMap);
    if ~isempty(exception)
        throw(exception);
    end
end

function m = getConversionFactorsForSignal(signal, spectrum, attenuations, fluxFactors, photoreceptors, orientation)
    m = containers.Map();

    config = signal.getConfigurationSettingMap();
    
    ndfs = config('ndfs');
    
    path = config('lightPath');
    if isempty(path)
        error('Light path is empty');
    end

    if ~isempty(regexpi(signal.device.name, 'Microdisplay', 'once'))
        settings = {'white', 'red', 'green', 'blue'};
        fluxFactors = fluxFactors(config('microdisplayBrightness'));
    elseif ~isempty(regexpi(signal.device.name, 'LightCrafter', 'once'))
        settings = {'auto', 'red', 'green', 'blue'};
    else
        if config.isKey('gain')
            gain = config('gain');
            if isempty(gain)
                error('Gain is empty');
            end
            settings = {gain};
        else
            settings = {'none'};
        end
    end
    
    for i = 1:numel(settings)
        setting = settings{i};
        map = getConversionFactorsForSignalWithSetting(signal, setting, spectrum, attenuations, fluxFactors, photoreceptors, orientation, ndfs, path);
        keys = map.keys;
        for k = 1:numel(keys)
            if numel(settings) > 1
                key = [setting ':' keys{k}];
            else
                key = keys{k};
            end
            m(key) = map(keys{k});
        end
    end
end

function m = getConversionFactorsForSignalWithSetting(signal, setting, spectrum, attenuations, fluxFactors, photoreceptors, orientation, ndfs, path)
    m = containers.Map();

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

    if ~isempty(regexpi(signal.device.name, 'Stage', 'once'))
        spectrum = spectrum(setting);
        attenuations = attenuations(setting);
    end
    factor = fluxFactors(setting);

    names = photoreceptors.keys;
    for k = 1:numel(names)
        n = names{k};
        collectingArea = getCollectingArea(photoreceptors(n).collectingArea, path, orientation);
        isom = edu.washington.riekelab.util.convisom(1, 'intensity', factor, spectrum, ...
            photoreceptors(n).spectrum, collectingArea, ndfs, attenuations);
        m(n) = round(isom);
    end
end

function x = newException(text, exc)
    x = MException(exc.identifier, text);
    for i = 1:numel(exc.cause)
        x = x.addCause(exc.cause{i});
    end
end
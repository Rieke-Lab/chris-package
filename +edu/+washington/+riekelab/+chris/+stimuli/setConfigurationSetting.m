function setConfigurationSetting(entity, name, value, deviceName)
    % Sets configuration settings for IO (i.e. responses, stimuli, backgrounds) in the persistent entity.
    %
    % Examples:
    %
    % % Set the 'gain' configuration setting to 'low' on only IO from 'Red LED' in an epoch entity:
    % setConfigurationSetting(epoch, 'gain', 'low', 'Red LED');
    %
    % % Set the 'ndfs' configuration setting to {'F1', 'F2'} on only IO from 'Red LED' in an epoch entity:
    % setConfigurationSetting(epoch, 'ndfs', {'F1', 'F2'}, 'Red LED');
    %
    % % Set the 'gain' configuration setting to 'low' on only IO from 'Red LED' and 'Green LED' in an epoch entity:
    % setConfigurationSetting(epoch, 'gain', 'low', {'Red LED', 'Green LED'});
    %
    % % Set the 'gain' and 'lightPath' configuration setting to 'medium' and 'above' respectively on only IO from 
    % % 'Red LED' and 'Green LED' in an epoch group entity:
    % setConfigurationSetting(epochGroup, {'gain', 'lightPath'}, {'medium', 'above'}, {'Red LED', 'Green LED'});

    if isa(entity, 'symphonyui.core.persistent.Experiment')
        signals = getSignalsFromExperiment(entity);
    elseif isa(entity, 'symphonyui.core.persistent.EpochGroup')
        signals = getSignalsFromEpochGroup(entity);
    elseif isa(entity, 'symphonyui.core.persistent.EpochBlock')
        signals = getSignalsFromEpochBlock(entity);
    elseif isa(entity, 'symphonyui.core.persistent.Epoch')
        signals = getSignalsFromEpoch(entity);
    elseif isa(entity, 'symphonyui.core.persistent.IoBase')
        signals = {entity};
    else
        error('Entity must be a persistent experiment, epoch group, epoch block, epoch or signal')
    end
    
    if iscell(name)
        names = name;
    else
        names = {name};
    end
    if iscell(value)
        values = value;
    else
        values = {value};
    end
    if iscell(deviceName)
        deviceNames = deviceName;
    else
        deviceNames = {deviceName};
    end
    if numel(names) ~= numel(values)
        error('Names and values must have the same number of element');
    end
    
    exception = [];
    for i = 1:numel(signals)
        signal = signals{i};
        
        if ~any(strcmp(signal.device.name, deviceNames))
            continue;
        end
        
        for k = 1:numel(names)
            try
                signal.setConfigurationSetting(names{k}, values{k});
            catch x
                if isempty(exception)
                    exception = MException('riekelab:setConfigurationSetting', 'Failed to set one or more configuration settings');
                end
                exception = exception.addCause(MException('riekelab:setConfigurationSetting', ...
                    [datestr(signal.epoch.startTime, 'HH:MM:SS:FFF') ':' signal.device.name ' - ' x.message]));
            end
        end
    end
    if ~isempty(exception)
        throw(exception);
    end
end

function s = getSignalsFromEpoch(epoch)
    s = [epoch.getResponses(), epoch.getStimuli(), epoch.getBackgrounds()];
end

function s = getSignalsFromEpochBlock(block)
    s = {};
    epochs = block.getEpochs();
    for i = 1:numel(epochs)
        s = [s getSignalsFromEpoch(epochs{i})]; %#ok<AGROW>
    end
end

function s = getSignalsFromEpochGroup(group)
    s = {};
    blocks = group.getEpochBlocks();
    for i = 1:numel(blocks)
        s = [s getSignalsFromEpochBlock(blocks{i})]; %#ok<AGROW>
    end
    children = group.getEpochGroups();
    for i = 1:numel(children)
        s = [s getSignalsFromEpochGroup(children{i})]; %#ok<AGROW>
    end
end

function s = getSignalsFromExperiment(experiment)
    s = {};
    groups = experiment.getEpochGroups();
    for i = 1:numel(groups)
        s = [s getSignalsFromEpochGroup(groups{i})]; %#ok<AGROW>
    end
end
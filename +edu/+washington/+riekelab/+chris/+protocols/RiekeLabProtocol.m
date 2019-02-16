classdef (Abstract) RiekeLabProtocol < symphonyui.core.Protocol
    
    methods
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@symphonyui.core.Protocol(obj, epoch);
            
            controllers = obj.rig.getDevices('Temperature Controller');
            if ~isempty(controllers)
                epoch.addResponse(controllers{1});
            end
        end
        
        function completeEpoch(obj, epoch)
            completeEpoch@symphonyui.core.Protocol(obj, epoch);
            
            controllers = obj.rig.getDevices('Temperature Controller');
            if ~isempty(controllers) && epoch.hasResponse(controllers{1})
                response = epoch.getResponse(controllers{1});
                [quantities, units] = response.getData();
                if ~strcmp(units, 'V')
                    error('Temperature Controller must be in volts');
                end
                
                % Temperature readout from Warner TC-324B controller 100 mV/degree C.
                temperature = mean(quantities) * 1000 * (1/100);
                temperature = round(temperature * 10) / 10;
                epoch.addProperty('bathTemperature', temperature);
                
                epoch.removeResponse(controllers{1});
            end
        end
        
    end
    
end


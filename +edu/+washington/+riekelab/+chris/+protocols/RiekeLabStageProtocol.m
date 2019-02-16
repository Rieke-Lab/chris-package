classdef (Abstract) RiekeLabStageProtocol < edu.washington.riekelab.protocols.RiekeLabProtocol
    
    properties (Access = protected)
        waitingForHardwareToStart
    end
    
    methods (Abstract)
        p = createPresentation(obj);
    end
    
    methods
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            obj.waitingForHardwareToStart = true;
            epoch.shouldWaitForTrigger = true;
            
            frameMonitor = obj.rig.getDevices('Frame Monitor');
            if ~isempty(frameMonitor)
                epoch.addResponse(frameMonitor{1});
            end
        end
        
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            
            if obj.waitingForHardwareToStart
                obj.waitingForHardwareToStart = false;
                obj.rig.getDevice('Stage').play(obj.createPresentation());
            end
        end
        
        function tf = shouldContinuePreloadingEpochs(obj) %#ok<MANU>
            tf = false;
        end
        
        function tf = shouldWaitToContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared > obj.numEpochsCompleted || obj.numIntervalsPrepared > obj.numIntervalsCompleted;
        end
        
        function completeRun(obj)
            completeRun@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            obj.rig.getDevice('Stage').clearMemory();
        end
        
        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            if tf
                tf = ~isempty(obj.rig.getDevices('Stage'));
                msg = 'No stage';
            end
        end
        
    end
    
end


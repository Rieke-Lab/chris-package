classdef SelectableConeCircles < handle
    properties
        coneCircles
        numCones
    end
    
    methods
        function obj = SelectableConeCircles(centers, radii, types, axes)
            obj.numCones = numel(radii);
            obj.coneCircles = cell(1, obj.numCones);
            for i = 1:obj.numCones
                obj.coneCircles{i} = edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.ConeCircle( ...
                    centers(i, :), ...
                    radii(i), ...
                    types{i}, ...
                    axes);
            end
        end
        
        function runFunctionOnConeCircles(obj, fxn)
            for i = 1:obj.numCones
                fxn(obj.coneCircles{i});
            end
        end
        
        function clearSelection(obj)
           obj.runFunctionOnConeCircles(@(x) x.unselect()); 
        end
        
        function handleClick(obj, location)
            obj.runFunctionOnConeCircles(@(x) x.handleClick(location));
        end
        
        function addStimulusToSelected(obj, protocolName, propertyMap)
            obj.runFunctionOnConeCircles(@(x) x.addStimulusIfSelected(protocolName, propertyMap));
        end
        
        function clearStimulusOnSelected(obj)
           obj.runFunctionOnConeCircles(@(x) x.clearStimulusIfSelected()); 
        end
        
        function clearAllStimuli(obj)
           obj.runFunctionOnConeCircles(@(x) x.clearStimulus()); 
        end
        
        function stimulus = getStimulusIfSingleConeSelected(obj)
            selected = false(1, obj.numCones);
            for i = 1:obj.numCones
                selected(i) = obj.coneCircles.isSelected();
            end
            
            numSelected = sum(selected);
            
            if numSelected == 0 || numSelected > 1
                stimulus = [];
                errorString = ['Exactly one cone must be selected (currently ' ...
                    num2str(numSelected) ' are selected).'];
                errdlg(errorString, 'Selection Problem', 'modal');
            else
                stimulus = obj.coneCircles{selected}.getStimulus();
            end
        end
        
        function stimuli = collectStimuli(obj)
            toUse = false(1, obj.numCones);
            stimuli = cell(1, obj.numCones);
            for i = 1:obj.numCones
                if obj.coneCircles{i}.hasStimulus()
                    toUse(i) = true;
                    stimuli{i} = obj.coneCircles{i}.getStimulus();
                end
            end
            stimuli = stimuli(toUse);
        end
        
        function delete(obj)
            obj.runFunctionOnConeCircles(@(x) x.delete());
        end
    end
end
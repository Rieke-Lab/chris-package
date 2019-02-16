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
        
        function selectAll(obj)
            obj.runFunctionOnConeCircles(@(x) x.select());
        end
        
        function unselectAll(obj)
            obj.runFunctionOnConeCircles(@(x) x.unselect());
        end
        
        function handleClick(obj, location)
            obj.runFunctionOnConeCircles(@(x) x.handleClick(location));
        end
        
        
        
        function [centers, radii, types] = collectSelectedConeLocationsAndTypes(obj)
            cones = obj.getSelectedCones();
            numSelectedCones = numel(cones);
            centers = zeros(1, numSelectedCones);
            radii = zeros(numSelectedCones, 2);
            types = cell(1, numSelectedCones);
            
            for i = 1:numSelectedCones
                [centers(i, :), radii(i), types{i}] = cones{i}.getLocationAndType();
            end
        end
        
        function cones = getSelectedCones(obj)
            isSelected = false(1, obj.numCones);
            
            for i = 1:obj.numCones
                isSelected(i) = obj.coneCircles{i}.isSelected();
            end
            
            cones = obj.coneCircles(isSelected);
        end
        
        function delete(obj)
            obj.runFunctionOnConeCircles(@(x) x.delete());
        end
    end
end
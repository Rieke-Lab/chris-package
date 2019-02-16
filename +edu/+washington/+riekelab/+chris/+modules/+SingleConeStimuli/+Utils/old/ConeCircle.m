classdef ConeCircle < handle
    properties
        center
        radius
        type
        selected
        axes
        selectedColor
        withStimColor
        circle
        protocolName = '';
        propertyMap
    end
    methods
        function obj = ConeCircle(center, radius, type, axes)
            obj.center = center;
            obj.radius = radius;
            obj.type = type;
            obj.axes = axes;
            [obj.selectedColor, obj.withStimColor] = ...
                edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.coneCircleColorLookup(obj.type);
            obj.draw();
        end
        
        function draw(obj)
            obj.circle = rectangle(obj.axes, ...
                'Position', obj.getPositionForDraw(), ...
                'EdgeColor', obj.selectedColor, ...
                'FaceColor', 'none');
        end
        
        function position = getPositionForDraw(obj)
            position = [(obj.center - obj.radius) obj.radius obj.radius];
        end
        
        function handleClick(obj, location)
            if ~obj.selected && obj.isWithin(location)
                obj.select();
            end
        end
        
        function tf = isWithin(obj, location)
            tf = norm(location - obj.center) <= obj.radius;
        end
        
        function fillCircle(obj)
            obj.circle.FaceColor = obj.selectedColor;
        end
        
        function unfillCircle(obj)
            obj.circle.FaceColor = obj.getUnfilledColor();
        end
        
        function select(obj)
            obj.selected = true;
            obj.fillCircle();
        end
        
        function unselect(obj)
            obj.selected = false;
            obj.unfillCircle();
        end
        
        function tf = isSelected(obj)
            tf = obj.selected;
        end
        
        function addStimulusIfSelected(obj, protocolName, propertyMap)
            if obj.selected
                obj.protocolName = protocolName;
                obj.propertyMap = propertyMap;
                obj.unselect();
            end
        end
        
        function clearStimulusIfSelected(obj)
            if obj.selected
                obj.clearStimulus();
                obj.unselect();
            end
        end
        
        function clearStimulus(obj)
            obj.protocolName = '';
            obj.propertyMap = [];
        end
        
        function stimulus = getStimulus(obj)
            stimulus = edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.SingleConeStimulus( ...
                obj.center, obj.radius, obj.protocolName, obj.propertyMap);
        end
        
        function tf = hasStimulus(obj)
            tf = ~isempty(obj.protocolName);
        end
        
        function fillColor = getUnfilledColor(obj)
            if obj.hasStimulus()
                fillColor = obj.withStimColor;
            else
                fillColor = 'none';
            end
        end
        
        function delete(obj)
            delete(obj.circle);
        end
    end
end
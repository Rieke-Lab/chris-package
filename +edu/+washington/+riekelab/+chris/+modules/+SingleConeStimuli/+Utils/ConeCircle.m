classdef ConeCircle < handle
    properties
        center
        radius
        type
        selected
        axes
        color
        circle
    end
    methods
        function obj = ConeCircle(center, radius, type, axes)
            obj.center = center;
            obj.radius = radius;
            obj.type = type;
            obj.axes = axes;
            obj.color = ...
                edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.coneCircleColorLookup(obj.type);
            obj.draw();
        end
        
        function draw(obj)
            obj.circle = rectangle(obj.axes, ...
                'Position', obj.getPositionForDraw(), ...
                'EdgeColor', obj.color, ...
                'FaceColor', 'none');
        end
        
        function position = getPositionForDraw(obj)
            position = [(obj.center - obj.radius) obj.radius obj.radius];
        end
        
        function [center, radius, type] = getLocationAndType(obj)
            center = obj.center;
            radius = obj.radius;
            type = obj.type;
        end
        
        function handleClick(obj, location)
            if obj.isWithin(location)
                if obj.selected()
                    obj.unselect();
                else
                    obj.select();
                end
            end
        end
        
        function tf = isWithin(obj, location)
            tf = norm(location - obj.center) <= obj.radius;
        end
        
        function fillCircle(obj)
            obj.circle.FaceColor = obj.color;
        end
        
        function unfillCircle(obj)
            obj.circle.FaceColor = 'none';
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
        
        function delete(obj)
            delete(obj.circle);
        end
    end
end
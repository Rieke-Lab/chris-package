classdef Cone < handle
    properties
        center
        radius
        type
    end
    
    methods
        function obj = Cone(center, radius)
            obj.center = center;
            obj.radius = radius;
            obj.type = 'unknown';
        end
        
        function pos = getCirclePositionForPlot(obj)
            pos = [obj.center obj.radius];
        end
        
        function pos = getCenterPosition(obj)
           pos = obj.center; 
        end
        
        function rad = getRadius(obj)
           rad = obj.radius; 
        end
        
        function setType(obj, newType)
            obj.type = newType;
        end
    end
end
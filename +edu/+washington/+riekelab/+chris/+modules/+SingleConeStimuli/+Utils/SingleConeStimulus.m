classdef SingleConeStimulus < handle
    properties
        center
        radius
        protocol
        propertyMap
    end
    
    methods
        function obj = SingleConeStimulus(center, radius, protocol, propertyMap)
            obj.center = center;
            obj.radius = radius;
            obj.protocol = protocol;
            obj.propertyMap = propertyMap;
        end
    end
end
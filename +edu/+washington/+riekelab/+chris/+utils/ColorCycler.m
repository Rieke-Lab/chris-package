classdef ColorCycler < handle
    properties (Constant)
       COLORS = {[0 0 1], [0 1 0], [1 0 0], [0 0.8 1], [0 0.8 0.2], [1 0.8 0.4]} 
    end
    
    properties
        numColors
        count
    end
    
    methods
        function obj = ColorCycler(numColors)
            if numColors > numel(obj.COLORS)
                error(['ColorCycler currently supports up to ' num2str(numel(obj.COLORS)) ' colors.']);
            end
            
            obj.numColors = numColors;
            obj.count = 1;
        end
        
        function c = Next(obj)
            c = obj.COLORS{mod(obj.count - 1, obj.numColors) + 1};
            obj.count = obj.count + 1;
        end
    end
end
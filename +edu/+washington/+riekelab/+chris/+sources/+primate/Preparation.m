classdef Preparation < edu.washington.riekelab.sources.Preparation
    
    methods
        
        function obj = Preparation()
            import symphonyui.core.*;
            
            obj.addAllowableParentType('edu.washington.riekelab.sources.primate.Primate');
        end
        
    end
    
end


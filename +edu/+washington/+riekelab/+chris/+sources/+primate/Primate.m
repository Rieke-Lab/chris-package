classdef Primate < edu.washington.riekelab.sources.Subject
    
    methods
        
        function obj = Primate()
            import symphonyui.core.*;
            import edu.washington.*;
            
            obj.addProperty('species', '', ...
                'type', PropertyType('char', 'row', {'', 'M. mulatta', 'M. fascicularis', 'M. nemestrina'}), ... 
                'description', 'Species');
            
            photoreceptors = containers.Map();
            photoreceptors('lCone') = struct( ...
                'collectingArea', containers.Map({'photoreceptorSide', 'ganglionCellSide'}, {0.37, 0.60}), ...
                'spectrum', importdata(riekelab.Package.getCalibrationResource('sources', 'primate', 'l_cone_spectrum.txt')));
            photoreceptors('mCone') = struct( ...
                'collectingArea', containers.Map({'photoreceptorSide', 'ganglionCellSide'}, {0.37, 0.60}), ...
                'spectrum', importdata(riekelab.Package.getCalibrationResource('sources', 'primate', 'm_cone_spectrum.txt')));
            photoreceptors('rod') = struct( ...
                'collectingArea', containers.Map({'photoreceptorSide', 'ganglionCellSide'}, {1.00, 1.00}), ...
                'spectrum', importdata(riekelab.Package.getCalibrationResource('sources', 'primate', 'rod_spectrum.txt')));
            photoreceptors('sCone') = struct( ...
                'collectingArea', containers.Map({'photoreceptorSide', 'ganglionCellSide'}, {0.37, 0.60}), ...
                'spectrum', importdata(riekelab.Package.getCalibrationResource('sources', 'primate', 's_cone_spectrum.txt')));
            obj.addResource('photoreceptors', photoreceptors);
            
            obj.addAllowableParentType([]);
        end
        
    end
    
end


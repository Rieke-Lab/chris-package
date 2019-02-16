classdef Panel < handle
    properties
        parentBox
        tabPanel
        controller
        
        imageBox % on the left
        buttonsBox
    end
    
    properties (Constant)
        BOX_RELATIVE_SIZES = [-3 -1];
        FLANKED_BUTTON_WIDTHS = [-1 -2 -1];
    end
    
    methods
        function obj = Panel(parentBox, tabPanel, controller)
            import appbox.*;
            
            obj.parentBox = parentBox;
            obj.tabPanel = tabPanel;
            obj.controller = controller;
            
            obj. imageBox = edu.washington.riekelab.baudin.modules.SingleConeStimuli.ImageBox(obj.parentBox);
            obj.buttonsBox = uix.VBox( ...
                'Parent', obj.parentBox);
            
            obj.parentBox.Widths = obj.BOX_RELATIVE_SIZES;
        end
        
        function setTabFunctionality(obj, idx, funct)
            obj.tabPanel.TabEnables{idx} = funct;
        end
        
        function contr = getController(obj)
            contr = obj.controller;
        end
    end
end
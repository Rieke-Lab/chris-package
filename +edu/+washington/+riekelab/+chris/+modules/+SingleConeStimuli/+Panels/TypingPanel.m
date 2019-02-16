classdef TypingPanel < edu.washington.riekelab.baudin.modules.SingleConeStimuli.Panels.Panel
    properties
        runTypingButton
    end
        
    properties (Constant)
        BUTTON_HEIGHT = 30;
    end
    
    methods
        function obj = TypingPanel(parentBox, tabPanel, controller)
            obj = obj@edu.washington.riekelab.baudin.modules.SingleConeStimuli.Panels.Panel(parentBox, tabPanel, controller);
            
            obj.imageBox.setTitle('Perform cone typing.');
            obj.constructButtonsBox();
            
            addlistener(obj.controller, 'updatedTyping', @obj.onUpdateTyping);
        end
        
        function constructButtonsBox(obj)
            import appbox.*;
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            obj.runTypingButton = edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Perform Typing', ...
                'Visible', 'off', ...
                'Callback', @obj.onRunTyping);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            obj.buttonsBox.Heights = [-1 obj.BUTTON_HEIGHT -10];
        end
        
        function activate(obj)
            obj.imageBox.displayImage(obj.controller.getConeMapWithCones());
            obj.setButtonVisibility('on');
        end
        
        function onRunTyping(obj, ~, ~)
            if obj.controller.conesAreTyped()
                toRun = ...
                    questdlg('Would you like to re-run the typing stimulus?', 'Overwrite', 'Yes', 'No', 'No');
            else
                toRun = true;
            end
            
            if toRun
                obj.controller.performTyping();
                % obj.imageBox.updateImage(obj.controller.getConeMapWithCones());
            end
        end
        
        function onUpdatedTyping(obj, ~, ~)
           obj.imageBox.updateImage(obj.controller.getConeMapWithCones()); 
        end
        
        function setButtonVisibility(obj, vis)
           obj.runTypingButton.Visible = vis;
        end
    end
end
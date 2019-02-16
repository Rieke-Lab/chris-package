classdef StimulusPanel < edu.washington.riekelab.baudin.modules.SingleConeStimuli.Panels.Panel
    properties
        selectableConeCircles
    end
    
    properties (Constant)
        BUTTON_HEIGHT = 30;
        TITLE_HEIGHT = 18;
    end
    
    methods
        function obj = StimulusPanel(parentBox, tabPanel, controller)
            obj = obj@edu.washington.riekelab.baudin.modules.SingleConeStimuli.Panels.Panel(parentBox, tabPanel, controller);
            obj.imageBox.setTitle('Perform cone typing.');
            obj.createButtonBox();
            addlistener(obj.controller, 'updatedTyping', @obj.onUpdatedTyping);
        end
        
        function activate(obj)
            obj.imageBox.displayImage(obj.controller.getConeMap());
            obj.imageBox.getImageObj().ButtonDownFcn = @obj.onClickedImage;
        end
        
        function createButtonBox(obj)
            % create a button for add stimulus to selected, clear from
            % selected, clear all, deliver stimulus
            import appbox.*;
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            uicontrol( ...
                'Parent', obj.buttonsBox, ...
                'Style', 'Text', ...
                'String', 'Cone selection:');
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Select all', ...
                'Visible', 'off', ...
                'Callback', @obj.onAddStimulus);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Unselect all', ...
                'Visible', 'off', ...
                'Callback', @obj.onClearStimulusOnSelected);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            uicontrol( ...
                'Parent', obj.buttonsBox, ...
                'Style', 'Text', ...
                'String', 'Stimulus delivery:');
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Deliver to selected', ...
                'Visible', 'off', ...
                'Callback', @obj.onViewStimulusOnSelected);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            obj.buttonsBox.Heights = [-1 obj.TITLE_HEIGHT 7 obj.BUTTON_HEIGHT 7 obj.BUTTON_HEIGHT ...
                -1 obj.TITLE_HEIGHT 7 obj.BUTTON_HEIGHT -1];
            
        end
        
        function drawConeCircles(obj)
            [centers, radii] = obj.controller.constructConeLocationMatrices();
            types = obj.controller.getConeTypes();
            obj.selectableConeCircles = ...
                edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.SelectableConeCircles( ...
                centers, radii, types, obj.imageBox.getImageAxes());
            
        end
        
        function onUpdatedTyping(obj, ~, ~)
            obj.selectableConeCircles.delete();
            obj.drawConeCircles();
        end
        
        function onClickedImage(obj, ~, ~)
            pos = obj.imageAxes.CurrentPoint(1, 1:2);
            obj.selectableConeCircles.handleClick(pos);
        end
        
        function onSelectAll(obj, ~, ~)
            obj.selectableConeCircles.selectAll();
        end
        
        function onUnselectAll(obj, ~, ~)
            obj.selectableConeCircles.unselectAll();
        end
        
        function onDeliverStimulus(obj, ~, ~)
            [centers, radii, types] = obj.selectableConeCircles.collectSelectedConeLocationsAndTypes();
            obj.controller.deliverStimulus(centers, radii, types);
        end
    end
end
classdef FittingBox < handle
    properties
        parentPanel
        controller
        
        imageAxes
        imageObj
        originalCData
        contentsBox
        
        selectConesBox
        runFitBox
        
        undoSelectionButton
        submitSelectionsButton
        runFitButton
        submitFitButton
        cancelFittingButton
        
        coneLocations = {};
        conePlottedPoints = {};
    end
    
    properties (Constant)
        BUTTON_HEIGHT = 30;
        TITLE_HEIGHT = 18;
        FLANKED_BUTTON_WIDTHS = [-1 -2 -1];
    end
    
    methods
        function obj = FittingBox(parentPanel)
            obj.parentPanel = parentPanel;
            obj.controller = obj.parentPanel.getController();
            obj.imageAxes = obj.parentPanel.getImageAxes();
            obj.constructPanel();
        end
        
        function constructPanel(obj)
            import appbox.*;
            import edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.*;
            
            parentBox = obj.parentPanel.buttonsBox;
            
            obj.contentsBox = addFlankedByEmptyVertical( ...
                @uix.VBox, parentBox, [-1 -10 -1]);
            
            uix.Empty( ...
                'Parent', obj.contentsBox);
            
            obj.selectConesBox = uix.VBox( ...
                'Parent', obj.contentsBox, ...
                'Visible', 'off');
            uicontrol( ...
                'Parent', obj.selectConesBox, ...
                'Style', 'Text', ...
                'String', 'Select Cone Centers:');
            obj.undoSelectionButton = addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.selectConesBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Undo Selection', ...
                'Callback', @obj.onUndoSelection);
            obj.submitSelectionsButton = addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.selectConesBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Submit', ...
                'Callback', @obj.onSubmitSelections);
            obj.selectConesBox.Heights = [obj.TITLE_HEIGHT obj.BUTTON_HEIGHT obj.BUTTON_HEIGHT];
            
            uix.Empty( ...
                'Parent', obj.contentsBox);
            
            obj.runFitBox = uix.VBox( ...
                'Parent', obj.contentsBox, ...
                'Visible', 'off');
            uicontrol( ...
                'Parent', obj.runFitBox, ...
                'Style', 'Text', ...
                'String', 'Fit Cone Locations:');
            obj.runFitButton = addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.runFitBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Run Fit', ...
                'Callback', @obj.onRunFit);
            obj.submitFitButton = addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.runFitBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Submit Fit', ...
                'Callback', @obj.onSubmitFit);
            obj.runFitBox.Heights = [obj.TITLE_HEIGHT obj.BUTTON_HEIGHT obj.BUTTON_HEIGHT];
            
            uix.Empty( ...
                'Parent', obj.contentsBox);
            
            obj.cancelFittingButton = addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.contentsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Cancel', ...
                'Visible', 'off', ...
                'Callback', @obj.onCancelFitting);
            
            uix.Empty( ...
                'Parent', obj.contentsBox);
            
            obj.contentsBox.Heights = [-0 sum(obj.selectConesBox.Heights) -10 sum(obj.runFitBox.Heights) -50 obj.BUTTON_HEIGHT -100];
            
        end
        
        function run(obj)
            % lock other buttons, make first panel available
            obj.parentPanel.inactivateButtons();
            obj.setSelectionBoxVisibility('on');
            obj.setCancelButtonVisibility('on');
            obj.imageObj = obj.parentPanel.getImageObj();
            
            obj.coneLocations = {};
            obj.imageObj.ButtonDownFcn = @obj.onClickedImage;
            obj.imageAxes.NextPlot = 'add';
        end
        
        function reset(obj)
            obj.setSelectionBoxVisibility('off');
            obj.setRunFitBoxVisibility('off');
            obj.setCancelButtonVisibility('off');
            obj.setSelectionBoxFunctionality('on');
            obj.setRunFitButtonFunctionality('on');
        end
        
        function onClickedImage(obj, ~, ~)
            pos = obj.imageAxes.CurrentPoint(1, 1:2);
            obj.coneLocations{end + 1} = pos;
            obj.conePlottedPoints{end + 1} = plot(obj.imageAxes, pos(1), pos(2), ...
                'Marker', '.', ...
                'MarkerSize', 30);
        end
        
        function onSubmitSelections(obj, ~, ~)
            if numel(obj.coneLocations) > 0
                obj.setSelectionBoxFunctionality('off');
                obj.controller.addUserDefinedConeLocations(obj.coneLocations);
                obj.setRunFitBoxVisibility('on');
                obj.setSubmitFitButtonFunctionality('off');
            end
        end
        
        function setSelectionBoxVisibility(obj, vis)
            obj.selectConesBox.Visible = vis;
        end
        
        function setSelectionBoxFunctionality(obj, funct)
            obj.undoSelectionButton.Enable = funct;
            obj.submitSelectionsButton.Enable = funct;
        end
        
        function setRunFitBoxVisibility(obj, vis)
            obj.runFitBox.Visible = vis;
        end
        
        function setCancelButtonVisibility(obj, vis)
            obj.cancelFittingButton.Visible = vis;
        end
        
        function onUndoSelection(obj, ~, ~)
            if numel(obj.coneLocations)
                obj.coneLocations = obj.coneLocations(1:end - 1);
                obj.conePlottedPoints{end}.delete();
                obj.conePlottedPoints = obj.conePlottedPoints(1:end - 1);
            end
        end
        
        function onCancelFitting(obj, ~, ~)
            obj.clearConeLocationsAndPoints();
            obj.controller.resetConeLocations();
            obj.reset();
            obj.imageObj.CData = obj.controller.getConeMap();
            obj.parentPanel.activateButtons();
        end
        
        function clearConeLocationsAndPoints(obj)
            obj.coneLocations = {};
            obj.clearConePoints();
        end
        
        function clearConePoints(obj)
            for i = 1:numel(obj.conePlottedPoints)
                obj.conePlottedPoints{i}.delete();
            end
            obj.conePlottedPoints = {};
        end
        
        function setRunFitButtonFunctionality(obj, funct)
            obj.runFitButton.Enable = funct;
        end
        
        function setSubmitFitButtonFunctionality(obj, funct)
            obj.submitFitButton.Enable = funct;
        end
        
        function onRunFit(obj, ~, ~)
            obj.setRunFitButtonFunctionality('off');
            obj.setSubmitFitButtonFunctionality('on');
            obj.controller.runConeLocationFit();
            obj.clearConePoints();
            obj.imageObj.CData = obj.controller.getConeMapWithCones();
        end
        
        function onSubmitFit(obj, ~, ~)
            disp('SUBMITTING THE ACTUAL FIT!!!');
            obj.controller.acceptFit();
            obj.reset();
            obj.parentPanel.resetButtons();
        end
    end
end

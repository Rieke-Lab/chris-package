classdef FittingPanel < edu.washington.riekelab.baudin.modules.SingleConeStimuli.Panels.Panel
    properties
        imageLoaded
    end
    
    properties % ui elements
       loadButton
       fitButton 
       fittingBox
    end
    
    methods
        function obj = FittingPanel(parentBox, tabPanel, controller)
            obj = obj@edu.washington.riekelab.baudin.modules.SingleConeStimuli.Panels.Panel(parentBox, tabPanel, controller);
            
            obj.imageBox.setTitle('Load an image.');
            obj.constructButtonsBox();
            
            obj.imageLoaded = false;
        end
        
        function constructButtonsBox(obj)
            import appbox.*;
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            % make button for fitting, start invisible
            obj.fitButton = edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Fit Cone Map', ...
                'Visible', 'off', ...
                'Callback', @obj.onFitConeMap);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            obj.fittingBox = edu.washington.riekelab.baudin.modules.SingleConeStimuli.FittingBox(obj);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            % make button for loading
            obj.loadButton = edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyHorizontal( ...
                @uicontrol, obj.buttonsBox, obj.FLANKED_BUTTON_WIDTHS, ...
                'Style', 'pushbutton', ...
                'String', 'Load Cone Map', ...
                'Callback', @obj.onLoadConeMap);
            
            uix.Empty( ...
                'Parent', obj.buttonsBox);
            
            obj.buttonsBox.Heights = [-4 -2 -2 -24 -2 -2 -1];
        end
        
        function resetButtons(obj)
            obj.hideFitButton();
            obj.activateButtons();
            obj.fittingBox.reset();
        end
                
        function onLoadConeMap(obj, ~, ~) 
            if obj.imageLoaded
                toLoad = strcmp('Yes', ...
                    questdlg('Would you like to overwrite the current image?', 'Overwrite', 'Yes', 'No', 'No'));
            else
                toLoad = true;
            end
            
            if toLoad
                % open file window
                [fileName, filePath, ~] = uigetfile('*.mat');
                
                if fileName
                    % load file, via the controller
                    obj.controller.loadConeMap(fullfile(filePath, fileName));
                    
                    % display the image, from controller
                    obj.imageBox.displayImage(obj.controller.getConeMap());
                    
                    obj.imageLoaded = true;
                    obj.showFitButton();
                    obj.imageBox.setTitle('Fit cone map or load new image.');
                end
            end
        end
        
        function showFitButton(obj)
            obj.fitButton.Visible = 'on';
        end
        
        function hideFitButton(obj)
           obj.fitButton.Visible = 'off'; 
        end
        
        function onFitConeMap(obj, ~, ~)
            obj.fittingBox.run();
        end
        
        function inactivateButtons(obj)
            obj.loadButton.Enable = 'off';
            obj.fitButton.Enable = 'off';
        end
        
        function activateButtons(obj)
            obj.loadButton.Enable = 'on';
            obj.fitButton.Enable = 'on';
        end
        
        function ax = getImageAxes(obj)
            ax = obj.imageBox.getImageAxes();
        end
        
        function im = getImageObj(obj)
            im = obj.imageBox.getImageObj();
        end
    end
end
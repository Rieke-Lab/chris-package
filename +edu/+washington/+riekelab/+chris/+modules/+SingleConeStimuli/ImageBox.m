classdef ImageBox < handle
    properties
        title
        imageAxes
        imageObj
    end
    
    methods
        function obj = ImageBox(parentBox)
            import appbox.*;
            
            % make a title bar and a place for the image beneath it
            mainBox = uix.VBox( ...
                'Parent', parentBox);
            
            obj.title = edu.washington.riekelab.baudin.modules.SingleConeStimuli.Utils.addFlankedByEmptyVertical( ...
                @uicontrol, mainBox, [-6 -20 -3], ...
                'Style', 'text', ...
                'FontSize', 22);
            
            obj.imageAxes = axes( ...
                'Parent', mainBox, ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1]);
            obj.imageAxes.XAxis.Visible = 'off';
            obj.imageAxes.YAxis.Visible = 'off';
            mainBox.Heights = [-1 -10];
            
            % display blank space until image is loaded
            obj.displayImage(0.9 * ones(300, 400, 3));
        end
        
        function displayImage(obj, imArray)
            obj.imageObj = imagesc(obj.imageAxes, imArray);
            obj.rehideAxesLines();
        end
        
        function setImageCallback(obj, fxn)
            obj.imageObj.ButtonDownFcn = fxn;
        end
        
        function setTitle(obj, title)
            obj.title.String = title;
        end
        
        function rehideAxesLines(obj)
            obj.imageAxes.XAxis.Visible = 'off';
            obj.imageAxes.YAxis.Visible = 'off';
        end
        
        function ax = getImageAxes(obj)
            ax = obj.imageAxes;
        end
        
        function im = getImageObj(obj)
            im = obj.imageObj;
        end
        
        function updateImage(obj, cdata)
            obj.imageObj.CData = cdata;
        end
    end
end
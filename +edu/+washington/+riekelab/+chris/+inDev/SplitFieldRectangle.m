classdef SplitFieldRectangle < stage.core.Stimulus
    % A split-field rectangle stimulus with three regions:
    % - Left: Adjustable color and opacity.
    % - Middle: Adjustable color and opacity.
    % - Right: Adjustable color and opacity.
    % The size of the middle gap is user-defined in pixels.

    properties
        position = [0, 0]       % Center position on the canvas [x, y] (pixels)
        size = [300, 100]       % Size [width, height] (pixels)
        orientation = 0         % Orientation (degrees)
        leftColor = [1, 0, 0]   % Color of the left region [R, G, B] (0 to 1)
        middleColor = [0, 1, 0] % Color of the middle region [R, G, B] (0 to 1)
        rightColor = [0, 0, 1]  % Color of the right region [R, G, B] (0 to 1)
        leftOpacity = 1         % Opacity of the left region (0 to 1)
        middleOpacity = 1       % Opacity of the middle region (0 to 1)
        rightOpacity = 1        % Opacity of the right region (0 to 1)
        gapSize = 30            % Width of the middle gap in pixels
    end

    properties (Access = private)
        mask    % Stimulus mask
        vbo     % Vertex buffer object
        vao     % Vertex array object
    end

    methods

        function init(obj, canvas)
            init@stage.core.Stimulus(obj, canvas);

            % Initialize the mask if it exists
            if ~isempty(obj.mask)
                obj.mask.init(canvas);
            end

            % Calculate the gap fraction based on gapSize (pixels) and total width (pixels)
            totalWidth = obj.size(1);
            gapFraction = obj.gapSize / totalWidth;
            
            % Validate the gap size
            if gapFraction < 0 || gapFraction > 1
                error('gapSize too large for the stimulus width. Reduce gapSize or increase width.');
            end
            
            % Calculate the relative widths of the left, middle, and right regions
            gapWidth = gapFraction;
            leftWidth = (1 - gapWidth) / 2;
            rightWidth = leftWidth;

            % Each vertex position is followed by a mask coordinate.
            vertexData = [
                % Left region
                -1  1  0  1,  0  1 ...
                -1 -1  0  1,  0  0 ...
                -1 + 2*leftWidth  1  0  1,  leftWidth  1 ...
                -1 + 2*leftWidth -1  0  1,  leftWidth  0 ...
                % Middle region
                -1 + 2*leftWidth  1  0  1,  leftWidth  1 ...
                -1 + 2*leftWidth -1  0  1,  leftWidth  0 ...
                -1 + 2*leftWidth + 2*gapWidth  1  0  1,  leftWidth + gapWidth  1 ...
                -1 + 2*leftWidth + 2*gapWidth -1  0  1,  leftWidth + gapWidth  0 ...
                % Right region
                -1 + 2*leftWidth + 2*gapWidth  1  0  1,  leftWidth + gapWidth  1 ...
                -1 + 2*leftWidth + 2*gapWidth -1  0  1,  leftWidth + gapWidth  0 ...
                 1  1  0  1,  1  1 ...
                 1 -1  0  1,  1  0
            ];

            obj.vbo = stage.core.gl.VertexBufferObject(canvas, GL.ARRAY_BUFFER, single(vertexData), GL.STATIC_DRAW);

            obj.vao = stage.core.gl.VertexArrayObject(canvas);
            obj.vao.setAttribute(obj.vbo, 0, 4, GL.FLOAT, GL.FALSE, 6*4, 0);
            obj.vao.setAttribute(obj.vbo, 1, 2, GL.FLOAT, GL.FALSE, 6*4, 4*4);
        end

        function setMask(obj, mask)
            % Assigns a mask to the stimulus.
            obj.mask = mask;
        end

    end

    methods (Access = protected)

        function performDraw(obj)
            modelView = obj.canvas.modelView;
            modelView.push();
            modelView.translate(obj.position(1), obj.position(2), 0);
            modelView.rotate(obj.orientation, 0, 0, 1);
            modelView.scale(obj.size(1) / 2, obj.size(2) / 2, 1);

            % Draw the left region
            c = [obj.leftColor, obj.leftOpacity];
            obj.canvas.drawArray(obj.vao, GL.TRIANGLE_STRIP, 0, 4, c, obj.mask);

            % Draw the middle region
            c = [obj.middleColor, obj.middleOpacity];
            obj.canvas.drawArray(obj.vao, GL.TRIANGLE_STRIP, 4, 4, c, obj.mask);

            % Draw the right region
            c = [obj.rightColor, obj.rightOpacity];
            obj.canvas.drawArray(obj.vao, GL.TRIANGLE_STRIP, 8, 4, c, obj.mask);

            modelView.pop();
        end

    end

end
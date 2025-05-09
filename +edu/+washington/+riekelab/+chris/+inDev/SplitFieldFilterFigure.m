classdef SplitFieldRectangle < stage.core.Stimulus
    % A split-field rectangle stimulus with individually controllable left, middle, and right sections.
    % This version uses a single initialization but still allows dynamic updates to section positions.
    
    properties
        position = [0, 0]           % Center position on the canvas [x, y] (pixels)
        size = [100, 100]           % Overall size [width, height] (pixels)
        gapSize = 10                % Width of the middle section/gap (pixels)
        orientation = 0             % Orientation (degrees)
        leftColor = [1, 1, 1]       % Left section color as single intensity value or [R, G, B] (0 to 1)
        middleColor = [0, 0, 0]     % Middle section color as single intensity value or [R, G, B] (0 to 1)
        rightColor = [1, 1, 1]      % Right section color as single intensity value or [R, G, B] (0 to 1)
        leftOpacity = 1             % Left section opacity (0 to 1)
        middleOpacity = 1           % Middle section opacity (0 to 1)
        rightOpacity = 1            % Right section opacity (0 to 1)
    end

    properties (Access = private)
        mask                        % Stimulus mask
        vbo                         % Vertex buffer object
        vao                         % Vertex array object
    end

    methods
        function init(obj, canvas)
            init@stage.core.Stimulus(obj, canvas);

            if ~isempty(obj.mask)
                obj.mask.init(canvas);
            end

            % Initialize with placeholder data - will be updated in first draw
            % 12 vertices for 3 quads (left, middle, right sections)
            vertexData = zeros(1, 12 * 6); % Each vertex has 6 components (pos + tex)
            obj.vbo = stage.core.gl.VertexBufferObject(canvas, GL.ARRAY_BUFFER, single(vertexData), GL.DYNAMIC_DRAW);

            obj.vao = stage.core.gl.VertexArrayObject(canvas);
            obj.vao.setAttribute(obj.vbo, 0, 4, GL.FLOAT, GL.FALSE, 6*4, 0);
            obj.vao.setAttribute(obj.vbo, 1, 2, GL.FLOAT, GL.FALSE, 6*4, 4*4);
            
            % Initial update of vertex positions
            obj.updateSectionPositions();
        end
        
        function setMask(obj, mask)
            % Assigns a mask to the stimulus.
            obj.mask = mask;
        end
        
        function updateSectionPositions(obj)
            % Calculate the position of each section based on the overall size and gap size
            totalWidth = obj.size(1);
            halfGap = obj.gapSize / 2;
            
            % Calculate normalized coordinates for the section boundaries
            leftEnd = -0.5 + (totalWidth/2 - halfGap) / totalWidth;
            rightStart = 0.5 - (totalWidth/2 - halfGap) / totalWidth;
            
            % Combine all vertex data into one array
            vertexData = [
                % Left section (4 vertices with pos + tex)
                -1      1  0  1,  0  1, ...
                -1     -1  0  1,  0  0, ...
                leftEnd  1  0  1,  1  1, ...
                leftEnd -1  0  1,  1  0, ...
                
                % Middle section (4 vertices with pos + tex)
                leftEnd     1  0  1,  0  1, ...
                leftEnd    -1  0  1,  0  0, ...
                rightStart  1  0  1,  1  1, ...
                rightStart -1  0  1,  1  0, ...
                
                % Right section (4 vertices with pos + tex)
                rightStart  1  0  1,  0  1, ...
                rightStart -1  0  1,  0  0, ...
                1           1  0  1,  1  1, ...
                1          -1  0  1,  1  0  ...
            ];
            
            % Update the vertex buffer object with all data at once
            obj.vbo.uploadData(single(vertexData));
        end
    end

    methods (Access = protected)
        function performDraw(obj)
            % Update section positions based on current gap size
            obj.updateSectionPositions();
            
            modelView = obj.canvas.modelView;
            modelView.push();
            modelView.translate(obj.position(1), obj.position(2), 0);
            modelView.rotate(obj.orientation, 0, 0, 1);
            modelView.scale(obj.size(1) / 2, obj.size(2) / 2, 1);

            % Draw left section
            leftC = obj.leftColor;
            if length(leftC) == 1
                leftC = [leftC, leftC, leftC, obj.leftOpacity];
            elseif length(leftC) == 3
                leftC = [leftC, obj.leftOpacity];
            end
            obj.canvas.drawArray(obj.vao, GL.TRIANGLE_STRIP, 0, 4, leftC, obj.mask);

            % Draw middle section
            middleC = obj.middleColor;
            if length(middleC) == 1
                middleC = [middleC, middleC, middleC, obj.middleOpacity];
            elseif length(middleC) == 3
                middleC = [middleC, obj.middleOpacity];
            end
            obj.canvas.drawArray(obj.vao, GL.TRIANGLE_STRIP, 4, 4, middleC, obj.mask);

            % Draw right section
            rightC = obj.rightColor;
            if length(rightC) == 1
                rightC = [rightC, rightC, rightC, obj.rightOpacity];
            elseif length(rightC) == 3
                rightC = [rightC, obj.rightOpacity];
            end
            obj.canvas.drawArray(obj.vao, GL.TRIANGLE_STRIP, 8, 4, rightC, obj.mask);

            modelView.pop();
        end
    end
end
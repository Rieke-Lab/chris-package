classdef SplitFieldRectangle < stage.core.Stimulus
    % A split-field rectangle stimulus with individually controllable left, middle, and right sections.
    
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
        leftVbo                     % Left section vertex buffer object
        middleVbo                   % Middle section vertex buffer object
        rightVbo                    % Right section vertex buffer object
        leftVao                     % Left section vertex array object
        middleVao                   % Middle section vertex array object
        rightVao                    % Right section vertex array object
    end

    methods
        function init(obj, canvas)
            init@stage.core.Stimulus(obj, canvas);

            if ~isempty(obj.mask)
                obj.mask.init(canvas);
            end

            % Initialize the three sections of the split field
            obj.initLeftSection(canvas);
            obj.initMiddleSection(canvas);
            obj.initRightSection(canvas);
        end
        
        function initLeftSection(obj, canvas)
            % Each vertex position is followed by a mask coordinate.
            % Left section vertices (normalized coordinates)
            vertexData = [-1  1  0  1,  0  1 ...
                          -1 -1  0  1,  0  0 ...
                           0  1  0  1,  1  1 ...
                           0 -1  0  1,  1  0];

            obj.leftVbo = stage.core.gl.VertexBufferObject(canvas, GL.ARRAY_BUFFER, single(vertexData), GL.STATIC_DRAW);

            obj.leftVao = stage.core.gl.VertexArrayObject(canvas);
            obj.leftVao.setAttribute(obj.leftVbo, 0, 4, GL.FLOAT, GL.FALSE, 6*4, 0);
            obj.leftVao.setAttribute(obj.leftVbo, 1, 2, GL.FLOAT, GL.FALSE, 6*4, 4*4);
        end
        
        function initMiddleSection(obj, canvas)
            % Middle section vertices (normalized coordinates)
            vertexData = [0  1  0  1,  0  1 ...
                          0 -1  0  1,  0  0 ...
                          0.2  1  0  1,  1  1 ...
                          0.2 -1  0  1,  1  0];

            obj.middleVbo = stage.core.gl.VertexBufferObject(canvas, GL.ARRAY_BUFFER, single(vertexData), GL.STATIC_DRAW);

            obj.middleVao = stage.core.gl.VertexArrayObject(canvas);
            obj.middleVao.setAttribute(obj.middleVbo, 0, 4, GL.FLOAT, GL.FALSE, 6*4, 0);
            obj.middleVao.setAttribute(obj.middleVbo, 1, 2, GL.FLOAT, GL.FALSE, 6*4, 4*4);
        end
        
        function initRightSection(obj, canvas)
            % Right section vertices (normalized coordinates)
            vertexData = [0.2  1  0  1,  0  1 ...
                          0.2 -1  0  1,  0  0 ...
                          1    1  0  1,  1  1 ...
                          1   -1  0  1,  1  0];

            obj.rightVbo = stage.core.gl.VertexBufferObject(canvas, GL.ARRAY_BUFFER, single(vertexData), GL.STATIC_DRAW);

            obj.rightVao = stage.core.gl.VertexArrayObject(canvas);
            obj.rightVao.setAttribute(obj.rightVbo, 0, 4, GL.FLOAT, GL.FALSE, 6*4, 0);
            obj.rightVao.setAttribute(obj.rightVbo, 1, 2, GL.FLOAT, GL.FALSE, 6*4, 4*4);
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
            
            % Update left section vertices
            leftVertexData = [-1    1  0  1,  0  1 ...
                              -1   -1  0  1,  0  0 ...
                              leftEnd  1  0  1,  1  1 ...
                              leftEnd -1  0  1,  1  0];
            
            % Update middle section vertices
            middleVertexData = [leftEnd     1  0  1,  0  1 ...
                                leftEnd    -1  0  1,  0  0 ...
                                rightStart  1  0  1,  1  1 ...
                                rightStart -1  0  1,  1  0];
            
            % Update right section vertices
            rightVertexData = [rightStart  1  0  1,  0  1 ...
                               rightStart -1  0  1,  0  0 ...
                               1           1  0  1,  1  1 ...
                               1          -1  0  1,  1  0];
            
            % Update the vertex buffer objects
            obj.leftVbo.uploadData(single(leftVertexData));
            obj.middleVbo.uploadData(single(middleVertexData));
            obj.rightVbo.uploadData(single(rightVertexData));
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
            obj.canvas.drawArray(obj.leftVao, GL.TRIANGLE_STRIP, 0, 4, leftC, obj.mask);

            % Draw middle section
            middleC = obj.middleColor;
            if length(middleC) == 1
                middleC = [middleC, middleC, middleC, obj.middleOpacity];
            elseif length(middleC) == 3
                middleC = [middleC, obj.middleOpacity];
            end
            obj.canvas.drawArray(obj.middleVao, GL.TRIANGLE_STRIP, 0, 4, middleC, obj.mask);

            % Draw right section
            rightC = obj.rightColor;
            if length(rightC) == 1
                rightC = [rightC, rightC, rightC, obj.rightOpacity];
            elseif length(rightC) == 3
                rightC = [rightC, obj.rightOpacity];
            end
            obj.canvas.drawArray(obj.rightVao, GL.TRIANGLE_STRIP, 0, 4, rightC, obj.mask);

            modelView.pop();
        end
    end
end
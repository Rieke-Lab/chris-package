classdef SineGenerator < symphonyui.core.StimulusGenerator
    % Generates a sinewave-modulated gaussian noise stimulus.  Built based
    % on GaussianNoiseGeneratorV2
    
    properties
        preTime             % Leading duration (ms)
        stimTime            % Noise duration (ms)
        tailTime            % Trailing duration (ms)
        sinFreq             % Frequency of sinewave 
        contr               % Contrast for sinewave
        mean                % Mean amplitude (units)
        mult                % Multiplier to invert sine polarity
        upperLimit = inf    % Upper bound on signal, signal is clipped to this value (units)
        lowerLimit = -inf   % Lower bound on signal, signal is clipped to this value (units)
        sampleRate          % Sample rate of generated stimulus (Hz)
        units               % Units of generated stimulus
    end
    
    methods
        
        function obj = SineGenerator(map)
            if nargin < 1
                map = containers.Map();
            end
            obj@symphonyui.core.StimulusGenerator(map);
        end
        
    end
    
    methods (Access = protected)
        
        function s = generateStimulus(obj)
            import Symphony.Core.*;
            
            timeToPts = @(t)(round(t * obj.sampleRate));
            
            prePts = timeToPts(obj.preTime);
            stimPts = timeToPts(obj.stimTime);
            tailPts = timeToPts(obj.tailTime);
                       
            data = ones(1, prePts + stimPts + tailPts) * obj.mean;
            sinStim = sin((0:stimPts-1)*2*pi*obj.sinFreq/obj.sampleRate) * obj.mean * obj.contr * obj.mult;
            
            data(prePts + 1:prePts + stimPts) = sinStim;
            
            % Clip signal to upper and lower limit.
            % NOTE: IF THERE ARE POINTS THAT ARE ACTUALLY OUT OF BOUNDS, THIS WILL MAKE IT SO THAT THE EXPECTATION OF 
            % THE STANDARD DEVIATION IS NO LONGER WHAT WAS SPECIFIED...
            data(data > obj.upperLimit) = obj.upperLimit;
            data(data < obj.lowerLimit) = obj.lowerLimit;
            
                                 
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            measurements = Measurement.FromArray(data, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
        end
        
    end
    
end


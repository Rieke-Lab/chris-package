classdef asymmetricPairPulseGenerator < symphonyui.core.StimulusGenerator
    % Generates a two-pulse stimulus with independent amplitudes.
    
    properties
        preTime
        pulseTime
        intervalTime
        tailTime
        
        amplitude1
        amplitude2
        
        mean
        sampleRate
        units
    end
    
    methods
        
        function obj = asymmetricPairPulseGenerator(map)
            if nargin < 1
                map = containers.Map();
            end
            obj@symphonyui.core.StimulusGenerator(map);
        end
        
    end
    
    methods (Access = protected)
        
        function s = generateStimulus(obj)
            
            import Symphony.Core.*
            
            timeToPts = @(t)(round(t / 1e3 * obj.sampleRate));
            
            prePts  = timeToPts(obj.preTime);
            pulsePts = timeToPts(obj.pulseTime);
            intervalPts = timeToPts(obj.intervalTime);
            tailPts = timeToPts(obj.tailTime);
            
            totalPts = prePts + pulsePts + intervalPts + pulsePts + tailPts;
            
            data = ones(1, totalPts) * obj.mean;
            
            % Pulse 1
            p1Start = prePts + 1;
            p1End   = prePts + pulsePts;
            data(p1Start:p1End) = obj.mean + obj.amplitude1;
            
            % Pulse 2
            p2Start = p1End + intervalPts + 1;
            p2End   = p2Start + pulsePts - 1;
            data(p2Start:p2End) = obj.mean + obj.amplitude2;
            
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            measurements = Measurement.FromArray(data, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
        end
        
    end
    
end
classdef SinusoidPlusNoiseGenerator < symphonyui.core.StimulusGenerator
    % Generates a stimulus combining a sinusoidal modulation with Gaussian noise.
    
    properties
        preTime             % Leading duration (ms)
        stimTime            % Stimulus duration (ms)
        tailTime            % Trailing duration (ms)
        noiseStdv           % Noise standard deviation, as fraction of mean
        freqCutoff          % Noise frequency cutoff for smoothing (Hz)
        numFilters = 4      % Number of filters in cascade for smoothing
        temporalContrast    % Contrast of sinusoidal modulation (0-1)
        temporalFrequency   % Frequency of sinusoidal modulation (Hz)
        phase = 0           % Sine wave phase offset (radians)
        mean                % Mean amplitude (units)
        seed                % Random number generator seed
        upperLimit = inf    % Upper bound on signal, signal is clipped to this value
        lowerLimit = -inf   % Lower bound on signal, signal is clipped to this value
        sampleRate          % Sample rate of generated stimulus (Hz)
        units               % Units of generated stimulus
    end
    
    properties (Access = private)
        sinusoidValues      % Store sinusoidal component values
        noiseValues         % Store noise component values
    end
    
    methods
        
        function obj = SinusoidPlusNoiseGenerator(map)
            if nargin < 1
                map = containers.Map();
            end
            obj@symphonyui.core.StimulusGenerator(map);
        end
        
    end
    
    methods (Access = protected)
        
        function s = generateStimulus(obj)
            import Symphony.Core.*;
            
            timeToPts = @(t)(round(t / 1e3 * obj.sampleRate));
            
            prePts = timeToPts(obj.preTime);
            stimPts = timeToPts(obj.stimTime);
            tailPts = timeToPts(obj.tailTime);
            
            % Generate sinusoidal component
            freq = 2 * pi * obj.temporalFrequency;
            time = (0:stimPts-1) / obj.sampleRate;
            sinusoid = obj.mean + obj.mean * obj.temporalContrast * sin(freq * time + obj.phase);
            
            % Store sinusoid values (for analysis)
            obj.sinusoidValues = ones(1, prePts + stimPts + tailPts) * obj.mean;
            obj.sinusoidValues(prePts + 1:prePts + stimPts) = sinusoid;
            
            % Initialize random number generator for noise
            stream = RandStream('mt19937ar', 'Seed', obj.seed);
            
            % Create gaussian noise
            noiseTime = obj.noiseStdv * obj.mean * stream.randn(1, stimPts);
            
            % To frequency domain for filtering
            noiseFreq = fft(noiseTime);
            
            % Construct the filter based on even/odd number of points
            freqStep = obj.sampleRate / stimPts;
            if mod(stimPts, 2) == 0
                % Construct the filter for even number of points
                frequencies = (0:stimPts / 2) * freqStep;
                oneSidedFilter = 1 ./ (1 + (frequencies / obj.freqCutoff) .^ (2 * obj.numFilters));
                filter = [oneSidedFilter fliplr(oneSidedFilter(2:end - 1))];
            else
                % Construct the filter for odd number of points
                frequencies = (0:(stimPts - 1) / 2) * freqStep;
                oneSidedFilter = 1 ./ (1 + (frequencies / obj.freqCutoff) .^ (2 * obj.numFilters));
                filter = [oneSidedFilter fliplr(oneSidedFilter(2:end))];
            end
            
            % Calculate filter factor for standard deviation correction
            filterFactor = sqrt(filter(2:end) * filter(2:end)' / (stimPts - 1));
            
            % Filter in frequency domain
            noiseFreq = noiseFreq .* filter;
            
            % Set first value of fft (mean in time domain) to 0
            noiseFreq(1) = 0;
            
            % Back to time domain
            noiseTime = ifft(noiseFreq);
            
            % Rescale to maintain desired standard deviation
            noiseTime = noiseTime / filterFactor;
            
            noiseTime = real(noiseTime);
            
            % Store noise values (for analysis)
            obj.noiseValues = ones(1, prePts + stimPts + tailPts) * obj.mean;
            obj.noiseValues(prePts + 1:prePts + stimPts) = noiseTime + obj.mean;
            
            % Combine sinusoid and noise
            data = ones(1, prePts + stimPts + tailPts) * obj.mean;
            data(prePts + 1:prePts + stimPts) = sinusoid + noiseTime;
            
            % Clip signal to upper and lower limit
            data(data > obj.upperLimit) = obj.upperLimit;
            data(data < obj.lowerLimit) = obj.lowerLimit;
            
            % Create stimulus
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            
            % Add component values to parameters for analysis
%             parameters.Add('sinusoidValues', obj.sinusoidValues);
%             parameters.Add('noiseValues', obj.noiseValues);
            
            measurements = Measurement.FromArray(data, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
        end
        
    end
    
end
function results = spikeDetectorOnline(data, threshold, sampleRate)
    % A fast spike detector function for online analysis. data is a matrix of spike recording data. threshold is the
    % deflection threshold to call an event a spike and not noise. If no threshold is provided, 1/3 maximum deflection
    % amplitude is used as threshold. This does a pretty good job for big-ish spikes and it's fast. Use something more
    % versatile for offline analysis.
    %
    % MHT 08/05/14
    %
    % AIW 12/10/14
    % Added section "Make sure detected spikes aren't just noise". Previously, code would find many spikes on trials 
    % with no spikes.
    
    if (nargin < 2)
        threshold = []; % define on trace-by-trace basis automatically, as 1/3rd of maximum deflection. Decent job.
        sampleRate = 1e4; % Hz, default at 10kHz
    end
    
    highPassCutSpikes = 500; % Hz, in order to remove everything but spikes
    sampleInterval = sampleRate^-1;
    refPeriod = 2E-3; % s
    refPeriodPoints = round(refPeriod./sampleInterval); % data points

    [nTraces, ~] = size(data);
    dataHighpass = edu.washington.riekelab.util.highPassFilter(data, highPassCutSpikes, sampleInterval);

    % Initialize output stuff
    sp = cell(nTraces, 1);
    spikeAmps = cell(nTraces, 1);
    violationInd = cell(nTraces, 1);

    for i=1:nTraces
        % Get the trace
        trace = dataHighpass(i,:);
        trace = trace - median(trace); % remove baseline
        if abs(max(trace)) < abs(min(trace)) % flip it over
            trace = -trace;
        end
        if isempty(threshold)
            threshold = max(trace)/3;
        end
        
        % Get peaks
        [peaks, peakTimes] = edu.washington.riekelab.util.getPeaks(trace, 1); % positive peaks
        peakTimes = peakTimes(peaks>0); % only positive deflections
        peaks = trace(peakTimes);
        peakTimes = peakTimes(peaks>threshold);      
        peaks = peaks(peaks>threshold);

        % Make sure detected spikes aren't just noise
        peakIdx = zeros(size(trace));
        peakIdx(peakTimes) = 1;
        nonspikePeaks = trace(~peakIdx); % trace values at time points that weren't detected as spikes
        % Compare magnitude of detected spikes to trace values that aren't "spikes"
        if mean((peaks)) < mean((nonspikePeaks)) + 4*std((nonspikePeaks)); % avg spike must be 4 stdevs from average non-spike, otherwise no spikes
            peakTimes = [];
            peaks = [];
        end

        sp{i} = peakTimes;
        spikeAmps{i} = peaks;
        violationInd{i} = find(diff(sp{i})<refPeriodPoints) + 1;
    end

    if length(sp) == 1 % return vector not cell array if only 1 trial
        sp = sp{1};
        spikeAmps = spikeAmps{1};    
        violationInd = violationInd{1};
    end

    results.sp = sp; % spike times (data points)
    results.spikeAmps = spikeAmps;
    results.violationInd = violationInd; % refractory violations in results.sp
end
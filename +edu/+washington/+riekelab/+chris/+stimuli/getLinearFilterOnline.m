function linearFilter = getLinearFilterOnline(stimulus, response, sampleRate, freqCutoff)
    % This function will find the linear filter that changes row vector "signal" into a set of "responses" in rows. 
    % samplerate and freqCutoff (which should be the highest frequency in the signal) should be in Hz.

    % The linear filter is a cc normalized by the power spectrum of the signal.
    % JC 3/31/08
    % MHT 080814

    % For rows as trials.
    filterFft = mean((fft(response,[],2).*conj(fft(stimulus,[],2))),1)./mean(fft(stimulus,[],2).*conj(fft(stimulus,[],2)),1);

    freqcutoffAdjusted = round(freqCutoff/(sampleRate/length(stimulus))); % this adjusts the freq cutoff for the length
    filterFft(:, 1+freqcutoffAdjusted:length(stimulus)-freqcutoffAdjusted) = 0; 

    linearFilter = real(ifft(filterFft));
end
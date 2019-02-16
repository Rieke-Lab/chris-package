function output = SymphonyIsomerizationsConverter( ...
    deviceCalibration, ...
    deviceSpectrum, ...
    photoreceptorSpectrum, ...
    collectingArea, ...
    currentNDFs, ...
    NDFAttenuations, ...
    direction, ... % either 'isomtovolts' or 'voltstoisom'
    input)

% this function will convert isomerizations to volts for a given cell/LED
% pairing with a given set of settings/NDFs (from epochGroup object)
device.wavelengths = deviceSpectrum(:, 1)';
device.values = deviceSpectrum(:, 2)';

photoreceptor.wavelengths = photoreceptorSpectrum(:, 1)';
photoreceptor.values = photoreceptorSpectrum(:, 2)';

% parse through NDFs - get attentuation factor (scale of 0 to 1, with 0
% total attenuation);
ndfAttenuation = DetermineNDFAttenuation(currentNDFs, NDFAttenuations);

% calculate isomerizations per watt for given device/photoreceptor pair
% (before NDFs) - this is isomerizations in the cell per watt of power
% arriving at the cell
isomPerW = calcIsomPerW(device, photoreceptor);

% account for NDFs
isomPerW = isomPerW * ndfAttenuation;

% calibration values are in (nanowatts/volt)/(square micron); collecting area
% should be in units of square microns, so microwatts/volt seen by the given
% photoreceptor should be (calibration value) * (collecting area)
nanoWattsPerVolt = deviceCalibration * collectingArea;
wattsPerVolt = nanoWattsPerVolt * (10^-9);

if strcmpi(direction, 'isomtovolts')
    % get the number of watts that will be necessary to achieve desired
    % isomerization rate
    wattsNeeded = input/isomPerW;
    
    % calculate the voltage necessary
    output = wattsNeeded/wattsPerVolt;
    
elseif strcmpi(direction, 'voltstoisom')
    % figure out watts at this voltage
    output = input * wattsPerVolt * isomPerW;
else
    error('check SymponyIsomerizationsCoverter direction: ''isomtovolts'' or ''voltstoisom''')
end

    % deviceSpectrum - struct with .values, .wavelengths (in m or nm)
    % photoreceptorSpectrum - struct with .values, .wavelengths (in m or nm)
    function isom = calcIsomPerW(deviceSpectrum, photoreceptorSpectrum)
        
        % Planck's constant
        h = 6.62607004e-34; % m^2*kg/s
        % Speed of light
        c = 299792458; % m/s
        
        % For both spectra, if the wavelengths are in nanometers, convert them to
        % meters (this assumes that it will only be in nm or m).
        if (max(photoreceptorSpectrum.wavelengths) > 1)
            photoreceptorSpectrum.wavelengths = photoreceptorSpectrum.wavelengths * (10^-9);
        end
        if (max(deviceSpectrum.wavelengths) > 1)
            deviceSpectrum.wavelengths = deviceSpectrum.wavelengths * (10^-9);
        end

        % The device spectra are often much more finely sampled than the
        % photoreceptor spectra.  Resample the device spectra at only those
        % wavelengths for which there is a probability of absorption.
        deviceSpectrum.values = ...
            interp1(deviceSpectrum.wavelengths, deviceSpectrum.values, photoreceptorSpectrum.wavelengths);
        deviceSpectrum.wavelengths = photoreceptorSpectrum.wavelengths;
        
        % make sure there are not negative values
        deviceSpectrum.values = max(deviceSpectrum.values, 0);
        photoreceptorSpectrum.values = max(photoreceptorSpectrum.values, 0);
        
        % Calculate the change in wavelength for each bin. Assume that the last bin
        % is of size equivalent to the second to last.
        dLs = deviceSpectrum.wavelengths(2:end) - deviceSpectrum.wavelengths(1:end-1);
        dLs(end+1) = dLs(end);
        
        % Calculate the isomerizations per joule of energy from the device (or,
        % equivalently, isomerizations per second per watt from the device).  Do so
        % with:
        % isom = integral(deviceSpectrum*photoreceptorSpectrum*dLs) /
        %        integral(deviceSpectrum*(hc/wavelengths)*dLs)
        isom = ((deviceSpectrum.values .* photoreceptorSpectrum.values) * dLs') / ...
            ((deviceSpectrum.values .* (h*c ./ deviceSpectrum.wavelengths)) * dLs');
        
    end

    function attenuation = DetermineNDFAttenuation( ...
            currentNDFs, ...
            NDFAttenuations)
        if isempty(currentNDFs)
            attenuation = 1;
        else
            attenuation = 0;
            ndfs = strsplit(currentNDFs, ';');
            for i = 1:numel(ndfs)
                attenuation = attenuation + NDFAttenuations(strtrim(ndfs{i}));
            end
            attenuation = 10 ^ (-attenuation);
        end
    end
end

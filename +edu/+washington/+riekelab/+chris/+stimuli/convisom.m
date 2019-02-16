function output = convisom(input, inputUnits, calibration, deviceSpectrum, photoreceptorSpectrum, collectingArea, ndfs, attenuations)
    % Convert isomerizations to intensity (volts or normalized) or vice versa.

    % Calculate attentuation factor (scale of 0 to 1, with 0 total attenuation).
    ndfAttenuation = calcNdfAttenuation(ndfs, attenuations);

    % Calculate isomerizations per watt for given device/photoreceptor pair (before NDFs) - this is isomerizations in 
    % the cell per watt of power arriving at the cell.
    isomPerWatt = calcIsomPerWatt( ...
        struct('wavelengths', deviceSpectrum(:, 1)', 'values', deviceSpectrum(:, 2)'), ...
        struct('wavelengths', photoreceptorSpectrum(:, 1)', 'values', photoreceptorSpectrum(:, 2)'));

    % Account for NDFs.
    isomPerWatt = isomPerWatt * ndfAttenuation;

    % Calibration values are in (nanowatts/intensity)/(square micron) where intensity is volts or normalized; collecting 
    % area should be in units of square microns, so microwatts/intensity seen by the given photoreceptor should be 
    % (calibration value) * (collecting area).
    nanoWattsPerIntensity = calibration * collectingArea;
    wattsPerIntensity = nanoWattsPerIntensity * (10^-9);

    if strcmpi(inputUnits, 'isom')
        % Get the number of watts that will be necessary to achieve desired isomerization rate.
        wattsNeeded = input / isomPerWatt;

        % Calculate the intensity necessary.
        output = wattsNeeded / wattsPerIntensity;
    elseif any(strcmpi(inputUnits, {'volts', 'intensity'}))
        % Figure out watts at this intensity.
        output = input * wattsPerIntensity * isomPerWatt;
    else
        error('Input units must be ''isom'' or ''volts'' or ''intensity''');
    end
end

function isom = calcIsomPerWatt(deviceSpectrum, photoreceptorSpectrum)
    % Planck's constant.
    h = 6.62607004e-34; % m^2*kg/s
    % Speed of light.
    c = 299792458; % m/s

    % For both spectra, if the wavelengths are in nanometers, convert them to meters (this assumes that it will only be 
    % in nm or m).
    if (max(photoreceptorSpectrum.wavelengths) > 1)
        photoreceptorSpectrum.wavelengths = photoreceptorSpectrum.wavelengths * (10^-9);
    end
    if (max(deviceSpectrum.wavelengths) > 1)
        deviceSpectrum.wavelengths = deviceSpectrum.wavelengths * (10^-9);
    end

    % The device spectra are often much more finely sampled than the photoreceptor spectra.  Resample the device spectra 
    % at only those wavelengths for which there is a probability of absorption.
    deviceSpectrum.values = interp1(deviceSpectrum.wavelengths, deviceSpectrum.values, photoreceptorSpectrum.wavelengths);
    deviceSpectrum.wavelengths = photoreceptorSpectrum.wavelengths;

    % Make sure there are not negative values.
    deviceSpectrum.values = max(deviceSpectrum.values, 0);
    photoreceptorSpectrum.values = max(photoreceptorSpectrum.values, 0);

    % Calculate the change in wavelength for each bin. Assume that the last bin is of size equivalent to the second to 
    % last.
    dLs = deviceSpectrum.wavelengths(2:end) - deviceSpectrum.wavelengths(1:end-1);
    dLs(end+1) = dLs(end);

    % Calculate the isomerizations per joule of energy from the device (or, equivalently, isomerizations per second per 
    % watt from the device).  Do so with:
    %   isom = integral(deviceSpectrum*photoreceptorSpectrum*dLs) /
    %          integral(deviceSpectrum*(hc/wavelengths)*dLs)
    isom = ((deviceSpectrum.values .* photoreceptorSpectrum.values) * dLs') / ...
        ((deviceSpectrum.values .* (h*c ./ deviceSpectrum.wavelengths)) * dLs');
end

function a = calcNdfAttenuation(ndfs, attenuations)
    if isempty(ndfs)
        a = 1;
    else
        a = 0;
        for i = 1:numel(ndfs)
            a = a + attenuations(strtrim(ndfs{i}));
        end
        a = 10 ^ (-a);
    end
end
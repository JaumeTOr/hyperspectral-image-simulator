%% Example usage for Hyperspectral Image Simulator
% Creates two example component spectra in the MATLAB base workspace and
% launches the app. The spectra are synthetic examples, not measured data.

channel = 1:160;

exampleSpectra = [ ...
    exp(-0.5 * ((channel - 48) / 9) .^ 2) + ...
    0.45 * exp(-0.5 * ((channel - 96) / 16) .^ 2); ...
    0.80 * exp(-0.5 * ((channel - 72) / 14) .^ 2) + ...
    0.65 * exp(-0.5 * ((channel - 126) / 11) .^ 2)];

exampleSpectrumNames = {'Broad peak', 'Split peak'};

app = HyperspectralImageSimulator();

% In the app, choose Add > From workspace and import
% exampleSpectra with exampleSpectrumNames.

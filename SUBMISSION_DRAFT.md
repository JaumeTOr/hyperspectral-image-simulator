# Lovelace's Square listing draft

## Name

Hyperspectral Image Simulator

## Short description

MATLAB GUI for designing component spectra and spatial concentration maps, then simulating mixture spectra and hyperspectral image cubes.

## Extended description

Hyperspectral Image Simulator is an interactive MATLAB tool for exploring how component spectra combine across a spatial image. Users can create Gaussian-peak or cubic-polynomial spectra, import component spectra from the MATLAB workspace, and paint per-component concentration maps. The app combines component spectra according to the image maps and adds Gaussian noise to generate sampled mixture spectra or a hyperspectral image cube. Use the GUI to inspect pure spectra, mixtures, and concentration patterns, then export the generated arrays and metadata to the MATLAB workspace. The channel axis is an index; the simulator does not calibrate wavelengths or model a specific instrument.

## Suggested technical details

- Category: Visualization tools; Exploratory tools; Teaching and learning resources
- Programming language: MATLAB and HTML/JavaScript
- Version: 0.1.0
- Keywords: MATLAB, chemometrics, hyperspectral imaging, spectral simulation, synthetic data, concentration maps
- License: CC BY-SA 4.0
- Authors: Jaume Torner Ortiz
- Affiliation: Universitat de Barcelona
- Contact email: enter privately in the Square submission form; do not add it to the public repository
- Citation request: Please cite Jaume Torner Ortiz when using the software in an article; see `CITATION.cff`.
- Repository or download: https://github.com/JaumeTOr/hyperspectral-image-simulator

## Included files

- `HyperspectralImageSimulator.m`: MATLAB app and simulation backend
- `HyperspectralImageSimulator.html`: graphical interface
- `example_usage.m`: ready-to-run example
- `CITATION.cff`: machine-readable citation metadata
- `README.md` and `README.txt`: usage and requirements
- `.gitignore`: excludes MATLAB workspace data and editor backups
- `LICENSE`: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)

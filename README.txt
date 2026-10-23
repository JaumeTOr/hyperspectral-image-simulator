HYPERSPECTRAL IMAGE SIMULATOR
============================

Purpose
-------
A MATLAB GUI for editing component spectra, drawing spatial concentration
maps, and simulating mixture spectra and hyperspectral image cubes.

Author: Jaume Torner Ortiz
Affiliation: Universitat de Barcelona

Requirements
------------
MATLAB with uifigure and the uihtml component. No additional MATLAB toolbox
or third-party JavaScript library is required. Keep the .m and .html files in
the same folder.

Start
-----
Set this folder as MATLAB's Current Folder and run:

    app = HyperspectralImageSimulator();

Example
-------
Run example_usage.m, then choose Add > From workspace and import
exampleSpectra and exampleSpectrumNames.

See README.md for details about creating spectra and image maps, saving
sessions, exports, limitations, and workspace persistence.

License
-------
Copyright (c) 2026 Jaume Torner Ortiz.

Released under CC BY-SA 4.0; see LICENSE. Sharing and adaptation, including
commercial use, require attribution and a link to the license. Shared
adaptations must use the same or a compatible CC BY-SA license.

# Hyperspectral Image Simulator (HyperPaint)

Version 0.1.0

Author: Jaume Torner Ortiz  
Affiliation: Universitat de Barcelona

Hyperspectral Image Simulator is a MATLAB graphical tool for building
synthetic hyperspectral images. It includes: customizing component spectra, drawing their spatial concentration maps, and
simulating mixed spectra and hyperspectral image cubes. It is intended for
simulating datasets to test your methodologies.

## Requirements

- MATLAB with `uifigure` and the `uihtml` component.
- No additional MATLAB toolbox or third-party JavaScript library is required.
- The MATLAB and HTML files must remain in the same folder.

## Package contents

- `HyperspectralImageSimulator.m`: MATLAB app and simulation backend.
- `HyperspectralImageSimulator.html`: self-contained graphical interface.
- `example_usage.m`: creates example spectra in the workspace and launches
  the app.
- `CITATION.cff`: machine-readable citation metadata.
- `LICENSE`: MIT License.
- `.gitignore`: excludes MATLAB workspace data and editor backups.
- `SUBMISSION_DRAFT.md`: proposed listing information for Lovelace's Square.

## Launch the app

In MATLAB, set this folder as the Current Folder and run:

```matlab
app = HyperspectralImageSimulator();
```

Keep the returned `app` variable in the workspace while using the GUI.

## Quick example

Run `example_usage.m`. It creates two example spectra and names in the base
workspace, then opens the app. In the GUI, choose **Add**, then **From
workspace**, and select `exampleSpectra` and `exampleSpectrumNames` to import
the examples. The spectra are synthetic demonstrations, not measurements from
an instrument or study.

You can also import your own real numeric vector as one component or a matrix
with one spectrum per row and wavelengths in columns. Optional component names
can be supplied as a cell array, string array, or character array.

## Build spectra

The app includes Gaussian-peak and cubic-polynomial component models. You can
also import a spectrum directly from the MATLAB workspace. Set the number of
spectral bands, preview samples, and noise level in **Global Spectra**. Charts
show individual component spectra, pure spectra, and simulated mixtures.

Imported workspace spectra are used directly. They must have the same number
of channels as other imported workspace spectra in the current session.

## Build a hyperspectral image

Open **Image Editor**, set the row and column counts, select a component, and
paint its concentration map. The canvas supports circular or square brushes,
brush values from 0 to 1, and grids up to 250 by 250 pixels. Component layers
can be transparent, edge-transparent, or painted with randomized pixel
concentrations.

At each pixel, component maps determine how the pure spectra are mixed. A
non-transparent layer hides layers beneath it at that pixel. Transparent
layers allow underlying components to contribute as well. The component
weights are not normalized to sum to one.

## Save and restore a session

**Save Session** stores the full editable state, including spectra and image
maps, in the MATLAB base workspace under a name you choose. Saving under an
existing name updates that entry. **Load Session** lists saved sessions and
compatible metadata variables in the workspace.

The MATLAB base workspace is cleared when MATLAB closes unless it is saved.
To preserve named sessions, run:

```matlab
save('mySessions.mat', 'spectraDesignerSessions')
```

In a later MATLAB session, load the file and choose the desired entry in the
GUI:

```matlab
load('mySessions.mat')
```

## Export data

**Export spectra to workspace** assigns `spectra`, `channelAxis`,
`pureSpectra`, and `metadata`. `spectra` contains sampled mixture spectra;
`metadata` omits the spatial image maps.

**Export cube to workspace** assigns `HSI`, `channelAxis`, `labelMap`,
`concMaps_out`, `concMaps_raw`, `concMaps_opaque`, `pureSpectra`, and
`metadata`. `HSI` is arranged as rows by columns by spectral channels and is
stored as `single`. Cube export metadata includes the full state and maps.

The largest allowed cube (250 rows, 250 columns, and 4096 channels) can
require close to 1 GB for `HSI` alone. Check available memory before exporting
large cubes.

## Method and limitations

For each pixel or sampled spectrum, the app combines the contributing pure
component curves using the image-map weights, component intensity means, and
offsets, then adds Gaussian noise. The channel axis is `1:nBands`; the app
does not calibrate wavelengths, simulate a particular instrument, or model
measurement-specific effects. Preview and cube noise use fixed MATLAB random
seeds. Randomized pixel concentrations use the browser's random generator.

## Citation

If you use this software in an article, please cite:

> Torner Ortiz, J. (2026). *Hyperspectral Image Simulator* (Version 0.1.0) [Computer software]. Universitat de Barcelona.

The accompanying `CITATION.cff` file provides machine-readable author and
software citation metadata.

## License and authorship

This project is released under the MIT License; see `LICENSE`. The MIT License
allows commercial use, modification, and redistribution, provided the license
and copyright notice are retained. Public distribution also requires the
contributor to have rights to share all included code and assets.

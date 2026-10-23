classdef HyperspectralImageSimulator < matlab.apps.AppBase
% HyperspectralImageSimulator
% Interactive tool for creating and exporting synthetic hyperspectral data.
%
% Author: Jaume Torner Ortiz
% Affiliation: Universitat de Barcelona
% Version: 0.1.0
% License: MIT (see LICENSE).
% The app combines editable component spectra with image concentration maps.

    properties (Access = public)
        UIFigure matlab.ui.Figure
        HTMLComponent matlab.ui.control.HTML
    end

    properties (Access = private)
        State struct
        ResponseCounter double = 0
        IsClosed logical = false
    end

    methods (Access = public)
        function app = HyperspectralImageSimulator()
            app.State = app.defaultState();
            app.createComponents();
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startupFcn);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            app.IsClosed = true;
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            screenSize = get(0, 'ScreenSize');
            figWidth = min(1450, round(screenSize(3) * 0.86));
            figHeight = min(920, round(screenSize(4) * 0.88));

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 figWidth figHeight];
            app.UIFigure.Name = 'Hyperspectral Image Simulator';
            app.UIFigure.Color = [0.91 0.92 0.93];
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @closeRequest, true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @figureSizeChanged, true);

            htmlPath = app.resolveHtmlPath();
            app.HTMLComponent = uihtml(app.UIFigure);
            app.HTMLComponent.Position = [1 1 figWidth figHeight];
            app.HTMLComponent.HTMLSource = htmlPath;
            app.HTMLComponent.DataChangedFcn = createCallbackFcn(app, @HTMLDataChanged, true);

            app.UIFigure.Visible = 'on';
        end

        function htmlPath = resolveHtmlPath(~)
            appFolder = fileparts(mfilename('fullpath'));
            candidates = {'HyperspectralImageSimulator.html'};

            for ii = 1:numel(candidates)
                candidatePath = fullfile(appFolder, candidates{ii});
                if isfile(candidatePath)
                    htmlPath = candidatePath;
                    return;
                end
            end

            error('HyperspectralImageSimulator:MissingHtml', ...
                'Cannot find the UI HTML file in %s. Expected one of: %s.', ...
                appFolder, strjoin(candidates, ', '));
        end

        function startupFcn(app)
            movegui(app.UIFigure, 'center');
            app.sendResponse('ready', struct( ...
                'state', app.State, ...
                'preview', app.buildPreview(app.State), ...
                'message', 'Ready'));
        end

        function figureSizeChanged(app, ~)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure), return; end
            pos = app.UIFigure.Position;
            if ~isempty(app.HTMLComponent) && isvalid(app.HTMLComponent)
                app.HTMLComponent.Position = [1 1 pos(3) pos(4)];
            end
        end

        function closeRequest(app, ~)
            app.IsClosed = true;
            delete(app);
        end

        function HTMLDataChanged(app, ~)
            try
                data = app.HTMLComponent.Data;
                if ~isstruct(data) || ~isfield(data, 'action'), return; end
                if isfield(data, 'source') && strcmp(char(string(data.source)), 'matlab'), return; end

                action = char(string(data.action));
                payload = struct();
                if isfield(data, 'payloadJson') && ~isempty(data.payloadJson)
                    payload = jsondecode(char(string(data.payloadJson)));
                end

                switch action
                    case 'uiReady'
                        app.sendResponse('state', struct( ...
                            'state', app.State, ...
                            'preview', app.buildPreview(app.State), ...
                            'message', 'Interface ready'));
                    case 'updateState'
                        app.State = app.normalizeState(payload);
                        app.sendResponse('preview', struct( ...
                            'preview', app.buildPreview(app.State), ...
                            'message', 'Preview updated'));
                    case 'exportSpectra'
                        app.State = app.normalizeState(payload);
                        app.exportSpectra();
                    case 'exportCube'
                        app.State = app.normalizeState(payload);
                        app.exportCube();
                    case 'saveSession'
                        app.State = app.normalizeState(payload.state);
                        app.saveSession(payload.name);
                    case 'listSessions'
                        response = struct();
                        response.sessions = app.workspaceSessions();
                        app.sendResponse('workspaceSessions', response);
                    case 'loadSession'
                        app.loadSession(payload.source, payload.name);
                    case 'importWorkspaceSpectra'
                        app.State = app.normalizeState(payload.state);
                        app.importWorkspaceSpectra(payload.sourceName, payload.namesVariableName);
                    case 'listWorkspaceVariables'
                        app.State = app.normalizeState(payload.state);
                        app.sendResponse('workspaceVariables', app.workspaceVariableLists());
                    otherwise
                        app.sendResponse('error', struct('message', ['Unknown action: ' action]));
                end
            catch ME
                app.sendResponse('error', struct('message', ME.message));
            end
        end

        function sendResponse(app, responseType, payload)
            if app.IsClosed || isempty(app.HTMLComponent) || ~isvalid(app.HTMLComponent), return; end
            out = struct();
            out.source = 'matlab';
            out.response = responseType;
            app.ResponseCounter = app.ResponseCounter + 1;
            out.timestamp = app.ResponseCounter;
            out.payloadJson = jsonencode(payload);
            app.HTMLComponent.Data = out;
        end
    end

    methods (Access = private)
        function state = defaultState(app)
            comps = repmat(app.defaultComponent(1), 1, 3);
            comps(1) = app.defaultComponent(1);
            comps(2) = app.defaultComponent(2);
            comps(3) = app.defaultComponent(3);

            state = struct();
            state.nBands = 160;
            state.noiseLevel = 0.004;
            state.nPreviewSpectra = 80;
            state.activeComponent = 1;
            state.components = comps;
            state.rows = 64;
            state.cols = 64;
            state.brushSize = 6;
            state.brushValue = 1.0;
            state.brushShape = 'circle';
            state.maps = app.defaultMaps(64, 64, numel(comps));
            state.opaqueMaps = app.defaultOpaqueMaps(64, 64, numel(comps));
        end

        function c = defaultComponent(app, k)
            colors = app.componentPalette(max(12, k));
            rng(100 + k);
            p1 = 950 + 80*k + 35*randn();
            p2 = 1200 + 70*k + 45*randn();
            c = struct();
            c.id = k;
            c.name = sprintf('Component %d', k);
            c.color = colors(k,:);
            c.type = 'gaussian';
            c.spectrum = [];
            c.peaks = [ ...
                struct('position', min(160, max(1, p1 / 10)), 'width', 8 + 8*rand(), 'abundance', 0.7 + 0.4*rand()), ...
                struct('position', min(160, max(1, p2 / 10)), 'width', 10 + 10*rand(), 'abundance', 0.45 + 0.35*rand())];
            c.polyCoeffs = [-0.35, 0.15, 0.75, 0.15];
            c.intensityMean = 1.0;
            c.offset = 0.02;
            c.zeroStart = NaN;
            c.zeroEnd = NaN;
            c.transparent = false;
            c.edgeTransparent = false;
            c.edgeGirth = 2;
            c.randomizePixels = false;
            c.hiddenVisual = false;
        end

        function maps = defaultMaps(~, rows, cols, nComp)
            maps = cell(1, nComp);
            if nComp == 0
                return;
            end
            base = zeros(rows, cols);
            base(:) = 1;
            maps{1} = base(:)';
            for k = 2:nComp
                maps{k} = zeros(1, rows * cols);
            end
        end

        function opaqueMaps = defaultOpaqueMaps(~, rows, cols, nComp)
            opaqueMaps = cell(1, nComp);
            for k = 1:nComp
                opaqueMaps{k} = ones(1, rows * cols);
            end
        end

        function state = normalizeState(app, state)
            if ~isfield(state, 'nBands'), state.nBands = 160; end
            if ~isfield(state, 'noiseLevel'), state.noiseLevel = 0.004; end
            if ~isfield(state, 'nPreviewSpectra'), state.nPreviewSpectra = 80; end
            if ~isfield(state, 'rows'), state.rows = 64; end
            if ~isfield(state, 'cols'), state.cols = 64; end
            if ~isfield(state, 'brushSize')
                if isfield(state, 'brushRadius')
                    state.brushSize = state.brushRadius;
                else
                    state.brushSize = 6;
                end
            end
            if isfield(state, 'brushRadius'), state = rmfield(state, 'brushRadius'); end
            if ~isfield(state, 'brushValue'), state.brushValue = 1; end
            if ~isfield(state, 'brushShape'), state.brushShape = 'circle'; end
            if ~isfield(state, 'components')
                state.components = app.defaultComponent(1);
            elseif isempty(state.components)
                componentTemplate = app.defaultComponent(1);
                state.components = componentTemplate([]);
            end

            state.nBands = max(8, min(4096, round(double(state.nBands))));
            state.rows = max(2, min(250, round(double(state.rows))));
            state.cols = max(2, min(250, round(double(state.cols))));
            state.brushSize = max(1, min(50, round(double(state.brushSize))));
            state.nPreviewSpectra = max(1, min(500, round(double(state.nPreviewSpectra))));
            state.noiseLevel = max(0, double(state.noiseLevel));
            nComp = numel(state.components);
            if ~isfield(state, 'activeComponent')
                state.activeComponent = 1;
            end
            if nComp == 0
                state.activeComponent = 0;
            else
                state.activeComponent = max(1, min(nComp, round(double(state.activeComponent))));
            end

            for kk = 1:nComp
                isWorkspaceSpectrum = isfield(state.components(kk), 'type') && ...
                    strcmpi(char(string(state.components(kk).type)), 'workspace');
                if (~isfield(state.components(kk), 'polyCoeffs') || isempty(state.components(kk).polyCoeffs)) && ...
                        ~isWorkspaceSpectrum
                    state.components(kk).polyCoeffs = [-0.35, 0.15, 0.75, 0.15];
                end
                if ~isfield(state.components(kk), 'spectrum')
                    state.components(kk).spectrum = [];
                end
                if ~isfield(state.components(kk), 'intensityMean') || isempty(state.components(kk).intensityMean)
                    state.components(kk).intensityMean = 1;
                end
                if ~isfield(state.components(kk), 'hiddenVisual') || isempty(state.components(kk).hiddenVisual)
                    state.components(kk).hiddenVisual = false;
                end
            end
            if ~isfield(state, 'maps') || isempty(state.maps)
                state.maps = app.defaultMaps(state.rows, state.cols, nComp);
            end
            state.maps = app.normalizeMaps(state.maps, state.rows, state.cols, nComp);
            if ~isfield(state, 'opaqueMaps') || isempty(state.opaqueMaps)
                state.opaqueMaps = app.defaultOpaqueMaps(state.rows, state.cols, nComp);
            end
            state.opaqueMaps = app.normalizeOpaqueMaps(state.opaqueMaps, state.rows, state.cols, nComp);

        end

        function maps = normalizeMaps(~, mapsIn, rows, cols, nComp)
            maps = cell(1, nComp);
            if iscell(mapsIn)
                src = mapsIn;
            elseif isnumeric(mapsIn) && ismatrix(mapsIn) && size(mapsIn, 1) == nComp
                src = cell(1, nComp);
                for kk = 1:nComp
                    src{kk} = mapsIn(kk,:);
                end
            elseif isnumeric(mapsIn) && ismatrix(mapsIn) && size(mapsIn, 2) == nComp
                src = cell(1, nComp);
                for kk = 1:nComp
                    src{kk} = mapsIn(:,kk);
                end
            else
                src = num2cell(mapsIn);
            end
            targetN = rows * cols;
            for k = 1:nComp
                if k <= numel(src)
                    v = double(src{k});
                    v = v(:)';
                else
                    v = zeros(1, targetN);
                end
                out = zeros(1, targetN);
                n = min(numel(v), targetN);
                if n > 0, out(1:n) = v(1:n); end
                out(out < 0) = 0;
                out(out > 1) = 1;
                maps{k} = out;
            end
        end

        function preview = buildPreview(app, state)
            state = app.normalizeState(state);
            lambda = 1:state.nBands;
            nComp = numel(state.components);
            pureS = zeros(nComp, state.nBands);
            for k = 1:nComp
                pureS(k,:) = app.buildPureSpectrum(lambda, state.components(k));
            end

            rng(1);
            normConc = app.effectiveConcentrations(state);
            nSamp = min(state.nPreviewSpectra, state.rows * state.cols);
            pixIdx = randperm(state.rows * state.cols, nSamp);
            rawSpectra = zeros(nSamp, state.nBands);
            dom = zeros(1, nSamp);
            for i = 1:nSamp
                idx = pixIdx(i);
                spec = zeros(1, state.nBands);
                for k = 1:nComp
                    comp = state.components(k);
                    intensity = max(0.05, app.scalarValue(comp.intensityMean, 1));
                    spec = spec + normConc(idx,k) * (intensity * pureS(k,:) + app.scalarValue(comp.offset, 0));
                end
                rawSpectra(i,:) = spec + state.noiseLevel * randn(1, state.nBands);
                if nComp > 0
                    [~, dom(i)] = max(normConc(idx,:));
                end
            end

            if nComp > 0
                [purity, labelMap] = max(normConc, [], 2);
            else
                purity = zeros(state.rows * state.cols, 1);
                labelMap = zeros(state.rows * state.cols, 1);
            end
            preview = struct();
            preview.lambda = lambda;
            preview.channelAxis = lambda;
            preview.pureSpectra = pureS;
            preview.rawSpectra = rawSpectra;
            preview.rawDominant = dom;
            preview.purity = purity(:)';
            preview.labelMap = labelMap(:)';
        end

        function sp = buildPureSpectrum(app, lambda, comp)
            componentType = '';
            if isfield(comp, 'type')
                componentType = char(string(comp.type));
            end
            if strcmpi(componentType, 'workspace')
                sp = double(comp.spectrum(:)');
                if numel(sp) ~= numel(lambda)
                    error('HyperspectralImageSimulator:WorkspaceSpectrumSize', ...
                        'Imported component spectra must have the same number of channels as the app.');
                end
                return;
            elseif strcmpi(componentType, 'polynomial')
                x = linspace(-1, 1, numel(lambda));
                coeffs = double(comp.polyCoeffs);
                if isempty(coeffs), coeffs = [0 0 0 0]; end
                sp = polyval(coeffs(:)', x);
                sp = sp - min(sp);
            else
                sp = zeros(1, numel(lambda));
                peaks = comp.peaks;
                for p = 1:numel(peaks)
                    pos = app.scalarValue(peaks(p).position, mean(lambda));
                    wid = max(1, app.scalarValue(peaks(p).width, 40));
                    amp = app.scalarValue(peaks(p).abundance, 1);
                    sp = sp + amp .* exp(-0.5 .* ((lambda - pos) ./ wid).^2);
                end
            end
            mx = max(sp);
            if mx > 0, sp = sp ./ mx; end
            zeroStart = NaN;
            zeroEnd = NaN;
            if isfield(comp, 'zeroStart')
                zeroStart = app.scalarValue(comp.zeroStart, NaN);
            end
            if isfield(comp, 'zeroEnd')
                zeroEnd = app.scalarValue(comp.zeroEnd, NaN);
            end
            if isfinite(zeroStart) && isfinite(zeroEnd)
                z1 = min(zeroStart, zeroEnd);
                z2 = max(zeroStart, zeroEnd);
                sp(lambda >= z1 & lambda <= z2) = 0;
            end
            sp(sp < 0) = 0;
        end

        function normConc = effectiveConcentrations(app, state)
            nComp = numel(state.components);
            maps = app.normalizeMaps(state.maps, state.rows, state.cols, nComp);
            opaqueMaps = app.normalizeOpaqueMaps(state.opaqueMaps, state.rows, state.cols, nComp);
            normConc = app.composeLayerMaps(maps, opaqueMaps, state.rows * state.cols, nComp);
        end

        function normConc = composeLayerMaps(~, maps, opaqueMaps, nPix, nComp)
            normConc = zeros(nPix, nComp);
            for idx = 1:nPix
                for kk = nComp:-1:1
                    wt = maps{kk}(idx);
                    if wt <= 0
                        continue;
                    end
                    if opaqueMaps{kk}(idx) > 0
                        normConc(idx,kk) = wt;
                        break;
                    else
                        normConc(idx,kk) = wt;
                    end
                end
            end
        end

        function maps = normalizeOpaqueMaps(~, mapsIn, rows, cols, nComp)
            maps = cell(1, nComp);
            if iscell(mapsIn)
                src = mapsIn;
            elseif isnumeric(mapsIn) && ismatrix(mapsIn) && size(mapsIn, 1) == nComp
                src = cell(1, nComp);
                for kk = 1:nComp
                    src{kk} = mapsIn(kk,:);
                end
            elseif isnumeric(mapsIn) && ismatrix(mapsIn) && size(mapsIn, 2) == nComp
                src = cell(1, nComp);
                for kk = 1:nComp
                    src{kk} = mapsIn(:,kk);
                end
            else
                src = num2cell(mapsIn);
            end
            targetN = rows * cols;
            for k = 1:nComp
                out = ones(1, targetN);
                if k <= numel(src)
                    v = double(src{k});
                    v = v(:)';
                    n = min(numel(v), targetN);
                    if n > 0
                        out(1:n) = double(v(1:n) > 0);
                    end
                end
                maps{k} = out;
            end
        end

        function lists = workspaceVariableLists(~)
            variables = evalin('base', 'whos');
            numericClasses = {'double','single','int8','uint8','int16','uint16', ...
                'int32','uint32','int64','uint64'};
            isNumeric = arrayfun(@(v) any(strcmp(v.class, numericClasses)) && ...
                numel(v.size) <= 2 && all(v.size > 0), variables);
            spectrumVariables = variables(isNumeric);
            textClasses = {'cell','string','char'};
            nameVariables = variables(arrayfun(@(v) any(strcmp(v.class, textClasses)), variables));

            spectraOptions = repmat(struct('name', '', 'label', ''), 1, numel(spectrumVariables));
            for ii = 1:numel(spectrumVariables)
                spectraOptions(ii).name = spectrumVariables(ii).name;
                spectraOptions(ii).label = sprintf('%s (%s, %s)', spectrumVariables(ii).name, ...
                    spectrumVariables(ii).class, mat2str(spectrumVariables(ii).size));
            end
            nameOptions = repmat(struct('name', '', 'label', ''), 1, numel(nameVariables));
            for ii = 1:numel(nameVariables)
                nameOptions(ii).name = nameVariables(ii).name;
                nameOptions(ii).label = sprintf('%s (%s, %s)', nameVariables(ii).name, ...
                    nameVariables(ii).class, mat2str(nameVariables(ii).size));
            end
            lists = struct('spectraVariables', spectraOptions, 'nameVariables', nameOptions);
        end

        function importWorkspaceSpectra(app, sourceName, namesVariableName)
            if isstring(sourceName) && isscalar(sourceName), sourceName = char(sourceName); end
            if ~ischar(sourceName) || ~isrow(sourceName) || isempty(sourceName)
                error('HyperspectralImageSimulator:InvalidSpectrumVariable', ...
                    'Select a spectrum variable from the workspace list.');
            end
            if nargin < 3 || isempty(namesVariableName)
                namesVariableName = '';
            elseif isstring(namesVariableName) && isscalar(namesVariableName)
                namesVariableName = char(namesVariableName);
            end
            if ~isempty(namesVariableName) && ...
                    (~ischar(namesVariableName) || ~isrow(namesVariableName))
                error('HyperspectralImageSimulator:InvalidSpectrumNames', ...
                    'Select a names variable from the workspace list.');
            end

            variables = evalin('base', 'whos');
            variableIndex = find(strcmp({variables.name}, sourceName), 1);
            numericClasses = {'double','single','int8','uint8','int16','uint16', ...
                'int32','uint32','int64','uint64'};
            if isempty(variableIndex) || ~any(strcmp(variables(variableIndex).class, numericClasses))
                error('HyperspectralImageSimulator:InvalidSpectrumVariable', ...
                    'The selected numeric spectrum variable is no longer available.');
            end
            imported = evalin('base', sourceName);
            if ~isnumeric(imported) || ~isreal(imported) || ~ismatrix(imported) || ...
                    isempty(imported) || any(~isfinite(double(imported(:))))
                app.sendResponse('error', struct('message', ...
                    'Select a nonempty, real numeric vector or matrix containing only finite values.'));
                return;
            end
            imported = double(imported);
            singleSpectrum = isvector(imported);
            if singleSpectrum
                imported = reshape(imported, 1, []);
            end

            nChannels = size(imported, 2);
            if nChannels < 8 || nChannels > 4096
                app.sendResponse('error', struct('message', ...
                    'Imported spectra must contain between 8 and 4096 wavelength columns.'));
                return;
            end

            hasWorkspaceSpectra = arrayfun(@(c) strcmpi(char(string(c.type)), 'workspace'), ...
                app.State.components);
            if any(hasWorkspaceSpectra) && app.State.nBands ~= nChannels
                app.sendResponse('error', struct('message', sprintf( ...
                    'Imported spectra must match the %d channels already used by workspace components.', ...
                    app.State.nBands)));
                return;
            end
            firstNewComponent = numel(app.State.components) + 1;
            nImported = size(imported, 1);
            componentNames = cell(nImported, 1);
            if ~isempty(namesVariableName)
                nameIndex = find(strcmp({variables.name}, namesVariableName), 1);
                textClasses = {'cell','string','char'};
                if isempty(nameIndex) || ~any(strcmp(variables(nameIndex).class, textClasses))
                    error('HyperspectralImageSimulator:InvalidSpectrumNames', ...
                        'The selected component names variable is no longer available.');
                end
                componentNames = app.normalizeComponentNames( ...
                    evalin('base', namesVariableName), nImported);
            end

            if ~any(hasWorkspaceSpectra)
                app.State.nBands = nChannels;
            end
            colors = app.componentPalette(firstNewComponent + nImported - 1);
            for ii = 1:nImported
                componentIndex = firstNewComponent + ii - 1;
                component = app.defaultComponent(componentIndex);
                component.id = componentIndex;
                if ~isempty(componentNames{ii})
                    component.name = componentNames{ii};
                elseif nImported == 1 && singleSpectrum
                    component.name = sourceName;
                else
                    component.name = sprintf('%s row %d', sourceName, ii);
                end
                component.color = colors(componentIndex, :);
                component.type = 'workspace';
                component.spectrum = imported(ii, :);
                component.peaks = struct('position', {}, 'width', {}, 'abundance', {});
                component.polyCoeffs = [];
                component.intensityMean = 1;
                component.offset = 0;
                component.zeroStart = NaN;
                component.zeroEnd = NaN;
                app.State.components(end + 1) = component;
                app.State.maps{end + 1} = zeros(1, app.State.rows * app.State.cols);
                app.State.opaqueMaps{end + 1} = ones(1, app.State.rows * app.State.cols);
            end

            app.State.activeComponent = firstNewComponent;
            app.State = app.normalizeState(app.State);
            app.sendResponse('state', struct( ...
                'state', app.State, ...
                'preview', app.buildPreview(app.State), ...
                'message', sprintf('Imported %d component spectrum(s) from %s.', nImported, sourceName)));
        end

        function componentNames = normalizeComponentNames(~, rawNames, expectedCount)
            if iscell(rawNames)
                componentNames = rawNames(:);
                for ii = 1:numel(componentNames)
                    value = componentNames{ii};
                    if isstring(value) && isscalar(value)
                        if ismissing(value)
                            error('HyperspectralImageSimulator:InvalidSpectrumNames', ...
                                'The names variable cannot contain missing or empty names.');
                        end
                        value = char(value);
                    elseif ~ischar(value) || (~isrow(value) && ~isempty(value))
                        error('HyperspectralImageSimulator:InvalidSpectrumNames', ...
                            'Cell name variables must contain character vectors or string scalars.');
                    end
                    componentNames{ii} = strtrim(value);
                end
            elseif isstring(rawNames)
                if any(ismissing(rawNames(:)))
                    error('HyperspectralImageSimulator:InvalidSpectrumNames', ...
                        'The names variable cannot contain missing or empty names.');
                end
                componentNames = cellstr(rawNames(:));
            elseif ischar(rawNames)
                if expectedCount > 1 && size(rawNames, 1) == expectedCount
                    componentNames = cellstr(rawNames);
                elseif isvector(rawNames)
                    componentNames = {rawNames(:)'};
                else
                    componentNames = cellstr(rawNames);
                end
            else
                error('HyperspectralImageSimulator:InvalidSpectrumNames', ...
                    'Names must be stored in a cell array, string array, or character array.');
            end

            if numel(componentNames) ~= expectedCount
                error('HyperspectralImageSimulator:InvalidSpectrumNames', ...
                    'The names variable must contain exactly %d name(s), one for each imported spectrum.', ...
                    expectedCount);
            end
            for ii = 1:numel(componentNames)
                componentNames{ii} = strtrim(componentNames{ii});
                if isempty(componentNames{ii})
                    error('HyperspectralImageSimulator:InvalidSpectrumNames', ...
                        'The names variable cannot contain missing or empty names.');
                end
            end
        end

        function exportSpectra(app)
            state = app.normalizeState(app.State);
            preview = app.buildPreview(state);
            spectra = preview.rawSpectra;
            channelAxis = preview.channelAxis;
            pureSpectra = preview.pureSpectra;
            metadata = state;
            metadata = rmfield(metadata, {'maps', 'opaqueMaps'});

            assignin('base', 'spectra', spectra);
            assignin('base', 'channelAxis', channelAxis);
            assignin('base', 'pureSpectra', pureSpectra);
            assignin('base', 'metadata', metadata);
            app.sendResponse('status', struct('message', ...
                'Exported spectra, channelAxis, pureSpectra, and metadata to the MATLAB workspace.'));
        end

        function exportCube(app)
            state = app.normalizeState(app.State);
            channelAxis = 1:state.nBands;
            nComp = numel(state.components);
            pureSpectra = zeros(nComp, state.nBands);
            for k = 1:nComp
                pureSpectra(k,:) = app.buildPureSpectrum(channelAxis, state.components(k));
            end
            normConc = app.effectiveConcentrations(state);
            rng(42);
            HSI = zeros(state.rows, state.cols, state.nBands, 'single');
            for idx = 1:(state.rows * state.cols)
                spec = zeros(1, state.nBands);
                for k = 1:nComp
                    comp = state.components(k);
                    intensity = max(0.05, app.scalarValue(comp.intensityMean, 1));
                    spec = spec + normConc(idx,k) * (intensity * pureSpectra(k,:) + app.scalarValue(comp.offset, 0));
                end
                [r,c] = ind2sub([state.rows state.cols], idx);
                HSI(r,c,:) = single(spec + state.noiseLevel * randn(1, state.nBands));
            end
            if nComp > 0
                [~, labelFlat] = max(normConc, [], 2);
                labelMap = reshape(labelFlat, [state.rows state.cols]);
                concMaps_out = reshape(normConc, [state.rows state.cols nComp]);
                concMaps_raw = zeros(state.rows, state.cols, nComp);
                concMaps_opaque = zeros(state.rows, state.cols, nComp);
                for k = 1:nComp
                    concMaps_raw(:,:,k) = reshape(state.maps{k}, [state.rows state.cols]);
                    concMaps_opaque(:,:,k) = reshape(state.opaqueMaps{k}, [state.rows state.cols]);
                end
            else
                labelMap = zeros(state.rows, state.cols);
                concMaps_out = zeros(state.rows, state.cols, 0);
                concMaps_raw = zeros(state.rows, state.cols, 0);
                concMaps_opaque = zeros(state.rows, state.cols, 0);
            end
            metadata = state;

            assignin('base', 'HSI', HSI);
            assignin('base', 'channelAxis', channelAxis);
            assignin('base', 'labelMap', labelMap);
            assignin('base', 'concMaps_out', concMaps_out);
            assignin('base', 'concMaps_raw', concMaps_raw);
            assignin('base', 'concMaps_opaque', concMaps_opaque);
            assignin('base', 'pureSpectra', pureSpectra);
            assignin('base', 'metadata', metadata);
            app.sendResponse('status', struct('message', ...
                'Exported HSI, maps, spectra, channelAxis, and metadata to the MATLAB workspace.'));
        end

        function saveSession(app, sessionName)
            sessionName = strtrim(char(string(sessionName)));
            if isempty(sessionName)
                error('HyperspectralImageSimulator:InvalidSessionName', ...
                    'Enter a name for this session.');
            end
            if numel(sessionName) > 80
                error('HyperspectralImageSimulator:InvalidSessionName', ...
                    'Session names must be 80 characters or fewer.');
            end

            state = app.normalizeState(app.State);
            sessions = app.readSessionRegistry();
            record = struct('name', sessionName, 'formatVersion', 1, 'state', state);
            wasUpdated = false;
            if isempty(sessions)
                sessions = record;
            else
                match = find(strcmpi({sessions.name}, sessionName), 1);
                if isempty(match)
                    sessions(end + 1) = record;
                else
                    sessions(match) = record;
                    wasUpdated = true;
                end
            end
            assignin('base', 'spectraDesignerSessions', sessions);
            if wasUpdated
                saveVerb = 'Updated';
            else
                saveVerb = 'Saved';
            end
            app.sendResponse('status', struct('message', ...
                sprintf('%s session "%s" in spectraDesignerSessions in the MATLAB workspace.', ...
                saveVerb, ...
                sessionName)));
        end

        function sessions = workspaceSessions(app)
            records = app.readSessionRegistry();
            sessions = repmat(struct('name', '', 'source', ''), 1, 0);
            for ii = 1:numel(records)
                sessions(end + 1) = struct( ...
                    'name', records(ii).name, 'source', 'named'); %#ok<AGROW>
            end
            if evalin('base', 'exist(''sessionMetadata'', ''var'')')
                legacySession = evalin('base', 'sessionMetadata');
                if app.isSessionMetadata(legacySession)
                    sessions(end + 1) = struct( ...
                        'name', 'Legacy sessionMetadata', 'source', 'sessionMetadata');
                end
            end
            if evalin('base', 'exist(''metadata'', ''var'')')
                exportMetadata = evalin('base', 'metadata');
                if app.isSessionMetadata(exportMetadata)
                    sessions(end + 1) = struct( ...
                        'name', 'Export metadata (metadata)', 'source', 'metadata');
                end
            end
        end

        function tf = isSessionMetadata(~, value)
            tf = false;
            if ~isstruct(value) || ~isscalar(value)
                return;
            end
            if isfield(value, 'state')
                value = value.state;
            end
            tf = isstruct(value) && isscalar(value) && isfield(value, 'components');
        end

        function sessions = readSessionRegistry(~)
            if evalin('base', 'exist(''spectraDesignerSessions'', ''var'')')
                sessions = evalin('base', 'spectraDesignerSessions');
                requiredFields = {'name', 'formatVersion', 'state'};
                if ~isstruct(sessions) || ...
                        ~all(cellfun(@(field) isfield(sessions, field), requiredFields))
                    error('HyperspectralImageSimulator:InvalidSessionRegistry', ...
                        'The workspace variable spectraDesignerSessions has an invalid format.');
                end
            else
                sessions = struct('name', {}, 'formatVersion', {}, 'state', {});
            end
        end

        function loadSession(app, source, sessionName)
            source = char(string(source));
            switch source
                case 'named'
                    sessions = app.readSessionRegistry();
                    match = find(strcmpi({sessions.name}, char(string(sessionName))), 1);
                    if isempty(match)
                        error('HyperspectralImageSimulator:MissingSession', ...
                            'The selected session is no longer available in the workspace.');
                    end
                    savedSession = sessions(match);
                    savedState = savedSession.state;
                    sourceName = sprintf('session "%s"', savedSession.name);
                    if savedSession.formatVersion > 1
                        error('HyperspectralImageSimulator:UnsupportedSessionVersion', ...
                            'This session was saved with a newer Hyperspectral Image Simulator format.');
                    end
                case 'sessionMetadata'
                    if ~evalin('base', 'exist(''sessionMetadata'', ''var'')')
                        error('HyperspectralImageSimulator:MissingSession', ...
                            'The workspace variable sessionMetadata is no longer available.');
                    end
                    savedSession = evalin('base', 'sessionMetadata');
                    sourceName = 'sessionMetadata';
                    if isstruct(savedSession) && isscalar(savedSession) && isfield(savedSession, 'state')
                        if isfield(savedSession, 'formatVersion') && savedSession.formatVersion > 1
                            error('HyperspectralImageSimulator:UnsupportedSessionVersion', ...
                                'This session was saved with a newer Hyperspectral Image Simulator format.');
                        end
                        savedState = savedSession.state;
                    else
                        savedState = savedSession;
                    end
                case 'metadata'
                    if ~evalin('base', 'exist(''metadata'', ''var'')')
                        error('HyperspectralImageSimulator:MissingSession', ...
                            'The workspace variable metadata is no longer available.');
                    end
                    savedState = evalin('base', 'metadata');
                    sourceName = 'metadata';
                otherwise
                    error('HyperspectralImageSimulator:InvalidSessionSource', ...
                        'Choose a session from the workspace list.');
            end

            if ~isstruct(savedState) || ~isscalar(savedState) || ~isfield(savedState, 'components')
                error('HyperspectralImageSimulator:InvalidSession', ...
                    'The selected workspace item (%s) does not contain valid Hyperspectral Image Simulator session data.', ...
                    sourceName);
            end

            nextState = app.normalizeState(savedState);
            nextPreview = app.buildPreview(nextState);
            app.State = nextState;
            app.sendResponse('state', struct( ...
                'state', nextState, ...
                'preview', nextPreview, ...
                'message', sprintf('Loaded the session from workspace variable %s.', sourceName)));
        end

        function colors = componentPalette(~, n)
            base = [ ...
                0.0000 0.0000 1.0000; ...
                1.0000 0.0000 0.0000; ...
                0.0000 1.0000 0.0000; ...
                0.9608 0.6196 0.0392; ...
                0.5412 0.3608 0.9647; ...
                0.9255 0.2824 0.6000];
            if n <= size(base,1)
                colors = base(1:n,:);
            else
                colors = hsv(n);
                colors(1:size(base,1),:) = base;
                colors = 0.85 * colors + 0.15;
            end
        end

        function value = scalarValue(~, raw, defaultValue)
            value = defaultValue;
            if nargin < 3
                defaultValue = NaN;
                value = defaultValue;
            end
            if isempty(raw)
                return;
            end
            if ischar(raw) || isstring(raw)
                parsed = str2double(raw);
                if isfinite(parsed)
                    value = parsed;
                end
                return;
            end
            if isnumeric(raw) || islogical(raw)
                raw = double(raw);
                raw = raw(:);
                raw = raw(isfinite(raw));
                if ~isempty(raw)
                    value = raw(1);
                end
            end
        end
    end
end

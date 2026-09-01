classdef BrainViewerModule < handle
    properties (Access = private)
        Figure
        ChatGPT
        Controls
        Data
        Viewer
    end
    
    methods
        function obj = BrainViewerModule(chatGPT)
            obj.ChatGPT = chatGPT;
        end
        
        function show(obj)
            obj.Figure = uifigure('Name', 'Brain Viewer', ...
                'Position', [150 150 1200 800]);
            
            obj.createLayout();
        end
    end
    
    methods (Access = private)
        function createLayout(obj)
            % Create main grid layout
            grid = uigridlayout(obj.Figure, [1 2]);
            grid.ColumnWidth = {'4x', '1x'};
            
            % Create viewer panel
            obj.createViewerPanel(grid);
            
            % Create control panel
            obj.createControlPanel(grid);
        end
        
        function createViewerPanel(obj, grid)
            viewerPanel = uipanel(grid);
            
            % Create 3D viewer axes
            obj.Viewer.Axes = uiaxes(viewerPanel, ...
                'Position', [10 10 800 780]);
            
            % Initialize empty plot
            hold(obj.Viewer.Axes, 'on');
            axis(obj.Viewer.Axes, 'equal');
            grid(obj.Viewer.Axes, 'on');
            view(obj.Viewer.Axes, 3);
        end
        
        function createControlPanel(obj, grid)
            controlPanel = uipanel(grid);
            controlPanel.Title = 'Controls';
            
            % Create data loading controls
            obj.createDataControls(controlPanel);
            
            % Create view controls
            obj.createViewControls(controlPanel);
            
            % Create visualization controls
            obj.createVisualizationControls(controlPanel);
            
            % Create ChatGPT panel
            obj.createChatGPTPanel(controlPanel);
        end
        
        function createDataControls(obj, panel)
            dataPanel = uipanel(panel, ...
                'Position', [10 600 280 150], ...
                'Title', 'Data');
            
            % File selection
            obj.Controls.DataPath = uieditfield(dataPanel, ...
                'Position', [10 90 200 22], ...
                'Value', '', ...
                'Editable', 'off');
            
            uibutton(dataPanel, 'Text', 'Load', ...
                'Position', [220 90 50 22], ...
                'ButtonPushedFcn', @(btn,event) obj.loadData());
            
            % Overlay selection
            obj.Controls.OverlayPath = uieditfield(dataPanel, ...
                'Position', [10 50 200 22], ...
                'Value', '', ...
                'Editable', 'off');
            
            uibutton(dataPanel, 'Text', 'Overlay', ...
                'Position', [220 50 50 22], ...
                'ButtonPushedFcn', @(btn,event) obj.loadOverlay());
        end
        
        function createViewControls(obj, panel)
            viewPanel = uipanel(panel, ...
                'Position', [10 400 280 190], ...
                'Title', 'View Controls');
            
            % View buttons
            views = {'Sagittal', 'Coronal', 'Axial', '3D'};
            for i = 1:length(views)
                uibutton(viewPanel, 'Text', views{i}, ...
                    'Position', [10+70*(i-1) 130 60 30], ...
                    'ButtonPushedFcn', @(btn,event) obj.changeView(views{i}));
            end
            
            % Slice controls
            uilabel(viewPanel, 'Text', 'Slice:', ...
                'Position', [10 90 40 22]);
            
            obj.Controls.SliceSlider = uislider(viewPanel, ...
                'Position', [60 100 200 3], ...
                'Limits', [1 100], ...
                'Value', 50, ...
                'ValueChangingFcn', @(slider,event) obj.updateSlice(event.Value));
        end
        
        function createVisualizationControls(obj, panel)
            visPanel = uipanel(panel, ...
                'Position', [10 200 280 190], ...
                'Title', 'Visualization');
            
            % Colormap selection
            uilabel(visPanel, 'Text', 'Colormap:', ...
                'Position', [10 130 60 22]);
            
            obj.Controls.Colormap = uidropdown(visPanel, ...
                'Position', [80 130 180 22], ...
                'Items', {'gray', 'jet', 'hot', 'cool'}, ...
                'ValueChangedFcn', @(dd,event) obj.updateColormap(event.Value));
            
            % Transparency
            uilabel(visPanel, 'Text', 'Transparency:', ...
                'Position', [10 90 80 22]);
            
            obj.Controls.Transparency = uislider(visPanel, ...
                'Position', [100 100 160 3], ...
                'Limits', [0 1], ...
                'Value', 0.5, ...
                'ValueChangingFcn', @(slider,event) obj.updateTransparency(event.Value));
            
            % Threshold
            uilabel(visPanel, 'Text', 'Threshold:', ...
                'Position', [10 50 70 22]);
            
            obj.Controls.Threshold = uislider(visPanel, ...
                'Position', [100 60 160 3], ...
                'Limits', [0 100], ...
                'Value', 50, ...
                'ValueChangingFcn', @(slider,event) obj.updateThreshold(event.Value));
        end
        
        function createChatGPTPanel(obj, panel)
            chatPanel = uipanel(panel, ...
                'Position', [10 10 280 180], ...
                'Title', 'ChatGPT Assistant');
            
            obj.Controls.ChatQuery = uieditfield(chatPanel, ...
                'Position', [10 120 200 22], ...
                'Value', '', ...
                'Placeholder', 'Ask about brain visualization...');
            
            uibutton(chatPanel, 'Text', 'Ask', ...
                'Position', [220 120 50 22], ...
                'ButtonPushedFcn', @(btn,event) obj.askChatGPT());
            
            obj.Controls.ChatResponse = uitextarea(chatPanel, ...
                'Position', [10 10 260 100], ...
                'Value', '', ...
                'Editable', 'off');
        end
        
        % Callback functions
        function loadData(obj)
            [file, path] = uigetfile({'*.nii;*.nii.gz', 'NIfTI files (*.nii, *.nii.gz)'});
            if file ~= 0
                obj.Controls.DataPath.Value = fullfile(path, file);
                obj.loadAndDisplayData(fullfile(path, file));
            end
        end
        
        function loadOverlay(obj)
            [file, path] = uigetfile({'*.nii;*.nii.gz', 'NIfTI files (*.nii, *.nii.gz)'});
            if file ~= 0
                obj.Controls.OverlayPath.Value = fullfile(path, file);
                obj.loadAndDisplayOverlay(fullfile(path, file));
            end
        end
        
        function loadAndDisplayData(obj, filepath)
            try
                % Load NIfTI data (implement actual loading logic)
                obj.Data.Main = load_nii(filepath);  % Requires NIfTI toolbox
                
                % Update display
                obj.updateDisplay();
                
                % Update slider limits
                dims = size(obj.Data.Main.img);
                obj.Controls.SliceSlider.Limits = [1 dims(3)];
                obj.Controls.SliceSlider.Value = round(dims(3)/2);
            catch ex
                errordlg(['Error loading data: ' ex.message], 'Error');
            end
        end
        
        function loadAndDisplayOverlay(obj, filepath)
            try
                % Load overlay data
                obj.Data.Overlay = load_nii(filepath);  % Requires NIfTI toolbox
                
                % Update display
                obj.updateDisplay();
            catch ex
                errordlg(['Error loading overlay: ' ex.message], 'Error');
            end
        end
        
        function updateDisplay(obj)
            if isfield(obj.Data, 'Main')
                % Clear current display
                cla(obj.Viewer.Axes);
                
                % Get current slice
                slice = round(obj.Controls.SliceSlider.Value);
                
                % Display main data
                imagesc(obj.Viewer.Axes, squeeze(obj.Data.Mainer.Axes, squeeze(obj.Data.Main.img(:,:,slice))));
                colormap(obj.Viewer.Axes, obj.Controls.Colormap.Value);
                
                % Display overlay if available
                if isfield(obj.Data, 'Overlay')
                    hold(obj.Viewer.Axes, 'on');
                    overlay = squeeze(obj.Data.Overlay.img(:,:,slice));
                    h = imagesc(obj.Viewer.Axes, overlay);
                    set(h, 'AlphaData', obj.Controls.Transparency.Value * (overlay > obj.Controls.Threshold.Value));
                    hold(obj.Viewer.Axes, 'off');
                end
                
                axis(obj.Viewer.Axes, 'equal');
                axis(obj.Viewer.Axes, 'tight');
            end
        end
        
        function changeView(obj, viewType)
            switch viewType
                case 'Sagittal'
                    view(obj.Viewer.Axes, [90 0]);
                case 'Coronal'
                    view(obj.Viewer.Axes, [0 0]);
                case 'Axial'
                    view(obj.Viewer.Axes, [0 90]);
                case '3D'
                    view(obj.Viewer.Axes, 3);
            end
        end
        
        function updateSlice(obj, value)
            obj.updateDisplay();
        end
        
        function updateColormap(obj, value)
            colormap(obj.Viewer.Axes, value);
        end
        
        function updateTransparency(obj, value)
            obj.updateDisplay();
        end
        
        function updateThreshold(obj, value)
            obj.updateDisplay();
        end
        
        function askChatGPT(obj)
            query = obj.Controls.ChatQuery.Value;
            if ~isempty(query)
                response = obj.ChatGPT.askGPT(query);
                obj.Controls.ChatResponse.Value = response;
            end
        end
        
        function generateScript(obj)
            % Generate MATLAB script for current visualization
            script = obj.createVisualizationScript();
            
            [file, path] = uiputfile('*.m', 'Save Visualization Script');
            if file ~= 0
                fid = fopen(fullfile(path, file), 'w');
                fprintf(fid, '%s', script);
                fclose(fid);
            end
        end
        
        function script = createVisualizationScript(obj)
            % Create MATLAB script from current settings
            script = '% Brain Visualization Script\n\n';
            
            % Add data loading
            script = [script sprintf('data = load_nii(''%s'');\n', obj.Controls.DataPath.Value)];
            if ~isempty(obj.Controls.OverlayPath.Value)
                script = [script sprintf('overlay = load_nii(''%s'');\n', obj.Controls.OverlayPath.Value)];
            end
            
            % Add visualization parameters
            script = [script sprintf('\n%% Visualization parameters\n')];
            script = [script sprintf('params.colormap = ''%s'';\n', obj.Controls.Colormap.Value)];
            script = [script sprintf('params.transparency = %.2f;\n', obj.Controls.Transparency.Value)];
            script = [script sprintf('params.threshold = %.2f;\n', obj.Controls.Threshold.Value)];
            
            % Add visualization commands
            script = [script '\n% Display data\n'];
            script = [script 'displayBrainData(data, overlay, params);\n'];
        end
    end
end

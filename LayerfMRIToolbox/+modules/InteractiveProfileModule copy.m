classdef InteractiveProfileModule < handle
    properties (Access = private)
        Parent          % Parent application handle
        Figure
        ChatGPT
        Controls
        Data
        Plots
        OriginalImage
        UIFigure
        Transparency
        OverlayImageHandle
        ROI
        Mask
        MaskFigure
        SaveButtonPressed
        isrotate
        MasklayerFigure
        InvidualFigure
        MeanPercentageFigure
        LayerProfileFigure
        StimVolume
        StimVolumes
        code_dir        % 添加 code_dir 属性
        QAenvName      % 添加 QAenvName 属性
    end

    methods
        function obj = InteractiveProfileModule(parent)
            if nargin > 0
                obj.Parent = parent;
            end
            obj.ChatGPT = obj.Parent.ChatGPTHelper();
            obj.code_dir = fileparts(mfilename("fullpath"));        %%所有在process中会出现的代码块的地址
            obj.pipeline_dir = fullfile(obj.code_dir,'pipelines');  %%存的pipeline的地址
            obj.d2n_dir = fullfile(obj.code_dir,'utils');
            obj.QAenvName = 'layerfmri'; % 或从配置文件/父对象获取
        end
        
        function show(obj)
            obj.Figure = uifigure('Name', 'Interactive Layer Profile', ...
                'Position', [150 150 1000 800]);
            obj.createLayout();
        end
    end
    
    methods (Access = private)

        function createLayout(obj)
            % Create main grid layout
            grid = uigridlayout(obj.Figure, [2 2]);
            grid.RowHeight = {'fit', '1x', '3x'};
            grid.ColumnWidth = {'5x', '4x'};
            
            % Create working directory panel at the top
            obj.createWorkingDirectorySelection(grid);
            
            % Create data selection and parameter panel
            obj.createDataAndParameterPanel(grid);
            
            % Create chatGPT panel at the top right
            obj.createChatGPTPanel(grid);
            
            % Create results panel at the bottom
            obj.createResultsPanel(grid);
        end

        function createWorkingDirectorySelection(obj, grid)
            % Add working directory selection directly to the grid
            selectButton = uibutton(grid, 'Text', 'Select Working Directory', ...
                'ButtonPushedFcn', @(btn,event) obj.selectWorkingDirectory());
            selectButton.Layout.Row = 1;
            selectButton.Layout.Column = 1;
            
            obj.Controls.WorkingDir = uieditfield(grid, 'Editable', 'off');
            obj.Controls.WorkingDir.Layout.Row = 1;
            obj.Controls.WorkingDir.Layout.Column = 2;
        end
        
        function createDataAndParameterPanel(obj, grid)
            dataParamPanel = uipanel(grid, 'Title', 'Data Selection and Parameters');
            dataParamPanel.Layout.Row = 2;
            dataParamPanel.Layout.Column = 1;
            
            % Layer fMRI File Paths
            labels = {'Layer fMRI File Path', 'Layer fMRI Mean File Path', 'Activation Map File Path'};
            for i = 1:3
                uilabel(dataParamPanel, 'Text', labels{i}, ...
                    'Position', [10 130-35*(i-1) 130 22]);
                
                obj.Controls.(sprintf('FilePath%d', i)) = uieditfield(dataParamPanel, ...
                    'Position', [150 130-35*(i-1) 250 22], ...
                    'Editable', 'off');
                
                uibutton(dataParamPanel, 'Text', 'Choose Path', ...
                    'Position', [410 130-35*(i-1) 80 22], ...
                    'ButtonPushedFcn', @(btn,event) obj.selectFilePath(i));
            end
            
            % Action Buttons
            uibutton(dataParamPanel, 'Text', 'Draw a Frame', ...
                'Position', [100 20 100 30], ...
                'ButtonPushedFcn', @(btn,event) obj.drawFrame());
            
            uibutton(dataParamPanel, 'Text', 'Draw Boundaries', ...
                'Position', [300 20 100 30], ...
                'ButtonPushedFcn', @(btn,event) obj.drawBoundaries());
        end
        
        function createChatGPTPanel(obj, grid)
            chatPanel = uipanel(grid, 'Title', 'ChatGPT Assistant');
            chatPanel.Layout.Row = 2;
            chatPanel.Layout.Column = 2;
            
            obj.Controls.ChatQuery = uieditfield(chatPanel, ...
                'Position', [10 40 200 22], ...
                'Value', '', ...
                'Placeholder', 'Ask about layer analysis...');
            
            uibutton(chatPanel, 'Text', 'Ask', ...
                'Position', [220 40 60 22], ...
                'ButtonPushedFcn', @(btn,event) obj.askChatGPT());
            
            obj.Controls.ChatResponse = uitextarea(chatPanel, ...
                'Position', [10 10 270 25], ...
                'Value', '', ...
                'Editable', 'off');
        end
        
        function createResultsPanel(obj, gridLayout)
            resultsPanel = uipanel(gridLayout, 'Title', 'Results');
            resultsPanel.Layout.Row = 3;
            resultsPanel.Layout.Column = [1 2];
            
            % Create tab group
            tabGroup = uitabgroup(resultsPanel, 'Position', [0.01 0.01 0.98 0.98]);
            
            % Create individual tabs for each type of result
            obj.Plots.IndividualTab = uitab(tabGroup, 'Title', 'Individual Results');
            obj.Plots.MeanTab = uitab(tabGroup, 'Title', 'Mean Percentage');
            obj.Plots.LayerTab = uitab(tabGroup, 'Title', 'Layer Profile');
            
            % Create axes for each tab with proper settings
            axesProps = {'Position', [0.1 0.1 0.8 0.8], ...
                         'Box', 'on', ...
                         'FontSize', 10, ...
                         'NextPlot', 'replacechildren', ...
                         'XGrid', 'on', ...
                         'YGrid', 'on'};
             
            obj.Plots.IndividualAxes = uiaxes(obj.Plots.IndividualTab, axesProps{:});
            obj.Plots.MeanAxes = uiaxes(obj.Plots.MeanTab, axesProps{:});
            obj.Plots.LayerAxes = uiaxes(obj.Plots.LayerTab, axesProps{:});
        end

        function createPlotControls(obj, panel)
            controls = {'Show Grid', 'Show Error Bars', 'Normalize'};
            for i = 1:length(controls)
                obj.Controls.(sprintf('Plot%d', i)) = uicheckbox(panel, ...
                    'Position', [300 670-30*i 100 22], ...
                    'Text', controls{i}, ...
                    'ValueChangedFcn', @(cb,event) obj.updatePlot());
            end
        end
        
        function selectWorkingDirectory(obj)
            dir = uigetdir();
            if dir ~= 0
                obj.Controls.WorkingDir.Value = dir;
            end
        end

        function selectFilePath(obj, fileIndex)
            [file, path] = uigetfile({'*.nii;*.nii.gz', 'NIfTI files (*.nii, *.nii.gz)'});
            if file ~= 0
                obj.Controls.(sprintf('FilePath%d', fileIndex)).Value = fullfile(path, file);
            end
        end

        function drawFrame(obj)
            try
                % Load and prepare images
                [mean_img, activation_map] = obj.loadImages();
                
                % Create main figure and layout
                obj.createFrameFigure(mean_img, activation_map);
                
                % Process frame if isrotate is true
                % if obj.isrotate
                    % Create ROI
                    obj.ROI = drawassisted;
                    obj.Mask = createMask(obj.ROI);
                    
                    % Add listeners
                    addlistener(obj.ROI, 'MovingROI', @(src,evt) obj.updateMask(src));
                    addlistener(obj.ROI, 'ROIMoved', @(src,evt) obj.updateMask(src));
                    
                    % Wait for ROI completion
                    wait(obj.ROI);
                    
                    % Show and process mask
                    obj.showMask();
                    
                    % Process results
                    obj.processFrameResults();
                % end
                
            catch ME
                uialert(obj.Figure, ['Error reading file: ', ME.message], 'Error');
            end
        end
        function drawBoundaries(obj)
            try
                % Load and prepare images
                [mean_img, activation_map] = obj.loadImages();
                
                % Create main figure and layout
                obj.createBoundaryFigure(mean_img, activation_map);
                
                % Draw boundaries and process mask
                mask = zeros(size(obj.OriginalImage));
                [rows, cols] = size(obj.OriginalImage);
                [h1, h2] = obj.drawBoundaryLines();
                
                % Setup mask updates
                obj.setupMaskListeners(h1, h2, mask, rows, cols);
                
                % Process results if save button pressed
                obj.processBoundaryResults();
                
            catch ME
                uialert(obj.Figure, ['Error reading file: ', ME.message], 'Error');
            end
        end

        % New helper functions
        function [mean_img, activation_map] = loadImages(obj)
            img_4D = spm_read_vols(spm_vol(obj.Controls.FilePath1.Value));
            mean_img = spm_read_vols(spm_vol(obj.Controls.FilePath2.Value));
            obj.OriginalImage = mean_img;
            activation_map = spm_read_vols(spm_vol(obj.Controls.FilePath3.Value));
            activation_map(activation_map < 1) = nan;
        end
        
        function createFrameFigure(obj, mean_img, activation_map)
            % Create main figure
            obj.UIFigure = figure('Name', 'Draw on the image', ...
                'NumberTitle', 'off', ...
                'Position', [100 100 1200 800]);

            % Create image panel
            obj.createImagePanel(mean_img, activation_map);
            
            % Create control panel
            obj.createFrameControlPanel();
        end

        function createBoundaryFigure(obj, mean_img, activation_map)
            % Create main figure
            obj.UIFigure = figure('Name', 'Draw on the image', ...
                'NumberTitle', 'off', ...
                'Position', [100 100 1200 800]);

            % Create image panel
            obj.createImagePanel(mean_img, activation_map);
            
            % Create control panel
            obj.createBoundaryControlPanel();
        end

        function createImagePanel(obj, mean_img, activation_map)
            % Create panel for image and slider
            imagePanel = uipanel(obj.UIFigure, ...
                'Position', [0.05 0.05 0.55 0.9], ...
                'BorderType', 'none');
            
            % Create axes for image
            ax = axes('Parent', imagePanel, ...
                'Position', [0 0.1 1 0.9]);  % Leave space at bottom for slider
            
            % Process activation map
            activation_map(activation_map < 1) = nan;
            
            % Create overlay image
            obj.Transparency = 1;
            obj.OverlayImageHandle = imoverlay(mean_img, activation_map, ...
                [1 0.8*max(activation_map(:))], ...
                [0.2*min(mean_img(:)) 0.8*max(mean_img(:))], ...
                "hot", obj.Transparency, ax);
            axis equal; axis off;
            title('Draw on the image. Press Enter when finished.');
            
            % Create slider for activation map transparency
            obj.Controls.ActivationSlider = uicontrol(imagePanel, 'Style', 'slider', ...
                'Min', 0, 'Max', 1, 'Value', 1, ...
                'Position', [10 5 imagePanel.Position(3)*obj.UIFigure.Position(3)-20 20], ...
                'Callback', @(src,~) obj.updateActivationTransparency(src));
            
            % Add label for slider
            uicontrol(imagePanel, 'Style', 'text', ...
                'String', 'Activation Map Transparency', ...
                'Position', [10 25 150 15], ...
                'HorizontalAlignment', 'left');
        end

        function updateActivationTransparency(obj, src)
            % Get alpha value from slider
            alpha = get(src, 'Value');
            
            % Update overlay transparency
            alphaData = obj.OverlayImageHandle.AlphaData;
            alphaData(~isnan(obj.OverlayImageHandle.CData)) = alpha;
            set(obj.OverlayImageHandle, 'AlphaData', alphaData);
        end

        function createFrameControlPanel(obj)
            
            % 创建控制面板
            controlPanel = uipanel(obj.UIFigure, ...
                'Position', [0.65 0.05 0.25 0.9], ...
                'Title', 'Controls');
            
            % Layout parameters
            params.padding = 20;
            params.elementHeight = 25;
            params.buttonWidth = 120;
            params.buttonHeight = 40;
            params.startY = 700;
            params.panelWidth = 240;
            
            % Create controls
            obj.createLayersControl(controlPanel, params);
            obj.createRandomStimControl(controlPanel, params);
            obj.createFrameConfirmButton(controlPanel, params);
        end

        function createBoundaryControlPanel(obj)
            
            % 创建控制面板
            controlPanel = uipanel(obj.UIFigure, ...
                'Position', [0.65 0.05 0.25 0.9], ...
                'Title', 'Controls');
            
            % Layout parameters
            params.padding = 20;
            params.elementHeight = 25;
            params.buttonWidth = 120;
            params.buttonHeight = 40;
            params.startY = 700;
            params.panelWidth = 240;
            
            % Create controls
            obj.createLayersControl(controlPanel, params);
            obj.createRandomStimControl(controlPanel, params);
            obj.createBoundaryConfirmButton(controlPanel, params);
        end

        function createLayersControl(obj, panel, p)
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Number of Layers:', ...
                'Position', [p.padding p.startY-3*p.elementHeight-p.padding 100 p.elementHeight], ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.NumLayers = uicontrol(panel, 'Style', 'edit', ...
                'Position', [p.padding+110 p.startY-3*p.elementHeight-p.padding 100 p.elementHeight], ...
                'String', '10');
        end

        function createRandomStimControl(obj, panel, p)
            % Random Stim dropdown
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Random Stim:', ...
                'Position', [p.padding p.startY-4*p.elementHeight-2*p.padding 100 p.elementHeight], ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.RandomStim = uicontrol(panel, 'Style', 'popupmenu', ...
                'String', {'no', 'yes'}, ...
                'Position', [p.padding+110 p.startY-4*p.elementHeight-2*p.padding 100 p.elementHeight], ...
                'Callback', @(src,~) obj.toggleRandomStimControl(panel, p));

            % Initial Stim Volume UI elements
            obj.createStimVolumeControl(panel, p);
        end

        function createStimVolumeControl(obj, panel, p)
            % Create initial stim volume controls with 'dynamicUI' tag
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Stim Volume', ...
                'Position', [p.padding p.startY-5*p.elementHeight-3*p.padding 100 p.elementHeight], ...
                'Tag', 'dynamicUI', ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.StimVolume = uicontrol(panel, 'Style', 'edit', ...
                'Position', [p.padding+110 p.startY-5*p.elementHeight-3*p.padding 100 p.elementHeight], ...
                'Tag', 'dynamicUI', ...
                'Callback', @(src,~) obj.updateStimVolume());
        end

        function toggleRandomStimControl(obj, panel, p)
            % Clear previous dynamic UI elements
            delete(findall(panel, 'Tag', 'dynamicUI'));
            
            % Get the selected value (popupmenu returns index)
            selectedValue = obj.Controls.RandomStim.String{obj.Controls.RandomStim.Value};
            
            if strcmp(selectedValue, 'yes')
                % Show random stim file path controls
                uicontrol(panel, 'Style', 'text', ...
                    'String', 'Random stim File Path', ...
                    'Position', [p.padding p.startY-5*p.elementHeight-3*p.padding 150 p.elementHeight], ...
                    'Tag', 'dynamicUI', ...
                    'HorizontalAlignment', 'left');
                
                obj.Controls.RandomStimPath = uicontrol(panel, 'Style', 'edit', ...
                    'Position', [p.padding+110 p.startY-5*p.elementHeight-3*p.padding 120 p.elementHeight], ...
                    'Tag', 'dynamicUI', ...
                    'Enable', 'off');
                
                uicontrol(panel, 'Style', 'pushbutton', ...
                    'String', 'Choose Path', ...
                    'Position', [p.padding+240 p.startY-5*p.elementHeight-3*p.padding 80 p.elementHeight], ...
                    'Tag', 'dynamicUI', ...
                    'Callback', @(~,~) obj.setRandomStimFilePath());
                    
                % Add text area for stim volume statistics (moved to bottom)
                obj.Controls.StimStats = uicontrol(panel, 'Style', 'text', ...
                    'Position', [p.padding p.startY-8*p.elementHeight-4*p.padding 300 3*p.elementHeight], ...
                    'Tag', 'dynamicUI', ...
                    'HorizontalAlignment', 'left');
            else
                % Show stim volume input
                obj.createStimVolumeControl(panel, p);
            end
        end

        function setRandomStimFilePath(obj)
            [filename, pathname] = uigetfile(...
                {'*.xlsx;*.xls;*.csv;*.txt;*.tsv', 'Data Files (*.xlsx, *.xls, *.csv, *.txt, *.tsv)'}, ...
                'Select a data file');
            
            if isequal(filename, 0) || isequal(pathname, 0)
                return; % User canceled selection
            end
            
            stimFile = fullfile(pathname, filename);
            obj.Controls.RandomStimPath.String = stimFile;
            
            % Read and process stim file
            stimInfo = readtable(stimFile);
            
            % Convert duration to volumes
            if iscell(stimInfo.Duration_ms_)
                stimDurationMs = cellfun(@str2double, stimInfo.Duration_ms_);
            elseif isstring(stimInfo.Duration_ms_)
                stimDurationMs = str2double(stimInfo.Duration_ms_);
            else
                stimDurationMs = stimInfo.Duration_ms_;
            end
            
            % Calculate stim volumes
            TR = 0.2; % TR in seconds
            stimDurationS = stimDurationMs / 1000;
            stimVolumes = stimDurationS / TR;
            
            % Store unique stim volumes
            obj.StimVolumes = unique(stimVolumes);
            
            % Create statistics string
            statsStr = obj.createStimVolumeStats(stimVolumes);
            
            % Update statistics display
            obj.Controls.StimStats.String = statsStr;
        end

        function statsStr = createStimVolumeStats(obj, stimVolumes)
            % Get unique volumes and their counts
            uniqueVolumes = unique(stimVolumes);
            volumeCounts = zeros(size(uniqueVolumes));
            
            for i = 1:length(uniqueVolumes)
                volumeCounts(i) = sum(stimVolumes == uniqueVolumes(i));
            end
            
            % Create statistics string
            statsStr = 'Stim Volumes Statistics:';
            for i = 1:length(uniqueVolumes)
                statsStr = sprintf('%s\nVolume %.1f: %d times', ...
                    statsStr, uniqueVolumes(i), volumeCounts(i));
            end
        end

        function updateStimVolume(obj)
            if isfield(obj.Controls, 'StimVolume')
                obj.StimVolume = str2double(obj.Controls.StimVolume.String);  % Use String instead of Value
            end
        end

        function createFrameConfirmButton(obj, panel, p)
            uicontrol(panel, 'Style', 'pushbutton', ...
                'String', 'Confirm Modification', ...
                'Position', [(p.panelWidth-p.buttonWidth)/2 p.padding p.buttonWidth p.buttonHeight], ...
                'Callback', @(~,~) obj.processFrameResults());
        end

        function createBoundaryConfirmButton(obj, panel, p)
            uicontrol(panel, 'Style', 'pushbutton', ...
                'String', 'Confirm Modification', ...
                'Position', [(p.panelWidth-p.buttonWidth)/2 p.padding p.buttonWidth p.buttonHeight], ...
                'Callback', @(~,~) obj.processBoundaryResults());
        end

        function [h1, h2] = drawBoundaryLines(obj)
            title('Draw the first boundary');
            h1 = drawfreehand('Color', 'r', 'Closed', false, 'InteractionsAllowed', 'all');
            title('Draw the second boundary');
            h2 = drawfreehand('Color', 'r', 'Closed', false, 'InteractionsAllowed', 'all');
        end

        function setupMaskListeners(obj, h1, h2, mask, rows, cols)
            obj.updateBMask(h1, h2, mask, rows, cols);
            addlistener(h1, 'ROIMoved', @(src,evt) obj.updateBMask(h1, h2, mask, rows, cols));
            addlistener(h2, 'ROIMoved', @(src,evt) obj.updateBMask(h1, h2, mask, rows, cols));
            wait(h1);
            wait(h2);
        end

        function processFrameResults(obj)
            try
                % 确保必要的图形对象存在
                if isempty(obj.MasklayerFigure) || ~isvalid(obj.MasklayerFigure)
                    obj.MasklayerFigure = figure('Name', 'Mask Layers');
                end
                
                % 获取必要的参数
                header = spm_vol(obj.Controls.FilePath1.Value);
                header = header(1);
                layernum = str2double(obj.Controls.NumLayers.String);
        
                % 处理 Mask 层
                figure(obj.MasklayerFigure);
                clf;
                layers = labelMask(obj.MasklayerFigure, obj.Mask, header, ...
                    obj.Controls.FilePath1.Value, layernum);
        
                % 获取 StimVolume
                if strcmp(obj.Controls.RandomStim.String{obj.Controls.RandomStim.Value}, 'yes')
                    if isempty(obj.StimVolumes)
                        errordlg('Please select a random stim file first.', 'Error');
                        return;
                    end
                    stimVolume = obj.StimVolumes;
                else
                    if isempty(obj.Controls.StimVolume.String)
                        errordlg('Please enter a stim volume.', 'Error');
                        return;
                    end
                    stimVolume = str2double(obj.Controls.StimVolume.String);
                end
        
                % 计算并显示结果
                obj.calculateAndDisplayResults(layers, stimVolume);
        
                % 设置 SaveButtonPressed 标志
                obj.SaveButtonPressed = true;
        
            catch ME
                errordlg(['Error in frame processing: ' ME.message], 'Error');
                disp(getReport(ME));
            end
        end

        function processBoundaryResults(obj)
            try
                % 确保必要的图形对象存在
                if isempty(obj.MasklayerFigure) || ~isvalid(obj.MasklayerFigure)
                    obj.MasklayerFigure = figure('Name', 'Mask Layers');
                end
                figure(obj.MasklayerFigure);
                clf;

                % 获取必要的参数
                header = spm_vol(obj.Controls.FilePath1.Value);
                header = header(1);
                layernum = str2double(obj.Controls.NumLayers.String);

                % 确保 Mask 存在
                if isempty(obj.Mask)
                    errordlg('Please draw boundaries first.', 'Error');
                    return;
                end

                % 处理 Mask 层
                layers = labelBMask(obj.MasklayerFigure, obj.Mask, header, ...
                    obj.Controls.FilePath1.Value, layernum);

                % 获取 StimVolume
                if strcmp(obj.Controls.RandomStim.String{obj.Controls.RandomStim.Value}, 'yes')
                    if isempty(obj.StimVolumes)
                        errordlg('Please select a random stim file first.', 'Error');
                        return;
                    end
                    stimVolume = obj.StimVolumes;
                else
                    if isempty(obj.Controls.StimVolume.String)
                        errordlg('Please enter a stim volume.', 'Error');
                        return;
                    end
                    stimVolume = str2double(obj.Controls.StimVolume.String);
                end

                % 计算并显示结果
                obj.calculateAndDisplayResults(layers, stimVolume);

                % 设置 SaveButtonPressed 标志
                obj.SaveButtonPressed = true;

                % 显示确认消息
                msgbox('Analysis completed successfully!', 'Success');

            catch ME
                errordlg(['Error in confirmation: ' ME.message], 'Error');
                disp(getReport(ME));
            end
        end

        function calculateAndDisplayResults(obj, layers, stimVolume)
            try
                % 确保 layernum 已定义
                layernum = str2double(obj.Controls.NumLayers.String);
                
                % 创建或激活 Individual Figure
                if isempty(obj.InvidualFigure) || ~isvalid(obj.InvidualFigure)
                    obj.InvidualFigure = figure('Name', 'Individual Results', ...
                        'NumberTitle', 'off', ...
                        'Position', [100 100 1200 800]);
                else
                    figure(obj.InvidualFigure);
                end
                clf;
                
                % 计算个体百分比
                percentage_epoch = calculate_individual_percentage(obj.InvidualFigure, ...
                    obj.Controls.FilePath1.Value, layernum, 140, 60, pwd, layers, [-0.005 0.03], stimVolume);
                
                % 创建或激活 Mean Percentage Figure
                if isempty(obj.MeanPercentageFigure) || ~isvalid(obj.MeanPercentageFigure)
                    obj.MeanPercentageFigure = figure('Name', 'Mean Percentage', ...
                        'NumberTitle', 'off', ...
                        'Position', [150 150 1200 800]);
                else
                    figure(obj.MeanPercentageFigure);
                end
                clf;
                
                % 计算平均百分比
                calculate_mean_percentage(obj.MeanPercentageFigure, percentage_epoch, [-0.005 0.03], stimVolume);
                
                % 创建或激活 Layer Profile Figure
                if isempty(obj.LayerProfileFigure) || ~isvalid(obj.LayerProfileFigure)
                    obj.LayerProfileFigure = figure('Name', 'Layer Profile', ...
                        'NumberTitle', 'off', ...
                        'Position', [200 200 1200 800]);
                else
                    figure(obj.LayerProfileFigure);
                end
                clf;
                
                % 计算层剖面
                calculate_layer_profile(obj.LayerProfileFigure, obj.Controls.FilePath1.Value, layers, 1:layernum);
                
                % 生成报告
                [pathstr, scan_name, extension] = fileparts(obj.Controls.FilePath1.Value);
                templatePath = fullfile(obj.code_dir, 'report', 'InteractiveProfile_template.html');
                datatype = 'InteractiveProfile';
                generate_HTML(obj, pathstr, scan_name, obj.QAenvName, templatePath, datatype);
                
            catch ME
                errordlg(['Error in displaying results: ' ME.message], 'Error');
                disp(getReport(ME));
            end
        end

        function showMask(obj)
            obj.MaskFigure = figure('Name', 'Mask of the drawn region', ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 839, 580]);
            ax = axes('Parent', obj.MaskFigure);
            imshow(obj.Mask, 'Parent', ax, 'InitialMagnification', 'fit');
            title('Mask of the drawn region');
        end   

        function updateMask(obj, src)
            obj.Mask = createMask(src);
        end
        
        function updateBMask(obj, h1, h2, mask, rows, cols)
            line1 = h1.Position;
            line2 = h2.Position;
            mask(:) = 0;
            for i = 1:size(line1, 1)
                y = round(line1(i, 1));
                x = round(line1(i, 2));
                if x > 0 && x <= size(mask, 1) && y > 0 && y <= size(mask, 2)
                    mask(x, y) = 1;
                end
            end
            for i = 1:size(line2, 1)
                y = round(line2(i, 1));
                x = round(line2(i, 2));
                if x > 0 && x <= size(mask, 1) && y > 0 && y <= size(mask, 2)
                    mask(x, y) = 2;
                end
            end
            waitforbuttonpress;
            key = get(gcf, 'CurrentKey');
            if strcmp(key, 'return')
                polygon_points = [line1; flipud(line2)];
                mask_polygon = poly2mask(polygon_points(:,1), polygon_points(:,2), rows, cols);
                mask(mask_polygon & mask == 0) = 3;
                obj.Mask = mask;
                obj.showMask();
            end
        end

        % Optional: Add a method to update the results panel layout
        function updateResultsLayout(obj)
            % Get the current figure size
            figPos = obj.Figure.Position;
            
            % Update tab positions if needed
            for ax = [obj.Plots.IndividualAxes, obj.Plots.MeanAxes, obj.Plots.LayerAxes]
                % Adjust axes properties based on figure size
                ax.FontSize = min(max(figPos(3)/100, 8), 12);  % Scale font size
                
                % Update axis limits and ticks if needed
                ax.XGrid = 'on';
                ax.YGrid = 'on';
            end
        end

        function askChatGPT(obj)
            try
                % 获取查询文本
                query = obj.Controls.ChatQuery.Value;
                
                % 调用 ChatGPT API
                response = obj.ChatGPT.askGPT(query);
                
                % 更新响应文本区域
                if isfield(obj.Controls, 'ChatResponse')
                    obj.Controls.ChatResponse.Value = response;
                end
                
            catch ME
                % 处理 ChatGPT 查询错误
                errordlg(['Error querying ChatGPT: ' ME.message], 'ChatGPT Error');
                if isfield(obj.Controls, 'ChatResponse')
                    obj.Controls.ChatResponse.Value = ['Error: ' ME.message];
                end
            end
        end

    end
end
classdef InteractiveProfileModule < handle
    properties (Access = private)
        Parent          % Parent application handle
        ChatGPT
        Controls
        Data
        UIFigure
        Transparency
        OverlayImageHandle
        ROI
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
        ImageSize

        Figure          % 主窗口
        Plots          % 图像相关的句柄
        img
        header
        OriginalImage      % 原始图像（用于计算）
        ActivationMap     % 原始激活图（用于计算）
        DisplayImage      % 显示用的图像
        DisplayActivationMap % 显示用的激活图
        CurrentRotation = 0  % 当前旋转角度
        Mask          % ROI掩码
        IsDrawingMode = false  % 绘图模式标志
        MaskFigure    % 掩码显示窗口
        Boundaries
        DisplaySettings

    end

    methods (Access = public)
        function obj = InteractiveProfileModule(parent)
            if nargin > 0
                obj.Parent = parent;
            end
            obj.ChatGPT = obj.Parent.ChatGPTHelper;
            obj.Controls = struct();  % 初始化 Controls 结构
            obj.code_dir = fileparts(mfilename("fullpath"));        %%所有在process中会出现的代码块的地址
            % obj.pipeline_dir = fullfile(obj.code_dir,'pipelines');  %%存的pipeline的地址
            % obj.d2n_dir = fullfile(obj.code_dir,'utils');
            obj.QAenvName = 'layerfmri'; % 或从配置文件/父对象获取
        end
        
        function show(obj)
            % 创建主窗口并设置始终置顶
            obj.Figure = uifigure('Name', 'Interactive Layer Profile', ...
                'Position', [150 150 1000 800], ...
                'WindowStyle', 'modal');  % 使用 modal 样式来保持窗口在前
            
            % 确保窗口可见性
            figure(obj.Figure);
            
            obj.createLayout();
        end

        function selectWorkingDirectory(obj)
            % 创建一个进度对话框
            % d = uiprogressdlg(obj.Figure, ...
            %     'Message', 'Selecting directory...', ...
            %     'Title', 'Please Wait', ...
            %     'Indeterminate','on');
            
            % 显示目录选择对话框
            dir = uigetdir(pwd, 'Select Working Directory');
            
            % 关闭进度对话框
            % close(d);
            
            if dir ~= 0
                obj.Controls.WorkingDir.Value = dir;
                % 强制窗口更新
                % drawnow
            end
        end
        
        function selectFilePath(obj, fileIndex)
            % 创建一个进度对话框
            % d = uiprogressdlg(obj.Figure, ...
            %     'Message', 'Selecting file...', ...
            %     'Title', 'Please Wait', ...
            %     'Indeterminate','on');
            
            % 显示文件选择对话框
            [file, path] = uigetfile(...
                {'*.nii;*.nii.gz', 'NIfTI files (*.nii, *.nii.gz)'}, ...
                'Select NIfTI File', ...
                pwd);
            
            % 关闭进度对话框
            % close(d);
            
            if file ~= 0
                obj.Controls.(sprintf('FilePath%d', fileIndex)).Value = fullfile(path, file);
                % 强制窗口更新
                % drawnow
            end
        end

        function drawBoundaries(obj)
            try
                % 加载和准备图像
                [mean_img, activation_map] = obj.loadImages();
                
                % 创建主窗口
                obj.createBoundaryFigure(mean_img, activation_map);
                
            catch ME
                errordlg(['Error: ', ME.message], 'Error');
            end
        end
        % New helper functions
        % function [mean_img, activation_map] = loadImages(obj)
        %     img_4D = spm_read_vols(spm_vol(obj.Controls.FilePath1.Value));
        %     mean_img = spm_read_vols(spm_vol(obj.Controls.FilePath2.Value));
        %     activation_map = spm_read_vols(spm_vol(obj.Controls.FilePath3.Value));
        %     activation_map(activation_map < 1) = nan;

        %     % 存储原始图像
        %     obj.OriginalImage = mean_img;
        %     obj.ActivationMap = activation_map;
            
        %     % 初始化显示图像
        %     obj.DisplayImage = mean_img;
        %     obj.DisplayActivationMap = activation_map;

        % end
        function [mean_img, activation_map] = loadImages(obj)
            % 加载4D数据
            header = spm_vol(obj.Controls.FilePath1.Value);
            img_4D = spm_read_vols(header);

            % 加载激活图
            activation_map = spm_read_vols(spm_vol(obj.Controls.FilePath2.Value));
            activation_map(activation_map < 1) = nan;
            
            % 检查维度
            img_size = size(img_4D);
            if length(img_size) >= 3 && img_size(3) > 1
                % 创建更大的选择对话框
                slice_fig = figure('Name', 'Select Slice', ...
                    'NumberTitle', 'off', ...
                    'Position', [300 200 800 600], ...
                    'MenuBar', 'none', ...
                    'ToolBar', 'none');

                % 创建面板用于组织控件
                control_panel = uipanel(slice_fig, ...
                    'Position', [0.05 0.05 0.9 0.2], ...
                    'Title', 'Controls');

                % 创建左右按钮和层数显示
                uicontrol(control_panel, 'Style', 'pushbutton', ...
                    'String', '←', ...
                    'FontSize', 14, ...
                    'Position', [20 20 50 30], ...
                    'Callback', @decrementSlice);

                text_display = uicontrol(control_panel, 'Style', 'text', ...
                    'Position', [80 20 150 30], ...
                    'FontSize', 12, ...
                    'String', sprintf('Slice: %d/%d', round(img_size(3)/2), img_size(3)));

                uicontrol(control_panel, 'Style', 'pushbutton', ...
                    'String', '→', ...
                    'FontSize', 14, ...
                    'Position', [240 20 50 30], ...
                    'Callback', @incrementSlice);

                % 对比度控制
                uicontrol(control_panel, 'Style', 'text', ...
                    'Position', [310 40 100 20], ...
                    'String', 'Contrast:', ...
                    'HorizontalAlignment', 'left');

                contrast_min_slider = uicontrol(control_panel, 'Style', 'slider', ...
                    'Position', [310 20 100 20], ...
                    'Min', 0, 'Max', 1, 'Value', 0.2, ...
                    'Callback', @updateContrast);

                contrast_max_slider = uicontrol(control_panel, 'Style', 'slider', ...
                    'Position', [420 20 100 20], ...
                    'Min', 0, 'Max', 1, 'Value', 0.8, ...
                    'Callback', @updateContrast);

                contrast_text = uicontrol(control_panel, 'Style', 'text', ...
                    'Position', [530 20 150 20], ...
                    'String', 'Range: [0.2, 0.8]');

                % 确认按钮
                uicontrol(control_panel, 'Style', 'pushbutton', ...
                    'String', 'Confirm', ...
                    'Position', [690 20 80 30], ...
                    'Callback', @confirmSlice);

                % 预览轴
                preview_ax = axes(slice_fig, 'Position', [0.1 0.3 0.8 0.65]);

                % 存储数据
                slice_data = struct();
                slice_data.img = img_4D;
                slice_data.selected_slice = round(img_size(3)/2);
                slice_data.confirmed = false;
                slice_data.contrast_min = 0.2;
                slice_data.contrast_max = 0.8;

                % 显示初始预览
                updatePreview();

                % 等待用户确认
                waitfor(slice_fig);

                if ~slice_data.confirmed
                    error('Slice selection cancelled');
                end

                % 使用选定的层
                selected_slice = slice_data.selected_slice;
                img_4D = img_4D(:,:,selected_slice,:);
                activation_map = activation_map(:,:,selected_slice);
                
                % 保存显示参数
                obj.DisplaySettings.contrast_min = slice_data.contrast_min;
                obj.DisplaySettings.contrast_max = slice_data.contrast_max;
                obj.DisplaySettings.selected_slice = selected_slice;
            end
            obj.img = img_4D;
            obj.header = header;

            % 计算时间维度上的平均
            if length(size(img_4D)) == 4
                mean_img = mean(img_4D, 4);
            else
                mean_img = img_4D;
            end
            
            % 存储原始图像
            obj.OriginalImage = mean_img;
            obj.ActivationMap = activation_map;
            
            % 初始化显示图像
            obj.DisplayImage = mean_img;
            obj.DisplayActivationMap = activation_map;
            
            % 嵌套函数：更新预览
            function updatePreview()
                if length(size(slice_data.img)) == 4
                    preview_data = squeeze(mean(slice_data.img(:,:,slice_data.selected_slice,:), 4));
                else
                    preview_data = slice_data.img(:,:,slice_data.selected_slice);
                end
                
                % 计算显示范围
                data_min = min(preview_data(:));
                data_max = max(preview_data(:));
                display_min = data_min + slice_data.contrast_min * (data_max - data_min);
                display_max = data_min + slice_data.contrast_max * (data_max - data_min);
                
                % 更新显示
                cla(preview_ax);
                imagesc(preview_ax, preview_data);
                colormap(preview_ax, 'gray');
                clim(preview_ax, [display_min display_max]);
                axis(preview_ax, 'image');
                title(preview_ax, sprintf('Slice %d Preview', slice_data.selected_slice));
                
                % 更新文本显示
                text_display.String = sprintf('Slice: %d/%d', slice_data.selected_slice, size(slice_data.img, 3));
                contrast_text.String = sprintf('Range: [%.2f, %.2f]', slice_data.contrast_min, slice_data.contrast_max);
            end
            
            % 嵌套函数：减少层数
            function decrementSlice(~, ~)
                slice_data.selected_slice = max(1, slice_data.selected_slice - 1);
                updatePreview();
            end

            % 嵌套函数：增加层数
            function incrementSlice(~, ~)
                slice_data.selected_slice = min(size(slice_data.img, 3), slice_data.selected_slice + 1);
                updatePreview();
            end

            % 嵌套函数：更新对比度
            function updateContrast(src, ~)
                if src == contrast_min_slider
                    slice_data.contrast_min = src.Value;
                else
                    slice_data.contrast_max = src.Value;
                end
                
                % 确保最小值小于最大值
                if slice_data.contrast_min >= slice_data.contrast_max
                    if src == contrast_min_slider
                        slice_data.contrast_min = slice_data.contrast_max - 0.1;
                        src.Value = slice_data.contrast_min;
                    else
                        slice_data.contrast_max = slice_data.contrast_min + 0.1;
                        src.Value = slice_data.contrast_max;
                    end
                end
                
                updatePreview();
            end

            % 嵌套函数：确认选择
            function confirmSlice(~, ~)
                slice_data.confirmed = true;
                close(slice_fig);
            end
        end

        function processBoundaryResults(obj)
            try
                workDir = obj.Controls.WorkingDir.Value;
                % 创建结果子目录
                resultsDir = fullfile(workDir, 'interactive_profile_results');
                if ~exist(resultsDir, 'dir')
                    mkdir(resultsDir);
                end
                % 确保必要的图形对象存在
                if isempty(obj.MasklayerFigure) || ~isvalid(obj.MasklayerFigure)
                    obj.MasklayerFigure = figure('Name', 'Mask Layers');
                end
                figure(obj.MasklayerFigure);
                clf;

                % 获取必要的参数
                header_single = obj.header(1);
                layernum = str2double(obj.Controls.NumLayers.String);

                % 确保 Mask 存在
                if isempty(obj.Mask)
                    errordlg('Please draw boundaries first.', 'Error');
                    return;
                end

                % 如果mask是在旋转状态下创建的，需要旋转回原始方向
                if obj.CurrentRotation ~= 0
                    % 将mask旋转回原始方向
                    rotation_angle = -obj.CurrentRotation;  % 使用负角度旋转回去
                    original_mask = imrotate(obj.Mask, rotation_angle, 'bilinear');
                    % 确保旋转后的mask仍然是二值图像
                    original_mask = round(original_mask);
                else
                    original_mask = obj.Mask;
                end

                % 处理 Mask 层
                layers = labelBMask(obj.MasklayerFigure, original_mask, header_single, ...
                    obj.img, resultsDir,layernum);

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
                obj.handleError(ME);  % 正确的调用方式
                disp(getReport(ME));
            end
        end

        function calculateAndDisplayResults(obj, layers, stimVolume)
            try
                workDir = obj.Controls.WorkingDir.Value;
                resultsDir = fullfile(workDir, 'interactive_profile_results');
                % 确保 layernum 已定义
                layernum = str2double(obj.Controls.NumLayers.String);
                baselinePoints = str2double(obj.Controls.BaselinePoints.String);
                baselineIndex = 1:baselinePoints;
                epoch_length = str2double(obj.Controls.EpochLength.String);
                blocknum = str2double(obj.Controls.BlockNum.String);

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
                EPI = obj.img(:,:,:,601:end); % Remove the first 600 volumes
                percentage_epoch = calculate_individual_percentage(obj.InvidualFigure, ...
                    EPI, layernum, epoch_length, blocknum, baselinePoints,resultsDir, layers, [-0.005 0.03], stimVolume);
                
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
                calculate_mean_percentage(obj.MeanPercentageFigure, percentage_epoch,resultsDir, [-0.005 0.03], stimVolume,baselinePoints, epoch_length);
                
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
                calculate_layer_profile(obj.LayerProfileFigure, obj.img, layers, baselineIndex, epoch_length, blocknum, resultsDir);
                
                % 生成报告
                [pathstr, scan_name, ~] = fileparts(obj.Controls.FilePath1.Value);
                templatePath = fullfile(obj.code_dir, 'report', 'InteractiveProfile_template.html');
                datatype = 'InteractiveProfile';
                generate_HTML(obj, pathstr, scan_name, obj.QAenvName, templatePath, datatype, resultsDir);
                
            catch ME
                errordlg(['Error in displaying results: ' ME.message], 'Error');
                obj.handleError(ME);
                disp(getReport(ME));
            end
        end
        
        function generate_HTML(app,inputPath,subjectName,envName, templatePath,datatype,output_dir)
            % 根据 datatype 设置 generatePath
%             inputPath=pathstr;
%             subjectName=scan_name;
%             envName=app.QAenvName;
%             templatePath,datatype
            if strcmp(datatype, 'longTR')
                generatePath = fullfile(app.code_dir, 'report', 'generate_longTR_HTML.py');
            elseif strcmp(datatype, 'longTR_MION')
                generatePath = fullfile(app.code_dir, 'report', 'generate_longTR_MION_HTML.py');
            elseif strcmp(datatype, 'shortTR')
                generatePath = fullfile(app.code_dir, 'report', 'generate_shortTR_HTML.py');
            elseif strcmp(datatype, 'shortTR_MION')
                generatePath = fullfile(app.code_dir, 'report', 'generate_shortTR_MION_HTML.py');
            elseif strcmp(datatype, 'InteractiveProfile')
                generatePath = fullfile(app.code_dir, 'report', 'generate_InteractiveProfile_HTML.py'); 
            else
                error('Unsupported datatype: %s', datatype);
            end
            pythonCommand = ['conda activate ', envName, ' && python ',generatePath,' ', inputPath,' ', output_dir,' ', subjectName,' --template ', templatePath];
            system(pythonCommand);
        end

        function updateMask(obj, src)
            obj.Mask = createMask(src);
        end
        
        function updateBMask(obj, h1, h2, mask, rows, cols)
            try
                % 获取线条位置
                line1 = h1.Position;
                line2 = h2.Position;
                
                % 清除当前掩码
                mask(:) = 0;
                
                % 更新第一条线的掩码
                for i = 1:size(line1, 1)
                    y = round(line1(i, 1));
                    x = round(line1(i, 2));
                    if x > 0 && x <= rows && y > 0 && y <= cols
                        mask(x, y) = 1;
                    end
                end
                
                % 更新第二条线的掩码
                for i = 1:size(line2, 1)
                    y = round(line2(i, 1));
                    x = round(line2(i, 2));
                    if x > 0 && x <= rows && y > 0 && y <= cols
                        mask(x, y) = 2;
                    end
                end
                
                % 创建多边形区域
                polygon_points = [line1; flipud(line2)];
                mask_polygon = poly2mask(polygon_points(:,1), polygon_points(:,2), rows, cols);
                mask(mask_polygon & mask == 0) = 3;
                
                % 更新类的掩码属性
                obj.Mask = mask;
                
                % 可选：实时显示更新后的掩码
                if isfield(obj, 'MaskFigure') && isvalid(obj.MaskFigure)
                    figure(obj.MaskFigure);
                    imshow(obj.Mask);
                    title('Updated Mask');
                    drawnow;
                end
                
            catch ME
                warning('Error updating mask: %s', ME.message);
            end
        end
        % 添加错误处理方法
        function handleError(obj, ME)
            try
                % 构建错误信息
                errorMsg = getReport(ME, 'extended', 'hyperlinks', 'off');
                
                % 如果 ChatGPT 控件存在，更新它们
                if isfield(obj.Controls, 'ChatQuery') && isfield(obj.Controls, 'ChatResponse')
                    % 设置查询文本
                    obj.Controls.ChatQuery.Value = sprintf('I got this MATLAB error: %s. Can you help me understand and fix it?', ME.message);
                    
                    % 设置响应文本区域为等待状态
                    obj.Controls.ChatResponse.Value = 'Processing error...';
                    
                    % 自动触发 ChatGPT 查询
                    obj.askChatGPT();
                else
                    % 如果没有 ChatGPT 控件，显示标准错误对话框
                    errordlg(sprintf('Error: %s\n\nStack Trace:\n%s', ME.message, errorMsg), 'Error');
                end
                
            catch innerME
                % 如果错误处理本身出错，确保显示一些信息
                errordlg(['Error in error handler: ' innerME.message], 'Critical Error');
                fprintf('Critical error in error handler:\n%s\n', getReport(innerME));
            end
        end

        function askChatGPT(obj)
            try
                % 获取查询文本
                query = obj.Controls.ChatQuery.Value;
                
                % 如果查询文本为空，检查是否有错误信息需要处理
                if isempty(query) && isfield(obj.Controls, 'LastError')
                    query = sprintf('I got this MATLAB error: %s. Can you help me understand and fix it?', obj.Controls.LastError);
                end
                
                % 调用 ChatGPT API
                try
                    response = obj.ChatGPT.askGPT(query);
                    disp(response);  % Add this to see the structure of the response
                catch ME
                    disp(['Error querying ChatGPT: ' ME.message]);  % Display the error message
                    errordlg(['Error querying ChatGPT: ' ME.message], 'ChatGPT Error');
                end
                
                % 更新响应文本区域
                if isfield(obj.Controls, 'ChatResponse')
                    obj.Controls.ChatResponse.Value = response;
                end
                
            catch ME
                % 处理 ChatGPT 查询错误
                errorMsg = ['Error querying ChatGPT: ' ME.message];
                if isfield(obj.Controls, 'ChatResponse')
                    obj.Controls.ChatResponse.Value = ['Error: ' ME.message];
                end
                % 存储错误信息以供后续查询
                obj.Controls.LastError = ME.message;
                errordlg(errorMsg, 'ChatGPT Error');
            end
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
            labels = {'Layer fMRI File Path', 'Activation Map File Path'};
            for i = 1:2
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
                'Position', [10 140 300 22], ...
                'Value', '', ...
                'Placeholder', 'Ask about layer analysis...');
            
            uibutton(chatPanel, 'Text', 'Ask', ...
                'Position', [320 140 60 22], ...
                'ButtonPushedFcn', @(btn,event) obj.askChatGPT());
            
            obj.Controls.ChatResponse = uitextarea(chatPanel, ...
                'Position', [10 10 360 125], ...
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
        
        function drawFrame(obj)
            try
                % Load and prepare images
                [mean_img, activation_map] = obj.loadImages();
                
                % Create main figure and layout
                obj.createFrameFigure(mean_img, activation_map);
                
                % Process frame if isrotate is true
                % if obj.isrotate
                % obj.isrotate = true;
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
                obj.handleError(ME);  % 正确的调用方式
            end
        end
        % function drawBoundaries(obj)
        %     try
        %         % Load and prepare images
        %         [mean_img, activation_map] = obj.loadImages();
                
        %         % Create main figure and layout
        %         obj.createBoundaryFigure(mean_img, activation_map);
                
        %         obj.rotateImage(mean_img, activation_map);

        %         % Draw boundaries and process mask
        %         mask = zeros(size(obj.OriginalImage));
        %         [rows, cols] = size(obj.OriginalImage);
        %         [h1, h2] = obj.drawBoundaryLines();
                
        %         % Setup mask updates
        %         obj.setupMaskListeners(h1, h2, mask, rows, cols);
                
        %         % Process results if save button pressed
        %         obj.processBoundaryResults();
                
        %     catch ME
        %         uialert(obj.Figure, ['Error reading file: ', ME.message], 'Error');
        % obj.handleError(ME);  % 正确的调用方式
        %     end
        % end

        
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
            % 创建新的图形窗口用于边界绘制
            obj.UIFigure = figure('Name', 'Draw Boundaries', ...
                'NumberTitle', 'off', ...
                'Position', [100 100 1200 800], ...
                'WindowStyle', 'modal');
            
            % 创建基本的图像显示
            obj.createImagePanel(mean_img, activation_map);
            
            % 创建边界绘制的控制面板
            % obj.createBoundaryControlPanel();
            obj.createControlPanels();

        end

        function createImagePanel(obj, mean_img, activation_map)
            % 创建图像显示区域
            obj.Plots.ImageAxes = axes(obj.UIFigure, ...
                'Position', [0.05 0.1 0.7 0.8], ...
                'DataAspectRatio', [1 1 1]);
            
            % 处理激活图
            obj.Transparency = 1;

            % 创建叠加图像
            obj.updateOverlay(true);  % true表示这是初始化调用

            % 设置初始视图
            axis(obj.Plots.ImageAxes, 'image');  % 使用'image'而不是'equal'
            axis(obj.Plots.ImageAxes, 'off');
            title('Adjust image view');
        end

        % % 新增方法：更新叠加图像
        % function updateOverlay(obj)
        %     if isvalid(obj.Plots.ImageAxes)
        %         % 保存当前视图状态
        %         currentXLim = xlim(obj.Plots.ImageAxes);
        %         currentYLim = ylim(obj.Plots.ImageAxes);

        %         cla(obj.Plots.ImageAxes);  % 清除当前轴
        %         obj.OverlayImageHandle = imoverlay(obj.DisplayImage, obj.DisplayActivationMap, ...
        %             [1 0.8*max(obj.DisplayActivationMap(:))], ...
        %             [0.2*min(obj.DisplayImage(:)) 0.8*max(obj.DisplayImage(:))], ...
        %             "hot", obj.Transparency, obj.Plots.ImageAxes);

        %         % 恢复视图状态
        %         xlim(obj.Plots.ImageAxes, currentXLim);
        %         ylim(obj.Plots.ImageAxes, currentYLim);
        %     end
        % end

        % 更新叠加图像方法
        function updateOverlay(obj, isInitial)
            if ~isvalid(obj.Plots.ImageAxes)
                return;
            end
            
            %只在非初始化时保存视图状态
            % if nargin < 2 || ~isInitial
            currentXLim = xlim(obj.Plots.ImageAxes);
            currentYLim = ylim(obj.Plots.ImageAxes);
            % end
            
            % 清除当前轴并创建新的叠加图像
            cla(obj.Plots.ImageAxes);
            % 使用保存的对比度设置
            if isfield(obj.DisplaySettings, 'contrast_min') && isfield(obj.DisplaySettings, 'contrast_max')
                img_min = min(obj.DisplayImage(:));
                img_max = max(obj.DisplayImage(:));
                display_min = img_min + obj.DisplaySettings.contrast_min * (img_max - img_min);
                display_max = img_min + obj.DisplaySettings.contrast_max * (img_max - img_min);
                
                % 使用保存的对比度设置创建叠加图像
                obj.OverlayImageHandle = imoverlay(obj.DisplayImage, obj.DisplayActivationMap, ...
                    [1 0.8*max(obj.DisplayActivationMap(:))], ...
                    [display_min display_max], ...  % 使用计算的显示范围
                    "hot", obj.Transparency, obj.Plots.ImageAxes);
            else
                % 使用默认设置
                obj.OverlayImageHandle = imoverlay(obj.DisplayImage, obj.DisplayActivationMap, ...
                    [1 0.8*max(obj.DisplayActivationMap(:))], ...
                    [0.2*min(obj.DisplayImage(:)) 0.8*max(obj.DisplayImage(:))], ...
                    "hot", obj.Transparency, obj.Plots.ImageAxes);
            end

            % 设置适当的显示范围
            if nargin >= 2 && isInitial
                % 初始化时设置合适的显示范围
                axis(obj.Plots.ImageAxes, 'image');
            else
                % 恢复之前的视图状态
                xlim(obj.Plots.ImageAxes, currentXLim);
                ylim(obj.Plots.ImageAxes, currentYLim);
            end
            % 设置图像显示属性
            colormap(obj.Plots.ImageAxes, "hot");
            axis(obj.Plots.ImageAxes, 'off');
            % 强制更新显示
            % drawnow;
        end

        % 修改透明度更新方法
        function updateActivationTransparency(obj, src)
            try
                % 获取新的透明度值
                alpha = get(src, 'Value');
                obj.Transparency = alpha;  % 更新存储的透明度值
                
                % 更新编辑框的值
                if isfield(obj.Controls, 'TransparencyEdit')
                    obj.Controls.TransparencyEdit.String = num2str(alpha, '%.2f');
                end
                
                % 重新创建叠加图像
                obj.updateOverlay(false);
                
                % 强制刷新显示
                % drawnow;
            catch ME
                warning('Error updating transparency: %s', ME.message);
            end
        end

        % 从编辑框更新透明度的方法
        function updateTransparencyFromEdit(obj, src)
            try
                value = str2double(src.String);
                if ~isnan(value) && value >= 0 && value <= 1
                    % 更新滑块值
                    obj.Controls.ActivationSlider.Value = value;
                    obj.Transparency = value;  % 更新存储的透明度值
                    % 重新创建叠加图像
                    obj.updateOverlay(false);
                    % 强制刷新显示
                    % drawnow;
                else
                    src.String = num2str(obj.Controls.ActivationSlider.Value, '%.2f');
                end
            catch ME
                warning('Error updating transparency from edit: %s', ME.message);
                src.String = num2str(obj.Controls.ActivationSlider.Value, '%.2f');
            end
        end

        function createControlPanels(obj)
            % 创建右侧主面板
            rightPanel = uipanel(obj.UIFigure, ...
                'Position', [0.75 0.05 0.24 0.9]);
            
            % 创建上部图像调整面板
            imageControlPanel = uipanel(rightPanel, ...
                'Title', 'Image Controls', ...
                'Position', [0.05 0.6 0.9 0.35]);
            
            % 创建下部参数设置面板
            parameterPanel = uipanel(rightPanel, ...
                'Title', 'Analysis Parameters', ...
                'Position', [0.05 0.05 0.9 0.5]);
            
            % 添加图像控制元素
            obj.createImageControls(imageControlPanel);
            
            % 添加参数设置元素
            obj.createParameterControls(parameterPanel);
        end
        function createImageControls(obj, panel)
            % 按钮的基本尺寸和位置
            buttonWidth = 100;
            buttonHeight = 25;
            spacing = 10;
            startY = 200;
            
            % 创建控制按钮            
            uicontrol(panel, 'Style', 'pushbutton', ...
                'String', 'Rotate', ...
                'Position', [20 startY buttonWidth buttonHeight], ...
                'Callback', @(~,~) obj.rotateImage());

            uicontrol(panel, 'Style', 'pushbutton', ...
                'String', 'Adjust Mode', ...
                'Position', [20 startY-spacing-buttonHeight buttonWidth buttonHeight], ...
                'Callback', @(~,~) obj.enableAdjustMode());
            
            uicontrol(panel, 'Style', 'pushbutton', ...
                'String', 'Draw Lines', ...
                'Position', [20 startY-2*(spacing+buttonHeight) buttonWidth buttonHeight], ...
                'Callback', @(~,~) obj.enableDrawMode());
            
            uicontrol(panel, 'Style', 'pushbutton', ...
                'String', 'Generate Mask', ...
                'Position', [20 startY-3*(spacing+buttonHeight) buttonWidth buttonHeight], ...
                'Callback', @(~,~) obj.generateMask());
            
            % 添加透明度控制
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Transparency:', ...
                'Position', [20 startY-4*(spacing+buttonHeight) buttonWidth 15], ...
                'HorizontalAlignment', 'left');
            
            % 滑块控制
            obj.Controls.ActivationSlider = uicontrol(panel, 'Style', 'slider', ...
                'Min', 0, 'Max', 1, 'Value', 1, ...
                'Position', [20 startY-4*(spacing+buttonHeight)-20 buttonWidth 15], ...
                'Callback', @(src,~) obj.updateActivationTransparency(src));
            
            % 数值输入框
            obj.Controls.TransparencyEdit = uicontrol(panel, 'Style', 'edit', ...
                'String', '1.0', ...
                'Position', [20+buttonWidth+5 startY-4*(spacing+buttonHeight)-20 40 20], ...
                'Callback', @(src,~) obj.updateTransparencyFromEdit(src));
        end

        function createParameterControls(obj, panel)
            % 设置参数控制面板的布局参数
            params.padding = 10;
            params.elementHeight = 25;
            params.buttonWidth = 120;
            params.buttonHeight = 30;
            params.startY = 330;
            params.panelWidth = 200;
            
            % 添加层数控制
            obj.createLayersControl(panel, params);
            
            % 添加随机刺激控制
            obj.createRandomStimControl(panel, params);
            
            % 添加确认按钮
            obj.createBoundaryConfirmButton(panel, params);
        end

        function enableAdjustMode(obj)
            % 启用图像调整模式
            obj.IsDrawingMode = false;
            zoom(obj.Plots.ImageAxes, 'on');
            pan(obj.Plots.ImageAxes, 'on');
            title(obj.Plots.ImageAxes, 'Adjust image view');
            
        end
        
        function enableDrawMode(obj)
            % 禁用图像调整模式
            obj.IsDrawingMode = true;
            zoom(obj.Plots.ImageAxes, 'off');
            pan(obj.Plots.ImageAxes, 'off');
                
            % 创建掩码
            [rows, cols] = size(obj.DisplayImage);
            mask = zeros(rows, cols);

            % 绘制边界线
            title(obj.Plots.ImageAxes, 'Draw the first boundary');
            h1 = drawfreehand('Color', 'r', 'Closed', false, 'InteractionsAllowed', 'all');
            
            title(obj.Plots.ImageAxes, 'Draw the second boundary');
            h2 = drawfreehand('Color', 'r', 'Closed', false, 'InteractionsAllowed', 'all');
            
            % 设置监听器和更新掩码
            obj.setupMaskListeners(h1, h2, mask, rows, cols);
            % % 如果没有旋转，直接更新掩码
            % obj.updateBMask(h1, h2, mask, rows, cols);
        end
        
        % 添加监听器设置方法
        function setupMaskListeners(obj, h1, h2, mask, rows, cols)
            % 初始更新掩码
            obj.updateBMask(h1, h2, mask, rows, cols);
            
            % 添加移动监听器
            addlistener(h1, 'ROIMoved', @(src,evt) obj.updateBMask(h1, h2, mask, rows, cols));
            addlistener(h2, 'ROIMoved', @(src,evt) obj.updateBMask(h1, h2, mask, rows, cols));
            
            % 添加点移动监听器
            addlistener(h1, 'MovingROI', @(src,evt) obj.updateBMask(h1, h2, mask, rows, cols));
            addlistener(h2, 'MovingROI', @(src,evt) obj.updateBMask(h1, h2, mask, rows, cols));
            
            % 存储句柄以供后续使用
            obj.Boundaries.h1 = h1;
            obj.Boundaries.h2 = h2;
        end

        % 修改：显示掩码方法
        function showMask(obj)
            if isempty(obj.MaskFigure) || ~isvalid(obj.MaskFigure)
                obj.MaskFigure = figure('Name', 'Mask of the drawn region', ...
                    'NumberTitle', 'off', ...
                    'Position', [100, 100, 839, 580], ...
                    'WindowStyle', 'modal');
            else
                figure(obj.MaskFigure);
                clf;
            end
            
            % 创建新的坐标轴
            ax = axes('Parent', obj.MaskFigure);
            
            % 显示掩码
            imshow(obj.Mask, 'Parent', ax, 'InitialMagnification', 'fit');
            title('Mask of the drawn region');
            
            % 添加原始图像轮廓作为参考（可选）
            hold(ax, 'on');
            boundaries = bwboundaries(obj.Mask > 0);
            for k = 1:length(boundaries)
                boundary = boundaries{k};
                plot(ax, boundary(:,2), boundary(:,1), 'r-', 'LineWidth', 1);
            end
            hold(ax, 'off');
        end
        function generateMask(obj)
            % 确保使用原始数据生成掩码
            if ~isempty(obj.Mask)
                % 显示掩码时使用原始图像尺寸
                obj.showMask();
            else
                errordlg('Please draw boundaries first.', 'Error');
            end
        end

        function rotateImage(obj)
            if ~obj.IsDrawingMode
                % 更新旋转角度
                obj.CurrentRotation = mod(obj.CurrentRotation + 90, 360);
                
                % 直接从原始图像旋转，避免累积误差
                rotated_mean = imrotate(obj.OriginalImage, obj.CurrentRotation, 'bilinear');
                rotated_activation = imrotate(obj.ActivationMap, obj.CurrentRotation, 'bilinear');
                obj.Transparency = 1;
                % 更新显示
                cla(obj.Plots.ImageAxes);
                % 使用保存的对比度设置
                if isfield(obj.DisplaySettings, 'contrast_min') && isfield(obj.DisplaySettings, 'contrast_max')
                    img_min = min(rotated_mean(:));
                    img_max = max(rotated_mean(:));
                    display_min = img_min + obj.DisplaySettings.contrast_min * (img_max - img_min);
                    display_max = img_min + obj.DisplaySettings.contrast_max * (img_max - img_min);
                    
                    % 使用保存的对比度设置创建叠加图像
                    obj.OverlayImageHandle = imoverlay(rotated_mean, rotated_activation, ...
                        [1 0.8*max(rotated_activation(:))], ...
                        [display_min display_max], ...  % 使用计算的显示范围
                        "hot", obj.Transparency, obj.Plots.ImageAxes);
                else
                    % 使用默认设置
                    obj.OverlayImageHandle = imoverlay(rotated_mean, rotated_activation, ...
                        [1 0.8*max(rotated_activation(:))], ...
                        [0.2*min(rotated_mean(:)) 0.8*max(rotated_mean(:))], ...
                        "hot", obj.Transparency, obj.Plots.ImageAxes);
                end
                % 更新显示用的图像
                obj.DisplayImage = rotated_mean;
                obj.DisplayActivationMap = rotated_activation;
                
                % 设置图像显示属性
                colormap(obj.Plots.ImageAxes, "hot");
                axis(obj.Plots.ImageAxes, 'image');
                axis off;
                % 强制更新显示
                drawnow;
            end
        end

        function createLayersControl(obj, panel, p)
            % 层数控制
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Number of Layers:', ...
                'Position', [p.padding p.startY-1*p.elementHeight-p.padding 100 p.elementHeight], ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.NumLayers = uicontrol(panel, 'Style', 'edit', ...
                'Position', [p.padding+110 p.startY-1*p.elementHeight-p.padding 100 p.elementHeight], ...
                'String', '10');
            
            % 基线时间点控制
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Baseline Points:', ...
                'Position', [p.padding p.startY-2*p.elementHeight-p.padding 100 p.elementHeight], ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.BaselinePoints = uicontrol(panel, 'Style', 'edit', ...
                'Position', [p.padding+110 p.startY-2*p.elementHeight-p.padding 100 p.elementHeight], ...
                'String', '10', ...
                'Tooltip', 'Number of time points for baseline calculation');
            
            % Block长度控制
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Block Length:', ...
                'Position', [p.padding p.startY-3*p.elementHeight-p.padding 100 p.elementHeight], ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.EpochLength = uicontrol(panel, 'Style', 'edit', ...
                'Position', [p.padding+110 p.startY-3*p.elementHeight-p.padding 100 p.elementHeight], ...
                'String', '20', ...
                'Tooltip', 'Length of each block in time points');
            
            % Block数量控制
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Number of Blocks:', ...
                'Position', [p.padding p.startY-4*p.elementHeight-p.padding 100 p.elementHeight], ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.BlockNum = uicontrol(panel, 'Style', 'edit', ...
                'Position', [p.padding+110 p.startY-4*p.elementHeight-p.padding 100 p.elementHeight], ...
                'String', '11', ...
                'Tooltip', 'Total number of blocks');
        end

        function createRandomStimControl(obj, panel, p)
            % Random Stim dropdown
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Random Stim:', ...
                'Position', [p.padding p.startY-5*p.elementHeight-2*p.padding 100 p.elementHeight], ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.RandomStim = uicontrol(panel, 'Style', 'popupmenu', ...
                'String', {'no', 'yes'}, ...
                'Position', [p.padding+110 p.startY-5*p.elementHeight-2*p.padding 100 p.elementHeight], ...
                'Callback', @(src,~) obj.toggleRandomStimControl(panel, p));

            % Initial Stim Volume UI elements
            obj.createStimVolumeControl(panel, p);
        end

        function createStimVolumeControl(obj, panel, p)
            % Create initial stim volume controls with 'dynamicUI' tag
            uicontrol(panel, 'Style', 'text', ...
                'String', 'Stim Volume', ...
                'Position', [p.padding p.startY-6*p.elementHeight-2*p.padding 100 p.elementHeight], ...
                'Tag', 'dynamicUI', ...
                'HorizontalAlignment', 'left');
            
            obj.Controls.StimVolume = uicontrol(panel, 'Style', 'edit', ...
                'Position', [p.padding+110 p.startY-6*p.elementHeight-2*p.padding 100 p.elementHeight], ...
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
                    'Position', [p.padding p.startY-6*p.elementHeight-2*p.padding 150 p.elementHeight], ...
                    'Tag', 'dynamicUI', ...
                    'HorizontalAlignment', 'left');
                
                obj.Controls.RandomStimPath = uicontrol(panel, 'Style', 'edit', ...
                    'Position', [p.padding+110 p.startY-6*p.elementHeight-2*p.padding 100 p.elementHeight], ...
                    'Tag', 'dynamicUI', ...
                    'Enable', 'off');
                
                uicontrol(panel, 'Style', 'pushbutton', ...
                    'String', 'Choose Path', ...
                    'Position', [p.padding+220 p.startY-6*p.elementHeight-2*p.padding 80 p.elementHeight], ...
                    'Tag', 'dynamicUI', ...
                    'Callback', @(~,~) obj.setRandomStimFilePath());
                    
                % Add text area for stim volume statistics (moved to bottom)
                obj.Controls.StimStats = uicontrol(panel, 'Style', 'text', ...
                    'Position', [p.padding p.startY-8*p.elementHeight-5*p.padding 300 3*p.elementHeight], ...
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

        % function createBoundaryConfirmButton(obj, panel, p)
        %     uicontrol(panel, 'Style', 'pushbutton', ...
        %         'String', 'Confirm Modification', ...
        %         'Position', [(p.panelWidth-p.buttonWidth)/2 p.padding p.buttonWidth p.buttonHeight], ...
        %         'Callback', @(~,~) obj.processBoundaryResults());
        % end
        function createBoundaryConfirmButton(obj, panel, p)            
            % Confirm button
            uicontrol(panel, 'Style', 'pushbutton', ...
                'String', 'Confirm Modification', ...
                'Position', [(p.panelWidth-p.buttonWidth-60)/2 p.padding p.buttonWidth p.buttonHeight], ...
                'Callback', @(~,~) obj.processBoundaryResults());
            
            % Batch Code button
            uicontrol(panel, 'Style', 'pushbutton', ...
                'String', 'Create Batch Code', ...
                'Position', [(p.panelWidth+p.buttonWidth-60)/2 p.padding p.buttonWidth p.buttonHeight], ...
                'Callback', @(~,~) obj.createBatchCode());
        end

        function [h1, h2] = drawBoundaryLines(obj)
            title('Draw the first boundary');
            h1 = drawfreehand('Color', 'r', 'Closed', false, 'InteractionsAllowed', 'all');
            title('Draw the second boundary');
            h2 = drawfreehand('Color', 'r', 'Closed', false, 'InteractionsAllowed', 'all');
        end

        % function setupMaskListeners(obj, h1, h2, mask, rows, cols)
        %     obj.updateBMask(h1, h2, mask, rows, cols);
        %     addlistener(h1, 'ROIMoved', @(src,evt) obj.updateBMask(h1, h2, mask, rows, cols));
        %     addlistener(h2, 'ROIMoved', @(src,evt) obj.updateBMask(h1, h2, mask, rows, cols));
        %     wait(h1);
        %     wait(h2);
        % end

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
                obj.handleError(ME);  % 正确的调用方式
                disp(getReport(ME));
            end
        end
        
        % Add new method for batch code generation
        function createBatchCode(obj)
            try
                % Get current parameters
                params = struct();
                params.numLayers = str2double(obj.Controls.NumLayers.String);
                params.baselinePoints = str2double(obj.Controls.BaselinePoints.String);
                params.epochLength = str2double(obj.Controls.EpochLength.String);
                params.blockNum = str2double(obj.Controls.BlockNum.String);
                params.isRandomStim = strcmp(obj.Controls.RandomStim.String{obj.Controls.RandomStim.Value}, 'yes');
                
                if params.isRandomStim
                    params.stimFile = obj.Controls.RandomStimPath.String;
                    params.stimVolumes = obj.StimVolumes;
                else
                    params.stimVolume = str2double(obj.Controls.StimVolume.String);
                end
                
                % Generate single subject code
                singleCode = obj.generateSingleSubjectCode(params);
                
                % Generate batch processing code
                batchCode = obj.generateBatchCode(params);
                
                % Save to files
                [filename, pathname] = uiputfile({'*.m', 'MATLAB Script (*.m)'}, 'Save Batch Scripts');
                if filename ~= 0
                    % Create file paths
                    [~, name, ext] = fileparts(filename);
                    singlePath = fullfile(pathname, filename);
                    batchPath = fullfile(pathname, [name '_batch' ext]);
                    
                    % Write files
                    fid = fopen(singlePath, 'w');
                    fprintf(fid, '%s', singleCode);
                    fclose(fid);
                    
                    fid = fopen(batchPath, 'w');
                    fprintf(fid, '%s', batchCode);
                    fclose(fid);
                    
                    % Show success message
                    msg = sprintf(['Batch codes saved to:\n\n' ...
                        'Single subject: %s\n' ...
                        'Batch processing: %s'], singlePath, batchPath);
                    uialert(obj.Figure, msg, 'Success', 'Icon', 'success');

                    % msgbox('Batch codes saved successfully!', 'Success');
                end
                
            catch ME
                errordlg(['Error creating batch code: ' ME.message], 'Error');
                obj.handleError(ME);
            end
        end

        function code = generateSingleSubjectCode(obj, params)
            % Determine stim volume code block based on random stim setting
            if params.isRandomStim
                stimCode = sprintf(['    %% Load random stim file\n' ...
                    '    stimInfo = readtable(''%s'');\n' ...
                    '    stimVolumes = calculateStimVolumes(stimInfo);\n' ...
                    '    stimVolume = stimVolumes;\n\n'], params.stimFile);
            else
                stimCode = sprintf('    stimVolume = %d;\n\n', params.stimVolume);
            end
        
            % Generate complete code
            code = sprintf(['%% Interactive Profile Analysis - Single Subject\n' ...
                '%% Generated on %s\n\n' ...
                'function runInteractiveProfile()\n' ...
                '    %% Parameters\n' ...
                '    numLayers = %d;\n' ...
                '    baselinePoints = %d;\n' ...
                '    epochLength = %d;\n' ...
                '    blockNum = %d;\n\n' ...
                '    %% Load data\n' ...
                '    filePath = ''%s'';\n' ...
                '    header = spm_vol(filePath);\n' ...
                '    img = spm_read_vols(header);\n\n' ...
                '    %% Create mask from rim file\n' ...
                '    rimPath = ''path/to/rim.nii'';  %% User should specify their rim.nii file\n' ...
                '    mask = createMaskFromRim(rimPath);\n\n' ...
                '    %% Create output directory\n' ...
                '    outputDir = fullfile(fileparts(filePath), ''interactive_profile_results'');\n' ...
                '    if ~exist(outputDir, ''dir'')\n' ...
                '        mkdir(outputDir);\n' ...
                '    end\n\n' ...
                '    %% Process layers\n' ...
                '    layers = labelMask(figure(), mask, header(1), img, outputDir, numLayers);\n\n' ...
                '%s' ... % Insert stim code here
                '    %% Calculate individual percentage changes\n' ...
                '    EPI = img(:,:,:,601:end); %% Remove first 600 volumes\n' ...
                '    percentage_epoch = calculate_individual_percentage(figure(), ...\n' ...
                '        EPI, numLayers, epochLength, blockNum, baselinePoints, ...\n' ...
                '        outputDir, layers, [-0.005 0.03], stimVolume);\n\n' ...
                '    %% Calculate mean percentage\n' ...
                '    calculate_mean_percentage(figure(), percentage_epoch, outputDir, ...\n' ...
                '        [-0.005 0.03], stimVolume, baselinePoints, epochLength);\n\n' ...
                '    %% Calculate layer profile\n' ...
                '    baselineIndex = 1:baselinePoints;\n' ...
                '    calculate_layer_profile(figure(), img, layers, baselineIndex, ...\n' ...
                '        epochLength, blockNum, outputDir);\n\n' ...
                '    %% Generate report\n' ...
                '    [pathstr, scan_name, ~] = fileparts(filePath);\n' ...
                '    templatePath = fullfile(''%s'', ''report'', ''InteractiveProfile_template.html'');\n' ...
                '    generate_HTML(pathstr, scan_name, ''%s'', templatePath, ''InteractiveProfile'', outputDir);\n' ...
                'end\n\n' ...
                '%% Helper Functions\n' ...
                'function mask = createMaskFromRim(rimPath)\n' ...
                '    %% Load rim file and create mask\n' ...
                '    rim = spm_read_vols(spm_vol(rimPath));\n' ...
                '    mask = rim > 0;\n' ...
                'end\n\n' ...
                'function stimVolumes = calculateStimVolumes(stimInfo)\n' ...
                '    %% Calculate stim volumes from duration\n' ...
                '    if iscell(stimInfo.Duration_ms_)\n' ...
                '        stimDurationMs = cellfun(@str2double, stimInfo.Duration_ms_);\n' ...
                '    elseif isstring(stimInfo.Duration_ms_)\n' ...
                '        stimDurationMs = str2double(stimInfo.Duration_ms_);\n' ...
                '    else\n' ...
                '        stimDurationMs = stimInfo.Duration_ms_;\n' ...
                '    end\n' ...
                '    TR = 0.2; %% TR in seconds\n' ...
                '    stimDurationS = stimDurationMs / 1000;\n' ...
                '    stimVolumes = unique(stimDurationS / TR);\n' ...
                'end'], ...
                datestr(now), params.numLayers, params.baselinePoints, ...
                params.epochLength, params.blockNum, obj.Controls.FilePath1.Value, ...
                stimCode, obj.code_dir, obj.QAenvName);
        end
        
        function code = generateBatchCode(obj, params)
            % Generate batch processing code
            code = sprintf(['%% Interactive Profile Analysis - Batch Processing\n' ...
                '%% Generated on %s\n\n' ...
                'function processBatch()\n' ...
                '    %% Default parameters\n' ...
                '    params = struct();\n' ...
                '    params.numLayers = %d;\n' ...
                '    params.baselinePoints = %d;\n' ...
                '    params.epochLength = %d;\n' ...
                '    params.blockNum = %d;\n\n' ...
                '    %% Subject list - Edit this section for your subjects\n' ...
                '    subjectList = {\n' ...
                '        struct(''name'', ''Subject1'', ...\n' ...
                '               ''filePath'', ''%s'', ...\n' ...
                '               ''rimPath'', ''path/to/rim1.nii'', ...\n' ...
                '               ''outputDir'', ''path/to/output1''),\n' ...
                '        %% Add more subjects as needed\n' ...
                '    };\n\n' ...
                '    %% Process each subject\n' ...
                '    for i = 1:length(subjectList)\n' ...
                '        try\n' ...
                '            subject = subjectList{i};\n' ...
                '            processSubject(subject, params);\n' ...
                '        catch ME\n' ...
                '            warning(''Error processing subject %%s: %%s'', subject.name, ME.message);\n' ...
                '        end\n' ...
                '    end\n' ...
                'end\n\n' ...
                'function processSubject(subject, params)\n' ...
                '    fprintf(''Processing subject: %%s\\n'', subject.name);\n\n' ...
                '    %% Create output directory\n' ...
                '    if ~exist(subject.outputDir, ''dir'')\n' ...
                '        mkdir(subject.outputDir);\n' ...
                '    end\n\n' ...
                '    %% Load data\n' ...
                '    header = spm_vol(subject.filePath);\n' ...
                '    img = spm_read_vols(header);\n' ...
                '    mask = createMaskFromRim(subject.rimPath);\n\n' ...
                '    %% Process layers\n' ...
                '    layers = labelMask(figure(), mask, header(1), img, subject.outputDir, params.numLayers);\n\n'], ...
                datestr(now), params.numLayers, params.baselinePoints, ...
                params.epochLength, params.blockNum, obj.Controls.FilePath1.Value);
        
            % Add stim volume handling
            if params.isRandomStim
                code = [code sprintf(['    %% Load random stim file\n' ...
                    '    stimInfo = readtable(''%s'');\n' ...
                    '    stimVolumes = calculateStimVolumes(stimInfo);\n' ...
                    '    stimVolume = stimVolumes; %% Use all unique stim volumes\n\n'], ...
                    params.stimFile)];
            else
                code = [code sprintf('    stimVolume = %d;\n\n', params.stimVolume)];
            end
        
            % Add analysis calculations
            code = [code sprintf(['    %% Calculate individual percentage changes\n' ...
                '    EPI = img(:,:,:,601:end); %% Remove first 600 volumes\n' ...
                '    percentage_epoch = calculate_individual_percentage(figure(), ...\n' ...
                '        EPI, params.numLayers, params.epochLength, params.blockNum, ...\n' ...
                '        params.baselinePoints, subject.outputDir, layers, [-0.005 0.03], stimVolume);\n\n' ...
                '    %% Calculate mean percentage\n' ...
                '    calculate_mean_percentage(figure(), percentage_epoch, subject.outputDir, ...\n' ...
                '        [-0.005 0.03], stimVolume, params.baselinePoints, params.epochLength);\n\n' ...
                '    %% Calculate layer profile\n' ...
                '    baselineIndex = 1:params.baselinePoints;\n' ...
                '    calculate_layer_profile(figure(), img, layers, baselineIndex, ...\n' ...
                '        params.epochLength, params.blockNum, subject.outputDir);\n\n' ...
                '    %% Generate report\n' ...
                '    [pathstr, scan_name, ~] = fileparts(subject.filePath);\n' ...
                '    templatePath = fullfile(''%s'', ''report'', ''InteractiveProfile_template.html'');\n' ...
                '    generate_HTML(pathstr, scan_name, ''%s'', templatePath, ''InteractiveProfile'', subject.outputDir);\n' ...
                '    \n    %% Close all figures\n' ...
                '    close all;\n' ...
                'end\n\n' ...
                '%% Helper Functions\n' ...
                'function mask = createMaskFromRim(rimPath)\n' ...
                '    %% Load rim file and create mask\n' ...
                '    rim = spm_read_vols(spm_vol(rimPath));\n' ...
                '    mask = rim > 0;\n' ...
                'end\n\n' ...
                'function stimVolumes = calculateStimVolumes(stimInfo)\n' ...
                '    %% Calculate stim volumes from duration\n' ...
                '    if iscell(stimInfo.Duration_ms_)\n' ...
                '        stimDurationMs = cellfun(@str2double, stimInfo.Duration_ms_);\n' ...
                '    elseif isstring(stimInfo.Duration_ms_)\n' ...
                '        stimDurationMs = str2double(stimInfo.Duration_ms_);\n' ...
                '    else\n' ...
                '        stimDurationMs = stimInfo.Duration_ms_;\n' ...
                '    end\n' ...
                '    TR = 0.2; %% TR in seconds\n' ...
                '    stimDurationS = stimDurationMs / 1000;\n' ...
                '    stimVolumes = unique(stimDurationS / TR);\n' ...
                'end\n\n' ...
                '%% Example usage:\n' ...
                '%% Edit subjectList with your subject information and run processBatch()\n'], ...
                obj.code_dir, obj.QAenvName)];
        
        end

        % % 修改错误处理函数，将错误信息发送到 ChatGPT
        % function handleError(obj, ME)
        %     % 构建错误信息
        %     errorMsg = getReport(ME, 'extended', 'hyperlinks', 'off');
            
        %     % 存储错误信息
        %     obj.Controls.LastError = errorMsg;
            
        %     % 自动将错误发送到 ChatGPT
        %     if isfield(obj.Controls, 'ChatQuery')
        %         obj.Controls.ChatQuery.Value = sprintf('I got this MATLAB error: %s. Can you help me understand and fix it?', errorMsg);
        %     end
        %     if isfield(obj.Controls, 'ChatResponse')
        %         obj.Controls.ChatResponse.Value = 'Processing error...';
        %     end
            
        %     % 调用 askChatGPT
        %     obj.askChatGPT();
        % end



    end
end
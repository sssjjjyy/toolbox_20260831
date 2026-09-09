classdef LayerfMRIToolbox < matlab.apps.AppBase
    properties (Access = private)
        % Main UI components
        MainFigure          matlab.ui.Figure
        
        % UI Panels for Dual-Mode Routing (新增的路由面板)
        SelectionPanel      matlab.ui.container.Panel
        ManualPanel         matlab.ui.container.Panel
        AIPanel             matlab.ui.container.Panel
        
        % Module Buttons
        ModuleButtons       struct = struct()
        
        % AI Components (AI 终端与输入组件)
        ChatHistoryArea       matlab.ui.control.TextArea
        PromptEditField       matlab.ui.control.TextArea
        SubmitPromptBtn       matlab.ui.control.Button
        AIWorkingDirField     matlab.ui.control.EditField
        BrowseAIWorkingDirBtn matlab.ui.control.Button
        RefreshAIContextBtn   matlab.ui.control.Button
        AIContextStatusLabel  matlab.ui.control.Label
        AIContext             struct = struct()
        
        % Model profile selection (first-level UI)
        ModelDropdown         matlab.ui.control.DropDown
        ModelStatusLabel      matlab.ui.control.Label
        SelectedModelID       char = 'deepseek'
        
        % Module managers
        ImmediateAnalysis  modules.ImmediateAnalysisModule
        InteractiveProfile modules.InteractiveProfileModule
        ProcessPipeline    modules.ProcessPipelineModule
        BrainViewer        modules.BrainViewerModule
        
    end
    
    properties (Access = public)
        % 这些属性需要在其他模块中访问，所以设为public
        d2n_dir         % utils目录路径
        code_dir
        QAenvName      % 环境名称
        WorkingDirPath % 工作目录
        ChatGPTHelper  % ChatGPT接口
    end

    methods (Access = private)
        function createMainInterface(app)
            % Create main figure with larger size
            app.MainFigure = uifigure('Name', 'AI-assist fMRI Toolbox', ...
                'Position', [100 100 800 600], ...
                'Color', [0.98 0.98 0.98]);
            
            % Add title panel (全局共享的顶部标题)
            titlePanel = uipanel(app.MainFigure, ...
                'Position', [0 500 800 100], ...
                'BackgroundColor', [0.2 0.3 0.7], ...
                'ForegroundColor', 'white');
            
            uilabel(titlePanel, ...
                'Text', 'AI-assist fMRI Toolbox', ...
                'Position', [20 20 760 60], ...
                'FontSize', 28, ...
                'FontWeight', 'bold', ...
                'FontColor', 'white', ...
                'HorizontalAlignment', 'center');
                
            % =========================================================
            % 1. Selection Panel (主选择界面)
            % =========================================================
            app.SelectionPanel = uipanel(app.MainFigure, ...
                'Position', [0 0 800 500], ...
                'BackgroundColor', [0.98 0.98 0.98], ...
                'BorderType', 'none');
                
            % 手动模式大按钮
            uibutton(app.SelectionPanel, 'push', ...
                'Text', 'Manual Pipeline', ...
                'Position', [150 220 220 100], ...
                'FontSize', 18, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.3 0.4 0.8], 'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.switchMode('Manual'));
                
            % 智能助手大按钮
            uibutton(app.SelectionPanel, 'push', ...
                'Text', 'AI Copilot', ...
                'Position', [430 220 220 100], ...
                'FontSize', 18, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.1 0.6 0.3], 'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.switchMode('AI'));

            % 模型选择（DeepSeek / GPT ...）
            uilabel(app.SelectionPanel, ...
                'Text', 'AI Model:', ...
                'Position', [140 60 90 26], ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'right');
            profileIds = utils.ModelProfile.ids();
            profileNames = utils.ModelProfile.displays();
            defaultIndex = find(strcmp(profileIds, app.SelectedModelID), 1);
            if isempty(defaultIndex)
                defaultIndex = 1;
                app.SelectedModelID = profileIds{1};
            end
            app.ModelDropdown = uidropdown(app.SelectionPanel, ...
                'Items', profileNames, ...
                'Value', profileNames{defaultIndex}, ...
                'Position', [245 60 260 28], ...
                'ValueChangedFcn', @(~,~) app.modelSelectionChanged());
            app.ModelStatusLabel = uilabel(app.SelectionPanel, ...
                'Text', '', ...
                'Position', [520 60 250 26], ...
                'FontSize', 11, ...
                'FontColor', [0.25 0.45 0.25]);
            app.refreshModelStatus();

            % =========================================================
            % 2. Manual Panel (传统手动模式界面 - 双列布局)
            % =========================================================
            app.ManualPanel = uipanel(app.MainFigure, ...
                'Position', [0 0 800 500], ...
                'BackgroundColor', [0.98 0.98 0.98], ...
                'BorderType', 'none', ...
                'Visible', 'off'); % 默认隐藏
                
            % 返回主菜单按钮
            uibutton(app.ManualPanel, 'push', ...
                'Text', '← Back', ...
                'Position', [20 450 120 30], ...
                'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) app.switchMode('Selection'));
            
            % 将 7 个模块分配到左右两列
            buttonConfigs = {
                % 第一列 (左侧)
                'ImmediateAnalysis',  'fMRI Immediate Analysis',   [70 350 300 70];
                'InteractiveProfile', 'Interactive Layer Profile', [70 250 300 70];
                'ProcessPipeline',    'Process Pipeline',          [70 150 300 70];
                'BrainViewer',        'Brain Viewer',              [70 50  300 70];
                % 第二列 (右侧)
                'HumanAnalysis',      'Human fMRI Analysis',       [430 350 300 70];
                'TaskAnalysis',       'Task fMRI Analysis',        [430 250 300 70];
                'RsAnalysis',         'Rs-fMRI Analysis',          [430 150 300 70]
            };
            
            for i = 1:size(buttonConfigs, 1)
                app.ModuleButtons.(buttonConfigs{i,1}) = uibutton(app.ManualPanel, ...
                    'Text', buttonConfigs{i,2}, ...
                    'Position', buttonConfigs{i,3}, ...
                    'ButtonPushedFcn', @(btn,event) app.moduleButtonPushed(buttonConfigs{i,1}), ...
                    'BackgroundColor', [0.2 0.3 0.7], ...
                    'FontColor', 'white', ...
                    'FontSize', 16, ...
                    'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center');
            end

            % =========================================================
            % 3. AI Panel (智能助手终端界面)
            % =========================================================
            app.AIPanel = uipanel(app.MainFigure, ...
                'Position', [0 0 800 500], ...
                'BackgroundColor', [0.98 0.98 0.98], ...
                'BorderType', 'none', ...
                'Visible', 'off'); % 默认隐藏
                
            % 返回主菜单按钮
            uibutton(app.AIPanel, 'push', ...
                'Text', '← Back', ...
                'Position', [20 455 100 30], ...
                'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) app.switchMode('Selection'));

            app.AIWorkingDirField = uieditfield(app.AIPanel, 'text', ...
                'Position', [130 455 425 30], ...
                'Placeholder', 'Select an AI working directory', ...
                'ValueChangedFcn', @(~,~) app.aiWorkingDirectoryChanged());

            app.BrowseAIWorkingDirBtn = uibutton(app.AIPanel, 'push', ...
                'Text', 'Browse', ...
                'Position', [565 455 85 30], ...
                'ButtonPushedFcn', @(~,~) app.selectAIWorkingDirectory());

            app.RefreshAIContextBtn = uibutton(app.AIPanel, 'push', ...
                'Text', 'Refresh', ...
                'Position', [660 455 90 30], ...
                'ButtonPushedFcn', @(~,~) app.refreshAIContext());

            app.AIContextStatusLabel = uilabel(app.AIPanel, ...
                'Text', 'Context: no working directory selected', ...
                'Position', [50 428 700 20], ...
                'FontColor', [0.35 0.35 0.35]);

            app.ChatHistoryArea = uitextarea(app.AIPanel, ...
                'Position', [50 145 700 275], ...
                'Editable', 'off', ...
                'BackgroundColor', [0.05 0.05 0.05], ...
                'FontColor', [0.2 0.9 0.2], ...
                'FontName', 'Courier New', ...
                'FontSize', 14);
            if isempty(app.ChatGPTHelper)
                app.ChatHistoryArea.Value = {'[System] AI Copilot unavailable.', '[System] 请检查Python和AI环境配置。'};
            else
                modelName = getenv('OPENAI_MODEL');
                if isempty(modelName)
                    app.ChatHistoryArea.Value = {'[System] AI Copilot initialized.', '[System] 正在等待您的指令...'};
                else
                    app.ChatHistoryArea.Value = {sprintf('[System] AI Copilot initialized (model: %s).', modelName), ...
                        '[System] 正在等待您的指令...'};
                end
            end
            
            % 用户 Prompt 输入框
            app.PromptEditField = uitextarea(app.AIPanel, ...
                'Position', [50 45 580 80], ...
                'FontSize', 14, ...
                'Placeholder', '请输入您的需求，例如：帮我把文件夹里的数据做一下头动校正...');
                
            % 发送按钮
            app.SubmitPromptBtn = uibutton(app.AIPanel, 'push', ...
                'Text', 'Send', ...
                'Position', [650 45 100 80], ...
                'FontSize', 16, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.1 0.6 0.3], 'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.sendAIPrompt());

            % =========================================================
            % 全局底部版本号
            % =========================================================
            uilabel(app.MainFigure, ...
                'Text', 'Version 1.1.0 (Dual-Mode Edition)', ...
                'Position', [10 10 780 20], ...
                'FontSize', 10, ...
                'FontColor', [0.5 0.5 0.5], ...
                'HorizontalAlignment', 'center');
        end
        
        % 面板路由函数
        function switchMode(app, mode)
            % 先隐藏所有面板
            app.SelectionPanel.Visible = 'off';
            app.ManualPanel.Visible = 'off';
            app.AIPanel.Visible = 'off';
            
            % 根据用户选择显示对应面板
            switch mode
                case 'Selection'
                    app.SelectionPanel.Visible = 'on';
                case 'Manual'
                    app.ManualPanel.Visible = 'on';
                case 'AI'
                    app.AIPanel.Visible = 'on';
                    % 聚焦到输入框
                    focus(app.PromptEditField);
            end
        end

        function selectAIWorkingDirectory(app)
            startPath = app.WorkingDirPath;
            if isempty(startPath) || ~isfolder(startPath)
                startPath = pwd;
            end
            selectedPath = uigetdir(startPath, 'Select AI working directory');
            if isequal(selectedPath, 0)
                return;
            end
            app.AIWorkingDirField.Value = selectedPath;
            app.WorkingDirPath = selectedPath;
            app.AIContext = struct();
            app.refreshAIContext();
        end

        function aiWorkingDirectoryChanged(app)
            selectedPath = strtrim(app.AIWorkingDirField.Value);
            app.WorkingDirPath = selectedPath;
            app.AIContext = struct();
            if isempty(selectedPath)
                app.AIContextStatusLabel.Text = 'Context: no working directory selected';
            elseif isfolder(selectedPath)
                app.AIContextStatusLabel.Text = 'Context: directory selected; click Refresh';
            else
                app.AIContextStatusLabel.Text = 'Context: directory does not exist';
            end
        end

        function refreshAIContext(app)
            selectedPath = strtrim(app.AIWorkingDirField.Value);
            if isempty(selectedPath) || ~isfolder(selectedPath)
                app.AIContext = struct();
                app.AIContextStatusLabel.Text = 'Context: select an existing directory';
                uialert(app.MainFigure, '请选择一个存在的工作目录。', 'Invalid Working Directory');
                return;
            end

            app.BrowseAIWorkingDirBtn.Enable = 'off';
            app.RefreshAIContextBtn.Enable = 'off';
            app.AIContextStatusLabel.Text = 'Context: scanning metadata...';
            drawnow;

            try
                [app.AIContext, summary] = utils.AIContextBuilder.build(selectedPath);
                app.WorkingDirPath = selectedPath;
                app.AIContextStatusLabel.Text = ['Context: ', summary];
                history = app.ChatHistoryArea.Value;
                app.ChatHistoryArea.Value = [history; {''}; {['[Context] ', summary]}];
                scroll(app.ChatHistoryArea, 'bottom');
            catch ME
                app.AIContext = struct();
                app.AIContextStatusLabel.Text = ['Context error: ', ME.message];
                uialert(app.MainFigure, ME.message, 'Context Scan Failed');
            end

            app.BrowseAIWorkingDirBtn.Enable = 'on';
            app.RefreshAIContextBtn.Enable = 'on';
        end
        
        function sendAIPrompt(app)
            inputValue = app.PromptEditField.Value;
            if ischar(inputValue) || isstring(inputValue)
                prompt = strtrim(strjoin(string(inputValue), newline));
            elseif iscell(inputValue)
                prompt = strtrim(strjoin(string(inputValue), newline));
            else
                prompt = "";
            end

            if strlength(prompt) == 0
                return;
            end

            profileStatus = utils.ModelProfile.apply(app.SelectedModelID);
            if ~profileStatus.configured
                currentHistory = app.ChatHistoryArea.Value;
                app.ChatHistoryArea.Value = [currentHistory; {''}; {['[System] ', profileStatus.message]}];
                scroll(app.ChatHistoryArea, 'bottom');
                return;
            end

            hasWorkDir = ~isempty(app.WorkingDirPath) && isfolder(app.WorkingDirPath);
            if hasWorkDir && isempty(fieldnames(app.AIContext))
                app.refreshAIContext();
            end

            currentHistory = app.ChatHistoryArea.Value;
            userMessage = ['> User: ', char(replace(prompt, newline, ' '))];
            app.ChatHistoryArea.Value = [currentHistory; {''}; {userMessage}; {'[System] AI 正在思考中...'}];
            app.PromptEditField.Value = '';
            app.SubmitPromptBtn.Enable = 'off';
            app.RefreshAIContextBtn.Enable = 'off';
            app.BrowseAIWorkingDirBtn.Enable = 'off';
            scroll(app.ChatHistoryArea, 'bottom');
            drawnow;

            try
                if isempty(app.ChatGPTHelper)
                    error('LayerfMRIToolbox:AIUnavailable', 'AI接口未初始化，请检查Python与环境变量配置。');
                end

                if ~hasWorkDir
                    response = app.ChatGPTHelper.askGPT(prompt, '', struct());
                    app.appendTerminal([{''; '[AI Copilot]'}; cellstr(splitlines(string(response)))]);
                else
                    tools = utils.ToolboxSkillRegistry.toolSchema();
                    result = app.ChatGPTHelper.requestPlan(prompt, app.AIContext, tools);
                    app.handleAgentResult(result);
                end
            catch ME
                currentHistory = app.ChatHistoryArea.Value;
                currentHistory(end) = [];
                app.ChatHistoryArea.Value = [currentHistory; {['[Error] ', ME.message]}];
            end

            app.SubmitPromptBtn.Enable = 'on';
            app.RefreshAIContextBtn.Enable = 'on';
            app.BrowseAIWorkingDirBtn.Enable = 'on';
            scroll(app.ChatHistoryArea, 'bottom');
        end

        function handleAgentResult(app, result)
            if ~strcmp(result.type, 'tool_plan')
                app.appendTerminal([{''; '[AI Copilot]'}; cellstr(splitlines(string(result.content)))]);
                return;
            end

            lines = {''; '[Plan] AI generated a structured plan.'};
            if ~isempty(result.summary)
                lines = [lines; {['[Plan] Summary: ', char(string(result.summary))]}];
            end
            stepTexts = cell(numel(result.steps), 1);
            for index = 1:numel(result.steps)
                step = result.steps(index);
                detail = '';
                if isstruct(step.arguments) && ~isempty(fieldnames(step.arguments))
                    names = fieldnames(step.arguments);
                    pairs = cell(numel(names), 1);
                    for pairIndex = 1:numel(names)
                        value = step.arguments.(names{pairIndex});
                        if ischar(value) || isstring(value)
                            text = char(string(value));
                        elseif isnumeric(value)
                            text = mat2str(double(value));
                        else
                            text = class(value);
                        end
                        pairs{pairIndex} = [names{pairIndex}, '=', text];
                    end
                    detail = [' (', strjoin(pairs, ', '), ')'];
                end
                if ~isempty(step.reason)
                    stepTexts{index} = sprintf('[Plan] %d. %s%s -- %s', index, step.tool, detail, char(string(step.reason)));
                else
                    stepTexts{index} = sprintf('[Plan] %d. %s%s', index, step.tool, detail);
                end
            end
            lines = [lines; stepTexts];
            app.appendTerminal(lines);

            validation = utils.AIPlanValidator.validatePlan(result, app.WorkingDirPath);
            if ~validation.ok
                blocked = cell(numel(validation.issues) + 2, 1);
                blocked{1} = '';
                blocked{2} = '[Validate] Plan rejected; nothing was executed.';
                for issueIndex = 1:numel(validation.issues)
                    blocked{issueIndex + 2} = ['[Blocked] ', validation.issues{issueIndex}];
                end
                app.appendTerminal(blocked);
                return;
            end

            app.appendTerminal({''; '[Validate] Plan passed the whitelist checks.'});
            utils.AIPlanExecutor.executePlan(result, app.WorkingDirPath, ...
                @(~, text) app.appendTerminal({text}));
        end

        function appendTerminal(app, lines)
            if ischar(lines) || isstring(lines)
                lines = cellstr(lines);
            end
            if ~iscell(lines)
                return;
            end
            currentHistory = app.ChatHistoryArea.Value;
            app.ChatHistoryArea.Value = [currentHistory; lines(:)];
            scroll(app.ChatHistoryArea, 'bottom');
            drawnow;
        end

        function modelSelectionChanged(app)
            if isempty(app.ModelDropdown)
                return;
            end
            ids = utils.ModelProfile.ids();
            index = find(strcmp(app.ModelDropdown.Items, app.ModelDropdown.Value), 1);
            if isempty(index) || index > numel(ids)
                return;
            end
            app.SelectedModelID = char(string(ids{index}));
            app.refreshModelStatus();
        end

        function refreshModelStatus(app)
            if isempty(app.SelectedModelID)
                app.SelectedModelID = 'deepseek';
            end
            try
                status = utils.ModelProfile.apply(app.SelectedModelID);
                if ~isempty(app.ModelStatusLabel)
                    if status.configured
                        app.ModelStatusLabel.Text = [status.display, '  |  key OK (', status.key_source, ')'];
                        app.ModelStatusLabel.FontColor = [0.25 0.45 0.25];
                    else
                        app.ModelStatusLabel.Text = [status.display, '  |  key NOT set (', status.key_env, ')'];
                        app.ModelStatusLabel.FontColor = [0.8 0.3 0.2];
                    end
                end
            catch ME
                if ~isempty(app.ModelStatusLabel)
                    app.ModelStatusLabel.Text = ['Model profile error: ', ME.message];
                    app.ModelStatusLabel.FontColor = [0.8 0.3 0.2];
                end
            end
        end
        
        function moduleButtonPushed(app, moduleName)
            switch moduleName
                case 'ImmediateAnalysis'
                    app.ImmediateAnalysis.show();
                case 'InteractiveProfile'
                    app.InteractiveProfile.show();
                case 'ProcessPipeline'
                    app.ProcessPipeline.show();
                case 'BrainViewer'
                    app.BrainViewer.show();
                    
                % 新增模块的占位保护逻辑
                case 'HumanAnalysis'
                    uialert(app.MainFigure, 'Human fMRI Analysis 模块正在开发中...', 'Coming Soon');
                case 'TaskAnalysis'
                    uialert(app.MainFigure, 'Task fMRI Analysis 模块正在开发中...', 'Coming Soon');
                case 'RsAnalysis'
                    uialert(app.MainFigure, 'Rs-fMRI Analysis 模块正在开发中...', 'Coming Soon');
            end
        end
    end
    
    methods (Access = public)
        function app = LayerfMRIToolbox
            % Initialize paths and environment
            app.code_dir = fileparts(mfilename('fullpath'));
            app.d2n_dir = fullfile(fileparts(mfilename('fullpath')), 'utils');
            app.QAenvName = 'layerfmri';
            app.WorkingDirPath = '';

            % Initialize ChatGPT interface
            app.ModuleButtons = struct();
            
            % Initialize ChatGPT helper
            try
                app.ChatGPTHelper = utils.ChatGPTInterface();
                if isempty(app.ChatGPTHelper)
                    warning('ChatGPT helper initialization returned empty object');
                end
            catch ME
                warning(ME.identifier, '%s', ME.message);
                app.ChatGPTHelper = [];
            end

            % Initialize module managers
            app.ImmediateAnalysis = modules.ImmediateAnalysisModule(app);
            app.InteractiveProfile = modules.InteractiveProfileModule(app);
            app.ProcessPipeline = modules.ProcessPipelineModule(app);
            app.BrainViewer = modules.BrainViewerModule(app);
            
            % Apply the default model profile so the AI env vars are ready
            try
                utils.ModelProfile.apply(app.SelectedModelID);
            catch
                warning('Model profile apply failed at startup; select a model in the UI.');
            end

            % Create main interface
            createMainInterface(app);
        end
    end
end
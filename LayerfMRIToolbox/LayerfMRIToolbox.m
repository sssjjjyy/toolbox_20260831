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
        ChatHistoryArea     matlab.ui.control.TextArea
        PromptEditField     matlab.ui.control.TextArea
        SubmitPromptBtn     matlab.ui.control.Button
        
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
                'Position', [20 450 120 30], ...
                'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) app.switchMode('Selection'));
                
            % 极客风终端显示区 (Chat History)
            app.ChatHistoryArea = uitextarea(app.AIPanel, ...
                'Position', [50 150 700 280], ...
                'Editable', 'off', ...
                'BackgroundColor', [0.05 0.05 0.05], ...
                'FontColor', [0.2 0.9 0.2], ...
                'FontName', 'Courier New', ...
                'FontSize', 14);
            app.ChatHistoryArea.Value = {'[System] AI Copilot Initialized.', '[System] 正在等待您的指令...'};
            
            % 用户 Prompt 输入框
            app.PromptEditField = uitextarea(app.AIPanel, ...
                'Position', [50 50 580 80], ...
                'FontSize', 14, ...
                'Placeholder', '请输入您的需求，例如：帮我把文件夹里的数据做一下头动校正...');
                
            % 发送按钮
            app.SubmitPromptBtn = uibutton(app.AIPanel, 'push', ...
                'Text', '发送 (Send)', ...
                'Position', [650 50 100 80], ...
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
        
        % 处理用户发送给 AI 的 Prompt
        function sendAIPrompt(app)
            userText = app.PromptEditField.Value;
            
            % 检查是否为空
            if isempty(userText) || all(cellfun(@isempty, userText))
                return;
            end
            
            % 1. 将用户的输入格式化并打印到上方终端框中
            currentHistory = app.ChatHistoryArea.Value;
            userMsg = ['> User: ' strjoin(userText, ' ')];
            app.ChatHistoryArea.Value = [currentHistory; {''}; {userMsg}; {'[System] AI 正在思考中...'}];
            scroll(app.ChatHistoryArea, 'bottom'); % 自动滚动到底部
            
            % 2. 清空输入框
            app.PromptEditField.Value = '';
            drawnow; % 强制立刻刷新 UI
            
            % =====================================================
            % TODO: 在这里连接 OpenAI API 逻辑 (调用 app.ChatGPTHelper)
            % =====================================================
            
            % 模拟网络延迟与假响应 (测试用)
            pause(1.0); 
            currentHistory = app.ChatHistoryArea.Value;
            % 替换掉最后一行 "[System] AI 正在思考中..."
            currentHistory(end) = {'[AI Copilot] 已收到您的文本请求！后端 OpenAI API 接口逻辑待接入。'};
            app.ChatHistoryArea.Value = currentHistory;
            scroll(app.ChatHistoryArea, 'bottom');
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
            
            % Create main interface
            createMainInterface(app);
        end
    end
end
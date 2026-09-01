classdef ImmediateAnalysisModule < handle
    properties (Access = private)
        Parent          % Parent application handle
        Figure
        WorkingDirPath
        ChatGPT
        Controls
        code_dir
        d2n_dir
        QAenvName
    end
    
    methods (Access = public)
        function obj = ImmediateAnalysisModule(parent)
            if nargin > 0
                obj.Parent = parent;
            end
            obj.ChatGPT = obj.Parent.ChatGPTHelper;  % 确保这里正确获取ChatGPT对象
            obj.code_dir = fileparts(mfilename('fullpath'));
            obj.d2n_dir = fullfile(fileparts(mfilename('fullpath')), 'utils');
            obj.QAenvName = 'layerfmri';

        end
        
        function show(obj)
            % Create module figure
            obj.Figure = uifigure('Name', 'fMRI Immediate Analysis', ...
                'Position', [150 150 410 600]);
            
            % Create working directory selection
            obj.createWorkingDirControls();
            
            % Create analysis buttons
            obj.createAnalysisButtons();
            
            % Create ChatGPT interface
            obj.createChatGPTPanel();
        end
    end
    
    methods (Access = private)
        function createWorkingDirControls(obj)
            % Create directory selection panel
            dirPanel = uipanel(obj.Figure, ...
                'Position', [20 520 380 60], ...
                'Title', 'Working Directory');
            
            % Create directory text field
            obj.Controls.DirPath = uieditfield(dirPanel, ...
                'Position', [10 10 300 30], ...
                'Value', '', ...
                'Editable', 'off');
            
            % Create browse button
            uibutton(dirPanel, 'Text', 'Browse', ...
                'Position', [310 10 60 30], ...
                'ButtonPushedFcn', @(btn,event) obj.browseDirectory());
        end
        
        function createAnalysisButtons(obj)
            % Create analysis buttons
            buttonConfigs = {
                'Bruker2Nifti', [20 440 380 60];
                'LongTR_BOLD', [20 360 380 60];
                'LongTR_CBV', [20 280 380 60];
                'ShortTR_BOLD', [20 200 380 60];
                'ShortTR_CBV', [20 120 380 60]
            };
            
            for i = 1:size(buttonConfigs, 1)
                uibutton(obj.Figure, 'Text', buttonConfigs{i,1}, ...
                    'Position', buttonConfigs{i,2}, ...
                    'ButtonPushedFcn', @(btn,event) obj.showParameterDialog(buttonConfigs{i,1}));
            end
        end
        
        function createChatGPTPanel(obj)
            % Create ChatGPT panel
            chatPanel = uipanel(obj.Figure, ...
                'Position', [20 20 380 80], ...
                'Title', 'ChatGPT Assistant');
            
            % Create query input field
            obj.Controls.ChatQuery = uieditfield(chatPanel, ...
                'Position', [10 40 300 30], ...
                'Value', '', ...
                'Placeholder', 'Ask ChatGPT about fMRI analysis...');
            
            % Create ask button
            uibutton(chatPanel, 'Text', 'Ask', ...
                'Position', [310 40 40 30], ...
                'ButtonPushedFcn', @(btn,event) obj.askChatGPT());

%             % Add Clear History button
%             uibutton(chatPanel, ...
%                 'Text', 'Clear Chat History', ...
%                 'Position', [355 40 20 30], ...
%                 'ButtonPushedFcn', @(btn,event) obj.clearChatHistory());
            
            % Create response display
            obj.Controls.ChatResponse = uitextarea(chatPanel, ...
                'Position', [10 10 370 25], ...
                'Value', '', ...
                'Editable', 'off');
        end
        
        function browseDirectory(obj)
            path = uigetdir('', 'Select Working Directory');
            if path ~= 0
                obj.WorkingDirPath = path;
                obj.Controls.DirPath.Value = path;
            end
        end
        function showParameterDialog(obj, analysisType)
            % Check if working directory is selected
            if isempty(obj.WorkingDirPath)
                uialert(obj.Figure, ...
                    'Please select a working directory first.', ...
                    'No Working Directory', ...
                    'Icon', 'warning');
                return;
            end
            
            % Create parameter dialog based on analysis type
            modules.ParameterDialog.show(analysisType, obj.WorkingDirPath, obj.ChatGPT, ...
                obj.code_dir,obj.d2n_dir, obj.QAenvName);
        end
        
        function askChatGPT(obj)
            try
                if isempty(obj.ChatGPT)
                    uialert(obj.Figure, ...
                        'ChatGPT helper is not initialized.', ...
                        'Error', ...
                        'Icon', 'error');
                    return;
                end
                
                % 获取查询内容
                query = obj.Controls.ChatQuery.Value;
                if isempty(query)
                    uialert(obj.Figure, ...
                        'Please enter a question.', ...
                        'Empty Query', ...
                        'Icon', 'warning');
                    return;
                end

                % 显示等待提示
                d = uiprogressdlg(obj.Figure, ...
                    'Message', 'Waiting for ChatGPT response...', ...
                    'Title', 'Processing');
                
                try
                    % 调用ChatGPT API（使用默认选项）
                    response = obj.ChatGPT.askGPT(query);
                    
                    % 关闭等待提示
                    close(d);
                    
                    % 更新响应文本区域
                    if isfield(obj.Controls, 'ChatResponse')
                        obj.Controls.ChatResponse.Value = response;
                    end
                catch ME
                    % 关闭等待提示
                    close(d);
                    
                    % 处理 ChatGPT 查询错误
                    errorMsg = ['Error querying ChatGPT: ' ME.message];
                    if isfield(obj.Controls, 'ChatResponse')
                        obj.Controls.ChatResponse.Value = ['Error: ' ME.message];
                    end
                    % 存储错误信息以供后续查询
                    obj.Controls.LastError = ME.message;
                    errordlg(errorMsg, 'ChatGPT Error');
                end
            catch ME
                uialert(obj.Figure, ...
                    sprintf('Error in askChatGPT: %s', ME.message), ...
                    'Error', ...
                    'Icon', 'error');
            end
        end

        function clearChatHistory(obj)
            try
                if ~isempty(obj.ChatGPT)
                    obj.ChatGPT.clearHistory();
                    % Clear the response display
                    obj.Controls.ChatResponse.Value = '';
                    % Show confirmation
                    uialert(obj.Figure, ...
                        'Chat history has been cleared.', ...
                        'Success', ...
                        'Icon', 'success');
                end
            catch ME
                uialert(obj.Figure, ...
                    sprintf('Failed to clear history: %s', ME.message), ...
                    'Error', ...
                    'Icon', 'error');
            end
        end

    end
end 
classdef ChatGPTInterface < handle
    properties (Access = private)
        PythonScript  % Python script path
        PythonPath    % Python executable path
        History       % Chat history
        KnowledgeDir  % Knowledge base directory
        ToolboxPath   % Toolbox path
    end
    
    properties (Access = public)
        LastError     % Store last error message
        Debug = false % Debug mode flag
    end
    
    methods (Access = public)
        function obj = ChatGPTInterface()
            % Get the path to the Python script
            obj.PythonScript = fullfile(fileparts(mfilename('fullpath')), 'chatgpt_api.py');
            
            % Get Python path from conda environment
            obj.PythonPath = fullfile(getenv('USERPROFILE'), '.conda', 'envs', 'layerfmri', 'python.exe');

            % Initialize properties
            obj.History = {};
            obj.LastError = '';
            obj.KnowledgeDir = fullfile(fileparts(mfilename('fullpath')), 'fmri_knowledge');
            obj.ToolboxPath = fileparts(fileparts(mfilename('fullpath')));
            
            % Verify paths and initialize system
            obj.verifyPaths();
            obj.initializeSystem();
        end
        
        function response = askGPT(obj, query, error_context)
            try
                % Input validation
                if ~ischar(query) && ~isstring(query)
                    error('ChatGPT:InvalidInput', 'Query must be a string');
                end
                
                % Get stack trace for error context if not provided
                if nargin < 3
                    error_context = '';
                elseif isa(error_context, 'MException')
                    % If error_context is an MException, get its details
                    error_context = obj.formatErrorContext(error_context);
                end
                
                % Escape quotes and prepare command
                query = strrep(query, '"', '\"');
                if ~isempty(error_context)
                    error_context = strrep(error_context, '"', '\"');
                    cmd = sprintf('"%s" "%s" "error" "%s" "%s"', ...
                        obj.PythonPath, obj.PythonScript, query, error_context);
                else
                    cmd = sprintf('"%s" "%s" "query" "%s"', ...
                        obj.PythonPath, obj.PythonScript, query);
                end
                
                % Execute command with proper encoding
                if ispc
                    [status, result] = system(['@echo off & chcp 65001 > nul & ' cmd]);
                else
                    [status, result] = system(cmd);
                end
                
                % Handle response
                if status == 0
                    result = regexprep(result, '^\xEF\xBB\xBF', ''); % Remove BOM
                    response = strtrim(result);
                    
                    % Store in history with timestamp
                    obj.History{end+1} = struct(...
                        'timestamp', datetime('now'), ...
                        'query', query, ...
                        'response', response, ...
                        'error_context', error_context ...
                    );
                    
                    if obj.Debug
                        fprintf('Debug: Query processed successfully\n');
                    end
                else
                    obj.LastError = result;
                    error('ChatGPT:APIError', 'Query failed: %s', result);
                end
                
            catch ME
                obj.LastError = ME.message;
                if obj.Debug
                    fprintf('Debug: Error in askGPT - %s\n', ME.message);
                    disp(getReport(ME, 'extended'));
                end
                error('ChatGPT:Error', 'Error processing query: %s', ME.message);
            end
        end
        
        function exportHistory(obj, filename)
            % Export chat history to JSON file
            if isempty(obj.History)
                warning('ChatGPT:Export', 'No history to export');
                return;
            end
            
            try
                % Convert datetime to string for JSON compatibility
                history = obj.History;
                for i = 1:length(history)
                    history{i}.timestamp = char(history{i}.timestamp);
                end
                
                % Write to JSON file
                fid = fopen(filename, 'w', 'n', 'utf-8');
                fprintf(fid, '%s', jsonencode(history, 'PrettyPrint', true));
                fclose(fid);
                
                if obj.Debug
                    fprintf('Debug: History exported to %s\n', filename);
                end
            catch ME
                warning('ChatGPT:Export', 'Failed to export history: %s', ME.message);
            end
        end
        
        function setDebug(obj, state)
            % Enable/disable debug mode
            obj.Debug = logical(state);
        end
        

        function error_context = formatErrorContext(obj, ME)
            % Format MException into detailed error context
            stack = ME.stack;
            error_context = sprintf('Error: %s\n\nStack Trace:\n', ME.message);
            
            for i = 1:length(stack)
                error_context = sprintf('%s\nFile: %s\nLine: %d\nFunction: %s\n', ...
                    error_context, stack(i).file, stack(i).line, stack(i).name);
            end
            
            % Add code context if available
            try
                for i = 1:length(stack)
                    file = stack(i).file;
                    line = stack(i).line;
                    if exist(file, 'file')
                        fid = fopen(file, 'r');
                        if fid ~= -1
                            lines = textscan(fid, '%s', 'Delimiter', '\n');
                            fclose(fid);
                            lines = lines{1};
                            
                            % Get context around the error line
                            start_line = max(1, line - 2);
                            end_line = min(length(lines), line + 2);
                            
                            error_context = sprintf('%s\nCode Context in %s:\n', ...
                                error_context, file);
                            for j = start_line:end_line
                                if j == line
                                    error_context = sprintf('%s> %d: %s\n', ...
                                        error_context, j, lines{j});
                                else
                                    error_context = sprintf('%s  %d: %s\n', ...
                                        error_context, j, lines{j});
                                end
                            end
                        end
                    end
                end
            catch
                % Ignore errors in getting code context
            end
        end
    end
end


% % 创建接口实例
% gpt = ChatGPTInterface();

% % 启用调试模式（可选）
% gpt.setDebug(true);

% % fMRI相关问题
% try
%     response = gpt.askGPT('请解释什么是功能磁共振成像？');
%     disp(response);
% catch ME
%     disp(['Error: ' ME.message]);
% end

% % 代码错误分析（直接传入 MException）
% try
%     % 你的代码
%     result = some_function(params);
% catch ME
%     % 直接传入 MException 对象
%     response = gpt.askGPT('代码执行出错', ME);
%     fprintf('Error Analysis:\n%s\n', response);
% end

% % 导出历史记录
% gpt.exportHistory('chat_history.json');
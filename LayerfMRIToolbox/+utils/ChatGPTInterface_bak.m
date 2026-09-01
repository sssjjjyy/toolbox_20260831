classdef ChatGPTInterface < handle
    properties (Access = private)
        PythonScript  % Python script path
        PythonPath    % Python executable path
        History
    end
    
    methods (Access = public)
        function obj = ChatGPTInterface()
            % Get the path to the Python script
            obj.PythonScript = fullfile(fileparts(mfilename('fullpath')), 'chatgpt_api.py');
            
            % Get Python path from conda environment
            obj.PythonPath = fullfile(getenv('USERPROFILE'), '.conda', 'envs', 'layerfmri', 'python.exe');

            % Initialize empty history
            obj.History = {};

            % Verify paths
            if ~exist(obj.PythonScript, 'file')
                error('ChatGPT:Setup', 'Python script not found at: %s', obj.PythonScript);
            end
            
            if ~exist(obj.PythonPath, 'file')
                error('ChatGPT:Setup', 'Python not found at: %s', obj.PythonPath);
            end
        end

        function clearHistory(obj)
            % Clear chat history
            obj.History = {};
        end

        function response = askGPT(obj, prompt)
            try
                % Add prompt to history
                obj.History{end+1} = struct('role', 'user', 'content', prompt);
                
                % Escape quotes in prompt
                prompt = strrep(prompt, '"', '\"');
                
                % Construct command with history flag
                if isempty(obj.History)
                    cmd = sprintf('"%s" "%s" "%s" --new-chat', ...
                        obj.PythonPath, obj.PythonScript, prompt);
                else
                    cmd = sprintf('"%s" "%s" "%s"', ...
                        obj.PythonPath, obj.PythonScript, prompt);
                end
                
                % Execute Python script with UTF-8 encoding
                if ispc
                    % 使用 @echo off 来隐藏命令输出
                    [status, result] = system(['@echo off & chcp 65001 > nul & ' cmd]);
                else
                    [status, result] = system(cmd);
                end
                
                if status == 0
                    % Remove BOM and extra lines
                    result = regexprep(result, '^\xEF\xBB\xBF', '');
                    result = strtrim(result);
                    
                    % Check for error message
                    if startsWith(result, 'Error:')
                        error('ChatGPT:APIError', result);
                    end
                    
                    % Add response to history
                    obj.History{end+1} = struct('role', 'assistant', 'content', result);
                    response = result;
                else
                    error('ChatGPT:APIError', 'Python script error: %s', result);
                end
                
            catch ME
                error('ChatGPT:Error', 'Error calling Python script: %s', ME.message);
            end
        end



    end
end
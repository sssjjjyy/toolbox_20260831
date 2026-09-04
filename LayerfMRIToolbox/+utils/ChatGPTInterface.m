classdef ChatGPTInterface < handle
    properties (Access = private)
        PythonScript
        PythonPath
        History
        KnowledgeDir
        ToolboxPath
    end

    properties (Access = public)
        LastError
        Debug = false
    end

    methods (Access = public)
        function obj = ChatGPTInterface()
            obj.PythonScript = fullfile(fileparts(mfilename('fullpath')), 'chatgpt_api.py');
            obj.PythonPath = obj.resolvePythonPath();
            obj.History = {};
            obj.LastError = '';
            obj.KnowledgeDir = fullfile(fileparts(mfilename('fullpath')), 'fmri_knowledge');
            obj.ToolboxPath = fileparts(fileparts(mfilename('fullpath')));
            obj.verifyPaths();
        end

        function response = askGPT(obj, query, errorContext)
            if nargin < 3
                errorContext = '';
            elseif isa(errorContext, 'MException')
                errorContext = obj.formatErrorContext(errorContext);
            end

            if ~(ischar(query) || (isstring(query) && isscalar(query)))
                error('ChatGPT:InvalidInput', 'Query must be a character vector or scalar string.');
            end

            query = char(string(query));
            errorContext = char(string(errorContext));
            request = struct( ...
                'mode', 'chat', ...
                'query', query, ...
                'error_context', errorContext, ...
                'toolbox_path', obj.ToolboxPath);

            try
                result = obj.invokePython(request);
                if ~isfield(result, 'ok') || ~result.ok
                    if isfield(result, 'error')
                        message = char(string(result.error));
                    else
                        message = 'The AI service returned an invalid response.';
                    end
                    error('ChatGPT:APIError', '%s', message);
                end
                if ~isfield(result, 'content')
                    error('ChatGPT:InvalidResponse', 'The AI response does not contain content.');
                end

                response = char(string(result.content));
                obj.History{end+1} = struct( ...
                    'timestamp', datetime('now'), ...
                    'query', query, ...
                    'response', response, ...
                    'error_context', errorContext);
                obj.LastError = '';
            catch ME
                obj.LastError = ME.message;
                if obj.Debug
                    disp(getReport(ME, 'extended'));
                end
                throwAsCaller(MException('ChatGPT:Error', 'Error processing query: %s', ME.message));
            end
        end

        function clearHistory(obj)
            obj.History = {};
        end

        function exportHistory(obj, filename)
            if isempty(obj.History)
                warning('ChatGPT:Export', 'No history to export.');
                return;
            end

            history = obj.History;
            for index = 1:numel(history)
                history{index}.timestamp = char(history{index}.timestamp);
            end

            fid = fopen(filename, 'w', 'n', 'UTF-8');
            if fid == -1
                error('ChatGPT:Export', 'Cannot open history file: %s', filename);
            end
            cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', jsonencode(history, 'PrettyPrint', true));
        end

        function setDebug(obj, state)
            obj.Debug = logical(state);
        end
    end

    methods (Access = private)
        function pythonPath = resolvePythonPath(~)
            pythonPath = strtrim(getenv('LAYERFMRI_PYTHON'));
            if isempty(pythonPath)
                if isunix
                    pythonPath = 'python3';
                else
                    pythonPath = 'python';
                end
            end
        end

        function verifyPaths(obj)
            if ~exist(obj.PythonScript, 'file')
                error('ChatGPT:Setup', 'Python script not found: %s', obj.PythonScript);
            end

            command = sprintf('"%s" --version', obj.PythonPath);
            [status, output] = system(command);
            if status ~= 0
                error('ChatGPT:Setup', 'Python is unavailable (%s): %s', obj.PythonPath, strtrim(output));
            end
        end

        function result = invokePython(obj, request)
            requestFile = [tempname, '.json'];
            fid = fopen(requestFile, 'w', 'n', 'UTF-8');
            if fid == -1
                error('ChatGPT:Request', 'Cannot create a temporary request file.');
            end
            fileCleanup = onCleanup(@() obj.deleteRequestFile(requestFile));
            fidCleanup = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', jsonencode(request));
            clear fidCleanup;

            command = sprintf('"%s" "%s" --request "%s"', ...
                obj.PythonPath, obj.PythonScript, requestFile);
            [status, output] = system(command);
            output = regexprep(output, '^\xEF\xBB\xBF', '');
            output = strtrim(output);

            if isempty(output)
                error('ChatGPT:EmptyResponse', 'The Python service returned no output.');
            end

            try
                result = jsondecode(output);
            catch
                error('ChatGPT:InvalidJSON', 'The Python service returned invalid JSON: %s', output);
            end

            if status ~= 0 && (~isfield(result, 'ok') || result.ok)
                error('ChatGPT:PythonError', 'The Python service failed: %s', output);
            end
        end

        function deleteRequestFile(~, filename)
            if exist(filename, 'file')
                delete(filename);
            end
        end

        function errorContext = formatErrorContext(~, exception)
            errorContext = sprintf('Error: %s\n\nStack Trace:\n', exception.message);
            for index = 1:numel(exception.stack)
                frame = exception.stack(index);
                errorContext = sprintf('%sFile: %s\nLine: %d\nFunction: %s\n', ...
                    errorContext, frame.file, frame.line, frame.name);
            end
        end
    end
end

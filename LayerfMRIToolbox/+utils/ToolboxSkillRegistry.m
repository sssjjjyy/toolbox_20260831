classdef ToolboxSkillRegistry
    % ToolboxSkillRegistry - local, auditable catalogue of process_module
    % skills exposed to the AI Copilot.
    %
    % A skill may be:
    %   status 'enabled'      -> registered, verified, and (if execution_mode
    %                            is 'auto') on the automatic-execution whitelist.
    %   status 'interactive'  -> recognized by the AI but not yet safe/validated
    %                            for automatic execution.
    %   status 'unavailable'  -> empty shell or missing dependency; the AI may
    %                            explain it but must never execute it.
    %
    % The executor may ONLY call functions through resolve()/feval on skills
    % returned by the whitelist. Model-supplied strings are never evaled.

    methods (Static)
        function skills = all()
            skills = utils.ToolboxSkillRegistry.loadSkills();
        end

        function root = toolboxRoot()
            root = fileparts(fileparts(mfilename('fullpath')));
        end

        function modulePath = processModulePath()
            modulePath = fullfile(utils.ToolboxSkillRegistry.toolboxRoot(), 'process_module');
        end

        function skill = get(name)
            skills = utils.ToolboxSkillRegistry.all();
            index = utils.ToolboxSkillRegistry.findIndex(skills, name);
            if isempty(index)
                skill = [];
            else
                skill = skills(index);
            end
        end

        function present = isRegistered(name)
            skills = utils.ToolboxSkillRegistry.all();
            present = ~isempty(utils.ToolboxSkillRegistry.findIndex(skills, name));
        end

        function ok = isEnabled(name)
            skill = utils.ToolboxSkillRegistry.get(name);
            if isempty(skill)
                ok = false;
            else
                ok = strcmp(skill.status, 'enabled');
            end
        end

        function ok = isAutoExecutable(name)
            skill = utils.ToolboxSkillRegistry.get(name);
            if isempty(skill)
                ok = false;
            else
                ok = strcmp(skill.status, 'enabled') && strcmp(skill.execution_mode, 'auto');
            end
        end

        function names = whitelist()
            skills = utils.ToolboxSkillRegistry.all();
            names = {};
            for index = 1:numel(skills)
                skill = skills(index);
                if utils.ToolboxSkillRegistry.isAutoExecutable(skill.name)
                    names{end+1, 1} = skill.name; %#ok<AGROW>
                end
            end
        end

        function names = allNames()
            skills = utils.ToolboxSkillRegistry.all();
            names = cell(numel(skills), 1);
            for index = 1:numel(skills)
                names{index} = skills(index).name;
            end
        end

        function handle = resolve(name)
            % Returns a function handle for an auto-executable skill, or [].
            % The path is added before lookup; handles come only from the
            % local registry metadata (never from model-supplied strings).
            handle = [];
            if ~utils.ToolboxSkillRegistry.isAutoExecutable(name)
                return;
            end
            skill = utils.ToolboxSkillRegistry.get(name);
            if isempty(skill) || ~isfield(skill, 'callable') || isempty(skill.callable)
                return;
            end
            modulePath = utils.ToolboxSkillRegistry.processModulePath();
            if exist(modulePath, 'dir')
                addpath(modulePath);
            end
            callable = char(string(skill.callable));
            if exist(callable, 'file') == 2 || exist(callable, 'builtin') == 5
                try
                    handle = str2func(callable);
                catch
                    handle = [];
                end
            end
        end

        function text = describe(name)
            skill = utils.ToolboxSkillRegistry.get(name);
            if isempty(skill)
                text = '';
                return;
            end
            text = sprintf('%s - %s [%s/%s]', skill.name, ...
                utils.ToolboxSkillRegistry.clean(skill.description), ...
                skill.status, skill.execution_mode);
            params = utils.ToolboxSkillRegistry.parameterArray(skill);
            if ~isempty(params)
                lines = cell(numel(params), 1);
                for index = 1:numel(params)
                    parameter = params(index);
                    mark = 'required';
                    if ~parameter.required
                        mark = 'optional';
                    end
                    lines{index} = sprintf('  - %s (%s, %s): %s', ...
                        parameter.name, parameter.type, mark, ...
                        utils.ToolboxSkillRegistry.clean(parameter.description));
                end
                text = sprintf('%s\n%s', text, strjoin(lines, newline));
            end
        end

        function schema = toolSchema()
            % Compact schema sent to the model: only skills the AI may reason
            % about, with their parameter contracts. Never includes keys/paths.
            skills = utils.ToolboxSkillRegistry.all();
            schema = struct('name', {}, 'description', {}, 'status', {}, ...
                'execution_mode', {}, 'parameters', {});
            for index = 1:numel(skills)
                skill = skills(index);
                params = utils.ToolboxSkillRegistry.parameterArray(skill);
                paramSchema = struct('name', {}, 'type', {}, 'required', {}, 'description', {});
                for paramIndex = 1:numel(params)
                    parameter = params(paramIndex);
                    paramSchema(end+1).name = parameter.name; %#ok<AGROW>
                    paramSchema(end).type = parameter.type;
                    paramSchema(end).required = logical(parameter.required);
                    paramSchema(end).description = utils.ToolboxSkillRegistry.clean(parameter.description);
                end
                schema(end+1).name = skill.name; %#ok<AGROW>
                schema(end).description = utils.ToolboxSkillRegistry.clean(skill.description);
                schema(end).status = skill.status;
                schema(end).execution_mode = skill.execution_mode;
                schema(end).parameters = paramSchema;
            end
        end

        function summary = summaryText()
            skills = utils.ToolboxSkillRegistry.all();
            counts = struct('enabled', 0, 'interactive', 0, 'unavailable', 0, 'auto', 0);
            for index = 1:numel(skills)
                skill = skills(index);
                if isfield(counts, skill.status)
                    counts.(skill.status) = counts.(skill.status) + 1;
                end
                if strcmp(skill.execution_mode, 'auto')
                    counts.auto = counts.auto + 1;
                end
            end
            summary = sprintf('%d skills registered: %d enabled, %d interactive, %d unavailable; %d auto-executable on the whitelist.', ...
                numel(skills), counts.enabled, counts.interactive, counts.unavailable, counts.auto);
        end

        function params = parameterArray(skill)
            params = [];
            if ~isfield(skill, 'parameters')
                return;
            end
            if isstruct(skill.parameters) && ~isempty(skill.parameters)
                params = skill.parameters;
            end
        end
    end

    methods (Static, Access = private)
        function skills = loadSkills()
            registryFile = fullfile(fileparts(mfilename('fullpath')), 'skills_registry.json');
            if ~exist(registryFile, 'file')
                error('ToolboxSkillRegistry:MissingFile', 'Registry file not found: %s', registryFile);
            end
            raw = jsondecode(fileread(registryFile));
            if ~isfield(raw, 'skills') || isempty(raw.skills)
                error('ToolboxSkillRegistry:Empty', 'Registry contains no skills.');
            end
            skills = raw.skills;
            % Normalize so every element exposes the full common field set.
            requiredFields = {'name', 'file', 'callable', 'display_name', 'description', ...
                'status', 'execution_mode', 'writes_files', 'dependencies', 'parameters'};
            for index = 1:numel(skills)
                for fieldIndex = 1:numel(requiredFields)
                    fieldName = requiredFields{fieldIndex};
                    if ~isfield(skills(index), fieldName)
                        switch fieldName
                            case {'writes_files'}
                                skills(index).(fieldName) = false;
                            case {'dependencies', 'parameters'}
                                skills(index).(fieldName) = [];
                            otherwise
                                skills(index).(fieldName) = '';
                        end
                    end
                end
            end
        end

        function index = findIndex(skills, name)
            index = [];
            if isempty(name) || isempty(skills)
                return;
            end
            for current = 1:numel(skills)
                if strcmpi(string(skills(current).name), string(name))
                    index = current;
                    return;
                end
            end
        end

        function value = clean(value)
            if ischar(value)
                value = strtrim(value);
            elseif isstring(value)
                value = strtrim(char(value));
            else
                value = char(string(value));
            end
        end
    end
end

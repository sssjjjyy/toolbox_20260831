classdef AIPlanValidator
    % AIPlanValidator - verifies an AI-produced tool plan against the local
    % skill registry before anything is executed.
    %
    % The validator is deliberately conservative: an unknown skill, a
    % non-enabled skill, a missing/unknown parameter, an out-of-directory
    % path, an existing output file, or a missing runtime dependency all
    % block the whole plan and are reported as issues.

    methods (Static)
        function result = validatePlan(plan, workdir, skills)
            result = struct( ...
                'ok', true, ...
                'plan_type', '', ...
                'issues', {{}}, ...
                'stepResults', repmat(struct('index', 0, 'tool', '', 'ok', false, 'issues', {{}}), 0, 1));

            if nargin < 2
                workdir = '';
            end
            if nargin < 3
                skills = utils.ToolboxSkillRegistry.all();
            end
            if isempty(workdir)
                workdir = '';
            end
            workdir = char(string(workdir));

            if ~isstruct(plan) || ~isfield(plan, 'type')
                result.ok = false;
                result.issues{end+1} = 'The plan is not a valid structured object.';
                return;
            end
            result.plan_type = char(string(plan.type));

            if ~strcmpi(result.plan_type, 'tool_plan')
                result.issues{end+1} = sprintf('Nothing to validate (type: %s).', result.plan_type);
                return;
            end

            if ~isfield(plan, 'steps') || isempty(plan.steps)
                result.ok = false;
                result.issues{end+1} = 'The tool plan contains no steps.';
                return;
            end

            steps = utils.AIPlanValidator.asStepArray(plan.steps);
            allIssues = {};
            for stepIndex = 1:numel(steps)
                stepResult = utils.AIPlanValidator.validateStep(steps(stepIndex), workdir, skills);
                result.stepResults(end+1) = stepResult;
                if ~stepResult.ok
                    result.ok = false;
                    prefix = sprintf('Step %d (%s): ', stepIndex, stepResult.tool);
                    for issueIndex = 1:numel(stepResult.issues)
                        allIssues{end+1} = [prefix, stepResult.issues{issueIndex}]; %#ok<AGROW>
                    end
                end
            end
            if ~isempty(allIssues)
                result.issues = allIssues;
            end
        end

        function stepResult = validateStep(step, workdir, skills)
            stepResult = struct('index', 0, 'tool', '', 'ok', true, 'issues', {{}});
            if ~isstruct(step)
                stepResult.ok = false;
                stepResult.issues{end+1} = 'The step is not a structured object.';
                return;
            end
            toolName = '';
            if isfield(step, 'tool')
                toolName = char(string(step.tool));
            end
            stepResult.tool = toolName;
            if isfield(step, 'index')
                stepResult.index = step.index;
            end
            if isempty(strtrim(toolName))
                stepResult.ok = false;
                stepResult.issues{end+1} = 'No tool name was provided.';
                return;
            end

            skill = utils.AIPlanValidator.findSkill(skills, toolName);
            if isempty(skill)
                stepResult.ok = false;
                stepResult.issues{end+1} = sprintf('Skill ''%s'' is not in the registry.', toolName);
                return;
            end

            status = char(string(skill.status));
            mode = char(string(skill.execution_mode));
            if ~strcmp(status, 'enabled')
                stepResult.ok = false;
                stepResult.issues{end+1} = sprintf( ...
                    'Skill ''%s'' is not enabled (status: %s). It can be explained but not executed.', ...
                    toolName, status);
                return;
            end
            if ~strcmp(mode, 'auto')
                stepResult.ok = false;
                stepResult.issues{end+1} = sprintf( ...
                    'Skill ''%s'' cannot run from a file-based plan yet (execution_mode: %s).', ...
                    toolName, mode);
                return;
            end

            arguments = struct();
            if isfield(step, 'arguments')
                arguments = step.arguments;
            end
            if ~isstruct(arguments)
                stepResult.ok = false;
                stepResult.issues{end+1} = 'Step arguments must be a JSON object.';
                return;
            end

            params = utils.ToolboxSkillRegistry.parameterArray(skill);
            paramNames = {};
            paramByType = containers.Map('KeyType', 'char', 'ValueType', 'char');
            hasVolumeParam = false;
            for paramIndex = 1:numel(params)
                parameter = params(paramIndex);
                name = char(string(parameter.name));
                paramNames{end+1} = name; %#ok<AGROW>
                paramByType(name) = char(string(parameter.type));
                if strcmpi(char(string(parameter.type)), 'volume')
                    hasVolumeParam = true;
                end
            end
            if hasVolumeParam
                stepResult.ok = false;
                stepResult.issues{end+1} = sprintf( ...
                    'Skill ''%s'' needs in-memory volume inputs that a file-based plan cannot provide yet.', ...
                    toolName);
                return;
            end

            argumentFields = fieldnames(arguments);
            for argumentIndex = 1:numel(argumentFields)
                fieldName = argumentFields{argumentIndex};
                if ~ismember(fieldName, paramNames)
                    stepResult.ok = false;
                    stepResult.issues{end+1} = sprintf('Unknown argument ''%s'' for skill ''%s''.', fieldName, toolName);
                end
            end
            if ~stepResult.ok
                return;
            end

            for paramIndex = 1:numel(params)
                parameter = params(paramIndex);
                name = char(string(parameter.name));
                required = logical(parameter.required);
                parameterType = char(string(parameter.type));
                if required && ~isfield(arguments, name)
                    stepResult.ok = false;
                    stepResult.issues{end+1} = sprintf('Missing required argument ''%s''.', name);
                    continue;
                end
                if ~isfield(arguments, name)
                    continue;
                end
                value = arguments.(name);

                switch parameterType
                    case {'numeric', 'integer'}
                        if ~utils.AIPlanValidator.isNumericValue(value, strcmp(parameterType, 'integer'))
                            stepResult.ok = false;
                            stepResult.issues{end+1} = sprintf( ...
                                'Argument ''%s'' must be a %s number.', name, parameterType);
                        end
                    case {'file', 'dir', 'output'}
                        if ~ischar(value) && ~isstring(value)
                            stepResult.ok = false;
                            stepResult.issues{end+1} = sprintf('Argument ''%s'' must be a path.', name);
                            continue;
                        end
                        issue = utils.AIPlanValidator.checkPathArgument(name, parameterType, char(string(value)), workdir);
                        if ~isempty(issue)
                            stepResult.ok = false;
                            stepResult.issues{end+1} = issue;
                        end
                    case {'string', 'list'}
                        if isstruct(value) && ~isempty(fieldnames(value))
                            stepResult.ok = false;
                            stepResult.issues{end+1} = sprintf('Argument ''%s'' must be text or a list.', name);
                        end
                    otherwise
                        % Unrecognised type: leave to the executor's checks.
                end
            end

            if ~stepResult.ok
                return;
            end

            dependencyIssues = utils.AIPlanValidator.checkDependencies(skill);
            if ~isempty(dependencyIssues)
                stepResult.ok = false;
                stepResult.issues = [stepResult.issues, dependencyIssues];
            end
        end

        function ok = isNumericValue(value, requireInteger)
            ok = false;
            if ischar(value) || isstring(value)
                parsed = str2double(char(string(value)));
                if isnan(parsed)
                    return;
                end
                value = parsed;
            end
            if ~(isscalar(value) && isnumeric(value) && isfinite(value))
                return;
            end
            if requireInteger && value ~= round(value)
                return;
            end
            ok = true;
        end

        function issue = checkPathArgument(name, parameterType, value, workdir)
            issue = '';
            resolved = utils.AIPlanValidator.resolvePath(workdir, value);

            if ~isempty(workdir) && ~utils.AIPlanValidator.isUnderRoot(workdir, resolved)
                issue = sprintf( ...
                    'Path of argument ''%s'' escapes the working directory (%s).', name, resolved);
                return;
            end

            switch parameterType
                case {'file'}
                    if ~exist(resolved, 'file') && ~exist(resolved, 'dir')
                        issue = sprintf('Input path ''%s'' does not exist.', resolved);
                    end
                case 'dir'
                    if ~exist(resolved, 'dir')
                        issue = sprintf('Directory ''%s'' does not exist.', resolved);
                    end
                case 'output'
                    [parent, ~, ~] = fileparts(resolved);
                    if ~isempty(parent) && ~exist(parent, 'dir')
                        issue = sprintf('Output folder ''%s'' does not exist.', parent);
                    elseif exist(resolved, 'file') || exist(resolved, 'dir')
                        issue = sprintf('Output ''%s'' already exists and would be overwritten.', resolved);
                    end
            end
        end

        function issues = checkDependencies(skill)
            issues = {};
            if ~isfield(skill, 'dependencies') || ~iscell(skill.dependencies)
                return;
            end
            dependencies = skill.dependencies;
            missingCount = 0;
            missing = repmat("", 1, numel(dependencies));
            for index = 1:numel(dependencies)
                dependency = char(string(dependencies{index}));
                if isempty(strtrim(dependency))
                    continue;
                end
                if isempty(which(dependency))
                    missingCount = missingCount + 1;
                    missing(missingCount) = string(dependency);
                end
            end
            if missingCount > 0
                missing = missing(1:missingCount);
                issues{end+1} = sprintf( ...
                    'Runtime dependencies not available on the MATLAB path: %s.', strjoin(missing, ', '));
            end
        end
    end

    methods (Static, Access = private)
        function skill = findSkill(skills, toolName)
            skill = [];
            target = lower(string(toolName));
            if isempty(target)
                return;
            end
            for index = 1:numel(skills)
                if strcmpi(string(skills(index).name), target)
                    skill = skills(index);
                    return;
                end
            end
        end

        function steps = asStepArray(rawSteps)
            steps = repmat(struct('tool', '', 'arguments', struct(), 'reason', '', 'index', 0), 0, 1);
            if isempty(rawSteps)
                return;
            end
            if ~isstruct(rawSteps)
                steps(1).tool = char(string(rawSteps));
                return;
            end
            for index = 1:numel(rawSteps)
                steps(end+1).index = index; %#ok<AGROW>
                steps(end).tool = '';
                steps(end).arguments = struct();
                steps(end).reason = '';
                if isfield(rawSteps(index), 'tool')
                    steps(end).tool = char(string(rawSteps(index).tool));
                end
                if isfield(rawSteps(index), 'arguments') && isstruct(rawSteps(index).arguments)
                    steps(end).arguments = rawSteps(index).arguments;
                end
                if isfield(rawSteps(index), 'reason')
                    steps(end).reason = char(string(rawSteps(index).reason));
                end
            end
        end

        function resolved = resolvePath(workdir, value)
            resolved = char(string(value));
            if ~isempty(workdir)
                fileObj = java.io.File(resolved);
                if ~fileObj.isAbsolute()
                    resolved = fullfile(workdir, resolved);
                end
            end
            resolved = char(java.io.File(resolved).getCanonicalPath());
        end

        function under = isUnderRoot(root, target)
            rootCanonical = char(java.io.File(root).getCanonicalPath());
            rootCanonical = utils.AIPlanValidator.normalizeSlashes(rootCanonical);
            targetCanonical = utils.AIPlanValidator.normalizeSlashes(target);
            prefix = [rootCanonical, '/'];
            under = strcmp(rootCanonical, targetCanonical) || startsWith(targetCanonical, prefix);
        end

        function path = normalizeSlashes(path)
            path = strrep(path, '\', '/');
            if numel(path) > 1 && endsWith(path, '/')
                path = path(1:end-1);
            end
        end
    end

    methods (Static)
        function skill = findSkillPublic(skills, toolName)
            skill = utils.AIPlanValidator.findSkill(skills, toolName);
        end

        function steps = asStepArrayPublic(rawSteps)
            steps = utils.AIPlanValidator.asStepArray(rawSteps);
        end
    end
end

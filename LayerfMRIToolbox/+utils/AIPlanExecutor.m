classdef AIPlanExecutor
    % AIPlanExecutor - runs a validated tool plan.
    %
    % Safety contract:
    %   * Only skills resolved from the LOCAL registry are callable.
    %   * Skill handles come from ToolboxSkillRegistry.resolve(), which only
    %     returns handles for status='enabled' and execution_mode='auto'.
    %   * Arguments are coerced strictly from the registry parameter schema.
    %   * No eval/evalin/str2func on model-supplied strings ever happens.
    %
    % Each step is recorded in the returned report with completed/error status.

    methods (Static)
        function report = executePlan(plan, workdir, onStatus, skills)
            report = struct( ...
                'ok', false, ...
                'stepCount', 0, ...
                'completed', 0, ...
                'failed', 0, ...
                'message', '', ...
                'steps', repmat(struct('index', 0, 'tool', '', 'status', '', 'message', '', 'arguments', struct()), 0, 1));

            if nargin < 3
                onStatus = [];
            end
            if nargin < 4
                skills = utils.ToolboxSkillRegistry.all();
            end
            if isempty(workdir)
                workdir = '';
            end
            workdir = char(string(workdir));

            if ~isstruct(plan) || ~isfield(plan, 'type') || ~strcmpi(char(string(plan.type)), 'tool_plan')
                report.message = 'The executor only accepts tool_plan objects.';
                return;
            end
            if ~isfield(plan, 'steps') || isempty(plan.steps)
                report.message = 'The plan contains no steps.';
                return;
            end

            steps = utils.AIPlanValidator.asStepArrayPublic(plan.steps);
            report.stepCount = numel(steps);

            modulePath = utils.ToolboxSkillRegistry.processModulePath();
            if exist(modulePath, 'dir')
                addpath(modulePath);
            end

            for stepIndex = 1:numel(steps)
                step = steps(stepIndex);
                stepResult = struct( ...
                    'index', step.index, ...
                    'tool', step.tool, ...
                    'status', 'error', ...
                    'message', '', ...
                    'arguments', struct());

                if isfield(step, 'arguments') && isstruct(step.arguments)
                    stepResult.arguments = step.arguments;
                end

                if ~isempty(onStatus)
                    utils.AIPlanExecutor.notify(onStatus, 'running', ...
                        sprintf('[Running] Step %d: %s', stepIndex, step.tool));
                end

                skill = utils.AIPlanValidator.findSkillPublic(skills, step.tool);
                if isempty(skill)
                    stepResult.message = sprintf('Skill ''%s'' is not in the registry.', step.tool);
                else
                    stepResult = utils.AIPlanExecutor.executeStep(skill, stepResult, workdir);
                end

                report.steps(end+1) = stepResult;
                if strcmp(stepResult.status, 'completed')
                    report.completed = report.completed + 1;
                    if ~isempty(onStatus)
                        utils.AIPlanExecutor.notify(onStatus, 'completed', ...
                            sprintf('[Completed] Step %d: %s', stepIndex, step.tool));
                    end
                else
                    report.failed = report.failed + 1;
                    if ~isempty(onStatus)
                        utils.AIPlanExecutor.notify(onStatus, 'error', ...
                            sprintf('[Error] Step %d (%s): %s', stepIndex, step.tool, stepResult.message));
                    end
                end
            end

            report.ok = (report.failed == 0 && report.completed > 0);
            if report.ok
                report.message = sprintf('Plan finished: %d/%d steps completed.', ...
                    report.completed, report.stepCount);
            else
                report.message = sprintf('Plan finished with %d failed step(s).', report.failed);
            end
            if ~isempty(onStatus)
                utils.AIPlanExecutor.notify(onStatus, 'summary', report.message);
            end
        end

        function stepResult = executeStep(skill, stepResult, workdir)
            handle = utils.ToolboxSkillRegistry.resolve(skill.name);
            if isempty(handle)
                stepResult.status = 'error';
                stepResult.message = sprintf( ...
                    'Skill ''%s'' cannot be resolved for automatic execution.', skill.name);
                return;
            end

            [args, argumentError] = utils.AIPlanExecutor.buildArguments(skill, stepResult.arguments, workdir);
            if ~isempty(argumentError)
                stepResult.status = 'error';
                stepResult.message = argumentError;
                return;
            end

            try
                if isempty(args)
                    feval(handle);
                else
                    feval(handle, args{:});
                end
                stepResult.status = 'completed';
                stepResult.message = 'Completed successfully.';
            catch ME
                stepResult.status = 'error';
                stepResult.message = ME.message;
            end
        end
    end

    methods (Static, Access = private)
        function notify(onStatus, type, text)
            try
                onStatus(type, text);
            catch
                % The callback is only for UI feedback; ignore failures.
            end
        end

        function [args, errorMessage] = buildArguments(skill, arguments, workdir)
            errorMessage = '';
            params = utils.ToolboxSkillRegistry.parameterArray(skill);
            ordered = utils.AIPlanExecutor.orderByPosition(params);
            paramByType = containers.Map('KeyType', 'char', 'ValueType', 'char');
            for index = 1:numel(params)
                name = char(string(params(index).name));
                paramByType(name) = char(string(params(index).type));
            end

            lastProvidedPosition = 0;
            for index = 1:numel(ordered)
                name = ordered(index).name;
                if isfield(arguments, name)
                    lastProvidedPosition = ordered(index).position;
                end
            end

            args = cell(1, numel(ordered));
            argCount = 0;
            for index = 1:numel(ordered)
                name = ordered(index).name;
                if ~isfield(arguments, name)
                    continue;
                end
                if ordered(index).position > 0 && ordered(index).position > lastProvidedPosition
                    continue;
                end
                value = arguments.(name);
                converted = utils.AIPlanExecutor.convertToMatlab(paramByType(name), value, workdir);
                if ischar(converted) && strcmp(converted, '__AIPLAN_INVALID__')
                    errorMessage = sprintf('Invalid argument ''%s'' (expected %s).', ...
                        name, paramByType(name));
                    return;
                end
                argCount = argCount + 1;
                args{argCount} = converted;
            end
            args = args(1:argCount);
        end

        function value = convertToMatlab(type, value, workdir)
            switch type
                case {'numeric', 'integer'}
                    if ischar(value) || isstring(value)
                        parsed = str2double(char(string(value)));
                        if isnan(parsed)
                            value = '__AIPLAN_INVALID__';
                        else
                            value = parsed;
                        end
                    elseif ~(isnumeric(value) && isscalar(value))
                        value = '__AIPLAN_INVALID__';
                    else
                        value = double(value);
                    end
                case {'file', 'dir', 'output'}
                    if ischar(value) || isstring(value)
                        path = char(string(value));
                        if ~isempty(workdir)
                            fileObj = java.io.File(path);
                            if ~fileObj.isAbsolute()
                                path = fullfile(workdir, path);
                            end
                        end
                        value = char(java.io.File(path).getCanonicalPath());
                    else
                        value = '__AIPLAN_INVALID__';
                    end
                case 'string'
                    if ischar(value) || isstring(value)
                        value = char(string(value));
                    elseif isnumeric(value)
                        value = num2str(value);
                    else
                        value = '__AIPLAN_INVALID__';
                    end
                otherwise
                    % list/volume/unknown types pass through; the validator
                    % already gates which skills are runnable.
            end
        end

        function ordered = orderByPosition(params)
            ordered = repmat(struct('name', '', 'position', 0), 0, 1);
            for index = 1:numel(params)
                ordered(end+1).name = char(string(params(index).name)); %#ok<AGROW>
                ordered(end).position = double(params(index).position);
            end
            if numel(ordered) > 1
                [~, order] = sort([ordered.position]);
                ordered = ordered(order);
            end
        end
    end
end

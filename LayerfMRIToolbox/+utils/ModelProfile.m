classdef ModelProfile
    % ModelProfile - selectable AI model profiles (e.g. DeepSeek vs GPT).
    %
    % Each profile describes an OpenAI-compatible endpoint, the exact model
    % string to send, and the NAME of the environment variable that holds its
    % API key. Keys are never stored in the repository.
    %
    % MATLAB translates the active profile into the OPENAI_* environment
    % variables that chatgpt_api.py already reads, right before each request,
    % so switching profiles requires no Python changes.

    methods (Static)
        function profiles = loadProfiles()
            profileFile = fullfile(fileparts(mfilename('fullpath')), 'model_profiles.json');
            if ~exist(profileFile, 'file')
                error('ModelProfile:MissingFile', 'Profile file not found: %s', profileFile);
            end
            raw = jsondecode(fileread(profileFile));
            if ~isfield(raw, 'profiles') || isempty(raw.profiles)
                error('ModelProfile:Empty', 'No model profiles are defined.');
            end
            profiles = raw.profiles;
            requiredFields = {'id', 'display', 'endpoint', 'model', 'deployment', 'key_env'};
            for index = 1:numel(profiles)
                for fieldIndex = 1:numel(requiredFields)
                    fieldName = requiredFields{fieldIndex};
                    if ~isfield(profiles(index), fieldName)
                        profiles(index).(fieldName) = '';
                    end
                end
            end
        end

        function profile = get(id)
            profiles = utils.ModelProfile.loadProfiles();
            profile = [];
            if isempty(id)
                return;
            end
            for index = 1:numel(profiles)
                if strcmpi(string(profiles(index).id), string(id))
                    profile = profiles(index);
                    return;
                end
            end
        end

        function ids = ids()
            profiles = utils.ModelProfile.loadProfiles();
            ids = cell(numel(profiles), 1);
            for index = 1:numel(profiles)
                ids{index} = char(string(profiles(index).id));
            end
        end

        function displays = displays()
            profiles = utils.ModelProfile.loadProfiles();
            displays = cell(numel(profiles), 1);
            for index = 1:numel(profiles)
                displays{index} = char(string(profiles(index).display));
            end
        end

        function status = apply(id)
            % Applies the profile to the OPENAI_* environment variables that
            % chatgpt_api.py reads. The key must be present in the profile's
            % own key_env variable; there is deliberately no fallback to
            % OPENAI_API_KEY so switching profiles can never silently reuse
            % the wrong provider's key.
            status = struct( ...
                'id', '', 'display', '', 'model', '', 'endpoint', '', ...
                'key_env', '', 'configured', false, 'key_source', '', ...
                'message', '');
            profile = utils.ModelProfile.get(id);
            if isempty(profile)
                status.message = sprintf('Unknown model profile: %s', id);
                return;
            end

            status.id = char(string(profile.id));
            status.display = char(string(profile.display));
            status.model = char(string(profile.model));
            status.endpoint = char(string(profile.endpoint));
            status.key_env = char(string(profile.key_env));

            keyValue = strtrim(getenv(status.key_env));
            status.key_source = status.key_env;

            setenv('OPENAI_API_KEY', keyValue);
            setenv('OPENAI_ENDPOINT', status.endpoint);
            setenv('OPENAI_MODEL', status.model);
            if isfield(profile, 'deployment')
                setenv('OPENAI_DEPLOYMENT', char(string(profile.deployment)));
            end
            timeoutValue = '120';
            if isfield(profile, 'timeout_seconds')
                timeoutValue = char(string(profile.timeout_seconds));
            end
            setenv('OPENAI_TIMEOUT_SECONDS', timeoutValue);

            if isempty(keyValue)
                status.configured = false;
                status.message = sprintf( ...
                    'Model "%s" key not configured. Export %s in the shell before starting MATLAB.', ...
                    status.id, status.key_env);
            else
                status.configured = true;
                status.message = sprintf('Model "%s" ready (key from %s).', status.id, status.key_env);
            end
        end

        function text = statusText(id)
            status = utils.ModelProfile.apply(id);
            if status.configured
                text = sprintf('%s - key OK (%s)', status.display, status.key_source);
            else
                text = sprintf('%s - key NOT configured (%s)', status.display, status.key_env);
            end
        end
    end
end

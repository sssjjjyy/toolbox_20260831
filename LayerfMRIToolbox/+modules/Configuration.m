classdef Configuration < handle
    properties (Access = private)
        Settings
    end
    
    methods
        function obj = Configuration()
            obj.Settings = struct();
            obj.setDefaults();
        end
        
        function value = get(obj, key)
            if isfield(obj.Settings, key)
                value = obj.Settings.(key);
            else
                error('Configuration:KeyNotFound', 'Configuration key not found: %s', key);
            end
        end
        
        function set(obj, key, value)
            obj.Settings.(key) = value;
        end
        
        function loadFromFile(obj, filename)
            if exist(filename, 'file')
                data = jsondecode(fileread(filename));
                obj.Settings = obj.mergeConfigs(obj.Settings, data);
            end
        end
    end
    
    methods (Access = private)
        function setDefaults(obj)
            obj.Settings.DefaultLayers = 10;
            obj.Settings.TimeoutSeconds = 30;
            obj.Settings.MaxRetries = 3;
            obj.Settings.RetryDelay = 1;
            obj.Settings.AutoQueryChatGPT = true;
            obj.Settings.TR_Seconds = 0.2;
            
            obj.Settings.ChatGPT_API_Key = getenv('OPENAI_API_KEY');
            obj.Settings.ChatGPT_Endpoint = getenv('OPENAI_ENDPOINT');
            obj.Settings.ChatGPT_Model = getenv('OPENAI_MODEL');
            obj.Settings.ChatGPT_Deployment = getenv('OPENAI_DEPLOYMENT');
            
            obj.Settings.DefaultImageSize = [800, 600];
            obj.Settings.DefaultFontSize = 12;
            
            obj.Settings.BaselineTime = 60;
            obj.Settings.StartTime = 10;
            obj.Settings.EndTime = 140;
            obj.Settings.PlotRange = [-0.005, 0.03];
        end
        
        function result = mergeConfigs(obj, defaults, userConfig)
            result = defaults;
            if isstruct(userConfig)
                fields = fieldnames(userConfig);
                for i = 1:length(fields)
                    field = fields{i};
                    if isstruct(userConfig.(field)) && isfield(defaults, field)
                        result.(field) = obj.mergeConfigs(defaults.(field), userConfig.(field));
                    else
                        result.(field) = userConfig.(field);
                    end
                end
            end
        end
    end
end 
classdef Logger < handle
    properties (Access = private)
        Name
        LogFile
    end
    
    methods
        function obj = Logger(name)
            obj.Name = name;
            % 创建日志文件名，使用当前时间戳
            timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
            obj.LogFile = fullfile(pwd, 'logs', sprintf('%s_%s.log', name, timestamp));
            
            % 确保日志目录存在
            if ~exist('logs', 'dir')
                mkdir('logs');
            end
            
            % 写入初始日志条目
            obj.info('Logger initialized');
        end
        
        function info(obj, message, varargin)
            obj.log('INFO', message, varargin{:});
        end
        
        function warning(obj, message, varargin)
            obj.log('WARNING', message, varargin{:});
        end
        
        function error(obj, message, varargin)
            obj.log('ERROR', message, varargin{:});
        end
        
        function debug(obj, message, varargin)
            obj.log('DEBUG', message, varargin{:});
        end
    end
    
    methods (Access = private)
        function log(obj, level, message, varargin)
            % 格式化消息
            if ~isempty(varargin)
                message = sprintf(message, varargin{:});
            end
            
            % 创建日志条目
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            logEntry = sprintf('%s [%s] %s: %s\n', timestamp, level, obj.Name, message);
            
            % 写入日志文件
            fid = fopen(obj.LogFile, 'a');
            if fid ~= -1
                fprintf(fid, '%s', logEntry);
                fclose(fid);
            end
            
            % 同时输出到命令窗口
            fprintf('%s', logEntry);
        end
    end
end 
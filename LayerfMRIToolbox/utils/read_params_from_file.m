function params = read_params_from_file(filename)
% 从文本文件中读取参数并返回一个结构体
%
% 输入:
%   - filename: 包含参数的文本文件名
%
% 输出:
%   - params: 包含参数名和值的结构体

% 打开文件
fileID = fopen(filename, 'r');

params = struct();

while ~feof(fileID)
    line = fgetl(fileID);
    

    if isempty(line) || line(1) == '%'
        continue;
    end
    
  
    [var_name, var_value] = strtok(line, '=');
    var_name = strtrim(var_name);
    var_value = strtrim(var_value(2:end));
    
    params.(var_name) = var_value;
    
end

fclose(fileID);
end
function dataset = read_dataset(filepath)
    % 打开数据集文件
    fid = fopen(filepath, 'r');
    
    % 定义结构体的字段名
    fieldNames = {'T2', 'MB', 'R', 'SEPI', 'Task_Name', 'Type_Set', 'TRs', 'Onset_Scan', 'Duration'};
    
    % 从文件中读取内容
    data = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    
    % 创建一个空结构体
    dataset = struct();
    
    % 将读取的内容赋值到结构体中
    for i = 1:numel(fieldNames)
        % 使用正则表达式将每行的内容拆分成字段名和值
        matches = regexp(data{1}{i}, '^(.*?):(.*)', 'tokens', 'once');
        % 如果匹配成功，则将字段名和值存储到结构体中
        if ~isempty(matches)
            dataset.(matches{1}) = matches{2};
        end
    end
end

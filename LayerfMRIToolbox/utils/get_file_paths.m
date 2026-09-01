function filePaths = get_file_paths(directory, searchStrings)
    % 获取指定路径下含有指定多个字符串的文件的完整路径
    %
    % 输入参数:
    %   directory: 要搜索的目录路径
    %   searchStrings: 要搜索的字符串(可以是单个字符串或字符串数组)
    %
    % 输出参数:
    %   filePaths: 匹配的文件的完整路径(字符串数组)
    
    % 检查输入参数
    if nargin < 2
        error('请提供目录路径和搜索字符串.');
    end
    
    % 确保searchStrings是一个元胞数组
    if ischar(searchStrings)
        searchStrings = {searchStrings};
    end
    
    % 获取目录下的所有文件
    files = dir(directory);
    
    % 初始化结果数组
    filePaths = {};
    
    % 遍历每个文件
    for i = 1:numel(files)
        % 跳过目录和隐藏文件
        if files(i).isdir || strcmp(files(i).name(1), '.')
            continue;
        end
        
        % 检查文件名是否包含所有搜索字符串
        if all(cellfun(@(str) contains(files(i).name, str), searchStrings))
            % 如果文件名匹配,将其完整路径添加到结果数组中
            filePaths{end+1} = fullfile(directory, files(i).name);
        end
    end
end
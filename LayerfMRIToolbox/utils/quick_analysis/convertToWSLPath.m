function wslPath = convertToWSLPath(windowsPath)
    % 检查路径是否包含盘符
    if length(windowsPath) > 2 && windowsPath(2) == ':'
        driveLetter = lower(windowsPath(1));
        % 替换反斜杠为正斜杠
        convertedPath = strrep(windowsPath(3:end), '\', '/');
        % 构建WSL路径
        wslPath = ['/mnt/' driveLetter convertedPath];
    else
        error('Invalid Windows path');
    end
end

% 示例使用
% windowsPath = 'C:\Users\Username\Documents\project';
% wslPath = convertToWSLPath(windowsPath);
% disp(wslPath);  % 输出: /mnt/c/Users/Username/Documents/project

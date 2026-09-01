function create_registration_animation(t1_img, func_img, varargin)
    % 设置默认参数
    p = inputParser;
    addRequired(p, 't1_img', @ischar);
    addRequired(p, 'func_img', @ischar);
    addParameter(p, 'z_cuts', [-20, -10, 0, 10, 20, 30], @isnumeric);
    addParameter(p, 'x_cuts', [-20, 0, 20], @isnumeric);
    addParameter(p, 'y_cuts', [-20, 0, 20], @isnumeric);
    addParameter(p, 'fps', 4, @isnumeric);
    addParameter(p, 'duration', 3, @isnumeric);
    addParameter(p, 'output_dir', pwd, @ischar);
    
    parse(p, t1_img, func_img, varargin{:});
    
    % 确保输入文件存在
    if ~exist(t1_img, 'file')
        error('结构像文件不存在: %s', t1_img);
    end
    if ~exist(func_img, 'file')
        error('功能像文件不存在: %s', func_img);
    end
    
    % 创建输出目录
    if ~exist(p.Results.output_dir, 'dir')
        mkdir(p.Results.output_dir);
    end
    
    % 构建Python命令
    z_cuts_str = sprintf('[%s]', num2str(p.Results.z_cuts, '%d,'));
    x_cuts_str = sprintf('[%s]', num2str(p.Results.x_cuts, '%d,'));
    y_cuts_str = sprintf('[%s]', num2str(p.Results.y_cuts, '%d,'));
    
    cmd = sprintf(['python registration_animation.py ' ...
                  '--t1_img "%s" ' ...
                  '--func_img "%s" ' ...
                  '--z_cuts %s ' ...
                  '--x_cuts %s ' ...
                  '--y_cuts %s ' ...
                  '--fps %d ' ...
                  '--duration %d ' ...
                  '--output_dir "%s"'], ...
                  t1_img, func_img, ...
                  z_cuts_str(1:end-1), ...
                  x_cuts_str(1:end-1), ...
                  y_cuts_str(1:end-1), ...
                  p.Results.fps, ...
                  p.Results.duration, ...
                  p.Results.output_dir);
    
    % 执行Python脚本
    [status, result] = system(cmd);
    
    % 检查执行状态
    if status ~= 0
        error('Python脚本执行失败:\n%s', result);
    else
        fprintf('动画创建成功！\n');
        fprintf('输出文件保存在: %s\n', p.Results.output_dir);
    end
end


% % 基本用法
% t1_img = 'path/to/structural.nii.gz';
% func_img = 'path/to/functional.nii.gz';
% create_registration_animation(t1_img, func_img);
% 
% % 自定义参数
% create_registration_animation(t1_img, func_img, ...
%     'z_cuts', [-30:10:30], ...
%     'x_cuts', [-30:15:30], ...
%     'y_cuts', [-30:15:30], ...
%     'fps', 6, ...
%     'duration', 4, ...
%     'output_dir', 'path/to/output');


function deface(input_path, output_path)
    % DEFACE_NII_WSL 使用 WSL 中的 FSL 对 NIfTI 文件进行去面部处理
    %   input_path: 输入 NIfTI 文件的完整路径
    %   output_path: 输出 NIfTI 文件的完整路径
    %
    % 示例:
    %   deface_nii_wsl('C:/data/sub-01.nii', 'C:/data/sub-01_defaced.nii')
    
        try
            % 检查输入文件是否存在
            if ~exist(input_path, 'file')
                error('Input file does not exist: %s', input_path);
            end
            
            % 创建输出目录（如果不存在）
            [output_dir, ~, ~] = fileparts(output_path);
            if ~exist(output_dir, 'dir')
                mkdir(output_dir);
            end
            
            % 转换Windows路径为WSL路径
            wsl_input = convert_to_wsl_path(input_path);
            wsl_output = convert_to_wsl_path(output_path);
            
            % 创建临时文件用于重新定向
            [~, input_name, ext] = fileparts(input_path);
            wsl_reoriented = convert_to_wsl_path(fullfile(output_dir, [input_name '_reoriented' ext]));
            
            % 构建WSL命令
            wsl_cmd = sprintf(['wsl -e bash -c "', ...
                'export FSLDIR=/usr/local/fsl && ', ...
                'source $FSLDIR/etc/fslconf/fsl.sh && ', ...
                'export PATH=/usr/local/fsl/bin/:$PATH && ', ...
                'fslreorient2std %s %s && ', ...
                'fsl_deface %s %s"'], ...
                wsl_input, wsl_reoriented, wsl_reoriented, wsl_output);
            
            % 执行WSL命令
            [status, cmdout] = system(wsl_cmd);
            
            % 检查命令执行状态
            if status ~= 0
                error('FSL command failed with output:\n%s', cmdout);
            end
            
            % 删除临时的重定向文件
            if exist(fullfile(output_dir, [input_name '_reoriented' ext]), 'file')
                delete(fullfile(output_dir, [input_name '_reoriented' ext]));
            end
            
            fprintf('Successfully defaced %s\nOutput saved to %s\n', input_path, output_path);
            
        catch ME
            % 错误处理
            error('Error in deface_nii_wsl: %s', ME.message);
        end
    end
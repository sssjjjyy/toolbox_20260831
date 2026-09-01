function processData(code_path,envName,inputType, raw_dir,base_dir,scanIDs,refIDs,name)
    % processData - 根据输入类型调用不同的处理函数
    % 输入参数:
    %   inputType - 字符串，'dicom' 或 'multiband'

    if strcmp(inputType, 'dicom')
        % 创建scan编号文件夹的函数并转换为nii文件
        % code_path = 'C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\utils';
        if ispc
            dcm2niix_cmd = fullfile(code_path, 'dcm2niix', 'dcm2niix_win', 'dcm2niix.exe');
        elseif isunix
            if ismac
                dcm2niix_cmd = fullfile(code_path, 'dcm2niix', 'dcm2niix_macos', 'dcm2niix');
            else
                dcm2niix_cmd = fullfile(code_path, 'dcm2niix', 'dcm2niix_lnx', 'dcm2niix');
            end
        else
            error('Unsupported operating system');
        end
        % Ensure dcm2niix exists
        if exist(dcm2niix_cmd, 'file')
            disp(['dcm2niix executable found at: ', dcm2niix_cmd]);
        else
            error('dcm2niix executable not found. Please check the path.');
        end

        for i = 1:length(scanIDs)
            scan_num = scanIDs;
            scan_num_str = num2str(scan_num); % 将scan_num转换为字符类型
            scan_folder = fullfile(base_dir, scan_num_str);
            if ~exist(scan_folder, 'dir')
                mkdir(scan_folder);
            end

            file_name = [name '_' scan_num_str];

            % dcm2niix_cmd = dcm2niix_use();
            dicom_dir = fullfile(raw_dir, scan_num_str, 'pdata', '1', 'dicom');

            % Check if the DICOM directory exists
            if ~exist(dicom_dir, 'dir')
                warning('DICOM directory does not exist for scan %s: %s', scan_num_str, dicom_dir);
            end

            % cmd = sprintf('"%s" -o "%s" -f %%f_%%p_%%t_%%s -z n "%s"', dcm2niix_cmd, scan_folder, dicom_dir);
            cmd = sprintf('"%s" -o "%s" -f "%s" -z n "%s"', dcm2niix_cmd, scan_folder, file_name, dicom_dir);
            % Execute the command
            [status, result] = system(cmd);
            if status ~= 0
                warning('Error converting scan %s: %s', scan_num_str, result);
            else
                fprintf('Successfully converted scan %s\n', scan_num_str);       
            end
        end

    elseif strcmp(inputType, 'multiband')
            scan_num = scanIDs;
            scan_num_str = num2str(scan_num); % 将scan_num转换为字符类型
            scan_folder = fullfile(base_dir, scan_num_str);
            if ~exist(scan_folder, 'dir')
                mkdir(scan_folder);
            end
            file_name = [name '_' scan_num_str];
            MB_path = fullfile(raw_dir, num2str(scanIDs));
            R_path = fullfile(raw_dir, num2str(refIDs));
            O_BOLD_path = scan_folder;
            % 检查 MB_path 和 R_path 是否存在
            if ~exist(MB_path, 'dir') || ~exist(R_path, 'dir')
                warning('MB_path or R_path does not exist for scan %s: %s, %s', scan_num_str, MB_path, R_path);
            end

            % currentEnv = pyenv;
            % if currentEnv.Status == "NotLoaded"
            %     % 配置 Python 环境
            %     pyenv('Version', 'C:\Users\zhuyt12023\.conda\envs\py38\python.exe');
            % end
            % %%配置自己的python环境，以及auto_mbconvert代码文件夹路径
            % if count(py.sys.path, 'C:\Users\zhuyt12023\Desktop\layerfmri-ui\layerfmri_code\utils') == 0
            %     insert(py.sys.path, int32(0), 'C:\Users\zhuyt12023\Desktop\layerfmri-ui\layerfmri_code\utils');
            % end
            % auto_mbconvert_module = py.importlib.import_module('auto_mbconvert');
            
            % result = auto_mbconvert_module.auto_mbconvert(MB_path, R_path, O_BOLD_path, file_name);
            % % 将 result 转换为 MATLAB 字符串类型
            % result_str = char(result);
            % disp(result_str);


            % code_path = 'C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\utils';
            % envName = 'layerfmri';
            amname = 'auto_mbconvert.py';
            generatePath = fullfile(code_path,amname);
            pythonCommand = sprintf('conda activate %s && python %s %s %s %s %s', envName, generatePath, MB_path, R_path, O_BOLD_path, file_name);
            [status, cmdout] = system(pythonCommand);
            if status == 0
                disp('Script executed successfully! Conversion completed! ');
                disp(cmdout);
            else
                disp('Error executing Python script. Conversion failed.');
                disp(cmdout);
            end
             
    end
end

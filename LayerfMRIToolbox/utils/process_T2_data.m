function target_file_nii = process_T2_data(working_dir, working_subject, T2_folder, sub_num, bids_root)
    % 处理T2数据

    % 定义源目录
    source_dir = fullfile(working_dir, working_subject, T2_folder, 'pdata', '1', 'dicom');

    % 定义目标目录
    sub_dir = fullfile(bids_root, ['sub-' num2str(sub_num)]);
    target_dir = fullfile(sub_dir, 'anat');

    % 确保目标目录存在
    if ~exist(target_dir, 'dir')
        mkdir(target_dir);
    end

    % 处理NIfTI文件和JSON文件
    files = dir(fullfile(source_dir, '*.nii'));
    for i = 1:length(files)
        source_file_nii = fullfile(files(i).folder, files(i).name);
        source_file_json = replace(source_file_nii, '.nii', '.json');
        
        % 生成目标文件名
        target_file_nii = fullfile(target_dir, ['sub-' num2str(sub_num) '_T2w.nii']);
        target_file_json = fullfile(target_dir, ['sub-' num2str(sub_num) '_T2w.json']);

        % 复制文件到BIDS目录
        copyfile(source_file_nii, target_file_nii);
        if exist(source_file_json, 'file')
            copyfile(source_file_json, target_file_json);
        end
    end
end

function target_file_nii_set = process_EPI_data(working_dir, working_subject, task, type, EPI_folders, sub_num, bids_root,events)
    % 处理EPI数据
    target_file_nii_set = {};
    for folder_idx = 1:length(EPI_folders)
        % 定义源目录
        source_dir = fullfile(working_dir, working_subject, EPI_folders, 'pdata', '1', 'dicom');
        
        % 定义目标目录
        
        sub_dir = fullfile(bids_root, ['sub-' num2str(sub_num)]);
        target_dir = fullfile(sub_dir, 'func');

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
            target_file_basename = ['sub-',num2str(sub_num),'_task-',string(task)];

            series_num = EPI_folders;
            series_num = string(series_num);
            
            if ~isempty(type)
                target_file_basename = [target_file_basename '_' string(type)];
                if(task ~= "rest")
                    generate_task_tsv(target_dir,sub_num,task,series_num,events,type);
                end
            end
            target_file_basename = [target_file_basename '_run-' series_num];
            target_file_nii_basename = [target_file_basename '_bold.nii'];
            target_file_nii_basename = strjoin(target_file_nii_basename, "");
            target_file_json_basename =  [target_file_basename '_bold.json'];
            target_file_json_basename = strjoin(target_file_json_basename, "");

            target_file_nii = fullfile(target_dir, target_file_nii_basename);
            target_file_json = fullfile(target_dir, target_file_json_basename);

            target_file_nii_set{folder_idx} = target_file_nii;
            % 复制文件到BIDS目录
            copyfile(source_file_nii, target_file_nii);
            copyfile(source_file_json, target_file_json);
        end
    end
end

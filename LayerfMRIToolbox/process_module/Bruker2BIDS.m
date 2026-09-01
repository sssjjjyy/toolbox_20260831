function [target_files, T2_files] = Bruker2BIDS(subjects, working_dirs, output_dir, task_names, type_set)
    % Bruker2BIDS - Convert Bruker data to BIDS format
    %
    % Inputs:
    %   subjects     - Cell array of subject folder names
    %   working_dirs - Cell array of working directories
    %   output_dir   - Output directory for BIDS data
    %   task_names   - Cell array of task names
    %   type_set     - Type settings for conversion
    %
    % Outputs:
    %   target_files - Cell array of converted target files
    %   T2_files     - Cell array of T2 files
    
    target_files = cell(1, numel(subjects));
    T2_files = cell(1, numel(subjects));
    
    for j = 1:numel(subjects)
        subject_folder = subjects{j};
        working_dir = working_dirs{j};
        dataset_name = 'sourcedata';
        
        % Get subject number
        sub_num = regexp(subject_folder, '\d+', 'match');
        sub_num = strcat(sub_num{3}, sub_num{4});
        
        % Read dataset
        dataset_txt = fullfile(working_dir, subject_folder, 'dataset.txt');
        dataset = read_dataset(dataset_txt);
        
        % Get T2 and EPI data
        T2 = {dataset.T2};
        EPI = {dataset.EPI1, dataset.EPI2};
        
        % Process events
        events = create_events_struct(dataset);
        
        % Convert to BIDS
        [target_files{j}, T2_files{j}] = rsfmri_bruker2bids(working_dir, output_dir, ...
            subject_folder, dataset_name, sub_num, task_names, ...
            type_set, T2, EPI, events);
    end
end

function Dicom2Nifti(subjects, working_dirs)
    % Dicom2Nifti - Convert DICOM files to NIfTI format
    %
    % Inputs:
    %   subjects     - Cell array of subject folder names
    %   working_dirs - Cell array of working directories
    %
    % Example:
    %   subjects = {'subject1', 'subject2'};
    %   working_dirs = {'/path/to/dir1', '/path/to/dir2'};
    %   Dicom2Nifti(subjects, working_dirs);
    
    for i = 1:numel(subjects)
        subject_folder = subjects{i};
        working_dir = working_dirs{i};
        
        % Read dataset information
        dataset_txt = fullfile(working_dir, subject_folder, 'dataset.txt');
        dataset = read_dataset(dataset_txt);
        
        % Extract T2 and EPI data
        T2 = {dataset.T2};
        EPI = {dataset.EPI1, dataset.EPI2};
        
        % Handle multiple EPI1 entries
        if contains(dataset.EPI1, ',')
            dataset.EPI1 = strsplit(dataset.EPI1, ',');
            EPI = {dataset.EPI1{:}, dataset.EPI2};
        end
        
        % Convert files to NIfTI format
        rsfmri_dicom2nifti_batch(working_dir, subject_folder, [T2, EPI]);
    end
end
function rsfmri_dicom2nifti(working_path, working_subject, scan_set)
    %DICOM2NIFTI_BATCH - Batch converts Bruker DICOM to NIfTI format
    % working_path: Root pathectory of data collection
    % working_subject: Specific data collection pathectory
    % scan_set: Set of scans to be converted (e.g., {'11','12','13'})
    % code_path: Path to the code pathectory
    % Detect the operating system
    [~, functionName, ~] = fileparts(mfilename('fullpath'));
    currentPath = fileparts(which(functionName));
    code_path = fileparts(currentPath);
    if ispc
        dcm2niix_cmd = fullfile(code_path, 'utils', 'dcm2niix', 'dcm2niix_win', 'dcm2niix.exe');
    elseif isunix
        if ismac
            dcm2niix_cmd = fullfile(code_path, 'utils', 'dcm2niix', 'dcm2niix_macos', 'dcm2niix');
        else
            dcm2niix_cmd = fullfile(code_path, 'utils', 'dcm2niix', 'dcm2niix_lnx', 'dcm2niix');
        end
    else
        error('Unsupported operating system');
    end

    % Ensure dcm2niix exists
    if ~exist(dcm2niix_cmd, 'file')
        error('dcm2niix executable not found. Please check the path.');
    end

    % Loop over each scan in the scan set
    for i = 1:length(scan_set)
        % Construct the full path to the DICOM pathectory
        dicom_path = fullfile(working_path, working_subject, scan_set{i}, 'pdata', '1', 'dicom');
        
        % Check if the DICOM pathectory exists
        if ~exist(dicom_path, 'path')
            warning('DICOM pathectory does not exist for scan %s: %s', scan_set{i}, dicom_path);
            continue;
        end

        % Construct the command to run dcm2niix
        cmd = sprintf('"%s" -o "%s" -f %%f_%%p_%%t_%%s -z n "%s"', dcm2niix_cmd, dicom_path, dicom_path);

        % Execute the command
        [status, result] = system(cmd);
        if status ~= 0
            warning('Error converting scan %s: %s', scan_set{i}, result);
        else
            fprintf('Successfully converted scan %s\n', scan_set{i});
        end
    end
end

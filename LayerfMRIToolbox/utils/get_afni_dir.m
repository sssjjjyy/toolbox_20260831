function afni_dir = get_afni_dir()

[status, afni_path] = system('wsl -d Ubuntu-18.04 -e ');


if status ~= 0
    error('Failed to retrieve AFNI path using "which afni" command.');
end


afni_path = strtrim(afni_path);


[afni_dir, ~, ~] = fileparts(afni_path);


if afni_dir(end) ~= '/'
    afni_dir = [afni_dir, '/'];
end
end
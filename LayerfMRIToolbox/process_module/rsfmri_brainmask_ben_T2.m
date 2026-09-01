function rsfmri_brainmask_ben_T2(input_path_exclude, ben_output_path_exclude, weight_path,env_name)
%UNTITLED4 此处提供此函数的摘要
%   此处提供详细说明
command = ['conda activate ', env_name, ' && python BEN_infer.py -i ', input_path_exclude, ' -o ', ben_output_path_exclude, ' -w ', weight_path];
system(command);
end
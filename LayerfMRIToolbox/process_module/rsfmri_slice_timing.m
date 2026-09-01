function rsfmri_slice_timing(data_path_exclude,slice_order,timing,prefix)
%RSFMRI_SLICE_TIMING 此处显示有关此函数的摘要
%   此处显示详细说明
spm_slice_timing(data_path_exclude,slice_order,length(slice_order)/2,timing,prefix);
end


function rsfmri_motion_correction(input_name_exclude,voxel_size_f,prefix)
%RSFMRI_MOTION_CORRECTION 此处显示有关此函数的摘要
%   此处显示详细说明
longTR_Realignment(input_name_exclude,voxel_size_f);
longTR_Reslice(input_name_exclude,prefix);
end


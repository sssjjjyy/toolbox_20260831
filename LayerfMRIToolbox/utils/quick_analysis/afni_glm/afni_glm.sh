#!/bin/bash

export PATH=$HOME/abin:$PATH

epipath=$1
motion_file=$2
inputfile=$3

cd "${epipath}"

if [ ! -f motion_params.1D ]; then
    mv "${motion_file}" motion_params.1D
fi

# # 仅仅构建设计矩阵并拟合 GLM
# 3dDeconvolve -input "${inputfile}" \
#              -polort A \
#              -num_stimts 7 \
#              -stim_times 1 auditory.1D 'BLOCK(10,1)' -stim_label 1 auditory \
#              -stim_file 2 motion_params.1D[0] -stim_base 2 -stim_label 2 roll \
#              -stim_file 3 motion_params.1D[1] -stim_base 3 -stim_label 3 pitch \
#              -stim_file 4 motion_params.1D[2] -stim_base 4 -stim_label 4 yaw \
#              -stim_file 5 motion_params.1D[3] -stim_base 5 -stim_label 5 dS \
#              -stim_file 6 motion_params.1D[4] -stim_base 6 -stim_label 6 dL \
#              -stim_file 7 motion_params.1D[5] -stim_base 7 -stim_label 7 dP \
#              -fout -tout \
#              -bucket stats_output

# 3dcalc -a stats_output+orig'[3]' -expr 'fitt_t2p(a,617)' -prefix p_values_output

# 3dAFNItoNIFTI -prefix stats_output.nii stats_output+orig
# 3dAFNItoNIFTI -prefix p_output.nii p_values_output+orig


# Step 1: 构建设计矩阵但不做拟合（用于 REML）
3dDeconvolve -input "${inputfile}" \
             -polort A \
             -num_stimts 7 \
             -stim_times 1 auditory.1D 'BLOCK(10,1)' -stim_label 1 auditory \
             -stim_file 2 motion_params.1D[0] -stim_base 2 -stim_label 2 roll \
             -stim_file 3 motion_params.1D[1] -stim_base 3 -stim_label 3 pitch \
             -stim_file 4 motion_params.1D[2] -stim_base 4 -stim_label 4 yaw \
             -stim_file 5 motion_params.1D[3] -stim_base 5 -stim_label 5 dS \
             -stim_file 6 motion_params.1D[4] -stim_base 6 -stim_label 6 dL \
             -stim_file 7 motion_params.1D[5] -stim_base 7 -stim_label 7 dP \
             -x1D X.xmat.1D -x1D_stop \
             -xjpeg design_matrix.jpg


# Step 2: 用 REML 拟合模型
3dREMLfit -matrix X.xmat.1D \
          -input "${inputfile}" \
          -Rbuck stats_output_REML \
          -Rerrts errts_REML \
          -fout -tout

3dcalc -a mask.nii -expr 'a' -prefix mask -datum byte

3dClustSim -mask mask+orig \
           -fwhmxyz 0.1875 0.1875 0.6 \
           -both -prefix ClustSim_classic

3dClusterize -inset stats_output_REML+orig \
             -ithr 0 -idat 0 \
             -2sided p=0.001 \
             -NN 2 -clust_nvox 20 \
             -pref_map thr_map_REML
3dAFNItoNIFTI -prefix thr_map.nii thr_map_REML+orig
3dAFNItoNIFTI -prefix stats_output_t.nii stats_output_REML+orig[2]
3dAFNItoNIFTI -prefix stats_output_f.nii stats_output_REML+orig[0]
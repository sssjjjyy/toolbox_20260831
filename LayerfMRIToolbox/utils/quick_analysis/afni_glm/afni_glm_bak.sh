#!/bin/bash

export PATH=$HOME/abin:$PATH

epipath=$1
motion_file=$2
inputfile=$3
block_duration=$4
TR=$5

cd "${epipath}"

if [ ! -f motion_params.1D ]; then
    mv "${motion_file}" motion_params.1D
fi

3dDeconvolve -input "${inputfile}" \
             -polort A \
             -num_stimts 7 \
             -stim_times 1 stim.1D "BLOCK(${block_duration},1)  LOCAL" -stim_label 1 stim \
             -stim_file 2 motion_params.1D[0] -stim_base 2 -stim_label 2 roll \
             -stim_file 3 motion_params.1D[1] -stim_base 3 -stim_label 3 pitch \
             -stim_file 4 motion_params.1D[2] -stim_base 4 -stim_label 4 yaw \
             -stim_file 5 motion_params.1D[3] -stim_base 5 -stim_label 5 dS \
             -stim_file 6 motion_params.1D[4] -stim_base 6 -stim_label 6 dL \
             -stim_file 7 motion_params.1D[5] -stim_base 7 -stim_label 7 dP \
             -TR_times ${TR} \
             -fout -tout \
             -bucket stats_output

3dcalc -a stats_output+orig'[3]' -expr 'fitt_t2p(a,617)' -prefix p_values_output

3dAFNItoNIFTI -prefix stats_output.nii stats_output+orig
3dAFNItoNIFTI -prefix p_output.nii p_values_output+orig
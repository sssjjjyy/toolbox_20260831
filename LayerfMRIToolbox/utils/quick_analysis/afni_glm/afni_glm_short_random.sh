#!/bin/bash
export PATH=$HOME/abin:$PATH

epipath=$1
inputfile=$2
TR=$3

cd "${epipath}"

3dDeconvolve -input "${inputfile}" \
             -polort A \
             -num_stimts 1 \
             -stim_times_AM1 1 stim.1D "dmBLOCK(1) LOCAL" -stim_label 1 stim \
             -TR_times ${TR} \
             -fout -tout \
             -bucket stats_output

3dcalc -a stats_output+orig'[3]' -expr 'fitt_t2p(a,617)' -prefix p_values_output

3dAFNItoNIFTI -prefix stats_output.nii stats_output+orig
3dAFNItoNIFTI -prefix p_output.nii p_values_output+orig

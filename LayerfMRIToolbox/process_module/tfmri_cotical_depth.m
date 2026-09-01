function tfmri_cotical_depth(rim_path_exclude,voxel_size,iter_times,convergence_threshold,mean_epi_path_exclude)
    computeThickness(rim_path_exclude, voxel_size, iter_times, convergence_threshold, mean_epi_path_exclude, true);
    computeThickness(rim_path_exclude, voxel_size, iter_times, convergence_threshold, mean_epi_path_exclude, false);
    normDepth('laplace_layer_thickness_forward.nii', 'laplace_layer_thickness_unforward.nii', mean_epi_path_exclude);
end


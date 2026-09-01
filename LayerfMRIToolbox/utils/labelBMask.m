function layers_data = labelBMask(MasklayerFigure,mask, header,rawfile,output_dir,num_layers)
cd(output_dir);
header.dt = [64,0];
rp_Write4DNIfTI(mask,header,'rim.nii');
layers_by_laynii('rim.nii',num_layers,true,1);
% layers_data = spm_read_vols(spm_vol('rim_layers_equivol.nii'));
% layers_data(layers_data == 0)=NaN;
layers_data = spm_read_vols(spm_vol('rim_metric_equivol.nii'));
layers_data(isnan(layers_data)) = 0;
layers_data(layers_data == 0) = nan;
map = discretize_values(layers_data);
map(isnan(map)) = 0;
saveMapAsNifti(map,'rim_layers.nii','rim_metric_equivol.nii');%%rim.nii是长TR多层的，生成3层的rim_3slice_layers.nii结果
layers_data = spm_read_vols(spm_vol('rim_layers.nii'));
layers_data(layers_data == 0)=NaN;

% bg_epi = spm_read_vols(spm_vol(rawfile));
bg_epi = rawfile(:,:,:,1);
% Generate distinguishable colors for visualization
colors = distinguishable_colors(num_layers, [1 1 1; 0 0 0]);

% Create a figure for visualization
fig = figure(MasklayerFigure);
imoverlay(rot90(bg_epi(:, :), 1), rot90(layers_data(:, :), 1), [1 num_layers], [], colors, 1, fig);
% Set colormap and colorbar
colormap(colors);
cb = colorbar;
% Hide colorbar tick marks
cb.TickLength = 0;
% Divide colorbar into n blocks and place labels at block centers
n = num_layers;
cb.Ticks = linspace(cb.Limits(1), cb.Limits(2), n + 1) + (cb.Limits(2) - cb.Limits(1)) / (2 * n);
cb.TickLabels = 1:num_layers;
% Export the visualization as an image file
export_fig(['layer_seg'],'-r','300')

end

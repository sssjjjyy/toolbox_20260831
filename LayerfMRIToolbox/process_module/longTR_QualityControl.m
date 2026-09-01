function longTR_QualityControl(path,rotation)
%longTR_QualityControl: This function is to generate a series of quality
%assessment images to assess the MRI image quality
%   root_path : the path of data location
%   scan_name : the set of scan name
%   type : T2 or EPI
%   output_path: output directory
%   For details about every quality assess index, refer to https://layerfmri.com/2020/04/06/qa/
% 修改文件名 修改tsnr的范围（0-25） 修改colormap（jet） 画mask 确定肌肉组织信号 将白边去掉
load('tSNRColorbar.mat')
scan_path = path;
[path_folder,data_name,~] = fileparts(scan_path);
qa_dir = fullfile(path_folder,[data_name,'_qa']);
if ~exist(qa_dir, 'dir')
    mkdir(qa_dir);
end
cd(qa_dir);
copyfile(scan_path,pwd);
system(['LN_SKEW -input ',data_name,'.nii']);
delete([data_name,'.nii']);
metrics = {'_tSNR', '_autocorr', '_imageSNR', '_kurt', '_local_gradient', ...
    '_mean', '_noise', '_overall_correl', '_skew', '_stedev'};
colormaps = {tSNRColormap,'jet','jet','jet','jet','jet','jet','jet','jet','jet'};
colorbar_set = [[0 25];[0.2 0.9];[0 30];[-1 1];[0 4000]; [0 1200]; [0 14000];[0 1];[-1 1];[0 22000]];
data = cell(1, numel(metrics));

for j = 1:numel(metrics)
    metric_path = fullfile(pwd, [data_name, metrics{j}, '.nii']);
    data{j} = spm_read_vols(spm_vol(metric_path));
end

for j = 1:numel(metrics)
    fig = figure('Position', [0 0 1480 346]);
    column = 7;
    row = ceil(size(data{j}, 3)/column);
    tiledlayout(row, column,"TileSpacing","none");
    for z = 1:size(data{j}, 3)
        nexttile
        imagesc(rot90(data{j}(:, :, z),rotation));
        caxis(colorbar_set(j,:));
        axis off
    end
    colormap(colormaps{j});
    cb = colorbar;
    cb.Layout.Tile = 'east';
    exportgraphics(fig, [data_name,'.nii', metrics{j}, '.png'], 'Resolution', '300');
    close(fig);
end

end


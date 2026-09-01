function LongTR_immediate_analysis(filename, TR, prestim_num, stim_num, interstim_num, poststim_num, block_num, fwhm_1, thresh_values, cluster_ext_values,FD_thrs,duration_input, type,hrf_type)

addpath(genpath('C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\'))
addpath('C:\matlabtool\spm12')

% filename='C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\b2n_test\auditory\derivative\20240525_415\9\longTR_9.nii';
% TR=1;%mouse 
% prestim_num=30;  % Number of Scans Before First Task Block
% stim_num=10;     % Number of Scans In Task Block
% interstim_num=30; % Number of Scans Between Task Blocks
% poststim_num=30; % Number of Scans After Last Task Block
% block_num=15; % Number of Task Blocks
% thresh_values = [0.01, 0.05]; % Example threshold values
% cluster_ext_values = [10, 20]; % Example cluster extent values
% FD_thrs = 1;
% duration_input=10;
% type = 'mouse';
% hrf_type = 'mouse_auditory'; % Options: 'mouse_auditory', 'mouse_whisker', 'none'

[pathstr, scan_name, extension] = fileparts(filename);
working_dir = pathstr;
cd(working_dir)

if(~exist(fullfile(working_dir,[scan_name,extension]),'file'))
    copyfile(filename,working_dir);
end

results_dir = working_dir;

tSNR_thrs = 7.5;
thrs=0.12;
% T_removed=0;           % the number of intial volumes for removal
if strcmp(type, 'mouse')
    dis_radius = 3; %mouse是3 rat是5
    BG_factor = 108 * 64;
elseif strcmp(type, 'rat')
    dis_radius = 5;
    BG_factor = 106 * 84;
else
    error('Invalid type. Type must be either "mouse" or "rat".');
end

onset=[zeros(1,prestim_num),repmat([ones(1,stim_num) zeros(1,interstim_num)],1,block_num - 1),ones(1,stim_num),zeros(1,poststim_num)];
onset_scan = prestim_num:(stim_num+interstim_num):(prestim_num+(stim_num+interstim_num)*block_num-interstim_num+poststim_num-1);

% initiate customized colormap
mymap_positive = colormap(autumn);
mymap_negative = colormap(winter);
mymap_negative = flipud(mymap_negative);
mymap=[mymap_negative;mymap_positive];
close all

% initialize SPM
spm('Defaults','fMRI');
spm_jobman('initcfg');

% plot tSNR
copyfile([scan_name,'.nii'],[scan_name,'_bak.nii'])
nii_info = niftiinfo([scan_name,'.nii']);
voxel_size = nii_info.PixelDimensions;
header=spm_vol([scan_name,'.nii']);
% voxel_size=[abs(header(1).mat(1,1)) abs(header(1).mat(2,2)) abs(header(1).mat(3,3))];
voxel_size = voxel_size(1:3);
disp(voxel_size)
% sorted_voxel_size = sort(voxel_size);
% FWHM = [sorted_voxel_size(1) * 1.5, sorted_voxel_size(2) * 1.5, sorted_voxel_size(3)];
% [~, original_order] = sort(voxel_size);
% FWHM = FWHM(original_order);
% % FWHM = 1.5 * voxel_size;
% % FWHM=[0.1875 0.1875 0.4]; %1.5倍 mouse
% % FWHM=[0.225 0.225 0.5]; %1.5倍 rat 

img=double(niftiread([scan_name,'.nii']));
% img=double(spm_read_vols(header));
dim = size(img);
func_2Dimg = reshape(img, dim(1)*dim(2)*dim(3), dim(4));
func_mean = mean(func_2Dimg, 2);
func_stdimev = std(func_2Dimg, 0, 2);
tSNR_2Dimg = func_mean./func_stdimev;
tSNR_3Dimg = reshape(tSNR_2Dimg, dim(1), dim(2), dim(3));
header_output = header(1);
header_output.fname = [scan_name,'_tSNR.nii'];
spm_write_vol(header_output, tSNR_3Dimg);
tSNR_3Dimg_thrs = tSNR_3Dimg;
tSNR_3Dimg_thrs(tSNR_3Dimg_thrs<tSNR_thrs)=NaN;
row = ceil(size(tSNR_3Dimg_thrs,3)/7);
figure('Position',[0 0 1488 172 * row]) %1488 172
for z=1:size(tSNR_3Dimg_thrs,3)
    h = subplottight(row, 7,z);
    [hF,hB] = imoverlay(rot90(img(:,:,z,1),1),rot90(tSNR_3Dimg_thrs(:,:,z),1),[0 25],[],jet,1,h);
end
colormap(jet);
% Adjust the position of the colorbar
h = gcf;
pos = get(h, 'Position');
colorbar('Position', [0.35 0.48 0.3 0.02], 'Orientation', 'horizontal'); % Adjust the position as needed

% colorbar;
export_fig([scan_name,'_tSNR_thrs.bmp'],'-r','300');

% realignment using AFNI
afni_dir = '/home/zhu_13579/abin/';
input_name = win2wsl(fullfile(results_dir,[scan_name,'.nii']));
afni_input_path = generate_prefix_path(fullfile(results_dir,[scan_name,'+orig.BRIK']),'r');
afni_input_path = win2wsl(afni_input_path);
system(['wsl', afni_dir, '3dvolreg -base 0 -cubic -zpad 1 -1Dfile rp_', scan_name, '.txt -1Dmatrix_save mat_vr.aff12.1D -prefix r', scan_name, ' ', input_name]);
system(['wsl', afni_dir, '3dAFNItoNIFTI ',afni_input_path]);

%%创建mean文件
% rsub=spm_read_vols(spm_vol(['r',scan_name,'.nii']));
rsub=niftiread(['r',scan_name,'.nii']);
mean_sub=mean(rsub,4);
header_mean = header(1);
header_mean.fname = ['mean',scan_name,'.nii'];
spm_write_vol(header_mean, mean_sub);

% plot motion parameters
motion=load([results_dir,'/rp_',scan_name,'.txt']);
figure;
subplot(3,1,1);
plot(motion(:,4:6))
xlim([0 size(motion,1)])
title('Translation')  
subplot(3,1,2); 
plot(motion(:,1:3))
xlim([0 size(motion,1)])
title('Rotation')  

motion_diff=zeros(size(motion));
temp=motion;
temp(:,1:3)=dis_radius*(pi/180)*temp(:,1:3); % displacement on surface of a r=3mm sphere
for x=2:size(motion,1)
    motion_diff(x,:)=temp(x,:)-temp(x-1,:);
end
motion_diff=abs(motion_diff);
framewise=sum(motion_diff,2);
    
subplot(3,1,3); 
plot(framewise)
xlim([0 size(framewise,1)])
title('FD')  
hold on
current_start = prestim_num + 1;
for i = 1 : block_num
x = current_start : current_start + stim_num - 1;
y = zeros(1, stim_num);
plot(x, y, 'r-', 'LineWidth', 2);
current_start = x(end) + interstim_num + 1;
end
hold off
export_fig([scan_name,'_motion.png'],'-r','300')

% smoothing
% --- Smoothing ---
% 若 fwhm_1 = 0，则直接拷贝输入文件为输出文件，并跳过 smoothing
if fwhm_1 == 0
    copyfile(['r', scan_name, '.nii'], ['sr', scan_name, '.nii']);
    fprintf('FWHM = 0, 跳过平滑，直接复制文件。\n');
else
    EPIfilename_header=spm_vol(['r',scan_name,'.nii']);
    % img_4D=spm_read_vols(EPIfilename_header);
    img_4D=niftiread(['r',scan_name,'.nii']);
    img_4D=rsfmri_smooth(img_4D,fwhm_1,voxel_size(1));
    img_4D(isnan(img_4D))=0;
    EPIfilename_header(1).dt(1)=64;
    rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['sr',scan_name,'.nii']);
end

% EPIfilename_header=spm_vol(['r',scan_name,'.nii']);
% % img_4D=spm_read_vols(EPIfilename_header);
% img_4D=niftiread(['r',scan_name,'.nii']);
% img_4D=rsfmri_smooth(img_4D,fwhm_1,voxel_size(1));
% img_4D(isnan(img_4D))=0;
% EPIfilename_header(1).dt(1)=64;
% rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['sr',scan_name,'.nii']);

% regression of motion signals
EPIfilename_header=spm_vol(['sr',scan_name,'.nii']);
% img_4D=spm_read_vols(EPIfilename_header);
img_4D=niftiread(['sr',scan_name,'.nii']);
motion_demean=zeros(size(motion));
for x=1:size(motion,1)
    motion_demean(x,:) = motion(x,:) - mean(motion);
end
img_mask=ones(dim(1),dim(2),dim(3));
img_4D=rsfmri_regression(img_4D,motion_demean,img_mask);
rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['sr',scan_name,'_regressed.nii']);

% calculate cross-correlation map
mean_img=mean(img_4D,4);
img_idx=find(mean_img>0);
img_2D=reshape(img_4D,[dim(1)*dim(2)*dim(3),dim(4)]);
img_2D_brain=img_2D(img_idx,:);
corr_map=corr(onset',img_2D_brain');
corr_3D=zeros(dim(1),dim(2),dim(3));
corr_1D=reshape(corr_3D, [dim(1)*dim(2)*dim(3),1]);
corr_1D(img_idx)=corr_map;
corr_3D=reshape(corr_1D,[dim(1),dim(2),dim(3)]);
header=EPIfilename_header(1);
header.fname=['sr',scan_name,'_regressed_cc_map.nii'];
spm_write_vol(header,corr_3D);


% plot the unthresholded cross-correlation map
% ana=spm_read_vols(spm_vol(['mean',scan_name,'.nii']));
ana=niftiread(['mean',scan_name,'.nii']);
figure('Position',[0 0 1488 688])
for z=1:size(ana,3)
    h = subplottight(4,7,z);
    [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(corr_3D(:,:,z),1),[-0.2 0.2],[],jet,1,h);
end
colormap(jet);
% Adjust the position of the colorbar
h = gcf;
pos = get(h, 'Position');
% colorbar('Position', [0.99 0.1 0.995 0.8]); % Adjust the position as needed
colorbar('Position', [0.35 0.48 0.3 0.02], 'Orientation', 'horizontal'); % Adjust the position as needed
% colorbar;
export_fig([scan_name,'_cc_unthresholded.bmp'],'-r','300')

% plot the thresholded cross-correlation map
% Define multiple threshold values
thrs_values = [0.12, 0.15, 0.2]; % Example threshold values
for thrs = thrs_values
    % disp(['Threshold: ', num2str(thrs)])
    corr_3D_thresh = corr_3D; % Create a copy to preserve the original data
    corr_3D_thresh(abs(corr_3D_thresh) < thrs) = NaN;
    % Create a figure
    figure('Position', [0 0 1488 688])
    % Loop over each slice
    for z = 1:size(ana, 3)
        h = subplottight(4, 7, z);
        [hF, hB] = imoverlay(rot90(ana(:, :, z, 1), 1), rot90(corr_3D_thresh(:, :, z), 1), [-0.4 0.4], [], mymap, 1, h);
    end
    % Set colormap and colorbar
    colormap(mymap)
    % Adjust the position of the colorbar
    h = gcf;
    pos = get(h, 'Position');
    % colorbar('Position', [0.99 0.1 0.995 0.8]); % Adjust the position as needed
    colorbar('Position', [0.35 0.48 0.3 0.02], 'Orientation', 'horizontal'); % Adjust the position as needed
    % Export the figure
    export_fig([scan_name, '_thresh_', num2str(thrs), '_cross_correlation.bmp'], '-r', '300')
end
% export_fig([scan_name,'_',num2str(thrs),'.bmp'],'-r','300')

% clear matlabbatch
% 在SPM分析开始前设置自定义HRF参数
% 默认HRF参数
hrf_default = [6.0000 16.0000 1.0000 1.0000 6.0000 0.0000 32.0000];
hrf_auditory = [3.5324 3.8155 0.4615 0.4634 1.2540 0.0000 32.0000];
hrf_whisker = [2.8038 2.9722 0.3712 0.3700 1.1960 0.0000 32.0000];
volume_tol = dim(4);

% 基础结果路径（确保 results_dir 指向 run 的主目录，如 ...\16）
base_results_dir = results_dir;
results_dirs = {};

switch hrf_type
    case 'mouse_auditory'
        % --- mouse_auditory HRF ---
        auditory_dir = fullfile(base_results_dir, 'mouse_auditory');
        mkdir(auditory_dir);
        copyfile(fullfile(base_results_dir, ['sr', scan_name, '.nii']), auditory_dir); copyfile(fullfile(base_results_dir, ['rp_', scan_name, '.txt']), auditory_dir);
        run_spm_glm('mouse_auditory', hrf_auditory, auditory_dir, ...
            scan_name, TR, onset_scan, duration_input, ...
            thresh_values, cluster_ext_values, volume_tol);
        cd (base_results_dir)
        % --- default HRF ---
        default_dir = fullfile(base_results_dir, 'default');
        mkdir(default_dir);
        copyfile(fullfile(base_results_dir, ['sr', scan_name, '.nii']), default_dir); copyfile(fullfile(base_results_dir, ['rp_', scan_name, '.txt']), default_dir);
        run_spm_glm('default', hrf_default, default_dir, ...
            scan_name, TR, onset_scan, duration_input, ...
            thresh_values, cluster_ext_values, volume_tol);
        cd (base_results_dir)

        results_dirs = {auditory_dir, default_dir};

    case 'mouse_whisker'
        whisker_dir = fullfile(base_results_dir, 'mouse_whisker');
        mkdir(whisker_dir);
        copyfile(fullfile(base_results_dir, ['sr', scan_name, '.nii']), whisker_dir); copyfile(fullfile(base_results_dir, ['rp_', scan_name, '.txt']), whisker_dir);
        run_spm_glm('mouse_whisker', hrf_whisker, whisker_dir, ...
            scan_name, TR, onset_scan, duration_input, ...
            thresh_values, cluster_ext_values, volume_tol);
        cd (base_results_dir)

        default_dir = fullfile(base_results_dir, 'default');
        mkdir(default_dir);
        copyfile(fullfile(base_results_dir, ['sr', scan_name, '.nii']), default_dir); copyfile(fullfile(base_results_dir, ['rp_', scan_name, '.txt']), default_dir);
        run_spm_glm('default', hrf_default, default_dir, ...
            scan_name, TR, onset_scan, duration_input, ...
            thresh_values, cluster_ext_values, volume_tol);
        cd (base_results_dir)

        results_dirs = {whisker_dir, default_dir};

    otherwise
        default_dir = fullfile(base_results_dir, 'default');
        mkdir(default_dir);
        copyfile(fullfile(base_results_dir, ['sr', scan_name, '.nii']), default_dir); copyfile(fullfile(base_results_dir, ['rp_', scan_name, '.txt']), default_dir);
        run_spm_glm('default', hrf_default, default_dir, ...
            scan_name, TR, onset_scan, duration_input, ...
            thresh_values, cluster_ext_values, volume_tol);
        cd (base_results_dir)

        results_dirs = {default_dir};
end

% 遍历结果目录列表，生成图像和分析结果
for i = 1:length(results_dirs)
    current_dir = results_dirs{i};
    disp(['Processing results in: ', current_dir]);

    for thresh = thresh_values
        for cluster_ext = cluster_ext_values
            % 动态生成文件路径
            t_map_file = fullfile(current_dir, ['spmT_0001_', scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.nii']);
            output_png_file = fullfile(current_dir, [scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.png']);
            output_bmp_file = fullfile(current_dir, [scan_name, '_average_percent_change_', num2str(thresh), '_', num2str(cluster_ext), '.bmp']);

            % 检查 t-map 文件是否存在
            if ~exist(t_map_file, 'file')
                warning('T-map file not found: %s', t_map_file);
                continue;
            end

            % 绘制SPM结果图像
            figure('Position', [0 0 700 346]);
            t_map_info = niftiinfo(t_map_file);
            t_map = double(niftiread(t_map_info));
            for z = 1:size(ana, 3)
                h = subplottight(3, 5, z);
                [hF, hB] = imoverlay(rot90(ana(:, :, z, 1), 1), rot90(t_map(:, :, z), 1), [-5 5], [], mymap, 1, h);
            end
            colormap(mymap);
            set(gcf, 'color', 'black');
            export_fig(output_png_file, '-r', '300');
            close;

            % 计算平均百分比变化
            overlay_data_display = t_map;
            overlay_data_display(t_map == 0) = NaN; % 应用mask
            BG = niftiread(['sr', scan_name, '.nii']);
            overlay_data_display(isnan(overlay_data_display)) = 0;
            active_index = find(overlay_data_display);
            BG_2D = reshape(BG, [size(BG, 1) * size(BG, 2) * size(BG, 3), size(BG, 4)]);
            ROI_ts = BG_2D(active_index, :);
            mean_ts = mean(ROI_ts, 1);

            % 初始化变量
            blockSize = 40;
            numBlocks = 15;
            startIdx = 1;
            percentChanges = zeros(numBlocks, blockSize);

            % 计算每个block的百分比变化
            for j = 1:numBlocks
                blockStart = startIdx + (j - 1) * blockSize;
                blockEnd = blockStart + blockSize - 1;
                blockData = mean_ts(blockStart:blockEnd);
                baseline = mean(blockData((blockSize - 19):(blockSize - 10)));
                percentChange = (blockData - baseline) ./ baseline;
                percentChanges(j, :) = percentChange;
            end

            % 计算平均百分比变化
            meanPercentChange = mean(percentChanges, 1);
            figure;
            plot(meanPercentChange, 'LineWidth', 1.5);
            hold on;
            xline(31, 'r--', 'LineWidth', 0.5);
            xline(40, 'r--', 'LineWidth', 0.5);
            set(gcf, 'unit', 'centimeters', 'position', [5, 5, 15, 5]);
            export_fig(output_bmp_file, '-r', '300');
            close;
        end
    end
end

% calculate the cross-correlation map after motion scrubbing
FD_outlier_idx = find(framewise>FD_thrs);
retained_points_index=false(1, length(framewise));
onset_scan_scrubbing = [onset_scan, length(framewise)];
retained_points_index(1:onset_scan_scrubbing(1))=true;
removed_block_num = 0;
for x=1:length(onset_scan)
    if isempty(intersect((onset_scan_scrubbing(x)+1:onset_scan_scrubbing(x+1)+1).', FD_outlier_idx))
        retained_points_index(onset_scan_scrubbing(x)+1:onset_scan_scrubbing(x+1)+1)=true;
    else
        removed_block_num = removed_block_num + 1;
    end
end
retained_block_num =block_num -removed_block_num;
disp(retained_block_num)
retained_points_index(end)=[];
img_4D_scrubbed=img_4D(:,:,:,retained_points_index);
onset_scrubbed = onset(retained_points_index);
framewise_scrubbed =framewise(retained_points_index);

dim = size(img_4D_scrubbed);
img_2D=reshape(img_4D_scrubbed,[dim(1)*dim(2)*dim(3),dim(4)]);
img_2D_brain=img_2D(img_idx,:);
corr_map=corr(onset_scrubbed',img_2D_brain');
corr_3D=zeros(dim(1),dim(2),dim(3));
corr_1D=reshape(corr_3D, [dim(1)*dim(2)*dim(3),1]);
corr_1D(img_idx)=corr_map;
corr_3D=reshape(corr_1D,[dim(1),dim(2),dim(3)]);
header=EPIfilename_header(1);
header.fname=['sr',scan_name,'_regressed_cc_map_scrubbed.nii'];
spm_write_vol(header,corr_3D);

% ana=spm_read_vols(spm_vol([scan_name,'.nii']));
ana=niftiread([scan_name,'.nii']);

figure('Position',[0 0 1488 688])
for z=1:size(ana,3)
    h = subplottight(4,7,z);
    [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(corr_3D(:,:,z),1),[-0.2 0.2],[],jet,1,h);
end
colormap(jet)
% Adjust the position of the colorbar
h = gcf;
pos = get(h, 'Position');
% colorbar('Position', [0.99 0.1 0.995 0.8]); % Adjust the position as needed
colorbar('Position', [0.35 0.48 0.3 0.02], 'Orientation', 'horizontal'); % Adjust the position as needed
export_fig([scan_name,'_scrubbed_unthresholded_cc.bmp'],'-r','300')

for thrs = thrs_values
    % disp(['Threshold: ', num2str(thrs)])
    corr_3D_thresh = corr_3D; % Create a copy to preserve the original data
    corr_3D_thresh(abs(corr_3D_thresh) < thrs) = NaN;
    % Create a figure
    figure('Position', [0 0 1488 688])
    % Loop over each slice
    for z = 1:size(ana, 3)
        h = subplottight(4, 7, z);
        [hF, hB] = imoverlay(rot90(ana(:, :, z, 1), 1), rot90(corr_3D_thresh(:, :, z), 1), [-0.4 0.4], [], mymap, 1, h);
    end
    % Set colormap and colorbar
    colormap(mymap);
    % Adjust the position of the colorbar
    h = gcf;
    pos = get(h, 'Position');
    % colorbar('Position', [0.99 0.1 0.995 0.8]); % Adjust the position as needed
    colorbar('Position', [0.35 0.48 0.3 0.02], 'Orientation', 'horizontal'); % Adjust the position as needed    
    % Export the figure
    export_fig([scan_name,'_',num2str(retained_block_num),'remained_',num2str(block_num),'_scrubbed_thresh_', num2str(thrs), '_cross_correlation.bmp'],'-r','300')
end

% close all
end 

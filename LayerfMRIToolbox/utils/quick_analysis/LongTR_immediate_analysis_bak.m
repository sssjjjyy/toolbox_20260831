function LongTR_immediate_analysis(filename, TR, prestim_num, stim_num, interstim_num, poststim_num, block_num, thresh_values, cluster_ext_values,FD_thrs,duration_input, type,hrf_type)

addpath(genpath('C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\'))
addpath('C:\matlabtool\spm12')

% filename='C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\b2n_test\auditory\derivative\20240525_415\9\longTR_9.nii';
% thresh_values = [0.01, 0.05]; % Example threshold values
% cluster_ext_values = [10, 20]; % Example cluster extent values

% prestim_num=30;  % Number of Scans Before First Task Block
% stim_num=10;     % Number of Scans In Task Block
% interstim_num=30; % Number of Scans Between Task Blocks
% poststim_num=30; % Number of Scans After Last Task Block
% block_num=15; % Number of Task Blocks
% duration_input=10;
% FD_thrs = 1;
% TR=1;%mouse 
% type = 'mouse';

[pathstr, scan_name, extension] = fileparts(filename);
working_dir = pathstr;
cd(working_dir)

if(~exist(fullfile(working_dir,[scan_name,extension]),'file'))
    copyfile(filename,working_dir);
end

results_dir = working_dir;

% Parameters
% prestim_num=30;  % Number of Scans Before First Task Block
% stim_num=10;     % Number of Scans In Task Block
% interstim_num=30; % Number of Scans Between Task Blocks
% poststim_num=30; % Number of Scans After Last Task Block
% block_num=15; % Number of Task Blocks
% duration_input=10;
% FD_thrs = 1;
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
% TR=1;%mouse 

%prestim_num:Number of Scans Before First Task Block
%stim_num:Number of Scans In Task Block
%interstim_num:Number of Scans Between Task Blocks
%poststim_num:Number of Scans After Last Task Block
%block_num:Number of Task Blocks
onset=[zeros(1,prestim_num),repmat([ones(1,stim_num) zeros(1,interstim_num)],1,block_num - 1),ones(1,stim_num),zeros(1,poststim_num)];
onset_scan = prestim_num:(stim_num+interstim_num):(prestim_num+(stim_num+interstim_num)*block_num-interstim_num+poststim_num-1);


%onset=[zeros(1,30) repmat([ones(1,10) zeros(1,30)],1,5)];
%onset=[zeros(1,30) repmat([repmat([ones(1,10) zeros(1,30)],1,5) zeros(1,120)],1,3)];
%onset=[repmat([ones(1,20) zeros(1,20)],1,5)];
%onset_scan=30:40:229; % SPM starts counting from 0
%onset_scan=[30 70 110 150 190 350 390 430 470 510 670 710 750 790 830]; % SPM starts counting from 0

% initiate customized colormap
mymap_positive = colormap(autumn);
mymap_negative = colormap(winter);
mymap_negative = flipud(mymap_negative);
mymap=[mymap_negative;mymap_positive];
close all

% onset_scan=30:40:229; % SPM starts counting from 0
% duration_input=10;

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
sorted_voxel_size = sort(voxel_size);
FWHM = [sorted_voxel_size(1) * 1.5, sorted_voxel_size(2) * 1.5, sorted_voxel_size(3)];
[~, original_order] = sort(voxel_size);
FWHM = FWHM(original_order);
% FWHM = 1.5 * voxel_size;
% FWHM=[0.1875 0.1875 0.4]; %1.5倍 mouse
% FWHM=[0.225 0.225 0.5]; %1.5倍 rat 

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
% colorbar('Position', [0.99 0.1 0.995 0.8]); % Adjust the position as needed
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
temp(:,1:3)=dis_radius*temp(:,1:3); % displacement on surface of a r=3mm sphere
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
EPIfilename_header=spm_vol(['r',scan_name,'.nii']);
% img_4D=spm_read_vols(EPIfilename_header);
img_4D=niftiread(['r',scan_name,'.nii']);
img_4D=rsfmri_smooth(img_4D,FWHM(1),voxel_size(1));
img_4D(isnan(img_4D))=0;
EPIfilename_header(1).dt(1)=64;
rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['sr',scan_name,'.nii']);

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

% img_class = class(niftiread([scan_name, '.nii']));
% tSNR_3Dimg = cast(tSNR_3Dimg, img_class);
% new_filename = [scan_name, '_tSNR.nii']; % Replace with your desired file name
% niftiwrite(tSNR_3Dimg, new_filename, nii_info);

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

clear matlabbatch
% 在SPM分析开始前设置自定义HRF参数
% 默认HRF参数
hrf_default = [6.0000 16.0000 1.0000 1.0000 6.0000 0.0000 32.0000];
hrf_auditory = [3.5324 3.8155 0.4615 0.4634 1.2540 0.0000 32.0000];
hrf_whisker = [2.8038 2.9722 0.3712 0.3700 1.1960 0.0000 32.0000];

global defaults;

% 根据hrf_type设置HRF参数
switch hrf_type
    case 'mouse_auditory'
        disp('Using Mouse Auditory HRF parameters.');
        defaults.stats.fmri.hrf = hrf_auditory;
        mkdir(fullfile(results_dir,'mouse_auditory'));
    case 'mouse_whisker'
        disp('Using Mouse Whisker HRF parameters.');
        defaults.stats.fmri.hrf = hrf_whisker;
        mkdir(fullfile(results_dir,'mouse_whisker'));
    otherwise % 'default' 或 'none'
        disp('Using Default HRF parameters.');
        defaults.stats.fmri.hrf = hrf_default;
        mkdir(fullfile(results_dir,'default'));
end

disp('Current HRF parameters set to:');
disp(defaults.stats.fmri.hrf);

% first-level analysis
f = spm_select('ExtFPList', pwd, ['sr',scan_name,'.nii'],1:dim(4));

% % Output Directory
% %--------------------------------------------------------------------------
% matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_mkdir.parent = cellstr(results_dir);
% matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_mkdir.name = 'GLM';
%% 对于default的HRF
% Model Specification
%--------------------------------------------------------------------------
matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(fullfile(results_dir,'default'));
matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'scans';
matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
matlabbatch{1}.spm.stats.fmri_spec.sess.scans = cellstr(f);
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.name = 'task';
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.onset = onset_scan;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.duration = duration_input;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.tmod = 0;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.pmod = struct('name', {}, 'param', {}, 'poly', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.orth = 1;
matlabbatch{1}.spm.stats.fmri_spec.sess.multi = {''};
matlabbatch{1}.spm.stats.fmri_spec.sess.regress = struct('name', {}, 'val', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg =cellstr([results_dir,'\rp_',scan_name,'.txt']); 
matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = 128;
matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';

% Model Estimation
%--------------------------------------------------------------------------
matlabbatch{2}.spm.stats.fmri_est.spmmat = cellstr(fullfile(results_dir,'default','SPM.mat'));
matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

% Contrasts
%--------------------------------------------------------------------------
matlabbatch{3}.spm.stats.con.spmmat = cellstr(fullfile(results_dir,'default','SPM.mat'));
matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'On > Off';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 0];
% matlabbatch{4}.spm.stats.con.consess{2}.tcon.name = 'Rest > Listening';
% matlabbatch{4}.spm.stats.con.consess{2}.tcon.weights = [-1 0];

%% 对于自定义hrf的
matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(fullfile(results_dir,hrf_type));
matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'scans';
matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
matlabbatch{1}.spm.stats.fmri_spec.sess.scans = cellstr(f);
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.name = 'task';
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.onset = onset_scan;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.duration = duration_input;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.tmod = 0;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.pmod = struct('name', {}, 'param', {}, 'poly', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.orth = 1;
matlabbatch{1}.spm.stats.fmri_spec.sess.multi = {''};
matlabbatch{1}.spm.stats.fmri_spec.sess.regress = struct('name', {}, 'val', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg =cellstr([results_dir,'\rp_',scan_name,'.txt']); 
matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = 128;
matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(0.2)';
% Model estimation
matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('fMRI model specification: SPM.mat File', ...
    substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), ...
    substruct('.','spmmat'));
matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
% Contrast specification - 需要根据新的设计矩阵调整
matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', ...
    substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), ...
    substruct('.','spmmat'));
% 如果只使用HRF（没有导数），则只有1个回归量
matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'Stimulus > Baseline';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1]; % 只有一个HRF回归量
matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';

% % Inference Results
% %--------------------------------------------------------------------------
% matlabbatch{4}.spm.stats.results.spmmat = cellstr([results_dir,'/SPM.mat']);
% matlabbatch{4}.spm.stats.results.conspec.contrasts = 1;
% matlabbatch{4}.spm.stats.results.conspec.threshdesc = 'none';
% matlabbatch{4}.spm.stats.results.conspec.thresh = thresh;
% matlabbatch{4}.spm.stats.results.conspec.extent = cluster_ext;
% matlabbatch{4}.spm.stats.results.export{1}.png = true;
% matlabbatch{4}.spm.stats.results.export{2}.tspm.basename = [scan_name,'_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext)];
% save([scan_name,'_first_level.mat'],'matlabbatch');
% spm_jobman('run',matlabbatch);

% % plot SPM results
% figure('Position',[0 0 700 346])
% % t_map = spm_read_vols(spm_vol(['spmT_0001_', scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.nii']));
% t_map_info = niftiinfo(['spmT_0001_', scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.nii']);
% t_map = double(niftiread(t_map_info));
% for z = 1:size(ana, 3)
%     h = subplottight(3, 5, z);
%     [hF, hB] = imoverlay(rot90(ana(:, :, z, 1), 1), rot90(t_map(:, :, z), 1), [-5 5], [], mymap, 1, h);
% end
% colormap(mymap)
% set(gcf, 'color', 'black');
% export_fig([scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.png'], '-r', '300')
%%
batch=4;
for thresh = thresh_values
    for cluster_ext = cluster_ext_values
        % Display the current threshold and cluster extent values
        disp(['Current threshold: ', num2str(thresh), ', Current cluster extent: ', num2str(cluster_ext)]);
        % Set up the matlabbatch for SPM
        matlabbatch{batch}.spm.stats.results.spmmat = cellstr([results_dir,'/SPM.mat']);
        matlabbatch{batch}.spm.stats.results.conspec.contrasts = 1;
        matlabbatch{batch}.spm.stats.results.conspec.threshdesc = 'none';
        matlabbatch{batch}.spm.stats.results.conspec.thresh = thresh;
        matlabbatch{batch}.spm.stats.results.conspec.extent = cluster_ext;
        matlabbatch{batch}.spm.stats.results.export{1}.png = true;
        matlabbatch{batch}.spm.stats.results.export{2}.tspm.basename = [scan_name,'_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext)];
        batch = batch + 1;
    end
end

save([scan_name,'_first_level.mat'],'matlabbatch');
spm_jobman('run',matlabbatch);

for thresh = thresh_values
    for cluster_ext = cluster_ext_values
        % Plot SPM results
        figure('Position', [0 0 700 346])
        t_map_info = niftiinfo(['spmT_0001_', scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.nii']);
        t_map = double(niftiread(t_map_info));
        for z = 1:size(ana, 3)
            h = subplottight(3, 5, z);
            [hF, hB] = imoverlay(rot90(ana(:, :, z, 1), 1), rot90(t_map(:, :, z), 1), [-5 5], [], mymap, 1, h);
        end
        colormap(mymap);
        set(gcf, 'color', 'black');
        export_fig([scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.png'], '-r', '300')
    end
end

%计算spmT_0.01_20激活区域的曲线
for thresh = thresh_values
    for cluster_ext = cluster_ext_values
        t_map = niftiread(['spmT_0001_', scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.nii']);
        overlay_data_display = t_map;
        overlay_data_display(t_map == 0) = NaN; % 应用mask
        
%         % 应用聚类大小阈值
%         BW = ~isnan(overlay_data_display);
%         for z = 1:size(BW, 3)
%             BW(:, :, z) = bwareaopen(BW(:, :, z), cluster_ext);
%         end
%         overlay_data_display(~BW) = NaN;

        BG=niftiread(['sr', scan_name, '.nii']);
        %% 计算并显示平均百分比变化
        % 将NaN设为0，便于索引
        overlay_data_display(isnan(overlay_data_display)) = 0;
        % 获取激活区域的索引
        active_index = find(overlay_data_display);
        % 提取激活区域的时间序列
        BG_reshape_factor = 28; % 根据您的数据调整
        BG_2D = reshape(BG, [BG_factor*BG_reshape_factor, size(BG, 4)]);
        ROI_ts = BG_2D(active_index, :);
        mean_ts = mean(ROI_ts, 1);
        
        % 初始化变量
        blockSize = 40;
        numBlocks = 15;
        startIdx = 1; 
        baselineLength = 10;
        
        % 存储每个block的percent change
        percentChanges = zeros(numBlocks, blockSize);
        
        % 遍历每个block
        for i = 1:numBlocks
            % 获取当前block的起始和结束索引
            blockStart = startIdx + (i - 1) * blockSize;
            blockEnd = blockStart + blockSize - 1;
        
            % 获取当前block数据
            blockData = mean_ts(blockStart:blockEnd);
        
            % 计算baseline
            baseline = mean(blockData((blockSize-19):(blockSize-10)));
        
            % 计算percent change
            percentChange = (blockData - baseline) ./ baseline;
        
            % 存储percent change
            percentChanges(i, :) = percentChange;
        end
        
        % 计算所有block的平均percent change
        meanPercentChange = mean(percentChanges, 1);
        
        figure;
        plot(meanPercentChange, 'LineWidth', 1.5);
        hold on;
        xline(31, 'r--', 'LineWidth', 0.5);
        xline(40, 'r--', 'LineWidth', 0.5);
        set(gcf, 'unit', 'centimeters', 'position', [5, 5, 15, 5]);
        
        export_fig(fullfile(results_dir, [scan_name,'_average_percent_change_', num2str(thresh),'_',num2str(cluster_ext),'.bmp']), '-r', '300');
        close;
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

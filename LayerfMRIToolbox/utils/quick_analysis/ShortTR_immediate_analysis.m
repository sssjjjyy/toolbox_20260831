function ShortTR_immediate_analysis(filename, TR, prestim_num, stim_num, interstim_num, poststim_num, block_num, thresh_values, cluster_ext_values,stimvolume,type)

addpath(genpath('C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\'))
addpath('C:\matlabtool\spm12')

[pathstr, scan_name, extension] = fileparts(filename);
working_dir = pathstr;
cd(working_dir)

if(~exist(fullfile(working_dir,[scan_name,extension]),'file'))
    copyfile(filename,working_dir);
end

results_dir = working_dir;
% % % Set the parameters for the analysis
% prestim_num=610;  % Number of Scans Before First Task Block
% stim_num=10;     % Number of Scans In Task Block
% interstim_num=130; % Number of Scans Between Task Blocks
% poststim_num=120; % Number of Scans After Last Task Block
% block_num=60; % Number of Task Blocks
% duration_input=10;
if strcmp(type, 'mouse')
    dis_radius = 3; %mouse是3 rat是5
    BG_factor = 108 * 64;
elseif strcmp(type, 'rat')
    dis_radius = 5;
    BG_factor = 106 * 84;
else
    error('Invalid type. Type must be either "mouse" or "rat".');
end
tSNR_thrs = 7.5;
thrs=0.12;
T_removed=0;           % the number of intial volumes for removal
% TR=0.2;%mouse 

%prestim_num:Number of Scans Before First Task Block
%stim_num:Number of Scans In Task Block
%interstim_num:Number of Scans Between Task Blocks
%poststim_num:Number of Scans After Last Task Block
%block_num:Number of Task Blocks
onset=[zeros(1,prestim_num),repmat([ones(1,stim_num) zeros(1,interstim_num)],1,block_num - 1),ones(1,stim_num),zeros(1,poststim_num)];
onset_scan = prestim_num:(stim_num+interstim_num):(prestim_num+(stim_num+interstim_num)*block_num-interstim_num+poststim_num-1);

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


% motion correction

% plot tSNR
copyfile([scan_name,'.nii'],[scan_name,'_bak.nii'])
nii_info = niftiinfo([scan_name,'.nii']);
voxel_size = nii_info.PixelDimensions;
voxel_size = voxel_size(1:3);
header=spm_vol([scan_name,'.nii']);
% voxel_size=[abs(header(1).mat(1,1)) abs(header(1).mat(2,2)) abs(header(1).mat(3,3))];
sorted_voxel_size = sort(voxel_size);
FWHM = [sorted_voxel_size(1) * 1.5, sorted_voxel_size(2) * 1.5, sorted_voxel_size(3)];
[~, original_order] = sort(voxel_size);
FWHM = FWHM(original_order);
% FWHM=[0.1875 0.1875 1.2]; %1.5倍 mouse

% disp(voxel_size)
% img=double(spm_read_vols(header));
img=double(niftiread([scan_name,'.nii']));
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
figure('Position',[0 0 1488 172 * row])
for z=1:size(tSNR_3Dimg_thrs,3)
    h = subplottight(row, 7,z);
    [hF,hB] = imoverlay(rot90(img(:,:,z,1),1),rot90(tSNR_3Dimg_thrs(:,:,z),1),[0 25],[],jet,1,h);
end
colormap(jet);
h = gcf;
pos = get(h, 'Position');
% colorbar('Position', [0.99 0.1 0.995 0.8]); % Adjust the position as needed
colorbar('Position', [0.35 0.48 0.3 0.02], 'Orientation', 'horizontal'); % Adjust the position as needed

export_fig([scan_name,'_tSNR_thrs.bmp'],'-r','300');

%%创建mean文件
mean_sub=mean(img,4);
header_mean = header(1);
header_mean.fname = ['mean',scan_name,'.nii'];
spm_write_vol(header_mean, mean_sub);
ana=spm_read_vols(spm_vol(['mean',scan_name,'.nii']));


% smoothing
EPIfilename_header=spm_vol([scan_name,'.nii']);
% EPIfilename_header=spm_vol(['r',scan_name,'.nii']);
% img_4D=spm_read_vols(EPIfilename_header);
img_4D=niftiread([scan_name,'.nii']);
img_4D=rsfmri_smooth(img_4D,FWHM(1),voxel_size(1));
img_4D(isnan(img_4D))=0;
EPIfilename_header(1).dt(1)=64;
rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['s',scan_name,'.nii']);


% first-level analysis
f = spm_select('ExtFPList', pwd, ['s',scan_name,'.nii'],1:dim(4));

% % Output Directory
% %--------------------------------------------------------------------------
% matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_mkdir.parent = cellstr(results_dir);
% matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_mkdir.name = 'GLM';

% Model Specification
%--------------------------------------------------------------------------
matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(results_dir);
matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'scans';
matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 1;
matlabbatch{1}.spm.stats.fmri_spec.sess.scans = cellstr(f);
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.name = 'task';
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.onset = onset_scan;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.duration = stimvolume;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.tmod = 0;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.pmod = struct('name', {}, 'param', {}, 'poly', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.orth = 1;
matlabbatch{1}.spm.stats.fmri_spec.sess.multi = {''};
matlabbatch{1}.spm.stats.fmri_spec.sess.regress = struct('name', {}, 'val', {});
% matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg =cellstr([results_dir,'\rp_',scan_name,'.txt']); 
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
matlabbatch{2}.spm.stats.fmri_est.spmmat = cellstr([results_dir,'\SPM.mat']);
matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

% Contrasts
%--------------------------------------------------------------------------
matlabbatch{3}.spm.stats.con.spmmat = cellstr([results_dir,'\SPM.mat']);
matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'On > Off';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 0];
% matlabbatch{4}.spm.stats.con.consess{2}.tcon.name = 'Rest > Listening';
% matlabbatch{4}.spm.stats.con.consess{2}.tcon.weights = [-1 0];

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
% 
% % plot SPM results
% figure('Position',[0 0 700 346])
% % t_map = spm_read_vols(spm_vol(['spmT_0001_', scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.nii']));
% t_map_info = niftiinfo(['spmT_0001_', scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.nii']);
% t_map = double(niftiread(t_map_info));
% for z = 1:size(ana, 3)
%     h = subplottight(1, 1, z);
%     [hF, hB] = imoverlay(rot90(ana(:, :, z, 1), 1), rot90(t_map(:, :, z), 1), [-5 5], [], mymap, 1, h);
% end
% colormap(mymap)
% set(gcf, 'color', 'black');
% export_fig([scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.png'], '-r', '300')

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

        BG=niftiread(['s', scan_name, '.nii']);
        %% 计算并显示平均百分比变化
        % 将NaN设为0，便于索引
        overlay_data_display(isnan(overlay_data_display)) = 0;
        % 获取激活区域的索引
        active_index = find(overlay_data_display);
        % 提取激活区域的时间序列
        BG_reshape_factor = 1; % 根据您的数据调整
        BG_2D = reshape(BG, [BG_factor*BG_reshape_factor, size(BG, 4)]);
        ROI_ts = BG_2D(active_index, :);
        mean_ts = mean(ROI_ts, 1);
        
        % 初始化变量
        blockSize = 140;
        numBlocks = 60;
        startIdx = 601; %%为什么不是611
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
            baseline = mean(blockData(1:baselineLength));
        
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

% Close all

end 
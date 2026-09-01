function ShortTR_immediate_analysis(working_dir, filename, TR, prestim_num, stim_num, interstim_num, poststim_num, block_num, fwhm_1,thresh_values, cluster_ext_values,type,stimvolume)

addpath(genpath('D:\code\layerfmritoolbox\layerfmri_code\'))

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
elseif strcmp(type, 'rat')
    dis_radius = 5;
else
    error('Invalid type. Type must be either "mouse" or "rat".');
end

tSNR_thrs = 7.5;
thrs=0.1;
T_removed=0;           % the number of intial volumes for removal
% TR=0.2;%mouse 

%prestim_num:Number of Scans Before First Task Block
%stim_num:Number of Scans In Task Block
%interstim_num:Number of Scans Between Task Blocks
%poststim_num:Number of Scans After Last Task Block
%block_num:Number of Task Blocks
onset=[zeros(1,prestim_num),repmat([ones(1,stim_num) zeros(1,interstim_num)],1,block_num - 1),ones(1,stim_num),zeros(1,poststim_num)];
onset_scan = prestim_num:(stim_num+interstim_num):(prestim_num+(stim_num+interstim_num)*block_num-interstim_num+poststim_num-1);
onset_hrf = conv(onset, hrf);
onset_hrf = onset_hrf(1:length(onset)); % Trim back to original scan length

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
header=spm_vol([scan_name,'.nii']);
try
    % Attempt to use MATLAB's native function first
    nii_info = niftiinfo([scan_name,'.nii']);
    voxel_size = nii_info.PixelDimensions;
catch
    % If niftiinfo fails (e.g., due to a bad slice_code byte), fall back to the SPM header matrix
    disp(['Warning: niftiinfo failed for ', scan_name, '. Using SPM affine matrix fallback.']);
    voxel_size = sqrt(sum(header(1).mat(1:3,1:3).^2));
end
disp(voxel_size)

img=double(spm_read_vols(header));
% img=double(niftiread([scan_name,'.nii']));
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
% 若 fwhm_1 = 0，则直接拷贝输入文件为输出文件，并跳过 smoothing
if fwhm_1 == 0
    copyfile([scan_name, '.nii'], ['s', scan_name, '.nii']);
    fprintf('FWHM = 0, 跳过平滑，直接复制文件。\n');
else
    EPIfilename_header=spm_vol([scan_name,'.nii']);
    % img_4D=spm_read_vols(EPIfilename_header);
    img_4D=niftiread([scan_name,'.nii']);
    img_4D=rsfmri_smooth(img_4D,fwhm_1,voxel_size(1));
    img_4D(isnan(img_4D))=0;
    EPIfilename_header(1).dt(1)=64;
    rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['s',scan_name,'.nii']);
end

% EPIfilename_header=spm_vol([scan_name,'.nii']);
% % EPIfilename_header=spm_vol(['r',scan_name,'.nii']);
% % img_4D=spm_read_vols(EPIfilename_header);
% img_4D=niftiread([scan_name,'.nii']);
% img_4D=rsfmri_smooth(img_4D,FWHM(1),voxel_size(1));
% img_4D(isnan(img_4D))=0;
% EPIfilename_header(1).dt(1)=64;
% rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['s',scan_name,'.nii']);


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
        figure('Position', [0 0 1488 688])
        t_map_info = niftiinfo(['spmT_0001_', scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.nii']);
        t_map = double(niftiread(t_map_info));
        for z = 1:size(ana, 3)
            h = subplottight(4, 7, z);
            [hF, hB] = imoverlay(rot90(ana(:, :, z, 1), 1), rot90(t_map(:, :, z), 1), [-5 5], [], mymap, 1, h);
        end
        colormap(mymap);
        set(gcf, 'color', 'black');
        export_fig([scan_name, '_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext), '.png'], '-r', '300')
    end
end



%% 调用ITK-SNAP进行ROI绘制
% 首先创建mean图像用于ITK-SNAP显示
itksnap_path = '"C:\Program Files\ITK-SNAP 4.2\bin\ITK-SNAP.exe"';
BG=niftiread(['s', scan_name, '.nii']);
BG_mean = mean(BG, 4);

% 保存mean图像
mean_filename = ['mean', scan_name, '.nii'];
% 定义要叠加的图像文件
overlay_file = ['spmT_0001_',scan_name,'_thresh_', num2str(thresh_values(1)), '_extent_', num2str(cluster_ext_values(1)),'.nii']; % 根据实际需要修改文件名

% 检查叠加文件是否存在
if exist(overlay_file, 'file')
    disp(['找到叠加文件: ', overlay_file]);
else
    warning('叠加文件不存在: %s', overlay_file);
    overlay_file = '';
end

% ==== 显示提示信息 ====
disp('=== ITK-SNAP 单图像叠加 ROI 绘制指南 ===');
disp(['主图像文件: ', mean_filename]);
if ~isempty(overlay_file)
    disp(['叠加图像文件: ', overlay_file]);
else
    disp('⚠ 未找到叠加图像，将仅加载主图像。');
end
disp('请在ITK-SNAP中:');
disp('1. 加载主图像');
disp('2. 添加叠加图像 (若存在)');
disp('3. 手动绘制ROI');
disp('4. 将ROI保存为: roi.nii');
disp('5. 绘制完成后按任意键继续...');

% ==== 尝试自动启动 ITK-SNAP ====
try
    % 构建命令
    itksnap_cmd = sprintf('%s -g "%s"', itksnap_path, mean_filename);
    if ~isempty(overlay_file)
        itksnap_cmd = [itksnap_cmd, sprintf(' -o "%s"', overlay_file)];
    end

    disp(['执行命令: ', itksnap_cmd]);
    system(itksnap_cmd);
catch
    disp('无法自动启动 ITK-SNAP，请手动操作:');
    disp(['   主图像: ', mean_filename]);
    if ~isempty(overlay_file)
        disp(['   叠加图像: ', overlay_file]);
    end
end

% ==== 等待用户完成 ROI 绘制 ====
pause;

%% 检查ROI文件是否存在
roi_filename = 'roi.nii';
if ~exist(roi_filename, 'file')
    error('未找到ROI文件: %s。请确保已保存ROI为roi.nii', roi_filename);
end

%% 基于ROI计算平均时间曲线
% 读取ROI数据
roi_data = niftiread(roi_filename);

% 获取ROI区域的索引
roi_index = find(roi_data > 0);

if isempty(roi_index)
    error('ROI文件中没有找到有效的ROI区域');
end

disp(['ROI包含 ', num2str(length(roi_index)), ' 个体素']);

% 提取ROI区域的时间序列
BG=niftiread(['s', scan_name, '.nii']);
BG_reshape_factor = 3; % 根据您的数据调整
BG_2D = reshape(BG, [size(BG,1)*size(BG,2)*size(BG,3), size(BG, 4)]);
ROI_ts = BG_2D(roi_index, :);
mean_ts = mean(ROI_ts, 1);

% 初始化变量
blockSize = stim_num+interstim_num;
numBlocks = block_num;
startIdx = prestim_num-10;
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

unique_stimvolumes = unique(stimvolume);  % 找到不同的 stimvolume
meanPercentChange_byStim = cell(length(unique_stimvolumes), 1);
colors = lines(length(unique_stimvolumes));  % 给不同 stimvolume 预定义颜色
figure; hold on;

% 遍历 stimvolume 类型
for s = 1:length(unique_stimvolumes)
    if length(unique_stimvolumes) >1 
        stim = unique_stimvolumes(s);
    
        % 找到属于这个 stimvolume 的 block index
        idx_blocks = find(stimvolume == stim);
    
        % 取出这些 block 的数据
        percentChanges_stim = percentChanges(idx_blocks, :);
    
        % 算平均
        meanPercentChange_byStim{s} = mean(percentChanges_stim, 1);
    
        % 绘曲线
        h = plot(meanPercentChange_byStim{s}, 'LineWidth', 1.5, ...
                 'Color', colors(s,:), 'DisplayName', ['Stim ', num2str(stim)]);
        
        % 找最低值
        [ymin, ~] = min(meanPercentChange_byStim{s});
        
        % 在 y = ymin 的位置画横线（从 11 到 stim+11）
        xline_range = [11, stim+11];
        hline = line(xline_range, [ymin ymin], 'Color', colors(s,:), ...
                     'LineStyle', '--', 'LineWidth', 1);
        % 不要 legend
        hline.Annotation.LegendInformation.IconDisplayStyle = 'off';

    elseif length(unique_stimvolumes) ==1
        % 计算所有block的平均percent change
        meanPercentChange = mean(percentChanges, 1);
        
        % 绘制ROI平均时间曲线
        % figure;
        plot(meanPercentChange, 'LineWidth', 1.5);
        hold on;
        xline(11, 'r--', 'LineWidth', 0.5);
        xline(20, 'r--', 'LineWidth', 0.5);
    end

end

title(['ROI平均时间曲线 - ', scan_name]);
xlabel('时间点');
ylabel('百分比变化');
legend('show');
set(gcf, 'unit', 'centimeters', 'position', [5, 5, 15, 5]);

% 保存图像
export_fig(fullfile(results_dir, [scan_name,'_ROI_average_timecourse.bmp']), '-r', '300');

% 
% % 计算所有block的平均percent change
% meanPercentChange = mean(percentChanges, 1);
% 
% % 绘制ROI平均时间曲线
% figure;
% plot(meanPercentChange, 'LineWidth', 1.5);
% hold on;
% xline(11, 'r--', 'LineWidth', 0.5);
% xline(20, 'r--', 'LineWidth', 0.5);
% 
% title(['ROI平均时间曲线 - ', scan_name]);
% xlabel('时间点');
% ylabel('百分比变化');
% set(gcf, 'unit', 'centimeters', 'position', [5, 5, 15, 5]);
% 
% % 保存图像
% export_fig(fullfile(results_dir, [scan_name,'_ROI_average_timecourse.bmp']), '-r', '300');
% 
% disp('ROI分析完成！');
% disp(['图像已保存: ', fullfile(results_dir, [scan_name,'_ROI_average_timecourse.bmp'])]);
% % disp(['数据已保存: ', fullfile(results_dir, [scan_name,'_ROI_timecourse_data.mat'])]);
% 
% % Close all

end 
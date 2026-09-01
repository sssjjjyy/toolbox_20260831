function LongTR_MION_immediate_analysis(filename, TR, prestim_num, stim_num, interstim_num, poststim_num, block_num, p_value_threshold_values, cluster_size_thrs_2D_values,FD_thrs,duration_input,type)

addpath(genpath('C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\'))
addpath('C:\matlabtool\spm12')

[pathstr, scan_name, extension] = fileparts(filename);
working_dir = pathstr;
cd(working_dir)

if(~exist(fullfile(working_dir,[scan_name,extension]),'file'))
    copyfile(filename,working_dir);
end

results_dir = working_dir;

% %%mouse
% prestim_num=30;  % Number of Scans Before First Task Block
% stim_num=10;     % Number of Scans In Task Block
% interstim_num=30; % Number of Scans Between Task Blocks
% poststim_num=30; % Number of Scans After Last Task Block
% block_num=15; % Number of Task Blocks
%%rat
% prestim_num=30;  % Number of Scans Before First Task Block
% stim_num=10;     % Number of Scans In Task Block
% interstim_num=30; % Number of Scans Between Task Blocks
% poststim_num=30; % Number of Scans After Last Task Block
% block_num=15; % Number of Task Blocks
% duration_input=10;
% FD_thrs = 1.2;
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
% TR=1;%mouse 
% TR=1.5;%rat

%prestim_num:Number of Scans Before First Task Block
%stim_num:Number of Scans In Task Block
%interstim_num:Number of Scans Between Task Blocks
%poststim_num:Number of Scans After Last Task Block
%block_num:Number of Task Blocks
onset=[zeros(1,prestim_num),repmat([ones(1,stim_num) zeros(1,interstim_num)],1,block_num - 1),ones(1,stim_num),zeros(1,poststim_num)]*-1;
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
voxel_size = voxel_size(1:3);
header=spm_vol([scan_name,'.nii']);
% voxel_size=[abs(header(1).mat(1,1)) abs(header(1).mat(2,2)) abs(header(1).mat(3,3))];
% disp(voxel_size)
sorted_voxel_size = sort(voxel_size);
FWHM = [sorted_voxel_size(1) * 1.5, sorted_voxel_size(2) * 1.5, sorted_voxel_size(3)];
[~, original_order] = sort(voxel_size);
FWHM = FWHM(original_order);
% FWHM=[0.1875 0.1875 0.4]; %1.5倍 mouse
% FWHM=[0.225 0.225 0.5]; %1.5倍 rat 

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

% realignment using AFNI
afni_dir = '/home/zhu_13579/abin/';
input_name = win2wsl(fullfile(results_dir,[scan_name,'.nii']));
afni_input_path = generate_prefix_path(fullfile(results_dir,[scan_name,'+orig.BRIK']),'r');
afni_input_path = win2wsl(afni_input_path);
system(['wsl', afni_dir, '3dvolreg -base 0 -cubic -zpad 1 -1Dfile rp_', scan_name, '.txt -1Dmatrix_save mat_vr.aff12.1D -prefix r', scan_name, ' ', input_name]);
system(['wsl', afni_dir, '3dAFNItoNIFTI ',afni_input_path]);

%%创建mean文件
rheader=spm_vol(['r',scan_name,'.nii']);
rsub=spm_read_vols(rheader);
% rsub=double(niftiread(['r',scan_name,'.nii']));
mean_sub=mean(rsub,4);
header_mean = rheader(1);
header_mean.fname = ['mean',scan_name,'.nii'];
spm_write_vol(header_mean, mean_sub);

% 调用ITK-SNAP手动绘制mask
mean_file_path = fullfile(pwd, header_mean.fname);
itksnap_path = '"C:\Program Files\ITK-SNAP 4.2\bin\ITK-SNAP.exe"';
[status, cmdout] = system([itksnap_path, ' -g "', mean_file_path, '"']);
% 检查ITK-SNAP是否成功启动
if status ~= 0
    error('Failed to start ITK-SNAP. Please ensure ITK-SNAP is installed and accessible from the command line.');
end

% 暂停，等待用户手动绘制完成后继续
uiwait(msgbox('请在ITK-SNAP中完成mask绘制，然后点击确定继续。', '等待用户操作', 'modal'));


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
colormap(jet)
h = gcf;
pos = get(h, 'Position');
% colorbar('Position', [0.99 0.1 0.995 0.8]); % Adjust the position as needed
colorbar('Position', [0.35 0.48 0.3 0.02], 'Orientation', 'horizontal'); % Adjust the position as needed

export_fig([scan_name,'_cc_unthresholded.bmp'],'-r','300')

% plot the thresholded cross-correlation map
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

%%%%afni_glm
output_directory = results_dir;
output_directory = convertToWSLPath(output_directory);
glm_file = 'C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\utils\quick_analysis\afni_glm\afni_glm.sh';
glm_file = convertToWSLPath(glm_file);
motion_file = ['rp_',scan_name,'.txt'];
input_file = ['sr', scan_name, '.nii'];
copyfile('C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\utils\quick_analysis\afni_glm\long\stim.1D', results_dir);
fileID = fopen('stim.1D', 'w');
fprintf(fileID, '%d ', onset_scan);
fclose(fileID);
duration_input_str=num2str(duration_input);
TR_str=num2str(TR);

command = sprintf('wsl bash -c "cd ''%s''; ''%s'' ''%s'' ''%s'' ''%s'' ''%s'' %s"', output_directory, glm_file, output_directory, motion_file, input_file, duration_input_str,TR_str);
% command = sprintf('wsl bash -c "cd ''%s''; ''%s'' ''%s'' ''%s'' ''%s''"', output_directory, glm_file, output_directory, motion_file, input_file);
disp(command)
% Execute the command in MATLAB
status = system(command);
% Check the status of the execution
if status == 0
    disp('Script executed successfully.');
else
    disp('Script execution failed.');
end

%% 调用ITK-SNAP进行ROI绘制
% 首先创建mean图像用于ITK-SNAP显示
BG=niftiread(['sr', scan_name, '.nii']);
BG_mean = mean(BG, 4);

% 保存mean图像
mean_filename = ['mean', scan_name, '.nii'];
% 定义要叠加的图像文件
overlay_files = {'stats_output_t.nii', 'stats_output_f.nii', 'thr_map.nii'}; % 根据实际需要修改文件名

% 检查叠加文件是否存在
existing_overlays = {};
for i = 1:length(overlay_files)
    if exist(overlay_files{i}, 'file')
        existing_overlays{end+1} = overlay_files{i};
    else
        warning('叠加文件不存在: %s', overlay_files{i});
    end
end

% 显示提示信息
disp('=== ITK-SNAP多图像叠加ROI绘制指南 ===');
disp(['主图像文件: ', mean_filename]);
disp('叠加图像文件:');
for i = 1:length(existing_overlays)
    disp(['  ', num2str(i), '. ', existing_overlays{i}]);
end
disp('请在ITK-SNAP中:');
disp('1. 加载主图像');
disp('2. 依次添加叠加图像');
disp('3. 手动绘制ROI');
disp('4. 将ROI保存为: roi.nii');
disp('5. 绘制完成后按任意键继续...');

% 尝试自动启动ITK-SNAP（如果安装了的话）
try
    % 构建ITK-SNAP命令，包含多个叠加图像
    itksnap_cmd = sprintf('%s -g "%s"', itksnap_path, mean_filename);
    
    % % 添加所有存在的叠加图像
    % for i = 1:length(existing_overlays)
    %     itksnap_cmd = [itksnap_cmd, sprintf(' -o "%s"', existing_overlays{i})];
    % end
        % 添加所有存在的叠加图像 - 修正：使用单个-o参数后跟多个文件
    if ~isempty(existing_overlays)
        itksnap_cmd = [itksnap_cmd, ' -o'];
        for i = 1:length(existing_overlays)
            itksnap_cmd = [itksnap_cmd, sprintf(' "%s"', existing_overlays{i})];
        end
    end

    disp(['执行命令: ', itksnap_cmd]);
    system(itksnap_cmd);
catch
    disp('无法自动启动ITK-SNAP，请手动打开ITK-SNAP并按以下步骤操作：');
    disp('1. File -> Open Main Image -> 选择主图像');
    disp(['   主图像: ', mean_filename]);
    disp('2. Tools -> Add Overlay -> 依次添加叠加图像');
    for i = 1:length(existing_overlays)
        disp(['   叠加图像', num2str(i), ': ', existing_overlays{i}]);
    end
    disp('3. 在Segmentation模式下绘制ROI');
    disp('4. File -> Save Segmentation -> 保存为roi.nii');
end

% 等待用户完成ROI绘制
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
BG_reshape_factor = 28; % 根据您的数据调整
BG_2D = reshape(BG, [size(BG,1)*size(BG,2)*size(BG,3), size(BG, 4)]);
ROI_ts = BG_2D(roi_index, :);
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

% 绘制ROI平均时间曲线
figure;
plot(meanPercentChange, 'LineWidth', 1.5);
hold on;
xline(31, 'r--', 'LineWidth', 0.5);
xline(40, 'r--', 'LineWidth', 0.5);
title(['ROI平均时间曲线 - ', scan_name]);
xlabel('时间点');
ylabel('百分比变化');
set(gcf, 'unit', 'centimeters', 'position', [5, 5, 15, 5]);

% 保存图像
export_fig(fullfile(results_dir, [scan_name,'_ROI_average_timecourse.jpg']), '-r', '300');

% 保存时间序列数据
% save(fullfile(results_dir, [scan_name,'_ROI_timecourse_data.mat']), 'meanPercentChange', 'mean_ts', 'roi_index');

disp('ROI分析完成！');
disp(['图像已保存: ', fullfile(results_dir, [scan_name,'_ROI_average_timecourse.jpg'])]);
% disp(['数据已保存: ', fullfile(results_dir, [scan_name,'_ROI_timecourse_data.mat'])]);

% %% 应用聚类大小阈值 (2D)
% % cluster_size_thrs_2D = 10;
% % p_value_threshold = 0.0001;
% for p_value_threshold = p_value_threshold_values
%     for cluster_size_thrs_2D = cluster_size_thrs_2D_values
%         % 读取pstat和mask数据
%         % pstat_data = spm_read_vols(spm_vol('p_output.nii'));
%         pstat_data=niftiread(['p_output.nii']);
%         %%这里的mask图像需要自己手动绘制！！！！！用mean图像来绘制
%         % mask_data = spm_read_vols(spm_vol('mask.nii'));
%         mask_data=niftiread(['mask.nii']);
%         pstat_mask = pstat_data < p_value_threshold;
        
%         % 对p值进行处理，便于颜色映射
%         % 取负对数，使得p值越小，数值越大
%         overlay_data_display = -log10(pstat_data);
%         overlay_data_display(~pstat_mask) = NaN; % 不符合条件的设为NaN
%         overlay_data_display(mask_data == 0) = NaN; % 应用mask
        
%         % 应用聚类大小阈值
%         BW = ~isnan(overlay_data_display);
%         for z = 1:size(BW, 3)
%             BW(:, :, z) = bwareaopen(BW(:, :, z), cluster_size_thrs_2D);
%         end
%         overlay_data_display(~BW) = NaN;
        
%         % 计算overlay_data_display的最小值和最大值
%         overlay_min = min(overlay_data_display(:));
%         overlay_max = max(overlay_data_display(:));
        
%         % 读取背景图像
%         % BG = spm_read_vols(spm_vol(['sr', scan_name, '.nii']));
%         BG=niftiread(['sr', scan_name, '.nii']);
%         BG_mean = mean(BG, 4);
        
%         % 显示图像
%         for z = 1:size(BG_mean, 3)
%             h = subplottight(4, 7, z);
%             [hF, hB] = imoverlay(rot90(BG_mean(:, :, z), 1), rot90(overlay_data_display(:, :, z), 1), [overlay_min overlay_max], [0 prctile(BG_mean(:), 95)], 'hot', 1, h);
%         end
%         % colormap(hot);
%         colormap(jet);
%         h = gcf;
%         pos = get(h, 'Position');
%         % colorbar('Position', [0.99 0.1 0.995 0.8]); % Adjust the position as needed
%         colorbar('Position', [0.35 0.48 0.3 0.02], 'Orientation', 'horizontal'); % Adjust the position as needed thrs_str = sprintf('%.6f', thrs); num2str(p_value_threshold)
%         p_value_threshold_str = sprintf('%.10f', p_value_threshold);  % 使用较大精度来避免科学计数法
%         p_value_threshold_str = regexprep(p_value_threshold_str, '0+$', '');  % 去掉末尾的多余0
%         p_value_threshold_str = regexprep(p_value_threshold_str, '\.$', '');  % 如果小数点后没有数字，去掉小数点
%         export_fig([scan_name,'_activation_', p_value_threshold_str ,'_',num2str(cluster_size_thrs_2D),'.bmp'], '-r', '300');
        
%         %% 计算并显示平均百分比变化
%         % 将NaN设为0，便于索引
%         overlay_data_display(isnan(overlay_data_display)) = 0;
%         % 获取激活区域的索引
%         active_index = find(overlay_data_display);
%         % 提取激活区域的时间序列
%         BG_reshape_factor = 28; % 根据您的数据调整
%         BG_2D = reshape(BG, [BG_factor*BG_reshape_factor, size(BG, 4)]);
%         ROI_ts = BG_2D(active_index, :);
%         mean_ts = mean(ROI_ts, 1);
        
%         % 初始化变量
%         blockSize = 40;
%         numBlocks = 15;
%         startIdx = 1; 
%         baselineLength = 10;
        
%         % 存储每个block的percent change
%         percentChanges = zeros(numBlocks, blockSize);
        
%         % 遍历每个block
%         for i = 1:numBlocks
%             % 获取当前block的起始和结束索引
%             blockStart = startIdx + (i - 1) * blockSize;
%             blockEnd = blockStart + blockSize - 1;
        
%             % 获取当前block数据
%             blockData = mean_ts(blockStart:blockEnd);
        
%             % 计算baseline
%             baseline = mean(blockData((blockSize-19):(blockSize-10)));
        
%             % 计算percent change
%             percentChange = (blockData - baseline) ./ baseline;
        
%             % 存储percent change
%             percentChanges(i, :) = percentChange;
%         end
        
%         % 计算所有block的平均percent change
%         meanPercentChange = mean(percentChanges, 1);
        
%         figure;
%         plot(meanPercentChange, 'LineWidth', 1.5);
%         hold on;
%         xline(31, 'r--', 'LineWidth', 0.5);
%         xline(40, 'r--', 'LineWidth', 0.5);
%         set(gcf, 'unit', 'centimeters', 'position', [5, 5, 15, 5]);
        
%         export_fig(fullfile(results_dir, [scan_name,'_average_percent_change_', p_value_threshold_str,'_',num2str(cluster_size_thrs_2D),'.bmp']), '-r', '300');
%         close;
%     end
% end

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
ana=niftiread([scan_name, '.nii']);

figure('Position',[0 0 1488 688])
for z=1:size(ana,3)
    h = subplottight(4,7,z);
    [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(corr_3D(:,:,z),1),[-0.2 0.2],[],jet,1,h);
end
colormap(jet)
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
end
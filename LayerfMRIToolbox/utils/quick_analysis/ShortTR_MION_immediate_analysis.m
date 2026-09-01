function ShortTR_MION_immediate_analysis(filename, TR, prestim_num, stim_num, interstim_num, poststim_num, block_num, p_value_threshold_values, cluster_size_thrs_2D_values,stimvolume,type)

% working_dir='C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\b2n_test\auditory\derivative\20240530_MION_1_45\21\test_time';
% filename='C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\b2n_test\auditory\derivative\20240530_MION_1_45\21\test_time\shortTR_21.nii';
% TR=0.2;
% disthres=2;
% cluster_size_thrs_2D=4;
% type='mouse';
% stimvolume=10;

addpath(genpath('C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\'))
addpath('C:\matlabtool\spm12')

[pathstr, scan_name, extension] = fileparts(filename);
working_dir = pathstr;
cd(working_dir)

if(~exist(fullfile(working_dir,[scan_name,extension]),'file'))
    copyfile(filename,working_dir);
end

results_dir = working_dir;

% % Set the parameters for the analysis
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
% onset=[zeros(1,prestim_num),repmat([ones(1,stim_num) zeros(1,interstim_num)],1,block_num - 1),ones(1,stim_num),zeros(1,poststim_num)];
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

% smoothing
EPIfilename_header=spm_vol([scan_name,'.nii']);
% EPIfilename_header=spm_vol(['r',scan_name,'.nii']);
% img_4D=spm_read_vols(EPIfilename_header);
img_4D=niftiread([scan_name,'.nii']);
img_4D=rsfmri_smooth(img_4D,FWHM(1),voxel_size(1));
img_4D(isnan(img_4D))=0;
EPIfilename_header(1).dt(1)=64;
rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['s',scan_name,'.nii']);


output_directory = results_dir;
output_directory = convertToWSLPath(output_directory);
glm_file = 'C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\utils\quick_analysis\afni_glm\afni_glm_short.sh';
glm_file_r = 'C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\utils\quick_analysis\afni_glm\afni_glm_short_random.sh';
glm_file = convertToWSLPath(glm_file);
glm_file_r = convertToWSLPath(glm_file_r);
input_file = ['s',scan_name,'.nii'];
copyfile('C:\Users\zhuyt12023\Desktop\layerfmri_ui\layerfmri_code\utils\quick_analysis\afni_glm\short\stim.1D', results_dir);
% fprintf(fileID, '%d ', onset_scan);
% 写入 onset_scan 和 duration_input 数据，每个数据之间用空格隔开
%LOCAL: 使用 LOCAL 来确保 AFNI 将你的 stim.1D 文件中的时间解释为基于 TR 的相对时间，而不是全局时间（秒）。
% onset_time = onset_scan * TR;
duration_input = stimvolume;
% duration_time = duration_input * TR;
TR_str = num2str(TR);
if isscalar(duration_input)
    duration_input_str = num2str(duration_input);
    fileID = fopen('stim.1D', 'w');
    fprintf(fileID, '%d ', onset_scan);
    fclose(fileID);
    command = sprintf('wsl bash -c "cd ''%s''; ''%s'' ''%s'' ''%s'' ''%s'' ''%s''"', output_directory, glm_file, output_directory, input_file,duration_input_str,TR_str);
    disp(command)
    status = system(command);
    if status == 0
        disp('Script executed successfully.');
    else
        disp('Script execution failed.');
    end
else
    fileID = fopen('stim.1D', 'w');
    for i = 1:length(onset_scan)
        fprintf(fileID, '%d:%d ', onset_scan(i), duration_input(i));
    end
    fclose(fileID);
    
    command = sprintf('wsl bash -c "cd ''%s''; ''%s'' ''%s'' ''%s'' ''%s''"', output_directory, glm_file_r, output_directory, input_file,TR_str);
    disp(command)
    status = system(command);
    if status == 0
        disp('Script executed successfully.');
    else
        disp('Script execution failed.');
    end
end
% duration_time = duration_input * TR;
% for i = 1:length(onset_scan)
%     fprintf(fileID, '%d:%d ', onset_time(i), duration_time(i));
% end
% fclose(fileID);

%% command = sprintf('wsl bash -c "cd ''%s''; ''%s'' ''%s'' ''%s''"', output_directory, glm_file, output_directory, input_file);
% disp(command)
% status = system(command);
% if status == 0
%     disp('Script executed successfully.');
% else
%     disp('Script execution failed.');
% end

%%
%% 调用ITK-SNAP进行ROI绘制
% 首先创建mean图像用于ITK-SNAP显示
BG=niftiread(['s', scan_name, '.nii']);
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
BG_reshape_factor = 3; % 根据您的数据调整
BG_2D = reshape(BG, [size(BG,1)*size(BG,2)*size(BG,3), size(BG, 4)]);
ROI_ts = BG_2D(roi_index, :);
mean_ts = mean(ROI_ts, 1);

% 初始化变量
blockSize = 140;
numBlocks = 60;
startIdx = 601;
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

% 绘制ROI平均时间曲线
figure;
plot(meanPercentChange, 'LineWidth', 1.5);
hold on;
xline(11, 'r--', 'LineWidth', 0.5);
xline(20, 'r--', 'LineWidth', 0.5);
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
        
%         % 应用阈值和mask
%         % pstat_data_display = pstat_data;
%         % pstat_data_display(pstat_data_display > p_value_threshold) = NaN;
%         % pstat_data_display(mask_data == 0) = NaN;
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
%         % BG = spm_read_vols(spm_vol(['s',scan_name,'.nii']));
%         BG=niftiread(['s', scan_name, '.nii']);
%         BG_mean = mean(BG, 4);
        
%         %rot90(overlay_data_display(:, :, z), 3) 旋转3次90度
%         % 显示图像
%         for z = 1:size(BG_mean, 3)
%             h = subplottight(2, 2, z);
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
%         %%这里根据需要调整是1还是3
%         BG_reshape_factor = 1;
%         BG_2D = reshape(BG, [BG_factor*BG_reshape_factor, size(BG, 4)]);
%         ROI_ts = BG_2D(active_index, :);
%         mean_ts = mean(ROI_ts, 1);
        
%         % 初始化变量
%         blockSize = 140;
%         numBlocks = 60;
%         startIdx = 601; %%为什么不是611
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
%             baseline = mean(blockData(1:baselineLength));
        
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
%         xline(11, 'r--', 'LineWidth', 0.5);
%         xline(20, 'r--', 'LineWidth', 0.5);
%         set(gcf, 'unit', 'centimeters', 'position', [5, 5, 15, 5]);
        
%         export_fig(fullfile(results_dir, [scan_name,'_average_percent_change_', p_value_threshold_str,'_',num2str(cluster_size_thrs_2D),'.bmp']), '-r', '300');
%         close;
    % end
end
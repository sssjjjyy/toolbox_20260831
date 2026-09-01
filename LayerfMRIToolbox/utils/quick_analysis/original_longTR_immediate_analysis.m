% clear all
% close all
%%激活是用spm还是afni计算
%加载代码和spm路径
addpath(genpath('C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\layerfMRItool-txn'))
addpath('C:\matlabtool\spm12')
addpath(genpath('D:\'))

%%nii文件所在位置
targetDirs = 'C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\211_0127\22';
cd(targetDirs)
% inputType = 'multiband';
inputType = 'dicom';
raw_dir = 'C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\20240127_171357_LTN_20240127_211_1_174';
base_dir = 'C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\211_0127';
scanIDs = 22;
refIDs = 9;
processData(inputType, raw_dir,base_dir,scanIDs,refIDs,'result')


scan_files = dir(fullfile(targetDirs, '*.nii'));
for k = 1:length(scan_files)
    fileName = scan_files(k).name;
    % if endsWith(fileName, 'bold.nii') % 检查是否以bold.nii结尾
        scan_name = fileName(1:end-length('.nii')); % 提取.nii前面的字符
        % disp(['Found bold.nii file: ', scan_name]);
    % end
end
results_dir = targetDirs;

%%mouse
prestim_num=30;  % Number of Scans Before First Task Block
stim_num=10;     % Number of Scans In Task Block
interstim_num=30; % Number of Scans Between Task Blocks
poststim_num=30; % Number of Scans After Last Task Block
block_num=15; % Number of Task Blocks
% %%rat
% prestim_num=30;  % Number of Scans Before First Task Block
% stim_num=10;     % Number of Scans In Task Block
% interstim_num=30; % Number of Scans Between Task Blocks
% poststim_num=30; % Number of Scans After Last Task Block
% block_num=15; % Number of Task Blocks
duration_input=10;
tSNR_thrs = 7.5;
thrs=0.12;
T_removed=0;           % the number of intial volumes for removal
FWHM=[0.1875 0.1875 0.4]; %1.5倍 mouse
% FWHM=[0.225 0.225 0.5]; %1.5倍 rat 不需要修改
TR=1;%mouse 
% TR=1.5;%rat


onset=[zeros(1,prestim_num),repmat([ones(1,stim_num) zeros(1,interstim_num)],1,block_num - 1),ones(1,stim_num),zeros(1,poststim_num)]*-1;
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
%     nii_info = niftiinfo([scan_name,'.nii']);
%     voxel_size = nii_info.PixelDimensions;
header=spm_vol([scan_name,'.nii']);
voxel_size=[abs(header(1).mat(1,1)) abs(header(1).mat(2,2)) abs(header(1).mat(3,3))];
% disp(voxel_size)
img=double(spm_read_vols(header));
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
colormap(jet)
export_fig([scan_name,'_tSNR_thrs.bmp'],'-r','300');

% realignment using AFNI
afni_dir = '/home/zhu_13579/abin/';
input_name = win2wsl(fullfile(results_dir,[scan_name,'.nii']));
afni_input_path = generate_prefix_path(fullfile(results_dir,[scan_name,'+orig.BRIK']),'r');
afni_input_path = win2wsl(afni_input_path);
system(['wsl', afni_dir, '3dvolreg -base 0 -cubic -zpad 1 -1Dfile rp_', scan_name, '.txt -1Dmatrix_save mat_vr.aff12.1D -prefix r', scan_name, ' ', input_name]);
system(['wsl', afni_dir, '3dAFNItoNIFTI ',afni_input_path]);

%%创建mean文件
rsub=spm_read_vols(spm_vol(['r',scan_name,'.nii']));
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
temp(:,1:3)=3*temp(:,1:3); % displacement on surface of a r=3mm sphere
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
img_4D=spm_read_vols(EPIfilename_header);
img_4D=rsfmri_smooth(img_4D,FWHM(1),voxel_size(1));
img_4D(isnan(img_4D))=0;
EPIfilename_header(1).dt(1)=64;
rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['sr',scan_name,'.nii']);

% regression of motion signals
EPIfilename_header=spm_vol(['sr',scan_name,'.nii']);
img_4D=spm_read_vols(EPIfilename_header);
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
ana=spm_read_vols(spm_vol(['mean',scan_name,'.nii']));
figure('Position',[0 0 1488 688])
for z=1:size(ana,3)
    h = subplottight(4,7,z);
    [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(corr_3D(:,:,z),1),[-0.2 0.2],[],jet,1,h);
end
colormap(jet)
colorbar;
export_fig([scan_name,'_unthresholded.bmp'],'-r','300')

% plot the thresholded cross-correlation map
corr_3D(abs(corr_3D)<thrs)=NaN;
figure('Position',[0 0 1488 688])
%figure('Position',[0 0 816 309])
for z=1:size(ana,3)
    h = subplottight(4,7,z);
    [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(corr_3D(:,:,z),1),[-0.4 0.4],[],mymap,1,h);
end
colormap(mymap)
colorbar;
export_fig([scan_name,'_',num2str(thrs),'.bmp'],'-r','300')

%%%%afni_glm
output_directory = results_dir;
output_directory = convertToWSLPath(output_directory);
glm_file = 'D:\afni_glm\afni_glm.sh';
glm_file = convertToWSLPath(glm_file);
motion_file = ['rp_',scan_name,'.txt'];
input_file = ['sr', scan_name, '.nii'];
copyfile('D:\afni_glm\long\auditory.1D', results_dir);

command = sprintf('wsl bash -c "cd ''%s''; ''%s'' ''%s'' ''%s'' ''%s''"', output_directory, glm_file, output_directory, motion_file, input_file);
disp(command)
% Execute the command in MATLAB
status = system(command);
% Check the status of the execution
if status == 0
    disp('Script executed successfully.');
else
    disp('Script execution failed.');
end

%% 应用聚类大小阈值 (2D)
cluster_size_thrs_2D = 10;
disthres = 8; %3.5 8
p_value = 0.0001;
% x = 1; % 假设处理第一个路径

% 读取zstat和mask数据
zstat_data = spm_read_vols(spm_vol('stats_output.nii'));
pstat_data = spm_read_vols(spm_vol('p_output.nii'));
%%这里的mask图像需要自己手动绘制！！！！！
mask_data = spm_read_vols(spm_vol('sub-20240605412_mask.nii'));
mask_data = mask_data(:,:,:,1);

% 应用阈值和mask
zstat_data_display = pstat_data;
% zstat_data_display(zstat_data_display < disthres) = 0;
zstat_data_display(zstat_data_display > p_value) = 0;
zstat_data_display(mask_data == 0) = 0;
zstat_data_display(zstat_data_display == 0) = NaN;
BW = zstat_data_display;
BW(BW ~= 0) = 1;
for z = 1:size(BW, 3)
    BW(:, :, z) = bwareaopen(BW(:, :, z), cluster_size_thrs_2D);
end
zstat_data_display = zstat_data_display .* BW;

% 读取背景图像
BG = spm_read_vols(spm_vol(['sr', scan_name, '.nii']));
BG_mean = mean(BG, 4);

BG_mean_mean=mean(BG_mean(:));
% 显示图像
for z = 1:size(BG_mean, 3)
    h = subplottight(4, 7, z);
    [hF, hB] = imoverlay(rot90(BG_mean(:, :, z), 1), rot90(zstat_data_display(:, :, z), 1), [0 p_value], [0 1.5*prctile(BG_mean(:), 95)], 'hot', 1, h);
end
colormap(hot);
% colormap(jet);
export_fig(['activation_3.5.bmp'], '-r', '300');

zstat_data_display(isnan(zstat_data_display)) = 0;
BG_reshape_factor = 28;
%% 计算并显示平均百分比变化
active_index = find(zstat_data_display);
BG_2D = reshape(BG, [108*64*BG_reshape_factor, 630]);
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
    baseline = mean(blockData(1:baselineLength));

    % 计算percent change
    percentChange = (blockData - baseline) / baseline;

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

export_fig(fullfile(results_dir, 'average_percent_change_3.5.bmp'), '-r', '300');
close;



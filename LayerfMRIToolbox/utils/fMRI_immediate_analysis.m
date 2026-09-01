function fMRI_immediate_analysis(results_dir, input_filename, prestim_num, stim_num,interstim_num, poststim_num, block_num, tSNR_thrs, FWHM, TR, thrs, duration_input)

% results_dir='/home_data/home/mazhw/test_data';
% input_filename = 'test.nii';
% 
% prestim_num=30;  % Number of Scans Before First Task Block
% stim_num=10;     % Number of Scans In Task Block
% interstim_num=30; % Number of Scans Between Task Blocks
% poststim_num=30; % Number of Scans After Last Task Block
% block_num=15; % Number of Task Blocks
% 
% tSNR_thrs = 7.5;
% FWHM=[0.1875 0.1875 0.6];
% TR=1;
% T_removed=0;           % the number of intial volumes for removal
% thrs=0.12;
% duration_input=10;
copyfile(input_filename,results_dir);
cd(results_dir)
% newStr = fileparts(input_filename,'.');
% scan_name = newStr{1};


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

% % convert dicom to nifti file
% dicom_filename=dir(fullfile('*.dcm'));
% hdr = spm_dicom_headers([results_dir,'\',dicom_filename(1,1).name]);
% spm_dicom_convert(hdr,'all','flat','nii',results_dir,'true');

% nifti_filename = dir(fullfile(results_dir, '*.nii'));
% movefile(fullfile(results_dir, nifti_filename(1).name), fullfile(results_dir, 'functionLocalier.nii'));
% json_filename = dir(fullfile(results_dir, '*.json'));
% movefile(fullfile(results_dir, json_filename(1).name), fullfile(results_dir, 'functionLocalier.json'));
% clearvars hdr nii_filename json_filename

scan_name = 'functionLocalier';
% plot tSNR
copyfile([scan_name,'.nii'],[scan_name,'_bak.nii'])
header=spm_vol([scan_name,'.nii']);
voxel_size=[abs(header(1).mat(1,1)) abs(header(1).mat(2,2)) abs(header(1).mat(3,3))];
disp(voxel_size)
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
temp(:,1:3)=50*temp(:,1:3); % displacement on surface of a r=3mm sphere
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
ana=spm_read_vols(spm_vol([scan_name,'.nii']));
figure('Position',[0 0 1488 688])
for z=1:size(ana,3)
    h = subplottight(4,7,z);
    [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(corr_3D(:,:,z),1),[-0.2 0.2],[],jet,1,h);
end
colormap(jet)
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
export_fig([scan_name,'_',num2str(thrs),'.bmp'],'-r','300')

% first-level analysis
f = spm_select('ExtFPList', pwd, ['sr',scan_name,'.nii'],1:dim(4));

% % Output Directory
% %--------------------------------------------------------------------------
% matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_mkdir.parent = cellstr(results_dir);
% matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_mkdir.name = 'GLM';

% Model Specification
%--------------------------------------------------------------------------
matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(results_dir);
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
matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg =cellstr([results_dir,'/rp_',scan_name,'.txt']); 
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
matlabbatch{2}.spm.stats.fmri_est.spmmat = cellstr([results_dir,'/SPM.mat']);
matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

% Contrasts
%--------------------------------------------------------------------------
matlabbatch{3}.spm.stats.con.spmmat = cellstr([results_dir,'/SPM.mat']);
matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'On > Off';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 0];
% matlabbatch{4}.spm.stats.con.consess{2}.tcon.name = 'Rest > Listening';
% matlabbatch{4}.spm.stats.con.consess{2}.tcon.weights = [-1 0];

% Inference Results
%--------------------------------------------------------------------------
matlabbatch{4}.spm.stats.results.spmmat = cellstr([results_dir,'/SPM.mat']);
matlabbatch{4}.spm.stats.results.conspec.contrasts = 1;
matlabbatch{4}.spm.stats.results.conspec.threshdesc = 'none';
matlabbatch{4}.spm.stats.results.conspec.thresh = 0.01;
matlabbatch{4}.spm.stats.results.conspec.extent = 20;
matlabbatch{4}.spm.stats.results.print = false;
save([scan_name,'_first_level.mat'],'matlabbatch');
spm_jobman('run',matlabbatch);
end
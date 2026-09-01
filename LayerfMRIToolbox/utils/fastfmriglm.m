function fastfmriglm(working_dir, input_filename, TR, prestim_num, stim_num, interstim_num, poststim_num, block_num, duration_input, thrs, cluster_ext)
% fastfmriglm('C:\fMRI_toolboxes\layerfMRItool\output_test', 'R7_17.nii', 0.2, 610, 10, 130, 120, 60, 10, 0.05, 20)
% Obtain scan name
cd(working_dir)
[~, scan_name, extension] = fileparts(input_filename);
if(~exist(fullfile(working_dir,[scan_name,extension]),'file'))
    copyfile(input_filename,working_dir);
end
% Calculate the onset used for SPM GLM
onset_scan = prestim_num:(stim_num+interstim_num):(prestim_num+(stim_num+interstim_num)*block_num-interstim_num+poststim_num-1);

% Obtain the number of time points in the input data
header = spm_vol(input_filename);
img = double(spm_read_vols(header));
dim = size(img);

spm('Defaults','fMRI');
spm_jobman('initcfg');

% Spatial smoothing
voxel_size=[abs(header(1).mat(1,1)) abs(header(1).mat(2,2)) abs(header(1).mat(3,3))];
disp(voxel_size)
img=rsfmri_smooth(img, voxel_size(1)*1.5, voxel_size(1));
header(1).dt = [64, 0];
rp_Write4DNIfTI(img, header(1), ['s',scan_name,'.nii']);

% first-level analysis
f = spm_select('ExtFPList', pwd, ['s',scan_name,'.nii'], 1:dim(4));

% % Output Directory
% %--------------------------------------------------------------------------
% matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_mkdir.parent = cellstr(results_dir);
% matlabbatch{1}.cfg_basicio.file_dir.dir_ops.cfg_mkdir.name = 'GLM';

% Model Specification
%--------------------------------------------------------------------------
matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(working_dir);
matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'scans';
matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 1;
matlabbatch{1}.spm.stats.fmri_spec.sess.scans = cellstr(f);
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.name = 'task';
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.onset = onset_scan;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.duration = duration_input;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.tmod = 0;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.pmod = struct('name', {}, 'param', {}, 'poly', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.orth = 1;
matlabbatch{1}.spm.stats.fmri_spec.sess.multi = {''};
matlabbatch{1}.spm.stats.fmri_spec.sess.regress = struct('name', {}, 'val', {});
%matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg =cellstr([results_dir,'\rp_',scan_name,'.txt']); 
matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = 128;
matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';

% Choose slash based on OS type
if ispc
    current_slash = '\';
else
    current_slash = '/';
end

% Model Estimation
%--------------------------------------------------------------------------
matlabbatch{2}.spm.stats.fmri_est.spmmat = cellstr([working_dir, current_slash, 'SPM.mat']);
matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

% Contrasts
%--------------------------------------------------------------------------
matlabbatch{3}.spm.stats.con.spmmat = cellstr([working_dir, current_slash, 'SPM.mat']);
matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'On > Off';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 0];
% matlabbatch{4}.spm.stats.con.consess{2}.tcon.name = 'Rest > Listening';
% matlabbatch{4}.spm.stats.con.consess{2}.tcon.weights = [-1 0];

% Inference Results
%--------------------------------------------------------------------------
matlabbatch{4}.spm.stats.results.spmmat = cellstr([working_dir, current_slash, 'SPM.mat']);
matlabbatch{4}.spm.stats.results.conspec.contrasts = 1;
matlabbatch{4}.spm.stats.results.conspec.threshdesc = 'none';
matlabbatch{4}.spm.stats.results.conspec.thresh = thrs;
matlabbatch{4}.spm.stats.results.conspec.extent = cluster_ext;
matlabbatch{4}.spm.stats.results.print = false;
matlabbatch{4}.spm.stats.results.export{1}.png = true;
matlabbatch{4}.spm.stats.results.export{1}.nii = true;
matlabbatch{4}.spm.stats.results.export{2}.tspm.basename = ['thresholds_', num2str(thrs),'_ex',num2str(cluster_ext)];
save([scan_name,'_first_level.mat'],'matlabbatch');
spm_jobman('run',matlabbatch);
spm('Quit');
end
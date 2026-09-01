function tfmri_1st_level_analysis(input_name_exclude,volumes,stimulus_name,thresholds,TR,onset_scan,duration_input,extents,threshdesc,bg_name_exclude, motion_file_exclude)
[results_dir,input_name] = fileparts(input_name_exclude);
spm('Defaults','fMRI');
spm('Visible','off');
spm_jobman('initcfg');
f = spm_select('ExtFPList', results_dir, input_name,1:volumes);
spm_mat_path = cellstr([results_dir, '/SPM.mat']);
% Model Specification
%--------------------------------------------------------------------------
matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(results_dir);
matlabbatch{1}.spm.stats.fmri_spec.timing.units = 'scans';
matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
matlabbatch{1}.spm.stats.fmri_spec.sess.scans = cellstr(f);
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.name = stimulus_name;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.onset = onset_scan;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.duration = duration_input;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.tmod = 0;
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.pmod = struct('name', {}, 'param', {}, 'poly', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.cond.orth = 1;
matlabbatch{1}.spm.stats.fmri_spec.sess.multi = {''};
matlabbatch{1}.spm.stats.fmri_spec.sess.regress = struct('name', {}, 'val', {});
matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg =cellstr(motion_file_exclude); 
matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = 128;
matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
matlabbatch{1}.spm.stats.fmri_spec.bases.fir.length = duration_input;
matlabbatch{1}.spm.stats.fmri_spec.bases.fir.order = duration_input;
matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';

% Model Estimation
%--------------------------------------------------------------------------
matlabbatch{2}.spm.stats.fmri_est.spmmat = spm_mat_path;
matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

%% Contrasts
%--------------------------------------------------------------------------
matlabbatch{3}.spm.stats.con.spmmat = spm_mat_path;
matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'On > Off';
matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 0];

%% Inference Results
%--------------------------------------------------------------------------
index = 4;
for k = 1:length(extents)
    for j = 1:numel(threshdesc)
        for i = 1:length(thresholds)
            % 构建matlabbatch结构
            matlabbatch{index}.spm.stats.results.spmmat = spm_mat_path;
            matlabbatch{index}.spm.stats.results.conspec.contrasts = 1;
            matlabbatch{index}.spm.stats.results.conspec.threshdesc = threshdesc{j};
            matlabbatch{index}.spm.stats.results.conspec.thresh = thresholds(i);
            matlabbatch{index}.spm.stats.results.conspec.extent = extents(k);
            matlabbatch{index}.spm.stats.results.export{1}.png = true;
            matlabbatch{index}.spm.stats.results.export{2}.tspm.basename = [threshdesc{j},'_', num2str(thresholds(i)),'_ex',num2str(extents(k))];
            index = index + 1;
        end
    end
end
save('first_level.mat','matlabbatch');
spm_jobman('run',matlabbatch);
%%Plot Result
for k = 1:length(extents)
    for j = 1:numel(threshdesc)
        for i = 1:length(thresholds)
            bw_name = ['spmT_0001_',threshdesc{j},'_', num2str(thresholds(i)),'_ex',num2str(extents(k)),'.nii'];
            
            longTR_PlotActivationMap(bw_name,bg_name_exclude,[threshdesc{j},'_', num2str(thresholds(i)),'_ex',num2str(extents(k))]);
        end
    end
end
end


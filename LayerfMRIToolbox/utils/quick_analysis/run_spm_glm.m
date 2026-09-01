function run_spm_glm(hrf_type,hrf_params, results_dir, scan_name, TR, onset_scan, duration_input,thresh_values,cluster_ext_values,volume_tol)
    
    global defaults;
    defaults.stats.fmri.hrf = hrf_params;
    
    disp(['Running GLM with HRF: ', mat2str(hrf_params)]);
    disp(['Output directory: ', fullfile(results_dir)]);

    f = spm_select('ExtFPList', results_dir, ['sr', scan_name, '.nii'], 1:volume_tol); % Use 1:inf to select all volumes

    matlabbatch = {};
    matlabbatch{1}.spm.stats.fmri_spec.dir = cellstr(fullfile(results_dir));
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
    matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg = cellstr(fullfile(results_dir, ['rp_', scan_name, '.txt']));
    matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = 128;
    matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
    matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
    matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
% 根据hrf_type设置CVI和对比
    if strcmp(hrf_type, 'default')
        matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(1)';
        
        % Model Estimation
        matlabbatch{2}.spm.stats.fmri_est.spmmat = cellstr(fullfile(results_dir, 'SPM.mat'));
%         matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('fMRI model specification: SPM.mat File', ...
%             substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), ...
%             substruct('.','spmmat'));
        matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
        matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
        
        % Contrasts for default HRF
        matlabbatch{3}.spm.stats.con.spmmat = cellstr(fullfile(results_dir, 'SPM.mat'));
%         matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', ...
%             substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), ...
%             substruct('.','spmmat'));
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'On > Off';
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1 0];
    else
        % For custom HRFs
        matlabbatch{1}.spm.stats.fmri_spec.cvi = 'AR(0.2)';
        
        % Model Estimation
        matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('fMRI model specification: SPM.mat File', ...
            substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), ...
            substruct('.','spmmat'));
        matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
        matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
        
        % Contrasts for custom HRF
        matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', ...
            substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), ...
            substruct('.','spmmat'));
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = 'Stimulus > Baseline';
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.weights = [1]; % Only one HRF regressor
        matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    end

    batch=4;
    for thresh = thresh_values
        for cluster_ext = cluster_ext_values
            % Display the current threshold and cluster extent values
            disp(['Current threshold: ', num2str(thresh), ', Current cluster extent: ', num2str(cluster_ext)]);
            % Set up the matlabbatch for SPM
            matlabbatch{batch}.spm.stats.results.spmmat = cellstr([fullfile(results_dir),'/SPM.mat']);
            matlabbatch{batch}.spm.stats.results.conspec.contrasts = 1;
            matlabbatch{batch}.spm.stats.results.conspec.threshdesc = 'none';
            matlabbatch{batch}.spm.stats.results.conspec.thresh = thresh;
            matlabbatch{batch}.spm.stats.results.conspec.extent = cluster_ext;
            matlabbatch{batch}.spm.stats.results.export{1}.png = true;
            matlabbatch{batch}.spm.stats.results.export{2}.tspm.basename = [scan_name,'_thresh_', num2str(thresh), '_extent_', num2str(cluster_ext)];
            batch = batch + 1;
        end
    end

    save([fullfile(results_dir),'/',scan_name,'_first_level.mat'],'matlabbatch');
    spm_jobman('run',matlabbatch);

end
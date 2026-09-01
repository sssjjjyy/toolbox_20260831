clear all
close all

working_dir='Y:/data2/10_cross_species_HRF_new/rat/awake_audi';
%raw_dir=[working_dir,'/raw'];
preproc_dir=[working_dir,'/preproc'];
T_removed=0;           % the number of intial volumes for removal
FWHM=[0.75 0.75 0.75];
TR=0.5;
prestim_num=244;  % Number of Scans Before First Task Block
stim_num=4;     % Number of Scans In Task Block
interstim_num=52; % Number of Scans Between Task Blocks
poststim_num=48; % Number of Scans After Last Task Block
block_num=60; % Number of Task Blocks
onset=[zeros(1,prestim_num),repmat([ones(1,stim_num) zeros(1,interstim_num)],1,block_num - 1),ones(1,stim_num),zeros(1,poststim_num)];
onset_scan = prestim_num:(stim_num+interstim_num):(prestim_num+(stim_num+interstim_num)*block_num-interstim_num+poststim_num-1);

%onset=[zeros(1,30) repmat([ones(1,10) zeros(1,30)],1,5)];
%onset=[zeros(1,30) repmat([repmat([ones(1,10) zeros(1,30)],1,5) zeros(1,120)],1,3)];
thrs=0.1;
tSNR_thrs = 7.5;
% onset_scan=30:40:229; % SPM starts counting from 0
% %onset_scan=[30 70 110 150 190 350 390 430 470 510 670 710 750 790 830]; % SPM starts counting from 0
duration_input=4;
   
% initiate customized colormap
mymap_positive = colormap(autumn);
mymap_negative = colormap(winter);
mymap_negative = flipud(mymap_negative);
mymap=[mymap_negative;mymap_positive];
close all

% initialize SPM
spm('Defaults','fMRI');
spm_jobman('initcfg');

%% Set up the Import Options and import the data
opts = spreadsheetImportOptions("NumVariables", 4);

% Specify sheet and range
opts.Sheet = "tfMRI";
opts.DataRange = "A1:D10";

% Specify column names and types
opts.VariableNames = ["Var1", "Var2", "Var3", "Var4"];
opts.VariableTypes = ["char", "char", "char", "char"];

% Specify variable properties
opts = setvaropts(opts, ["Var1", "Var2", "Var3", "Var4"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Var1", "Var2", "Var3", "Var4"], "EmptyFieldRule", "auto");

% Import the data
infoS2 = readtable("Y:\data2\10_cross_species_HRF_new\rat\awake_audi\info.xls", opts, "UseExcel", false);

%% Convert to output type
infoS2 = table2cell(infoS2);
numIdx = cellfun(@(x) ~isnan(str2double(x)), infoS2);
infoS2(numIdx) = cellfun(@(x) {str2double(x)}, infoS2(numIdx));
T = infoS2;
%% Clear temporary variables
clear numIdx opts infoS2

%% Generate Rat-Specific HRF for custom correlation
% Using a faster peak (approx 3s) for rat neurovascular coupling
hrf_rat = spm_hrf(TR, [3.5 4 0.5 0.5 1.25 0 32]); 
onset_hrf = conv(onset, hrf_rat);
onset_hrf = onset_hrf(1:length(onset)); % Trim back to original scan length

for i=8:size(T,1)
    i
    % i=1;
    subjectname=T{i,1};
    % subjectname=['Rat', num2str(T(i,1))];

    for j=2:size(T,2)
        if ~isnan(T{i,j})
            scan_num = T{i,j};
            % scan_num = T(i,2);
            results_dir=[preproc_dir, '/', subjectname,'/',num2str(scan_num)];
            file_name=[subjectname,'_',num2str(scan_num)];
           % file_name = 'Rat10_20251024_11';
           % results_dir='Y:/data2/10_cross_species_HRF_new/rat';
            cd(results_dir)
            if isfile([file_name,'_bak.nii'])
                continue;
            end
            copyfile([file_name,'.nii'], [file_name,'_bak.nii'])
            header=spm_vol([file_name,'.nii']);
            img_4D=double(spm_read_vols(header));
            dim = size(img_4D);
            try
                % Attempt to use MATLAB's native function first
                nii_info = niftiinfo([file_name,'.nii']);
                voxel_size = nii_info.PixelDimensions;
            catch
                % If niftiinfo fails (e.g., due to a bad slice_code byte), fall back to the SPM header matrix
                disp(['Warning: niftiinfo failed for ', file_name, '. Using SPM affine matrix fallback.']);
                voxel_size = sqrt(sum(header(1).mat(1:3,1:3).^2));
            end
            disp(voxel_size)

            % calculate and plot tSNR
            func_2Dimg = reshape(img_4D, dim(1)*dim(2)*dim(3), dim(4));
            func_mean = mean(func_2Dimg, 2);
            func_stdimev = std(func_2Dimg, 0, 2);
            tSNR_2Dimg = func_mean./func_stdimev;
            tSNR_3Dimg = reshape(tSNR_2Dimg, dim(1), dim(2), dim(3));
            header_output = header(1);
            header_output.fname = [file_name,'_tSNR.nii'];
            header_output.dt = [64 0];
            spm_write_vol(header_output, tSNR_3Dimg);
            tSNR_3Dimg_thrs = tSNR_3Dimg;
            tSNR_3Dimg_thrs(tSNR_3Dimg_thrs<tSNR_thrs)=NaN;
            figure('Position',[0 0 700 346])
            for z=1:size(tSNR_3Dimg_thrs,3)
                h = subplottight(4,8,z);
                [hF,hB] = imoverlay(rot90(img_4D(:,:,z,1),1),rot90(tSNR_3Dimg_thrs(:,:,z),1),[0 25],[],jet,1,h);
            end
            colormap(jet)
            export_fig([file_name,'_tSNR.png'],'-r','300');

%             % slice timing correction
%             nslices = dim(3);
%             disp(nslices)
%             P = spm_select('ExtFPList', pwd, [file_name,'_bak.nii'], 1:(length(header)-T_removed));
%             TA = TR-TR/nslices;
%             timing(1) = TA / (nslices -1);
%             timing(2) = TR - TA;
%             spm_slice_timing(P, [1:2:nslices 2:2:nslices], 1, timing, 'a')
%             movefile(['a',file_name,'_bak.nii'], ['a',file_name,'.nii']);

            % realignment
            P = spm_select('ExtFPList', pwd, [file_name,'.nii'],1:(length(header)-T_removed));
            realign_flags.quality = 0.9;
            realign_flags.fwhm = voxel_size(1)*1.5;
            realign_flags.sep = voxel_size(1);
            realign_flags.rtm = 1;
            realign_flags.wrap = [0 0 0];
            realign_flags.interp = 4;
            realign_flags.graphics=0;
            realign_flags.weight = '';
            spm_realign(P,realign_flags);

            reslice_flags.mask = 1;
            reslice_flags.which = [2 1];
            reslice_flags.interp = 4;
            reslice_flags.wrap = [0 0 0];
            reslice_flags.prefix = 'r';
            spm_reslice(P,reslice_flags);
            save([file_name,'_realign.mat'],'realign_flags','reslice_flags');
            clearvars P realign_flags reslice_flags

            % plot motion parameters
            motion=load([results_dir,'/rp_',file_name,'.txt']);
            figure;
            subplot(3,1,1);
            plot(motion(:,1:3))
            xlim([0 size(motion,1)])
            title('Translation')  
            subplot(3,1,2); 
            plot(motion(:,4:6))
            xlim([0 size(motion,1)])
            title('Rotation')  
            
            motion_diff=zeros(size(motion));
            temp=motion;
            temp(:,4:6)=5*temp(:,4:6); % displacement on surface of a r=5mm sphere
            for x=2:size(motion,1)
                motion_diff(x,:)=temp(x,:)-temp(x-1,:);
            end
            motion_diff=abs(motion_diff);
            framewise=sum(motion_diff,2);
                
            subplot(3,1,3); 
            plot(framewise)
            xlim([0 size(framewise,1)])
              
            hold on
            current_start = prestim_num + 1;
            for s = 1 : block_num
                x = current_start : current_start + stim_num - 1;
                y = zeros(1, stim_num);
                plot(x, y, 'r-', 'LineWidth', 2);
                current_start = x(end) + interstim_num + 1;
            end
            hold off
            corr_num = corr(onset.', framewise);
            title(['FD, r=', num2str(corr_num,'%.2f')])
            export_fig([file_name,'_motion.png'],'-r','300');
            delete([file_name,'.nii']);
            copyfile([file_name,'_bak.nii'], [file_name,'.nii']);

            % smoothing
            %spm_smooth(['r',file_name,'.nii'],['sr',file_name,'.nii'],FWHM,0);
            EPIfilename_header=spm_vol(['r',file_name,'.nii']);
            img_4D=spm_read_vols(EPIfilename_header);
            img_4D=rsfmri_smooth(img_4D,FWHM(1),voxel_size(1));
            img_4D(isnan(img_4D))=0;
            EPIfilename_header(1).dt=[64 0];
            rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['sr',file_name,'.nii']);

            % % regression of motion signals
            % % EPIfilename_header=spm_vol(['sr',file_name,'.nii']);
            % % img_4D=spm_read_vols(EPIfilename_header);
            % motion_demean=zeros(size(motion));
            % for x=1:size(motion,1)
            %     motion_demean(x,:) = motion(x,:) - mean(motion);
            % end
            % dim=size(img_4D);
            % img_mask=ones(dim(1),dim(2),dim(3));
            % %motion_demean(:,3:5)=[];
            % img_4D=rsfmri_regression(img_4D,motion_demean,img_mask);
            % rp_Write4DNIfTI(img_4D,EPIfilename_header(1),['sr',file_name,'_regressed.nii']);

%% --- CHANGED: Voxelwise Delay Estimation & Partial Correlation ---
            mean_img = mean(img_4D,4);
            img_idx = find(mean_img>0);
            img_2D = reshape(img_4D,[dim(1)*dim(2)*dim(3),dim(4)]);
            img_2D_brain = img_2D(img_idx,:);
            
            % Test lags from 0 to 8 TRs (0 to 4 seconds delay)
            lags_to_test = 0:8; 
            max_corr_map = -inf(length(img_idx), 1); 
            best_lag_map = zeros(length(img_idx), 1); 
            
            for lag = lags_to_test
                % Shift the HRF-convolved task vector forward by 'lag' TRs
                if lag == 0
                    shifted_task = onset_hrf;
                else
                    shifted_task = [zeros(1, lag), onset_hrf(1:end-lag)];
                end
                
                % Calculate true partial correlation, controlling for 6 motion parameters
                % Inputs must be columns: (Brain Data, Task Vector, Motion Matrix)
                current_corr = partialcorr(img_2D_brain', shifted_task', motion);
                
                % Update voxels where this lag yields a better correlation
                update_idx = current_corr > max_corr_map;
                max_corr_map(update_idx) = current_corr(update_idx);
                best_lag_map(update_idx) = lag; 
            end
            
            % Write 3D Max Correlation Map
            corr_3D=zeros(dim(1),dim(2),dim(3));
            corr_1D=reshape(corr_3D, [dim(1)*dim(2)*dim(3),1]);
            corr_1D(img_idx) = max_corr_map;
            corr_3D=reshape(corr_1D,[dim(1),dim(2),dim(3)]);
            
            header=EPIfilename_header(1);
            header.dt(1)=64;
            header.fname=['sr',file_name,'_cc_map_optimized.nii'];
            spm_write_vol(header,corr_3D);

            % Write 3D Voxelwise Delay (Lag) Map
            lag_3D = zeros(dim(1),dim(2),dim(3));
            lag_1D = reshape(lag_3D, [dim(1)*dim(2)*dim(3),1]);
            lag_1D(img_idx) = best_lag_map;
            lag_3D = reshape(lag_1D,[dim(1),dim(2),dim(3)]);
            header.fname = ['sr',file_name,'_lag_map.nii'];
            spm_write_vol(header,lag_3D);

            % % calculate cross-correlation map
            % mean_img=mean(img_4D,4);
            % img_idx=find(mean_img>0);
            % img_2D=reshape(img_4D,[dim(1)*dim(2)*dim(3),dim(4)]);
            % img_2D_brain=img_2D(img_idx,:);
            % corr_map=corr(onset',img_2D_brain');
            % corr_3D=zeros(dim(1),dim(2),dim(3));
            % corr_1D=reshape(corr_3D, [dim(1)*dim(2)*dim(3),1]);
            % corr_1D(img_idx)=corr_map;
            % corr_3D=reshape(corr_1D,[dim(1),dim(2),dim(3)]);
            % header=EPIfilename_header(1);
            % header.dt(1)=64;
            % header.fname=['sr',file_name,'_regressed_cc_map.nii'];
            % spm_write_vol(header,corr_3D);

            % plot the unthresholded cross-correlation map
            %ana=spm_read_vols(spm_vol('E:\high_res_fMRI\B8_Rat2_8_old\sB101218_D111918_2-230001-00001-000001.nii'));
            ana=spm_read_vols(spm_vol(['mean',file_name,'.nii']));
            figure('Position',[0 0 700 346])
            %figure('Position',[0 0 1488 688])
            for z=1:size(ana,3)
                h = subplottight(4,8,z);
                [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(corr_3D(:,:,z),1),[-0.2 0.2],[],jet,1,h);
            end
            colormap(jet)
            set(gcf,'color','w');
            export_fig([file_name,'_unthresholded.png'],'-r','300');

            % plot the thresholded cross-correlation map
            corr_3D(corr_3D<thrs)=0;
            BW=corr_3D;
            BW(BW~=0)=1;
            for z=1:size(BW,3)
                BW(:,:,z)=bwareaopen(BW(:,:,z),20);
            end
            corr_3D=corr_3D.*BW;
            % corr_3D(:,1:50,:)=0;
            corr_3D(corr_3D==0)=NaN;
            figure('Position',[0 0 700 346])
            %figure('Position',[0 0 816 309])
            for z=1:size(ana,3)
                h = subplottight(4,8,z);
                [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(corr_3D(:,:,z),1),[-0.4 0.4],[],mymap,1,h);
            end
            colormap(mymap)
            set(gcf,'color','black');
            export_fig([file_name,'_',num2str(thrs),'.png'],'-r','300');

            % plot the lag map
            lag_3D(lag_3D==0)=NaN;
            figure('Position',[0 0 700 346])
            %figure('Position',[0 0 816 309])
            for z=1:size(ana,3)
                h = subplottight(4,8,z);
                [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(lag_3D(:,:,z),1),[0 8],[],jet,1,h);
            end
            colormap(jet)
            set(gcf,'color','black');
            export_fig([file_name,'_lag_map.png'],'-r','300');

            % figure
            % %figure('Position',[0 0 816 309])
            % imoverlay(rot90(ana(:,:,7,1),1),rot90(corr_3D(:,:,7),1),[-0.4 0.4],[0 180],mymap,1,h);
            % colormap(mymap)
            % export_fig([file_name,'_',num2str(thrs),'_slice_7.bmp'],'-r','300')
            % 
            % h2=figure
            % imoverlay(rot90(ana(:,:,10),1),rot90(corr_3D(:,:,10),1),[-0.4 0.4],[0 180],mymap,1,h2);
            % colormap(mymap)
            % export_fig([file_name,'_',num2str(thrs),'_slice_10.bmp'],'-r','300')

            % first-level analysis
            f = spm_select('ExtFPList', pwd, ['sr',file_name,'.nii'],1:(dim(4)-T_removed));
            
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
            matlabbatch{1}.spm.stats.fmri_spec.sess.multi_reg =cellstr([results_dir,'/rp_',file_name,'.txt']); 
            matlabbatch{1}.spm.stats.fmri_spec.sess.hpf = 128;
            matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});

% --- CHANGED: Added Temporal Derivative to handle voxelwise delays in GLM ---
            matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [1 0];
            
            matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
            matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
            matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8;
            %matlabbatch{1}.spm.stats.fmri_spec.mask = {[results_dir,'/',file_name,'_mask.nii,1']};
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
            matlabbatch{4}.spm.stats.results.conspec.thresh = 0.05;
            matlabbatch{4}.spm.stats.results.conspec.extent = 20;
            matlabbatch{4}.spm.stats.results.export{1}.png = true;
            matlabbatch{4}.spm.stats.results.export{2}.tspm.basename = [file_name,'_thresh_0.05_extent_20'];

            matlabbatch{5}.spm.stats.results.spmmat = cellstr([results_dir,'/SPM.mat']);
            matlabbatch{5}.spm.stats.results.conspec.contrasts = 1;
            matlabbatch{5}.spm.stats.results.conspec.threshdesc = 'FWE';
            matlabbatch{5}.spm.stats.results.conspec.thresh = 0.05;
            matlabbatch{5}.spm.stats.results.conspec.extent = 20;
            matlabbatch{5}.spm.stats.results.export{1}.png = true;
            matlabbatch{5}.spm.stats.results.export{2}.tspm.basename = [file_name,'_thresh_FWE0.05_extent_20'];

            save([file_name,'_first_level.mat'],'matlabbatch');
            spm_jobman('run',matlabbatch);

            % plot SPM results
            figure('Position',[0 0 700 346])
            t_map = spm_read_vols(spm_vol(['spmT_0001_',file_name,'_thresh_0.05_extent_20.nii']));
            for z=1:size(ana,3)
                h = subplottight(4,8,z);
                [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(t_map(:,:,z),1),[0 15],[],mymap,1,h);
            end
            colormap(autumn)
            set(gcf,'color','black');
            export_fig([file_name,'_thresh_0.05_extent_20.png'],'-r','300');

            figure('Position',[0 0 700 346])
            t_map = spm_read_vols(spm_vol(['spmT_0001_',file_name,'_thresh_FWE0.05_extent_20.nii']));
            for z=1:size(ana,3)
                h = subplottight(4,8,z);
                [hF,hB] = imoverlay(rot90(ana(:,:,z,1),1),rot90(t_map(:,:,z),1),[0 15],[],mymap,1,h);
            end
            colormap(autumn)
            set(gcf,'color','black');
            export_fig([file_name,'_thresh_FWE0.05_extent_20.png'],'-r','300');

            clearvars -except hrf_rat onset_hrf raw_dir preproc_dir T_removed FWHM TR onset onset_scan duration_input thrs mymap T i j subjectname  prestim_num stim_num interstim_num poststim_num block_num tSNR_thrs;            close all
            close all
        end
    end
end
classdef ParameterDialog < handle
    properties (Access = private)
        Figure
        Controls
        WorkingDirPath
        ChatGPT
        AnalysisType
        Parameters
        d2n_dir
        code_dir
        QAenvName
        IsDebugMode = true;  % 调试模式开关
    end

    
    methods (Static)
        function show(analysisType, workingDirPath, chatGPT, code_dir,d2n_dir, QAenvName)
            dialog = modules.ParameterDialog(analysisType, workingDirPath, chatGPT, code_dir,d2n_dir, QAenvName);
            dialog.createDialog();
        end
    end

    methods (Access = public)

       function obj = ParameterDialog(analysisType, workingDirPath, chatGPT, code_dir,d2n_dir, QAenvName)
            obj.AnalysisType = analysisType;
            obj.WorkingDirPath = workingDirPath;
            obj.ChatGPT = chatGPT;
            obj.code_dir = code_dir;
            obj.d2n_dir = d2n_dir;
            obj.QAenvName = QAenvName;
       end
       
        function runAnalysis(obj)
            try
                % 添加调试信息
                disp('Starting analysis...');
                disp(['Analysis Type: ' obj.AnalysisType]);

                % Collect parameters based on analysis type
                switch obj.AnalysisType
                    case 'Bruker2Nifti'
                        params = obj.getBruker2NiftiParams();
                        % 确保参数是正确的类型
                        if ~isnumeric(params.scanIDs) || ~isnumeric(params.referenceIDs)
                            error('Scan ID and Reference ID must be numeric values');
                        end
                        
                        % 调用处理函数
                        processData(obj.d2n_dir, obj.QAenvName, params.inputType, ...
                            params.rawDir, obj.WorkingDirPath, ...
                            params.scanIDs, params.referenceIDs, params.filename);
                        
                        % 显示成功消息
                        uialert(obj.Figure, 'Conversion completed successfully!', ...
                            'Success', 'Icon', 'success');


                    case 'LongTR_BOLD'
                        disp('Getting LongTR parameters...');
                        params = obj.getLongTRParams();
                        
                        % 调试输出参数
                        disp('Parameters collected:');
                        disp(params);
                        
                        % 确保所有参数都是正确的类型
                        filePath = char(params.filePath);  % 转换为字符向量
                        tr = double(params.tr);
                        prestim = double(params.prestimulus_number);
                        stim = double(params.stimulus_number);
                        interstim = double(params.interstimulus_number);
                        poststim = double(params.poststimulus_number);
                        fwhm_1 = double(params.fwhm_1_number);
                        block = double(params.block_number);
                        thresh = params.threshold;  % 这是数组
                        extent = params.extent_threshold;  % 这是数组
                        fd = double(params.fd_threshold);
                        stimvol = double(params.stim_volume);
                        species = char(params.species);  % 转换为字符向量
                        hrf_type = char(params.hrf_type);  % 转换为字符向量 
        
                        % 调用分析函数
                        LongTR_immediate_analysis(filePath, tr, prestim, stim, ...
                            interstim, poststim, block, fwhm_1,thresh, extent, ...
                            fd, stimvol, species, hrf_type);
        
                        % params.filePath = 'C:/Users/zhuyt12023/Desktop/layerfmri_mouse_immediate/b2n_test/auditory/derivative/20240525_423/13/Results.nii';
                        % obj.code_dir = 'C:/Users/zhuyt12023/Desktop/layerfmri_ui/LayerfMRIToolbox';
                        % obj.QAenvName = 'layerfmri';

                        % 生成报告 - 确保所有参数都是字符串
                        [pathstr, scan_name, ~] = fileparts(params.filePath);                        
                        templatePath = fullfile(obj.code_dir, 'report', 'longTR_template.html');
                        datatype = 'longTR';
                        generate_HTML(obj.code_dir,pathstr, scan_name, obj.QAenvName, templatePath, datatype,hrf_type);

                

                    case 'LongTR_CBV'
                            % ==== 记录开始时间 ====
                        startTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                        logFile = fullfile(obj.WorkingDirPath, 'LongTR_BOLD_run_log.txt');
                        fid = fopen(logFile, 'a');  % 追加模式
                        fprintf(fid, '--- LongTR_BOLD run started at %s ---\n', startTime);
                        fclose(fid);

                        disp('Getting LongTR parameters...');
                        params = obj.getLongTRParams();
                        % 调试输出参数
                        disp('Parameters collected:');
                        disp(params);

                        % 确保所有参数都是正确的类型
                        filePath = char(params.filePath);  % 转换为字符向量
                        tr = double(params.tr);
                        prestim = double(params.prestimulus_number);
                        stim = double(params.stimulus_number);
                        interstim = double(params.interstimulus_number);
                        poststim = double(params.poststimulus_number);
                        block = double(params.block_number);
                        thresh = params.threshold;  % 这是数组
                        extent = params.extent_threshold;  % 这是数组
                        fd = double(params.fd_threshold);
                        stimvol = double(params.stim_volume);
                        species = char(params.species);  % 转换为字符向量

                        % 调用分析函数
                        LongTR_MION_immediate_analysis(filePath, tr, prestim, stim, ...
                            interstim, poststim, block, thresh, extent, ...
                            fd, stimvol, species);

                        [pathstr, scan_name, ~] = fileparts(params.filePath);
                        templatePath = fullfile(obj.code_dir, 'report', 'longTR_MION_template.html');
                        datatype = 'longTR_MION';
                        generate_HTML(obj.code_dir,pathstr,scan_name,obj.QAenvName, templatePath,datatype);
                        
                        % ==== 记录结束时间 ====
                        endTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');
                        durationSec = seconds(endTime - startTime);
                        fid = fopen(logFile, 'a');
                        fprintf(fid, 'Run finished at %s\n\n', endTime);
                        fprintf(fid, 'Run finished at %s (Duration: %.2f seconds)\n\n', endTime, durationSec);
                        fclose(fid);

                    case 'ShortTR_BOLD'
                        disp('Getting ShortTR parameters...');
                        params = obj.getShortTRParams();
                        % 调试输出参数
                        disp('Parameters collected:');
                        disp(params);

                        % 确保所有参数都是正确的类型
                        filePath = char(params.filePath);  % 转换为字符向量
                        tr = double(params.tr);
                        prestim = double(params.prestimulus_number);
                        stim = double(params.stimulus_number);
                        interstim = double(params.interstimulus_number);
                        poststim = double(params.poststimulus_number);
                        block = double(params.block_number);
                        thresh = params.threshold;  % 这是数组
                        extent = params.extent_threshold;  % 这是数组
                        fd = double(params.fd_threshold);
                        stimvol = double(params.stim_volume);
                        species = char(params.species);  % 转换为字符向量

                        
                        ShortTR_immediate_analysis(params.filePath, ...
                            str2double(params.tr), str2double(params.prestimulus_number), str2double(params.stimulus_number), ...
                            str2double(params.interstimulus_number), str2double(params.poststimulus_number), ...
                            str2double(params.block_number), str2num(params.threshold), str2num(params.extent_threshold), ...
                            str2double(params.stim_volume), params.species);       
                            [pathstr, scan_name, ~] = fileparts(params.filePath);
                            templatePath = fullfile(obj.code_dir, 'report', 'shortTR_template.html');
                            datatype = 'shortTR';
                            generate_HTML(pathstr,scan_name,obj.QAenvName, templatePath,datatype);

                    case 'ShortTR_CBV'
                        params = obj.getShortTRParams();
                        ShortTR_MION_immediate_analysis(params.filePath, ...
                            double(params.tr), double(params.prestimulus_number), double(params.stimulus_number), ...
                            double(params.interstimulus_number), double(params.poststimulus_number), ...
                            double(params.block_number), params.threshold, params.extent_threshold, ...
                            double(params.stim_volume), params.species);  
                            [pathstr, scan_name, ~] = fileparts(params.filePath);
                            templatePath = fullfile(obj.code_dir, 'report', 'shortTR_MION_template.html');
                            datatype = 'shortTR_MION';
                            generate_HTML(pathstr,scan_name,obj.QAenvName, templatePath,datatype);
                end
            
                % Show success message
                uialert(obj.Figure, ...
                    sprintf('%s analysis completed successfully!', obj.AnalysisType), ...
                    'Success', 'Icon', 'success');
                
                % Close the dialog
                delete(obj.Figure);
                
            catch ME
                % 详细的错误报告
                errorReport = sprintf('Analysis failed:\n');
                errorReport = [errorReport sprintf('Error Message: %s\n', ME.message)];
                errorReport = [errorReport sprintf('Error Stack:\n')];
                for i = 1:length(ME.stack)
                    errorReport = [errorReport sprintf('  File: %s\n  Line: %d\n  Function: %s\n', ...
                        ME.stack(i).file, ME.stack(i).line, ME.stack(i).name)];
                end

                % 显示错误信息
                disp('=================== ERROR REPORT ===================');
                disp(errorReport);
                disp('=================================================');

                uialert(obj.Figure, ...
                    sprintf('Analysis failed: %s', ME.message), ...
                    'Error', 'Icon', 'error');
            end
        end
        function createBatchCode(obj)
            try
                % Get parameters based on analysis type
                switch obj.AnalysisType
                    case 'Bruker2Nifti'
                        params = obj.getBruker2NiftiParams();
                        [singleCode, batchCode] = obj.generateBruker2NiftiBatchCode(params);
                    case {'LongTR_BOLD', 'LongTR_CBV'}
                        params = obj.getLongTRParams();
                        [singleCode, batchCode] = obj.generateLongTRBatchCode(params);
                    case {'ShortTR_BOLD', 'ShortTR_CBV'}
                        params = obj.getShortTRParams();
                        [singleCode, batchCode] = obj.generateShortTRBatchCode(params);
                end
                
                % Create directory for batch scripts
                [filename, pathname] = uiputfile({'*.m', 'MATLAB Script (*.m)'}, ...
                    'Save Single Subject Code');
                
                if filename ~= 0
                    % Save single subject code
                    singlePath = fullfile(pathname, filename);
                    fid = fopen(singlePath, 'w');
                    fprintf(fid, '%s', singleCode);
                    fclose(fid);
                    
                    % Save batch processing code
                    [~, name, ext] = fileparts(filename);
                    batchPath = fullfile(pathname, [name '_batch' ext]);
                    fid = fopen(batchPath, 'w');
                    fprintf(fid, '%s', batchCode);
                    fclose(fid);
                    
                    % Show success message
                    msg = sprintf(['Batch codes saved to:\n\n' ...
                        'Single subject: %s\n' ...
                        'Batch processing: %s'], singlePath, batchPath);
                    uialert(obj.Figure, msg, 'Success', 'Icon', 'success');
                end
                
            catch ME
                uialert(obj.Figure, ...
                    sprintf('Failed to create batch code: %s', ME.message), ...
                    'Error', 'Icon', 'error');
            end
        end
        
        function [singleCode, batchCode] = generateBruker2NiftiBatchCode(obj, params)
            % Generate single subject code
            singleCode = sprintf(['%% Bruker2Nifti Analysis - Single Subject\n' ...
                '%% Generated on %s\n\n' ...
                '%% Parameters\n' ...
                'rawDir = ''%s'';\n' ...
                'inputType = ''%s'';\n' ...
                'scanIDs = %d;\n' ...
                'referenceIDs = %d;\n' ...
                'filename = ''%s'';\n\n' ...
                '%% Run Analysis\n' ...
                'processData(''%s'', ''%s'', ''%s'', rawDir, ''%s'', ...\n' ...
                '    scanIDs, referenceIDs, filename);\n'], ...
                datestr(now), params.rawDir, params.inputType, ...
                params.scanIDs, params.referenceIDs, params.filename, ...
                obj.d2n_dir, obj.QAenvName, params.inputType, obj.WorkingDirPath);
            
            % Generate batch processing code
            batchCode = sprintf(['%% Bruker2Nifti Analysis - Batch Processing\n' ...
                '%% Generated on %s\n\n' ...
                'function runBatchBruker2Nifti()\n' ...
                '    %% Define common parameters\n' ...
                '    d2n_dir = ''%s'';\n' ...
                '    QAenvName = ''%s'';\n' ...
                '    inputType = ''%s'';\n' ...
                '    workingDir = ''%s'';\n\n' ...
                '    %% Define subject list\n' ...
                '    subjects = {\n' ...
                '        %%  rawDir                     scanIDs    referenceIDs    filename\n' ...
                '        {''%s'',                  %d,         %d,           ''%s''}\n' ...
                '        %% Add more subjects here using the same format\n' ...
                '    };\n\n' ...
                '    %% Process all subjects\n' ...
                '    for i = 1:length(subjects)\n' ...
                '        try\n' ...
                '            subject = subjects{i};\n' ...
                '            fprintf(''Processing subject %%d/%%d...\\n'', i, length(subjects));\n' ...
                '            processData(d2n_dir, QAenvName, inputType, subject{1}, workingDir, ...\n' ...
                '                subject{2}, subject{3}, subject{4});\n' ...
                '        catch ME\n' ...
                '            warning(''Error processing subject %%d: %%s'', i, ME.message);\n' ...
                '        end\n' ...
                '    end\n' ...
                'end\n'], ...
                datestr(now), obj.d2n_dir, obj.QAenvName, params.inputType, ...
                obj.WorkingDirPath, params.rawDir, params.scanIDs, ...
                params.referenceIDs, params.filename);
        end
        
        function [singleCode, batchCode] = generateLongTRBatchCode(obj, params)
            % Determine function name based on analysis type
            if contains(obj.AnalysisType, 'BOLD')
                funcName = 'LongTR_immediate_analysis';
            else
                funcName = 'LongTR_MION_immediate_analysis';
            end
            
            % Generate single subject code
            singleCode = sprintf(['%% %s Analysis - Single Subject\n' ...
                '%% Generated on %s\n\n' ...
                '%% Parameters\n' ...
                'filePath = ''%s'';\n' ...
                'tr = %f;\n' ...
                'prestim = %d;\n' ...
                'stim = %d;\n' ...
                'interstim = %d;\n' ...
                'poststim = %d;\n' ...
                'block = %d;\n' ...
                'thresh = [%s];\n' ...
                'extent = [%s];\n' ...
                'fd = %f;\n' ...
                'stimvol = %d;\n' ...
                'species = ''%s'';\n\n' ...
                '%% Run Analysis\n' ...
                '%s(filePath, tr, prestim, stim, interstim, poststim, ...\n' ...
                '    block, thresh, extent, fd, stimvol, species);\n\n' ...
                '%% Generate Report\n' ...
                '[pathstr, scan_name, ~] = fileparts(filePath);\n' ...
                'templatePath = fullfile(''%s'', ''report'', ''%s_template.html'');\n' ...
                'datatype = ''%s'';\n' ...
                'generate_HTML(''%s'', pathstr, scan_name, ''%s'', templatePath, datatype);\n'], ...
                obj.AnalysisType, datestr(now), params.filePath, params.tr, ...
                params.prestimulus_number, params.stimulus_number, ...
                params.interstimulus_number, params.poststimulus_number, ...
                params.block_number, num2str(params.threshold), ...
                num2str(params.extent_threshold), params.fd_threshold, ...
                params.stim_volume, params.species, funcName, obj.code_dir, ...
                lower(obj.AnalysisType), lower(obj.AnalysisType), ...
                obj.code_dir, obj.QAenvName);
            
            % Generate batch processing code
            batchCode = sprintf(['%% %s Analysis - Batch Processing\n' ...
                '%% Generated on %s\n\n' ...
                'function runBatch%s()\n' ...
                '    %% Common parameters\n' ...
                '    tr = %f;\n' ...
                '    prestim = %d;\n' ...
                '    stim = %d;\n' ...
                '    interstim = %d;\n' ...
                '    poststim = %d;\n' ...
                '    block = %d;\n' ...
                '    thresh = [%s];\n' ...
                '    extent = [%s];\n' ...
                '    fd = %f;\n' ...
                '    stimvol = %d;\n' ...
                '    species = ''%s'';\n' ...
                '    code_dir = ''%s'';\n' ...
                '    QAenvName = ''%s'';\n\n' ...
                '    %% Subject list\n' ...
                '    subjects = {\n' ...
                '        %%  filePath\n' ...
                '        ''%s''\n' ...
                '        %% Add more subjects here\n' ...
                '    };\n\n' ...
                '    %% Process all subjects\n' ...
                '    for i = 1:length(subjects)\n' ...
                '        try\n' ...
                '            filePath = subjects{i};\n' ...
                '            fprintf(''Processing subject %%d/%%d: %%s\\n'', i, length(subjects), filePath);\n\n' ...
                '            %% Run analysis\n' ...
                '            %s(filePath, tr, prestim, stim, interstim, poststim, ...\n' ...
                '                block, thresh, extent, fd, stimvol, species);\n\n' ...
                '            %% Generate report\n' ...
                '            [pathstr, scan_name, ~] = fileparts(filePath);\n' ...
                '            templatePath = fullfile(code_dir, ''report'', ''%s_template.html'');\n' ...
                '            datatype = ''%s'';\n' ...
                '            generate_HTML(code_dir, pathstr, scan_name, QAenvName, templatePath, datatype);\n' ...
                '        catch ME\n' ...
                '            warning(''Error processing subject %%d: %%s'', i, ME.message);\n' ...
                '        end\n' ...
                '    end\n' ...
                'end\n'], ...
                obj.AnalysisType, datestr(now), obj.AnalysisType, params.tr, ...
                params.prestimulus_number, params.stimulus_number, ...
                params.interstimulus_number, params.poststimulus_number, ...
                params.block_number, num2str(params.threshold), ...
                num2str(params.extent_threshold), params.fd_threshold, ...
                params.stim_volume, params.species, obj.code_dir, obj.QAenvName, ...
                params.filePath, funcName, lower(obj.AnalysisType), ...
                lower(obj.AnalysisType));
        end
        
        function [singleCode, batchCode] = generateShortTRBatchCode(obj, params)
            % Similar structure to generateLongTRBatchCode but for ShortTR
            if contains(obj.AnalysisType, 'BOLD')
                funcName = 'ShortTR_immediate_analysis';
            else
                funcName = 'ShortTR_MION_immediate_analysis';
            end
            
            % Generate single subject code
            singleCode = sprintf(['%% %s Analysis - Single Subject\n' ...
                '%% Generated on %s\n\n' ...
                '%% Parameters\n' ...
                'filePath = ''%s'';\n' ...
                'tr = %f;\n' ...
                'prestim = %d;\n' ...
                'stim = %d;\n' ...
                'interstim = %d;\n' ...
                'poststim = %d;\n' ...
                'block = %d;\n' ...
                'thresh = %f;\n' ...
                'extent = %f;\n' ...
                'stimvol = %d;\n' ...
                'species = ''%s'';\n\n' ...
                '%% Run Analysis\n' ...
                '%s(filePath, tr, prestim, stim, interstim, poststim, ...\n' ...
                '    block, thresh, extent, stimvol, species);\n\n' ...
                '%% Generate Report\n' ...
                '[pathstr, scan_name, ~] = fileparts(filePath);\n' ...
                'templatePath = fullfile(''%s'', ''report'', ''%s_template.html'');\n' ...
                'datatype = ''%s'';\n' ...
                'generate_HTML(pathstr, scan_name, ''%s'', templatePath, datatype);\n'], ...
                obj.AnalysisType, datestr(now), params.filePath, params.tr, ...
                params.prestimulus_number, params.stimulus_number, ...
                params.interstimulus_number, params.poststimulus_number, ...
                params.block_number, params.threshold, params.extent_threshold, ...
                params.stim_volume, params.species, funcName, obj.code_dir, ...
                lower(obj.AnalysisType), lower(obj.AnalysisType), obj.QAenvName);
            
            % Generate batch processing code
            batchCode = sprintf(['%% %s Analysis - Batch Processing\n' ...
                '%% Generated on %s\n\n' ...
                'function runBatch%s()\n' ...
                '    %% Common parameters\n' ...
                '    tr = %f;\n' ...
                '    prestim = %d;\n' ...
                '    stim = %d;\n' ...
                '    interstim = %d;\n' ...
                '    poststim = %d;\n' ...
                '    block = %d;\n' ...
                '    thresh = %f;\n' ...
                '    extent = %f;\n' ...
                '    stimvol = %d;\n' ...
                '    species = ''%s'';\n' ...
                '    code_dir = ''%s'';\n' ...
                '    QAenvName = ''%s'';\n\n' ...
                '    %% Subject list\n' ...
                '    subjects = {\n' ...
                '        %%  filePath\n' ...
                '        ''%s''\n' ...
                '        %% Add more subjects here\n' ...
                '    };\n\n' ...
                '    %% Process all subjects\n' ...
                '    for i = 1:length(subjects)\n' ...
                '        try\n' ...
                '            filePath = subjects{i};\n' ...
                '            fprintf(''Processing subject %%d/%%d: %%s\\n'', i, length(subjects), filePath);\n\n' ...
                '            %% Run analysis\n' ...
                '            %s(filePath, tr, prestim, stim, interstim, poststim, ...\n' ...
                '                block, thresh, extent, stimvol, species);\n\n' ...
                '            %% Generate report\n' ...
                '            [pathstr, scan_name, ~] = fileparts(filePath);\n' ...
                '            templatePath = fullfile(code_dir, ''report'', ''%s_template.html'');\n' ...
                '            datatype = ''%s'';\n' ...
                '            generate_HTML(pathstr, scan_name, QAenvName, templatePath, datatype);\n' ...
                '        catch ME\n' ...
                '            warning(''Error processing subject %%d: %%s'', i, ME.message);\n' ...
                '        end\n' ...
                '    end\n' ...
                'end\n'], ...
                obj.AnalysisType, datestr(now), obj.AnalysisType, params.tr, ...
                params.prestimulus_number, params.stimulus_number, ...
                params.interstimulus_number, params.poststimulus_number, ...
                params.block_number, params.threshold, params.extent_threshold, ...
                params.stim_volume, params.species, obj.code_dir, obj.QAenvName, ...
                params.filePath, funcName, lower(obj.AnalysisType), ...
                lower(obj.AnalysisType));
        end

        function loadParameters(obj)
            try
                % Open file dialog for loading parameters
                [filename, pathname] = uigetfile({'*.json', 'Parameter Files (*.json)'}, ...
                    'Load Parameters');
                
                if filename == 0
                    return;
                end
                
                % Read JSON file
                fullPath = fullfile(pathname, filename);
                params = jsondecode(fileread(fullPath));
                
                % Update UI controls based on analysis type
                switch obj.AnalysisType
                    case {'ShortTR_BOLD', 'ShortTR_CBV'}
                        obj.loadShortTRParams(params);
                    case {'LongTR_BOLD', 'LongTR_CBV'}
                        obj.loadLongTRParams(params);
                end
                
                uialert(obj.Figure, 'Parameters loaded successfully!', ...
                    'Success', 'Icon', 'success');
                
            catch ME
                uialert(obj.Figure, ...
                    sprintf('Failed to load parameters: %s', ME.message), ...
                    'Error', 'Icon', 'error');
            end
        end
        
        function saveParameters(obj)
            try
                % Get current parameters based on analysis type
                switch obj.AnalysisType
                    case {'ShortTR_BOLD', 'ShortTR_CBV'}
                        params = obj.getShortTRParams();
                    case {'LongTR_BOLD', 'LongTR_CBV'}
                        params = obj.getLongTRParams();
                end
                
                % Open file dialog for saving parameters
                [filename, pathname] = uiputfile({'*.json', 'Parameter Files (*.json)'}, ...
                    'Save Parameters');
                
                if filename == 0
                    return;
                end
                
                % Save to JSON file
                fullPath = fullfile(pathname, filename);
                jsonStr = jsonencode(params, 'PrettyPrint', true);
                fid = fopen(fullPath, 'w');
                fprintf(fid, '%s', jsonStr);
                fclose(fid);
                
                uialert(obj.Figure, 'Parameters saved successfully!', ...
                    'Success', 'Icon', 'success');
                
            catch ME
                uialert(obj.Figure, ...
                    sprintf('Failed to save parameters: %s', ME.message), ...
                    'Error', 'Icon', 'error');
            end
        end
        
        % Add these methods to handle the random stim controls
        function updateRandomStimControls(obj)
            selectedButton = obj.Controls.RandomStimGroup.SelectedObject;
            if strcmp(selectedButton.Text, 'No')
                % Show Stim Volume controls
                obj.Controls.StimVolumeLabel.Visible = 'on';
                obj.Controls.StimVolume.Visible = 'on';
                % Hide Random Stim File controls
                obj.Controls.RandomStimFileLabel.Visible = 'off';
                obj.Controls.RandomStimFile.Visible = 'off';
                obj.Controls.RandomStimBrowse.Visible = 'off';
            else
                % Hide Stim Volume controls
                obj.Controls.StimVolumeLabel.Visible = 'off';
                obj.Controls.StimVolume.Visible = 'off';
                % Show Random Stim File controls
                obj.Controls.RandomStimFileLabel.Visible = 'on';
                obj.Controls.RandomStimFile.Visible = 'on';
                obj.Controls.RandomStimBrowse.Visible = 'on';
            end
        end

        % Add callback function
        function onSpeciesChanged(obj)
            try
                selectedButton = obj.Controls.SpeciesGroup.SelectedObject;
                if ~isempty(selectedButton)
                    % 可以在这里添加任何需要在species改变时执行的代码
                    disp(['Selected species: ' selectedButton.Text]);
                end
            catch ME
                warning('Species selection change error: %s', ME.message);
            end
        end

        function browseRawDir(obj)
            path = uigetdir('', 'Select Raw Data Directory');
            if path ~= 0
                obj.Controls.RawDir.Value = path;
            end
        end
        
        function browseFilePath(obj)
            [filename, pathname] = uigetfile({'*.nii;*.nii.gz', 'NIfTI files (*.nii, *.nii.gz)'}, ...
                'Select NIfTI File');
            if filename ~= 0
                obj.Controls.FilePath.Value = fullfile(pathname, filename);
            end
        end
        function browseRandomStimFile(obj)
            [filename, pathname, ~] = uigetfile({'*.xlsx;*.xls;*.csv;*.txt;*.tsv', 'Data Files (*.xlsx, *.xls, *.csv, *.txt, *.tsv)'}, 'Select Random Stim File');
            if filename ~= 0
                obj.Controls.RandomStimFile.Value = fullfile(pathname, filename);
                stim_file = fullfile(pathname,filename); 
                obj.Controls.RandomStimFile.Value = stim_file;
                stim_info = readtable(stim_file); 
                if iscell(stim_info.Duration_ms_)
                    stim_duration_ms_ = cellfun(@str2double, stim_info.Duration_ms_);
                elseif isstring(stim_info.Duration_ms_)
                    stim_duration_ms_ = str2double(stim_info.Duration_ms_);
                else
                    stim_duration_ms_ = stim_info.Duration_ms_;
                end
                stim_duration_s = stim_duration_ms_/1000;
                TR=0.2;
                obj.Controls.StimVolume.Value = stim_duration_s/TR;
            end

        end
    end

    methods (Access = private)
        
        function createDialog(obj)
            % Create dialog figure
            obj.Figure = uifigure('Name', [obj.AnalysisType ' Parameters'], ...
                'Position', [200 200 600 400], ...
                'Color', [0.98 0.98 0.98]);
            
            % Create parameters based on analysis type
            switch obj.AnalysisType
                case 'Bruker2Nifti'
                    obj.createBruker2NiftiParams();
                case 'LongTR_BOLD'
                    obj.createLongTRParams();
                case 'LongTR_CBV'
                    obj.createLongTRParams();
                case 'ShortTR_BOLD'
                    obj.createShortTRParams();
                case 'ShortTR_CBV'
                    obj.createShortTRParams();
            end
            
            % Create common buttons
            obj.createCommonButtons();
        end
        
        function createBruker2NiftiParams(obj)
            % Raw Directory Selection
            uilabel(obj.Figure, 'Text', 'Raw Directory:', ...
                'Position', [20 340 100 22]);
            
            obj.Controls.RawDir = uieditfield(obj.Figure, ...
                'Position', [130 340 350 22], ...
                'Value', '', ...
                'Editable', 'off');
            
            uibutton(obj.Figure, 'Text', 'Browse', ...
                'Position', [490 340 90 22], ...
                'ButtonPushedFcn', @(btn,event) obj.browseRawDir());
            
            % Input Type (Radio Buttons)
            bg = uibuttongroup(obj.Figure, ...
                'Position', [20 260 560 60], ...
                'Title', 'Input Type');
            
            % Store the button group in Controls
            obj.Controls.InputTypeGroup = bg;
            
            % Create radio buttons
            uiradiobutton(bg, 'Text', 'dicom', ...
                'Position', [10 10 100 22], ...
                'Value', 1);  % Default selection
            uiradiobutton(bg, 'Text', 'multiband', ...
                'Position', [120 10 120 22]);
            
            % Scan ID
            uilabel(obj.Figure, 'Text', 'Scan ID:', ...
                'Position', [20 220 100 22]);
            obj.Controls.ScanID = uieditfield(obj.Figure, 'numeric', ...
                'Position', [130 220 100 22], ...
                'Value', 1);
            
            % Reference ID
            uilabel(obj.Figure, 'Text', 'Reference ID:', ...
                'Position', [20 180 100 22]);
            obj.Controls.RefID = uieditfield(obj.Figure, 'numeric', ...
                'Position', [130 180 100 22], ...
                'Value', 1);
            
            % Filename
            uilabel(obj.Figure, 'Text', 'Filename:', ...
                'Position', [20 140 100 22]);
            obj.Controls.Filename = uieditfield(obj.Figure, ...
                'Position', [130 140 350 22], ...
                'Value', 'converted_data');
        end
        
        function createLongTRParams(obj)
            % Add Load/Save Parameter buttons at the top
            uibutton(obj.Figure, 'Text', 'Load Parameters', ...
                'Position', [290 50 120 25], ...
                'BackgroundColor', [0.3 0.6 0.8], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(btn,event) obj.loadParameters());

            uibutton(obj.Figure, 'Text', 'Save Parameters', ...
                'Position', [420 50 120 25], ...
                'BackgroundColor', [0.2 0.6 0.2], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(btn,event) obj.saveParameters());
            % File Path Selection
            uilabel(obj.Figure, 'Text', 'File Path:', ...
                'Position', [20 340 100 22]);
            
            obj.Controls.FilePath = uieditfield(obj.Figure, ...
                'Position', [130 340 350 22], ...
                'Value', '', ...
                'Editable', 'off');
            
            uibutton(obj.Figure, 'Text', 'Browse', ...
                'Position', [490 340 90 22], ...
                'ButtonPushedFcn', @(btn,event) obj.browseFilePath());
            
            % Left column parameters
            leftParamConfigs = {
                'TR',                   [20 300],  1.0;
                'Prestimulus Number',   [20 260],  30;
                'Stimulus Number',      [20 220],  10;
                'Interstimulus Number', [20 180],  30;
                'Poststimulus Number',  [20 140],  30;
                'Block Number',         [20 100],  15
            };
            
            % Right column parameters
            rightParamConfigs = {
                'Threshold',           [350 300],  '0.01,0.05';
                'Extent Threshold',    [350 260],  '10,20';
                'FD Threshold',        [350 220],  1.5;
                'Stim Volume',         [350 180],  10;
            };
            
            % Create left column parameters
            for i = 1:size(leftParamConfigs, 1)
                uilabel(obj.Figure, 'Text', leftParamConfigs{i,1}, ...
                    'Position', [leftParamConfigs{i,2}(1) leftParamConfigs{i,2}(2) 120 22]);
                
                fieldName = strrep(lower(leftParamConfigs{i,1}), ' ', '_');
                obj.Controls.(fieldName) = uieditfield(obj.Figure, 'numeric', ...
                    'Position', [leftParamConfigs{i,2}(1) + 130 leftParamConfigs{i,2}(2) 100 22], ...
                    'Value', leftParamConfigs{i,3});
            end
            
            % Create right column parameters
            for i = 1:size(rightParamConfigs, 1)
                uilabel(obj.Figure, 'Text', rightParamConfigs{i,1}, ...
                    'Position', [rightParamConfigs{i,2}(1) rightParamConfigs{i,2}(2) 120 22]);
                
                fieldName = strrep(lower(rightParamConfigs{i,1}), ' ', '_');
                if ismember(rightParamConfigs{i,1}, {'Threshold', 'Extent Threshold'})
                    % Text field for comma-separated values
                    obj.Controls.(fieldName) = uieditfield(obj.Figure, ...
                        'Position', [rightParamConfigs{i,2}(1) + 130 rightParamConfigs{i,2}(2) 100 22], ...
                        'Value', rightParamConfigs{i,3}, ...
                        'Tooltip', 'Enter multiple values separated by comma');
                else
                    % Numeric field for single values
                    obj.Controls.(fieldName) = uieditfield(obj.Figure, 'numeric', ...
                        'Position', [rightParamConfigs{i,2}(1) + 130 rightParamConfigs{i,2}(2) 100 22], ...
                        'Value', rightParamConfigs{i,3});
                end
            end
            
            % Add a help text label for thresholds
            uilabel(obj.Figure, 'Text', 'Note: For Threshold and Extent Threshold, enter values separated by commas', ...
                'Position', [350 155 400 22], ...
                'FontAngle', 'italic', ...
                'FontSize', 9);
            
            % Species Selection (Radio Buttons)
            bg = uibuttongroup(obj.Figure, ...
                'Position', [20 20 200 50], ...
                'Title', 'Species', ...
                'SelectionChangedFcn', @(~,~) obj.onSpeciesChanged());
            
            obj.Controls.SpeciesGroup = bg;
            
            % 创建Mouse按钮getLongTRParams
            mouseBtn = uiradiobutton(bg, ...
                'Text', 'Mouse', ...
                'Position', [10 10 80 22], ...
                'Tag', 'mouse');  % 使用Tag存储小写值

            % 创建Rat按钮
            ratBtn = uiradiobutton(bg, ...
                'Text', 'Rat', ...
                'Position', [100 10 80 22], ...
                'Tag', 'rat');    % 使用Tag存储小写值

            % 默认选择Mouse
            mouseBtn.Value = 1;

            % HRF Selection (Radio Buttons)
            hrfBg = uibuttongroup(obj.Figure, ...
                'Position', [280 100 320 50], ...
                'Title', 'Additional HRF', ...
                'SelectionChangedFcn', @(~,~) obj.onHRFChanged());

            obj.Controls.HRFGroup = hrfBg;

            % 创建Default Only按钮
            noneBtn = uiradiobutton(hrfBg, ...
                'Text', 'Default Only', ...
                'Position', [10 10 100 22], ...
                'Tag', 'none',  ...
                'Tooltip', 'Only use default HRF parameters');

            % 创建Mouse Auditory按钮
            auditoryBtn = uiradiobutton(hrfBg, ...
                'Text', 'Mouse Auditory', ...
                'Position', [100 10 100 22], ...
                'Tag', 'mouse_auditory', ...
                'Tooltip', 'Use both default and mouse auditory HRF parameters');

            % 创建Mouse Whisker按钮
            whiskerBtn = uiradiobutton(hrfBg, ...
                'Text', 'Mouse Whisker', ...
                'Position', [210 10 100 22], ...
                'Tag', 'mouse_whisker', ...
                'Tooltip', 'Use both default and mouse whisker HRF parameters');

            % 默认选择Default Only
            noneBtn.Value = 1;
            

        end
        
        
        function createShortTRParams(obj)
            % Add Load/Save Parameter buttons at the top
            uibutton(obj.Figure, 'Text', 'Load Parameters', ...
                'Position', [290 50 120 25], ...
                'BackgroundColor', [0.3 0.6 0.8], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(btn,event) obj.loadParameters());
            
            uibutton(obj.Figure, 'Text', 'Save Parameters', ...
                'Position', [420 50 120 25], ...
                'BackgroundColor', [0.2 0.6 0.2], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(btn,event) obj.saveParameters());
            
            % File Path Selection
            uilabel(obj.Figure, 'Text', 'File Path:', ...
                'Position', [20 340 100 22]);
            
            obj.Controls.FilePath = uieditfield(obj.Figure, ...
                'Position', [130 340 350 22], ...
                'Value', '', ...
                'Editable', 'off');
            
            uibutton(obj.Figure, 'Text', 'Browse', ...
                'Position', [490 340 90 22], ...
                'ButtonPushedFcn', @(btn,event) obj.browseFilePath());
            
            % Numeric parameters - Left column
            leftParamConfigs = {
                'TR',                   [20 300],  1.0;
                'Prestimulus Number',   [20 260],  30;
                'Stimulus Number',      [20 220],  30;
                'Interstimulus Number', [20 180],  30
            };
            
            % Numeric parameters - Right column
            rightParamConfigs = {
                'Poststimulus Number',  [300 300],  30;
                'Block Number',         [300 260],  5;
                'Threshold',           [300 220],  0.001;
                'Extent Threshold',    [300 180],  0
            };
            
            % Create numeric input fields - Left column
            for i = 1:size(leftParamConfigs, 1)
                uilabel(obj.Figure, 'Text', leftParamConfigs{i,1}, ...
                    'Position', [leftParamConfigs{i,2}(1) leftParamConfigs{i,2}(2) 120 22]);
                
                fieldName = strrep(lower(leftParamConfigs{i,1}), ' ', '_');
                obj.Controls.(fieldName) = uieditfield(obj.Figure, 'numeric', ...
                    'Position', [leftParamConfigs{i,2}(1) + 130 leftParamConfigs{i,2}(2) 100 22], ...
                    'Value', leftParamConfigs{i,3});
            end
            
            % Create numeric input fields - Right column
            for i = 1:size(rightParamConfigs, 1)
                uilabel(obj.Figure, 'Text', rightParamConfigs{i,1}, ...
                    'Position', [rightParamConfigs{i,2}(1) rightParamConfigs{i,2}(2) 120 22]);
                
                fieldName = strrep(lower(rightParamConfigs{i,1}), ' ', '_');
                obj.Controls.(fieldName) = uieditfield(obj.Figure, 'numeric', ...
                    'Position', [rightParamConfigs{i,2}(1) + 130 rightParamConfigs{i,2}(2) 100 22], ...
                    'Value', rightParamConfigs{i,3});
            end
            
            % Random Stim Selection (Radio Buttons)
            bg = uibuttongroup(obj.Figure, ...
                'Position', [20 120 560 50], ...  % Adjusted position
                'Title', 'Random Stim', ...
                'SelectionChangedFcn', @(~,~) obj.updateRandomStimControls());
            
            obj.Controls.RandomStimGroup = bg;
            
            uiradiobutton(bg, 'Text', 'Yes', ...
                'Position', [10 5 80 22], ...
                'Value', 1);
            
            uiradiobutton(bg, 'Text', 'No', ...
                'Position', [100 5 80 22]);
            
            % Stim Volume controls
            obj.Controls.StimVolumeLabel = uilabel(obj.Figure, 'Text', 'Stim Volume:', ...
                'Position', [20 90 100 22]);  % Adjusted position
            obj.Controls.StimVolume = uieditfield(obj.Figure, 'numeric', ...
                'Position', [130 90 100 22], ...  % Adjusted position
                'Value', 30);
            
            % Random Stim File controls
            obj.Controls.RandomStimFileLabel = uilabel(obj.Figure, 'Text', 'Random Stim File:', ...
                'Position', [20 90 100 22], ...  % Same vertical position as StimVolume
                'Visible', 'off');
            obj.Controls.RandomStimFile = uieditfield(obj.Figure, ...
                'Position', [130 90 350 22], ...  % Same vertical position as StimVolume
                'Value', '', ...
                'Editable', 'off', ...
                'Visible', 'off');
            obj.Controls.RandomStimBrowse = uibutton(obj.Figure, 'Text', 'Browse', ...
                'Position', [490 90 90 22], ...  % Same vertical position as StimVolume
                'ButtonPushedFcn', @(btn,event) obj.browseRandomStimFile(), ...
                'Visible', 'off');
            
            % Species Selection (Radio Buttons)
            bg = uibuttongroup(obj.Figure, ...
                'Position', [20 20 200 50], ...  % Adjusted position
                'Title', 'Species', ...
                'SelectionChangedFcn', @(~,~) obj.onSpeciesChanged());
            
            obj.Controls.SpeciesGroup = bg;
            
            % 创建Mouse按钮getLongTRParams
            mouseBtn = uiradiobutton(bg, ...
                'Text', 'Mouse', ...
                'Position', [10 10 80 22], ...
                'Tag', 'mouse');  % 使用Tag存储小写值

            % 创建Rat按钮
            ratBtn = uiradiobutton(bg, ...
                'Text', 'Rat', ...
                'Position', [100 10 80 22], ...
                'Tag', 'rat');    % 使用Tag存储小写值

            % 默认选择Mouse
            mouseBtn.Value = 1;
            
            % Initial update of random stim controls
            obj.updateRandomStimControls();
        end
        
        function createCommonButtons(obj)
            % Create Batch Code button
            uibutton(obj.Figure, 'Text', 'Create Batch Code', ...
                'Position', [250 20 120 25], ...
                'BackgroundColor', [0.3 0.6 0.8], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(btn,event) obj.createBatchCode());
            % Run button
            uibutton(obj.Figure, 'Text', 'Run', ...
                'Position', [380 20 90 25], ...
                'BackgroundColor', [0.2 0.6 0.2], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(btn,event) obj.runAnalysis());
            
            % Cancel button
            uibutton(obj.Figure, 'Text', 'Cancel', ...
                'Position', [480 20 90 25], ...
                'ButtonPushedFcn', @(btn,event) delete(obj.Figure));
        end
        
        
        
        function params = getBruker2NiftiParams(obj)
            params = struct();
            
            % 获取并验证原始数据目录
            params.rawDir = obj.Controls.RawDir.Value;
            if isempty(params.rawDir)
                error('Raw directory must be selected');
            end
            
            % 获取并验证Scan ID
            scanIDStr = obj.Controls.ScanID.Value;
            if isempty(scanIDStr)
                error('Scan ID cannot be empty');
            end
            % 确保scanID是数字
            if isnumeric(scanIDStr)
                params.scanIDs = scanIDStr;
            else
                % 如果是字符串，尝试转换为数
                try
                    params.scanIDs = str2double(scanIDStr);
                    if isnan(params.scanIDs)
                        error('Invalid Scan ID: must be a number');
                    end
                catch
                    error('Invalid Scan ID format');
                end
            end
            
            % 获取并验证Reference ID
            refIDStr = obj.Controls.RefID.Value;
            if isempty(refIDStr)
                error('Reference ID cannot be empty');
            end
            % 确保referenceID是数字
            if isnumeric(refIDStr)
                params.referenceIDs = refIDStr;
            else
                % 如果是字符串，尝试转换为数字
                try
                    params.referenceIDs = str2double(refIDStr);
                    if isnan(params.referenceIDs)
                        error('Invalid Reference ID: must be a number');
                    end
                catch
                    error('Invalid Reference ID format');
                end
            end
            
            % 获取文件名
            params.filename = obj.Controls.Filename.Value;
            if isempty(params.filename)
                error('Filename cannot be empty');
            end
            
            % 获取输入类型
            selectedButton = obj.Controls.InputTypeGroup.SelectedObject;
            params.inputType = selectedButton.Text;
        end

        function params = getLongTRParams(obj)
            params = struct();
            
            % 验证文件路径
            if isempty(obj.Controls.FilePath.Value)
                error('File path cannot be empty');
            end
            params.filePath = obj.Controls.FilePath.Value;
            
            % 验证并转换数值参数
            numericParams = {
                'tr', 'TR';
                'prestimulus_number', 'Prestimulus Number';
                'stimulus_number', 'Stimulus Number';
                'interstimulus_number', 'Interstimulus Number';
                'poststimulus_number', 'Poststimulus Number';
                'block_number', 'Block Number';
                'fd_threshold', 'FD Threshold';
                'stim_volume', 'Stim Volume'
            };
            
            for i = 1:size(numericParams, 1)
                fieldName = numericParams{i,1};
                displayName = numericParams{i,2};
                value = obj.Controls.(fieldName).Value;
                % value = str2double(value);
                
                % 验证数值
                if isempty(value) || isnan(value) || isinf(value)
                    error('%s must be a valid number', displayName);
                end
                params.(fieldName) = value;
            end
            
            % 处理阈值（可能包含多个值）
            thresholdStr = obj.Controls.threshold.Value;
            try
                thresholdValues = str2num(thresholdStr); % 使用str2num而不是str2double
                if isempty(thresholdValues) || any(isnan(thresholdValues)) || any(isinf(thresholdValues))
                    error('Threshold must contain valid numbers (e.g., 0.01,0.05)');
                end
                params.threshold = thresholdValues;
            catch
                error('Invalid threshold format. Use comma-separated numbers (e.g., 0.01,0.05)');
            end
            
            % 处理extent threshold（可能包含多个值）
            extentStr = obj.Controls.extent_threshold.Value;
            try
                extentValues = str2num(extentStr); % 使用str2num而不是str2double
                if isempty(extentValues) || any(isnan(extentValues)) || any(isinf(extentValues))
                    error('Extent threshold must contain valid numbers (e.g., 0,5)');
                end
                params.extent_threshold = extentValues;
            catch
                error('Invalid extent threshold format. Use comma-separated numbers (e.g., 0,5)');
            end
            
            % 获取species
            species_selectedButton = obj.Controls.SpeciesGroup.SelectedObject;
            if isempty(species_selectedButton)
                error('Species must be selected');
            end
            params.species = species_selectedButton.Tag;

            % 获取HRF类型
            hrf_selectedButton = obj.Controls.HRFGroup.SelectedObject;
            % 获取选择的HRF类型
            hrfType = hrf_selectedButton.Tag;
            % 根据选择设置相应的HRF参数
            switch hrfType
                case 'none'
                    % 只使用默认参数
                    params.hrf_type = 'default';
                case 'mouse_auditory'
                    % 使用默认和听觉参数
                    params.hrf_type = 'mouse_auditory';
                case 'mouse_whisker'
                    % 使用默认和触须参数
                    params.hrf_type = 'mouse_whisker';
            end
        end

        % Add this method to collect parameters
        function params = getShortTRParams(obj)
            params = struct();
            params.filePath = obj.Controls.FilePath.Value;
            params.tr = obj.Controls.tr.Value;
            params.prestimulus_number = obj.Controls.prestimulus_number.Value;
            params.stimulus_number = obj.Controls.stimulus_number.Value;
            params.interstimulus_number = obj.Controls.interstimulus_number.Value;
            params.poststimulus_number = obj.Controls.poststimulus_number.Value;
            params.block_number = obj.Controls.block_number.Value;
            params.threshold = obj.Controls.threshold.Value;
            params.extent_threshold = obj.Controls.extent_threshold.Value;
            
            % Get random stim selection and related value
            selectedButton = obj.Controls.RandomStimGroup.SelectedObject;
            params.random_stim = selectedButton.Text;
            if strcmp(params.random_stim, 'No')
                params.stim_volume = obj.Controls.StimVolume.Value;
                params.random_stim_file = '';
            else
                params.stim_volume = [];
                params.random_stim_file = obj.Controls.RandomStimFile.Value;
            end
            
            % Get selected species
            try
                selectedButton = obj.Controls.SpeciesGroup.SelectedObject;
                if isempty(selectedButton)
                    error('Species must be selected');
                end
                params.species = selectedButton.Tag;
            catch ME
                error('Failed to get species selection: %s', ME.message);
            end
        end
        
        
        
        function loadShortTRParams(obj, params)
            % Update numeric fields
            obj.Controls.tr.Value = params.tr;
            obj.Controls.prestimulus_number.Value = params.prestimulus_number;
            obj.Controls.stimulus_number.Value = params.stimulus_number;
            obj.Controls.interstimulus_number.Value = params.interstimulus_number;
            obj.Controls.poststimulus_number.Value = params.poststimulus_number;
            obj.Controls.block_number.Value = params.block_number;
            obj.Controls.threshold.Value = params.threshold;
            obj.Controls.extent_threshold.Value = params.extent_threshold;
            
            % Update random stim selection
            for btn = obj.Controls.RandomStimGroup.Children'
                if strcmp(btn.Text, params.random_stim)
                    btn.Value = 1;
                    break;
                end
            end
            
            % Update dependent controls based on random stim selection
            obj.updateRandomStimControls();
            if strcmp(params.random_stim, 'Yes')
                obj.Controls.StimVolume.Value = params.stim_volume;
            else
                obj.Controls.RandomStimFile.Value = params.random_stim_file;
            end
            
            % Update species selection
            for btn = obj.Controls.SpeciesGroup.Children'
                if strcmp(btn.Text, params.species)
                    btn.Value = 1;
                    break;
                end
            end
        end
        
        function loadLongTRParams(obj, params)
            % Similar to loadShortTRParams but for Long TR parameters
            obj.Controls.tr.Value = params.tr;
            obj.Controls.prestimulus_number.Value = params.prestimulus_number;
            obj.Controls.stimulus_number.Value = params.stimulus_number;
            obj.Controls.interstimulus_number.Value = params.interstimulus_number;
            obj.Controls.poststimulus_number.Value = params.poststimulus_number;
            obj.Controls.block_number.Value = params.block_number;
            obj.Controls.threshold.Value = params.threshold;
            obj.Controls.extent_threshold.Value = params.extent_threshold;
            obj.Controls.fd_threshold.Value = params.fd_threshold;
            obj.Controls.stim_volume.Value = params.stim_volume;
            
            % Update species selection
            for btn = obj.Controls.SpeciesGroup.Children'
                if strcmp(btn.Text, params.species)
                    btn.Value = 1;
                    break;
                end
            end
        end
        function onHRFChanged(obj)
           try
                selectedButton = obj.Controls.HRFGroup.SelectedObject;
                if ~isempty(selectedButton)
                    % 可以在这里添加任何需要在species改变时执行的代码
                    disp(['Selected hrf: ' selectedButton.Text]);
                end
            catch ME
                warning('hrf selection change error: %s', ME.message);
            end
%             % 获取选中的按钮
%             selectedButton = obj.Controls.HRFGroup.SelectedObject;
%             % 获取选择的HRF类型
%             hrfType = selectedButton.Tag;
%             % 根据选择设置相应的HRF参数
%             switch hrfType
%                 case 'Default Only'
%                     % 只使用默认参数
%                     obj.hrf_type = 'default';
%                 case 'Mouse Auditory'
%                     % 使用默认和听觉参数
%                     obj.hrf_type = 'mouse_auditory';
%                 case 'Mouse Whisker'
%                     % 使用默认和触须参数
%                     obj.hrf_type = 'mouse_whisker';
%             end
        end
        % Add validation function
        function validateThresholds(obj, thresholdStr, extentStr)
            % Validate threshold values
            thresholdValues = str2double(strsplit(thresholdStr, ','));
            if any(isnan(thresholdValues)) || any(thresholdValues < 0) || any(thresholdValues > 1)
                error('Threshold values must be between 0 and 1');
            end
            
            % Validate extent threshold values
            extentValues = str2double(strsplit(extentStr, ','));
            if any(isnan(extentValues)) || any(extentValues < 0)
                error('Extent threshold values must be non-negative numbers');
            end
        end

    end

    methods (Access = private)
        function debugPrint(obj, message)
            if obj.IsDebugMode
                disp(['DEBUG: ' message]);
            end
        end
    end
end
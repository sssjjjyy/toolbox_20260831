function generate_HTML_debug(code_dir,inputPath,outputPath,subjectName,envName, templatePath,datatype,hrf_type)
    % 根据 datatype 设置 generatePath
    if strcmp(datatype, 'longTR')
        generatePath = fullfile(code_dir, 'report', 'generate_longTR_HTML.py');
    elseif strcmp(datatype, 'longTR_MION')
        generatePath = fullfile(code_dir, 'report', 'generate_longTR_MION_HTML.py');
    elseif strcmp(datatype, 'shortTR')
        generatePath = fullfile(code_dir, 'report', 'generate_shortTR_HTML.py');
    elseif strcmp(datatype, 'shortTR_MION')
        generatePath = fullfile(code_dir, 'report', 'generate_shortTR_MION_HTML.py');
    elseif strcmp(datatype, 'InteractiveProfile')
        generatePath = fullfile(code_dir, 'report', 'generate_InteractiveProfile_HTML.py');
    else
        error('Unsupported datatype: %s', datatype);
    end
    
    % ========== 调试信息打印 ==========
    fprintf('\n========== Python Script Debug Info ==========\n');
    fprintf('Code Dir: %s\n', code_dir);
    fprintf('Input Path: %s\n', inputPath);
    fprintf('Output Path: %s\n', outputPath);
    fprintf('Subject Name: %s\n', subjectName);
    fprintf('Env Name: %s\n', envName);
    fprintf('Template Path: %s\n', templatePath);
    fprintf('Data Type: %s\n', datatype);
    fprintf('HRF Type: %s\n', hrf_type);
    fprintf('Python Script Path: %s\n', generatePath);
    
    % 检查文件是否存在
    if ~isfile(generatePath)
        error('Python script not found: %s', generatePath);
    end
    
    if ~isfile(templatePath)
        error('Template file not found: %s', templatePath);
    end
    
    if ~isfolder(inputPath)
        error('Input folder not found: %s', inputPath);
    end
    
    fprintf('✓ All files and folders exist\n');
    
    % ========== 构建命令（确保路径用引号包围） ==========
    % 方法1：使用临时日志文件记录错误
    logFile = fullfile(tempdir, 'python_output.log');
    
    pythonCommand = sprintf(['conda activate %s && python "%s" "%s" --output_dir "%s" %s ' ...
        '--hrf_type %s --template "%s" > "%s" 2>&1'], ...
        envName, generatePath, inputPath, outputPath, subjectName, hrf_type, templatePath, logFile);
    
    fprintf('\n========== Executing Command ==========\n');
    fprintf('%s\n\n', pythonCommand);
    
    % ========== 执行命令 ==========
    [status, cmdout] = system(pythonCommand);
    
    fprintf('========== Command Output ==========\n');
    fprintf('Status Code: %d\n', status);
    fprintf('Output:\n%s\n', cmdout);
    
    % ========== 读取日志文件 ==========
    if isfile(logFile)
        fprintf('\n========== Detailed Log File ==========\n');
        fid = fopen(logFile, 'r');
        logContent = fread(fid, '*char')';
        fclose(fid);
        fprintf('%s\n', logContent);
        
        % 删除日志文件
        delete(logFile);
    end
    
    % ========== 检查输出结果 ==========
    fprintf('\n========== Output Files Check ==========\n');
    outputHtmlDir = fullfile(outputPath, 'Results_HTML');
    if isfolder(outputHtmlDir)
        htmlFiles = dir(fullfile(outputHtmlDir, '*.html'));
        fprintf('Found %d HTML files in %s\n', length(htmlFiles), outputHtmlDir);
        for i = 1:length(htmlFiles)
            fprintf('  - %s\n', htmlFiles(i).name);
        end
    else
        fprintf('⚠ Output directory not found: %s\n', outputHtmlDir);
    end
    
    if status ~= 0
        fprintf('\n❌ Command failed with status: %d\n', status);
    else
        fprintf('\n✓ Command executed successfully\n');
    end
end
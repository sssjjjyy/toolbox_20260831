function generate_HTML(code_dir,inputPath,outputPath,subjectName,envName, templatePath,datatype,hrf_type)
    % 根据 datatype 设置 generatePath
%             inputPath=pathstr;
%             subjectName=scan_name;
%             envName=app.QAenvName;
%             templatePath,datatype
    if strcmp(datatype, 'longTR')
        generatePath = fullfile(code_dir, 'report', 'generate_longTR_HTML_1011.py');
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
    pythonCommand = ['conda activate ', envName, ' && python ',generatePath,' ', inputPath,' --output_dir ',outputPath,' ' subjectName,' --hrf_type ',hrf_type,' --template ', templatePath,];
    system(pythonCommand);
    pythonCommand = sprintf('conda activate %s && python "%s" "%s" --output_dir "%s" ...', envName, generatePath, inputPath, outputPath);

end
classdef ProcessPipelineModule < handle
    properties (Access = private)
        Figure
        ChatGPT
        Controls
        Pipeline = {}
        Participants = {}
        ModulePath   % Add path to modules
        DefaultPipeline = {}  % Add default pipeline configuration
        FunctionParameterList = struct()  % Store function parameters
        FunctionParameterTextList = struct()  % Store parameter UI controls
        CodeDir  % Path to code directory
        WorkDir  % Add working directory property
    end
    
    methods
        function obj = ProcessPipelineModule(chatGPT)
            obj.ChatGPT = chatGPT;
            % Get the path to the LayerfMRIToolbox directory
            currentFile = mfilename('fullpath');
            [toolboxPath, ~, ~] = fileparts(fileparts(currentFile));
            obj.ModulePath = fullfile(toolboxPath,'process_module');

            obj.loadDefaultPipeline();
        end
        
        function show(obj)
            obj.Figure = uifigure('Name', 'Process Pipeline', ...
                'Position', [150 150 1200 800],'WindowStyle', 'modal');
            
            obj.createLayout();
        end
    end
    
    methods (Access = private)

        function createLayout(obj)
            % Create main grid layout
            grid = uigridlayout(obj.Figure, [1 2]);
            grid.ColumnWidth = {'3x', '1x'};

            
            % Create pipeline panel on the left
            % pipelinePanel = uipanel(grid);
            % pipelinePanel.Title = 'Pipeline';
            obj.createPipelinePanel(grid);
            
            % Create right container for participants and chat
            rightContainer = uigridlayout(grid, [2 1]);
            rightContainer.RowHeight = {'2x', '1x'};  % 参与者面板占2份，聊天窗口占1份
            
            % Create participants panel
            participantsPanel = uipanel(rightContainer);
            participantsPanel.Title = 'Participants';
            obj.createParticipantsPanel(participantsPanel);
            
            % Create ChatGPT panel below participants
            chatPanel = uipanel(rightContainer);
            chatPanel.Title = 'ChatGPT Assistant';
            obj.createChatControls(chatPanel);
        end
        
        function createChatControls(obj, panel)
            % Create grid layout for chat controls
            grid = uigridlayout(panel, [2 1]);
            grid.RowHeight = {'4x', '1x'};
            grid.Padding = [5 5 5 5];
            
            % Create response display area
            obj.Controls.ChatResponse = uitextarea(grid);
            obj.Controls.ChatResponse.Value = 'ChatGPT responses will appear here...';
            obj.Controls.ChatResponse.Editable = false;
            
            % Create input area with send button
            inputGrid = uigridlayout(grid, [1 2]);
            inputGrid.ColumnWidth = {'5x', '1x'};
            inputGrid.Padding = [0 0 0 0];
            
            obj.Controls.ChatQuery = uitextarea(inputGrid);
            obj.Controls.ChatQuery.Value = '';
            obj.Controls.ChatQuery.Placeholder = 'Type your question here...';
            
            % Send button
            uibutton(inputGrid, 'Text', 'Send', ...
                'ButtonPushedFcn', @(btn,event) obj.askChatGPT());
        end

        
        function loadDefaultPipeline(obj)
            % Load default pipeline configuration from a file
            defaultConfigPath = fullfile('configs', 'default_pipeline.json');
            if exist(defaultConfigPath, 'file')
                config = jsondecode(fileread(defaultConfigPath));
                obj.DefaultPipeline = config.pipeline;
            end
        end
        function functions = getAvailableFunctions(obj)
            % Dynamically get available functions from process_module folder
            moduleFiles = dir(fullfile(obj.ModulePath, '*.m'));
            functions = {};
            for i = 1:length(moduleFiles)
                [~, funcName, ~] = fileparts(moduleFiles(i).name);
                functions{end+1} = funcName;
            end
        end

        function script = createPipelineScript(obj)
            script = '% Pipeline Processing Script\n\n';
            
            % Add module imports
            script = [script '% Add module path\n'];
            script = [script 'addpath(''' obj.ModulePath ''');\n\n'];
            
            % Add parameters
            script = [script '% Parameters\n'];
            params = obj.collectParameters();
            script = [script 'params = ' obj.struct2str(params) ';\n\n'];
            
            % Add processing steps
            script = [script '% Processing Steps\n'];
            for i = 1:length(obj.Pipeline)
                % Get the module file content
                moduleFile = fullfile(obj.ModulePath, [obj.Pipeline{i} '.m']);
                if exist(moduleFile, 'file')
                    moduleContent = fileread(moduleFile);
                    script = [script sprintf('\n%% %s\n', obj.Pipeline{i})];
                    script = [script moduleContent '\n'];
                    script = [script sprintf('%s(params.%s);\n', ...
                        obj.Pipeline{i}, obj.Pipeline{i})];
                end
            end
                % Execute pipeline button
            uibutton(panel, 'Text', 'Execute Pipeline', ...
                'Position', [660 350 100 30], ...
                'ButtonPushedFcn', @(btn,event) obj.executePipeline());
            
            % Add cleanup
            script = [script '\n% Cleanup\n'];
            script = [script 'rmpath(''' obj.ModulePath ''');\n'];
        end

        function executePipeline(obj)
            % Execute each step in the pipeline
            for i = 1:length(obj.Pipeline)
                currentStep = obj.Pipeline{i};
                
                % Collect parameters for current step
                params = struct();
                if isfield(obj.FunctionParameterList, currentStep)
                    params = obj.FunctionParameterList.(currentStep);
                end
                
                % Add common parameters
                params.subjects = obj.Controls.ParticipantList.Items;
                params.working_dirs = obj.Participants;
                
                % Execute the current step
                try
                    feval(currentStep, params);
                    disp(['Successfully completed: ' currentStep]);
                catch ME
                    warning(['Error in step ' currentStep ': ' ME.message]);
                    obj.handleError(ME);
                end
            end
        end
        
        function createPipelinePanel(obj, grid)
            pipelinePanel = uipanel(grid);
            pipelinePanel.Title = 'Pipeline Configuration';
            
            % Create function list with all available functions
            availableFunctions = {
                'deface',
                'rsfmri_dicom2nifti',
                'rsfmri_bruker2bids',
                'longTR_QualityControl',
                'rsfmri_bias_field_correction',
                'rsfmri_sdc',
                'rsfmri_brainmask_ben_finetune',
                'rsfmri_brainmask_ben_T2',
                'rsfmri_brainmask_ben_EPI',
                'rsfmri_slice_timing',
                'rsfmri_motion_correction',
                'rsfmri_regression',
                'rsfmri_bandpassfilt',
                'rsfmri_smooth_2D',
                'tfmri_1st_level_analysis',
                'tfmri_cotical_depth'
            };
            
            % Create function list
            obj.Controls.FunctionList = uilistbox(pipelinePanel, ...
                'Position', [10 400 300 300], ...
                'Items', availableFunctions, ...
                'ValueChangedFcn', @(src,event) obj.functionSelected(src.Value));
            
            % Create pipeline display
            obj.createPipelineDisplay(pipelinePanel);
            
            % Create parameter panel
            obj.createParameterPanel(pipelinePanel);
            
            % Create control buttons
            obj.createPipelineControls(pipelinePanel);
        end
        
        function createPipelineControls(obj, panel)
            % Add function to pipeline
            uibutton(panel, 'Text', 'Add Function', ...
                'Position', [10 350 100 30], ...
                'ButtonPushedFcn', @(btn,event) obj.addFunction());
            
            % Remove function from pipeline
            uibutton(panel, 'Text', 'Remove Function', ...
                'Position', [120 350 120 30], ...
                'ButtonPushedFcn', @(btn,event) obj.removeFunction());
            
            % Move function up/down
            uibutton(panel, 'Text', '↑', ...
                'Position', [250 350 40 30], ...
                'ButtonPushedFcn', @(btn,event) obj.moveFunction('up'));
            
            uibutton(panel, 'Text', '↓', ...
                'Position', [300 350 40 30], ...
                'ButtonPushedFcn', @(btn,event) obj.moveFunction('down'));
            
            % Clear pipeline button
            uibutton(panel, 'Text', 'Clear Pipeline', ...
                'Position', [350 350 100 30], ...
                'ButtonPushedFcn', @(btn,event) obj.clearPipeline());
            
            % Save/Load pipeline
            uibutton(panel, 'Text', 'Save Pipeline', ...
                'Position', [460 350 100 30], ...
                'ButtonPushedFcn', @(btn,event) obj.savePipeline());
            
            uibutton(panel, 'Text', 'Load Pipeline', ...
                'Position', [570 350 100 30], ...
                'ButtonPushedFcn', @(btn,event) obj.loadPipeline());
            
            % Generate script
            uibutton(panel, 'Text', 'Generate Script', ...
                'Position', [680 350 100 30], ...
                'ButtonPushedFcn', @(btn,event) obj.generateScript());
        end
        
        function createParameterPanel(obj, panel)
            paramPanel = uipanel(panel, ...
                'Position', [10 50 810 290], ...
                'Title', 'Function Parameters');
            
            % Parameter controls will be created dynamically
            obj.Controls.ParameterGrid = uigridlayout(paramPanel, [1 1]);
        end
        
        % function createParticipantsPanel(obj, grid)
        %     participantsPanel = uipanel(grid);
        %     participantsPanel.Title = 'Participants';
            
        %     % Create working directory selection
        %     uilabel(participantsPanel, 'Text', 'Working Directory:', ...
        %         'Position', [10 720 100 22]);
            
        %     % Text field for working directory
        %     obj.Controls.WorkDirField = uieditfield(participantsPanel, ...
        %         'Position', [10 690 200 22], ...
        %         'Value', '', ...
        %         'Editable', 'off');
            
        %     % Browse button for working directory
        %     uibutton(participantsPanel, 'Text', 'Browse', ...
        %         'Position', [220 690 70 22], ...
        %         'ButtonPushedFcn', @(btn,event) obj.selectWorkDir());
            
        %     % Create participant list
        %     obj.Controls.ParticipantList = uilistbox(participantsPanel, ...
        %         'Position', [10 50 280 620], ...
        %         'Items', {}, ...
        %         'MultiSelect', 'on', ...
        %         'ValueChangedFcn', @(src,event) disp(['Selection changed: ' num2str(length(src.Value)) ' items selected']));
            
        %     % Create participant control buttons
        %     obj.createParticipantControls(participantsPanel);
        % end
        function createParticipantsPanel(obj, panel)
            % Create grid layout for participants panel
            grid = uigridlayout(panel, [4 3]);
            grid.RowHeight = {'fit', '10x', '0.5x', 'fit'};  % 使用 'fit' 替代 'auto'
            grid.ColumnWidth = {'1x', 'fit', 'fit'};
            grid.Padding = [5 5 5 5];
            grid.RowSpacing = 5;
            grid.ColumnSpacing = 5;
            
            % Working Directory Label
            uilabel(grid, 'Text', 'Working Directory:');
            
            % Text field for working directory (spans 2 columns)
            obj.Controls.WorkDirField = uieditfield(grid, ...
                'Value', '', ...
                'Editable', 'off');
            obj.Controls.WorkDirField.Layout.Column = [1 2];
            
            % Browse button
            uibutton(grid, 'Text', 'Browse', ...
                'ButtonPushedFcn', @(btn,event) obj.selectWorkDir());
            
            % Create participant list (spans all columns)
            obj.Controls.ParticipantList = uilistbox(grid, ...
                'Items', {}, ...
                'MultiSelect', 'on', ...
                'ValueChangedFcn', @(src,event) disp(['Selection changed: ' num2str(length(src.Value)) ' items selected']));
                obj.Controls.ParticipantList.Layout.Column = [1 3];
    
                % Create participant control buttons in the bottom row
                buttonGrid = uigridlayout(grid, [1 2]);
                buttonGrid.Layout.Column = [1 3];
                buttonGrid.Padding = [0 0 0 0];
                buttonGrid.ColumnSpacing = 5;
                
                % Add participant control buttons (original ones)
                uibutton(buttonGrid, 'Text', 'Add Participant', ...
                    'ButtonPushedFcn', @(btn,event) obj.addParticipantsByFolder());
                
                uibutton(buttonGrid, 'Text', 'Remove Participant', ...
                    'ButtonPushedFcn', @(btn,event) obj.removeParticipants());
        end

        function selectWorkDir(obj)
            % Open folder selection dialog
            path = uigetdir(pwd, 'Select Working Directory');
            
            if path ~= 0
                obj.WorkDir = path;
                obj.Controls.WorkDirField.Value = path;
                
                % Update default path for participant selection
                if isempty(obj.Participants)
                    cd(path);
                end
                % 将窗口重新置顶
                figure(obj.Figure);
            end
        end
        
        function addParticipantsByFolder(obj)
            if isempty(obj.WorkDir)
                errordlg('Please select a working directory first.', 'Error');
                return;
            end
            
            % Let user select multiple directories using uipickfiles
            folderNames = uipickfiles('FilterSpec', obj.WorkDir, ...
                'REFilter', '.*', ...
                'Prompt', 'Select subject directories:');
            
            if ~isempty(folderNames) && iscell(folderNames)
                % Extract directory paths and names
                [parentDirs, subjectNames] = cellfun(@fileparts, ...
                    folderNames, 'UniformOutput', false);
                
                % Check for duplicates
                currentItems = obj.Controls.ParticipantList.Items;
                newSubjects = {};
                newParentDirs = {};
                
                for i = 1:length(subjectNames)
                    if ~ismember(subjectNames{i}, currentItems)
                        newSubjects{end+1} = subjectNames{i};
                        newParentDirs{end+1} = parentDirs{i};
                    else
                        warndlg(['Subject "' subjectNames{i} '" already exists.'], 'Warning');
                    end
                end
                
                if ~isempty(newSubjects)
                    % Add new participants
                    obj.Participants = [obj.Participants, newParentDirs];
                    
                    % Update participant list
                    obj.Controls.ParticipantList.Items = [currentItems, newSubjects];
                    
                    % Force visual update
                    drawnow;
                end
            end
        end

        function removeParticipants(obj)
            % Get selected item text
            selectedItems = obj.Controls.ParticipantList.Value;
            
            if ~isempty(selectedItems)
                try
                    % Get all current items
                    currentItems = obj.Controls.ParticipantList.Items;
                    
                    % Find indices of selected items
                    if iscell(selectedItems)
                        % For multiple selections
                        removeIndices = [];
                        for i = 1:length(selectedItems)
                            idx = find(strcmp(currentItems, selectedItems{i}));
                            removeIndices = [removeIndices, idx];
                        end
                    else
                        % For single selection
                        removeIndices = find(strcmp(currentItems, selectedItems));
                    end
                    
                    % Keep indices of items to retain
                    keepIndices = true(1, length(currentItems));
                    keepIndices(removeIndices) = false;
                    
                    % First clear selection (before updating items)
                    obj.Controls.ParticipantList.Value = {};
                    
                    % Then update participants and list
                    obj.Participants = obj.Participants(keepIndices);
                    obj.Controls.ParticipantList.Items = currentItems(keepIndices);
                    
                    % Force visual update
                    drawnow;
                    
                catch ME
                    disp('Error during removal:');
                    disp(ME.message);
                end
            end
        end


        function functionSelected(obj, selectedFunc)
            if ~isempty(selectedFunc)
                % Show parameter dialog for the selected function
                obj.openParameterDialog(selectedFunc);
            end
        end
        
        % 3. 修改参数显示，保存所有类型参数的历史记录
        function openParameterDialog(obj, selectedFunction)
            % Get function file path
            funcPath = fullfile(obj.ModulePath, [selectedFunction, '.m']);
            
            % Read function parameters
            params = obj.extractFunctionParameters(funcPath);
            
            if ~isempty(params)
                % Clear existing parameter controls
                delete(obj.Controls.ParameterGrid.Children);
                
                % Create new parameter controls
                grid = uigridlayout(obj.Controls.ParameterGrid, [length(params)+1 3]);
                grid.ColumnWidth = {'2x', '3x', '1x'};
                
                % Add parameter controls with empty values
                for i = 1:length(params)
                    paramName = params{i};
                    
                    % Add label
                    uilabel(grid, 'Text', paramName);
                    
                    % Add appropriate control based on parameter type
                    if contains(paramName, 'path') && ~contains(paramName, 'exclude')
                        editField = uieditfield(grid, 'Editable', 'off');
                        obj.FunctionParameterTextList.(selectedFunction).(paramName) = editField;
                        
                        uibutton(grid, 'Text', 'Browse', ...
                            'ButtonPushedFcn', @(btn,event) obj.browseParameter(selectedFunction, paramName));
                    else
                        editField = uieditfield(grid);
                        obj.FunctionParameterTextList.(selectedFunction).(paramName) = editField;
                        uipanel(grid); % Empty panel for alignment
                    end
                end
                
                % Add Add Function button
                uibutton(grid, 'Text', 'Add Function', ...
                    'ButtonPushedFcn', @(btn,event) obj.addFunction());
            end
        end

        function saveParameters(obj, dlg, funcName)
            % Save parameters from dialog to FunctionParameterList
            params = struct();
            fields = fieldnames(obj.FunctionParameterTextList.(funcName));
            
            for i = 1:length(fields)
                paramName = fields{i};
                params.(paramName) = obj.FunctionParameterTextList.(funcName).(paramName).Value;
            end
            
            obj.FunctionParameterList.(funcName) = params;
            close(dlg);
        end

        function savePipeline(obj)
            [file, path] = uiputfile('*.json', 'Save Pipeline Configuration');
            if file ~= 0
                % Create configuration structure
                config = struct();
                config.pipeline = obj.Pipeline;
                config.parameters = obj.FunctionParameterList;
                
                % Save to JSON
                jsonStr = jsonencode(config, 'PrettyPrint', true);
                fid = fopen(fullfile(path, file), 'w');
                fprintf(fid, '%s', jsonStr);
                fclose(fid);
            end
        end

        function loadPipeline(obj)
            [file, path] = uigetfile('*.json', 'Load Pipeline Configuration');
            if file ~= 0
                % Load configuration
                config = jsondecode(fileread(fullfile(path, file)));
                
                % Update pipeline
                obj.Pipeline = config.pipeline;
                obj.FunctionParameterList = config.parameters;
                
                % Update display
                obj.updatePipelineDisplay();
            end
        end
        
        function params = getFunctionParameters(obj, funcName)
            % Return parameters for specific function
            % This should be implemented based on your function specifications
            switch funcName
                case 'Preprocessing'
                    params = {'Input Directory', 'Output Directory', 'File Pattern'};
                case 'Motion Correction'
                    params = {'Reference Volume', 'Interpolation Method'};
                otherwise
                    params = {};
            end
        end
        
        function addFunction(obj)
            % Get selected function from function list
            selectedFunc = obj.Controls.FunctionList.Value;
            
            if ~isempty(selectedFunc)
                try
                    % Initialize parameter structure if needed
                    if ~isfield(obj.FunctionParameterList, selectedFunc)
                        obj.FunctionParameterList.(selectedFunc) = struct();
                    end
                    
                    % Get all parameter fields for this function
                    paramFields = fieldnames(obj.FunctionParameterTextList.(selectedFunc));
                    
                    % Save all parameters
                    for i = 1:length(paramFields)
                        paramName = paramFields{i};
                        currentValue = obj.FunctionParameterTextList.(selectedFunc).(paramName).Value;
                        obj.FunctionParameterList.(selectedFunc).(paramName) = currentValue;
                    end
                    
                    % Add function to pipeline
                    if isempty(obj.Pipeline)
                        obj.Pipeline = {};
                    end
                    obj.Pipeline{end+1} = selectedFunc;
                    
                    % Update pipeline display
                    obj.updatePipelineDisplay();
                    
                    % Clear parameter panel
                    obj.clearParameterPanel();
                    
                    % Debug information
                    disp(['Added function: ' selectedFunc]);
                    disp('Parameters:');
                    disp(obj.FunctionParameterList.(selectedFunc));
                    
                catch ME
                    disp(['Error adding function: ' ME.message]);
                    obj.handleError(ME);
                end
            end
        end
        
        function removeFunction(obj)
            % Get selected node from pipeline display
            selectedNode = obj.Controls.PipelineDisplay.SelectedNodes;
            
            if ~isempty(selectedNode)
                try
                    % Get the index from the node text (assumes format "1. FunctionName")
                    nodeText = selectedNode(1).Text;
                    % Extract number before the dot
                    idx = str2double(regexp(nodeText, '^\d+', 'match'));
                    
                    if ~isnan(idx) && idx > 0 && idx <= length(obj.Pipeline)
                        % Remove function from pipeline
                        obj.Pipeline(idx) = [];
                        
                        % Update pipeline display
                        obj.updatePipelineDisplay();
                        
                        % Debug information
                        disp(['Removed function at index: ' num2str(idx)]);
                        disp(['Pipeline length: ' num2str(length(obj.Pipeline))]);
                    end
                catch ME
                    disp(['Error in removeFunction: ' ME.message]);
                    obj.handleError(ME);
                end
            else
                disp('No pipeline item selected');
            end
        end

        function moveFunction(obj, direction)
            % Get selected node
            selectedNode = obj.Controls.PipelineDisplay.SelectedNodes;
            
            if ~isempty(selectedNode)
                try
                    % Get current index
                    nodeText = selectedNode(1).Text;
                    % 使用简单的数字提取方法
                    dotIndex = strfind(nodeText, '.');
                    if ~isempty(dotIndex)
                        currentIdx = str2double(nodeText(1:dotIndex(1)-1));
                    else
                        return;
                    end
                    
                    if isnan(currentIdx)
                        return;
                    end
                    
                    % Calculate new index
                    if strcmp(direction, 'up') && currentIdx > 1
                        newIdx = currentIdx - 1;
                    elseif strcmp(direction, 'down') && currentIdx < length(obj.Pipeline)
                        newIdx = currentIdx + 1;
                    else
                        return;
                    end
                    
                    % Swap functions
                    temp = obj.Pipeline{currentIdx};
                    obj.Pipeline{currentIdx} = obj.Pipeline{newIdx};
                    obj.Pipeline{newIdx} = temp;
                    
                    % Update display
                    obj.updatePipelineDisplay();
                    
                    % Select the moved item
                    nodes = obj.Controls.PipelineDisplay.Children;
                    if ~isempty(nodes)
                        for i = 1:length(nodes)
                            nodeText = nodes(i).Text;
                            dotIdx = strfind(nodeText, '.');
                            if ~isempty(dotIdx)
                                nodeIndex = str2double(nodeText(1:dotIdx(1)-1));
                                if nodeIndex == newIdx
                                    % 使用 uitree 的 SelectedNodes 属性来设置选择
                                    obj.Controls.PipelineDisplay.SelectedNodes = nodes(i);
                                    break;
                                end
                            end
                        end
                    end
                    
                    % Debug information
                    disp(['Moved function from ' num2str(currentIdx) ' to ' num2str(newIdx)]);
                    
                catch ME
                    disp(['Error in moveFunction: ' ME.message]);
                    obj.handleError(ME);
                end
            end
        end
        
        function updatePipelineDisplay(obj)
            % Clear existing nodes
            delete(obj.Controls.PipelineDisplay.Children);
            
            % Add nodes for each function in pipeline
            for i = 1:length(obj.Pipeline)
                node = uitreenode(obj.Controls.PipelineDisplay, ...
                    'Text', sprintf('%d. %s', i, obj.Pipeline{i}));
            end
            
            % Force visual update
            drawnow;
        end
        
        function params = collectParameters(obj)
            % Collect all parameter values
            params = struct();
            for i = 1:length(obj.Pipeline)
                funcParams = obj.getFunctionParameters(obj.Pipeline{i});
                for j = 1:length(funcParams)
                    controlName = sprintf('Param_%s_%d', obj.Pipeline{i}, j);
                    if isfield(obj.Controls, controlName)
                        params.(obj.Pipeline{i}).(funcParams{j}) = ...
                            obj.Controls.(controlName).Value;
                    end
                end
            end
        end
        
        function applyParameters(obj, params)
            % Apply loaded parameters to controls
            fields = fieldnames(params);
            for i = 1:length(fields)
                funcParams = obj.getFunctionParameters(fields{i});
                for j = 1:length(funcParams)
                    controlName = sprintf('Param_%s_%d', fields{i}, j);
                    if isfield(obj.Controls, controlName)
                        obj.Controls.(controlName).Value = ...
                            params.(fields{i}).(funcParams{j});
                    end
                end
            end
        end
        
        function generateScript(obj)
            % Generate MATLAB script for the pipeline
            script = obj.createPipelineScript();
            
            [file, path] = uiputfile('*.m', 'Save Pipeline Script');
            if file ~= 0
                fid = fopen(fullfile(path, file), 'w');
                fprintf(fid, '%s', script);
                fclose(fid);
            end
        end
        
        function str = struct2str(obj, s)
            % Convert structure to string representation
            str = 'struct(';
            fields = fieldnames(s);
            for i = 1:length(fields)
                if i > 1
                    str = [str ', '];
                end
                if isstruct(s.(fields{i}))
                    str = [str '''' fields{i} ''', ' obj.struct2str(s.(fields{i}))];
                else
                    str = [str '''' fields{i} ''', ''' s.(fields{i}) ''''];
                end
            end
            str = [str ')'];
        end
        
        function addParticipants(obj)
            % Let user select multiple directories using uipickfiles
            folderNames = uipickfiles('FilterSpec', pwd, ...
                'REFilter', '.*', ...
                'Prompt', 'Select subject directories:');
            
            if ~isempty(folderNames) && iscell(folderNames)  % Check if directories were selected
                % Extract directory paths and names
                [subjectDirectories, subjectNames] = cellfun(@fileparts, folderNames, 'UniformOutput', false);
                
                % Add new participants
                obj.Participants = [obj.Participants, subjectDirectories];
                
                % Update participant list with subject names
                obj.Controls.ParticipantList.Items = subjectNames;
                
            elseif ischar(folderNames)  % Single directory selected
                [subjectDirectory, subjectName] = fileparts(folderNames);
                
                % Add new participant
                obj.Participants = [obj.Participants, {subjectDirectory}];
                
                % Update participant list
                obj.Controls.ParticipantList.Items = {subjectName};
                
            else
                % Selection was canceled - do nothing
            end
        end

        % function Dicom2Nifti(params)
        %     for i = 1:numel(params.subjects)
        %         subject_folder = params.subjects{i};
        %         working_dir = params.working_dirs{i};
        %         dataset_txt = fullfile(working_dir, subject_folder, 'dataset.txt');
        %         dataset = read_dataset(dataset_txt);
                
        %         T2 = {dataset.T2};
        %         EPI = {dataset.EPI1, dataset.EPI2};
        %         if contains(dataset.EPI1, ',')
        %             dataset.EPI1 = strsplit(dataset.EPI1, ',');
        %             EPI = {dataset.EPI1{:}, dataset.EPI2};
        %         end
                
        %         rsfmri_dicom2nifti_batch(working_dir, subject_folder, [T2, EPI]);
        %     end
        % end

        % function Bruker2BIDS(params)
        %     for j = 1:numel(params.subjects)
        %         subject_folder = params.subjects{j};
        %         working_dir = params.working_dirs{j};
        %         dataset_name = 'sourcedata';
                
        %         % Get subject number
        %         sub_num = regexp(subject_folder, '\d+', 'match');
        %         sub_num = strcat(sub_num{3}, sub_num{4});
                
        %         % Read dataset
        %         dataset_txt = fullfile(working_dir, subject_folder, 'dataset.txt');
        %         dataset = read_dataset(dataset_txt);
                
        %         % Process events
        %         events = create_events_struct(dataset);
                
        %         % Convert to BIDS
        %         [target_file, T2_file] = rsfmri_bruker2bids(working_dir, params.output_dir, ...
        %             subject_folder, dataset_name, sub_num, params.task_names, ...
        %             params.type_set, T2, EPI, events);
                    
        %         % Store results
        %         params.target_files{j} = target_file;
        %         params.T2_files{j} = T2_file;
        %     end
        % end


        function updateParameterPanel(obj, funcName)
            % Clear existing controls
            delete(obj.Controls.ParameterGrid.Children);
            
            % Get function file path
            funcPath = fullfile(obj.CodeDir, 'preproc_func', [funcName, '.m']);
            
            % Read function parameters from file
            params = obj.extractFunctionParameters(funcPath);
            
            if ~isempty(params)
                % Create parameter controls
                grid = uigridlayout(obj.Controls.ParameterGrid, [length(params) 3]);
                grid.ColumnWidth = {'2x', '3x', '1x'};
                
                for i = 1:length(params)
                    paramName = params{i};
                    
                    % Add label
                    uilabel(grid, 'Text', paramName);
                    
                    % Add input field
                    if contains(paramName, 'path') && ~contains(paramName, 'exclude')
                        % Path selection
                        editField = uieditfield(grid, 'Editable', 'off');
                        obj.FunctionParameterTextList.(funcName).(paramName) = editField;
                        
                        % Browse button
                        uibutton(grid, 'Text', 'Browse', ...
                            'ButtonPushedFcn', @(btn,event) obj.browseParameter(funcName, paramName));
                    elseif contains(paramName, 'threshdesc')
                        % Threshold selection
                        panel = uipanel(grid);
                        layout = uigridlayout(panel, [1 3]);
                        thresholdOptions = {'none', 'FWE', 'FDR'};
                        for j = 1:length(thresholdOptions)
                            uicheckbox(layout, 'Text', thresholdOptions{j}, ...
                                'ValueChangedFcn', @(cbx,event) obj.thresholdSelected(cbx, funcName, paramName));
                        end
                        grid.ColumnSpan = [1 2];
                    else
                        % Standard text input
                        editField = uieditfield(grid);
                        obj.FunctionParameterTextList.(funcName).(paramName) = editField;
                        uipanel(grid); % Empty panel for grid alignment
                    end
                end
            end
        end

        % 新增用于更新参数值的函数
        function updateParameterValue(obj, funcName, paramName, value)
            % Ensure the function exists in the parameter list
            if ~isfield(obj.FunctionParameterList, funcName)
                obj.FunctionParameterList.(funcName) = struct();
            end
            
            % Update the parameter value
            obj.FunctionParameterList.(funcName).(paramName) = value;
            
            % Debug information
            disp(['Updated ' funcName '.' paramName ': ' char(string(value))]);
        end

        function params = extractFunctionParameters(obj, funcPath)
            % Read function file to extract parameter names
            functionText = fileread(funcPath);
            paramPattern = 'function\s+\w+\s*=?\s*\w+\(([\w\s,]+)\)';
            paramNames = regexp(functionText, paramPattern, 'tokens', 'once');
            
            params = {};
            if ~isempty(paramNames)
                paramNames = strsplit(paramNames{1}, ',');
                for i = 1:numel(paramNames)
                    paramName = strtrim(paramNames{i});
                    if ~contains(paramName, 'exclude')
                        params{end+1} = paramName;
                    end
                end
            end
        end


        function browseParameter(obj, funcName, paramName)
            if contains(paramName, 'weight')
                % File selection for weights
                [filename, pathname] = uigetfile();
                if filename ~= 0
                    value = fullfile(pathname, filename);
                    obj.FunctionParameterList.(funcName).(paramName) = value;
                    obj.FunctionParameterTextList.(funcName).(paramName).Value = value;

                    % 将窗口重新置顶
                    figure(obj.Figure);
                end
            else
                % Directory selection
                path = uigetdir();
                if path ~= 0
                    obj.FunctionParameterList.(funcName).(paramName) = path;
                    obj.FunctionParameterTextList.(funcName).(paramName).Value = path;

                    % 将窗口重新置顶
                    figure(obj.Figure);
                end
            end
        end

        function thresholdSelected(obj, checkbox, funcName, paramName)
            % Initialize if needed
            if ~isfield(obj.FunctionParameterList, funcName) || ...
               ~isfield(obj.FunctionParameterList.(funcName), paramName)
                obj.FunctionParameterList.(funcName).(paramName) = {};
            end
            
            if checkbox.Value
                % Add threshold
                obj.FunctionParameterList.(funcName).(paramName){end+1} = checkbox.Text;
            else
                % Remove threshold
                index = cellfun(@(x) isequal(x, checkbox.Text), ...
                    obj.FunctionParameterList.(funcName).(paramName));
                obj.FunctionParameterList.(funcName).(paramName)(index) = [];
            end
        end
        
        function valid = validateParameters(obj, funcName)
            % Check if all required parameters are filled
            if isfield(obj.FunctionParameterList, funcName)
                params = obj.FunctionParameterList.(funcName);
                fields = fieldnames(params);
                
                % Debug information
                disp(['Validating parameters for: ' funcName]);
                disp('Current parameters:');
                disp(params);
                
                valid = true;  % 默认为 true
                return;  % 如果有参数列表，就认为是有效的
            else
                % 如果是新函数，也返回 true
                valid = true;
            end
        end

        function clearParameterPanel(obj)
            % Clear parameter panel
            delete(obj.Controls.ParameterGrid.Children);
            % Get first item as default or empty string if no items
            if ~isempty(obj.Controls.FunctionList.Items)
                obj.Controls.FunctionList.Value = obj.Controls.FunctionList.Items{1};
            else
                obj.Controls.FunctionList.Value = '';
            end
        end

        % 添加清空pipeline的方法
        function clearPipeline(obj)
            % Ask for confirmation
            choice = questdlg('Are you sure you want to clear the entire pipeline?', ...
                'Clear Pipeline', ...
                'Yes', 'No', 'No');
            
            if strcmp(choice, 'Yes')
                % Clear pipeline
                obj.Pipeline = {};
                
                % Clear parameter list
                obj.FunctionParameterList = struct();
                
                % Update display
                obj.updatePipelineDisplay();
                
                % Clear parameter panel
                obj.clearParameterPanel();
                
                % Debug information
                disp('Pipeline cleared');
            end
        end

        function createPipelineDisplay(obj, panel)
            % Create pipeline display tree
            obj.Controls.PipelineDisplay = uitree(panel, ...
                'Position', [320 400 500 300], ...
                'SelectionChangedFcn', @(src,event) obj.pipelineNodeSelected(event.SelectedNodes));
        end

        function pipelineNodeSelected(obj, selectedNodes)
            if ~isempty(selectedNodes)
                % Extract function name from node text (remove index number)
                nodeText = selectedNodes(1).Text;
                [~, funcName] = strtok(nodeText, '.');
                funcName = strtrim(funcName(2:end)); % Remove dot and spaces
                
                % Show parameter dialog for the selected function with saved parameters
                obj.openParameterDialogWithSavedParams(funcName);
            end
        end

        function openParameterDialogWithSavedParams(obj, selectedFunction)
            % Get function file path
            funcPath = fullfile(obj.ModulePath, [selectedFunction, '.m']);
            
            % Read function parameters
            params = obj.extractFunctionParameters(funcPath);
            
            if ~isempty(params)
                % Clear existing parameter controls
                delete(obj.Controls.ParameterGrid.Children);
                
                % Create new parameter controls
                grid = uigridlayout(obj.Controls.ParameterGrid, [length(params)+1 3]);
                grid.ColumnWidth = {'2x', '3x', '1x'};
                
                % Add parameter controls
                for i = 1:length(params)
                    paramName = params{i};
                    
                    % Add label
                    uilabel(grid, 'Text', paramName);
                    
                    % Get saved value
                    savedValue = '';
                    if isfield(obj.FunctionParameterList, selectedFunction) ...
                            && isfield(obj.FunctionParameterList.(selectedFunction), paramName)
                        savedValue = obj.FunctionParameterList.(selectedFunction).(paramName);
                    end
                    
                    % Add appropriate control based on parameter type
                    if contains(paramName, 'path') && ~contains(paramName, 'exclude')
                        editField = uieditfield(grid, 'Editable', 'off');
                        if ~isempty(savedValue)
                            editField.Value = savedValue;
                        end
                        obj.FunctionParameterTextList.(selectedFunction).(paramName) = editField;
                        
                        uibutton(grid, 'Text', 'Browse', ...
                            'ButtonPushedFcn', @(btn,event) obj.browseParameter(selectedFunction, paramName));
                    else
                        editField = uieditfield(grid);
                        if ~isempty(savedValue)
                            editField.Value = savedValue;
                        end
                        obj.FunctionParameterTextList.(selectedFunction).(paramName) = editField;
                        uipanel(grid); % Empty panel for alignment
                    end
                end
                
                % Add Update button
                uibutton(grid, 'Text', 'Update Parameters', ...
                    'ButtonPushedFcn', @(btn,event) obj.updateFunctionParameters(selectedFunction));
            end
        end

        function updateFunctionParameters(obj, funcName)
            try
                % Initialize parameter structure if it doesn't exist
                if ~isfield(obj.FunctionParameterList, funcName)
                    obj.FunctionParameterList.(funcName) = struct();
                end
                
                % Get all parameter fields for this function
                paramFields = fieldnames(obj.FunctionParameterTextList.(funcName));
                
                % Update all parameters
                for i = 1:length(paramFields)
                    paramName = paramFields{i};
                    % Get the current value from the UI control
                    currentValue = obj.FunctionParameterTextList.(funcName).(paramName).Value;
                    % Save the value
                    obj.FunctionParameterList.(funcName).(paramName) = currentValue;
                end
                
                % Debug information
                disp(['Updated parameters for: ' funcName]);
                disp('New parameter values:');
                disp(obj.FunctionParameterList.(funcName));
                
                % Clear parameter panel
                obj.clearParameterPanel();
                
                % Update pipeline display
                obj.updatePipelineDisplay();
                
            catch ME
                disp(['Error updating parameters: ' ME.message]);
                obj.handleError(ME);
            end
        end
        
        function handleError(obj, ME)
            % 构建错误信息
            errorMsg = getReport(ME, 'extended', 'hyperlinks', 'off');
            
            % 显示错误信息在MATLAB命令窗口
            disp('Error occurred:');
            disp(errorMsg);
            
            % 将错误信息发送到ChatGPT输入框
            if isfield(obj.Controls, 'ChatQuery')
                obj.Controls.ChatQuery.Value = sprintf('I got this MATLAB error: %s\nCan you help me understand and fix it?', errorMsg);
            end
            
            % 自动发送到ChatGPT
            obj.askChatGPT();
        end
        
        function askChatGPT(obj)
            try
                % Get the query
                query = obj.Controls.ChatQuery.Value;
                if isempty(query)
                    return;
                end
                
                % Show loading message
                obj.Controls.ChatResponse.Value = 'Getting response from ChatGPT...';
                drawnow;
                
                % Get response from ChatGPT
                response = obj.ChatGPT.getResponse(query);
                
                % Update response area
                obj.Controls.ChatResponse.Value = response;
                
                % Clear query area
                obj.Controls.ChatQuery.Value = '';
                
            catch ME
                % Handle any errors in the ChatGPT communication
                obj.Controls.ChatResponse.Value = sprintf('Error communicating with ChatGPT: %s', ME.message);
            end
        end

    end
end 
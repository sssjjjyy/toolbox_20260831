classdef ParameterDialog < handle
    properties (Access = private)
        Figure
        Parameters
        WorkingDir
        ChatGPT
        Controls
    end
    
    methods (Static)
        function show(analysisType, workingDir, chatGPT)
            dialog = ParameterDialog(analysisType, workingDir, chatGPT);
            dialog.createDialog();
        end
    end
    
    methods (Access = private)
        function obj = ParameterDialog(analysisType, workingDir, chatGPT)
            obj.Parameters = obj.getDefaultParameters(analysisType);
            obj.WorkingDir = workingDir;
            obj.ChatGPT = chatGPT;
        end
        
        function createDialog(obj)
            % Create dialog figure
            obj.Figure = uifigure('Name', 'Analysis Parameters', ...
                'Position', [200 200 600 800]);
            
            % Create parameter controls
            obj.createParameterControls();
            
            % Create action buttons
            obj.createActionButtons();
            
            % Create ChatGPT panel
            obj.createChatGPTPanel();
        end
        
        function params = getDefaultParameters(~, analysisType)
            % Return default parameters based on analysis type
            params = struct();
            switch analysisType
                case 'LongTR_Normal'
                    params.TR = 2;
                    params.Volumes = 100;
                    % Add more parameters
            end
        end
        
        function createParameterControls(obj)
            % Create controls for each parameter
            fields = fieldnames(obj.Parameters);
            for i = 1:length(fields)
                label = uilabel(obj.Figure, ...
                    'Position', [20 750-40*i 150 22], ...
                    'Text', fields{i});
                
                obj.Controls.(fields{i}) = uieditfield(obj.Figure, ...
                    'Position', [180 750-40*i 150 22], ...
                    'Value', num2str(obj.Parameters.(fields{i})));
            end
        end
        
        function createActionButtons(obj)
            % Create Run button
            uibutton(obj.Figure, 'Text', 'Run Analysis', ...
                'Position', [20 100 150 30], ...
                'ButtonPushedFcn', @(btn,event) obj.runAnalysis());
            
            % Create Generate Script button
            uibutton(obj.Figure, 'Text', 'Generate Script', ...
                'Position', [180 100 150 30], ...
                'ButtonPushedFcn', @(btn,event) obj.generateScript());
        end
        
        function createChatGPTPanel(obj)
            % Similar to the ChatGPT panel in ImmediateAnalysisModule
        end
        
        function runAnalysis(obj)
            % Collect parameters and run analysis
            params = obj.collectParameters();
            % Implement analysis logic
        end
        
        function generateScript(obj)
            % Generate MATLAB script
            params = obj.collectParameters();
            script = obj.createMatlabScript(params);
            
            % Save script
            [file, path] = uiputfile('*.m', 'Save Analysis Script');
            if file ~= 0
                fid = fopen(fullfile(path, file), 'w');
                fprintf(fid, '%s', script);
                fclose(fid);
            end
        end
        
        function params = collectParameters(obj)
            % Collect parameters from UI controls
            fields = fieldnames(obj.Parameters);
            params = struct();
            for i = 1:length(fields)
                params.(fields{i}) = str2double(obj.Controls.(fields{i}).Value);
            end
        end
        
        function script = createMatlabScript(obj, params)
            % Create MATLAB script from parameters
            script = '% Analysis Script\n\n';
            script = [script 'params = struct();\n'];
            
            fields = fieldnames(params);
            for i = 1:length(fields)
                script = [script sprintf('params.%s = %g;\n', ...
                    fields{i}, params.(fields{i}))];
            end
            
            script = [script '\n% Run analysis\n'];
            script = [script 'runAnalysis(params);\n'];
        end
    end
end 
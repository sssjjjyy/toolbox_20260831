classdef LayerfMRIToolbox < matlab.apps.AppBase
    properties (Access = private)
        % Main UI components
        MainFigure          matlab.ui.Figure
        ModuleButtons       struct = struct()
        
        % Module managers
        ImmediateAnalysis  modules.ImmediateAnalysisModule
        InteractiveProfile modules.InteractiveProfileModule
        ProcessPipeline    modules.ProcessPipelineModule
        BrainViewer        modules.BrainViewerModule
        
    end
    properties (Access = public)
        % 这些属性需要在其他模块中访问，所以设为public
        d2n_dir         % utils目录路径
        code_dir
        QAenvName      % 环境名称
        WorkingDirPath % 工作目录
        ChatGPTHelper  % ChatGPT接口
    end

    methods (Access = private)
        function createMainInterface(app)
            % Create main figure with larger size
            app.MainFigure = uifigure('Name', 'AI-assist fMRI Toolbox', ...
                'Position', [100 100 800 600], ...
                'Color', [0.98 0.98 0.98]);
            
            % Add title panel
            titlePanel = uipanel(app.MainFigure, ...
                'Position', [0 500 800 100], ...
                'BackgroundColor', [0.2 0.3 0.7], ...
                'ForegroundColor', 'white');
            
            % Add main title
            uilabel(titlePanel, ...
                'Text', 'AI-assist fMRI Toolbox', ...
                'Position', [20 20 760 60], ...
                'FontSize', 28, ...
                'FontWeight', 'bold', ...
                'FontColor', 'white', ...
                'HorizontalAlignment', 'center');
            
            % Create module buttons with modern style and better spacing
            buttonConfigs = {
                'ImmediateAnalysis', 'fMRI Immediate Analysis', [150 380 500 70];
                'InteractiveProfile', 'Interactive Layer Profile', [150 280 500 70];
                'ProcessPipeline', 'Process Pipeline', [150 180 500 70];
                'BrainViewer', 'Brain Viewer', [150 80 500 70]
            };
            
            % Modern button style
            for i = 1:size(buttonConfigs, 1)
                app.ModuleButtons.(buttonConfigs{i,1}) = uibutton(app.MainFigure, ...
                    'Text', buttonConfigs{i,2}, ...
                    'Position', buttonConfigs{i,3}, ...
                    'ButtonPushedFcn', @(btn,event) app.moduleButtonPushed(buttonConfigs{i,1}), ...
                    'BackgroundColor', [0.2 0.3 0.7], ...
                    'FontColor', 'white', ...
                    'FontSize', 16, ...
                    'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center');
                
                % Add hover effect (optional, if your MATLAB version supports it)
                try
                    app.ModuleButtons.(buttonConfigs{i,1}).MouseHoverFcn = @(~,~) set(app.ModuleButtons.(buttonConfigs{i,1}), 'BackgroundColor', [0.3 0.4 0.8]);
                    app.ModuleButtons.(buttonConfigs{i,1}).MouseOutFcn = @(~,~) set(app.ModuleButtons.(buttonConfigs{i,1}), 'BackgroundColor', [0.2 0.3 0.7]);
                catch
                    % Ignore if hover effects are not supported
                end
            end
            
            % Add version info at bottom
            uilabel(app.MainFigure, ...
                'Text', 'Version 1.0.0', ...
                'Position', [10 10 780 20], ...
                'FontSize', 10, ...
                'FontColor', [0.5 0.5 0.5], ...
                'HorizontalAlignment', 'center');
        end
        
        function moduleButtonPushed(app, moduleName)
            switch moduleName
                case 'ImmediateAnalysis'
                    app.ImmediateAnalysis.show();
                case 'InteractiveProfile'
                    app.InteractiveProfile.show();
                case 'ProcessPipeline'
                    app.ProcessPipeline.show();
                case 'BrainViewer'
                    app.BrainViewer.show();
            end
        end
    end
    
    methods (Access = public)
        function app = LayerfMRIToolbox
            % Initialize paths and environment
            app.code_dir = fileparts(mfilename('fullpath'));
            app.d2n_dir = fullfile(fileparts(mfilename('fullpath')), 'utils');
            app.QAenvName = 'layerfmri';
            app.WorkingDirPath = '';


            % Initialize ChatGPT interface
            app.ModuleButtons = struct();
            
            % Initialize ChatGPT helper
            try
                app.ChatGPTHelper = utils.ChatGPTInterface();
                if isempty(app.ChatGPTHelper)
                    warning('ChatGPT helper initialization returned empty object');
                end
            catch ME
                warning(ME.identifier, '%s', ME.message);
                app.ChatGPTHelper = [];
            end

            % Initialize module managers
            app.ImmediateAnalysis = modules.ImmediateAnalysisModule(app);
            app.InteractiveProfile = modules.InteractiveProfileModule(app);
            % app.InteractiveProfile.show();
            app.ProcessPipeline = modules.ProcessPipelineModule(app);
            app.BrainViewer = modules.BrainViewerModule(app);
            
            % Create main interface
            createMainInterface(app);
        end
    end
end
function plot_individual_results(target_axes,epoch_percentage, num_epoches, output_dir,range,stim_volume)
    % 清除目标轴并设置为当前轴
    cla(target_axes);
    axes(target_axes);
    hold on;

    % 计算子图布局
    num_cols = 4;
    num_rows = ceil(num_epoches / num_cols);
    
    % 计算每个子图的宽度和高度
    subplot_width = 0.24;
    subplot_height = 1 / num_rows;

    % 检查 stim_volume 是否需要扩展
    if length(stim_volume) == 1
        stim_volume = repmat(stim_volume, 1, num_epoches);
    end

    % 创建临时不可见图形用于生成子图
    temp_fig = figure('Visible', 'off');
    
    try
        for i = 1:num_epoches
            % 计算子图位置
            col = mod(i - 1, num_cols);
            row = floor((i - 1) / num_cols);
            left = col * subplot_width;
            bottom = 1 - (row + 1) * subplot_height;

            % 在临时图形中创建子图
            subplot('Position', [left bottom subplot_width subplot_height]);
            
            % 设置颜色图
            mymap = videen(range);
            
            % 绘制图像
            imagesc(epoch_percentage(:, :, i), range);
            colormap(mymap);

            % 设置轴属性
            axis tight;
            axis off;
            
            % 添加白色边框
            rectangle('Position', [0.5, 0.5, size(epoch_percentage, 2), size(epoch_percentage, 1)], ...
                'EdgeColor', 'w', 'LineWidth', 4);
            
            % 添加红色刺激指示线
            end_vol = 11.5 + stim_volume(i) - 1;
            line([11.5, end_vol], [0.5, 0.5], 'Color', 'r', 'LineWidth', 4);
        end

        % 添加颜色条
        hCB = colorbar;
        set(hCB, 'Position', [0.98 0.01 0.015 0.98]);
        set(hCB, 'AxisLocation', 'in');

        % 将临时图形的内容复制到目标轴
        all_children = allchild(temp_fig);
        copyobj(all_children, target_axes);
        export_fig(['individual_percentage.bmp'],'-r','300')

        % % 保存图像
        % if ~isempty(output_dir)
        %     saveas(temp_fig, fullfile(output_dir, 'individual_percentage.bmp'));
        % end

    catch ME
        close(temp_fig);
        rethrow(ME);
    end

    % 关闭临时图形
    close(temp_fig);
    % %% Individual Percentage Maps
    % fig = figure(InvidualFigure);

    % % Dynamically calculate the number of columns for subplots
    % num_cols = 4;
    % num_rows = ceil(num_epoches / num_cols);
    
    % % Calculate width and height for each subplot
    % subplot_width = 0.24; %1 / num_cols
    % subplot_height = 1 / num_rows;

    % % 检查 stim_volume 是否只有一个数值，如果是，则扩展为与 num_epoches 相同的维度
    % if length(stim_volume) == 1
    %     stim_volume = repmat(stim_volume, 1, num_epoches);
    % end

    % for i = 1:num_epoches
    %     % Calculate subplot position
    %     col = mod(i - 1, num_cols);
    %     row = floor((i - 1) / num_cols);
    %     left = col * subplot_width;
    %     bottom = 1 - (row + 1) * subplot_height;

    %     % Create subplot
    %     subplot('Position', [left bottom subplot_width subplot_height]);
        
    %     mymap = videen(range);
    %     % Plot the image
    %     imagesc(epoch_percentage(:, :, i), range);
    %     colormap(mymap);
    %     colormap;

    %     % Set current axis to fill the subplot area
    %     set(gca, 'Position', [left bottom subplot_width subplot_height], 'Units', 'normalized');

    %     axis tight;  % Ensure content fills the entire subplot
    %     axis off;
    %     % Add white border
    %     rectangle('Position', [0.5, 0.5, size(epoch_percentage, 2), size(epoch_percentage, 1)], ...
    %         'EdgeColor', 'w', 'LineWidth', 4);
    %     % Add red border for the lower half of columns 11 to 20
    %     end_vol = 11.5 + stim_volume(i) - 1;
    %     line([11.5, end_vol], [0.5, 0.5], 'Color', 'r', 'LineWidth', 4);

    % end
    % hCB = colorbar;
    % set(hCB, 'Position', [0.98 0.01 0.015 0.98]);
    % set(hCB, 'AxisLocation', 'in');
    % export_fig(['individual_percentage.bmp'],'-r','300')
end
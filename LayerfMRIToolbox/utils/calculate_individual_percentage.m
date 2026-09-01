function epoch_percentage = calculate_individual_percentage(InvidualFigure,current_file, num_layers, epoch_len, num_epoches, baselineIndex,output_dir,map,range,stim_volume)
    % EPI = spm_read_vols(spm_vol(current_file));
    EPI = current_file;
    EPI_bak = EPI;
    % EPI = EPI(:,:,:,601:end); % Remove the first 600 volumes
    epi2d = reshape(EPI, [], size(EPI, 4)); % Collapse 3 spatial dimensions into 1
    epi2d_bak = reshape(EPI_bak, [], size(EPI_bak, 4));
    ROI_TC = zeros(size(EPI, 4), num_layers);
    ROI_BAK = zeros(size(EPI_bak, 4), num_layers);
    for k = 1:num_layers
        ROI_TC(:, k) = mean(epi2d(map == (num_layers - k + 1), :), 1); % Get the seed time courses
        ROI_BAK(:,k) = mean(epi2d_bak(map == (num_layers - k + 1), :), 1);
    end
    ROI_TC = ROI_TC';
    epoch_data = zeros(num_layers, epoch_len, num_epoches);
    epoch_percentage = zeros(num_layers, epoch_len, num_epoches);
    for i = 1:num_epoches
        epoch_data(:, :, i) = ROI_TC(:, (1 + (i - 1) * epoch_len):(epoch_len + (i - 1) * epoch_len));
        epoch_data_single = epoch_data(:, :, i);
        SI_basemean = mean(epoch_data_single(:,1:baselineIndex),2);
        epoch_percentage_single = (epoch_data_single - SI_basemean) ./ SI_basemean;
        epoch_percentage(:, :, i) = epoch_percentage_single;
    end

    
    %% Individual Percentage Maps
    fig = figure(InvidualFigure);

    % Dynamically calculate the number of columns for subplots
    num_cols = 4;
    num_rows = ceil(num_epoches / num_cols);
    
    % Calculate width and height for each subplot
    subplot_width = 0.24; %1 / num_cols
    subplot_height = 1 / num_rows;

    % 检查 stim_volume 是否只有一个数值，如果是，则扩展为与 num_epoches 相同的维度
    if length(stim_volume) == 1
        stim_volume = repmat(stim_volume, 1, num_epoches);
    end

    for i = 1:num_epoches
        % Calculate subplot position
        col = mod(i - 1, num_cols);
        row = floor((i - 1) / num_cols);
        left = col * subplot_width;
        bottom = 1 - (row + 1) * subplot_height;

        % Create subplot
        subplot('Position', [left bottom subplot_width subplot_height]);
        
        mymap = videen(range);
        % Plot the image
        imagesc(epoch_percentage(:, :, i), range);
        colormap(mymap);
        colormap;

        % Set current axis to fill the subplot area
        set(gca, 'Position', [left bottom subplot_width subplot_height], 'Units', 'normalized');

        axis tight;  % Ensure content fills the entire subplot
        axis off;
        % Add white border
        rectangle('Position', [0.5, 0.5, size(epoch_percentage, 2), size(epoch_percentage, 1)], ...
            'EdgeColor', 'w', 'LineWidth', 4);
        % Add red border for the lower half of columns 11 to 20
        end_vol = baselineIndex + stim_volume(i);
        line([baselineIndex+1, end_vol], [0.5, 0.5], 'Color', 'r', 'LineWidth', 4);

    end
    hCB = colorbar;
    set(hCB, 'Position', [0.98 0.01 0.015 0.98]);
    set(hCB, 'AxisLocation', 'in');
    export_fig(fullfile(output_dir, 'individual_percentage.bmp'),'-r','300')
end


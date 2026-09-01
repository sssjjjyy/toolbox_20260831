function  calculate_mean_percentage(meanFigure,epoch_percentage,output_dir,range,stim_volume,baselineIndex, epoch_length)
    % mymap = videen(range);
    % fig = figure(meanFigure);
    % mean_percent_map = mean(epoch_percentage, 3);
    % a = zeros(1, 140);
    % a(1, 11:20) = 0.026;
    % combined_data = vertcat(mean_percent_map(:, 1:end), a);
    % imagesc(combined_data, range); colormap(mymap);
    % axis equal;
    % axis off;
    % set(gcf, 'color', 'w');
    % set(gca, 'TickDir', 'out');
    % ax = gca;
    % ax.XTick = [11 20 30 40 50 100 140];
    % set(gca, 'FontSize', 14);
    % Group epoch_percentage data based on stim_volume
    unique_volumes = unique(stim_volume);
    fig = figure(meanFigure);
    for i = 1:length(unique_volumes)
        volume = unique_volumes(i);
        indices = stim_volume == volume;
        mean_percent_map = mean(epoch_percentage(:, :, indices), 3);

        % Create the colormap and figure
        mymap = videen(range);
%         fig = figure('Name', ['Mean Percentage - Volume ', num2str(volume)]); % Create a new figure for each unique volume
        a = zeros(1, epoch_length);
        end_vol=baselineIndex+unique_volumes(i);
        a(1, (baselineIndex+1):end_vol) = 0.026;
        combined_data = vertcat(mean_percent_map(:, 1:end), a);
        imagesc(combined_data, range); colormap(mymap);colormap;
        axis equal;
        axis off;
        set(gcf, 'color', 'w');
        set(gca, 'TickDir', 'out');
        ax = gca;
        total_points = size(combined_data, 2);
        ax.XTick = [baselineIndex+1, end_vol, total_points];

        % ax.XTick = [11 20 30 40 50 100 140];
        set(gca, 'FontSize', 14);
        % title(['Stim Volume: ', num2str(volume)]);
        hTitle = title(['Stim Volume: ', num2str(volume)]);
        currentPosition = get(hTitle, 'Position');
        set(hTitle, 'Position', [currentPosition(1), 0, currentPosition(3)]);

        hCB = colorbar('Orientation', 'horizontal');
        set(hCB, 'Position', [0.1 0.4 0.8 0.03]);  
        export_fig(fullfile(output_dir, ['Mean Percentage - Volume ', num2str(volume),'.bmp']),'-r','300')
    end
end


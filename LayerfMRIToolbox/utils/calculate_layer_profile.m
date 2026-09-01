function calculate_layer_profile(layerprofileFigure,filename,layniiDepthMap,baselineIndex,blocklength,blocknum,output_dir)
    % motionCorrection = spm_read_vols(spm_vol(filename));
    motionCorrection = filename;
    laynii_average = zeros(max(layniiDepthMap(:)),1);
    index = max(layniiDepthMap(:));
    id_index = 1;
    for i = index:-1:1
         [~,~,laynii_average(id_index)] = calculate_average_percnetage(motionCorrection,layniiDepthMap,i,baselineIndex,blocklength,blocknum);
         id_index = id_index + 1;
    end
    figure(layerprofileFigure);
    % l_arr = [0,4,8.5];
    % r_arr = [1.5,6,10];
    % color_arr = ["#becdff","#ffc7ff","#ffffcd"];
    laynii_average(isnan(laynii_average)) = 0;
    minY = min(laynii_average(:));
    maxY = max(laynii_average(:));
    % for i = 1 : 3
    %     leftBottomXIndex = l_arr(i);
    %     rightBottomXIndex = r_arr(i);
    %     if(minY < 0)
    %         area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY+abs(minY);minY maxY+abs(minY)],minY,'FaceColor',color_arr(i),"FaceAlpha",0.9,'EdgeColor','none');
    %     else
    %         area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY;minY maxY],'FaceColor',color_arr(i),"FaceAlpha",0.9,'EdgeColor','none');
    %     end
    %     hold on
    % end
    plot(laynii_average,'DisplayName', '{\Delta}BOLD LAYNII');
    hold off;
    % xticks(0:10);   % 假设1是CSF，3是II/III，6是Vb，9是WM
    % xticklabels({'CSF','' ,'','', 'II/III', '', '', 'Vb', '', '','', 'WM'});
    setLayerLabels(gca, index);
    ylim([minY,maxY]);
    current_yticks = yticks;
    new_yticklabels = 100 * current_yticks;
    yticklabels(new_yticklabels);
    ylabel('{\Delta}BOLD');
    title('Average Layer-Dependent fMRI Responses(LAYNII)');
    % 只在设置的xticks处保留小短线
    set(gca, 'TickLength', [0.01 0.025]); % 这里的数字可以根据您的需要进行调整
%     exportgraphics(fig, 'average_layer_dependent_fmri_responses_all_slices.png', 'Resolution', '300');
%     close(fig);
    export_fig(fullfile(output_dir, 'average_layer_dependent_fmri_responses_all_slices.bmp'),'-r','300')
end


function setLayerLabels(ax, num_layers)
    % 设置刻度
    xticks(0:num_layers);
    
    % 创建自适应标签
    if num_layers > 0
        % 创建空标签数组
        labels = cell(1, num_layers + 1);
        
        % 设置关键位置的标签
        labels{1} = 'CSF';                          % 第一个位置
        labels{ceil(num_layers/2)} = 'II/III';      % 中间位置
        labels{ceil(3*num_layers/4)} = 'Vb';        % 3/4位置
        labels{end} = 'WM';                         % 最后位置
        
        % 其他位置设为空字符串
        empty_indices = cellfun('isempty', labels);
        labels(empty_indices) = {''};
    end
    
    % 应用标签
    xticklabels(labels);
end
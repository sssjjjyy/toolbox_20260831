function [layniiPercentChange,percentSignal,layerMaxPercentChangeLaynii] = calculate_average_percnetage(motionCorrection,layniiDepthMap,layniiDepthNum,baselineIndex,blocklength)
    startIndex = 16;
    endIndex = 215;
    segmentLength = blocklength;
    depthIndex = (layniiDepthMap == layniiDepthNum);
    [depthI, depthJ, depthK] = ind2sub(size(layniiDepthMap), find(depthIndex));
    
    percentSignal = zeros(length(depthI), blocklength);
    
    for i = 1:length(depthI)
        x = depthI(i);
        y = depthJ(i);
        z = depthK(i);
        values = squeeze(motionCorrection(x, y, z, baselineIndex));
        baselineSignal = mean(values);
        percentChange = (squeeze(motionCorrection(x, y, z, :)) - baselineSignal) ./ baselineSignal;
        reshapedData = reshape(percentChange(startIndex:endIndex), segmentLength, []);
        % voxelPercentChange = sum(reshapedData, 2) ./ 5;
        voxelPercentChange = mean(reshapedData, 2);
        percentSignal(i, :) = voxelPercentChange;
    end
    
    % 第二步: 平均这些点的percent change结果
    layniiPercentChange = percentSignal;
    avgPercentChange = mean(percentSignal, 1);
    layerMaxPercentChangeLaynii = max(avgPercentChange(:));
%     avgPercentChange(isnan(avgPercentChange(:))) = 0;
%     minY = min(avgPercentChange(:));
%     maxY = max(avgPercentChange(:));
%     if(minY >= maxY) 
%         maxY = minY + 0.1; 
%     end
%     figure(averagePercentFigure);
%     leftBottomXIndex =  15;
%     rightBottomXIndex = 25;
%     if(minY < 0)
%        area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY+abs(minY);minY maxY+abs(minY)],minY,'FaceColor',"#F3F3F3","FaceAlpha",0.9,'EdgeColor','none');
%     else
%        area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY;minY maxY],'FaceColor',"#F3F3F3","FaceAlpha",0.9,'EdgeColor','none');
%     end
%     hold on
%     
%     % 第三步: 画出这些平均后的结果随时间变化的折线
%     plot(avgPercentChange);
%     ylim([minY,maxY]);
%     current_yticks = yticks;
%     new_yticklabels = 100 * current_yticks;
%     yticklabels(new_yticklabels);
%     xlabel('Time');
%     ylabel('{\Delta}BOLD');
%     title(['Average Percent Change over Time for Layer ', num2str(layniiDepthNum)]);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
%     exportgraphics(fig, ['average_block_mean_depth_', num2str(depthnum), '.png'], 'Resolution', '300');
%     close(fig);
end


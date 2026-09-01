function [outputArg1,outputArg2] = calculate_motion_signal(motionFigure,meanTimeSeries,blocknum,interStim,Stim)
    figure(motionFigure);
    tiledlayout(3,1)
    nexttile
    maxY = 1.2* max(meanTimeSeries(:));
    minY = 0.8 * min(meanTimeSeries(:));
    for i = 1 : blocknum
        leftBottomXIndex = 0 + (i - 1) * interStim + (interStim - Stim);
        rightBottomXIndex = Stim + (i - 1) * interStim + (interStim - Stim);
        area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY;minY maxY],'FaceColor',"#F3F3F3","FaceAlpha",0.9,'EdgeColor','none');
        hold on
    end
    plot(meanTimeSeries);
    xlim([1,numel(meanTimeSeries)]);
    ylim([minY maxY]);
    xlabel('Time');
    ylabel('intensity');
    title('Mean Timeseries');
    hold off
    nexttile
    maxY = 1.2* max(meanPercnetSignal(:));
    minY = 0.8 * min(meanPercnetSignal(:));
    for i = 1 : blocknum
        leftBottomXIndex = 0 + (i - 1) * 40 + 30;
        rightBottomXIndex = 10 + (i - 1) * 40 + 30;
        if(minY < 0)
            area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY+abs(minY);minY maxY+abs(minY)],minY,'FaceColor',"#F3F3F3","FaceAlpha",0.9,'EdgeColor','none');
        else
            area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY;minY maxY],'FaceColor',"#F3F3F3","FaceAlpha",0.9,'EdgeColor','none');
        end
        hold on
    end
    plot(meanPercnetSignal);
    xlim([1,numel(meanPercnetSignal)]);
    ylim([minY maxY]);
    xlabel('Time');
    ylabel('{\Delta}BOLD');
    title('Percent Change');
    hold off
    nexttile
    fd=compute_FD(motion);
    maxY = 1.2* max(fd(:));
    minY = 0.8* min(fd(:));
    for i = 1 : 5
        leftBottomXIndex = 0 + (i - 1) * 40 + 30;
        rightBottomXIndex = 10 + (i - 1) * 40 + 30;
        if(minY < 0)
            area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY+abs(minY);minY maxY+abs(minY)],minY,'FaceColor',"#F3F3F3","FaceAlpha",0.9,'EdgeColor','none');
        else
            area([leftBottomXIndex leftBottomXIndex;rightBottomXIndex rightBottomXIndex],[minY maxY;minY maxY],'FaceColor',"#F3F3F3","FaceAlpha",0.9,'EdgeColor','none');
        end
        hold on
    end
    xlim([1,numel(fd)]);
    ylim([minY maxY]);
    plot(fd)
    xlim([0 size(fd,1)]);
    xlabel('Time');
    ylabel('fd');
    title('FD');
    yline(0.2,'Linestyle','--','color','r');
    hold off
%     exportgraphics(fig, 'mean_timeSeries.png', 'Resolution', '300');
%     close(fig);
end


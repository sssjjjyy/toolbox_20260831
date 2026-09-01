function h = subplottight(n,m,i)
    % n: number of rows
    % m: number of columns
    % i: current subplot index
    
    [c,r] = ind2sub([m n], i);
    gap = 0; % 完全移除间隔
    
    % 计算每个子图的位置
    width = 1/m;
    height = 1/n;
    
    left = (c-1)/m;
    bottom = 1 - r/n;
    
    ax = subplot('Position', [left, bottom, width, height]);
    
    % 确保图像填充整个子图区域
    set(ax, 'Units', 'normalized');
    set(ax, 'Position', [left, bottom, width, height]);
    
    if(nargout > 0)
        h = ax;
    end
end
% function h = subplottight(n,m,i)
%     [c,r] = ind2sub([m n], i);
%     ax = subplot('Position', [(c-1)/m, 1-(r)/n, 1/m, 1/n]);
%     if(nargout > 0)
%       h = ax;
%     end
% end
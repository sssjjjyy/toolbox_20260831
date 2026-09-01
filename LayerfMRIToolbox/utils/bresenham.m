% % 创建 108x64 的 mask
% mask = zeros(108, 64);
% 
% % 起始点和终止点
% x1 = 42; y1 = 81;
% x2 = 28; y2 = 89;
% 
% % 计算直线上的所有点，使用 Bresenham 算法
% points = bresenham(x1, y1, x2, y2);
% 
% % 将直线上的点在 mask 中标记为 1
% for i = 1:size(points, 1)
%     x = points(i, 1);
%     y = points(i, 2);
%     if x > 0 && x <= size(mask, 1) && y > 0 && y <= size(mask, 2)
%         mask(x, y) = 1;
%     end
% end
% 
% % 显示结果
% imshow(mask, []);

function points = bresenham(x1, y1, x2, y2)
    points = [];
    dx = abs(x2 - x1);
    dy = abs(y2 - y1);
    sx = sign(x2 - x1);
    sy = sign(y2 - y1);
    
    if dy <= dx
        err = dx / 2;
        while x1 ~= x2
            points = [points; x1, y1];
            err = err - dy;
            if err < 0
                y1 = y1 + sy;
                err = err + dx;
            end
            x1 = x1 + sx;
        end
    else
        err = dy / 2;
        while y1 ~= y2
            points = [points; x1, y1];
            err = err - dx;
            if err < 0
                x1 = x1 + sx;
                err = err + dy;
            end
            y1 = y1 + sy;
        end
    end
    points = [points; x2, y2]; % 添加终点
end
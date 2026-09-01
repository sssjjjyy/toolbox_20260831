function distance = pointToLineDistance(point, lineDirection, linePoint)
    % point: 目标点的坐标 [x, y]
    % lineDirection: 直线的方向向量 [dx, dy]
    % linePoint: 直线上的一个点的坐标 [x0, y0]
    
    % 计算直线的斜率
    slope = lineDirection(2) / lineDirection(1);
    
    % 如果直线垂直于 x 轴
    if isinf(slope)
        % 计算直线的截距
        intercept = linePoint(1);
    else
        % 计算直线的截距
        intercept = linePoint(2) - slope * linePoint(1);
    end
    
    % 计算点到直线的距离
    distance = abs(slope * point(1) - point(2) + intercept) / sqrt(slope^2 + 1);
end

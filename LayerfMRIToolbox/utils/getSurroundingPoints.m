function surrounding_points = getSurroundingPoints(array, x, y)
    % 获取数组的大小
    [rows, cols] = size(array);
    
    % 定义偏移量，代表周围八个点的相对位置
    offsets = [-1, -1;
                0, -1;
                1, -1;
               -1,  0;
               +1,  0;
               -1,  1;
                0,  1;
                1,  1];
    
    % 初始化周围点的坐标
    surrounding_points = zeros(8,1);
    
    % 遍历偏移量，计算周围八个点的坐标
    for i = 1:8
        % 计算当前偏移量对应的坐标
        new_x = x + offsets(i, 1);
        new_y = y + offsets(i, 2);
        
        % 检查新坐标是否在数组范围内
        if new_x >= 1 && new_x <= rows && new_y >= 1 && new_y <= cols
            % 将周围点的坐标存储到结果数组中
            surrounding_points(i) = array(new_x, new_y);
        else
            % 超出数组范围的点，坐标设为 NaN
            surrounding_points(i) = NaN;
        end
    end
end

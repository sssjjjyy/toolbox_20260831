function input_data = fill_area(input_data)

for i = 1 : size(input_data,3)
    input = input_data(:,:,i);
    fillRegion = (input == 3 ) | (input == 2 ) | (input == 1 );

    % 通过imfill函数填充区域
    % 'holes'选项填充封闭区域中的空洞
    filledRegion = imfill(fillRegion, 'holes');
    
    % 将填充后的区域（现在为逻辑值）转换回原始矩阵的数值（3）
    output = input;
    output(filledRegion) = 3;
    output(input == 2) = 2;
    output(input == 1) = 1;
    input_data(:,:,i) = output;
end


end
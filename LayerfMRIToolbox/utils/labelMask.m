function layers_data = labelMask(MasklayerFigure,mask, header,rawfile,num_layers)
% 获取二进制图像中 1 组成区域的边界
% figure;
boundaries = bwboundaries(mask);
% imshow(mask);
% hold on;
for k = 1:length(boundaries)
    thisBoundary = boundaries{k};
%     plot(thisBoundary(:,2), thisBoundary(:,1), 'g', 'LineWidth', 2);
end
% 初始化两组顶点
group1 = [];
group2 = [];
% 初始化标记的mask
labeled_mask = zeros(size(mask));

% 循环遍历每个组成区域的边界
for k = 1:length(boundaries)
    thisBoundary = boundaries{k};

    % 获取四个顶点
    boundaryLength = size(thisBoundary, 1);
    if boundaryLength >= 4
        max_x_index = max(thisBoundary(:,2));
        max_y_index = max(thisBoundary(:,1));
        min_x_index = min(thisBoundary(:,2));
        min_y_index = min(thisBoundary(:,1));
        
        indices = find(thisBoundary(:,2) == max_x_index);
        values = thisBoundary(indices,:);
        y_index = min(values(:,1));
        vertex1 = [y_index,max_x_index];

        indices = find(thisBoundary(:,2) == min_x_index);
        values = thisBoundary(indices,:);
        y_index = max(values(:,1));
        vertex2 = [y_index,min_x_index];

        indices = find(thisBoundary(:,1) == max_y_index);
        values = thisBoundary(indices,:);
        x_index = max(values(:,2));
        vertex3 = [max_y_index,x_index];

        indices = find(thisBoundary(:,1) == min_y_index);
        values = thisBoundary(indices,:);
        x_index = min(values(:,2));
        vertex4 = [min_y_index,x_index];
        group1 = [group1; vertex2; vertex4];
        group2 = [group2; vertex1; vertex3];
    end
end

if(group1(1,1) < group1(2,1))
    point_1 = group1(1,:);
    point_2 = group1(2,:);
else
    point_2 = group1(1,:);
    point_1 = group1(2,:);
end

if(group2(1,1) < group2(2,1))
    point_3 = group2(1,:);
    point_4 = group2(2,:);
else
    point_4 = group2(1,:);
    point_3 = group2(2,:);
end

vector_1 = point_1 - point_2;
distance_1 = sqrt(sum((point_1 - point_3).^2));
distance_2 = sqrt(sum((point_1 - point_4).^2));
if(distance_1 < distance_2)
    vector_2_1 = point_1 - point_3;
    vector_2_2 = point_2 - point_4;
else
    vector_2_1 = point_1 - point_4;
    vector_2_2 = point_2 - point_3;
end

vector_3 = point_3 - point_4;
if((max([point_1(1,1),point_2(1,1)]) - min([point_1(1,1),point_2(1,1)])) >...
        (max([point_1(1,2),point_2(1,2)]) - min([point_1(1,2),point_2(1,2)])))
    direction_index = 1;
else
    direction_index = 2;
end



% 遍历边界中的每个点，根据其位置分配到不同的组
for k = 1:length(boundaries)
    thisBoundary = boundaries{k};

    for i = 1:size(thisBoundary, 1)
        % 获取当前点的坐标
        point = thisBoundary(i, :);
        distance_out_1 = pointToLineDistance(point,vector_1,point_1);
        distance_out_2 = pointToLineDistance(point,vector_3,point_3);
        % 判断当前点应该属于哪个组
        if distance_out_1 < distance_out_2
            % 属于组1，用红色绘制
            distance_1 = pointToLineDistance(point,vector_1,point_1);
            distance_2 = pointToLineDistance(point,vector_2_1,point_1);
            distance_3 = pointToLineDistance(point,vector_2_2,point_2);
            if(distance_1 <= distance_2 && distance_1 <= distance_3)
                labeled_mask(point(1), point(2)) = 1;
%                 plot(point(2),point(1),'r.','LineWidth',2);
            else
                labeled_mask(point(1), point(2)) = 3;
            end
        else 
            % 属于组2，用蓝色绘制
            distance_1 = pointToLineDistance(point,vector_3,point_3);
            distance_2 = pointToLineDistance(point,vector_2_1,point_1);
            distance_3 = pointToLineDistance(point,vector_2_2,point_2);
            if(distance_1 <= distance_2 && distance_1 <= distance_3)
                labeled_mask(point(1), point(2)) = 2;
%                 plot(point(2),point(1),'b.','LineWidth',2);
            else
                labeled_mask(point(1), point(2)) = 3;
            end
        end
    end
end

thisBoundary = boundaries{k};
for i = 2 : length(thisBoundary) - 1
    point_1 = thisBoundary(i - 1,:);
    point_1 = labeled_mask(point_1(1),point_1(2));
    point_2 = thisBoundary(i,:);
    point_2 = labeled_mask(point_2(1),point_2(2));
    point_3 = thisBoundary(i + 1,:);
    point_3 = labeled_mask(point_3(1),point_3(2));
    % 假设 point_1、point_2、point_3 是点坐标向量
    point = thisBoundary(i,:);
    if point_1 == 1 && point_3 == 1 && point_2 ~= 1
        labeled_mask(point(1),point(2)) = 1;
    elseif point_1 == 2 && point_3 == 2 && point_2 ~= 2
        labeled_mask(point(1),point(2)) = 2;
    end

end

rim = fill_area(labeled_mask);
index_arr = find(rim == 3);
for i = 1 : size(index_arr)
    [y,x] = ind2sub(size(rim),index_arr(i));
    surr_arr = getSurroundingPoints(rim,y,x);
    num_1 = length(find(surr_arr == 1));
    num_0 = length(find(surr_arr == 0));
    num_2 = length(find(surr_arr == 2));
    if(num_1 == 2 && num_0 == 5)
        rim(y,x) = 1;
    elseif(num_2 == 2 && num_0 == 5)
        rim(y,x) = 2;
    end
end

for i = 1:size(rim,1)
    for j = 1:size(rim,2)
        data = rim(i,j);
        surr_arr = getSurroundingPoints(rim,i,j);
        num_1 = length(find(surr_arr == 1));
        num_3 = length(find(surr_arr == 3));
        num_2 = length(find(surr_arr == 2));
        if(data == 0 && num_1 > 2)
            rim(i,j) = 1;
        elseif(data == 0 && num_2 > 2)
            rim(i,j) = 2;
        elseif(data == 0 && num_1 == 1 && num_3 == 2)
            rim(i,j) = 1;
        elseif(data == 0 && num_2 == 2 && num_3 == 2)
            rim(i,j) = 2;
        end
    end
end
header.dt = [64,0];
rp_Write4DNIfTI(rim,header,'rim.nii');
layers_by_laynii('rim.nii',num_layers,true,1);
layers_data = spm_read_vols(spm_vol('rim_layers_equivol.nii'));

layers_data(layers_data == 0)=NaN;
bg_epi = spm_read_vols(spm_vol(rawfile));
bg_epi = bg_epi(:,:,:,1);
% Generate distinguishable colors for visualization
colors = distinguishable_colors(num_layers, [1 1 1; 0 0 0]);

% Create a figure for visualization
fig = figure(MasklayerFigure);
imoverlay(rot90(bg_epi(:, :), 1), rot90(layers_data(:, :), 1), [1 num_layers], [], colors, 1, fig);
% Set colormap and colorbar
colormap(colors);
cb = colorbar;
% Hide colorbar tick marks
cb.TickLength = 0;
% Divide colorbar into n blocks and place labels at block centers
n = num_layers;
cb.Ticks = linspace(cb.Limits(1), cb.Limits(2), n + 1) + (cb.Limits(2) - cb.Limits(1)) / (2 * n);
cb.TickLabels = 1:num_layers;
% Export the visualization as an image file
export_fig(['layer_seg'],'-r','300')

end

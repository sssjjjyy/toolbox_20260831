function is_apply_transform = check_registration_result_EPI(moving_image,fixed_image,rotation)
%LONGTR_CHECKREGISTRATIONRESULT 此处显示有关此函数的摘要
%   此处显示详细说明
mask_header=spm_vol(moving_image);
subPath = fileparts(fixed_image);
mask_data=spm_read_vols(mask_header);
mask_data(mask_data ~= 0) = 1;
org_header=spm_vol(fixed_image);
org_data=spm_read_vols(org_header);
for z=1:size(org_data,3)
    mask_data(:,:,z) = edge(mask_data(:,:,z),'canny',0.16);
end
mask_data(mask_data == 0) = nan;
fig = figure('Position', [0 0 1480 346]);
column = 7;
row = ceil(size(org_data, 3)/column);
tiledlayout(row, column,"TileSpacing","none");
for z=1:size(org_data,3)
    h = nexttile;
    map = colormap([1 0 0]);
    imoverlay(rot90(org_data(:,:,z),rotation),rot90(mask_data(:,:,z),rotation),[0 1],[0 0.9 * max(org_data(:))],map,1,h);
end


uicontrol('Style', 'pushbutton', 'String', '接受', 'Position', [10, 10, 60, 25], 'Callback', @acceptCallback);
uicontrol('Style', 'pushbutton', 'String', '拒绝', 'Position', [fig.Position(3)-100, 10, 60, 25], 'Callback', @rejectCallback);

uiwait(fig);

    function acceptCallback(~, ~)

        choice = questdlg('是否将该变换运用到其他的扫描中？', '确认', 'Yes', 'No', 'No');
        switch choice
            case 'Yes'
                % 执行将变换应用到其他扫描的操作
                is_apply_transform = true;
                % 在这里添加应用变换的代码
            case 'No'
                % 不执行任何操作
                is_apply_transform = false;
        end
    
        exportgraphics(fig, fullfile(subPath, 'regist_QC.png'), 'Resolution', 300);
        uiresume(fig);
        close(fig);

        exportgraphics(fig,fullfile(subPath,'regist_QC.png'),'Resolution',300);
        uiresume(fig);
        close(fig);
    end
    function rejectCallback(~, ~)
        itksnap_commad = ['ITK-SNAP -g ',org,' -s ',mask];
        system(itksnap_commad);
        close(fig);
        longTR_BorderQC(org,mask,rotation);
    end
end


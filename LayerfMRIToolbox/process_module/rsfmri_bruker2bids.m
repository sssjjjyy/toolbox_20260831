function rsfmri_bruker2bids(working_path,output_path,working_subject,dataset_name,sub_num,task_name,type_set,T2_folders,MB_folders,EPI_folders)
%该函数主要用来实现将采集的bruker数据转成BIDS格式
%其中working_path是采集数据的根目录 如可能取值为 C:\Users\SHT-TXN\Desktop\DataAnalysis\layertest\
%working_subject:是具体的采集数据的数据目录 20231204_123802_LTN_20231204_173_1_86
%dataset_name:是生成BIDS格式的目录名 mouse173
%sub_num: 是指具体的实验鼠的编号 173
%task_name:是指具体的刺激名称（可以传入cell变量） {'electronic stimulus','rest'}
%type_set:针对同一种刺激不同的采集参数的集合（即一种刺激可能有多个参数的采集） {'TR1500','TR200'，''}
%T2_folders: T2结构像的目录名（可以传入cell变量）{'13'，'15'}（这里的数字代表扫描时session的编号）
%EPI_folders: EPI扫描的目录名（传入二维cell数组） {{'2','4','5'},
%%这个代表electronic_stimulus_TR1500 的EPI数据的扫描session的编号集合
% {'1','3','6'},这个代表electronic_stimulus_TR200 的EPI数据的扫描session的编号集合
% {},这个代表electronic_stimulus的EPI数据的扫描session的编号集合
% {},这个代表rest_TR200 的EPI数据的扫描session的编号集合
% {},这个代表rest_TR1500 的EPI数据的扫描session的编号集合
% {'7','8'},这个代表rest的EPI数据的扫描session的编号集合
% }
%举例
%具体某个待处理的session下的nifti文件的路径为EPI_folders/working_subject/EPI_folders{1，1}/pdata/1/dicom/xxxx.nii
%json文件路径为：EPI_folders/working_subject/EPI_folders{1，1}/pdata/1/dicom/xxxx.json
%注意xxxx为占字符 具体可以是任意字符
%
% 定义BIDS根目录

% working_path ='C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\test'
% output_path = 'C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\tt';
% working_subject ='20240127_171357_LTN_20240127_211_1_174'
% dataset_name ='sourcedata'
% sub_num = '20240127211'
% % task_name = {'auditory_stimulation','auditory_stimulation'}
% % type_set = {'TR1000','TR200'}
% T2_folders = {'15'}
% MB_folders = {'8','13'}
% EPI_folders = {'22','24','26','28'}  
% dataset_txt = fullfile(working_path, working_subject, 'dataset.txt');
% dataset = read_dataset(dataset_txt);
% events = struct('onset', [], 'duration', [], 'trial_type', {}, 'response_time', {}, 'stim_file', {}, 'channel', {}, 'annots', {});
% TRs = strsplit(dataset.TRs, ',');
% onset_scan = strsplit(dataset.Onset_Scan, ',');
% duration_input = str2double(dataset.Duration);
% task_name = strsplit(dataset.Task_Name, ',');
% type_set = strsplit(dataset.Type_Set, ',');
        
for j = 1:length(TRs)
    num_length = length(str2double(onset_scan{j}));
    events(j).onset = str2double(onset_scan{j}) * str2double(TRs{j});
    events(j).duration = repmat(duration_input * str2double(TRs{j}), num_length, 1);
    events(j).trial_type = repmat({'start'}, num_length, 1);
    events(j).response_time = repmat({'n/a'}, num_length, 1);
    events(j).stim_file = repmat({'n/a'}, num_length, 1);
    events(j).channel = repmat({'n/a'}, num_length, 1);
    events(j).annots = repmat({'n/a'}, num_length, 1);
end


bids_root = fullfile(output_path, dataset_name);

% 确保BIDS根目录存在
if ~exist(bids_root, 'path')
    mkpath(bids_root);
end

% 为每个实验鼠创建一个子目录
sub_path = fullfile(bids_root, ['sub-' num2str(sub_num)]);
if ~exist(sub_path, 'path')
    mkpath(sub_path);
end

% Initialize output variables
MB_file = cell(1, length(MB_folders));
target_file_nii = cell(1, length(EPI_folders));
T2_file = '';


% 处理T2结构像数据
for i = 1:length(T2_folders)
    T2_file = process_T2_data(working_path, working_subject, T2_folders{i}, sub_num, bids_root);
end

% 处理MB数据
index2 = 1;
for i = 1:length(MB_folders)
    % MB_file = process_T2_data(working_path, working_subject, MB_folders{i}, sub_num, bids_root);
    MB_file{i} = process_MB_data(working_path, working_subject, task_name{index2}, type_set{index2}, MB_folders{i}, sub_num, bids_root,events(index2));

end


% 处理EPI数据
index2 = 2;
for i = 1:length(EPI_folders)
    % for j = 1:length(EPI_folders{i})
    %     if(i > 1)
    %         index2 = index2 + length(EPI_folders{i-1});
    %     end
        % target_file_nii{i,j} = process_EPI_data(working_path, working_subject, task_name{index2}, type_set{index2}, EPI_folders{i}, sub_num, bids_root,events(index2));
    target_file_nii{i} = process_EPI_data(working_path, working_subject, task_name{index2}, type_set{index2}, EPI_folders{i}, sub_num, bids_root,events(index2));

        % end
end
end



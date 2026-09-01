function generate_task_tsv(target_dir, sub_num,task, run_num, events,type)
    % 生成任务事件的.tsv文件
    % target_dir: 目标目录
    % task: 任务名称
    % run_num: 运行编号
    % events:
    % 一个结构体数组，包含字段'onset'（开始时间）,'duration'（持续时间）,'trial_type'（事件类型）,response_time(相应时间)，stim_file(刺激文件),channel(通道),annots(标志)

% bids_root = 'C:\Users\zhuyt12023\Desktop\layerfmri_mouse_immediate\tt\sourcedata';
% sub_num = '20240127211'
% sub_dir = fullfile(bids_root, ['sub-' num2str(sub_num)]);
% target_dir = fullfile(sub_dir, 'func');
% run_num = series_num;

    tsv_filename_basename = ['sub-' num2str(sub_num) '_task-' task '_' type '_run-' run_num '_events.tsv'];
    tsv_filename_basename = join(tsv_filename_basename, "");
    tsv_filename_basename = tsv_filename_basename{1};
    tsv_filename = fullfile(target_dir, tsv_filename_basename);
    % 创建表格
    tsv_table = table([events.onset]', [events.duration], events.trial_type ...
        , events.response_time,events.stim_file,events.channel,events.annots,...
        'VariableNames', {'onset', 'duration', 'trial_type', ...
        'response_time','stim_file','channel','annots'});

    writetable(tsv_table, tsv_filename, 'FileType', 'text', 'Delimiter', '\t');
end

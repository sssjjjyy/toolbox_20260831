function rsfmri_brainmask_ben_finetune(env_name,train_path,label_path,target_path,weight_path,prefix)

command = ['conda activate ', env_name, ' && python BEN_DA.py -t ', train_path, ' -l ', label_path, ' -r ', target_path,' -weight ',weight_path,' -prefix ',prefix];
system(command);
end
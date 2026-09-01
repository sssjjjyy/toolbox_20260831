function prefix_path = generate_prefix_path(input_path,prefix)
    [pathstr, filename, ext] = fileparts(input_path);
    new_filename = [prefix filename ext];
    prefix_path = fullfile(pathstr, new_filename);
end

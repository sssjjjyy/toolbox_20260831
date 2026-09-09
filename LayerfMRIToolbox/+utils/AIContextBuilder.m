classdef AIContextBuilder
    methods (Static)
        function [context, summary] = build(rootPath, maxReturnedFiles, maxScannedEntries)
            if nargin < 2
                maxReturnedFiles = 500;
            end
            if nargin < 3
                maxScannedEntries = 20000;
            end

            rootPath = char(string(rootPath));
            if isempty(rootPath) || ~isfolder(rootPath)
                error('AIContext:InvalidDirectory', 'Working directory does not exist: %s', rootPath);
            end
            if ~(isscalar(maxReturnedFiles) && isnumeric(maxReturnedFiles) && maxReturnedFiles > 0)
                error('AIContext:InvalidLimit', 'maxReturnedFiles must be a positive scalar.');
            end
            if ~(isscalar(maxScannedEntries) && isnumeric(maxScannedEntries) && maxScannedEntries > 0)
                error('AIContext:InvalidLimit', 'maxScannedEntries must be a positive scalar.');
            end

            rootPath = char(java.io.File(rootPath).getCanonicalPath());
            queue = cell(maxScannedEntries, 1);
            queue{1} = rootPath;
            queueIndex = 1;
            queueCount = 1;
            scannedEntries = 0;
            supportedFiles = 0;
            returnedFileCount = 0;
            scanTruncated = false;
            files = repmat(struct( ...
                'relative_path', '', ...
                'type', '', ...
                'size_bytes', 0, ...
                'modified', ''), maxReturnedFiles, 1);
            counts = struct( ...
                'nifti', 0, ...
                'dicom', 0, ...
                'json', 0, ...
                'table', 0, ...
                'matlab_data', 0, ...
                'text', 0, ...
                'transform', 0, ...
                'script', 0, ...
                'image', 0);

            while queueIndex <= queueCount
                currentPath = queue{queueIndex};
                queueIndex = queueIndex + 1;
                entries = dir(currentPath);

                for index = 1:numel(entries)
                    entry = entries(index);
                    if strcmp(entry.name, '.') || strcmp(entry.name, '..')
                        continue;
                    end

                    scannedEntries = scannedEntries + 1;
                    if scannedEntries > maxScannedEntries
                        scanTruncated = true;
                        break;
                    end

                    fullPath = fullfile(entry.folder, entry.name);
                    if entry.isdir
                        if ~utils.AIContextBuilder.shouldSkipDirectory(entry.name)
                            if queueCount >= maxScannedEntries
                                scanTruncated = true;
                                break;
                            end
                            queueCount = queueCount + 1;
                            queue{queueCount} = fullPath;
                        end
                        continue;
                    end

                    relativePath = utils.AIContextBuilder.relativePath(rootPath, fullPath);
                    fileType = utils.AIContextBuilder.classifyFile(entry.name, relativePath);
                    if isempty(fileType)
                        continue;
                    end

                    supportedFiles = supportedFiles + 1;
                    counts.(fileType) = counts.(fileType) + 1;
                    if returnedFileCount < maxReturnedFiles
                        returnedFileCount = returnedFileCount + 1;
                        modified = datetime(entry.datenum, 'ConvertFrom', 'datenum', ...
                            'Format', 'yyyyMMdd''T''HHmmss');
                        files(returnedFileCount, 1) = struct( ...
                            'relative_path', relativePath, ...
                            'type', fileType, ...
                            'size_bytes', double(entry.bytes), ...
                            'modified', char(modified));
                    end
                end

                if scanTruncated
                    break;
                end
            end

            files = files(1:returnedFileCount);
            [~, rootName] = fileparts(rootPath);
            context = struct( ...
                'schema_version', '1.0', ...
                'generated_at', char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')), ...
                'root_name', rootName, ...
                'root_path', rootPath, ...
                'scanned_entries', scannedEntries, ...
                'supported_file_count', supportedFiles, ...
                'returned_file_count', numel(files), ...
                'scan_truncated', scanTruncated, ...
                'file_list_truncated', supportedFiles > numel(files), ...
                'counts', counts, ...
                'files', files);

            summary = sprintf( ...
                '%d supported files: %d NIfTI, %d DICOM, %d JSON, %d tables, %d MAT, %d transforms, %d scripts, %d images.', ...
                supportedFiles, counts.nifti, counts.dicom, counts.json, counts.table, ...
                counts.matlab_data, counts.transform, counts.script, counts.image);
            if scanTruncated || supportedFiles > numel(files)
                summary = sprintf('%s File details are truncated.', summary);
            end
        end
    end

    methods (Static, Access = private)
        function skip = shouldSkipDirectory(name)
            normalized = lower(string(name));
            skip = startsWith(normalized, ".") || ismember(normalized, [ ...
                "__pycache__", "node_modules", "weights", "weight", ...
                "models", "model", "generated_code"]);
        end

        function relativePath = relativePath(rootPath, fullPath)
            prefix = [rootPath, filesep];
            if startsWith(fullPath, prefix)
                relativePath = fullPath(numel(prefix)+1:end);
            else
                relativePath = fullPath;
            end
            relativePath = strrep(relativePath, '\', '/');
        end

        function fileType = classifyFile(name, relativePath)
            normalized = lower(string(name));
            [~, ~, extension] = fileparts(char(normalized));
            extension = lower(string(extension));

            if endsWith(normalized, ".nii") || endsWith(normalized, ".nii.gz")
                fileType = 'nifti';
            elseif ismember(extension, [".dcm", ".ima"]) || ...
                    (strlength(extension) == 0 && contains(lower(string(relativePath)), "dicom"))
                fileType = 'dicom';
            elseif extension == ".json"
                fileType = 'json';
            elseif ismember(extension, [".tsv", ".csv", ".xlsx", ".xls"])
                fileType = 'table';
            elseif extension == ".mat"
                fileType = 'matlab_data';
            elseif ismember(extension, [".txt", ".1d", ".log"])
                fileType = 'text';
            elseif ismember(extension, [".h5", ".hdf5", ".tfm"])
                fileType = 'transform';
            elseif ismember(extension, [".m", ".py", ".sh", ".job", ".yml", ".yaml"])
                fileType = 'script';
            elseif ismember(extension, [".png", ".jpg", ".jpeg", ".bmp", ".svg", ".pdf"])
                fileType = 'image';
            else
                fileType = '';
            end
        end
    end
end

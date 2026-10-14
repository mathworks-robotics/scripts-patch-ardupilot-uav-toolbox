function applyCodeInsertions(rootPath, jsonPath)
% APPLYCODEINSERTIONS Apply code insertions/replacements/wraps described in JSON.
%   Skips any operation if the same TAG is already present in the target file.
%
%   applyCodeInsertions(rootPath, jsonPath)
%
% Inputs
%   rootPath - repository root (string)
%   jsonPath - path to JSON config (string)
%
% Behavior
%   - For each file entry in JSON, reads the file into memory and processes
%     operations in ascending line order (by "line" or "start_line").
%   - Before applying an operation that would add a TAG block, searches
%     the file for the start tag "<comment_style> TAG: <tag>".
%     If found, the operation is skipped to avoid duplicate edits.
%   - Writes updated file content with LF line endings.
%
% Operation types
%   "insert"  - Insert code block before the given "line".
%   "replace" - Replace the given "line" with the code block.
%   "wrap"    - Wrap lines start_line..end_line (inclusive) with "before"
%               lines above and "after" lines below.

    % Load and decode the JSON configuration file
    jsonText = fileread(jsonPath);
    config = jsondecode(jsonText);

    % Iterate over each file entry in the JSON
    for f = 1:length(config.files)
        fileEntry = config.files(f);

        % Convert relative path to platform-specific format
        relParts = strsplit(fileEntry.path, '/');           % Split path by '/'
        relPath = fullfile(relParts{:});                    % Reconstruct using platform-specific separator
        filePath = fullfile(rootPath, relPath);             % Combine with root path

        % Check if the file exists before attempting to modify
        if ~isfile(filePath)
            error('File not found: %s', filePath);
        end

        % Determine tag prefix from JSON or fallback to default
        if isfield(fileEntry, 'comment_style')
            tagPrefix = strtrim(fileEntry.comment_style);   % Use specified comment style
        else
            tagPrefix = '//';                               % Default to C/C++ style
        end

        % Read the file content into a string array (one line per element)
        fileContent = readlines(filePath);

        % Sort operations by line number ascending
        % This ensures we apply edits top-to-bottom and can track line shifts correctly.
        % "wrap" entries use "start_line" instead of "line", so we build a
        % unified sort key.
        insertions = fileEntry.insertions;
        % Normalize cell array to struct array (jsondecode produces a cell
        % array when JSON objects have different field sets, e.g. mixed
        % insert/replace and wrap entries)
        if iscell(insertions)
            allFieldNames = {};
            for k = 1:length(insertions)
                allFieldNames = union(allFieldNames, fieldnames(insertions{k}), 'stable');
            end
            for k = 1:length(insertions)
                for j = 1:length(allFieldNames)
                    if ~isfield(insertions{k}, allFieldNames{j})
                        insertions{k}.(allFieldNames{j}) = [];
                    end
                end
            end
            insertions = [insertions{:}];
        end

        sortKeys = zeros(1, length(insertions));
        for k = 1:length(insertions)
            if isfield(insertions(k), 'start_line') && ~isempty(insertions(k).start_line)
                sortKeys(k) = insertions(k).start_line;
            else
                sortKeys(k) = insertions(k).line;
            end
        end
        [~, idx] = sort(sortKeys);
        insertions = insertions(idx);

        % Initialize line shift tracker
        % This variable tracks how many lines have been added or removed
        % so that subsequent operations can adjust their target line numbers
        lineShift = 0;

        % Process each operation in order
        for i = 1:length(insertions)
            ins = insertions(i);
            opType = lower(strtrim(ins.type));               % Normalize operation type
            tag = strtrim(ins.tag);                          % Clean up tag string

            % Build tag marker lines
            startTagLine = strcat(tagPrefix , " TAG: " , tag);
            endTagLine   = strcat(tagPrefix , " END TAG: " , tag);

            % If the tag already exists anywhere in the file, skip this operation
            tagExistsIdx = find(fileContent == startTagLine, 1, 'first');
            if ~isempty(tagExistsIdx)
                fprintf('Skipping "%s" for tag "%s" in %s: tag already present at line %d.\n', opType, tag, filePath, tagExistsIdx);
                continue;
            end

            % Apply the operation
            switch opType
                case "insert"
                    adjustedLine = ins.line + lineShift;
                    codeBlock = string(ins.code);
                    taggedBlock = [startTagLine; codeBlock; endTagLine];

                    fileContent = [fileContent(1:adjustedLine-1); taggedBlock; fileContent(adjustedLine:end)];
                    lineShift = lineShift + length(taggedBlock);
                    fprintf('Inserted tag "%s" into %s at line %d.\n', tag, filePath, adjustedLine);

                case "replace"
                    adjustedLine = ins.line + lineShift;
                    codeBlock = string(ins.code);
                    taggedBlock = [startTagLine; codeBlock; endTagLine];

                    fileContent = [fileContent(1:adjustedLine-1); taggedBlock; fileContent(adjustedLine+1:end)];
                    lineShift = lineShift + length(taggedBlock) - 1;
                    fprintf('Replaced line %d in %s with tag "%s".\n', adjustedLine, filePath, tag);

                case "wrap"
                    adjStart = ins.start_line + lineShift;
                    adjEnd   = ins.end_line   + lineShift;
                    beforeBlock = string(ins.before);
                    afterBlock  = string(ins.after);

                    % Build: [before-file] [startTag] [before-lines] [original range] [after-lines] [endTag] [rest-of-file]
                    wrappedBlock = [startTagLine; beforeBlock; fileContent(adjStart:adjEnd); afterBlock; endTagLine];

                    fileContent = [fileContent(1:adjStart-1); wrappedBlock; fileContent(adjEnd+1:end)];
                    linesAdded = length(wrappedBlock) - (adjEnd - adjStart + 1);
                    lineShift = lineShift + linesAdded;
                    fprintf('Wrapped lines %d-%d in %s with tag "%s".\n', adjStart, adjEnd, filePath, tag);

                otherwise
                    error('Unknown operation type "%s" in file %s.', opType, filePath);
            end
        end

        % Write the modified content back to the original file
        writeLinesWithLF(fileContent, filePath);
    end
end

function writeLinesWithLF(lines, filePath)
    % WRITELINESWITHLF Writes lines to a file using LF-only line endings.
    % This avoids platform-dependent CRLF endings (e.g., on Windows).
    fid = fopen(filePath, 'w');
    if fid == -1
        error('Failed to open file: %s', filePath);
    end

    for i = 1:length(lines)-1
        fprintf(fid, '%s\n', lines(i));  % Explicitly use \n for LF
    end
    % LF not needed for last line
    fprintf(fid, '%s', lines(length(lines)));
    fclose(fid);
end
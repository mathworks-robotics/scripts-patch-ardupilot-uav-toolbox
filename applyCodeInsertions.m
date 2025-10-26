function applyCodeInsertions(rootPath, jsonPath)
% APPLYCODEINSERTIONS Apply code insertions/replacements described in JSON.
%   Skips any insertion if the same TAG is already present in the target file.
%
%   applyCodeInsertions(rootPath, jsonPath)
%
% Inputs
%   rootPath - repository root (string)
%   jsonPath - path to JSON config (string)
%
% Behavior
%   - For each file entry in JSON, reads the file into memory and processes
%     insertions in ascending line order.
%   - Before applying an insertion/replacement that would add a TAG block,
%     searches the file for the start tag "<comment_style> TAG: <tag>".
%     If found, the insertion/replacement is skipped to avoid duplicate inserts.
%   - Writes updated file content with LF line endings.

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

        % Sort insertions by line number ascending
        % This ensures we apply edits top-to-bottom and can track line shifts correctly
        insertions = fileEntry.insertions;
        [~, idx] = sort([insertions.line]);
        insertions = insertions(idx);

        % Initialize line shift tracker
        % This variable tracks how many lines have been added or removed
        % so that subsequent operations can adjust their target line numbers
        lineShift = 0;

        % Process each insertion or replacement in order
        for i = 1:length(insertions)
            ins = insertions(i);
            originalLine = ins.line;                         % Line number from JSON
            adjustedLine = originalLine + lineShift;         % Adjusted for prior edits

            codeBlock = string(ins.code);                    % Convert code block to string array
            opType = lower(strtrim(ins.type));               % Normalize operation type
            tag = strtrim(ins.tag);                          % Clean up tag string

            %Wrap code block with tag markers using appropriate comment style
            startTagLine = strcat(tagPrefix , " TAG: " , tag);
            endTagLine   = strcat(tagPrefix , " END TAG: " , tag);
            taggedBlock = [startTagLine; string(codeBlock); endTagLine];

            % If the tag already exists anywhere in the file, skip this insertion
            % We search for an exact line match of the start tag.
            tagExistsIdx = find(fileContent == startTagLine, 1, 'first');
            if ~isempty(tagExistsIdx)
                fprintf('Skipping insertion for tag "%s" in %s: tag already present at line %d.\n', tag, filePath, tagExistsIdx);
                % Do not modify fileContent or lineShift; continue to next insertion
                continue;
            end

            % Apply the operation
            switch opType
                case "insert"
                    % Insert the tagged block before the adjusted line
                    fileContent = [fileContent(1:adjustedLine-1); taggedBlock; fileContent(adjustedLine:end)];
                    lineShift = lineShift + length(taggedBlock);  % Update shift by number of inserted lines
                    fprintf('Inserted tag "%s" into %s at line %d.\n', tag, filePath, adjustedLine);

                case "replace"
                    % Replace the adjusted line with the tagged block
                    fileContent = [fileContent(1:adjustedLine-1); taggedBlock; fileContent(adjustedLine+1:end)];
                    lineShift = lineShift + length(taggedBlock) - 1;  % Update shift by net line change
                    fprintf('Replaced line %d in %s with tag "%s".\n', adjustedLine, filePath, tag);

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
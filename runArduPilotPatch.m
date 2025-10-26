function runArduPilotPatch(rootPath, vehicleType)
% RUNARDUPILOTPATCH Apply Simulink patch to ArduPilot for the given vehicle type.
%   runArduPilotPatch(rootPath, vehicleType)
%
% Inputs
%   rootPath    - absolute or relative path to the ArduPilot repository root (char)
%   vehicleType - 'Copter' or 'Plane' (case-insensitive) (char)
%
% Behavior
%   - Validates inputs and locates a JSON configuration file named
%     "<vehicleType>_modification.json" in the same folder as this script.
%   - Calls applyCodeInsertions(rootPath, jsonPath) to apply tag-based edits.
%   - Copies the AC_Simulink folder contents from the script directory 'common'
%     into the repo at libraries/AC_Simulink.

% Prompt text informs the user about copying files and modifying GPL v3 code.
prompt = [ ...
    'This script will add new files to your ArduPilot repository and modify few existing ' ...
    'files to integrate a Simulink-specific library. \nThe ArduPilot repository ' ...
    'is licensed under GPL v3, and by proceeding you acknowledge that you are modifying ' ...
    'GPL v3–licensed software.\nDo you consent to proceed? [y/n]: '];

resp = input(prompt, 's');
if isempty(resp)
    return;
end
firstChar = lower(strtrim(resp(1)));
consent = any(firstChar == ('y'));
if ~consent
    return;
end
 
% Start logging command window outputs to a file
diary(fullfile(tempdir,'runArduPilotPatch_log.txt'));

% Validate vehicle type
vehicleType = lower(strtrim(vehicleType));
if ~ismember(vehicleType, {'copter', 'plane'})
    error('Invalid vehicle type. Use "Copter" or "Plane".');
end

% Determine JSON file path based on vehicle type
scriptDir = fileparts(mfilename('fullpath'));  % Directory of this script
jsonFileName = [vehicleType, '_modification.json'];  % .json file
jsonPath = fullfile(scriptDir, jsonFileName);

% Check if JSON file exists
if ~isfile(jsonPath)
    error('JSON configuration file not found: %s', jsonPath);
end

% Apply code insertions using the existing function
fprintf('Applying code insertions for %s...\n', upper(vehicleType));
applyCodeInsertions(rootPath, jsonPath);

% Prepare source and destination paths for AC_Simulink folder
sourceFolderCommon = fullfile(scriptDir, 'common');  % e.g., Copter/
destFolder = fullfile(rootPath, 'libraries', 'AC_Simulink');

% Copy AC_Simulink contents
fprintf('Copying AC_Simulink files from %s to %s...\n', sourceFolderCommon, destFolder);
if ~isfolder(sourceFolderCommon)
    error('Source folder not found: %s', sourceFolderCommon);
end

if isfolder(destFolder)
    rmdir(destFolder, 's');  % Remove existing folder
end
copyfile(sourceFolderCommon, destFolder,'f');

fprintf('Simulink patch applied successfully for %s.\n', upper(vehicleType));
% stop logging
diary off;

end
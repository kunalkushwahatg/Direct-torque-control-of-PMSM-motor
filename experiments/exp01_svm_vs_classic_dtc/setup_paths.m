function setup_paths()
%SETUP_PATHS  Run once per MATLAB session from this experiment folder.
%   Adds models/, scripts/ and the shared tools/ folder to the path and sends
%   Simulink's generated files (slprj, .slxc) to a temp cache so the project stays clean.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'models'), fullfile(root,'scripts'), fullfile(fileparts(fileparts(root)),'tools'));
cache = fullfile(tempdir,'dtc_sim_cache'); if ~exist(cache,'dir'), mkdir(cache); end
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',cache,'createDir',true);
fprintf('Paths set. Simulink cache folder: %s\n', cache);
end

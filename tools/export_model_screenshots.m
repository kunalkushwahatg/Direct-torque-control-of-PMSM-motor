function export_model_screenshots()
%EXPORT_MODEL_SCREENSHOTS  Save full top-level screenshots of every Simulink model.
%
% Run from the repository root, or with tools/ on the MATLAB path:
%   addpath('tools')
%   export_model_screenshots
%
% Output: docs/screenshots/<experiment>_<model>.png
%
% The models are loaded, zoomed to fit, printed, and closed without saving.

repo_root = fileparts(fileparts(mfilename('fullpath')));
outdir = fullfile(repo_root, 'docs', 'screenshots');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

items = {
    'exp01_classic_dtc_final', fullfile(repo_root, 'experiments', 'exp01_svm_vs_classic_dtc', 'models', 'classic_dtc_final.slx');
    'exp01_svm_dtc_final',     fullfile(repo_root, 'experiments', 'exp01_svm_vs_classic_dtc', 'models', 'svm_dtc_final.slx');
    'exp02_classic_dtc_rob',   fullfile(repo_root, 'experiments', 'exp02_robustness', 'models', 'classic_dtc_rob.slx');
    'exp02_svm_dtc_rob',       fullfile(repo_root, 'experiments', 'exp02_robustness', 'models', 'svm_dtc_rob.slx');
    'exp03_classic_dtc_rs',    fullfile(repo_root, 'experiments', 'exp03_rs_boundary', 'models', 'classic_dtc_rs.slx');
    'exp03_svm_dtc_rs',        fullfile(repo_root, 'experiments', 'exp03_rs_boundary', 'models', 'svm_dtc_rs.slx');
    'exp05_classic_winder',    fullfile(repo_root, 'experiments', 'exp05_winder_mechanics', 'models', 'classic_dtc_winder.slx');
    'exp05_svm_winder',        fullfile(repo_root, 'experiments', 'exp05_winder_mechanics', 'models', 'svm_dtc_winder.slx');
    'exp05_winder_plant',      fullfile(repo_root, 'experiments', 'exp05_winder_mechanics', 'winder_mechanics.slx')
};

for k = 1:size(items, 1)
    name = items{k, 1};
    file = items{k, 2};
    if ~isfile(file)
        warning('Skipping missing model: %s', file);
        continue;
    end
    [~, model, ~] = fileparts(file);
    fprintf('Exporting %s ...\n', name);
    load_system(file);
    set_param(model, 'ZoomFactor', 'FitSystem');
    print(['-s' model], '-dpng', '-r180', fullfile(outdir, [name '.png']));
    close_system(model, 0);
end
fprintf('Screenshots written to %s\n', outdir);
end

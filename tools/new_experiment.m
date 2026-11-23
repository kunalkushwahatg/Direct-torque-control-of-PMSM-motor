function new_experiment(name, projectRoot)
%NEW_EXPERIMENT  Create the next experiment folder with the standard structure.
%   new_experiment('robustness_rs_mismatch')  ->  experiments/exp02_robustness_rs_mismatch/
% The scripts (parameters, metrics, run_case/run_all, figure helpers) and the models are COPIED
% from the most recent experiment, so every experiment is a self-contained, reproducible snapshot.
if nargin < 2, projectRoot = fileparts(fileparts(mfilename('fullpath'))); end
ex = fullfile(projectRoot,'experiments'); d = dir(fullfile(ex,'exp*')); d = d([d.isdir]);
nums = cellfun(@(s) str2double(regexp(s,'^exp(\d+)_','tokens','once')), {d.name}); nums = nums(~isnan(nums));
n = 1; if ~isempty(nums), n = max(nums) + 1; end
dest = fullfile(ex, sprintf('exp%02d_%s', n, name));
for sub = {'models','scripts','results','figures'}, mkdir(fullfile(dest,sub{1})); end
if ~isempty(nums)
    [~,i] = max(nums); prev = fullfile(ex, d(i).name);
    copyfile(fullfile(prev,'scripts','*.m'), fullfile(dest,'scripts'));
    copyfile(fullfile(prev,'setup_paths.m'), dest);
    mdl = dir(fullfile(prev,'models','*.slx'));
    for k = 1:numel(mdl), copyfile(fullfile(prev,'models',mdl(k).name), fullfile(dest,'models')); end
    if exist(fullfile(dest,'scripts','build_final.m'),'file'), delete(fullfile(dest,'scripts','build_final.m')); end
end
fid = fopen(fullfile(dest,'README.md'),'w');
fprintf(fid, '# exp%02d_%s\n\n**Date:** %s\n\n', n, name, datestr(now,'yyyy-mm-dd'));
fprintf(fid, '## Goal\n(one or two sentences: the question this experiment answers)\n\n');
fprintf(fid, '## What changed vs the previous experiment\n- \n\n## Models and conditions\n- \n\n');
fprintf(fid, '## How to reproduce\n```matlab\nsetup_paths\nrun_all\nmake_figures\n```\n\n');
fprintf(fid, '## Results (key numbers; figures in figures/)\n- \n\n## Conclusions / next steps\n- \n');
fclose(fid);
fprintf('Created %s\n(models and scripts copied from the previous experiment - edit before running)\n', dest);
end

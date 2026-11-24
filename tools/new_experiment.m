function new_experiment(name, projectRoot)
%NEW_EXPERIMENT  Create the next experiment folder with the standard structure.
%   new_experiment('robustness_rs_mismatch')  ->  experiments/exp02_robustness_rs_mismatch/
%
%   Copies the common analysis scripts and models from the most recent
%   experiment so the new folder starts as a self-contained snapshot.
%   Model-building scripts are deliberately not copied.

if nargin < 2
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

ex = fullfile(projectRoot, 'experiments');
d = dir(fullfile(ex, 'exp*'));
d = d([d.isdir]);

names = {d.name};
nums = nan(size(names));
for k = 1:numel(names)
    tok = regexp(names{k}, '^exp(\d+)_', 'tokens', 'once');
    if ~isempty(tok)
        nums(k) = str2double(tok{1});
    end
end
valid = ~isnan(nums);
d = d(valid);
nums = nums(valid);

n = 1;
if ~isempty(nums)
    n = max(nums) + 1;
end

dest = fullfile(ex, sprintf('exp%02d_%s', n, name));
for sub = {'models', 'scripts', 'results', 'figures'}
    mkdir(fullfile(dest, sub{1}));
end

if ~isempty(nums)
    [~, i] = max(nums);
    prev = fullfile(ex, d(i).name);

    common_scripts = {'pmsm_dtc_parameters.m', 'dtc_metrics.m', ...
                      'run_case.m', 'run_all.m', 'make_results.m'};
    for k = 1:numel(common_scripts)
        src = fullfile(prev, 'scripts', common_scripts{k});
        if isfile(src)
            copyfile(src, fullfile(dest, 'scripts'));
        end
    end

    if isfile(fullfile(prev, 'setup_paths.m'))
        copyfile(fullfile(prev, 'setup_paths.m'), dest);
    end

    mdl = dir(fullfile(prev, 'models', '*.slx'));
    for k = 1:numel(mdl)
        copyfile(fullfile(prev, 'models', mdl(k).name), fullfile(dest, 'models'));
    end
end

template_file = fullfile(projectRoot, 'templates', 'experiment_readme_template.md');
if isfile(template_file)
    readme = fileread(template_file);
    readme = strrep(readme, 'expNN_short_name', sprintf('exp%02d_%s', n, name));
    readme = strrep(readme, '**Date:**   **Status:** planned / running / done', ...
                    sprintf('**Date:** %s   **Status:** planned', char(datetime('today','Format','yyyy-MM-dd'))));
    fid = fopen(fullfile(dest, 'README.md'), 'w');
    fprintf(fid, '%s', readme);
    fclose(fid);
else
    fid = fopen(fullfile(dest, 'README.md'), 'w');
    fprintf(fid, '# exp%02d_%s\n\n**Date:** %s   **Status:** planned\n', ...
            n, name, char(datetime('today','Format','yyyy-MM-dd')));
    fclose(fid);
end

fprintf('Created %s\n', dest);
fprintf('Copied scripts/models are a snapshot; edit them before running.\n');
end

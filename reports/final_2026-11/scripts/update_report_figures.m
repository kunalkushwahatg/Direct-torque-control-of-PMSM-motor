% UPDATE_REPORT_FIGURES  Copy the final exp05 case figures into the report folder.
% Also rebuilds the three-panel overlay from the saved case data.

here = fileparts(mfilename('fullpath'));
report_dir = fileparts(here);
repo_root = fileparts(fileparts(report_dir));
exp_root = fullfile(repo_root,'experiments','exp05_winder_mechanics');
figdir = fullfile(report_dir,'figures');

pairs = {
    'fig_case_classical_wind_ff1.png',   'fig_classic_wind.png'
    'fig_case_svm_wind_ff1.png',         'fig_svm_wind.png'
    'fig_case_classical_unwind_ff1.png', 'fig_classic_unwind.png'
    'fig_case_svm_unwind_ff1.png',       'fig_svm_unwind.png'
    'fig_summary_ff.png',                'fig_summary_ff.png'
};

for k = 1:size(pairs,1)
    src = fullfile(exp_root,'figures',pairs{k,1});
    dst = fullfile(figdir,pairs{k,2});
    if ~isfile(src)
        error('Missing source figure: %s', src);
    end
    copyfile(src,dst);
    fprintf('copied %s -> %s\n', pairs{k,1}, pairs{k,2});
end

run(fullfile(here,'make_overlay_3panel.m'));
fprintf('Report figures updated.\n');

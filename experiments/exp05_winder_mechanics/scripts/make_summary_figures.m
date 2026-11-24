function make_summary_figures()
%MAKE_SUMMARY_FIGURES  Rebuild fig_summary_ff.png from final_matrix.csv.
%   Left: tension RMSE with feedforward off/on.
%   Right: torque ripple with feedforward off/on.

exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(exp_root, fullfile(exp_root,'scripts'), ...
        fullfile(exp_root,'..','..','tools'));
T = readtable(fullfile(exp_root,'results','final_matrix.csv'));
tags = {'SVM_wind_ff0','SVM_wind_ff1','Classical_wind_ff0','Classical_wind_ff1', ...
        'SVM_unwind_ff0','SVM_unwind_ff1','Classical_unwind_ff0','Classical_unwind_ff1'};
idx = zeros(size(tags));
for k = 1:numel(tags)
    idx(k) = find(strcmp(T.tag, tags{k}), 1);
    if isempty(idx(k))
        error('Missing tag %s in final_matrix.csv', tags{k});
    end
end
R = T(idx,:);

rmse = reshape(R.F_rmse, 2, 4).';       % group x [FF0 FF1]
ripple = reshape(R.ripple, 2, 4).';
labels = {'SVM wind','Classical wind','SVM unwind','Classical unwind'};

fig = figure('Visible','off','Color','w','Position',[80 80 1200 460]);
subplot(1,2,1);
b = bar(rmse);
b(1).FaceColor = [0.85 0.33 0.10];
b(2).FaceColor = [0.00 0.45 0.74];
set(gca,'XTickLabel',labels,'FontSize',11,'Box','on','YGrid','on');
ylabel('Tension RMSE (N)');
legend({'FF off','FF on'},'Location','northwest');
title('Tension error');

subplot(1,2,2);
b = bar(ripple);
b(1).FaceColor = [0.85 0.33 0.10];
b(2).FaceColor = [0.00 0.45 0.74];
set(gca,'XTickLabel',labels,'FontSize',11,'Box','on','YGrid','on');
ylabel('Torque ripple, \sigma(T_e) (N·m)');
legend({'FF off','FF on'},'Location','northwest');
title('Torque ripple');

save_figure(fig,'fig_summary_ff',fullfile(exp_root,'figures'));
close(fig);
end

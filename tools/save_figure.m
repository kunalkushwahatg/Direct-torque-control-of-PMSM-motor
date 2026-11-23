function save_figure(fig, name, outdir)
%SAVE_FIGURE  Save a figure as PNG (300 dpi), vector PDF and editable .fig.
%   save_figure(gcf, 'fig01_dynamic_overview', fullfile(exp_root,'figures'))
if ~exist(outdir,'dir'), mkdir(outdir); end
exportgraphics(fig, fullfile(outdir,[name '.png']), 'Resolution', 300);
exportgraphics(fig, fullfile(outdir,[name '.pdf']), 'ContentType', 'vector');
savefig(fig, fullfile(outdir,[name '.fig']));
end

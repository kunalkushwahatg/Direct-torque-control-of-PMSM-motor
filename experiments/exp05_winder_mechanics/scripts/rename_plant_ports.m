% RENAME_PLANT_PORTS  Give the wrapped Plant block meaningful port labels.
% These are display names only; connectivity and results are unchanged.
exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(exp_root,'scripts'), fullfile(exp_root,'models'), ...
    fullfile(exp_root,'..','exp03_rs_boundary','scripts'));
pmsm_dtc_parameters; winder_params;
r0 = winder.r0_wind; H0 = 0; F0 = winder.F0; winder_mode_set = 1;

in_map  = {'g1','g2','g3','g4','g5','g6','vline','mode'};
out_map = {'i_a','i_c','i_b','F','r','i_mon','J','omega','v_surf','m','T_L','Te'};

for mdl = {'classic_dtc_winder_clean','svm_dtc_winder_clean'}
    m = mdl{1};
    if getSimulinkBlockHandle(m) <= 0, load_system(m); end
    fprintf('=== %s ===\n', m);

    ib = find_system([m '/Plant'],'SearchDepth',1,'BlockType','Inport');
    for k = 1:numel(ib)
        pn = str2double(get_param(ib{k},'Port'));
        if pn <= numel(in_map) && ~strcmp(get_param(ib{k},'Name'), in_map{pn})
            try
                set_param(ib{k},'Name',in_map{pn});
                fprintf('  in  %d -> %s\n', pn, in_map{pn});
            catch e
                fprintf('  in  %d FAILED: %s\n', pn, e.message);
            end
        end
    end

    ob = find_system([m '/Plant'],'SearchDepth',1,'BlockType','Outport');
    for k = 1:numel(ob)
        pn = str2double(get_param(ob{k},'Port'));
        if pn <= numel(out_map) && ~strcmp(get_param(ob{k},'Name'), out_map{pn})
            try
                set_param(ob{k},'Name',out_map{pn});
                fprintf('  out %d -> %s\n', pn, out_map{pn});
            catch e
                fprintf('  out %d FAILED: %s\n', pn, e.message);
            end
        end
    end
    save_system(m);
end
fprintf('done\n');

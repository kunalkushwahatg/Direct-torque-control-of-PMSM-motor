% RUN_FINAL_MATRIX  Four-way comparison + robustness subset (S-curve, damped web).
exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(exp_root, fullfile(exp_root,'scripts'), fullfile(exp_root,'models'), ...
    fullfile(exp_root,'..','..','tools'));
run(fullfile(exp_root,'..','exp03_rs_boundary','scripts','pmsm_dtc_parameters.m'));
run(fullfile(exp_root,'scripts','winder_params.m'));

rows = cell(0,22);

%% A. four-way comparison
cfgs = {'svm_dtc_winder','SVM',1,0.06; 'svm_dtc_winder','SVM',-1,0.115; ...
        'classic_dtc_winder','Classical',1,0.06; 'classic_dtc_winder','Classical',-1,0.115};
for c = 1:size(cfgs,1)
    for ff = [0 1]
        tag = sprintf('%s_%s_ff%d', cfgs{c,2}, ternary(cfgs{c,3}==1,'wind','unwind'), ff);
        met = run_case_2s(cfgs{c,1}, cfgs{c,3}, cfgs{c,4}, tag, ff, 1);
        rows(end+1,:) = {tag, cfgs{c,2}, ternary(cfgs{c,3}==1,'wind','unwind'), ff, ...
            met.F_rmse, met.F_max, met.F_min, met.F_mean_ss, met.overshoot, ...
            met.speed_rmse, met.mismatch_max, met.Te_peak, met.ripple, ...
            met.ia_peak, met.ia_rms, met.sat_time, met.bal_rms, ...
            met.r0_act, met.r_end, met.J0, met.J_end, met.wall}; %#ok<SAGROW>
    end
end

%% B. line-speed robustness (winding, full FF)
for v = [0.8 1.6]
    v_line_set = v;
    for c = [1 3]
        tag = sprintf('%s_wind_v%.1f_ff1', cfgs{c,2}, v);
        met = run_case_2s(cfgs{c,1}, 1, 0.06, tag, 1, 1);
        rows(end+1,:) = {tag, cfgs{c,2}, 'wind', 1, met.F_rmse, met.F_max, ...
            met.F_min, met.F_mean_ss, met.overshoot, met.speed_rmse, ...
            met.mismatch_max, met.Te_peak, met.ripple, met.ia_peak, met.ia_rms, ...
            met.sat_time, met.bal_rms, met.r0_act, met.r_end, met.J0, met.J_end, met.wall}; %#ok<SAGROW>
    end
end
v_line_set = 1.2;

%% C. initial-radius robustness (full FF)
radcases = {1, 0.08, 'wind_r080'; -1, 0.10, 'unwind_r100'};
for r = 1:2
    for c = [1 3]
        tag = sprintf('%s_%s_ff1', cfgs{c,2}, radcases{r,3});
        met = run_case_2s(cfgs{c,1}, radcases{r,1}, radcases{r,2}, tag, 1, 1);
        rows(end+1,:) = {tag, cfgs{c,2}, ternary(radcases{r,1}==1,'wind','unwind'), ...
            1, met.F_rmse, met.F_max, met.F_min, met.F_mean_ss, met.overshoot, ...
            met.speed_rmse, met.mismatch_max, met.Te_peak, met.ripple, ...
            met.ia_peak, met.ia_rms, met.sat_time, met.bal_rms, ...
            met.r0_act, met.r_end, met.J0, met.J_end, met.wall}; %#ok<SAGROW>
    end
end

%% D. tension-reference step 15 -> 18 N at 1.2 s (winding, full FF)
for c = [1 3]
    m = cfgs{c,1};
    tmpdir = tempname; mkdir(tmpdir); addpath(tmpdir);
    tmpmodel = [m '_fstep_tmp'];
    cleanupObj = onCleanup(@() cleanup_fstep(tmpdir, tmpmodel));
    copyfile(fullfile(exp_root,'models',[m '.slx']), fullfile(tmpdir,[tmpmodel '.slx']));
    load_system(fullfile(tmpdir,[tmpmodel '.slx']));

    % replace F_ref_set by a Step feeding the same destinations
    ph = get_param([tmpmodel '/F_ref_set'],'PortHandles');
    l  = get_param(ph.Outport(1),'Line');
    db = get_param(l,'DstBlockHandle'); dp = get_param(l,'DstPortHandle');
    dst = {};
    for q=1:numel(db), dst{end+1} = {get_param(db(q),'Name'), get_param(dp(q),'PortNumber')}; end %#ok<SAGROW>
    delete_line(l);
    add_block('simulink/Sources/Step',[tmpmodel '/F_step'], ...
        'Position',[760 940 800 970], ...
        'Time','1.2','Before','15','After','18');
    for q=1:numel(dst)
        add_line(tmpmodel,'F_step/1',[dst{q}{1} '/' num2str(dst{q}{2})],'autorouting','on');
    end

    tag = sprintf('%s_wind_Fstep_ff1', cfgs{c,2});
    met = run_case_2s(tmpmodel, 1, 0.06, tag, 1, 1);
    rows(end+1,:) = {tag, cfgs{c,2}, 'wind', 1, met.F_rmse, met.F_max, ...
        met.F_min, met.F_mean_ss, met.overshoot, met.speed_rmse, ...
        met.mismatch_max, met.Te_peak, met.ripple, met.ia_peak, met.ia_rms, ...
        met.sat_time, met.bal_rms, met.r0_act, met.r_end, met.J0, met.J_end, met.wall}; %#ok<SAGROW>
    close_system(tmpmodel,0);
    clear cleanupObj;
end

%% save
T = cell2table(rows,'VariableNames',{'tag','controller','direction','ff', ...
    'F_rmse','F_max','F_min','F_mean','overshoot','speed_rmse','mismatch_max', ...
    'Te_peak','ripple','ia_peak','ia_rms','sat_time','balance_rms', ...
    'r0','r_end','J0','J_end','wall'});
writetable(T, fullfile(exp_root,'results','final_matrix.csv'));
save(fullfile(exp_root,'results','final_matrix.mat'),'T');
disp(T(:,{'tag','controller','direction','ff','F_rmse','F_max','F_min','speed_rmse','ia_peak','sat_time'}));

function cleanup_fstep(tmpdir,tmpmodel)
    if bdIsLoaded(tmpmodel), close_system(tmpmodel,0); end
    if contains(path,tmpdir), rmpath(tmpdir); end
    if exist(tmpdir,'dir'), rmdir(tmpdir,'s'); end
end

function s = ternary(cond,a,b)
    if cond, s = a; else, s = b; end
end



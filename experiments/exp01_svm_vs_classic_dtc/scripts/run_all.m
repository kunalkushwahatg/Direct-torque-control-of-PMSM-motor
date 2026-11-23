% Runs the dynamic test and the speed x load sweep for BOTH controllers (sequentially, ~3 hours).
% To use several MATLAB sessions, set  sel = 1  (SVM-DTC) or  sel = 2  (classical) before calling run_all.
exp_root = fileparts(fileparts(mfilename('fullpath'))); addpath(exp_root); setup_paths;
models = {'svm_dtc_final','classic_dtc_final'}; short = {'svm','cl'};
if ~exist('sel','var'), sel = 1:2; end
for im = sel
    % case table: tag, speed, TL0, TL, t_load, t_stop, windows, names, dynamic?
    cases = {{[short{im} '_dyn'], 20, 0.5, 2, 0.5, 1.0, {[0.3 0.5],[0.7 1.0]}, {'light','load'}, true}};
    for w = [10 30 60]
        for TLs = [0.5 4]   % load stepped 0.5 -> TLs at 0.3 s, steady window 0.5-0.9 s
            cases{end+1} = {sprintf('%s_w%d_T%g', short{im}, w, TLs), w, 0.5, TLs, 0.3, 0.9, {[0.5 0.9]}, {'ss'}, false}; %#ok<SAGROW>
        end
    end
    for ic = 1:numel(cases)
        c = cases{ic};
        case_model = models{im}; case_tag = c{1}; case_w = c{2}; case_TL0 = c{3}; case_TL = c{4};
        case_tload = c{5}; case_tstop = c{6}; case_win = c{7}; case_names = c{8}; case_dynamic = c{9};
        if exist(fullfile(exp_root,'results',['result_' case_tag '.mat']),'file'), continue; end   % resume support
        run_case;
    end
end

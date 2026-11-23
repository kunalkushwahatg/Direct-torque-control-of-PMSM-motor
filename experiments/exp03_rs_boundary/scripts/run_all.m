% Finer Rs-mismatch sweep (both controllers, 5 and 20 rad/s): 20 simulations.
% Two MATLAB sessions:  sel = 1 (SVM-DTC)  and  sel = 2 (classical), then run_all.
exp_root = fileparts(fileparts(mfilename('fullpath'))); addpath(exp_root); setup_paths;
models = {'svm_dtc_rs','classic_dtc_rs'}; short = {'svm','cl'};
if ~exist('sel','var'), sel = 1:2; end
for im = sel
    cases = {};
    for w = [20 5]
        for f = [0.8 0.9 1.05 1.1 1.2]
            cases{end+1} = {sprintf('%s_w%d_rs%03d',short{im},w,round(100*f)), w, 0.5, 2, 0.3, 0.9, f, 1e9, {[0.5 0.9]}, {'ss'}, w, 2}; %#ok<SAGROW>
        end
    end
    for ic = 1:numel(cases)
        c = cases{ic};
        case_model = models{im}; case_tag = c{1}; case_w = c{2}; case_TL0 = c{3}; case_TL = c{4}; case_tload = c{5}; case_tstop = c{6};
        case_rsf = c{7}; case_trev = c{8}; case_win = c{9}; case_names = c{10}; case_wt = c{11}; case_TLt = c{12};
        if exist(fullfile(exp_root,'results',['result_' case_tag '.mat']),'file'), continue; end
        run_case;
    end
end

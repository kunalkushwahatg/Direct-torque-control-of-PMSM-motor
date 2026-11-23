% Robustness cases for BOTH controllers (about 20 simulations, ~12-18 min each).
% To use two MATLAB sessions: set  sel = 1  (SVM-DTC) in one and  sel = 2  (classical) in the other, then run_all.
exp_root = fileparts(fileparts(mfilename('fullpath'))); addpath(exp_root); setup_paths;
models = {'svm_dtc_rob','classic_dtc_rob'}; short = {'svm','cl'};
if ~exist('sel','var'), sel = 1:2; end
for im = sel
    cases = {};
    % Set 1: Rs mismatch at medium speed (20 rad/s, load 0.5 -> 2 N.m at 0.3 s, window 0.5-0.8 s)
    for f = [0.7 1.0 1.3]
        cases{end+1} = {sprintf('%s_mid_rs%03d',short{im},round(100*f)), 20, 0.5, 2, 0.3, 0.8, f, 1e9, {[0.5 0.8]}, {'ss'}, 20, 2}; %#ok<SAGROW>
    end
    % Set 2: Rs mismatch at LOW speed (2 and 5 rad/s, window 0.5-0.9 s)
    for w = [5 2]
        for f = [0.7 1.0 1.3]
            cases{end+1} = {sprintf('%s_low_w%d_rs%03d',short{im},w,round(100*f)), w, 0.5, 2, 0.3, 0.9, f, 1e9, {[0.5 0.9]}, {'ss'}, w, 2}; %#ok<SAGROW>
        end
    end
    % Set 3: speed reversal +5 -> -5 rad/s at 0.6 s, load 1 N.m, no Rs error
    cases{end+1} = {sprintf('%s_reversal',short{im}), 5, 0.5, 1, 0.2, 1.2, 1.0, 0.6, {[0.4 0.6],[0.9 1.2]}, {'fwd','rev'}, [5 -5], [1 1]}; %#ok<SAGROW>
    for ic = 1:numel(cases)
        c = cases{ic};
        case_model = models{im}; case_tag = c{1}; case_w = c{2}; case_TL0 = c{3}; case_TL = c{4}; case_tload = c{5}; case_tstop = c{6};
        case_rsf = c{7}; case_trev = c{8}; case_win = c{9}; case_names = c{10}; case_wt = c{11}; case_TLt = c{12};
        if exist(fullfile(exp_root,'results',['result_' case_tag '.mat']),'file'), continue; end   % resume support
        run_case;
    end
end

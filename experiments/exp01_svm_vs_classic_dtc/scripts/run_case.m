% Runs ONE simulation case and saves result_<case_tag>.mat
% Set these variables first (run_all.m does it for you):
%   case_model  case_tag  case_w  case_TL0  case_TL  case_tload  case_tstop  case_win  case_names  case_dynamic
exp_root = fileparts(fileparts(mfilename('fullpath')));
pmsm_dtc_parameters;
w_ref = case_w; TL_init = case_TL0; TL = case_TL; t_load = case_tload; Tsim = case_tstop;
load_system(case_model);
set_param(case_model,'SimscapeLogType','none','SignalLogging','off','SaveOutput','off');
out = sim(case_model);
cfg = struct('p',p,'lambda_f',lambda_f,'w_ref',w_ref,'ramp_time',0.05,'load_time',t_load, ...
    'windows',{case_win},'win_names',{case_names},'band_speed',0.01,'dt',1e-5, ...
    'thd_fmax',20e3,'current_sign',-1,'dynamic',case_dynamic);
r = dtc_metrics(out, cfg);
r.case = struct('model',case_model,'tag',case_tag,'w',case_w,'TL0',case_TL0,'TL',case_TL,'Ts_dtc',Ts_dtc);
save(fullfile(exp_root,'results',['result_' case_tag '.mat']),'r');
disp(['CASE DONE ' case_tag]);
close_system(case_model,0);

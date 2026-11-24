% HISTORICAL / DOCUMENTATION ONLY: shows how the *_final.slx models were derived from the development models.
% Those earlier models are not part of the public repository; they remain in Git history.
% The paths below refer to the old flat layout and will not run as-is.
% Builds svm_dtc_final.slx and classic_dtc_final.slx from the working models in the parent folder.
here = pwd; par = fileparts(here);
pmsm_dtc_parameters;
function lg(m,blk,port,nm,y)
 add_block('simulink/Sinks/To Workspace',[m '/' nm],'VariableName',nm,'MaxDataPoints','inf','SaveFormat','Timeseries','SampleTime','-1','Position',[1300 y 1360 y+20]);
 ph=get_param(blk,'PortHandles'); add_line(m,ph.Outport(port),get_param([m '/' nm],'PortHandles').Inport(1));
end
function common(m)
 set_param([m '/omega_ref'],'After','w_ref');
 set_param([m '/Load_step'],'Time','t_load','Before','-TL_init','After','-TL');
 set_param([m '/PID Controller'],'P','Kp_speed','I','Ki_speed','AntiWindupMode','clamping');
 b=find_system(m,'SearchDepth',1,'Regexp','on','Name','PS-Simulink.*Converter5'); lg(m,b{1},1,'ib_data',540);
 set_param(m,'SimscapeLogType','none','StopTime','Tsim');
end

%% ---------------- SVM-DTC ----------------
src=[par '\svm_dtc.slx']; load_system(src); m='svm_dtc';
save_system(m,[here '\svm_dtc_final.slx']); m='svm_dtc_final';
pw=find_system(m,'SearchDepth',1,'Regexp','on','Name','PWM Generator.*'); set_param(pw{1},'Ts','Ts_pwm');
common(m);
% estimator voltage: gate-derived voltages at PWM rate -> average over one controller period -> hold at Ts_dtc
N='round(Ts_dtc/Ts_pwm)';
est=[m '/dtc_estimator']; pe=get_param(est,'PortHandles');
for k=[4 5], delete_line(get_param(pe.Inport(k),'Line')); end
fa=[m '/valpha_app']; fb=[m '/vbeta_app']; pa=get_param(fa,'PortHandles'); pb=get_param(fb,'PortHandles');
names={'avg_valpha','avg_vbeta'}; src_p={pa,pb}; dst=[4 5]; y=[400 450];
for i=1:2
  fir=[m '/' names{i}]; zoh=[m '/hold_' names{i}];
  add_block('simulink/Discrete/Discrete FIR Filter',fir,'Coefficients',['ones(1,' N ')/' N],'SampleTime','Ts_pwm','Position',[1100 y(i) 1180 y(i)+30]);
  add_block('simulink/Discrete/Zero-Order Hold',zoh,'SampleTime','Ts_dtc','Position',[1220 y(i) 1260 y(i)+30]);
  pf=get_param(fir,'PortHandles'); pz=get_param(zoh,'PortHandles');
  add_line(m,src_p{i}.Outport(1),pf.Inport(1)); add_line(m,pf.Outport(1),pz.Inport(1)); add_line(m,pz.Outport(1),pe.Inport(dst(i)));
end
set_param(m,'SimulationCommand','update'); disp('SVM FINAL UPDATE OK'); save_system(m); close_system(m,0);

%% ---------------- Classical DTC ----------------
src=[par '\pmsm_dtc_classic_baseline_matched.slx']; load_system(src); m='pmsm_dtc_classic_baseline_matched';
save_system(m,[here '\classic_dtc_final.slx']); m='classic_dtc_final';
common(m);
set_param(m,'SimulationCommand','update'); disp('CLASSIC FINAL UPDATE OK'); save_system(m); close_system(m,0);

% Documentation + builder: adds the robustness hooks to the exp02 copies of the two models.
%   1) estimator stator resistance = Rs * Rs_factor   (the real motor keeps Rs)
%   2) optional speed reversal: second step 'omega_rev' added to the speed reference (t_rev, after = -2*w_ref)
root = fileparts(fileparts(mfilename('fullpath'))); cd(root); setup_paths; pmsm_dtc_parameters;
for mname = {'svm_dtc_rob','classic_dtc_rob'}
    m = mname{1}; load_system(m);
    set_param([m '/Constant7'],'Value','Rs*Rs_factor');                       % estimator Rs
    w = [m '/omega_ref']; r = [m '/omega_ref_ramp'];
    pr = get_param(r,'PortHandles'); delete_line(get_param(pr.Inport(1),'Line'));
    pos = get_param(w,'Position');
    add_block('simulink/Sources/Step',[m '/omega_rev'],'Time','t_rev','Before','0','After','-2*w_ref','SampleTime','Ts_dtc','Position',pos+[0 60 0 60]);
    add_block('simulink/Math Operations/Sum',[m '/ref_sum'],'Inputs','++','Position',[pos(3)+40 pos(2)+10 pos(3)+70 pos(2)+50]);
    ps = get_param([m '/ref_sum'],'PortHandles'); pw = get_param(w,'PortHandles'); pv = get_param([m '/omega_rev'],'PortHandles');
    add_line(m,pw.Outport(1),ps.Inport(1)); add_line(m,pv.Outport(1),ps.Inport(2)); add_line(m,ps.Outport(1),pr.Inport(1));
    set_param(m,'SimulationCommand','update'); save_system(m); close_system(m,0); fprintf('%s built\n',m);
end

% RUN_FF3  Compare A (off), B (full), C (inertia-only) on winding.
exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(exp_root, fullfile(exp_root,'scripts'), fullfile(exp_root,'models'), ...
    fullfile(exp_root,'..','..','tools'));
run(fullfile(exp_root,'..','exp03_rs_boundary','scripts','pmsm_dtc_parameters.m'));
run(fullfile(exp_root,'scripts','winder_params.m'));

T_ramp = 1.0;
add_feedforward('svm_dtc_winder');

load_system('svm_dtc_winder');
set_param('svm_dtc_winder','SimscapeLogType','none');

if getSimulinkBlockHandle('svm_dtc_winder/wref_log') < 0
    add_block('simulink/Sinks/To Workspace','svm_dtc_winder/wref_log', ...
        'VariableName','wref_log','SaveFormat','Timeseries','Position',[900 700 940 725]);
    add_line('svm_dtc_winder','omega_ref_ramp/1','wref_log/1');
end
if getSimulinkBlockHandle('svm_dtc_winder/vline_log') < 0
    add_block('simulink/Sinks/To Workspace','svm_dtc_winder/vline_log', ...
        'VariableName','vline_log','SaveFormat','Timeseries','Position',[900 780 940 805]);
    add_line('svm_dtc_winder','v_sat/1','vline_log/1');
end

r0 = winder.r0_unwind; H0 = 0; F0 = winder.F0;
winder_mode_set = -1; filt_on = 1; Tsim = 0.5;

cases = {'A',0,1; 'B',1,1; 'C',1,0};
R = struct();

for k = 1:size(cases,1)
    tag = cases{k,1}; ff_on = cases{k,2}; ff_full = cases{k,3};
    out = sim('svm_dtc_winder');

    t  = out.get('F_log').Time;
    F  = out.get('F_log').Data;
    omg = out.get('w_data').Data;
    wr = out.get('wref_log').Data;
    vl = out.get('vline_log').Data;
    r  = out.get('r_log').Data;
    J  = out.get('J_log').Data;
    TL = out.get('TL_log').Data;
    Te = out.get('Te_log').Data;
    ia = out.get('ia_data').Data;

    sel = t >= 0.1;
    vs  = omg.*r;
    H   = J.*omg;
    res = Te - TL - B*omg - gradient(H,t);

    m.tension_rmse = sqrt(mean((F(sel)-F_ref).^2));
    m.Fmax = max(F); m.Fmin = min(F);
    m.overshoot = max(F) - F_ref;
    m.speed_rmse = sqrt(mean((wr(sel)-omg(sel)).^2));
    m.vs_mismatch = max(abs(vs(sel)-vl(sel)));
    m.Te_peak = max(abs(Te));
    m.ripple = std(Te(sel));
    m.ia_peak = max(abs(ia));
    m.ia_rms = sqrt(mean(ia(sel).^2));
    m.sat_time = sum(abs(Te)>=0.99*Tmax)*mean(diff(t));
    m.bal_rms = sqrt(mean(res(sel).^2));
    m.bal_max = max(abs(res(sel)));

    fprintf('\n=== %s (ff_on=%d, ff_full=%d) ===\n', tag, ff_on, ff_full);
    fprintf('  tension RMSE %.3f N  max %.2f  min %.2f  overshoot %.2f\n', ...
        m.tension_rmse, m.Fmax, m.Fmin, m.overshoot);
    fprintf('  speed RMSE %.5f rad/s  mismatch %.3e m/s\n', m.speed_rmse, m.vs_mismatch);
    fprintf('  Te peak %.3f  ripple %.3f  sat %.3f s\n', m.Te_peak, m.ripple, m.sat_time);
    fprintf('  ia peak %.2f A  rms %.2f A  balance rms %.3e\n', m.ia_peak, m.ia_rms, m.bal_rms);

    R.(tag).t=t; R.(tag).F=F; R.(tag).err=wr-omg; R.(tag).m=m;
end

save(fullfile(exp_root,'results','ff3_unwinding.mat'),'R');

fig = figure('Visible','off','Color','w','Position',[80 80 1100 420]);
cols = {[0 0.447 0.741],[0.85 0.33 0.10],[0.47 0.67 0.19]};
subplot(1,2,1); hold on;
for k=1:3, plot(R.(cases{k,1}).t,R.(cases{k,1}).F,'Color',cols{k},'LineWidth',1.3); end
yline(F_ref,'k--'); grid on; xlabel('t [s]'); ylabel('F [N]');
legend({'A: ff off','B: full ff','C: inertia-only','F_{ref}'},'Location','southeast');
title('Web tension');

subplot(1,2,2); hold on;
for k=1:3, plot(R.(cases{k,1}).t,R.(cases{k,1}).err,'Color',cols{k},'LineWidth',1.3); end
grid on; xlabel('t [s]'); ylabel('w_{ref}-w [rad/s]');
legend({'A','B','C'},'Location','southeast'); title('Speed tracking error');

save_figure(fig,'fig_ff3_unwinding',fullfile(exp_root,'figures'));
close(fig);
fprintf('\nSaved fig_ff3_unwinding and results/ff3_unwinding.mat\n');




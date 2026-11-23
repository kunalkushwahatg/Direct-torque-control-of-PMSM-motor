function met = run_case_2s(model, mode, r0, tag, ffon, fffull)
%RUN_CASE_2S  Two-second winder case with metrics, raw data and plots.
%   model : 'svm_dtc_winder' or 'classic_dtc_winder'
%   mode  : +1 winding, -1 unwinding
%   r0    : initial radius [m]
%   tag   : file tag
%   ffon  : 0/1 feedforward gate
%   fffull: 1 full, 0 inertia only

exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(exp_root, fullfile(exp_root,'scripts'), fullfile(exp_root,'models'), ...
    fullfile(exp_root,'..','..','tools'));

Fref = evalin('base','F_ref');
Bv   = evalin('base','B');
Tmaxv= evalin('base','Tmax');

assignin('base','winder_mode_set',mode);
assignin('base','r0',r0);
assignin('base','H0',0);
assignin('base','F0',Fref);
assignin('base','Tsim',2);
assignin('base','T_ramp',1.0);
assignin('base','ff_on',ffon);
assignin('base','ff_full',fffull);
assignin('base','filt_on',1);

load_system(model);
set_param(model,'MaxStep','5e-6','SimscapeLogType','none');

if getSimulinkBlockHandle([model '/wref_log']) < 0
    add_block('simulink/Sinks/To Workspace',[model '/wref_log'], ...
        'VariableName','wref_log','SaveFormat','Timeseries','Position',[900 700 940 725]);
    add_line(model,'omega_ref_ramp/1','wref_log/1');
end
if getSimulinkBlockHandle([model '/vline_log']) < 0
    add_block('simulink/Sinks/To Workspace',[model '/vline_log'], ...
        'VariableName','vline_log','SaveFormat','Timeseries','Position',[900 780 940 805]);
    add_line(model,'v_sat/1','vline_log/1');
end

tic; out = sim(model); wall = toc;

t  = out.get('F_log').Time;
F  = out.get('F_log').Data;
omg= out.get('w_data').Data;
wr = out.get('wref_log').Data;
vl = out.get('vline_log').Data;
r  = out.get('r_log').Data;
J  = out.get('J_log').Data;
TL = out.get('TL_log').Data;
Te = out.get('Te_log').Data;
ia = out.get('ia_data').Data;

vs  = omg.*r;
H   = J.*omg;
res = Te - TL - Bv*omg - gradient(H,t);
sel = t >= 1.3;

met.model = string(model);
met.mode = mode; met.r0 = r0; met.ffon = ffon; met.fffull = fffull;
met.wall = wall;
met.F_rmse = sqrt(mean((F(sel)-Fref).^2));
met.F_max = max(F); met.F_min = min(F);
met.F_mean_ss = mean(F(sel));
met.overshoot = max(F)-Fref;
met.slack_frac = mean(F<0.5);
met.speed_rmse = sqrt(mean((wr(sel)-omg(sel)).^2));
met.mismatch_max = max(abs(vs(sel)-vl(sel)));
met.mismatch_rms = sqrt(mean((vs(sel)-vl(sel)).^2));
met.Te_peak = max(abs(Te));
met.ripple = std(Te(sel));
met.ia_peak = max(abs(ia));
met.ia_rms = sqrt(mean(ia(sel).^2));
met.sat_time = sum(abs(Te)>=0.99*Tmaxv)*mean(diff(t));
met.bal_rms = sqrt(mean(res(sel).^2));
met.bal_max = max(abs(res(sel)));
met.r_end = r(end); met.J_end = J(end);
met.r0_act = r(1); met.J0 = J(1);
met.v_ss = mean(vl(sel));

resdir = fullfile(exp_root,'results');
figdir = fullfile(exp_root,'figures');
save(fullfile(resdir,['val2s_' tag '.mat']), ...
    't','F','omg','wr','vl','r','J','TL','Te','ia','met');

fig = figure('Visible','off','Color','w','Position',[60 60 1300 760]);
subplot(2,3,1); plot(t,F,'b','LineWidth',1.2); hold on; yline(Fref,'k--'); grid on;
xlabel('t [s]'); ylabel('F [N]'); title('Web tension');
subplot(2,3,2); plot(t,omg,'b','LineWidth',1.1); hold on;
plot(t,wr,'--','Color',[0.85 0.33 0.10],'LineWidth',1.8); grid on;
xlabel('t [s]'); ylabel('\omega [rad/s]'); legend({'\omega','\omega_{ref}'},'Location','southeast');
title('Shaft speed');
subplot(2,3,3); plot(t,r,'b','LineWidth',1.2); grid on;
xlabel('t [s]'); ylabel('r [m]'); title('Roll radius');
subplot(2,3,4); plot(t,J,'b','LineWidth',1.2); grid on;
xlabel('t [s]'); ylabel('J [kg m^2]'); title('Total inertia');
subplot(2,3,5); plot(t,Te,'b','LineWidth',1.0); yline(Tmaxv,'r--'); yline(-Tmaxv,'r--'); grid on;
xlabel('t [s]'); ylabel('T_e [N m]'); title('Motor torque');
subplot(2,3,6); plot(t,vs-vl,'b','LineWidth',1.0); grid on;
xlabel('t [s]'); ylabel('v_{surf}-v_{line} [m/s]'); title('Surface-speed mismatch');
if contains(model,'svm','IgnoreCase',true)
    ctrl_name = 'SVM-DTC';
else
    ctrl_name = 'Classical DTC';
end
if mode > 0, dir_name = 'winding'; else, dir_name = 'unwinding'; end
sgtitle(sprintf('%s: %s', ctrl_name, dir_name));
save_figure(fig,['fig2s_' tag],figdir);
close(fig);

fprintf('\n=== %s ===\n', tag);
fprintf('  r %.4f -> %.4f m   J %.5f -> %.5f\n', met.r0_act, met.r_end, met.J0, met.J_end);
fprintf('  F rmse %.3f N  max %.2f  min %.2f  mean %.2f  slack %.1f %%\n', ...
    met.F_rmse, met.F_max, met.F_min, met.F_mean_ss, 100*met.slack_frac);
fprintf('  speed rmse %.5f  mismatch max %.2e  Te peak %.3f  ripple %.3f\n', ...
    met.speed_rmse, met.mismatch_max, met.Te_peak, met.ripple);
fprintf('  ia peak %.2f A rms %.2f A  sat %.3f s  balance rms %.2e  wall %.0f s\n', ...
    met.ia_peak, met.ia_rms, met.sat_time, met.bal_rms, wall);
end

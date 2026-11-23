% RUN_COMPARISON  Same winder case through SVM-DTC and classical DTC.
%
%   Case: winding, r0 = 0.06 m, v_line = 1.2 m/s, F0 = 15 N,
%         speed reference 20 rad/s, Tsim = 0.2 s.
%
%   Torque balance checked as  Te - TL - B*w - d(J*w)/dt.

exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(exp_root, fullfile(exp_root,'scripts'), fullfile(exp_root,'models'), ...
        fullfile(exp_root,'..','..','tools'));
run(fullfile(exp_root,'..','exp03_rs_boundary','scripts','pmsm_dtc_parameters.m'));
run(fullfile(exp_root,'scripts','winder_params.m'));

r0 = winder.r0_wind;
H0 = 0;
F0 = winder.F0;
v_line_set = 1.2;
winder_mode_set = 1;
Tsim = 0.2;

models = {'svm_dtc_winder','classic_dtc_winder'};
labels = {'SVM-DTC','Classical DTC'};
keys   = {'SVM','Classical'};
D = struct();

for i = 1:numel(models)
    m = models{i};
    load_system(m);
    set_param(m,'SimscapeLogType','none');
    fprintf('\n=== %s ===\n', labels{i});
    tic; out = sim(m); el = toc;

    t  = out.get('w_data').Time;
    omg = out.get('w_data').Data;
    F  = out.get('F_log').Data;
    r  = out.get('r_log').Data;
    J  = out.get('J_log').Data;
    TL = out.get('TL_log').Data;
    Te = out.get('Te_log').Data;

    H  = J.*omg;
    dH = gradient(H,t);
    res = Te - TL - B*omg - dH;
    sel = t >= 0.15;

    met.w_ss    = mean(omg(sel));
    met.w_err   = 100*abs(met.w_ss - w_ref)/w_ref;
    met.w_max   = max(omg);
    met.F_end   = F(end);
    met.r_end   = r(end);
    met.J_end   = J(end);
    met.Te_end  = Te(end);
    met.Te_max  = max(Te);
    met.bal_rms = rms(res(sel));
    met.bal_max = max(abs(res(sel)));
    met.simtime = el;

    fprintf('  speed: %.3f rad/s (err %.2f %%), peak %.3f\n', met.w_ss, met.w_err, met.w_max);
    fprintf('  tension end: %.2f N\n', met.F_end);
    fprintf('  radius: %.5f -> %.5f m   inertia: %.5f -> %.5f kg m^2\n', ...
        r(1), met.r_end, J(1), met.J_end);
    fprintf('  Te end: %.3f N m, peak %.3f N m\n', met.Te_end, met.Te_max);
    fprintf('  torque balance residual: rms %.3e, max %.3e N m\n', met.bal_rms, met.bal_max);
    fprintf('  sim time %.1f s\n', el);

    D.(keys{i}).t=t; D.(keys{i}).omg=omg; D.(keys{i}).F=F; D.(keys{i}).r=r;
    D.(keys{i}).J=J; D.(keys{i}).TL=TL; D.(keys{i}).Te=Te; D.(keys{i}).met=met;
    save(fullfile(exp_root,'results',['comparison_' models{i} '.mat']), ...
        't','omg','F','r','J','TL','Te','met');
end

% ---- comparison table ----
fprintf('\n%-16s %10s %10s\n','metric','SVM-DTC','Classical');
for f = {'w_ss','w_err','F_end','r_end','J_end','Te_end','Te_max','bal_rms'}
    a = D.('SVM').met.(f{1});
    b = D.('Classical').met.(f{1});
    fprintf('%-16s %10.4g %10.4g\n', f{1}, a, b);
end

% ---- figure ----
fig = figure('Visible','off','Color','w','Position',[80 80 1250 720]);
cols = {[0 0.447 0.741],[0.85 0.33 0.10]};

subplot(2,3,1); hold on;
for i=1:2, plot(D.(keys{i}).t,D.(keys{i}).omg,'Color',cols{i},'LineWidth',1.2); end
yline(w_ref,'k--'); grid on; xlabel('t [s]'); ylabel('\omega [rad/s]');
legend(labels,'Location','southeast'); title('Shaft speed');

subplot(2,3,2); hold on;
for i=1:2, plot(D.(keys{i}).t,D.(keys{i}).F,'Color',cols{i},'LineWidth',1.2); end
grid on; xlabel('t [s]'); ylabel('F [N]'); title('Web tension');

subplot(2,3,3); hold on;
for i=1:2, plot(D.(keys{i}).t,D.(keys{i}).r,'Color',cols{i},'LineWidth',1.2); end
grid on; xlabel('t [s]'); ylabel('r [m]'); title('Roll radius');

subplot(2,3,4); hold on;
for i=1:2, plot(D.(keys{i}).t,D.(keys{i}).J,'Color',cols{i},'LineWidth',1.2); end
grid on; xlabel('t [s]'); ylabel('J [kg m^2]'); title('Total inertia');

subplot(2,3,5); hold on;
for i=1:2, plot(D.(keys{i}).t,D.(keys{i}).TL,'Color',cols{i},'LineWidth',1.2); end
grid on; xlabel('t [s]'); ylabel('T_{web} [N m]'); title('Web load torque');

subplot(2,3,6); hold on;
for i=1:2, plot(D.(keys{i}).t,D.(keys{i}).Te,'Color',cols{i},'LineWidth',1.2); end
grid on; xlabel('t [s]'); ylabel('T_e [N m]'); title('Motor torque');

sgtitle('Winder case: SVM-DTC vs classical DTC (identical mechanics)');
save_figure(fig,'fig_controller_comparison',fullfile(exp_root,'figures'));
close(fig);
fprintf('\nSaved comparison figure and .mat files.\n');



% VALIDATE_WINDER  Standalone validation of the winder/unwinder mechanics.
%
% Runs winding and unwinding cases, checks the equations numerically,
% writes results/validation_metrics.csv and six plots per case.

exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(exp_root, fullfile(exp_root,'scripts'), fullfile(exp_root,'models'), ...
        fullfile(exp_root,'..','..','tools'));
run(fullfile(exp_root,'scripts','winder_params.m'));

resdir = fullfile(exp_root,'results');
figdir = fullfile(exp_root,'figures');

cases = { ...
    'winding',   +1, winder.r0_wind,   20; ...
    'unwinding', -1, winder.r0_unwind, 20  };

allm = table();
for ic = 1:size(cases,1)
    name  = cases{ic,1};
    mode  = cases{ic,2};
    r0    = cases{ic,3};
    Tsim  = cases{ic,4};

    winder_mode = mode;
    omega0 = v_init/r0;
    J0     = winder_Jfun(r0);
    H0     = J0*omega0;
    F0     = winder.F0;
    Te0    = mode*F0*r0;          % bumpless start: preload the speed-loop integrator

    fprintf('\n=== %s: mode=%+d, r0=%.3f m, Tsim=%.0f s ===\n', name, mode, r0, Tsim);
    out = sim('winder_mechanics');

    % logging order: r J F vline vsurf TL omega Te omega_ref draw
    LOG    = out.get('logs').Data;
    t      = out.get('logs').Time;
    r      = LOG(:,1);
    J      = LOG(:,2);
    F      = LOG(:,3);
    vline  = LOG(:,4);
    vsurf  = LOG(:,5);
    TL     = LOG(:,6);
    omega  = LOG(:,7);
    Te     = LOG(:,8);

    % mass signal (plant output 7 is not in the log vector; recompute)
    m = rho*w*pi*max(r.^2-rc^2,0);

    met = check_case(t,r,J,F,vline,vsurf,TL,omega,Te,m,mode,r0, ...
                     F_ref,rc,rmax,Fmax,Jm,Jc,rho,w,h,E,A,L,B);

    met.case = string(name);
    allm = [allm; struct2table(met)]; %#ok<AGROW>

    save(fullfile(resdir,['validation_' name '.mat']), ...
        't','r','J','F','vline','vsurf','TL','omega','Te','m','met');

    plot_case(t,r,J,F,vline,vsurf,TL,omega,F_ref,name,figdir);
    print_metrics(name,met);
end

writetable(allm, fullfile(resdir,'validation_metrics.csv'));
fprintf('\nWrote results/validation_metrics.csv\n');
fprintf('\n--- summary ---\n');
disp(allm(:,{'case','r_dir_ok','J_dir_ok','F_ss_err_pct','v_match_pct', ...
    'r_ode_rel','H_ode_rel','F_ode_rel','TL_err','J_err','limits_ok'}));

%% =======================================================================
function met = check_case(t,r,J,F,vline,vsurf,TL,omega,Te,m,mode,r0, ...
                         F_ref,rc,rmax,Fmax,Jm,Jc,rho,w,h,E,A,L,B)

met = struct();
met.r0 = r0; met.r_end = r(end);
met.r_dir_ok = double(sign(r(end)-r(1)) == mode);
met.J_dir_ok = double(sign(J(end)-J(1)) == mode);

% steady-state window: last 20 %
sel = t >= 0.8*t(end);
met.F_ss = mean(F(sel));
met.F_ss_err_pct = 100*abs(met.F_ss - F_ref)/F_ref;
met.v_match_pct = 100*max(abs(vsurf(sel)-vline(sel))./max(vline(sel),0.1));

% algebraic identities
met.TL_err = max(abs(TL - mode*F.*r));
J_chk = Jm + Jc + 0.5*(rho*w*pi*max(r.^2-rc^2,0)).*(r.^2+rc^2);
met.J_err = max(abs(J - J_chk));

% integral (ODE) consistency, stopping before a radius limit is hit
idx = numel(t);
k = find(r >= rmax-1e-9, 1); if ~isempty(k), idx = min(idx,k-1); end
k = find(r <= rc+1e-9, 1);   if ~isempty(k), idx = min(idx,k-1); end
idx = max(idx,11);

% tension check starts after the start-up transient (avoids the F = 0 clamp)
i0 = find(t >= 3, 1); if isempty(i0), i0 = 1; end
i0 = min(i0, idx-10);

H = J.*omega;
dR_res = (r(idx)-r(1)) - trapz(t(1:idx), mode*h*vline(1:idx)./(2*pi*r(1:idx)));
dH_res = (H(idx)-H(1)) - trapz(t(1:idx), Te(1:idx)-TL(1:idx)-B*omega(1:idx));
dF_res = (F(idx)-F(i0)) - trapz(t(i0:idx), ...
         mode*(E*A/L)*(vsurf(i0:idx)-vline(i0:idx)));

met.r_ode_rel = abs(dR_res)/max(abs(r(idx)-r(1)),1e-9);
met.H_ode_rel = abs(dH_res)/max(abs(H(idx)-H(1)),1e-9);
met.F_ode_rel = abs(dF_res)/max(F_ref,1);

% limits
met.r_min = min(r); met.r_max = max(r);
met.F_min = min(F); met.F_max = max(F);
met.limits_ok = double(met.r_min >= rc-1e-9 && met.r_max <= rmax+1e-9 && ...
                       met.F_min >= -1e-9  && met.F_max <= Fmax+1e-9);

met.Te_min = min(Te); met.Te_max = max(Te);
met.omega_min = min(omega); met.omega_max = max(omega);
end

%% =======================================================================
function plot_case(t,r,J,F,vline,vsurf,TL,omega,F_ref,name,figdir)

fig = figure('Visible','off','Color','w','Position',[80 80 1250 720]);

subplot(2,3,1);
plot(t,r,'b','LineWidth',1.3); grid on;
xlabel('time [s]'); ylabel('r [m]'); title('Roll radius');

subplot(2,3,2);
plot(t,J,'b','LineWidth',1.3); grid on;
xlabel('time [s]'); ylabel('J [kg m^2]'); title('Total inertia (motor + roll)');

subplot(2,3,3);
plot(t,F,'b','LineWidth',1.3); hold on;
yline(F_ref,'k--','F_{ref}');
grid on; xlabel('time [s]'); ylabel('F [N]'); title('Web tension');

subplot(2,3,4);
plot(t,vsurf,'b','LineWidth',1.2); hold on;
plot(t,vline,'k--','LineWidth',1.9);
grid on; xlabel('time [s]'); ylabel('speed [m/s]');
legend({'\omega r','v_{line}'},'Location','southeast');
title('Line speed vs roll surface speed');

subplot(2,3,5);
plot(t,TL,'b','LineWidth',1.3); grid on;
xlabel('time [s]'); ylabel('T_{web} [N m]'); title('Web load torque on the shaft');

subplot(2,3,6);
plot(t,omega,'b','LineWidth',1.3); grid on;
xlabel('time [s]'); ylabel('\omega [rad/s]'); title('Roll speed');

sgtitle(sprintf('Winder mechanics validation: %s',name));
save_figure(fig, ['fig_' name '_validation'], figdir);
close(fig);
end

%% =======================================================================
function print_metrics(name,met)
fprintf('  r: %.4f -> %.4f m   (direction ok: %d)\n', met.r0, met.r_end, met.r_dir_ok);
fprintf('  J direction ok: %d   J identity error: %.2e kg m^2\n', met.J_dir_ok, met.J_err);
fprintf('  F_ss: %.3f N   error: %.2f %%   speed-match error: %.3f %%\n', ...
    met.F_ss, met.F_ss_err_pct, met.v_match_pct);
fprintf('  TL identity error: %.2e N m\n', met.TL_err);
fprintf('  ODE residuals (relative): r %.2e | H %.2e | F %.2e\n', ...
    met.r_ode_rel, met.H_ode_rel, met.F_ode_rel);
fprintf('  limits: r in [%.4f, %.4f], F in [%.2f, %.2f]  (ok: %d)\n', ...
    met.r_min, met.r_max, met.F_min, met.F_max, met.limits_ok);
fprintf('  Te range: [%.2f, %.2f] N m   omega range: [%.2f, %.2f] rad/s\n', ...
    met.Te_min, met.Te_max, met.omega_min, met.omega_max);
end

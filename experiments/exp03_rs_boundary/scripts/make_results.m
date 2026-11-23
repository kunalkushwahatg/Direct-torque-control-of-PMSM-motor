% MAKE_RESULTS (exp03): Rs stability boundary. Combines the exp03 sweep with the matching exp02 cases (70, 100, 130 %).
% Tests the prediction  d(err)/dt = ((Rs_est - Rs)/L) * err + ...   i.e. growth rate k = (factor-1)*Rs/L  for factor > 1.
exp_root = fileparts(fileparts(mfilename('fullpath'))); rdir = fullfile(exp_root,'results'); fdir = fullfile(exp_root,'figures');
exp2 = fullfile(fileparts(exp_root),'exp02_robustness','results');
Rs = 2.875; L = 8.5e-3; ctl = {'svm','cl'}; ctlname = {'SVM-DTC','Classical DTC'}; speeds = [20 5]; fac = [70 80 90 100 105 110 120 130];
loadr = @(c,w,f) loadcase(rdir,exp2,c,w,f);

%% collect
n = 0; rows = {}; D = struct();
for c = 1:2, for w = speeds, for f = fac
    r = loadr(ctl{c},w,f); if isempty(r), continue; end
    s = r.ss; err = abs(r.sig.lam - r.sig.lam_true); t = r.sig.t;
    sm = movmean(err, 200);                                   % 2 ms smoothing at 100 kHz
    i0 = find(sm > 2e-3, 1); i1 = find(sm > 3e-2, 1);
    t_fail = NaN; k_meas = NaN; if ~isempty(i1), t_fail = t(i1); end
    if ~isempty(i0) && ~isempty(i1) && i1 - i0 > 200
        pf = polyfit(t(i0:i1), log(sm(i0:i1)), 1); k_meas = pf(1);
    end
    k_pred = (f/100 - 1) * Rs / L;
    n = n + 1; rows(n,:) = {sprintf('%s_w%d_rs%03d',ctl{c},w,f), ctlname{c}, w, f, s.lam_true_mean, s.lam_true_min, s.flux_err_rms, s.speed_err_rms, s.Te_true_rms, s.lost_control, t_fail, k_meas, k_pred}; %#ok<SAGROW>
    D.(sprintf('%s_w%d_rs%03d',ctl{c},w,f)) = r;
end, end, end
T = cell2table(rows,'VariableNames',{'tag','controller','speed_ref','Rs_pct','lam_true_mean','lam_true_min','flux_err_rms','speed_err_rms','Te_true_rms','lost_control','t_fail_s','growth_rate_meas','growth_rate_pred'});
writetable(T, fullfile(rdir,'metrics_summary.csv'));

%% print
fprintf('\n=== OUTCOME vs ASSUMED Rs (true flux ideal 0.175 Wb; L = lost control) ===\n');
for w = speeds
    fprintf('\nSpeed %d rad/s\n%-8s |', w, 'Rs %'); fprintf(' %-18s |', ctlname{:}); fprintf('\n');
    for f = fac
        out = cell(1,2);
        for c = 1:2, k = find(strcmp(T.tag, sprintf('%s_w%d_rs%03d',ctl{c},w,f)),1);
            if isempty(k), out{c} = '(missing)'; elseif T.lost_control(k), out{c} = sprintf('LOST (t=%.0f ms)',1e3*T.t_fail_s(k)); else, out{c} = sprintf('ok, flux %.3f',T.lam_true_mean(k)); end
        end
        fprintf('%-8d | %-18s | %-18s |\n', f, out{1}, out{2});
    end
end
fprintf('\n=== GROWTH RATE of the flux error (unstable cases): measured vs predicted k = (f-1)*Rs/L [1/s] ===\n');
for i = 1:height(T), if T.Rs_pct(i) > 100 && ~isnan(T.growth_rate_meas(i))
    fprintf('%-18s measured %7.1f   predicted %7.1f\n', T.tag{i}, T.growth_rate_meas(i), T.growth_rate_pred(i)); end, end

%% figures
cc = {[0 0.447 0.741],[0.85 0.33 0.10]}; mk = @(h) figure('Visible','off','Position',[100 100 1100 h],'Color','w');
f1 = mk(520);                                               % fig01: true flux vs assumed Rs
for si = 1:2, subplot(1,2,si); hold on; w = speeds(si);
    for c = 1:2
        k = T.speed_ref == w & strcmp(T.controller, ctlname{c}); x = T.Rs_pct(k); y = T.lam_true_mean(k); lost = T.lost_control(k) == 1;
        [x,o] = sort(x); y = y(o); lost = lost(o); plot(x(~lost), y(~lost), '-o', 'Color', cc{c}, 'LineWidth', 1.3, 'MarkerFaceColor', cc{c});
        plot(x(lost), min(y(lost),0.6), 'x', 'Color', cc{c}, 'MarkerSize', 10, 'LineWidth', 2);
    end
    yline(0.175,'k--'); grid on; xlabel('Rs assumed by the estimator [% of true]'); ylabel('true flux [Wb]'); ylim([0 0.6]); title(sprintf('%d rad/s  (x = control lost)', w));
    if si == 1, legend('SVM-DTC','','Classical DTC','','ideal 0.175 Wb','Location','north'); end
end
save_figure(f1,'fig01_true_flux_vs_assumed_Rs',fdir); close(f1);

f2 = mk(520);                                               % fig02: growth rate measured vs predicted
hold on; for c = 1:2
    k = strcmp(T.controller, ctlname{c}) & T.Rs_pct > 100 & ~isnan(T.growth_rate_meas); plot(T.growth_rate_pred(k), T.growth_rate_meas(k), 'o', 'Color', cc{c}, 'MarkerFaceColor', cc{c}, 'MarkerSize', 7);
end
lim = [0 max([T.growth_rate_pred; 1])]; plot(lim, lim, 'k--'); grid on; xlabel('predicted growth rate (Rs_{est} - Rs)/L  [1/s]'); ylabel('measured growth rate of flux error [1/s]');
legend('SVM-DTC','Classical DTC','prediction','Location','northwest'); title('Does the simple model explain the instability?');
save_figure(f2,'fig02_growth_rate_measured_vs_predicted',fdir); close(f2);

f3 = mk(620); w = 20;                                       % fig03: flux error on a log axis (straight line = exponential growth)
for c = 1:2, subplot(1,2,c); hold on;
    for f = [105 110 120 130], key = sprintf('%s_w%d_rs%03d',ctl{c},w,f); if ~isfield(D,key), continue; end
        r = D.(key); semilogy(r.sig.t, movmean(abs(r.sig.lam - r.sig.lam_true), 200) + 1e-6, 'LineWidth', 1.1);
    end
    set(gca,'YScale','log'); grid on; xlabel('t [s]'); ylabel('|estimated - true flux| [Wb]'); title(sprintf('%s, %d rad/s', ctlname{c}, w)); legend('Rs 105 %','110 %','120 %','130 %','Location','southeast'); ylim([1e-5 20]);
end
save_figure(f3,'fig03_flux_error_growth_log',fdir); close(f3);
fprintf('\nSaved 3 figures to %s and %d rows to results/metrics_summary.csv\n', fdir, height(T));

function r = loadcase(rdir,exp2,c,w,f)
    if w == 20, nm2 = sprintf('%s_mid_rs%03d',c,f); else, nm2 = sprintf('%s_low_w%d_rs%03d',c,w,f); end
    p1 = fullfile(rdir,sprintf('result_%s_w%d_rs%03d.mat',c,w,f)); p2 = fullfile(exp2,['result_' nm2 '.mat']);
    r = []; if exist(p1,'file'), r = load(p1,'r').r; elseif exist(p2,'file'), r = load(p2,'r').r; end
end

% Prints the comparison tables and draws the figures from result_*.mat
exp_root = fileparts(fileparts(mfilename('fullpath')));
R = @(tag) load(fullfile(exp_root,'results',['result_' tag '.mat']));
S = R('svm_dyn').r; C = R('cl_dyn').r;
fprintf('\n=== DYNAMIC TEST (loaded window 0.7-1.0 s, %g N.m) ===\n', S.case.TL);
fprintf('%-34s %14s %14s\n','Metric','Classical DTC','SVM-DTC');
row = @(n,a,b,f) fprintf('%-34s %14s %14s\n', n, sprintf(f,a), sprintf(f,b));
for wn = {'light','load'}
    s = S.(wn{1}); c = C.(wn{1}); fprintf('-- %s window\n', wn{1});
    row('Torque ripple RMS, true [N.m]',   c.Te_true_rms, s.Te_true_rms, '%.4f');
    row('Torque ripple RMS, true [%]',     c.Te_true_pct, s.Te_true_pct, '%.2f');
    row('Torque ripple pk-pk, true [N.m]', c.Te_true_pk2pk,s.Te_true_pk2pk,'%.3f');
    row('Torque ripple RMS, est [N.m]',    c.Te_est_rms,  s.Te_est_rms,  '%.4f');
    row('Flux ripple pk-pk [Wb]',          c.lam_pk2pk,   s.lam_pk2pk,   '%.4f');
    row('Current THD to 20 kHz [%]',       c.THD_20k,     s.THD_20k,     '%.2f');
    row('Avg switching freq [Hz]',         c.fsw_avg,     s.fsw_avg,     '%.0f');
end
fprintf('-- dynamic\n');
row('Speed overshoot [%]',      C.dynamic.speed_overshoot_pct, S.dynamic.speed_overshoot_pct,'%.2f');
row('Speed settling 1% [ms]',   C.dynamic.speed_settling_ms,   S.dynamic.speed_settling_ms,  '%.1f');
row('Speed dip at load [rad/s]',C.dynamic.load_speed_dip,      S.dynamic.load_speed_dip,     '%.3f');
row('Recovery after load [ms]', C.dynamic.load_recovery_ms,    S.dynamic.load_recovery_ms,   '%.1f');
row('Torque rise 10-90% [ms]',  C.dynamic.torque_rise_ms,      S.dynamic.torque_rise_ms,     '%.2f');

fprintf('\n=== OPERATING-POINT SWEEP (true torque ripple RMS [N.m] / THD20k [%%] / flux ripple pk-pk [mWb]) ===\n');
fprintf('%-8s %-8s | %-26s | %-26s\n','w[rad/s]','TL[N.m]','Classical DTC','SVM-DTC');
for w = [10 30 60]
  for TL = [0.5 4]
    c = R(sprintf('cl_w%d_T%g',w,TL)).r.ss; s = R(sprintf('svm_w%d_T%g',w,TL)).r.ss;
    fprintf('%-8d %-8g | %7.4f / %6.2f / %5.2f | %7.4f / %6.2f / %5.2f\n', w, TL, ...
        c.Te_true_rms, c.THD_20k, 1e3*c.lam_pk2pk, s.Te_true_rms, s.THD_20k, 1e3*s.lam_pk2pk);
  end
end

figure('Name','Dynamic comparison','Position',[50 50 1200 800]);
subplot(3,1,1); plot(C.sig.t, C.sig.Te_true, S.sig.t, S.sig.Te_true); grid on; ylabel('T_e true [N.m]'); legend('Classical DTC','SVM-DTC'); title('Torque (reconstructed from currents)');
subplot(3,1,2); plot(C.sig.t, C.sig.w, S.sig.t, S.sig.w); grid on; ylabel('\omega [rad/s]'); title('Speed');
subplot(3,1,3); plot(C.sig.t, C.sig.lam, S.sig.t, S.sig.lam); grid on; ylabel('|\lambda_s| [Wb]'); xlabel('t [s]'); title('Stator flux magnitude');
save_figure(gcf,'fig_dynamic_quick',fullfile(exp_root,'figures'));

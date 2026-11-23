% MAKE_RESULTS  One script for everything produced from results/result_*.mat:
%   1) comparison tables printed to the command window
%   2) 9 figures (PNG 300 dpi + vector PDF + .fig) in figures/
%   3) results/metrics_summary.csv with the key metrics of every run
% Requires setup_paths (adds tools/save_figure.m to the path).
exp_root = fileparts(fileparts(mfilename('fullpath')));
rdir = fullfile(exp_root,'results'); fdir = fullfile(exp_root,'figures');

%% load every result once
files = dir(fullfile(rdir,'result_*.mat')); R = struct();
for i = 1:numel(files)
    tmp = load(fullfile(rdir,files(i).name),'r');
    R.(matlab.lang.makeValidName(erase(erase(files(i).name,'result_'),'.mat'))) = tmp.r;
end
get = @(tag) R.(matlab.lang.makeValidName(tag));
C = get('cl_dyn'); S = get('svm_dyn');
speeds = [10 30 60]; loads = [0.5 4];

%% 1) tables
fprintf('\n=== DYNAMIC TEST (windows: light 0.3-0.5 s, loaded 0.7-1.0 s at %g N.m) ===\n', S.case.TL);
fprintf('%-34s %14s %14s\n','Metric','Classical DTC','SVM-DTC');
row = @(n,a,b,f) fprintf('%-34s %14s %14s\n', n, sprintf(f,a), sprintf(f,b));
for wn = {'light','load'}
    c = C.(wn{1}); s = S.(wn{1}); fprintf('-- %s window\n', wn{1});
    row('Torque ripple RMS, true [N.m]',   c.Te_true_rms,  s.Te_true_rms,  '%.4f');
    row('Torque ripple RMS, true [%]',     c.Te_true_pct,  s.Te_true_pct,  '%.2f');
    row('Torque ripple pk-pk, true [N.m]', c.Te_true_pk2pk,s.Te_true_pk2pk,'%.3f');
    row('Torque ripple RMS, est [N.m]',    c.Te_est_rms,   s.Te_est_rms,   '%.4f');
    row('Flux ripple pk-pk [Wb]',          c.lam_pk2pk,    s.lam_pk2pk,    '%.4f');
    row('Current THD to 20 kHz [%]',       c.THD_20k,      s.THD_20k,      '%.2f');
    row('Avg switching freq [Hz]',         c.fsw_avg,      s.fsw_avg,      '%.0f');
end
fprintf('-- dynamic\n');
dc = C.dynamic; ds = S.dynamic;
row('Speed overshoot [%]',       dc.speed_overshoot_pct, ds.speed_overshoot_pct, '%.2f');
row('Speed settling 1% [ms]',    dc.speed_settling_ms,   ds.speed_settling_ms,   '%.1f');
row('Speed dip at load [rad/s]', dc.load_speed_dip,      ds.load_speed_dip,      '%.3f');
row('Recovery after load [ms]',  dc.load_recovery_ms,    ds.load_recovery_ms,    '%.1f');
row('Torque rise 10-90% [ms]',   dc.torque_rise_ms,      ds.torque_rise_ms,      '%.2f');

fprintf('\n=== SWEEP: true torque ripple RMS [N.m] / THD20k [%%] / flux ripple pk-pk [mWb] ===\n');
fprintf('%-8s %-8s | %-26s | %-26s\n','w[rad/s]','TL[N.m]','Classical DTC','SVM-DTC');
lab = {}; Cm = []; Sm = [];
for w = speeds, for TL = loads
    c = get(sprintf('cl_w%d_T%g',w,TL)).ss; s = get(sprintf('svm_w%d_T%g',w,TL)).ss;
    fprintf('%-8d %-8g | %7.4f / %6.2f / %5.2f | %7.4f / %6.2f / %5.2f\n', w, TL, ...
        c.Te_true_rms, c.THD_20k, 1e3*c.lam_pk2pk, s.Te_true_rms, s.THD_20k, 1e3*s.lam_pk2pk);
    lab{end+1} = sprintf('%d rad/s, %g N\\cdotm',w,TL); %#ok<SAGROW>
    Cm(end+1,:) = [c.Te_true_rms, c.THD_20k, 1e3*c.lam_pk2pk, c.fsw_avg]; %#ok<SAGROW>
    Sm(end+1,:) = [s.Te_true_rms, s.THD_20k, 1e3*s.lam_pk2pk, s.fsw_avg]; %#ok<SAGROW>
end, end

%% 2) figures
cC = [0.85 0.33 0.10]; cS = [0.00 0.447 0.741];   % classical = orange, SVM-DTC = blue
lg = {'Classical DTC','SVM-DTC'}; D = {C,S}; col = {cC,cS};
newfig = @() figure('Visible','off','Position',[100 100 1100 750],'Color','w');
seg  = @(d,w) d.sig.t >= w(1) & d.sig.t <= w(2);
pair = @(d,fld,w,lw) cellfun(@(dd,cc) plot(dd.sig.t(seg(dd,w)),dd.sig.(fld)(seg(dd,w)),'Color',cc,'LineWidth',lw), d, col, 'UniformOutput', false);

f = newfig(); full = [0 inf];                                                       % fig01 overview
subplot(3,1,1); hold on; pair(D,'Te_true',full,0.6); grid on; ylabel('T_e [N\cdotm]'); legend(lg,'Location','northwest'); title('Torque (reconstructed from measured currents)');
subplot(3,1,2); hold on; pair(D,'w',full,1.2);       grid on; ylabel('\omega [rad/s]'); title('Speed');
subplot(3,1,3); hold on; pair(D,'lam',full,0.6);     grid on; ylabel('|\lambda_s| [Wb]'); xlabel('t [s]'); title('Stator flux magnitude');
save_figure(f,'fig01_dynamic_overview',fdir); close(f);

f = newfig();                                                                       % fig02 steady torque zoom
for k = 1:2
    subplot(2,1,k); plot(D{k}.sig.t(seg(D{k},[0.80 0.86])),D{k}.sig.Te_true(seg(D{k},[0.80 0.86])),'Color',col{k},'LineWidth',0.8); grid on; ylim([0.8 3.4]);
    ylabel('T_e [N\cdotm]'); title(sprintf('%s, loaded 2 N\\cdotm (RMS ripple %.3f N\\cdotm)',lg{k},D{k}.load.Te_true_rms));
end
xlabel('t [s]'); save_figure(f,'fig02_torque_steady_zoom',fdir); close(f);

f = newfig(); w = [0.45 0.65];                                                      % fig03 load step
subplot(2,1,1); hold on; pair(D,'w',w,1.4);       grid on; ylabel('\omega [rad/s]'); title('Load step 0.5 \rightarrow 2 N\cdotm at 0.5 s'); legend(lg);
subplot(2,1,2); hold on; pair(D,'Te_true',w,0.6); grid on; ylabel('T_e [N\cdotm]'); xlabel('t [s]');
save_figure(f,'fig03_load_step_response',fdir); close(f);

f = newfig();                                                                       % fig04 current waveform
for k = 1:2
    subplot(2,1,k); plot(D{k}.sig.t(seg(D{k},[0.80 0.90])),D{k}.sig.ia(seg(D{k},[0.80 0.90])),'Color',col{k},'LineWidth',0.7); grid on; ylabel('i_a [A]'); title(lg{k});
end
xlabel('t [s]'); save_figure(f,'fig04_current_waveform',fdir); close(f);

f = newfig(); hold on; Fs = 1/(C.sig.t(2)-C.sig.t(1));                              % fig05 current spectrum
for k = 1:2
    x = D{k}.sig.ia(seg(D{k},[0.7 1.0])); x = x - mean(x); N = numel(x); h = hann(N);
    Y = abs(fft(x.*h))/(sum(h)/2); fr = (0:N-1)'*Fs/N; s = fr > 1 & fr <= 20e3;
    plot(fr(s),Y(s)+1e-7,'Color',col{k},'LineWidth',0.7);
end
set(gca,'YScale','log'); grid on; xlabel('f [Hz]'); ylabel('|I_a| [A]'); legend(lg); title('Phase-A current spectrum, loaded (0.7-1.0 s)');
save_figure(f,'fig05_current_spectrum',fdir); close(f);

yl = {'True torque ripple RMS [N\cdotm]','Current THD to 20 kHz [%]','Flux ripple pk-pk [mWb]','Average switching frequency [Hz]'};
nm = {'fig06_sweep_torque_ripple','fig07_sweep_current_thd','fig08_sweep_flux_ripple','fig09_sweep_switching_frequency'};
for m = 1:4                                                                         % fig06-09 sweep bars
    f = newfig(); b = bar([Cm(:,m) Sm(:,m)]); b(1).FaceColor = cC; b(2).FaceColor = cS;
    set(gca,'XTickLabel',lab,'XTickLabelRotation',20); grid on; ylabel(yl{m}); legend(lg,'Location','northwest'); title('Operating-point sweep');
    save_figure(f,nm{m},fdir); close(f);
end

%% 3) summary table (all runs)
rows = {}; tags = sort(fieldnames(R));
for i = 1:numel(tags)
    r = R.(tags{i}); wins = setdiff(fieldnames(r),{'cfg','t','sig','case','dynamic'});
    for j = 1:numel(wins), s = r.(wins{j});
        rows(end+1,:) = {r.case.tag, r.case.model, r.case.w, r.case.TL, r.case.Ts_dtc, wins{j}, s.Te_true_mean, s.Te_true_rms, s.Te_true_pk2pk, s.Te_est_rms, ...
            s.lam_mean, s.lam_pk2pk, s.lam_rms, s.THD_20k, s.THD_50th, s.fsw_avg, s.speed_mean, s.n_cycles}; %#ok<SAGROW>
    end
end
T = cell2table(rows,'VariableNames',{'tag','model','speed_rad_s','load_Nm','Ts_dtc_s','window','Te_true_mean','Te_true_rms','Te_true_pk2pk','Te_est_rms', ...
    'lam_mean','lam_pk2pk','lam_rms','THD_20k_pct','THD_50th_pct','fsw_avg_Hz','speed_mean','n_cycles'});
writetable(T,fullfile(rdir,'metrics_summary.csv'));
fprintf('\nSaved 9 figures to %s and %d rows to results/metrics_summary.csv\n', fdir, height(T));

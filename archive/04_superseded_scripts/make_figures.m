% Generates every figure and the summary table for experiment 01 from results/result_*.mat
% Outputs (PNG 300 dpi + vector PDF + editable .fig) go to figures/, table to results/metrics_summary.csv
exp_root = fileparts(fileparts(mfilename('fullpath')));
rdir = fullfile(exp_root,'results'); fdir = fullfile(exp_root,'figures');
Rr = @(tag) getfield(load(fullfile(rdir,['result_' tag '.mat'])),'r');
C = Rr('cl_dyn'); S = Rr('svm_dyn');
cC = [0.85 0.33 0.10]; cS = [0.00 0.447 0.741];           % classical = orange, SVM-DTC = blue
mk = @() figure('Visible','off','Position',[100 100 1100 750],'Color','w');
lg = {'Classical DTC','SVM-DTC'};

%% fig01 - dynamic overview
f = mk();
subplot(3,1,1); plot(C.sig.t,C.sig.Te_true,'Color',cC,'LineWidth',0.6); hold on; plot(S.sig.t,S.sig.Te_true,'Color',cS,'LineWidth',0.6); grid on;
ylabel('T_e [N\cdotm]'); legend(lg,'Location','northwest'); title('Torque (reconstructed from measured currents)');
subplot(3,1,2); plot(C.sig.t,C.sig.w,'Color',cC,'LineWidth',1.2); hold on; plot(S.sig.t,S.sig.w,'Color',cS,'LineWidth',1.2); grid on; ylabel('\omega [rad/s]'); title('Speed');
subplot(3,1,3); plot(C.sig.t,C.sig.lam,'Color',cC,'LineWidth',0.6); hold on; plot(S.sig.t,S.sig.lam,'Color',cS,'LineWidth',0.6); grid on; ylabel('|\lambda_s| [Wb]'); xlabel('t [s]'); title('Stator flux magnitude');
save_figure(f,'fig01_dynamic_overview',fdir); close(f);

%% fig02 - steady-state torque zoom (loaded)
f = mk(); w = [0.80 0.86];
for k = 1:2
    D = {C,S}; col = {cC,cS}; subplot(2,1,k);
    i = D{k}.sig.t >= w(1) & D{k}.sig.t <= w(2); plot(D{k}.sig.t(i),D{k}.sig.Te_true(i),'Color',col{k},'LineWidth',0.8); grid on;
    ylim([0.8 3.4]); ylabel('T_e [N\cdotm]'); title(sprintf('%s, loaded 2 N\\cdotm (RMS ripple %.3f N\\cdotm)',lg{k},D{k}.load.Te_true_rms));
end
xlabel('t [s]'); save_figure(f,'fig02_torque_steady_zoom',fdir); close(f);

%% fig03 - load-step response
f = mk(); w = [0.45 0.65];
subplot(2,1,1); hold on; subplot(2,1,2); hold on;
for k = 1:2
    D = {C,S}; col = {cC,cS}; i = D{k}.sig.t >= w(1) & D{k}.sig.t <= w(2);
    subplot(2,1,1); plot(D{k}.sig.t(i),D{k}.sig.w(i),'Color',col{k},'LineWidth',1.4);
    subplot(2,1,2); plot(D{k}.sig.t(i),D{k}.sig.Te_true(i),'Color',col{k},'LineWidth',0.6);
end
subplot(2,1,1); grid on; ylabel('\omega [rad/s]'); title('Load step 0.5 \rightarrow 2 N\cdotm at 0.5 s'); legend(lg);
subplot(2,1,2); grid on; ylabel('T_e [N\cdotm]'); xlabel('t [s]');
save_figure(f,'fig03_load_step_response',fdir); close(f);

%% fig04 - phase-A current waveform
f = mk(); w = [0.80 0.90];
for k = 1:2
    D = {C,S}; col = {cC,cS}; subplot(2,1,k); i = D{k}.sig.t >= w(1) & D{k}.sig.t <= w(2);
    plot(D{k}.sig.t(i),D{k}.sig.ia(i),'Color',col{k},'LineWidth',0.7); grid on; ylabel('i_a [A]'); title(lg{k});
end
xlabel('t [s]'); save_figure(f,'fig04_current_waveform',fdir); close(f);

%% fig05 - current spectrum (loaded window)
f = mk(); Fs = 1/(C.sig.t(2)-C.sig.t(1)); hold on;
for k = 1:2
    D = {C,S}; col = {cC,cS}; i = D{k}.sig.t >= 0.7 & D{k}.sig.t <= 1.0; x = D{k}.sig.ia(i) - mean(D{k}.sig.ia(i)); N = numel(x);
    h = hann(N); Y = abs(fft(x.*h))/(sum(h)/2); fr = (0:N-1)'*Fs/N; s = fr <= 20e3 & fr > 1;
    semilogy(fr(s),Y(s)+1e-7,'Color',col{k},'LineWidth',0.7);
end
set(gca,'YScale','log'); grid on; xlabel('f [Hz]'); ylabel('|I_a| [A]'); legend(lg); title('Phase-A current spectrum, loaded (0.7-1.0 s)');
save_figure(f,'fig05_current_spectrum',fdir); close(f);

%% sweep figures
speeds = [10 30 60]; loads = [0.5 4]; lab = {}; Cm = []; Sm = [];
for w = speeds, for TL = loads
    c = Rr(sprintf('cl_w%d_T%g',w,TL)).ss; s = Rr(sprintf('svm_w%d_T%g',w,TL)).ss;
    lab{end+1} = sprintf('%d rad/s, %g N\\cdotm',w,TL); %#ok<SAGROW>
    Cm(end+1,:) = [c.Te_true_rms, c.THD_20k, 1e3*c.lam_pk2pk, c.fsw_avg]; %#ok<SAGROW>
    Sm(end+1,:) = [s.Te_true_rms, s.THD_20k, 1e3*s.lam_pk2pk, s.fsw_avg]; %#ok<SAGROW>
end, end
yl = {'True torque ripple RMS [N\cdotm]','Current THD to 20 kHz [%]','Flux ripple pk-pk [mWb]','Average switching frequency [Hz]'};
nm = {'fig06_sweep_torque_ripple','fig07_sweep_current_thd','fig08_sweep_flux_ripple','fig09_sweep_switching_frequency'};
for m = 1:4
    f = mk(); b = bar([Cm(:,m) Sm(:,m)]); b(1).FaceColor = cC; b(2).FaceColor = cS;
    set(gca,'XTickLabel',lab,'XTickLabelRotation',20); grid on; ylabel(yl{m}); legend(lg,'Location','northwest'); title('Operating-point sweep');
    save_figure(f,nm{m},fdir); close(f);
end

%% summary table (all results)
files = dir(fullfile(rdir,'result_*.mat')); rows = {};
for i = 1:numel(files)
    r = load(fullfile(rdir,files(i).name)).r; wins = setdiff(fieldnames(r),{'cfg','t','sig','case','dynamic'});
    for j = 1:numel(wins), s = r.(wins{j});
        rows(end+1,:) = {r.case.tag, r.case.model, r.case.w, r.case.TL, r.case.Ts_dtc, wins{j}, s.Te_true_mean, s.Te_true_rms, s.Te_true_pk2pk, s.Te_est_rms, ...
            s.lam_mean, s.lam_pk2pk, s.lam_rms, s.THD_20k, s.THD_50th, s.fsw_avg, s.speed_mean, s.n_cycles}; %#ok<SAGROW>
    end
end
T = cell2table(rows,'VariableNames',{'tag','model','speed_rad_s','load_Nm','Ts_dtc_s','window','Te_true_mean','Te_true_rms','Te_true_pk2pk','Te_est_rms', ...
    'lam_mean','lam_pk2pk','lam_rms','THD_20k_pct','THD_50th_pct','fsw_avg_Hz','speed_mean','n_cycles'});
writetable(sortrows(T,'tag'),fullfile(rdir,'metrics_summary.csv'));
fprintf('Saved %d figures to %s and %d table rows to results/metrics_summary.csv\n',9,fdir,height(T));

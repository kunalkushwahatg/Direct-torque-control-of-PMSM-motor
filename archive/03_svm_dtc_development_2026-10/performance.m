%% DTC / SVM-DTC PERFORMANCE METRICS  (same script works for both controllers)
% Run the model first. Needs these To-Workspace variables (timeseries):
%   out.Ts_data  - estimated torque Te        out.ia_data  - phase-A current
%   out.Sa_data  - phase-A high-side gate     out.w_data   - mechanical speed
%   out.lam_data - stator flux magnitude
% (old version kept as performance_old.m)

%% --- Test conditions (edit to match your run) ---
cfg.p          = 4;        % pole pairs
cfg.w_ref      = 20;       % final speed reference [rad/s]
cfg.ramp_time  = 0.05;     % speed reference starts at this time [s]
cfg.load_time  = 0.5;      % load torque step time [s]
cfg.win_light  = [0.30 0.50];   % steady window BEFORE load step  (light load)
cfg.win_load   = [0.70 1.00];   % steady window AFTER  load step  (loaded)
cfg.band_speed = 0.01;     % speed settling band (1 %)
cfg.dt         = 1e-5;     % common analysis grid (100 kHz)
cfg.thd_fmax   = 20e3;     % THD bandwidth [Hz]

%% --- Extract and resample to a uniform grid ---
Te_ts = out.Ts_data;  ia_ts = out.ia_data;  w_ts = out.w_data;
lam_ts = out.lam_data; Sa_ts = out.Sa_data;
t  = (0:cfg.dt:min([Te_ts.Time(end), ia_ts.Time(end), w_ts.Time(end)]))';
rs = @(ts) interp1(ts.Time, squeeze(ts.Data), t, 'linear', 'extrap');
Te = rs(Te_ts); ia = rs(ia_ts); w = rs(w_ts); lam = rs(lam_ts);
Fs = 1/cfg.dt;

metrics = struct();
names = {'light','load'};  wins = {cfg.win_light, cfg.win_load};

%% --- Steady-state metrics per window ---
for k = 1:2
    idx = t >= wins{k}(1) & t <= wins{k}(2);
    Tk = Te(idx); Lk = lam(idx);
    res.Te_mean        = mean(Tk);
    res.Te_pk2pk       = max(Tk) - min(Tk);
    res.Te_rms_ripple  = sqrt(mean((Tk - mean(Tk)).^2));
    res.Te_ripple_pct  = 100 * res.Te_rms_ripple / abs(res.Te_mean);
    res.lam_mean       = mean(Lk);
    res.lam_pk2pk      = max(Lk) - min(Lk);
    res.lam_rms_ripple = sqrt(mean((Lk - mean(Lk)).^2));
    [res.THD_20k, res.THD_50th, res.n_cycles, res.f_elec] = current_thd(t(idx), ia(idx), Fs, cfg.thd_fmax);
    % average switching frequency from the RAW gate signal (phase-A transitions)
    sa_t = Sa_ts.Time; sa = squeeze(Sa_ts.Data) > 0.5;
    si = sa_t >= wins{k}(1) & sa_t <= wins{k}(2);
    res.fsw_avg = sum(abs(diff(sa(si)))) / (2 * (wins{k}(2) - wins{k}(1)));
    metrics.(names{k}) = res;
end

%% --- Dynamic metrics ---
% speed response to the reference
sp = t >= cfg.ramp_time & t < cfg.load_time;
dy.speed_overshoot_pct = 100 * max(0, max(w(sp)) - cfg.w_ref) / cfg.w_ref;
out_band = abs(w - cfg.w_ref) > cfg.band_speed * cfg.w_ref;
last = find(out_band & sp, 1, 'last');
dy.speed_settling_ms = 1e3 * (t(last) - cfg.ramp_time);
% speed reaction to the load step
ld = t >= cfg.load_time & t <= cfg.load_time + 0.3;
dy.load_speed_dip = cfg.w_ref - min(w(ld));
last = find(out_band & t >= cfg.load_time, 1, 'last');
dy.load_recovery_ms = 1e3 * (t(last) - cfg.load_time);
% torque rise time to the load step (10-90 %, 1 ms smoothing)
Tsm = movmean(Te, round(1e-3 / cfg.dt));
T0 = mean(Te(t >= cfg.load_time - 0.05 & t < cfg.load_time - 0.005));
T1 = metrics.load.Te_mean;
seg = t >= cfg.load_time; ts = t(seg); Ts_ = Tsm(seg);
i10 = find(Ts_ >= T0 + 0.1*(T1-T0), 1, 'first');
i90 = find(Ts_ >= T0 + 0.9*(T1-T0), 1, 'first');
dy.torque_rise_ms = 1e3 * (ts(i90) - ts(i10));
metrics.dynamic = dy;

%% --- Print ---
clc;
fprintf('================ CONTROLLER METRICS ================\n');
fprintf('%-28s %14s %14s\n', 'Steady state', 'Light load', 'Loaded');
L = metrics.light; H = metrics.load;
pr = @(n,a,b,f) fprintf('%-28s %14s %14s\n', n, sprintf(f,a), sprintf(f,b));
pr('Torque mean [N.m]',        L.Te_mean,       H.Te_mean,       '%.3f');
pr('Torque ripple pk-pk [N.m]',L.Te_pk2pk,      H.Te_pk2pk,      '%.3f');
pr('Torque ripple RMS [N.m]',  L.Te_rms_ripple, H.Te_rms_ripple, '%.4f');
pr('Torque ripple RMS [%]',    L.Te_ripple_pct, H.Te_ripple_pct, '%.2f');
pr('Flux mean [Wb]',           L.lam_mean,      H.lam_mean,      '%.4f');
pr('Flux ripple pk-pk [Wb]',   L.lam_pk2pk,     H.lam_pk2pk,     '%.4f');
pr('Flux ripple RMS [Wb]',     L.lam_rms_ripple,H.lam_rms_ripple,'%.5f');
pr('Current THD to 20 kHz [%]',L.THD_20k,       H.THD_20k,       '%.2f');
pr('Current THD to 50th [%]',  L.THD_50th,      H.THD_50th,      '%.2f');
pr('Avg switching freq [Hz]',  L.fsw_avg,       H.fsw_avg,       '%.0f');
pr('Electrical freq [Hz]',     L.f_elec,        H.f_elec,        '%.2f');
fprintf('\nDynamic response\n');
fprintf('  Speed overshoot            : %.2f %%\n',  dy.speed_overshoot_pct);
fprintf('  Speed settling (%g%% band)  : %.1f ms\n', 100*cfg.band_speed, dy.speed_settling_ms);
fprintf('  Speed dip at load step     : %.3f rad/s\n', dy.load_speed_dip);
fprintf('  Speed recovery after load  : %.1f ms\n',  dy.load_recovery_ms);
fprintf('  Torque rise time (10-90%%)  : %.2f ms\n', dy.torque_rise_ms);
fprintf('====================================================\n');
save('metrics.mat', 'metrics', 'cfg');

%% --- Figure for the paper ---
figure('Name','Metrics','Position',[100 100 1100 800]);
subplot(2,2,1); plot(t, Te, t, Tsm, 'LineWidth', 1); grid on; xlabel('t [s]'); ylabel('T_e [N.m]'); title('Torque (raw and 1 ms mean)');
subplot(2,2,2); plot(t, w, 'LineWidth', 1.2); grid on; xlabel('t [s]'); ylabel('\omega [rad/s]'); title('Speed');
subplot(2,2,3); plot(t, lam, 'LineWidth', 1); grid on; xlabel('t [s]'); ylabel('|\lambda_s| [Wb]'); title('Stator flux magnitude');
subplot(2,2,4);
idx = t >= cfg.win_load(1) & t <= cfg.win_load(2);
x = ia(idx) - mean(ia(idx)); N = numel(x); Y = abs(fft(x .* hann(N))) / (sum(hann(N)) / 2);
f = (0:N-1)' * Fs / N; sel = f <= cfg.thd_fmax;
semilogy(f(sel), Y(sel) + eps); grid on; xlabel('f [Hz]'); ylabel('|I_a| [A]'); title('Phase-A current spectrum (loaded)');

%% --- local function ---
function [thd20k, thd50, ncyc, fe] = current_thd(tw, x, Fs, fmax)
    x = x - mean(x);
    fc = 50; [b, a] = butter(2, fc/(Fs/2), 'low'); xf = filtfilt(b, a, x);
    zc = find(xf(1:end-1) .* xf(2:end) <= 0);
    ncyc = floor((numel(zc) - 1) / 2);
    if ncyc < 1, thd20k = NaN; thd50 = NaN; fe = NaN; return; end
    i0 = zc(1); i1 = zc(1 + 2*ncyc);
    seg = x(i0:i1-1); N = numel(seg);
    P = abs(fft(seg) / N); P = P(1:floor(N/2)+1); P(2:end-1) = 2 * P(2:end-1);
    fund = P(ncyc + 1);
    fe = ncyc / (N / Fs);
    fr = (0:floor(N/2))' * Fs / N;
    harm = P(2:end) .^ 2; frH = fr(2:end);
    sel = frH <= fmax; sel(ncyc) = false;                   % drop fundamental (index ncyc in P(2:end))
    thd20k = 100 * sqrt(sum(harm(sel))) / fund;
    k = (1:50) * ncyc + 1; k = k(k <= numel(P)); k = k(2:end);
    thd50 = 100 * sqrt(sum(P(k) .^ 2)) / fund;
end

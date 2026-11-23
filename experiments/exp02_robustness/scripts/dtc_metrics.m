function r = dtc_metrics(out, cfg)
%DTC_METRICS  Steady-state and dynamic metrics for DTC / SVM-DTC simulations.
%   r = dtc_metrics(out, cfg)  - out: sim output with timeseries
%       Ts_data (Te_est), ia_data, ib_data, w_data, lam_data, Sa_data
%   cfg fields: p, lambda_f, w_ref, ramp_time, load_time, windows (cell of [t0 t1]),
%       win_names, band_speed, dt, thd_fmax, current_sign, dynamic (true/false)
dt = cfg.dt; Fs = 1/dt;
tmax = min([out.Ts_data.Time(end), out.ia_data.Time(end), out.ib_data.Time(end), out.w_data.Time(end)]);
t  = (0:dt:tmax)';
rs = @(ts) interp1(ts.Time, squeeze(ts.Data), t, 'linear', 'extrap');
Te = rs(out.Ts_data); ia = rs(out.ia_data); ib = rs(out.ib_data);
w  = rs(out.w_data);  lam = rs(out.lam_data);

% torque reconstructed from measured currents and rotor angle (SPMSM: Te = 1.5 p lambda_f iq)
a = cfg.current_sign * ia; b = cfg.current_sign * ib;
th = cfg.p * cumtrapz(t, w);
be = (a + 2*b) / sqrt(3);
iq = -a .* sin(th) + be .* cos(th);
Tt = 1.5 * cfg.p * cfg.lambda_f * iq;
id = a .* cos(th) + be .* sin(th);                                 % true stator flux magnitude (SPMSM) from currents
LT = hypot(cfg.Ld * id + cfg.lambda_f, cfg.Lq * iq);

r.cfg = cfg; r.t = t; 
for k = 1:numel(cfg.windows)
    win = cfg.windows{k}; idx = t >= win(1) & t <= win(2); s = struct();
    for sig = {'est','true'}
        T = Te(idx); if strcmp(sig{1},'true'), T = Tt(idx); end
        s.(['Te_' sig{1} '_mean'])   = mean(T);
        s.(['Te_' sig{1} '_pk2pk'])  = max(T) - min(T);
        s.(['Te_' sig{1} '_rms'])    = sqrt(mean((T - mean(T)).^2));
        s.(['Te_' sig{1} '_pct'])    = 100 * s.(['Te_' sig{1} '_rms']) / abs(mean(T));
    end
    L = lam(idx);
    s.lam_mean = mean(L); s.lam_pk2pk = max(L)-min(L); s.lam_rms = sqrt(mean((L-mean(L)).^2));
    [s.THD_20k, s.THD_50th, s.n_cycles, s.f_elec] = local_thd(ia(idx), Fs, cfg.thd_fmax);
    sa_t = out.Sa_data.Time; sa = squeeze(out.Sa_data.Data) > 0.5; si = sa_t >= win(1) & sa_t <= win(2);
    s.fsw_avg = sum(abs(diff(sa(si)))) / (2 * (win(2) - win(1)));
    s.speed_mean = mean(w(idx)); s.speed_ripple_pk2pk = max(w(idx)) - min(w(idx));
    % robustness metrics: how wrong is the estimate, and did the drive keep control?
    s.lam_true_mean = mean(LT(idx)); s.lam_true_min = min(LT(idx)); s.lam_true_max = max(LT(idx));
    s.flux_err_mean = mean(L - LT(idx)); s.flux_err_rms = sqrt(mean((L - LT(idx)).^2)); s.flux_err_max = max(abs(L - LT(idx)));
    s.speed_err_mean = mean(w(idx)) - cfg.w_target(k);
    s.speed_err_rms = sqrt(mean((w(idx) - cfg.w_target(k)).^2));
    s.Te_track_err = s.Te_true_mean - cfg.TL_target(k);
    s.lost_control = double(s.lam_true_min < 0.5 * cfg.lambda_f || abs(s.speed_err_mean) > 0.2 * max(abs(cfg.w_target(k)),1));
    r.(cfg.win_names{k}) = s;
end
if cfg.dynamic
    band = cfg.band_speed * cfg.w_ref; outb = abs(w - cfg.w_ref) > band;
    sp = t >= cfg.ramp_time & t < cfg.load_time;
    d.speed_overshoot_pct = 100 * max(0, max(w(sp)) - cfg.w_ref) / cfg.w_ref;
    d.speed_settling_ms   = 1e3 * (t(find(outb & sp, 1, 'last')) - cfg.ramp_time);
    ld = t >= cfg.load_time & t <= cfg.load_time + 0.3;
    d.load_speed_dip      = cfg.w_ref - min(w(ld));
    d.load_recovery_ms    = 1e3 * (t(find(outb & t >= cfg.load_time, 1, 'last')) - cfg.load_time);
    Tsm = movmean(Tt, round(1e-3 / dt));
    T0 = mean(Tt(t >= cfg.load_time - 0.05 & t < cfg.load_time - 0.005));
    T1 = r.(cfg.win_names{end}).Te_true_mean;
    seg = t >= cfg.load_time; ts = t(seg); Ts_ = Tsm(seg);
    i10 = find(Ts_ >= T0 + 0.1*(T1-T0), 1, 'first'); i90 = find(Ts_ >= T0 + 0.9*(T1-T0), 1, 'first');
    d.torque_rise_ms      = 1e3 * (ts(i90) - ts(i10));
    r.dynamic = d;
end
r.sig = struct('t',t,'Te_est',Te,'Te_true',Tt,'w',w,'lam',lam,'lam_true',LT,'ia',ia);
end

function [thd20k, thd50, ncyc, fe] = local_thd(x, Fs, fmax)
x = x - mean(x);
[b, a] = butter(2, 50/(Fs/2), 'low'); xf = filtfilt(b, a, x);
zc = find(xf(1:end-1) .* xf(2:end) <= 0); ncyc = floor((numel(zc) - 1) / 2);
if ncyc < 1, thd20k = NaN; thd50 = NaN; fe = NaN; return; end
seg = x(zc(1):zc(1 + 2*ncyc) - 1); N = numel(seg);
P = abs(fft(seg) / N); P = P(1:floor(N/2)+1); P(2:end-1) = 2 * P(2:end-1);
fund = P(ncyc + 1); fe = ncyc / (N / Fs); fr = (0:floor(N/2))' * Fs / N;
harm = P(2:end).^2; sel = fr(2:end) <= fmax; sel(ncyc) = false;
thd20k = 100 * sqrt(sum(harm(sel))) / fund;
k = (2:50) * ncyc + 1; k = k(k <= numel(P)); thd50 = 100 * sqrt(sum(P(k).^2)) / fund;
end

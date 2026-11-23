%% RESEARCH-GRADE DTC METRICS ANALYZER

% 1. Extract Data
Te_data = out.Ts_data; 
ia_data = out.ia_data;
Sa_data = out.Sa_data;

t = Te_data.Time;
Te = squeeze(Te_data.Data);
ia = squeeze(ia_data.Data);
Sa = squeeze(Sa_data.Data);

Ts = 2e-6; % Sample time
Fs = 1 / Ts; % Sampling frequency (500 kHz)

%% --- EXACT RISE TIME (Isolating the Step Event) ---
step_time = 0.3;     
T_init    = 0.0;     
T_final   = 0.5;     

step_region_idx = find(t >= step_time);
t_step  = t(step_region_idx);
Te_step = Te(step_region_idx);

delta_T = T_final - T_init;
y10 = T_init + (0.1 * delta_T);
y90 = T_init + (0.9 * delta_T);

idx10 = find(Te_step >= y10, 1, 'first');
idx90 = find(Te_step >= y90, 1, 'first');

if isempty(idx10) || isempty(idx90) || idx90 < idx10
    rise_time_exact = NaN;
else
    rise_time_exact = t_step(idx90) - t_step(idx10);
end

%% --- EXACT THD (Filtered Zero-Crossing & Integer-Cycle Windowing) ---
steady_start_time = 0.5;
steady_indices = t >= steady_start_time;
ia_steady = ia(steady_indices);
Sa_steady = Sa(steady_indices);
time_window = t(end) - steady_start_time;

% 1. Remove DC offset
ia_ac = ia_steady - mean(ia_steady);

% 2. Create a 50 Hz Low-Pass Filter to strip switching noise for cycle detection
fc = 50; 
[b, a] = butter(2, fc / (Fs / 2), 'low');
% filtfilt applies the filter forward and backward so there is ZERO phase shift
ia_filtered = filtfilt(b, a, ia_ac); 

% 3. Find zero-crossings on the FILTERED, smooth signal
sign_changes = find(ia_filtered(1:end-1) .* ia_filtered(2:end) <= 0);

if length(sign_changes) >= 3
    idx_start = sign_changes(1);
    num_half_cycles = length(sign_changes) - 1;
    num_full_cycles = floor(num_half_cycles / 2);
    idx_end = sign_changes(1 + (num_full_cycles * 2));
    
    % 4. Extract the integer cycles from the RAW, UNFILTERED signal
    ia_exact_cycles = ia_ac(idx_start : idx_end - 1);
    
    % 5. Perform Leakage-Free FFT
    N = length(ia_exact_cycles);
    Y = fft(ia_exact_cycles);
    P2 = abs(Y / N);
    P1 = P2(1:floor(N/2) + 1);
    P1(2:end-1) = 2 * P1(2:end-1);
    
    fund_idx = num_full_cycles + 1;
    fundamental_mag = P1(fund_idx);
    
    harmonic_power = sum(P1(2:end).^2) - fundamental_mag^2;
    harmonic_power = max(harmonic_power, 0); 
    
    thd_exact = 100 * sqrt(harmonic_power) / fundamental_mag;
else
    % Fallback if the simulation time window is too short to capture a full cycle
    thd_exact = thd(ia_ac, Fs);
    thd_exact = 100 * (10^(thd_exact/20));
    num_full_cycles = 0;
end

%% --- METRICS OUTPUT ---
Te_steady = Te(steady_indices);
Te_ripple_pk2pk = max(Te_steady) - min(Te_steady);
ss_error = mean(Te_steady) - T_final;

total_transitions = sum(abs(diff(Sa_steady)));
average_fsw = total_transitions / (2 * time_window);

clc;
fprintf('=== RESEARCH-GRADE DTC METRICS ===\n');
fprintf('Target Torque Commanded : %.2f N*m\n', T_final);
fprintf('1. Torque Ripple (Pk-Pk): %.4f N*m\n', Te_ripple_pk2pk);
fprintf('2. Torque Rise Time     : %.5f seconds\n', rise_time_exact);
fprintf('3. Steady-State Error   : %.4f N*m\n', ss_error);
fprintf('4. Avg Switching Freq   : %.0f Hz\n', average_fsw);
if num_full_cycles > 0
    fprintf('5. Phase A Current THD  : %.2f %% (Calculated over %d exact cycles)\n', thd_exact, num_full_cycles);
else
    fprintf('5. Phase A Current THD  : %.2f %% (Fallback calculation used)\n', thd_exact);
end
fprintf('==================================\n');
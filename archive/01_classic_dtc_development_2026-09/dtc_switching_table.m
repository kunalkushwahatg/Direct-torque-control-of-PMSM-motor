function [Sa, Sb, Sc] = dtc_switching_table(lambda_s_mag, theta_s_deg, Te_est, ...
    lambda_ref, Te_ref, HB_lambda, HB_torque)
%#codegen
% DTC hysteresis comparators + switching table (Parts 4.4-4.6)
% Outputs the 3-phase switching state (Sa,Sb,Sc) each in {0,1}
% Feed this into a Simulink "Controlled Voltage Source" / averaged VSI
% block, or directly into a full switched IGBT bridge if you're doing
% detailed power-electronics simulation.

persistent d_lambda d_torque
if isempty(d_lambda)
    d_lambda = 1;   % start assuming flux needs to rise
    d_torque = 0;
end

%% --- Flux hysteresis comparator (2-level, Part 4.4) ---
flux_err = lambda_ref - lambda_s_mag;
if flux_err > HB_lambda
    d_lambda = 1;
elseif flux_err < -HB_lambda
    d_lambda = 0;
end
% else: hold previous value (hysteresis behavior)

%% --- Torque hysteresis comparator (3-level, Part 4.4) ---
torque_err = Te_ref - Te_est;
if torque_err > HB_torque
    d_torque = 1;
elseif torque_err < -HB_torque
    d_torque = -1;
else
    d_torque = 0;
end

%% --- Sector identification (Step 1 from the sector clarification) ---
theta = mod(theta_s_deg, 360);
if theta >= 330 || theta < 30
    n = 1;
elseif theta < 90
    n = 2;
elseif theta < 150
    n = 3;
elseif theta < 210
    n = 4;
elseif theta < 270
    n = 5;
else
    n = 6;
end

%% --- Vector selection rule (Step 2 from the sector clarification) ---
% Vector index wraps mod 6, mapped to 1-6 (no zero index)
wrap6 = @(k) mod(k-1,6) + 1;

if d_torque == 0
    vec_idx = 0;   % zero vector (alternate V0/V7 for switching loss balance)
elseif d_lambda == 1 && d_torque == 1
    vec_idx = wrap6(n+1);
elseif d_lambda == 1 && d_torque == -1
    vec_idx = wrap6(n-1);
elseif d_lambda == 0 && d_torque == 1
    vec_idx = wrap6(n+2);
else % d_lambda == 0 && d_torque == -1
    vec_idx = wrap6(n-2);
end

%% --- Map vector index to switching state (Part 3.2 table) ---
switch vec_idx
    case 0
        Sa = 0; Sb = 0; Sc = 0;     % V0 (use V7=[1 1 1] on alternating cycles)
    case 1
        Sa = 1; Sb = 0; Sc = 0;     % V1
    case 2
        Sa = 1; Sb = 1; Sc = 0;     % V2
    case 3
        Sa = 0; Sb = 1; Sc = 0;     % V3
    case 4
        Sa = 0; Sb = 1; Sc = 1;     % V4
    case 5
        Sa = 0; Sb = 0; Sc = 1;     % V5
    case 6
        Sa = 1; Sb = 0; Sc = 1;     % V6
end

end

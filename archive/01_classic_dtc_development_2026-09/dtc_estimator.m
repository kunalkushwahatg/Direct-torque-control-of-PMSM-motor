function [lambda_s_mag, theta_s_deg, Te_est, lambda_alpha, lambda_beta] = ...
    dtc_estimator(ia, ib, ic, v_alpha, v_beta, Rs, p, Ts)
%#codegen
% DTC flux and torque estimator (voltage model, Part 4.3)
% Implements this as a MATLAB Function block with two persistent
% integrator states (lambda_alpha, lambda_beta).
%
% Inputs:
%   ia, ib, ic      - measured phase currents [A]
%   v_alpha, v_beta - inverter output voltage in alpha-beta frame [V]
%                     (computed upstream from the switching state, Part 3.2)
%   Rs              - stator resistance [ohm]
%   p               - pole pairs
%   Ts              - sample time [s]
%
% Outputs:
%   lambda_s_mag - stator flux magnitude [Wb]
%   theta_s_deg  - stator flux angle [deg], wrapped to [0,360)
%   Te_est       - estimated electromagnetic torque [N*m]
%   lambda_alpha, lambda_beta - flux components, useful for scope/debug

persistent lam_a lam_b
if isempty(lam_a)
    lam_a = 0;
    lam_b = 0;
end

%% Clarke transform of currents (amplitude-invariant, Part 1.2)
i_alpha = ia;
i_beta  = (1/sqrt(3))*ia + (2/sqrt(3))*ib;

%% Flux integration (Part 4.3) — forward Euler, simplest form
% NOTE: pure integration drifts at low speed (Problem 3, Part 5.1).
% Once this base version works, replace with a low-pass-filter-based
% or closed-loop observer estimator and compare.
lam_a = lam_a + Ts * (v_alpha - Rs*i_alpha);
lam_b = lam_b + Ts * (v_beta  - Rs*i_beta);

lambda_alpha = lam_a;
lambda_beta  = lam_b;

%% Magnitude and angle
lambda_s_mag = sqrt(lam_a^2 + lam_b^2);
theta_s_rad  = atan2(lam_b, lam_a);
theta_s_deg  = mod(theta_s_rad * 180/pi, 360);

%% Torque estimate (Part 4.3)
Te_est = 1.5 * p * (lam_a*i_beta - lam_b*i_alpha);

end

function [ia, ib, ic, omega_m, theta_e_deg, Te] = dtc_pmsm_plant(...
    v_alpha, v_beta, TL, Rs, Ld, Lq, lambda_f, p, J, B, Ts)
%#codegen
% Pure-math PMSM plant model (Part 2.6), no Simscape/SPS blocks required.
% Implements: inverse Park (alpha-beta -> dq) using the plant's own
% theta state, integrates id, iq, omega_m, theta forward, then inverse
% Clarke/Park back to phase currents for the estimator's feedback path.
%
% Inputs:
%   v_alpha, v_beta - stator voltage in stationary frame [V]
%                      (computed upstream from Sa,Sb,Sc,Vdc, Part 3.2)
%   TL              - load torque [N*m]
%   Rs,Ld,Lq,lambda_f,p,J,B - motor parameters (Part 2 notation)
%   Ts              - integration step [s] -- should equal Tsolver,
%                      i.e. this block should run every solver step,
%                      NOT at the slower DTC sample rate.
%
% Outputs:
%   ia, ib, ic   - phase currents [A], feed straight into dtc_estimator
%   omega_m      - mechanical speed [rad/s]
%   theta_e_deg  - electrical rotor angle [deg], for scopes/debug only
%   Te           - actual electromagnetic torque produced [N*m]

persistent id iq omega theta
if isempty(id)
    id = 0; iq = 0; omega = 0; theta = 0;
end

%% Inverse Park: alpha-beta -> dq, using this block's own theta state
% (Part 1.2 Park transform, inverted)
v_d =  cos(theta)*v_alpha + sin(theta)*v_beta;
v_q = -sin(theta)*v_alpha + cos(theta)*v_beta;

%% Electrical equations (Part 2.6) -- forward Euler
omega_e = p * omega;
did_dt = (v_d - Rs*id + omega_e*Lq*iq) / Ld;
diq_dt = (v_q - Rs*iq - omega_e*Ld*id - omega_e*lambda_f) / Lq;

id = id + Ts*did_dt;
iq = iq + Ts*diq_dt;

%% Torque and mechanical equation (Part 2.4, 2.5)
Te = 1.5*p*(lambda_f*iq + (Ld-Lq)*id*iq);
domega_dt = (Te - TL - B*omega) / J;
omega = omega + Ts*domega_dt;

%% Advance rotor angle
theta = theta + Ts*omega_e;
theta = mod(theta, 2*pi);

%% Outputs: dq -> alpha-beta (forward Park) -> abc (inverse Clarke)
i_alpha =  cos(theta)*id - sin(theta)*iq;
i_beta  =  sin(theta)*id + cos(theta)*iq;

ia = i_alpha;
ib = -0.5*i_alpha + (sqrt(3)/2)*i_beta;
ic = -0.5*i_alpha - (sqrt(3)/2)*i_beta;

omega_m = omega;
theta_e_deg = theta * 180/pi;

end

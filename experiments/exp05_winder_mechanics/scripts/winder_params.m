% WINDER_PARAMS  Illustrative parameters for the winder/unwinder mechanical model.
%
% These values are NOT experimental data and NOT industry-standard values.
% They were chosen so that the illustrative roll spans a realistic
% radius/inertia ratio and stays inside the existing lab motor's torque and
% speed range. Change them freely; every script reads them from here.
%
% Units are SI unless stated.

%% Web material (paper/board-like)
winder.rho    = 800;        % kg/m^3   bulk density of the wound material
winder.w      = 0.30;       % m        web width
winder.h      = 0.5e-3;     % m        web thickness (0.5 mm board-like)
winder.E      = 2.0e9;      % Pa       Young's modulus (paper 0.5-5 GPa)
winder.L      = 1.0;        % m        free web length between line and roll
winder.A      = winder.w * winder.h;   % m^2  web cross-section

%% Roll / core geometry
winder.rc     = 0.05;       % m        core radius
winder.rmax   = 0.12;       % m        maximum roll radius
winder.r0_wind   = 0.06;    % m        initial radius, winding
winder.r0_unwind = 0.115;    % m        initial radius, unwinding

%% Inertia and friction
winder.Jc     = 0.005;      % kg*m^2   core + shaft inertia (illustrative)
winder.Jm     = 0.0008;     % kg*m^2   motor rotor inertia (existing model: J)
winder.Bm     = 0.0001;     % N*m*s    viscous damping (existing model: B)

%% Tension and torque limits
winder.F_ref  = 15;         % N        tension setpoint
winder.F0     = 15;         % N        initial tension
winder.Fmax   = 200;        % N        web strength limit (illustrative)
winder.Tmax   = 5;          % N*m      drive torque limit (existing saturation)

%% Line speed profile
winder.v_init  = 0.2;       % m/s      initial line speed
winder.v_slope = 0.9;       % m/s^2    ramp slope -> 2.0 m/s at t = 2 s
winder.v_max   = 2.0;       % m/s      final line speed
winder.v_line_set = 1.2;    % m/s      winder line speed
winder.T_ramp  = 0.4;       % s        line-speed startup ramp
winder.f_c     = 2.0;       % Hz       tension feedback filter cutoff
winder.tau_F   = 1/(2*pi*winder.f_c);  % s
winder.filt_on = 1;         % 1 = filtered feedback, 0 = raw
winder.C_web   = 500;       % N*s/m  viscoelastic web damping (zeta~0.3)
winder.ff_on   = 1;         % 1 = feedforward on, 0 = off
winder.ff_full = 0;         % 1 = full (inertia+tension+friction), 0 = inertia only

%% Controllers used ONLY for the standalone validation
% (same speed-loop gains as the existing drive; draw loop is a validation aid)
winder.Kp_speed = 2.0;      % A/(rad/s) equivalent, same as existing model
winder.Ki_speed = 150;
winder.Kp_draw  = 1e-3;     % rad/s per N  (speed-based tension trim)
winder.Ki_draw  = 2e-2;     % rad/s per N per s
winder.draw_max = 0.5;      % rad/s        draw trim saturation

%% Closed-loop tension controller (identical for both drives)
% Design: plant from dw to F is an integrator with gain K*r, K = E*A/L.
% Choose wn = 4 rad/s, zeta = 1 at r = 0.06:
%   K*r = 1.8e4
%   Kp = 2*zeta*wn/(K*r) = 4.4e-4 rad/s per N
%   Ki = wn^2/(K*r)      = 8.9e-4 rad/s per N per s
winder.Kp_F        = 4.4e-4;  % rad/s per N
winder.Ki_F        = 8.9e-4;  % rad/s per N per s
winder.draw_max    = 0.2;     % rad/s  PI output limit
winder.draw_takeup = 0.02;    % rad/s  fixed draw while the web is slack
winder.F_slack     = 0.5;     % N      slack threshold
winder.w_min       = 0;       % rad/s  speed-reference lower limit (0 = standstill allowed)
winder.w_max       = 60;      % rad/s  speed-reference upper limit

%% Numerical
winder.Ts     = 20e-6;      % s        controller / plant sample time
winder.Tsim   = 20;         % s        default simulation time

%% Packed parameter vector for the MATLAB Function block
% order: [rho w rc h E A L Jc Jm B Fmax rmax]
winder_p = [winder.rho, winder.w, winder.rc, winder.h, winder.E, ...
            winder.A, winder.L, winder.Jc, winder.Jm, winder.Bm, ...
            winder.Fmax, winder.rmax];

%% Helper: total inertia at a given radius (used for initial conditions)
winder_Jfun = @(r) winder.Jm + winder.Jc + ...
    0.5 * (winder.rho * winder.w * pi * max(r^2 - winder.rc^2, 0)) * ...
    (r^2 + winder.rc^2);

%% Flat aliases used directly by Simulink block parameters
rho      = winder.rho;
w        = winder.w;
web_w    = winder.w;
rc       = winder.rc;
h        = winder.h;
E        = winder.E;
A        = winder.A;
L        = winder.L;
Jc       = winder.Jc;
Jm       = winder.Jm;
B        = winder.Bm;
Fmax     = winder.Fmax;
rmax     = winder.rmax;
F_ref    = winder.F_ref;
F0       = winder.F0;
Tmax     = winder.Tmax;
Kp_speed = winder.Kp_speed;
Ki_speed = winder.Ki_speed;
Kp_draw  = winder.Kp_draw;
Ki_draw  = winder.Ki_draw;
draw_max = winder.draw_max;
Kp_F     = winder.Kp_F;
Ki_F     = winder.Ki_F;
draw_takeup = winder.draw_takeup;
F_slack  = winder.F_slack;
w_min    = winder.w_min;
w_max    = winder.w_max;
v_init   = winder.v_init;
v_slope  = winder.v_slope;
v_max    = winder.v_max;
v_line_set = winder.v_line_set;
T_ramp   = winder.T_ramp;
f_c      = winder.f_c;
tau_F    = winder.tau_F;
filt_on  = winder.filt_on;
ff_on    = winder.ff_on;
ff_full  = winder.ff_full;
K_web    = E*A/L;
C_web    = winder.C_web;
Ts       = winder.Ts;
Tsim     = winder.Tsim;












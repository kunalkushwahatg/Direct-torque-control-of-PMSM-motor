    %% PMSM + DTC Simulation Parameters
% Run this script first (or set as Simulink model callback: InitFcn)
% All values are example figures for a small IPMSM — replace with your
% actual motor's datasheet/identified parameters.

%% Motor electrical parameters
Rs      = 2.875;       % Stator resistance [ohm]
Ld      = 8.5e-3;      % d-axis inductance [H]
Lq      = 8.5e-3;      % q-axis inductance [H]  (set Lq = Ld for SPMSM test case)
lambda_f = 0.175;      % Permanent magnet flux linkage [Wb]
p       = 4;           % Pole pairs

%% Mechanical parameters
J       = 0.0008;      % Rotor inertia [kg*m^2]
B       = 0.0001;      % Friction coefficient [N*m*s]

%% Inverter / DC bus
Vdc     = 300;          % DC bus voltage [V]

%% DTC controller parameters
lambda_ref = 0.175;     % Stator flux reference [Wb] — start near lambda_f for SPMSM,
                         % or rated flux value from motor datasheet for IPMSM
HB_lambda  = 0.01 * lambda_ref;   % Flux hysteresis band (start ~1-2% of ref)
HB_torque  = 0.02;                % Torque hysteresis band [N*m] (tune experimentally)
Ts_dtc     = 2e-6;                % DTC control sample time [s] (20-50 us typical)

%% Speed loop PI (outer loop, generates Te_ref)
Kp_speed = 2.0;
Ki_speed = 50;
speed_ref = 100;        % Reference mechanical speed [rad/s]
TL        = 2.0;        % Load torque [N*m] — apply as a step during simulation

%% Simulation
Tsim = 0.5;              % Total simulation time [s]
Tsolver = 1e-6;           % Fixed-step solver step size [s] — must be << Ts_dtc

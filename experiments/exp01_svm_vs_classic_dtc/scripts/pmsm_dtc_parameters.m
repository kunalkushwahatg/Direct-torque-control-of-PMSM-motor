%% PMSM + DTC / SVM-DTC simulation parameters  (FINAL set)
% Run this before simulating svm_dtc_final.slx or classic_dtc_final.slx.

%% Motor electrical parameters
Rs       = 2.875;      % Stator resistance [ohm]
Ld       = 8.5e-3;     % d-axis inductance [H]
Lq       = 8.5e-3;     % q-axis inductance [H]   (SPMSM: Ld = Lq)
lambda_f = 0.175;      % PM flux linkage [Wb]
p        = 4;          % Pole pairs

%% Mechanical parameters
J = 0.0008;            % Rotor inertia [kg*m^2]
B = 0.0001;            % Viscous friction [N*m*s]

%% Inverter / DC bus
Vdc = 300;             % DC bus voltage [V]

%% Sample times
Ts_dtc = 20e-6;        % Controller sample time [s]  (same for BOTH controllers)
Ts_pwm = 2e-6;         % PWM carrier time resolution [s] (SVM-DTC only; 100 steps per 5 kHz period)

%% DTC references and classical hysteresis bands
lambda_ref = 0.175;               % Stator flux reference [Wb]
HB_lambda  = 0.01 * lambda_ref;   % Flux hysteresis band (classical DTC only)
HB_torque  = 0.02;                % Torque hysteresis band [N*m] (classical DTC only)

%% Speed loop (PI, in the model's PID block: P = 2, I = 150, clamping anti-windup)
Kp_speed = 2.0;  Ki_speed = 150;

%% Test scenario (used by the models)
w_ref  = 20;           % Final speed reference [rad/s] (ramped at 700 rad/s^2 from t = 0.05 s)
TL_init = 0.5;         % Load torque before the load step [N*m]
TL      = 2.0;         % Load torque after the load step [N*m]
t_load  = 0.5;         % Load step time [s]

%% Simulation
Tsim = 1;              % Stop time [s]

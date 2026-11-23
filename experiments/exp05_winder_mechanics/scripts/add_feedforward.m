function add_feedforward(m)
%ADD_FEEDFORWARD  Modular inertia feedforward (+ optional full terms).
%
%   T_inertia = J*wdot_ref + dJ/dt*w_ref
%   T_extra   = mode*F_ref*r + B*w_ref
%   T_ff      = T_inertia + ff_full*T_extra
%   Te*       = sat(T_PI + ff_on*T_ff)
%
%   dv_line/dt is gated: it equals v_line_set/T_ramp only while the ramp is
%   still rising, and is zero after v_line reaches v_line_set.
%   J is taken from the winder plant output; derivatives are analytical.

if ~bdIsLoaded(m), load_system(m); end

names = {'Tff','Tff_inertia','Tff_extra','FF_Mux','FF_Mux3a','FF_Mux3b','FF_Mux4b', ...
         'dJdr','rdotFF','wdotFF','v_clock_ff','v_tau_ff','v_tau_sat_ff','v_scurve_d', ...
         'Jwdot','dJw','T_inertia','Tff_sum','ff_full_c','ff_full_gate', ...
         'ff_on','ff_gate','Te_sum','Te_sat'};
for k = 1:numel(names)
    if getSimulinkBlockHandle([m '/' names{k}]) > 0
        delete_block([m '/' names{k}]);
    end
end

if getSimulinkBlockHandle([m '/svm_voltage_command']) > 0
    innerBlk = 'svm_voltage_command'; innerPort = 5;
else
    innerBlk = 'MATLAB Function1';    innerPort = 5;
end

ph = get_param([m '/' innerBlk],'PortHandles');
l  = get_param(ph.Inport(innerPort),'Line');
if l > 0, delete_line(l); end

% dJ/dr
add_block('simulink/User-Defined Functions/Fcn',[m '/dJdr'], ...
    'Position',[900 1060 990 1100], ...
    'Expr','rho*w*pi*u(1)*(u(1)^2+rc^2) + (rho*w*pi*(u(1)^2-rc^2))*u(1)');

% rdot = mode*h*v_line/(2*pi*r)
add_block('simulink/Signal Routing/Mux',[m '/FF_Mux3a'], ...
    'Position',[850 1150 855 1220],'Inputs','3');
add_block('simulink/User-Defined Functions/Fcn',[m '/rdotFF'], ...
    'Position',[900 1160 990 1210], ...
    'Expr','u(1)*h*u(2)/(2*pi*u(3))');

% dv_line/dt of the S-curve reference
add_block('simulink/Sources/Clock',[m '/v_clock_ff'], ...
    'Position',[850 1250 880 1280]);
add_block('simulink/Math Operations/Gain',[m '/v_tau_ff'], ...
    'Position',[900 1250 940 1280],'Gain','1/T_ramp');
add_block('simulink/Discontinuities/Saturation',[m '/v_tau_sat_ff'], ...
    'Position',[960 1250 1000 1280],'UpperLimit','1','LowerLimit','0');
add_block('simulink/User-Defined Functions/Fcn',[m '/v_scurve_d'], ...
    'Position',[1020 1250 1120 1290], ...
    'Expr','v_line_set*(6*u(1)-6*u(1)^2)/T_ramp');

% wdot = dv/dt / r - v_line*rdot/r^2
add_block('simulink/Signal Routing/Mux',[m '/FF_Mux4b'], ...
    'Position',[1020 1150 1025 1230],'Inputs','4');
add_block('simulink/User-Defined Functions/Fcn',[m '/wdotFF'], ...
    'Position',[1070 1160 1170 1210], ...
    'Expr','u(4)/u(1) - u(2)*u(3)/(u(1)^2)');

% J*wdot
add_block('simulink/Math Operations/Product',[m '/Jwdot'], ...
    'Position',[1200 1080 1230 1120],'Inputs','2');
% dJ/dt*w
add_block('simulink/Math Operations/Product',[m '/dJw'], ...
    'Position',[1200 1170 1230 1210],'Inputs','3');
add_block('simulink/Math Operations/Sum',[m '/T_inertia'], ...
    'Position',[1270 1090 1300 1130],'Inputs','++');

% extra = mode*F_ref*r + B*w_ref
add_block('simulink/Signal Routing/Mux',[m '/FF_Mux'], ...
    'Position',[1020 1300 1025 1380],'Inputs','4');
add_block('simulink/User-Defined Functions/Fcn',[m '/Tff_extra'], ...
    'Position',[1070 1310 1170 1360], ...
    'Expr','u(1)*F_ref*u(3) + B*u(4)');
add_block('simulink/Sources/Constant',[m '/ff_full_c'], ...
    'Position',[1200 1300 1240 1330],'Value','ff_full');
add_block('simulink/Math Operations/Product',[m '/ff_full_gate'], ...
    'Position',[1270 1300 1300 1340],'Inputs','2');
add_block('simulink/Math Operations/Sum',[m '/Tff_sum'], ...
    'Position',[1340 1120 1370 1160],'Inputs','++');

add_block('simulink/Sources/Constant',[m '/ff_on'], ...
    'Position',[1340 1300 1380 1330],'Value','ff_on');
add_block('simulink/Math Operations/Product',[m '/ff_gate'], ...
    'Position',[1410 1160 1440 1200],'Inputs','2');

add_block('simulink/Math Operations/Sum',[m '/Te_sum'], ...
    'Position',[1480 1000 1510 1040],'Inputs','++');
add_block('simulink/Discontinuities/Saturation',[m '/Te_sat'], ...
    'Position',[1550 1000 1590 1040], ...
    'UpperLimit','Tmax','LowerLimit','-Tmax');

% wiring
connect(m,'Winder Plant/2','dJdr',1);

connect(m,'winder_mode/1','FF_Mux3a',1);
connect(m,'v_sat/1','FF_Mux3a',2);
connect(m,'Winder Plant/2','FF_Mux3a',3);
connect(m,'FF_Mux3a/1','rdotFF',1);

connect(m,'v_clock_ff/1','v_tau_ff',1);
connect(m,'v_tau_ff/1','v_tau_sat_ff',1);
connect(m,'v_tau_sat_ff/1','v_scurve_d',1);

connect(m,'Winder Plant/2','FF_Mux4b',1);
connect(m,'v_sat/1','FF_Mux4b',2);
connect(m,'rdotFF/1','FF_Mux4b',3);
connect(m,'v_scurve_d/1','FF_Mux4b',4);
connect(m,'FF_Mux4b/1','wdotFF',1);

connect(m,'Winder Plant/3','Jwdot',1);
connect(m,'wdotFF/1','Jwdot',2);

connect(m,'dJdr/1','dJw',1);
connect(m,'rdotFF/1','dJw',2);
connect(m,'omega_ref_ramp/1','dJw',3);

connect(m,'Jwdot/1','T_inertia',1);
connect(m,'dJw/1','T_inertia',2);

connect(m,'winder_mode/1','FF_Mux',1);
connect(m,'F_ref_set/1','FF_Mux',2);
connect(m,'Winder Plant/2','FF_Mux',3);
connect(m,'omega_ref_ramp/1','FF_Mux',4);
connect(m,'FF_Mux/1','Tff_extra',1);
connect(m,'Tff_extra/1','ff_full_gate',1);
connect(m,'ff_full_c/1','ff_full_gate',2);

connect(m,'T_inertia/1','Tff_sum',1);
connect(m,'ff_full_gate/1','Tff_sum',2);

connect(m,'Tff_sum/1','ff_gate',1);
connect(m,'ff_on/1','ff_gate',2);

connect(m,'PID Controller/1','Te_sum',1);
connect(m,'ff_gate/1','Te_sum',2);
connect(m,'Te_sum/1','Te_sat',1);
connect(m,'Te_sat/1',innerBlk,innerPort);

save_system(m);
fprintf('Feedforward added to %s (inner target: %s/%d)\n', m, innerBlk, innerPort);
end

%% ----------------------------------------------------------------------
function connect(m, src, dstBlk, dstPort)
ph = get_param([m '/' dstBlk],'PortHandles');
l  = get_param(ph.Inport(dstPort),'Line');
if l > 0, delete_line(l); end
add_line(m, src, [dstBlk '/' num2str(dstPort)], 'autorouting','on');
end




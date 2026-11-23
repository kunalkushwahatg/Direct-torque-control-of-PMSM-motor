function build_winder_model()
%BUILD_WINDER_MODEL  Standalone winder/unwinder validation model.
%
%   Run:  winder_params; build_winder_model;  then validate_winder
%
%   The plant is a single Level-2 MATLAB S-function (winder_plant_sfun.m),
%   so the diagram stays readable and the equations live in one place.
%   Logging is a single 10-channel Mux -> one To Workspace block.

mdl = 'winder_mechanics';
if bdIsLoaded(mdl), close_system(mdl,0); end
if exist([mdl '.slx'],'file'), delete([mdl '.slx']); end
new_system(mdl); open_system(mdl);

%% ---------------- sources ----------------
add_block('simulink/Sources/Ramp',[mdl '/Line speed'], ...
    'Position',[40 90 85 120], ...
    'InitialOutput','v_init','slope','v_slope','start','0');

add_block('simulink/Discontinuities/Saturation',[mdl '/v_sat'], ...
    'Position',[120 90 160 120], ...
    'UpperLimit','v_max','LowerLimit','0');

add_block('simulink/Sources/Constant',[mdl '/Tension ref'], ...
    'Position',[40 170 85 200],'Value','F_ref');

add_block('simulink/Sources/Constant',[mdl '/Mode'], ...
    'Position',[40 250 85 280],'Value','winder_mode');

%% ---------------- plant + drive subsystems ----------------
add_block('simulink/Ports & Subsystems/Subsystem',[mdl '/Winder Plant'], ...
    'Position',[520 70 900 370]);
build_plant([mdl '/Winder Plant']);

add_block('simulink/Ports & Subsystems/Subsystem',[mdl '/Virtual Drive'], ...
    'Position',[190 400 430 610]);
build_drive([mdl '/Virtual Drive']);

%% ---------------- logging ----------------
add_block('simulink/Signal Routing/Mux',[mdl '/LogMux'], ...
    'Position',[1000 70 1005 430],'Inputs','10');

add_block('simulink/Sinks/To Workspace',[mdl '/logs'], ...
    'Position',[1080 235 1125 265], ...
    'VariableName','logs','SaveFormat','Timeseries');

%% ---------------- top-level wiring ----------------
add_line(mdl,'Line speed/1','v_sat/1','autorouting','on');
add_line(mdl,'v_sat/1','Winder Plant/2','autorouting','on');
add_line(mdl,'v_sat/1','Virtual Drive/1','autorouting','on');
add_line(mdl,'Tension ref/1','Virtual Drive/6','autorouting','on');
add_line(mdl,'Mode/1','Winder Plant/3','autorouting','on');
add_line(mdl,'Mode/1','Virtual Drive/5','autorouting','on');

add_line(mdl,'Winder Plant/2','Virtual Drive/2','autorouting','on');  % r
add_line(mdl,'Winder Plant/1','Virtual Drive/3','autorouting','on');  % F
add_line(mdl,'Winder Plant/5','Virtual Drive/4','autorouting','on');  % omega
add_line(mdl,'Virtual Drive/1','Winder Plant/1','autorouting','on');  % Te

% logging order: r J F vline vsurf TL omega Te omega_ref draw
add_line(mdl,'Winder Plant/2','LogMux/1','autorouting','on');
add_line(mdl,'Winder Plant/3','LogMux/2','autorouting','on');
add_line(mdl,'Winder Plant/1','LogMux/3','autorouting','on');
add_line(mdl,'v_sat/1','LogMux/4','autorouting','on');
add_line(mdl,'Winder Plant/6','LogMux/5','autorouting','on');
add_line(mdl,'Winder Plant/4','LogMux/6','autorouting','on');
add_line(mdl,'Winder Plant/5','LogMux/7','autorouting','on');
add_line(mdl,'Virtual Drive/1','LogMux/8','autorouting','on');
add_line(mdl,'Virtual Drive/2','LogMux/9','autorouting','on');
add_line(mdl,'Virtual Drive/3','LogMux/10','autorouting','on');
add_line(mdl,'LogMux/1','logs/1','autorouting','on');

%% ---------------- tidy ----------------
try, Simulink.Mask.create([mdl '/Winder Plant']); catch, end
try, Simulink.Mask.create([mdl '/Virtual Drive']); catch, end

set_param(mdl,'StopTime','Tsim');
set_param(mdl,'Solver','VariableStepAuto','RelTol','1e-4','MaxStep','1e-3');
set_param(mdl,'SaveOutput','off','SignalLogging','off');

save_system(mdl);
fprintf('Built %s.slx\n', mdl);
end

%% =======================================================================
function build_plant(ph)
%BUILD_PLANT  Winder/unwinder mechanics: one S-function block.
delete_line(ph,'In1/1','Out1/1');
delete_block([ph '/In1']); delete_block([ph '/Out1']);

add_block('simulink/Ports & Subsystems/In1',[ph '/Te'], ...
    'Position',[30 60 60 80],'Port','1');
add_block('simulink/Ports & Subsystems/In1',[ph '/vline'], ...
    'Position',[30 130 60 150],'Port','2');
add_block('simulink/Ports & Subsystems/In1',[ph '/mode'], ...
    'Position',[30 200 60 220],'Port','3');

add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[ph '/Winder'], ...
    'Position',[230 70 380 250], ...
    'FunctionName','winder_plant_sfun', ...
    'Parameters','winder_p, r0, H0, F0');

add_block('simulink/Ports & Subsystems/Out1',[ph '/F'], ...
    'Position',[500 50 530 70],'Port','1');
add_block('simulink/Ports & Subsystems/Out1',[ph '/r'], ...
    'Position',[500 95 530 115],'Port','2');
add_block('simulink/Ports & Subsystems/Out1',[ph '/J'], ...
    'Position',[500 140 530 160],'Port','3');
add_block('simulink/Ports & Subsystems/Out1',[ph '/TL'], ...
    'Position',[500 185 530 205],'Port','4');
add_block('simulink/Ports & Subsystems/Out1',[ph '/omega'], ...
    'Position',[500 230 530 250],'Port','5');
add_block('simulink/Ports & Subsystems/Out1',[ph '/vsurf'], ...
    'Position',[500 275 530 295],'Port','6');
add_block('simulink/Ports & Subsystems/Out1',[ph '/m'], ...
    'Position',[500 320 530 340],'Port','7');

add_line(ph,'Te/1','Winder/1','autorouting','on');
add_line(ph,'vline/1','Winder/2','autorouting','on');
add_line(ph,'mode/1','Winder/3','autorouting','on');

add_line(ph,'Winder/1','F/1','autorouting','on');
add_line(ph,'Winder/2','r/1','autorouting','on');
add_line(ph,'Winder/3','J/1','autorouting','on');
add_line(ph,'Winder/4','TL/1','autorouting','on');
add_line(ph,'Winder/5','omega/1','autorouting','on');
add_line(ph,'Winder/6','vsurf/1','autorouting','on');
add_line(ph,'Winder/7','m/1','autorouting','on');
end

%% =======================================================================
function build_drive(ph)
%BUILD_DRIVE  Validation-only virtual drive: speed loop + tension draw trim.
delete_line(ph,'In1/1','Out1/1');
delete_block([ph '/In1']); delete_block([ph '/Out1']);

add_block('simulink/Ports & Subsystems/In1',[ph '/vline'], ...
    'Position',[20 40 50 60],'Port','1');
add_block('simulink/Ports & Subsystems/In1',[ph '/r'], ...
    'Position',[20 90 50 110],'Port','2');
add_block('simulink/Ports & Subsystems/In1',[ph '/F'], ...
    'Position',[20 140 50 160],'Port','3');
add_block('simulink/Ports & Subsystems/In1',[ph '/omega'], ...
    'Position',[20 190 50 210],'Port','4');
add_block('simulink/Ports & Subsystems/In1',[ph '/mode'], ...
    'Position',[20 240 50 260],'Port','5');
add_block('simulink/Ports & Subsystems/In1',[ph '/F_ref'], ...
    'Position',[20 290 50 310],'Port','6');

add_block('simulink/Math Operations/Divide',[ph '/v_over_r'], ...
    'Position',[110 35 140 75],'Inputs','*/');

add_block('simulink/Math Operations/Sum',[ph '/F_err'], ...
    'Position',[110 135 140 165],'Inputs','+-');
add_block('simulink/Continuous/PID Controller',[ph '/PI_draw'], ...
    'Position',[180 135 220 175]);
set_param([ph '/PI_draw'],'Controller','PI','Form','Parallel', ...
    'TimeDomain','Continuous-time', ...
    'P','Kp_draw','I','Ki_draw','D','0', ...
    'LimitOutput','on','UpperSaturationLimit','draw_max', ...
    'LowerSaturationLimit','-draw_max','AntiWindupMode','clamping');

add_block('simulink/Math Operations/Product',[ph '/draw_mode'], ...
    'Position',[330 190 360 230],'Inputs','2');

add_block('simulink/Math Operations/Sum',[ph '/w_ref'], ...
    'Position',[410 90 440 130],'Inputs','++');

add_block('simulink/Math Operations/Sum',[ph '/w_err'], ...
    'Position',[490 170 520 200],'Inputs','+-');

add_block('simulink/Continuous/PID Controller',[ph '/PI'], ...
    'Position',[570 165 610 205]);
set_param([ph '/PI'],'Controller','PI','Form','Parallel', ...
    'TimeDomain','Continuous-time', ...
    'P','Kp_speed','I','Ki_speed','D','0', ...
    'LimitOutput','on','UpperSaturationLimit','Tmax', ...
    'LowerSaturationLimit','-Tmax','AntiWindupMode','clamping', ...
    'InitialConditionForIntegrator','Te0');

add_block('simulink/Ports & Subsystems/Out1',[ph '/Te'], ...
    'Position',[690 165 720 185],'Port','1');
add_block('simulink/Ports & Subsystems/Out1',[ph '/omega_ref'], ...
    'Position',[500 90 530 110],'Port','2');
add_block('simulink/Ports & Subsystems/Out1',[ph '/draw'], ...
    'Position',[330 300 360 320],'Port','3');

add_line(ph,'vline/1','v_over_r/1','autorouting','on');
add_line(ph,'r/1','v_over_r/2','autorouting','on');

add_line(ph,'F_ref/1','F_err/1','autorouting','on');
add_line(ph,'F/1','F_err/2','autorouting','on');
add_line(ph,'F_err/1','PI_draw/1','autorouting','on');
add_line(ph,'PI_draw/1','draw_mode/1','autorouting','on');
add_line(ph,'mode/1','draw_mode/2','autorouting','on');

add_line(ph,'v_over_r/1','w_ref/1','autorouting','on');
add_line(ph,'draw_mode/1','w_ref/2','autorouting','on');

add_line(ph,'w_ref/1','w_err/1','autorouting','on');
add_line(ph,'omega/1','w_err/2','autorouting','on');

add_line(ph,'w_err/1','PI/1','autorouting','on');
add_line(ph,'PI/1','Te/1','autorouting','on');
add_line(ph,'w_ref/1','omega_ref/1','autorouting','on');
add_line(ph,'PI_draw/1','draw/1','autorouting','on');
end




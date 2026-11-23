function build_drive_native(srcName, dstName)
%BUILD_DRIVE_NATIVE  Winder integrated into a drive copy (native blocks).
%
%   Mechanical chain (verified):
%     PMSM1.RConn1 -> TorqueSensor.LConn1
%     TorqueSensor.RConn1 -> SpeedSource.LConn1
%     SpeedSource.RConn2 -> Mechanical Rotational Reference.LConn1
%     PMSM1.RConn2 (case) -> Mechanical Rotational Reference2.LConn1
%     TorqueSensor.RConn2 -> PS-Simulink (Te)
%     Simulink-PS -> SpeedSource.RConn1 (omega)
%
%   The winder plant is native Simulink blocks; no S-function callbacks.

exp_root = fileparts(fileparts(mfilename('fullpath')));
src = fullfile(exp_root,'..','exp03_rs_boundary','models',[srcName '.slx']);
dst = fullfile(exp_root,'models',[dstName '.slx']);
if ~exist(fullfile(exp_root,'models'),'dir'), mkdir(fullfile(exp_root,'models')); end
copyfile(src,dst);
addpath(fullfile(exp_root,'..','exp03_rs_boundary','models'));
addpath(fullfile(exp_root,'scripts'));
load_system(dst);
m = dstName;

% ---- parameter check (printed, not assumed) ----
fprintf('PMSM lam = %s %s ; J = %s %s ; pm_flux = %s %s\n', ...
    get_param([m '/PMSM1'],'lam'), get_param([m '/PMSM1'],'lam_unit'), ...
    get_param([m '/PMSM1'],'J'),   get_param([m '/PMSM1'],'J_unit'), ...
    get_param([m '/PMSM1'],'pm_flux_linkage'), get_param([m '/PMSM1'],'pm_flux_linkage_unit'));

% ---- remove old load and old speed sensor ----
lh3 = get_param([m '/PS-Simulink Converter3'],'LineHandles');
if isstruct(lh3) && isfield(lh3,'Outport') && lh3.Outport > 0
    delete_line(lh3.Outport);
end
delete_block([m '/Ideal Torque Source']);
delete_block([m '/Ideal Rotational Motion Sensor']);
delete_block([m '/PS-Simulink Converter3']);
try, delete_block([m '/Simulink-PS Converter1']); catch, end
try, delete_block([m '/Load_step']); catch, end

% ---- remove only the shaft line; keep the case ground ----
lh = get_param([m '/PMSM1'],'LineHandles');
for q = 1:numel(lh.RConn)
    h = lh.RConn(q);
    if h <= 0, continue; end
    keep = false;
    try
        sb = get_param(h,'SrcBlockHandle');
        if sb>0 && strcmp(get_param(sb,'Name'),'Mechanical Rotational Reference2'), keep = true; end
    catch, end
    try
        db = get_param(h,'DstBlockHandle');
        if db>0 && strcmp(get_param(db,'Name'),'Mechanical Rotational Reference2'), keep = true; end
    catch, end
    if ~keep, delete_line(h); end
end

% ---- new mechanical blocks ----
add_block('fl_lib/Mechanical/Mechanical Sensors/Ideal Torque Sensor', ...
    [m '/Torque Sensor'],'Position',[300 520 340 580]);
add_block('fl_lib/Mechanical/Mechanical Sources/Ideal Angular Velocity Source', ...
    [m '/Speed Source'],'Position',[420 520 460 580]);
add_block('nesl_utility/PS-Simulink Converter', ...
    [m '/Te Conv'],'Position',[300 630 340 660]);
add_block('nesl_utility/Simulink-PS Converter', ...
    [m '/w Conv'],'Position',[420 630 460 660]);

add_block('simulink/Sources/Constant',[m '/v_line'], ...
    'Position',[560 660 600 690],'Value','v_line_set');
add_block('simulink/Sources/Constant',[m '/winder_mode'], ...
    'Position',[560 710 600 740],'Value','winder_mode_set');

% ---- native winder plant subsystem ----
add_block('simulink/Ports & Subsystems/Subsystem',[m '/Winder Plant'], ...
    'Position',[650 470 900 730]);
build_native_plant([m '/Winder Plant']);

% ---- mechanical chain ----
add_line(m,'PMSM1/RConn1','Torque Sensor/LConn1','autorouting','on');
add_line(m,'Torque Sensor/RConn1','Speed Source/LConn1','autorouting','on');
add_line(m,'Speed Source/RConn2','Mechanical Rotational Reference/LConn1','autorouting','on');
try
    add_line(m,'PMSM1/RConn2','Mechanical Rotational Reference2/LConn1','autorouting','on');
catch
    % already grounded
end

% ---- signals ----
add_line(m,'Torque Sensor/RConn2','Te Conv/LConn1','autorouting','on');
add_line(m,'Te Conv/1','Winder Plant/1','autorouting','on');
add_line(m,'Winder Plant/5','w Conv/1','autorouting','on');
add_line(m,'w Conv/RConn1','Speed Source/RConn1','autorouting','on');
add_line(m,'v_line/1','Winder Plant/2','autorouting','on');
add_line(m,'winder_mode/1','Winder Plant/3','autorouting','on');

% ---- speed feedback ----
add_line(m,'Winder Plant/5','Sum/2','autorouting','on');
add_line(m,'Winder Plant/5','omega/1','autorouting','on');
add_line(m,'Winder Plant/5','w_data/1','autorouting','on');

% ---- logs ----
logs = {'F','r','J','TL'};
srcs = [1 2 3 4];
ys   = [760 790 820 850];
for k = 1:numel(logs)
    add_block('simulink/Sinks/To Workspace',[m '/' logs{k} '_log'], ...
        'Position',[950 ys(k) 995 ys(k)+25], ...
        'VariableName',[logs{k} '_log'],'SaveFormat','Timeseries');
    add_line(m,['Winder Plant/' num2str(srcs(k))],[logs{k} '_log/1'],'autorouting','on');
end
add_block('simulink/Sinks/To Workspace',[m '/Te_log'], ...
    'Position',[950 880 995 905], ...
    'VariableName','Te_log','SaveFormat','Timeseries');
add_line(m,'Te Conv/1','Te_log/1','autorouting','on');

% ---- mechanical ownership ----
% lam is viscous damping (N*m*s/rad); pm_flux_linkage is NOT touched.
set_param([m '/PMSM1'],'J','0','lam','0');

save_system(m);
fprintf('Built %s.slx\n', dstName);
end

%% =======================================================================
function build_native_plant(ph)
%BUILD_NATIVE_PLANT  Validated equations, native blocks.
delete_line(ph,'In1/1','Out1/1');
delete_block([ph '/In1']); delete_block([ph '/Out1']);

add_block('simulink/Ports & Subsystems/In1',[ph '/Te'], ...
    'Position',[20 40 50 60],'Port','1');
add_block('simulink/Ports & Subsystems/In1',[ph '/vline'], ...
    'Position',[20 100 50 120],'Port','2');
add_block('simulink/Ports & Subsystems/In1',[ph '/mode'], ...
    'Position',[20 160 50 180],'Port','3');

add_block('simulink/Math Operations/Product',[ph '/r2'], ...
    'Position',[120 300 150 330],'Inputs','2');
add_block('simulink/Sources/Constant',[ph '/rc2'], ...
    'Position',[120 360 160 390],'Value','rc^2');
add_block('simulink/Math Operations/Sum',[ph '/r2_minus_rc2'], ...
    'Position',[210 305 240 340],'Inputs','+-');
add_block('simulink/Math Operations/Gain',[ph '/m'], ...
    'Position',[290 310 330 335],'Gain','rho*web_w*pi');
add_block('simulink/Math Operations/Sum',[ph '/r2_plus_rc2'], ...
    'Position',[210 375 240 410],'Inputs','++');
add_block('simulink/Math Operations/Gain',[ph '/half_m'], ...
    'Position',[290 380 330 405],'Gain','0.5');
add_block('simulink/Math Operations/Product',[ph '/Jroll_core'], ...
    'Position',[380 345 410 375],'Inputs','2');
add_block('simulink/Sources/Constant',[ph '/Jc'], ...
    'Position',[380 410 420 440],'Value','Jc');
add_block('simulink/Math Operations/Sum',[ph '/Jroll'], ...
    'Position',[460 370 490 405],'Inputs','++');
add_block('simulink/Sources/Constant',[ph '/Jm'], ...
    'Position',[460 435 500 465],'Value','Jm');
add_block('simulink/Math Operations/Sum',[ph '/J'], ...
    'Position',[540 390 570 425],'Inputs','++');

add_block('simulink/Math Operations/Divide',[ph '/omega'], ...
    'Position',[620 390 650 420],'Inputs','*/');
add_block('simulink/Math Operations/Product',[ph '/TL'], ...
    'Position',[380 170 410 210],'Inputs','3');
add_block('simulink/Math Operations/Product',[ph '/vsurf'], ...
    'Position',[620 300 650 330],'Inputs','2');

add_block('simulink/Math Operations/Product',[ph '/num_dr'], ...
    'Position',[300 40 330 70],'Inputs','2');
add_block('simulink/Math Operations/Gain',[ph '/h_gain'], ...
    'Position',[380 45 420 65],'Gain','h');
add_block('simulink/Math Operations/Gain',[ph '/den_dr'], ...
    'Position',[300 100 340 120],'Gain','2*pi');
add_block('simulink/Math Operations/Divide',[ph '/drdt'], ...
    'Position',[470 60 500 90],'Inputs','*/');

add_block('simulink/Math Operations/Gain',[ph '/Bw'], ...
    'Position',[620 460 660 480],'Gain','B');
add_block('simulink/Math Operations/Sum',[ph '/dHdt'], ...
    'Position',[700 430 730 470],'Inputs','+--');
add_block('simulink/Math Operations/Sum',[ph '/dv'], ...
    'Position',[700 300 730 335],'Inputs','+-');
add_block('simulink/Math Operations/Product',[ph '/dxdt'], ...
    'Position',[780 300 810 340],'Inputs','2');

add_block('simulink/Continuous/Integrator',[ph '/Int_r'], ...
    'Position',[960 45 1000 85],'InitialCondition','r0', ...
    'LimitOutput','on','UpperSaturationLimit','rmax', ...
    'LowerSaturationLimit','rc');
add_block('simulink/Continuous/Integrator',[ph '/Int_H'], ...
    'Position',[960 130 1000 170],'InitialCondition','H0');
add_block('simulink/Continuous/Integrator',[ph '/Int_x'], ...
    'Position',[960 215 1000 255],'InitialCondition','F0/K_web', ...
    'LimitOutput','on','UpperSaturationLimit','Fmax/K_web', ...
    'LowerSaturationLimit','0');
add_block('simulink/Math Operations/Gain',[ph '/K_x'], ...
    'Position',[1040 205 1080 235],'Gain','K_web');
add_block('simulink/Math Operations/Gain',[ph '/C_d'], ...
    'Position',[860 360 900 385],'Gain','C_web');
add_block('simulink/Math Operations/Sum',[ph '/F_sum'], ...
    'Position',[1120 300 1150 340],'Inputs','++');
add_block('simulink/Discontinuities/Saturation',[ph '/F_sat'], ...
    'Position',[1180 300 1220 340], ...
    'UpperLimit','Fmax','LowerLimit','0');

add_block('simulink/Ports & Subsystems/Out1',[ph '/out_F'], ...
    'Position',[1070 215 1100 235],'Port','1');
add_block('simulink/Ports & Subsystems/Out1',[ph '/out_r'], ...
    'Position',[1070 45 1100 65],'Port','2');
add_block('simulink/Ports & Subsystems/Out1',[ph '/out_J'], ...
    'Position',[1070 390 1100 410],'Port','3');
add_block('simulink/Ports & Subsystems/Out1',[ph '/out_TL'], ...
    'Position',[1070 175 1100 195],'Port','4');
add_block('simulink/Ports & Subsystems/Out1',[ph '/out_omega'], ...
    'Position',[1070 460 1100 480],'Port','5');
add_block('simulink/Ports & Subsystems/Out1',[ph '/out_vsurf'], ...
    'Position',[1070 300 1100 320],'Port','6');
add_block('simulink/Ports & Subsystems/Out1',[ph '/out_m'], ...
    'Position',[1070 340 1100 360],'Port','7');

% wiring
add_line(ph,'Int_r/1','r2/1','autorouting','on');
add_line(ph,'Int_r/1','r2/2','autorouting','on');
add_line(ph,'r2/1','r2_minus_rc2/1','autorouting','on');
add_line(ph,'rc2/1','r2_minus_rc2/2','autorouting','on');
add_line(ph,'r2_minus_rc2/1','m/1','autorouting','on');
add_line(ph,'r2/1','r2_plus_rc2/1','autorouting','on');
add_line(ph,'rc2/1','r2_plus_rc2/2','autorouting','on');
add_line(ph,'m/1','half_m/1','autorouting','on');
add_line(ph,'half_m/1','Jroll_core/1','autorouting','on');
add_line(ph,'r2_plus_rc2/1','Jroll_core/2','autorouting','on');
add_line(ph,'Jroll_core/1','Jroll/1','autorouting','on');
add_line(ph,'Jc/1','Jroll/2','autorouting','on');
add_line(ph,'Jroll/1','J/1','autorouting','on');
add_line(ph,'Jm/1','J/2','autorouting','on');

add_line(ph,'Int_H/1','omega/1','autorouting','on');
add_line(ph,'J/1','omega/2','autorouting','on');

add_line(ph,'mode/1','TL/1','autorouting','on');
add_line(ph,'F_sat/1','TL/2','autorouting','on');
add_line(ph,'Int_r/1','TL/3','autorouting','on');

add_line(ph,'omega/1','vsurf/1','autorouting','on');
add_line(ph,'Int_r/1','vsurf/2','autorouting','on');

add_line(ph,'mode/1','num_dr/1','autorouting','on');
add_line(ph,'vline/1','num_dr/2','autorouting','on');
add_line(ph,'num_dr/1','h_gain/1','autorouting','on');
add_line(ph,'Int_r/1','den_dr/1','autorouting','on');
add_line(ph,'h_gain/1','drdt/1','autorouting','on');
add_line(ph,'den_dr/1','drdt/2','autorouting','on');

add_line(ph,'omega/1','Bw/1','autorouting','on');
add_line(ph,'Te/1','dHdt/1','autorouting','on');
add_line(ph,'TL/1','dHdt/2','autorouting','on');
add_line(ph,'Bw/1','dHdt/3','autorouting','on');

add_line(ph,'vsurf/1','dv/1','autorouting','on');
add_line(ph,'vline/1','dv/2','autorouting','on');
add_line(ph,'mode/1','dxdt/1','autorouting','on');
add_line(ph,'dv/1','dxdt/2','autorouting','on');

add_line(ph,'drdt/1','Int_r/1','autorouting','on');
add_line(ph,'dHdt/1','Int_H/1','autorouting','on');
add_line(ph,'dxdt/1','Int_x/1','autorouting','on');
add_line(ph,'Int_x/1','K_x/1','autorouting','on');
add_line(ph,'dxdt/1','C_d/1','autorouting','on');
add_line(ph,'K_x/1','F_sum/1','autorouting','on');
add_line(ph,'C_d/1','F_sum/2','autorouting','on');
add_line(ph,'F_sum/1','F_sat/1','autorouting','on');

add_line(ph,'F_sat/1','out_F/1','autorouting','on');
add_line(ph,'Int_r/1','out_r/1','autorouting','on');
add_line(ph,'J/1','out_J/1','autorouting','on');
add_line(ph,'TL/1','out_TL/1','autorouting','on');
add_line(ph,'omega/1','out_omega/1','autorouting','on');
add_line(ph,'vsurf/1','out_vsurf/1','autorouting','on');
add_line(ph,'m/1','out_m/1','autorouting','on');
end



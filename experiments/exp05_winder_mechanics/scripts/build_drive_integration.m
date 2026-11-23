function build_drive_integration(srcName, dstName)
%BUILD_DRIVE_INTEGRATION  Speed-imposed winder integrated into a drive copy.
%
%   Mechanical chain (verified port names):
%     PMSM1.RConn1 -> TorqueSensor.LConn1
%     TorqueSensor.RConn1 -> SpeedSource.LConn1
%     SpeedSource.RConn2 -> Mechanical Rotational Reference.LConn1
%     TorqueSensor.RConn2 -> PS-Simulink (torque signal)
%     Simulink-PS -> SpeedSource.RConn1 (speed command)
%
%   PMSM.RConn2 (case) stays grounded through Reference2.
%   PMSM J and lam are set to zero; Jm and B live in the winder plant.

exp_root = fileparts(fileparts(mfilename('fullpath')));
src = fullfile(exp_root,'..','exp03_rs_boundary','models',[srcName '.slx']);
dst = fullfile(exp_root,'models',[dstName '.slx']);
if ~exist(fullfile(exp_root,'models'),'dir'), mkdir(fullfile(exp_root,'models')); end
copyfile(src,dst);
addpath(fullfile(exp_root,'..','exp03_rs_boundary','models'));
addpath(fullfile(exp_root,'scripts'));
load_system(dst);
m = dstName;

% ---- remove old load and old speed sensor ----
lh3 = get_param([m '/PS-Simulink Converter3'],'LineHandles');
if isstruct(lh3) && isfield(lh3,'Outport') && lh3.Outport > 0
    delete_line(lh3.Outport);      % removes the branched speed-feedback line
end
delete_block([m '/Ideal Torque Source']);
delete_block([m '/Ideal Rotational Motion Sensor']);
delete_block([m '/PS-Simulink Converter3']);
try, delete_block([m '/Simulink-PS Converter1']); catch, end
try, delete_block([m '/Load_step']); catch, end

% ---- remove the shaft line, keep the case ground (Reference2) ----
lh = get_param([m '/PMSM1'],'LineHandles');
for q = 1:numel(lh.RConn)
    h = lh.RConn(q);
    if h <= 0, continue; end
    keep = false;
    try, sb = get_param(h,'SrcBlockHandle'); if sb>0 && strcmp(get_param(sb,'Name'),'Mechanical Rotational Reference2'), keep = true; end; catch, end
    try, db = get_param(h,'DstBlockHandle'); if db>0 && strcmp(get_param(db,'Name'),'Mechanical Rotational Reference2'), keep = true; end; catch, end
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

% ---- winder plant + inputs ----
add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function', ...
    [m '/Winder'],'Position',[560 480 700 620], ...
    'FunctionName','winder_plant_sfun', ...
    'Parameters','winder_p, r0, H0, F0');

add_block('simulink/Sources/Constant',[m '/v_line'], ...
    'Position',[560 650 600 680],'Value','v_line_set');
add_block('simulink/Sources/Constant',[m '/winder_mode'], ...
    'Position',[560 700 600 730],'Value','1');

% ---- mechanical chain ----
add_line(m,'PMSM1/RConn1','Torque Sensor/LConn1','autorouting','on');
add_line(m,'Torque Sensor/RConn1','Speed Source/LConn1','autorouting','on');
add_line(m,'Speed Source/RConn2','Mechanical Rotational Reference/LConn1','autorouting','on');

% ---- torque signal ----
add_line(m,'Torque Sensor/RConn2','Te Conv/LConn1','autorouting','on');
add_line(m,'Te Conv/1','Winder/1','autorouting','on');

% ---- speed command ----
add_line(m,'Winder/5','w Conv/1','autorouting','on');
add_line(m,'w Conv/RConn1','Speed Source/RConn1','autorouting','on');

% ---- winder inputs ----
add_line(m,'v_line/1','Winder/2','autorouting','on');
add_line(m,'winder_mode/1','Winder/3','autorouting','on');

% ---- speed feedback replaces the old motion-sensor signal ----
add_line(m,'Winder/5','Sum/2','autorouting','on');
add_line(m,'Winder/5','omega/1','autorouting','on');
add_line(m,'Winder/5','w_data/1','autorouting','on');

% ---- logs ----
logs = {'F','r','J','TL','Te'};
srcs = [1 2 3 4 0];
ys   = [760 790 820 850 880];
for k = 1:numel(logs)
    add_block('simulink/Sinks/To Workspace',[m '/' logs{k} '_log'], ...
        'Position',[820 ys(k) 865 ys(k)+25], ...
        'VariableName',[logs{k} '_log'],'SaveFormat','Timeseries');
    if srcs(k) == 0
        add_line(m,'Te Conv/1',[logs{k} '_log/1'],'autorouting','on');
    else
        add_line(m,['Winder/' num2str(srcs(k))],[logs{k} '_log/1'],'autorouting','on');
    end
end

% ---- move mechanical ownership to the winder ----
set_param([m '/PMSM1'],'J','0','lam','0');

save_system(m);
fprintf('Built %s.slx\n', dstName);
end

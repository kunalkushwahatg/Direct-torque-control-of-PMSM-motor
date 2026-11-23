function add_tension_control(m)
%ADD_TENSION_CONTROL  Industrial-style tension loop around an integrated drive.
%
%   Feedforward:  w_ff = v_line / r
%   Feedback:     e = F_ref - F ;  u = PI(e)
%   Slack bias:   b = draw_takeup * sat(1 - F/F_slack, 0, 1)
%   Correction:   dw = mode*(u + b)
%   Reference:    w_ref = w_ff + dw  -> existing rate limiter -> speed loop
%
%   mode = +1 winding   : raise tension by running the roll faster
%   mode = -1 unwinding : raise tension by running the roll slower
%
%   Limits: PI output +-draw_max, w_ref in [w_min,w_max], clamping AW.
%   The slack bias is continuous (no switching), so it takes up slack without
%   integrator windup and without solver chattering.

if ~bdIsLoaded(m)
    load_system(m);
end

if getSimulinkBlockHandle([m '/Tension Control']) > 0
    delete_block([m '/Tension Control']);
end

ph = [m '/Tension Control'];
add_block('simulink/Ports & Subsystems/Subsystem',ph, ...
    'Position',[900 880 1170 1080]);
build_tension_subsystem(ph);

if getSimulinkBlockHandle([m '/F_ref_set']) < 0
    add_block('simulink/Sources/Constant',[m '/F_ref_set'], ...
        'Position',[760 940 800 970],'Value','F_ref');
end

add_line(m,'Winder Plant/1','Tension Control/1','autorouting','on');
add_line(m,'Winder Plant/2','Tension Control/2','autorouting','on');
add_line(m,'v_line/1','Tension Control/3','autorouting','on');
add_line(m,'winder_mode/1','Tension Control/4','autorouting','on');
add_line(m,'F_ref_set/1','Tension Control/5','autorouting','on');

lim = [m '/omega_ref_ramp'];
if getSimulinkBlockHandle(lim) > 0
    lh = get_param(lim,'LineHandles');
    if isstruct(lh) && isfield(lh,'Inport') && lh.Inport > 0
        delete_line(lh.Inport);
    end
    add_line(m,'Tension Control/1','omega_ref_ramp/1','autorouting','on');
else
    lh = get_param([m '/Sum'],'LineHandles');
    if isstruct(lh) && isfield(lh,'Inport')
        h = lh.Inport(1);
        if h > 0, delete_line(h); end
    end
    add_line(m,'Tension Control/1','Sum/1','autorouting','on');
end

save_system(m);
fprintf('Tension control added to %s\n', m);
end

%% =======================================================================
function build_tension_subsystem(ph)
delete_line(ph,'In1/1','Out1/1');
delete_block([ph '/In1']); delete_block([ph '/Out1']);

add_block('simulink/Ports & Subsystems/In1',[ph '/F'], ...
    'Position',[20 40 50 60],'Port','1');
add_block('simulink/Ports & Subsystems/In1',[ph '/r'], ...
    'Position',[20 90 50 110],'Port','2');
add_block('simulink/Ports & Subsystems/In1',[ph '/vline'], ...
    'Position',[20 140 50 160],'Port','3');
add_block('simulink/Ports & Subsystems/In1',[ph '/mode'], ...
    'Position',[20 190 50 210],'Port','4');
add_block('simulink/Ports & Subsystems/In1',[ph '/Fref'], ...
    'Position',[20 240 50 260],'Port','5');

% feedforward
add_block('simulink/Math Operations/Divide',[ph '/w_ff'], ...
    'Position',[110 130 140 170],'Inputs','*/');

% tension error and PI
add_block('simulink/Math Operations/Sum',[ph '/eF'], ...
    'Position',[110 230 140 260],'Inputs','+-');
add_block('simulink/Continuous/PID Controller',[ph '/PI_F'], ...
    'Position',[190 220 230 270]);
set_param([ph '/PI_F'],'Controller','PI','Form','Parallel', ...
    'TimeDomain','Continuous-time','P','Kp_F','I','Ki_F','D','0', ...
    'LimitOutput','on','UpperSaturationLimit','draw_max', ...
    'LowerSaturationLimit','-draw_max','AntiWindupMode','clamping', ...
    'InitialConditionForIntegrator','0');

% continuous slack bias: b = draw_takeup * sat(1 - F/F_slack, 0, 1)
add_block('simulink/Math Operations/Gain',[ph '/inv_Fslack'], ...
    'Position',[110 320 150 350],'Gain','1/F_slack');
add_block('simulink/Sources/Constant',[ph '/one'], ...
    'Position',[110 370 140 400],'Value','1');
add_block('simulink/Math Operations/Sum',[ph '/one_minus'], ...
    'Position',[190 325 220 360],'Inputs','+-');
add_block('simulink/Discontinuities/Saturation',[ph '/slack_sat'], ...
    'Position',[260 325 300 355], ...
    'UpperLimit','1','LowerLimit','0');
add_block('simulink/Math Operations/Gain',[ph '/takeup_gain'], ...
    'Position',[330 325 370 355],'Gain','draw_takeup');

% total draw = PI + bias
add_block('simulink/Math Operations/Sum',[ph '/draw_total'], ...
    'Position',[410 250 440 285],'Inputs','++');

% dw = mode * draw_total
add_block('simulink/Math Operations/Product',[ph '/mode_draw'], ...
    'Position',[490 250 520 290],'Inputs','2');

% w_ref = w_ff + dw
add_block('simulink/Math Operations/Sum',[ph '/w_ref'], ...
    'Position',[580 140 610 180],'Inputs','++');
add_block('simulink/Discontinuities/Saturation',[ph '/w_lim'], ...
    'Position',[650 145 690 175], ...
    'UpperLimit','w_max','LowerLimit','w_min');
add_block('simulink/Ports & Subsystems/Out1',[ph '/omega_ref'], ...
    'Position',[740 145 770 165],'Port','1');

add_line(ph,'vline/1','w_ff/1','autorouting','on');
add_line(ph,'r/1','w_ff/2','autorouting','on');

add_line(ph,'Fref/1','eF/1','autorouting','on');
add_line(ph,'F/1','eF/2','autorouting','on');
add_line(ph,'eF/1','PI_F/1','autorouting','on');

add_line(ph,'F/1','inv_Fslack/1','autorouting','on');
add_line(ph,'inv_Fslack/1','one_minus/2','autorouting','on');
add_line(ph,'one/1','one_minus/1','autorouting','on');
add_line(ph,'one_minus/1','slack_sat/1','autorouting','on');
add_line(ph,'slack_sat/1','takeup_gain/1','autorouting','on');

add_line(ph,'PI_F/1','draw_total/1','autorouting','on');
add_line(ph,'takeup_gain/1','draw_total/2','autorouting','on');

add_line(ph,'mode/1','mode_draw/1','autorouting','on');
add_line(ph,'draw_total/1','mode_draw/2','autorouting','on');

add_line(ph,'w_ff/1','w_ref/1','autorouting','on');
add_line(ph,'mode_draw/1','w_ref/2','autorouting','on');
add_line(ph,'w_ref/1','w_lim/1','autorouting','on');
add_line(ph,'w_lim/1','omega_ref/1','autorouting','on');
end

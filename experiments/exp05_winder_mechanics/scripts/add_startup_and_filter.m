function add_startup_and_filter(m)
%ADD_STARTUP_AND_FILTER  Common line-speed ramp + tension feedback LPF.
%
%   v_line: 0 -> v_line_set over T_ramp, identical for winding/unwinding.
%   The tension reference uses the ramped v_line, so w_ff = v_line/r starts
%   at zero with the roll at rest. This keeps the initial 15 N tension.
%
%   Feedback: first-order LPF 1/(tau_F*s+1), tau_F = 1/(2*pi*f_c), f_c = 2 Hz.
%   A Switch selects raw (filt_on = 0) or filtered (filt_on = 1) feedback.

if ~bdIsLoaded(m), load_system(m); end

% ---------- remove previous versions of the added blocks ----------
for nm = {'v_step','v_rate','v_sat','v_ramp','v_clock','v_tau','v_tau_sat','v_scurve','F_lpf','filt_sel','filt_on', ...
          'lpf_sum','lpf_gain','lpf_int'}
    if getSimulinkBlockHandle([m '/' nm{1}]) > 0
        delete_block([m '/' nm{1}]);
    end
end
if getSimulinkBlockHandle([m '/v_line']) > 0
    lh = get_param([m '/v_line'],'LineHandles');
    if isstruct(lh) && isfield(lh,'Outport') && lh.Outport > 0
        delete_line(lh.Outport);
    end
    delete_block([m '/v_line']);
end

% ---------- S-curve line-speed reference ----------
add_block('simulink/Sources/Clock',[m '/v_clock'],'Position',[440 660 470 690]);
add_block('simulink/Math Operations/Gain',[m '/v_tau'],'Position',[490 660 530 685],'Gain','1/T_ramp');
add_block('simulink/Discontinuities/Saturation',[m '/v_tau_sat'],'Position',[550 660 590 690],'UpperLimit','1','LowerLimit','0');
add_block('simulink/User-Defined Functions/Fcn',[m '/v_scurve'],'Position',[610 660 710 700],'Expr','v_line_set*(3*u(1)^2-2*u(1)^3)');
add_block('simulink/Discontinuities/Saturation',[m '/v_sat'], ...
    'Position',[740 660 780 690],'UpperLimit','v_line_set','LowerLimit','0');

connect(m,'v_clock/1','v_tau',1);
connect(m,'v_tau/1','v_tau_sat',1);
connect(m,'v_tau_sat/1','v_scurve',1);
connect(m,'v_scurve/1','v_sat',1);
connect(m,'v_sat/1','Winder Plant',2);
connect(m,'v_sat/1','Tension Control',3);

try
    set_param([m '/omega_ref_ramp'],'InitialCondition','0');
catch
end

% ---------- tension feedback filter ----------
% first-order 1/(tau_F*s+1) built explicitly so the state can start at F0
add_block('simulink/Math Operations/Sum',[m '/lpf_sum'], ...
    'Position',[600 850 630 880],'Inputs','+-');
add_block('simulink/Math Operations/Gain',[m '/lpf_gain'], ...
    'Position',[660 855 700 875],'Gain','1/tau_F');
add_block('simulink/Continuous/Integrator',[m '/lpf_int'], ...
    'Position',[730 850 770 880],'InitialCondition','F0');
add_block('simulink/Signal Routing/Switch',[m '/filt_sel'], ...
    'Position',[810 870 840 920],'Criteria','u2 < Threshold','Threshold','0.5');
add_block('simulink/Sources/Constant',[m '/filt_on'], ...
    'Position',[600 930 640 960],'Value','filt_on');

connect(m,'Winder Plant/1','lpf_sum',1);
connect(m,'lpf_int/1','lpf_sum',2);
connect(m,'lpf_sum/1','lpf_gain',1);
connect(m,'lpf_gain/1','lpf_int',1);
connect(m,'Winder Plant/1','filt_sel',3);
connect(m,'lpf_int/1','filt_sel',1);
connect(m,'filt_on/1','filt_sel',2);
connect(m,'filt_sel/1','Tension Control',1);

save_system(m);
fprintf('Startup ramp + feedback filter added to %s\n', m);
end

%% ----------------------------------------------------------------------
function connect(m, src, dstBlk, dstPort)
ph = get_param([m '/' dstBlk],'PortHandles');
l  = get_param(ph.Inport(dstPort),'Line');
if l > 0, delete_line(l); end
add_line(m, src, [dstBlk '/' num2str(dstPort)], 'autorouting','on');
end



% BEAUTIFY_SVM_WRAP  Final clean SVM model: plant wrapped + four groups.
exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(exp_root,'scripts'), fullfile(exp_root,'models'), ...
    fullfile(exp_root,'..','exp03_rs_boundary','scripts'));
src = fullfile(exp_root,'models','svm_dtc_winder_wrap.slx');
dst = fullfile(exp_root,'models','svm_dtc_winder_clean.slx');
copyfile(src,dst);
pmsm_dtc_parameters; winder_params;
r0 = winder.r0_wind; H0 = 0; F0 = winder.F0; winder_mode_set = 1;
m = 'svm_dtc_winder_clean';
load_system(m);

groups = {
 'Logging', {'F_log','J_log','r_log','TL_log','Te_log','w_data','ia_data', ...
             'ib_data','lam_data','Sa_data','Te_data','Te_est','Lambda_s_mag', ...
             'Ic','crrrents','omega','XY Graph','Scope','Scope1'};
 'Feedforward', {'dJdr','rdotFF','wdotFF','FF_Mux3a','FF_Mux4b','Jwdot', ...
             'dJw','T_inertia','Tff_extra','FF_Mux','ff_full_c', ...
             'ff_full_gate','ff_on','ff_gate','v_clock_ff','v_tau_ff', ...
             'v_tau_sat_ff','v_scurve_d','Tff_sum'};
 'Controller', {'dtc_estimator','svm_voltage_command','svm_duty_cycles', ...
             'PID Controller','Sum','ref_sum','omega_ref','omega_rev', ...
             'omega_ref_ramp','Unit Delay1','Data Type Conversion','Demux','Smux', ...
             'Zero-Order Hold','Zero-Order Hold1','Zero-Order Hold2', ...
             'hold_avg_valpha','hold_avg_vbeta','avg_valpha','avg_vbeta', ...
             'valpha_app','vbeta_app','PWM Generator (Three-phase, Two-level)1', ...
             'Te_sum','Te_sat'};
 'Line Reference', {'v_clock','v_tau','v_tau_sat','v_scurve','v_sat', ...
             'F_ref_set','winder_mode'};
};

ok = {};
for g = 1:size(groups,1)
    name = groups{g,1};
    names = groups{g,2};
    blocks = cellfun(@(n)[m '/' n], names, 'UniformOutput', false);
    live = blocks(cellfun(@(b) getSimulinkBlockHandle(b) > 0, blocks));
    fprintf('%s: %d blocks\n', name, numel(live));
    try
        hb = cellfun(@(b) getSimulinkBlockHandle(b), live);
        Simulink.BlockDiagram.createSubsystem(hb);
        subs = find_system(m,'SearchDepth',1,'BlockType','SubSystem');
        newsub = '';
        for k=1:numel(subs)
            nm = get_param(subs{k},'Name');
            if strcmp(nm,'Subsystem') || startsWith(nm,'Subsystem')
                newsub = subs{k};
            end
        end
        if ~isempty(newsub), set_param(newsub,'Name',strrep(name,' ','_')); end
        try, set_param(m,'SimulationCommand','update'); catch e2, fprintf('  compile: %s\n', e2.message); end
        ok{end+1} = name; %#ok<SAGROW>
        fprintf('  grouped OK\n');
    catch e
        fprintf('  FAILED: %s\n', e.message);
    end
end

try
    Simulink.BlockDiagram.arrangeSystem(m);
catch
end

save_system(m);
open_system(m);
print(['-s' m],'-dpng','-r120',fullfile(exp_root,'figures','svm_clean_v2.png'));
fprintf('Grouped: %s\n', strjoin(ok,', '));
fprintf('Top level blocks: %d\n', numel(find_system(m,'SearchDepth',1,'Type','Block')));

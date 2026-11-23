% WRAP_PLANT_SVM  Wrap the SVM drive + winder into one 'Plant' block.
exp_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(exp_root,'scripts'), fullfile(exp_root,'models'), ...
    fullfile(exp_root,'..','exp03_rs_boundary','scripts'));
src = fullfile(exp_root,'models','svm_dtc_winder.slx');
dst = fullfile(exp_root,'models','svm_dtc_winder_wrap.slx');
copyfile(src,dst);
pmsm_dtc_parameters; winder_params;
r0 = winder.r0_wind; H0 = 0; F0 = winder.F0; winder_mode_set = 1;
m = 'svm_dtc_winder_wrap';
load_system(m);

plant_blocks = {
 'PMSM1','Converter (Three-Phase)','Current Sensor','Current Sensor1', ...
 'Current Sensor2','DC Voltage Source','Electrical Reference', ...
 'Mechanical Rotational Reference','Mechanical Rotational Reference1', ...
 'Mechanical Rotational Reference2','Phase Splitter','Phase Splitter1', ...
 'Six-Pulse Gate Multiplexer','Speed Source','Torque Sensor', ...
 'Solver Configuration','Simulink-PS Converter','Simulink-PS Converter2', ...
 'Simulink-PS Converter3','Simulink-PS Converter4','Simulink-PS Converter5', ...
 'Simulink-PS Converter6','PS-Simulink Converter4','PS-Simulink Converter5', ...
 'PS-Simulink Converter6','PS-Simulink Converter7','Te Conv','w Conv', ...
 'Winder Plant'};

blocks = cellfun(@(n)[m '/' n], plant_blocks, 'UniformOutput', false);
live = blocks(cellfun(@(b) getSimulinkBlockHandle(b) > 0, blocks));
fprintf('plant blocks found: %d / %d\n', numel(live), numel(blocks));

h = cellfun(@(b) getSimulinkBlockHandle(b), live);
Simulink.BlockDiagram.createSubsystem(h);

subs = find_system(m,'SearchDepth',1,'BlockType','SubSystem');
newsub = '';
for k=1:numel(subs)
    nm = get_param(subs{k},'Name');
    if strcmp(nm,'Subsystem') || startsWith(nm,'Subsystem')
        newsub = subs{k};
    end
end
assert(~isempty(newsub),'no new subsystem found');
set_param(newsub,'Name','Plant');

try
    set_param(m,'SimulationCommand','update');
    fprintf('compiled OK\n');
catch e
    fprintf('COMPILE FAILED: %s\n', e.message);
    if ~isempty(e.cause)
        for k=1:numel(e.cause), fprintf('  %s\n', e.cause{k}.message); end
    end
end
save_system(m);
open_system(m);
print(['-s' m],'-dpng','-r100',fullfile(exp_root,'figures','svm_wrap_v1.png'));
fprintf('ports: %d in, %d out\n', ...
    numel(find_system([m '/Plant'],'SearchDepth',1,'BlockType','Inport')), ...
    numel(find_system([m '/Plant'],'SearchDepth',1,'BlockType','Outport')));

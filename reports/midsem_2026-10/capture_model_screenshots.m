% Screenshots of the two Simulink models for the report (tidied temporary copies; the experiment models are not modified)
here = fileparts(mfilename('fullpath')); root = fileparts(fileparts(here));
mdir = fullfile(root,'experiments','exp01_svm_vs_classic_dtc','models'); fdir = fullfile(here,'figures');
tmp = fullfile(tempdir,'capture_model_screenshots'); if ~exist(tmp,'dir'), mkdir(tmp); end; addpath(tmp);
run(fullfile(root,'experiments','exp01_svm_vs_classic_dtc','scripts','pmsm_dtc_parameters.m'));
src = {'svm_dtc_final','classic_dtc_final'}; dst = {'shot_svm','shot_classic'}; out = {'simulink_dtc_svm.png','simulink_dtc_classic.png'};
for k = 1:2
    copyfile(fullfile(mdir,[src{k} '.slx']), fullfile(tmp,[dst{k} '.slx'])); load_system(fullfile(tmp,dst{k})); m = dst{k};
    tw = find_system(m,'SearchDepth',1,'BlockType','ToWorkspace');                   % drop logging blocks (and their lines)
    for i = 1:numel(tw)
        ph = get_param(tw{i},'PortHandles'); l = get_param(ph.Inport(1),'Line'); if l>0, delete_line(l); end
        delete_block(tw{i});
    end
    if k == 1                                                                         % tidy the averaging chain of the estimator voltage
        dm = get_param([m '/Demux'],'Position'); x = dm(3)+70; y = dm(2)-20;
        set_param([m '/Smux'],'Position',[x y x+5 y+60]);
        set_param([m '/valpha_app'],'Position',[x+60 y-30 x+170 y]);   set_param([m '/vbeta_app'],'Position',[x+60 y+60 x+170 y+90]);
        set_param([m '/avg_valpha'],'Position',[x+210 y-30 x+300 y]);  set_param([m '/avg_vbeta'],'Position',[x+210 y+60 x+300 y+90]);
        set_param([m '/hold_avg_valpha'],'Position',[x+340 y-30 x+380 y]); set_param([m '/hold_avg_vbeta'],'Position',[x+340 y+60 x+380 y+90]);
        % replace the two long wires to the estimator by Goto/From tags
        pe = get_param([m '/dtc_estimator'],'PortHandles'); tags = {'v_alpha_avg','v_beta_avg'}; hs = {'hold_avg_valpha','hold_avg_vbeta'};
        for i = 1:2
            l = get_param(pe.Inport(3+i),'Line'); if l>0, delete_line(l); end
            hp = get_param([m '/' hs{i}],'Position'); ip = get_param(pe.Inport(3+i),'Position');
            add_block('simulink/Signal Routing/Goto',[m '/goto_' tags{i}],'GotoTag',tags{i},'Position',[hp(3)+30 hp(2)+5 hp(3)+90 hp(2)+25]);
            add_block('simulink/Signal Routing/From',[m '/from_' tags{i}],'GotoTag',tags{i},'Position',[ip(1)-210 ip(2)-10 ip(1)-150 ip(2)+10]);
            set_param([m '/goto_' tags{i}],'ShowName','off'); set_param([m '/from_' tags{i}],'ShowName','off');
            add_line(m, get_param([m '/' hs{i}],'PortHandles').Outport(1), get_param([m '/goto_' tags{i}],'PortHandles').Inport(1));
            add_line(m, get_param([m '/from_' tags{i}],'PortHandles').Outport(1), pe.Inport(3+i));
        end
        blks = {'Smux','valpha_app','vbeta_app','avg_valpha','avg_vbeta','hold_avg_valpha','hold_avg_vbeta'}; lh = [];
        for i = 1:numel(blks)
            ph = get_param([m '/' blks{i}],'PortHandles');
            for p = [ph.Inport ph.Outport], l = get_param(p,'Line'); if l>0, lh(end+1) = l; end, end %#ok<AGROW>
        end
        try, Simulink.BlockDiagram.routeLine(unique(lh)); catch, end
    end
    if k == 2, pp = get_param([m '/PID Controller'],'Position'); set_param([m '/PID Controller'],'Position',pp+[110 40 110 40]); end
    open_system(m); set_param(m,'ZoomFactor','fit to view');
    print(['-s' m],'-dpng','-r220',fullfile(fdir,out{k})); close_system(m,0); fprintf('%s done\n',out{k});
end

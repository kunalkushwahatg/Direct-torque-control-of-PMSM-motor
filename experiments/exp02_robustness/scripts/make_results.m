% MAKE_RESULTS (exp02): tables, figures and results/metrics_summary.csv for the robustness study.
% Requires setup_paths (tools/save_figure.m).
exp_root = fileparts(fileparts(mfilename('fullpath')));
rdir = fullfile(exp_root,'results'); fdir = fullfile(exp_root,'figures');
files = dir(fullfile(rdir,'result_*.mat')); R = struct();
for i = 1:numel(files)
    tmp = load(fullfile(rdir,files(i).name),'r');
    R.(matlab.lang.makeValidName(erase(erase(files(i).name,'result_'),'.mat'))) = tmp.r;
end
get_result = @(tag) R.(matlab.lang.makeValidName(tag));
cases = {'mid',20; 'low_w5',5; 'low_w2',2}; rsf = [70 100 130]; ctl = {'svm','cl'}; ctlname = {'SVM-DTC','Classical DTC'};
tag = @(c,k,f) sprintf('%s_%s_rs%03d', ctl{c}, cases{k,1}, f);

%% 1) table: flux and control outcome
fprintf('\n=== Rs MISMATCH (estimator Rs = factor x true Rs) ===\n');
fprintf('%-14s %-7s | %-34s | %-34s\n','Speed [rad/s]','Rs fact','SVM-DTC','Classical DTC');
fprintf('%-14s %-7s | %-34s | %-34s\n','','','true flux / torque ripple / state','true flux / torque ripple / state');
for k = 1:3, for f = rsf
    out = cell(1,2);
    for c = 1:2, s = get_result(tag(c,k,f)).ss; st = 'ok'; if s.lost_control, st = 'LOST CONTROL'; end
        out{c} = sprintf('%6.3f Wb / %7.3f N.m / %s', s.lam_true_mean, s.Te_true_rms, st); end
    fprintf('%-14d %-7s | %-34s | %-34s\n', cases{k,2}, sprintf('%d %%',f), out{1}, out{2});
end, end
fprintf('\n=== SPEED REVERSAL +5 -> -5 rad/s (nominal Rs) ===\n');
for c = 1:2, r = get_result([ctl{c} '_reversal']);
    fprintf('%-14s forward: ripple %.3f N.m, flux err %.4f | reverse: ripple %.3f N.m, flux err %.4f | lost: %d/%d\n', ctlname{c}, r.fwd.Te_true_rms, r.fwd.flux_err_rms, r.rev.Te_true_rms, r.rev.flux_err_rms, r.fwd.lost_control, r.rev.lost_control);
end

%% 2) figures
cC = [0.85 0.33 0.10]; cS = [0.00 0.447 0.741]; cT = [0.1 0.1 0.1]; col = {cS,cC};
newfig = @(h) figure('Visible','off','Position',[100 100 1200 h],'Color','w');

% fig01: estimated vs true flux, mid speed, three Rs values, both controllers
f = newfig(850);
for c = 1:2, for j = 1:3
    r = get_result(tag(c,1,rsf(j))); subplot(3,2,(j-1)*2+c); hold on;
    plot(r.sig.t,r.sig.lam,'Color',[0.6 0.6 0.6],'LineWidth',0.5); plot(r.sig.t,r.sig.lam_true,'Color',col{c},'LineWidth',0.5); grid on; ylim([0 0.6]);
    title(sprintf('%s, estimator Rs = %d %%', ctlname{c}, rsf(j))); if j==1 && c==1, legend('estimated flux (controller sees)','true flux (motor)','Location','east'); end
    if j==3, xlabel('t [s]'); end; ylabel('flux [Wb]');
end, end
save_figure(f,'fig01_flux_estimated_vs_true_mid_speed',fdir); close(f);

% fig02/03: speed responses
for k = 1:3
    f = newfig(700);
    for c = 1:2, subplot(2,1,c); hold on;
        for j = 1:3, r = get_result(tag(c,k,rsf(j))); plot(r.sig.t,r.sig.w,'LineWidth',1.1); end
        yline(cases{k,2},'k--'); grid on; ylabel('\omega [rad/s]'); title(sprintf('%s, speed reference %d rad/s',ctlname{c},cases{k,2}));
        legend('Rs 70 %','Rs 100 %','Rs 130 %','reference','Location','best'); ylim(cases{k,2}+[-30 30]);
    end
    xlabel('t [s]'); save_figure(f,sprintf('fig0%d_speed_response_%s',k+1,cases{k,1}),fdir); close(f);
end

% fig05: pass/fail map
f = newfig(520); M = zeros(9,2); lab = {}; txt = cell(9,2); n = 0;
for k = 1:3, for j = 1:3, n = n+1; lab{n} = sprintf('%d rad/s, Rs %d%%',cases{k,2},rsf(j));
    for c = 1:2, s = get_result(tag(c,k,rsf(j))).ss; M(n,c) = s.lost_control;
        if s.lost_control, txt{n,c} = 'LOST'; else, txt{n,c} = sprintf('flux %.3f',s.lam_true_mean); end
    end
end, end
imagesc(M,[0 1]); colormap([0.78 0.92 0.78; 0.95 0.65 0.65]); set(gca,'XTick',1:2,'XTickLabel',ctlname,'YTick',1:9,'YTickLabel',lab);
for i = 1:9, for c = 1:2, text(c,i,txt{i,c},'HorizontalAlignment','center','FontWeight','bold'); end, end
title('Did the controller keep control?  (green = yes, red = no; number = true flux, ideal 0.175 Wb)');
save_figure(f,'fig05_control_kept_map',fdir); close(f);

% fig06: reversal
f = newfig(700);
for c = 1:2, r = get_result([ctl{c} '_reversal']);
    subplot(2,2,c); plot(r.sig.t,r.sig.w,'Color',col{c},'LineWidth',1.2); hold on; grid on; yline(0,'k:'); ylabel('\omega [rad/s]'); title([ctlname{c} ': speed reversal']);
    subplot(2,2,2+c); plot(r.sig.t,r.sig.Te_true,'Color',col{c},'LineWidth',0.4); grid on; ylabel('T_e [N\cdotm]'); xlabel('t [s]'); ylim([-1 3]);
end
save_figure(f,'fig06_speed_reversal',fdir); close(f);

%% 3) summary table
rows = {}; tags = sort(fieldnames(R));
for i = 1:numel(tags)
    r = R.(tags{i}); wins = setdiff(fieldnames(r),{'cfg','t','sig','case','dynamic'});
    for j = 1:numel(wins), s = r.(wins{j});
        rows(end+1,:) = {r.case.tag, r.case.model, r.case.w, r.case.Rs_factor, wins{j}, s.speed_mean, s.speed_err_rms, s.Te_true_mean, s.Te_true_rms, s.lam_mean, ...
            s.lam_true_mean, s.lam_true_min, s.lam_true_max, s.flux_err_rms, s.flux_err_max, s.lost_control}; %#ok<SAGROW>
    end
end
T = cell2table(rows,'VariableNames',{'tag','model','speed_ref','Rs_factor','window','speed_mean','speed_err_rms','Te_true_mean','Te_true_rms','lam_est_mean', ...
    'lam_true_mean','lam_true_min','lam_true_max','flux_err_rms','flux_err_max','lost_control'});
writetable(T,fullfile(rdir,'metrics_summary.csv'));
fprintf('\nSaved 6 figures to %s and %d rows to results/metrics_summary.csv\n', fdir, height(T));

% Generates the seven result figures used in the mid-semester report (A4 text width = 6.3 in, Times New Roman).
% Reads saved results of exp01 and exp03/exp02; writes PNG (300 dpi) into figures/.
here = fileparts(mfilename('fullpath')); report_dir = fileparts(here); root = fileparts(fileparts(report_dir)); ex = fullfile(root,'experiments'); fdir = fullfile(report_dir,'figures');
r1 = fullfile(ex,'exp01_svm_vs_classic_dtc','results'); r2 = fullfile(ex,'exp02_robustness','results'); r3 = fullfile(ex,'exp03_rs_boundary','results');
C = load(fullfile(r1,'result_cl_dyn.mat'),'r').r; S = load(fullfile(r1,'result_svm_dyn.mat'),'r').r;
cC = [0.85 0.33 0.10]; cS = [0 0.447 0.741]; FS = 10; W = 6.3;
mk = @(h) figure('Visible','off','Units','inches','Position',[1 1 W h],'Color','w','PaperPositionMode','auto');
style_ax = @(ax) set(ax,'FontName','Times New Roman','FontSize',FS,'LineWidth',0.6,'Box','on','XGrid','on','YGrid','on','GridAlpha',0.25);
save_png = @(f,n) exportgraphics(f,fullfile(fdir,n),'Resolution',300);
dec = 4;

% --- 1. dynamic overview
f = mk(4.6); D = {C,S}; col = {cC,cS};
ax1 = subplot(3,1,1); hold on; for k=1:2, plot(D{k}.sig.t(1:dec:end),D{k}.sig.Te_true(1:dec:end),'Color',col{k},'LineWidth',0.5); end
ylabel('T_e (N\cdotm)'); legend('Conventional DTC','DTC-SVM','Location','southeast','FontSize',FS-1); style_ax(ax1); set(ax1,'XTickLabel',[]);
ax2 = subplot(3,1,2); hold on; for k=1:2, plot(D{k}.sig.t(1:dec:end),D{k}.sig.w(1:dec:end),'Color',col{k},'LineWidth',1.1); end
ylabel('\omega (rad/s)'); style_ax(ax2); set(ax2,'XTickLabel',[]);
ax3 = subplot(3,1,3); hold on; for k=1:2, plot(D{k}.sig.t(1:dec:end),D{k}.sig.lam(1:dec:end),'Color',col{k},'LineWidth',0.5); end
ylabel('|\lambda_s| (Wb)'); xlabel('Time (s)'); style_ax(ax3); save_png(f,'fig_dynamic.png'); close(f);

% --- 2. steady torque zoom
f = mk(3.4); w = [0.80 0.86]; nm = {'Conventional DTC','DTC-SVM'};
for k=1:2, ax = subplot(2,1,k); i = D{k}.sig.t>=w(1) & D{k}.sig.t<=w(2);
    plot(D{k}.sig.t(i),D{k}.sig.Te_true(i),'Color',col{k},'LineWidth',0.8); ylim([0.8 3.4]); ylabel('T_e (N\cdotm)'); style_ax(ax);
    text(0.99,0.88,nm{k},'Units','normalized','HorizontalAlignment','right','FontName','Times New Roman','FontSize',FS,'FontWeight','bold');
    if k==1, set(ax,'XTickLabel',[]); else, xlabel('Time (s)'); end
end
save_png(f,'fig_torque_zoom.png'); close(f);

% --- 3. current spectrum
f = mk(2.9); ax = axes; hold on; Fs = 1/(C.sig.t(2)-C.sig.t(1));
for k=1:2, i = D{k}.sig.t>=0.7 & D{k}.sig.t<=1.0; x = D{k}.sig.ia(i)-mean(D{k}.sig.ia(i)); N = numel(x); h = hann(N);
    Y = abs(fft(x.*h))/(sum(h)/2); fr = (0:N-1)'*Fs/N; s = fr>1 & fr<=20e3; plot(fr(s),Y(s)+1e-7,'Color',col{k},'LineWidth',0.6); end
set(ax,'YScale','log'); xlabel('Frequency (Hz)'); ylabel('|I_a| (A)'); legend('Conventional DTC','DTC-SVM','FontSize',FS-1); ylim([1e-5 3]); style_ax(ax); save_png(f,'fig_spectrum.png'); close(f);

% --- 4. sweep: torque ripple and THD
ctl = {'cl','svm'}; lab = {}; M = zeros(6,2,2); n = 0;
for sp = [10 30 60], for TL = [0.5 4], n = n+1; lab{n} = sprintf('%d / %g',sp,TL);
    for c=1:2, s = load(fullfile(r3,'..','..','exp01_svm_vs_classic_dtc','results',sprintf('result_%s_w%d_T%g.mat',ctl{c},sp,TL)),'r').r.ss; M(n,c,1)=s.Te_true_rms; M(n,c,2)=s.THD_20k; end
end, end
f = mk(2.9); yl = {'Torque ripple RMS (N\cdotm)','Current THD, 20 kHz (%)'};
for m=1:2, ax = subplot(1,2,m); b = bar(M(:,:,m)); b(1).FaceColor = cC; b(2).FaceColor = cS; set(ax,'XTickLabel',lab,'XTickLabelRotation',45);
    ylabel(yl{m}); xlabel('Speed (rad/s) / load (N\cdotm)'); style_ax(ax); if m==1, legend('Conventional DTC','DTC-SVM','Location','northwest','FontSize',FS-1); end
    if m==1, ylim([0 0.62]); end
    if m==2, set(ax,'YScale','log'); ylim([1 250]); end
end
save_png(f,'fig_sweep.png'); close(f);

% --- 5. true flux vs assumed Rs (exp03 + exp02)
fac = [70 80 90 100 105 110 120 130]; speeds = [20 5]; f = mk(2.9);
for si=1:2, ax = subplot(1,2,si); hold on; w = speeds(si);
    for c=1:2, xs=[]; ys=[]; lost=[];
        for p = fac
            if w==20, n2 = sprintf('%s_mid_rs%03d',ctl{c},p); else, n2 = sprintf('%s_low_w%d_rs%03d',ctl{c},w,p); end
            p1 = fullfile(r3,sprintf('result_%s_w%d_rs%03d.mat',ctl{c},w,p)); p2 = fullfile(r2,['result_' n2 '.mat']);
            if exist(p1,'file'), r = load(p1,'r').r; else, r = load(p2,'r').r; end
            xs(end+1)=p; ys(end+1)=min(r.ss.lam_true_mean,0.6); lost(end+1)=r.ss.lost_control; %#ok<SAGROW>
        end
        ok = lost==0;
        if any(ok), plot(xs(ok),ys(ok),'-o','Color',col{c},'MarkerFaceColor',col{c},'LineWidth',1.1,'MarkerSize',4); end
        plot(xs(~ok),ys(~ok),'x','Color',col{c},'MarkerSize',8,'LineWidth',1.6);
    end
    plot([65 135],[0.175 0.175],'k--','LineWidth',0.7); xlim([65 135]); ylim([0 0.65]);
    if si==1, hC = plot(NaN,NaN,'s','Color',cC,'MarkerFaceColor',cC); hS = plot(NaN,NaN,'s','Color',cS,'MarkerFaceColor',cS); legend([hC hS],'Conventional DTC','DTC-SVM','Location','south','FontSize',FS-1); end
    xlabel('Assumed R_s (% of true)'); ylabel('True flux (Wb)'); title(sprintf('%d rad/s',w),'FontWeight','normal'); style_ax(ax);
end
save_png(f,'fig_rs_flux.png'); close(f);

% --- 6. estimated vs true flux for three Rs values (DTC-SVM, 20 rad/s)
f = mk(4.0);
for j=1:3, p = [70 100 130]; r = load(fullfile(r2,sprintf('result_svm_mid_rs%03d.mat',p(j))),'r').r; ax = subplot(3,1,j); hold on;
    plot(r.sig.t(1:dec:end),r.sig.lam(1:dec:end),'Color',[0.55 0.55 0.55],'LineWidth',0.8); plot(r.sig.t(1:dec:end),r.sig.lam_true(1:dec:end),'Color',cS,'LineWidth',0.8);
    ylim([0 0.6]); ylabel('Flux (Wb)'); style_ax(ax); title(sprintf('Assumed R_s = %d %% of true value',p(j)),'FontWeight','normal','FontSize',FS);
    if j==1, legend('Estimated (seen by controller)','True (motor)','Location','west','FontSize',FS-1); end
    if j<3, set(ax,'XTickLabel',[]); else, xlabel('Time (s)'); end
end
save_png(f,'fig_rs_estimated_true.png'); close(f);
disp('figures done');

% --- 7. stability map: assumed Rs vs speed (one cell per case; both controllers gave the same outcome)
fac = [70 80 90 100 105 110 120 130]; speeds = [20 5]; f = mk(1.9); ax = axes; hold on;
for si = 1:2
    for fi = 1:numel(fac)
        w = speeds(si); p = fac(fi); lost = 0; fl = NaN;
        for c = 1:2
            if w==20, n2 = sprintf('%s_mid_rs%03d',ctl{c},p); else, n2 = sprintf('%s_low_w%d_rs%03d',ctl{c},w,p); end
            p1 = fullfile(r3,sprintf('result_%s_w%d_rs%03d.mat',ctl{c},w,p)); p2 = fullfile(r2,['result_' n2 '.mat']);
            if exist(p1,'file'), r = load(p1,'r').r; else, r = load(p2,'r').r; end
            lost = max(lost,r.ss.lost_control); if c==2, fl = r.ss.lam_true_mean; end
        end
        if lost, fc = [0.96 0.70 0.70]; tx = 'lost'; else, fc = [0.74 0.90 0.74]; tx = sprintf('%.3f',fl); end
        rectangle('Position',[fi-0.5 si-0.5 1 1],'FaceColor',fc,'EdgeColor','k','LineWidth',0.6);
        text(fi,si,tx,'HorizontalAlignment','center','FontName','Times New Roman','FontSize',FS);
    end
end
set(ax,'XLim',[0.5 numel(fac)+0.5],'YLim',[0.5 2.5],'XTick',1:numel(fac),'XTickLabel',arrayfun(@(v) sprintf('%d',v),fac,'UniformOutput',false),'YTick',1:2,'YTickLabel',{'20 rad/s','5 rad/s'},'YDir','reverse','FontName','Times New Roman','FontSize',FS,'LineWidth',0.6,'Box','on');
xlabel('Assumed R_s (% of true value)'); save_png(f,'fig_rs_map.png'); close(f);
disp('map done');

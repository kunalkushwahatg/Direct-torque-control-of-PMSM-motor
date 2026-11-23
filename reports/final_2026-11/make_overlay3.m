% Three-panel overlay: tension, torque, surface-speed mismatch.
here = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(here));
exp_root = fullfile(repo_root,'experiments','exp05_winder_mechanics');
outdir = fullfile(here,'figures');
C = load(fullfile(exp_root,'results','val2s_Classical_wind_ff1.mat'));
S = load(fullfile(exp_root,'results','val2s_SVM_wind_ff1.mat'));
blue = [0.00 0.45 0.74];
orange = [0.85 0.33 0.10];

fig = figure('Visible','off','Color','w','Position',[60 60 1800 620]);

subplot(1,3,1);
h1 = plot(S.t,S.F,'Color',blue,'LineWidth',1.0); hold on;
h2 = plot(C.t,C.F,'Color',orange,'LineWidth',1.6);
h3 = yline(15,'k--','LineWidth',1.2); grid on;
xlabel('t [s]'); ylabel('F [N]'); title('Web tension');
legend([h1 h2 h3],{'SVM-DTC','Classical DTC','Setpoint'},'Location','southeast','FontSize',9);

subplot(1,3,2);
h1 = plot(C.t,C.Te,'Color',orange,'LineWidth',1.6); hold on;
h2 = plot(S.t,S.Te,'Color',blue,'LineWidth',1.0); grid on;
xlabel('t [s]'); ylabel('T_e [N m]'); title('Motor torque');
legend([h1 h2],{'Classical DTC','SVM-DTC'},'Location','northeast','FontSize',9);

subplot(1,3,3);
h1 = plot(S.t,S.omg.*S.r-S.vl,'Color',blue,'LineWidth',1.0); hold on;
h2 = plot(C.t,C.omg.*C.r-C.vl,'Color',orange,'LineWidth',1.6); grid on;
xlabel('t [s]'); ylabel('v_{surf}-v_{line} [m/s]'); title('Surface-speed mismatch');
legend([h1 h2],{'SVM-DTC','Classical DTC'},'Location','southeast','FontSize',9);

sgtitle('Classical DTC vs SVM-DTC: winding, feedforward on');
print(fig,'-dpng','-r160',fullfile(outdir,'fig_overlay3.png'));
close(fig);
fprintf('saved fig_overlay3.png\n');

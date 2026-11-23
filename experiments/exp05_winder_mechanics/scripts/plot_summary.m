% PLOT_SUMMARY  Two-panel summary for the report:
%   (a) tension RMSE, feedforward off vs on, four main cases
%   (b) torque ripple (std of Te), feedforward on, classical vs SVM
exp_root = fileparts(fileparts(mfilename('fullpath')));
T = readtable(fullfile(exp_root,'results','final_matrix.csv'),'TextType','string');

tags = ["SVM_wind","SVM_unwind","Classical_wind","Classical_unwind"];
lab  = {'SVM wind','SVM unwind','Classical wind','Classical unwind'};
rmse0 = zeros(4,1); rmse1 = zeros(4,1); ripple = zeros(4,1);
for k=1:4
    rmse0(k) = T.F_rmse(T.tag==tags(k)+"_ff0");
    rmse1(k) = T.F_rmse(T.tag==tags(k)+"_ff1");
    ripple(k)= T.ripple(T.tag==tags(k)+"_ff1");
end

fig = figure('Visible','off','Color','w','Position',[80 80 1500 680]);

subplot(1,2,1);
b = bar([rmse0 rmse1],'grouped');
b(1).FaceColor = [0.75 0.78 0.82];
b(2).FaceColor = [0.10 0.45 0.75];
set(gca,'XTickLabel',lab,'FontSize',13); grid on;
ylabel('Tension RMSE [N]','FontSize',14);
title('Feedforward off vs on (2 s, 15 N)','FontSize',15);
legend({'FF off','FF on'},'Location','northeast','FontSize',12);
ylim([0 7]);
for k=1:4
    text(k-0.15,rmse0(k)+0.12,sprintf('%.2f',rmse0(k)),'HorizontalAlignment','center','FontSize',11);
    text(k+0.15,rmse1(k)+0.12,sprintf('%.2f',rmse1(k)),'HorizontalAlignment','center','FontSize',11);
end

subplot(1,2,2);
b2 = bar(ripple); grid on;
b2.FaceColor = [0.85 0.33 0.10];
set(gca,'XTickLabel',lab,'FontSize',13);
ylabel('Torque ripple, std(T_e) [N m]','FontSize',14);
title('Torque ripple, feedforward on','FontSize',15);
ylim([0 0.55]);
for k=1:4
    text(k,ripple(k)+0.012,sprintf('%.3f',ripple(k)),'HorizontalAlignment','center','FontSize',11);
end

sgtitle('Winder tension control: summary of the 2 s comparison','FontSize',15);
print(fig,'-dpng','-r150',fullfile(exp_root,'figures','fig_summary_ff.png'));
close(fig);
fprintf('saved fig_summary_ff.png\n');

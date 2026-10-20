function render_bwar_impl72_figures()
% MATLAB-only, traceable, slide-ready BWAR-Impl-72 figures.
% Reads existing results without changing any previous study artifacts.
% Outputs 8 PNG (3840x2160 target) + editable FIG files.

thisDir = fileparts(mfilename('fullpath'));
outRoot = fileparts(thisDir);
resultRoot = fileparts(outRoot);
srcImpl = fullfile(resultRoot,'bwar_implementation_refinement');
srcR2 = fullfile(srcImpl,'verification_round2');
srcP48 = fullfile(resultRoot,'calibration_architecture_study_p4_8');
srcP03 = fullfile(resultRoot,'calibration_architecture_study');
figDir = fullfile(outRoot,'figures');
dataDir = fullfile(outRoot,'data');
logDir = fullfile(outRoot,'logs');
for d = {figDir,dataDir,logDir}
    if ~isfolder(d{1}), mkdir(d{1}); end
end

set(groot,'defaultFigureColor','white');
set(groot,'defaultAxesFontName','Microsoft YaHei');
set(groot,'defaultTextFontName','Microsoft YaHei');
set(groot,'defaultAxesFontSize',13);
set(groot,'defaultLineLineWidth',1.7);
set(groot,'defaultFigureRenderer','opengl');

cfg.outRoot = outRoot; cfg.figDir = figDir; cfg.dataDir = dataDir;
cfg.srcImpl = srcImpl; cfg.srcR2 = srcR2; cfg.srcP48 = srcP48; cfg.srcP03 = srcP03;
cfg.blue = [0.09 0.42 0.70]; cfg.teal = [0.05 0.54 0.48];
cfg.orange = [0.90 0.48 0.08]; cfg.red = [0.76 0.25 0.25];
cfg.gold = [0.78 0.56 0.10]; cfg.ink = [0.07 0.19 0.29];
cfg.gray = [0.40 0.48 0.53]; cfg.grid = [0.85 0.89 0.91];

diary(fullfile(logDir,'matlab_figure_render.log'));
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('MATLAB BWAR figure render starts: %s\n',char(datetime('now')));

% Figure 1
fig01_architecture_filter(cfg);
% Figure 2
fig02_integer_bridge_search(cfg);
% Figure 3
fig03_topR_tradeoff(cfg);
% Figure 4
fig04_cal1_distribution(cfg);
% Figure 5
fig05_local_transfer(cfg);
% Figure 6
fig06_pdk_sensitivity(cfg);
% Figure 7
fig07_calibration_levels(cfg);
% Figure 8
fig08_averaging_tradeoff(cfg);

write_manifest(cfg);
fprintf('MATLAB BWAR figure render complete: %s\n',char(datetime('now')));
end

function fig01_architecture_filter(cfg)
T = readtable(fullfile(cfg.srcP03,'csv','architecture_calibration_summary.csv'));
names = {'Current','CBW','BWA','SBW'};
cap = zeros(1,4); pass = zeros(1,4); n = zeros(1,4);
for k=1:4
    r = T(strcmp(string(T.architecture),names{k}) & strcmp(string(T.calibration_mode),'CAL1'),:);
    cap(k) = r.total_cap_pF(1); pass(k) = r.spec_pass_yield(1); n(k) = r.MC_runs(1);
end
Tr2 = readtable(fullfile(cfg.srcR2,'csv','candidate_64_vs_72_CAL1_10000.csv'));
r72 = Tr2(strcmp(string(Tr2.candidate),'BWAR-Impl-72'),:);
names{5} = 'BWAR-Impl-72'; cap(5) = r72.total_cap_pF; pass(5) = 100*r72.pass_yield; n(5) = r72.MC_runs;

f = newfigure();
tiledlayout(f,1,2,'TileSpacing','compact','Padding','loose');
ax1 = nexttile; b = bar(ax1,1:5,cap,0.62,'FaceColor','flat');
b.CData = [repmat([0.55 0.65 0.71],4,1);cfg.gold];
set(ax1,'YScale','log','XTick',1:5,'XTickLabel',{'Current','CBW','BWA','SBW','Impl-72'});
ylabel(ax1,'差分核心电容（pF，对数刻度）'); styleax(ax1,cfg);
for k=1:5
    if cap(k)>500
        ypos=cap(k)*.72; tcolor=[1 1 1];
    else
        ypos=cap(k)*1.35; tcolor=cfg.ink;
    end
    text(ax1,k,ypos,sprintf('%.1f pF',cap(k)),'HorizontalAlignment','center','FontSize',10,'Color',tcolor);
end

ax2 = nexttile; b = bar(ax2,1:5,pass,0.62,'FaceColor','flat');
b.CData = [repmat([0.55 0.65 0.71],4,1);cfg.gold];
hold(ax2,'on'); h=yline(ax2,99,'--','99% 良率目标','Color',cfg.red,'LineWidth',1.6,'LabelHorizontalAlignment','left'); h.HandleVisibility='off';
set(ax2,'YLim',[0 105],'XTick',1:5,'XTickLabel',{'Current','CBW','BWA','SBW','Impl-72'});
ylabel(ax2,'CAL1 联合通过率（%）'); styleax(ax2,cfg);
for k=1:5
    text(ax2,k,pass(k)+3,sprintf('%.1f%%\nn = %d',pass(k),n(k)),'HorizontalAlignment','center','FontSize',10,'Color',cfg.ink);
end
annotation(f,'textbox',[.06 .91 .88 .07],'String', ...
    '图1  原始四种架构未通过完整 ADC 的 CAL1 筛选；BWA 多点冗余路径收敛到 Impl-72。', ...
    'EdgeColor','none','FontSize',22,'FontWeight','bold','Color',cfg.ink);
annotation(f,'textbox',[.06 .004 .88 .014],'String', ...
    '来源：Phase 0–3 architecture_calibration_summary.csv（原始四种，1,000 MC）；verification_round2 candidate_64_vs_72_CAL1_10000.csv（Impl-72，10,000 MC）。', ...
    'EdgeColor','none','FontSize',9,'Color',cfg.gray);
saveplot(f,cfg,'01_原始架构_CAL1面积与良率对比');
end

function fig02_integer_bridge_search(cfg)
T = readtable(fullfile(cfg.srcImpl,'csv','integer_bridge_coarse_search.csv'));
Tfine = readtable(fullfile(cfg.srcImpl,'csv','integer_bridge_fine_10k.csv'));
Ttop = readtable(fullfile(cfg.srcImpl,'csv','topR_pareto_probe.csv'));
r72 = Ttop(Ttop.topR_Cu==72 & Ttop.lowR1_Cu==256 & Ttop.botCap_Cu==1,:);

f = newfigure();
tiledlayout(f,1,2,'TileSpacing','compact','Padding','loose');
ax1 = nexttile; hold(ax1,'on');
cbVals = unique(T.Cb_Cu)'; bestPass = zeros(size(cbVals)); bestDnl = zeros(size(cbVals)); bestCap = zeros(size(cbVals));
for k=1:numel(cbVals)
    S = T(T.Cb_Cu==cbVals(k),:);
    [~,ord] = sortrows([-S.pass_yield,S.DNL_P99],[1 2]); rr = S(ord(1),:);
    bestPass(k) = 100*rr.pass_yield; bestDnl(k)=rr.DNL_P99; bestCap(k)=rr.total_cap_pF;
end
b = bar(ax1,cbVals,bestPass,.56,'FaceColor','flat'); b.CData = [cfg.red;cfg.teal];
set(ax1,'XTick',cbVals,'XLim',[min(cbVals)-.55 max(cbVals)+.55],'YLim',[0 105]); xlabel(ax1,'桥电容 C_b（Cu）'); ylabel(ax1,'该桥值下的最高 CAL1 通过率（%，128 MC）'); styleax(ax1,cfg);
for k=1:numel(cbVals)
    text(ax1,cbVals(k),bestPass(k)+3,sprintf('%.1f%%\nDNL P99 %.2f',bestPass(k),bestDnl(k)), ...
        'HorizontalAlignment','center','FontSize',10);
end
text(ax1,2,13,sprintf('Cb=2 是唯一保留\n高良率搜索空间的整数桥'),'HorizontalAlignment','center','FontSize',11,'FontWeight','bold','Color',cfg.teal);

ax2 = nexttile; hold(ax2,'on');
valid = Tfine.pass_yield>0.99;
scatter(ax2,Tfine.total_cap_pF(valid),Tfine.DNL_P99(valid),68,Tfine.topR_Cu(valid),'filled','MarkerEdgeColor','white');
scatter(ax2,r72.total_cap_pF,r72.DNL_P99,180,cfg.gold,'p','filled','MarkerEdgeColor',cfg.ink,'LineWidth',1.2);
h=yline(ax2,1,'--','DNL < 1 LSB 硬规格','Color',cfg.red,'LineWidth',1.4); h.HandleVisibility='off';
h=yline(ax2,.8,'--','0.8 LSB 工程裕量线','Color',cfg.orange,'LineWidth',1.4); h.HandleVisibility='off';
xlabel(ax2,'差分核心电容（pF）'); ylabel(ax2,'max |DNL| P99（LSB，10,000 MC）');
styleax(ax2,cfg); colormap(ax2,parula); cb=colorbar(ax2); cb.Label.String='topR（Cu）';
text(ax2,r72.total_cap_pF+0.3,r72.DNL_P99,sprintf('Impl-72\n%.1f pF, %.3f LSB',r72.total_cap_pF,r72.DNL_P99),'FontSize',10,'Color',cfg.ink);
annotation(f,'textbox',[.06 .91 .88 .07],'String', ...
    '图2  整数桥搜索：Cb=2 Cu 同时满足可实现性与搜索裕量；随后在其上用 topR 收敛 DNL。', ...
    'EdgeColor','none','FontSize',22,'FontWeight','bold','Color',cfg.ink);
annotation(f,'textbox',[.06 .004 .88 .014],'String', ...
    '左：integer_bridge_coarse_search.csv，4,125 个候选、128 MC；右：integer_bridge_fine_10k.csv 与 topR_pareto_probe.csv，仅显示通过 CAL1 的 10k 候选。', ...
    'EdgeColor','none','FontSize',9,'Color',cfg.gray);
saveplot(f,cfg,'02_整数桥搜索_Cb2可行区与面积_DNL前沿');
end

function fig03_topR_tradeoff(cfg)
T = readtable(fullfile(cfg.srcImpl,'csv','topR_pareto_probe.csv'));
T = sortrows(T,'topR_Cu');
f = newfigure();
tiledlayout(f,2,1,'TileSpacing','compact','Padding','loose');
ax1=nexttile; hold(ax1,'on');
plot(ax1,T.topR_Cu,T.DNL_P95,'o-','Color',cfg.blue,'MarkerFaceColor',cfg.blue,'DisplayName','DNL P95');
plot(ax1,T.topR_Cu,T.DNL_P99,'s-','Color',cfg.gold,'MarkerFaceColor',cfg.gold,'DisplayName','DNL P99');
h=yline(ax1,1,'--','硬规格：1 LSB','Color',cfg.red,'LineWidth',1.3); h.HandleVisibility='off'; h=yline(ax1,.8,'--','工程裕量：0.8 LSB','Color',cfg.orange,'LineWidth',1.3); h.HandleVisibility='off';
h=xline(ax1,64,':','64 Cu','Color',cfg.blue,'LineWidth',1.2); h.HandleVisibility='off'; h=xline(ax1,72,':','72 Cu','Color',cfg.gold,'LineWidth',1.2); h.HandleVisibility='off';
xlim(ax1,[20 76]); ylim(ax1,[.74 .98]); ylabel(ax1,'max |DNL|（LSB）'); legend(ax1,'Location','northeast','Box','off'); styleax(ax1,cfg);

ax2=nexttile; hold(ax2,'on');
plot(ax2,T.topR_Cu,T.INL_P95,'o-','Color',cfg.blue,'MarkerFaceColor',cfg.blue,'DisplayName','INL P95');
plot(ax2,T.topR_Cu,T.INL_P99,'s-','Color',cfg.gold,'MarkerFaceColor',cfg.gold,'DisplayName','INL P99');
h=yline(ax2,4,'--','硬规格：4 LSB','Color',cfg.red,'LineWidth',1.3); h.HandleVisibility='off';
h=xline(ax2,64,':','64 Cu','Color',cfg.blue,'LineWidth',1.2); h.HandleVisibility='off'; h=xline(ax2,72,':','72 Cu','Color',cfg.gold,'LineWidth',1.2); h.HandleVisibility='off';
xlim(ax2,[20 76]); ylim(ax2,[.55 .82]); xlabel(ax2,'TOP 冗余电容 topR（Cu）'); ylabel(ax2,'max |INL|（LSB）'); legend(ax2,'Location','northwest','Box','off'); styleax(ax2,cfg);
annotation(f,'textbox',[.06 .925 .88 .06],'String', ...
    '图3  topR 扫描：Impl-72 相比 Impl-64 多 2.4 pF，将 DNL P99 从 0.7977 降至 0.7771 LSB。', ...
    'EdgeColor','none','FontSize',22,'FontWeight','bold','Color',cfg.ink);
annotation(f,'textbox',[.06 .004 .88 .014],'String', ...
    '固定条件：Cb=2 Cu、lowR1=256 Cu、botCap=1 Cu、19 次判决。来源：topR_pareto_probe.csv，全部为 10,000 MC。', ...
    'EdgeColor','none','FontSize',9,'Color',cfg.gray);
saveplot(f,cfg,'03_topR扫描_DNL裕量与INL代价');
end

function fig04_cal1_distribution(cfg)
S = load(fullfile(cfg.srcR2,'raw','candidate_64_vs_72_CAL1_10000.mat'),'raw');
d64=S.raw.c1(:,9); d72=S.raw.c2(:,9); i64=S.raw.c1(:,10); i72=S.raw.c2(:,10);
f = newfigure();
tiledlayout(f,1,2,'TileSpacing','compact','Padding','loose');
ax1=nexttile; hold(ax1,'on'); plotecdf(ax1,d64,cfg.blue,'Impl-64'); plotecdf(ax1,d72,cfg.gold,'Impl-72');
q64=quantile(d64,.99); q72=quantile(d72,.99); h=xline(ax1,q64,':','64 P99','Color',cfg.blue); h.HandleVisibility='off'; h=xline(ax1,q72,':','72 P99','Color',cfg.gold); h.HandleVisibility='off';
xlim(ax1,[.68 .84]); ylim(ax1,[0 1]); xlabel(ax1,'每片 max |DNL|（LSB）'); ylabel(ax1,'累积概率'); legend(ax1,'Location','southeast','Box','off'); styleax(ax1,cfg);
ax1.YTickLabel = compose('%.0f%%',100*ax1.YTick);
text(ax1,.685,.14,sprintf('P99：64 = %.4f LSB\nP99：72 = %.4f LSB',q64,q72),'FontSize',11,'BackgroundColor',[1 .98 .93],'EdgeColor',[.92 .76 .46]);

ax2=nexttile; hold(ax2,'on'); plotecdf(ax2,i64,cfg.blue,'Impl-64'); plotecdf(ax2,i72,cfg.gold,'Impl-72');
q64=quantile(i64,.99); q72=quantile(i72,.99); h=xline(ax2,q64,':','64 P99','Color',cfg.blue); h.HandleVisibility='off'; h=xline(ax2,q72,':','72 P99','Color',cfg.gold); h.HandleVisibility='off';
xlim(ax2,[.65 .80]); ylim(ax2,[0 1]); xlabel(ax2,'每片 max |INL|（LSB）'); ylabel(ax2,'累积概率'); legend(ax2,'Location','southeast','Box','off'); styleax(ax2,cfg); ax2.YTickLabel=compose('%.0f%%',100*ax2.YTick);
text(ax2,.655,.14,sprintf('P99：64 = %.4f LSB\nP99：72 = %.4f LSB\n系统限值：4 LSB',q64,q72),'FontSize',11,'BackgroundColor',[.94 .98 .97],'EdgeColor',[.48 .75 .68]);
annotation(f,'textbox',[.06 .91 .88 .07],'String', ...
    '图4  逐芯片 10k 分布：72 的 DNL 分布整体左移；INL 略高但仍远离 4 LSB 限值。', ...
    'EdgeColor','none','FontSize',22,'FontWeight','bold','Color',cfg.ink);
annotation(f,'textbox',[.06 .004 .88 .014],'String', ...
    '来源：candidate_64_vs_72_CAL1_10000.mat 的逐芯片原始数据；CAL1 oracle 有效位权重构。', ...
    'EdgeColor','none','FontSize',9,'Color',cfg.gray);
saveplot(f,cfg,'04_Impl64_vs_Impl72_逐芯片CAL1_DNL_INL累积分布');
end

function fig05_local_transfer(cfg)
chips=[1 136 8697]; labels={'正常片：chip 1','典型微反转：chip 136','严重微反转：chip 8697'};
f=newfigure(); tiledlayout(f,3,1,'TileSpacing','compact','Padding','loose');
for k=1:3
    file=fullfile(cfg.srcR2,'raw',sprintf('diagnostic_BWAR-Impl-72_chip_%05d.mat',chips(k)));
    S=load(file,'rec'); r=S.rec;
    M=65536; vin=((r.interval_lo(:)+r.interval_hi(:))/2)*M;
    cal1=min(M-1,max(0,floor(M*(double(r.decision_bits)*r.actual_weights(:))+.5)));
    cal2=r.cal2_decoder_output(:);
    if r.n_down>0, center=r.down_positions(1); else, center=round(numel(vin)/2); end
    idx=max(1,center-20):min(numel(vin),center+22);
    ax=nexttile; hold(ax,'on');
    stairs(ax,vin(idx),cal1(idx),'Color',cfg.teal,'LineWidth',1.6,'DisplayName','CAL1：真实有效位权');
    stairs(ax,vin(idx),cal2(idx),'Color',cfg.red,'LineWidth',1.4,'DisplayName','CAL2：测得权重');
    if r.n_down>0
        p=center; plot(ax,vin(p:p+1),cal2(p:p+1),'o','Color',cfg.red,'MarkerFaceColor',cfg.red,'HandleVisibility','off');
        text(ax,mean(vin(p:p+1)),max(cal2(idx))+1,'1-code 反转','Color',cfg.red,'FontWeight','bold','HorizontalAlignment','center');
    end
    xlabel(ax,'输入位置（等效 LSB16）'); ylabel(ax,'输出码'); title(ax,sprintf('%s：n_{down} = %d，缺码 = %d',labels{k},r.n_down,r.missing_count));
    styleax(ax,cfg); grid(ax,'on');
    if k==1,legend(ax,'Location','northwest','Box','off');end
end
annotation(f,'textbox',[.06 .925 .88 .06],'String', ...
    '图5  Impl-72 的局部传输：CAL2 失败来自数字权重估计后的局部码序交换，而物理 SAR 区间连续。', ...
    'EdgeColor','none','FontSize',22,'FontWeight','bold','Color',cfg.ink);
annotation(f,'textbox',[.06 .004 .88 .014],'String', ...
    '来源：verification_round2/raw/diagnostic_BWAR-Impl-72_chip_*.mat；配置 σmeas=0.02 LSB，Navg=512。', ...
    'EdgeColor','none','FontSize',9,'Color',cfg.gray);
saveplot(f,cfg,'05_Impl72_CAL2微反转_代表芯片局部传输曲线');
end

function fig06_pdk_sensitivity(cfg)
SK=load(fullfile(cfg.srcR2,'raw','candidate_64_vs_72_CAL1_10000.mat'),'raw');
SP=load(fullfile(cfg.srcR2,'raw','candidate_64_vs_72_CAL1_PDK_10000.mat'),'raw');
datasets={SK.raw.c1(:,9),SK.raw.c2(:,9),SP.raw.c1(:,9),SP.raw.c2(:,9)};
datasetsI={SK.raw.c1(:,10),SK.raw.c2(:,10),SP.raw.c1(:,10),SP.raw.c2(:,10)};
labels={'64-K','72-K','64-PDK','72-PDK'};
Dmat=[datasets{1},datasets{2},datasets{3},datasets{4}];
Imat=[datasetsI{1},datasetsI{2},datasetsI{3},datasetsI{4}];
f=newfigure(); tiledlayout(f,1,2,'TileSpacing','compact','Padding','loose');
ax1=nexttile; boxplot(ax1,Dmat,'Labels',labels,'Symbol',''); hold(ax1,'on');
for k=1:4, scatter(ax1,k,quantile(datasets{k},.99),64, iff(mod(k,2)==1,cfg.blue,cfg.gold),'filled','MarkerEdgeColor',cfg.ink); end
h=yline(ax1,.8,'--','0.8 LSB 工程裕量','Color',cfg.orange); h.HandleVisibility='off'; ylabel(ax1,'每片 max |DNL|（LSB）'); styleax(ax1,cfg); ylim(ax1,[.68 .83]);
text(ax1,.65,.69,'圆点：P99','FontSize',10,'Color',cfg.gray);

ax2=nexttile; boxplot(ax2,Imat,'Labels',labels,'Symbol',''); hold(ax2,'on');
for k=1:4, scatter(ax2,k,quantile(datasetsI{k},.99),64, iff(mod(k,2)==1,cfg.blue,cfg.gold),'filled','MarkerEdgeColor',cfg.ink); end
h=yline(ax2,4,'--','INL < 4 LSB','Color',cfg.red); h.HandleVisibility='off'; ylabel(ax2,'每片 max |INL|（LSB）'); styleax(ax2,cfg); ylim(ax2,[.65 .82]);
annotation(f,'textbox',[.06 .91 .88 .07],'String', ...
    '图6  失配模型敏感性：PDK σ 从 1.6326% 提高到 1.67487% 后，64/72 的 CAL1 分布仍保持规格裕量。', ...
    'EdgeColor','none','FontSize',22,'FontWeight','bold','Color',cfg.ink);
annotation(f,'textbox',[.06 .004 .88 .014],'String', ...
    '每组 10,000 MC；圆点为 P99。来源：candidate_64_vs_72_CAL1_10000.mat 与 candidate_64_vs_72_CAL1_PDK_10000.mat。', ...
    'EdgeColor','none','FontSize',9,'Color',cfg.gray);
saveplot(f,cfg,'06_K模型_vs_PDK失配_逐芯片DNL_INL箱线图');
end

function fig07_calibration_levels(cfg)
Scal1=load(fullfile(cfg.srcR2,'raw','candidate_64_vs_72_CAL1_10000.mat'),'raw');
Scal2=load(fullfile(cfg.srcR2,'raw','candidate_64_vs_72_CAL2_A_10000.mat'),'raw');
Tdec=readtable(fullfile(cfg.srcR2,'csv','decoder_ABC_debug100_oracleSparse.csv'));
cal0=100*mean(Scal1.raw.c2(:,5)); cal1=100*mean(Scal1.raw.c2(:,13)); cal2a=100*mean(Scal2.raw.c2(:,5));
tb=Tdec(strcmp(string(Tdec.candidate),'BWAR-Impl-72'),:);
getpass=@(s) 100*tb.pass_yield(strcmp(string(tb.decoder),s));
values=[cal0 cal1 cal2a getpass('B_oracle_upper_bound') getpass('C_sparse_raw_vector')];
labs={'CAL0','CAL1 oracle','CAL2-A','CAL2-B','CAL2-C'};
ns=[10000 10000 10000 100 100];
f=newfigure(); ax=axes(f,'Position',[.10 .18 .82 .62]);
b=bar(ax,1:5,values,.64,'FaceColor','flat'); b.CData=[cfg.gray;cfg.teal;cfg.red;cfg.gold;cfg.red];
hold(ax,'on'); h=yline(ax,99,'--','99% 目标','Color',cfg.red,'LineWidth',1.7,'LabelHorizontalAlignment','left'); h.HandleVisibility='off';
set(ax,'XTick',1:5,'XTickLabel',labs,'YLim',[0 105],'XTickLabelRotation',0); ylabel(ax,'联合通过率（%）'); styleax(ax,cfg);
for k=1:5,text(ax,k,values(k)+3,sprintf('%.2f%%\nn=%d',values(k),ns(k)),'HorizontalAlignment','center','FontSize',10);end
text(ax,3,9,'A/C：仅 19 个测得位权','HorizontalAlignment','center','FontSize',9,'Color',cfg.red,'FontWeight','bold');
text(ax,4,9,'B：真实区间顺序的诊断上界','HorizontalAlignment','center','FontSize',9,'Color',cfg.gold,'FontWeight','bold');
annotation(f,'textbox',[.06 .91 .88 .07],'String', ...
    '图7  校准层级的证据边界：CAL1 证明 CDAC 物理可行；当前可实现 CAL2 decoder 仍未跨过 99% 门。', ...
    'EdgeColor','none','FontSize',22,'FontWeight','bold','Color',cfg.ink);
annotation(f,'textbox',[.06 .004 .88 .014],'String', ...
    'Impl-72。CAL0/CAL1/CAL2-A 为 10,000 MC；decoder B/C 为 100 颗诊断。B 不是片上可实现 decoder。', ...
    'EdgeColor','none','FontSize',9,'Color',cfg.gray);
saveplot(f,cfg,'07_Impl72_CAL0_CAL1_CAL2解码器层级良率对比');
end

function fig08_averaging_tradeoff(cfg)
T=readtable(fullfile(cfg.srcImpl,'csv','practical_cal2.csv'));
T=T(abs(T.sigma_meas_LSB-.02)<1e-12 & abs(T.Vos_cal_LSB)<1e-12,:); T=sortrows(T,'Navg');
f=newfigure(); tiledlayout(f,1,2,'TileSpacing','compact','Padding','loose');
ax1=nexttile; hold(ax1,'on');
plot(ax1,T.Navg,100*T.pass_yield,'o-','Color',cfg.blue,'MarkerFaceColor',cfg.blue,'DisplayName','联合通过率');
plot(ax1,T.Navg,100*T.monotonic_yield,'s-','Color',cfg.teal,'MarkerFaceColor',cfg.teal,'DisplayName','单调良率');
h=yline(ax1,99,'--','99% 目标','Color',cfg.red,'LineWidth',1.5); h.HandleVisibility='off'; set(ax1,'XScale','log','XTick',T.Navg,'XTickLabel',string(T.Navg),'YLim',[25 102]);
xlabel(ax1,'每个权重的重复平均次数 Navg（log2）'); ylabel(ax1,'良率（%）'); legend(ax1,'Location','southeast','Box','off'); styleax(ax1,cfg);
text(ax1,512,95.8,'94.8%','HorizontalAlignment','center','Color',cfg.blue,'FontWeight','bold');

ax2=nexttile; hold(ax2,'on');
semilogy(ax2,T.Navg,T.mean_down_transitions,'o-','Color',cfg.orange,'MarkerFaceColor',cfg.orange);
set(ax2,'XScale','log','XTick',T.Navg,'XTickLabel',string(T.Navg)); xlabel(ax2,'每个权重的重复平均次数 Navg（log2）'); ylabel(ax2,'每片平均下降码对数（对数刻度）'); styleax(ax2,cfg);
text(ax2,350,2,sprintf('Navg = 512：\n19 × 512 × 2 = 19,456\n次比较器判决（下限）'),'FontSize',11,'BackgroundColor',[1 .98 .93],'EdgeColor',[.92 .76 .46]);
annotation(f,'textbox',[.06 .91 .88 .07],'String', ...
    '图8  前台校准代价：重复平均降低白噪，但严格单调性仍把少量微反转放大为良率损失。', ...
    'EdgeColor','none','FontSize',22,'FontWeight','bold','Color',cfg.ink);
annotation(f,'textbox',[.06 .004 .88 .014],'String', ...
    '来源：practical_cal2.csv；Impl-72，每点 500 MC，σmeas=0.02 LSB、无系统偏置。10k 最终复验见图7。', ...
    'EdgeColor','none','FontSize',9,'Color',cfg.gray);
saveplot(f,cfg,'08_CAL2重复平均_良率与微反转计数');
end

function f=newfigure()
f=figure('Visible','off','Position',[80 80 1920 1080],'Color','w','Renderer','opengl');
end

function styleax(ax,cfg)
grid(ax,'on'); ax.GridColor=cfg.grid; ax.GridAlpha=.9; ax.Box='off'; ax.LineWidth=.9; ax.TickDir='out';
ax.XColor=cfg.ink; ax.YColor=cfg.ink;
end

function plotecdf(ax,x,c,name)
x=sort(x(:)); y=(1:numel(x))'/numel(x); plot(ax,x,y,'Color',c,'LineWidth',2.1,'DisplayName',name);
end

function saveplot(f,cfg,stem)
drawnow;
exportgraphics(f,fullfile(cfg.figDir,[stem '.png']),'Resolution',220,'BackgroundColor','white');
savefig(f,fullfile(cfg.figDir,[stem '.fig']));
close(f);
end

function out=iff(cond,a,b)
if cond,out=a;else,out=b;end
end

function write_manifest(cfg)
names = {'01_原始架构_CAL1面积与良率对比'; ...
    '02_整数桥搜索_Cb2可行区与面积_DNL前沿'; ...
    '03_topR扫描_DNL裕量与INL代价'; ...
    '04_Impl64_vs_Impl72_逐芯片CAL1_DNL_INL累积分布'; ...
    '05_Impl72_CAL2微反转_代表芯片局部传输曲线'; ...
    '06_K模型_vs_PDK失配_逐芯片DNL_INL箱线图'; ...
    '07_Impl72_CAL0_CAL1_CAL2解码器层级良率对比'; ...
    '08_CAL2重复平均_良率与微反转计数'};
T=table(string(names),repmat("MATLAB",8,1),repmat("PNG + FIG",8,1), ...
    'VariableNames',{'figure','renderer','outputs'});
writetable(T,fullfile(cfg.dataDir,'figure_manifest.csv'));
end

% ============================================================================
% make_figures.m —— 由实测结果生成科学绘图(从不使用 CAL2 占位数据)
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的“可视化”生成器。把汇总 S、回归 reg、全部数据 allData
%       画成 DNL/INL P99、三项良率、电容/判决成本、可达区间 CDF、静态回归等图，
%       并挑代表芯片存档 .mat 与子图，最后写 representative_chips.csv。
% 输入  ：cfg；S —— 汇总表；reg —— 回归表；allData —— 4 架构各自的 MC 数据元胞
% 输出  ：无(写 figures/ 与 raw/ 与 csv/)
% 关键算法：每组图 reshape 成 (4架构×2模式)；非单调的 Inf 用 replace_invalid
%       转 NaN 并在图上标“invalid”；代表芯片按 CAL1 的 DNL(median/P99/worst)选。
% ============================================================================
function make_figures(cfg,S,reg,allData)
% Scientific plots from executed MATLAB results, never placeholder CAL2 data.
names=cfg.architectures; colors=[.10 .40 .70;.04 .55 .47];  % 架构名；两种校准模式 CAL0/CAL1 的配色
for metric={'DNL','INL'}
    key=metric{1};v=reshape(S.([key '_max_P99']),2,4)';
    f=newfig();b=bar(replace_invalid(v),'grouped');
    for j=1:2,b(j).FaceColor=colors(j,:);end
    set(gca,'XTick',1:4,'XTickLabel',names);ylabel(['P99 max |' key '| (LSB)']);
    title(['ADC output ' key ': exact thresholds, 1,000 dies']);
    legend('CAL0','CAL1','Location','northwest');grid on;
    y=max(1,max(v(isfinite(v))));if isempty(y),y=1;end
    ylim([0 y*1.35]);
    for k=1:4,for j=1:2
        if ~isfinite(v(k,j))
            text(k+(j-1.5)*.28,y*.8-(j-1)*y*.14,sprintf('CAL%d: invalid',j-1),...
                'HorizontalAlignment','center','Rotation',90,'FontSize',9);
        end
    end,end
    subtitle('Invalid = nonmonotonic dies affect P99; no finite DNL/INL is fabricated');
    savefigout(f,cfg,['01_' key '_P99']);
end
fields={'missing_code_yield','spec_pass_yield','monotonic_yield'};
labels={'Zero-missing-code yield','Joint specification pass yield','Monotonic-output yield'};
for i=1:3
    f=newfig();v=reshape(S.(fields{i}),2,4)';b=bar(v,'grouped');
    for j=1:2,b(j).FaceColor=colors(j,:);end
    set(gca,'XTick',1:4,'XTickLabel',names);ylim([0 110]);ylabel('Yield (%)');
    title(labels{i});subtitle('1,000 dies each; CAL2 not run');legend('CAL0','CAL1');grid on;
    for k=1:4,for j=1:2,text(k+(j-1.5)*.28,v(k,j)+3,sprintf('%.1f%%',v(k,j)),...
                'HorizontalAlignment','center','FontSize',10);end,end
    savefigout(f,cfg,sprintf('0%d_%s',i+2,fields{i}));
end
f=newfig();tiledlayout(1,2);
nexttile;bar(S.total_cap_pF(1:2:end),'FaceColor',colors(1,:));
set(gca,'YScale','log','XTick',1:4,'XTickLabel',names);ylabel('Differential core C (pF, log scale)');
title('Physical capacitor cost');grid on;
nexttile;bar(S.decision_count(1:2:end),'FaceColor',colors(2,:));
set(gca,'XTick',1:4,'XTickLabel',names);ylim([0 22]);ylabel('Comparisons / conversion');title('Search cost');grid on;
savefigout(f,cfg,'06_capacitance_and_decisions');
f=newfig();hold on;
for k=1:4
    x=sort(allData{k}(:,15));plot(x,(1:numel(x))/numel(x),'LineWidth',1.8);
end
xline(cfg.M,'--','65536 codes required');xlabel('Reachable input intervals per die');ylabel('Empirical CDF');
title('Information available before any digital decoder');legend(names,'Location','northwest');grid on;
savefigout(f,cfg,'07_reachable_regions');
f=newfig();sel=reg.MC_runs==max(reg.MC_runs);bar([reg.P99(sel) reg.target_q99(sel)]);
set(gca,'XTick',1:4,'XTickLabel',names);ylabel('STATIC DAC max |DNL| P99 (LSB)');
title('Historical static regression only - not ADC output DNL');legend('This MATLAB run','Historical 100k target');grid on;
savefigout(f,cfg,'08_static_regression');

% Representative CAL1 dies: selection rule is explicit and deterministic.
rep=struct([]);  % 代表芯片索引表(确定性挑选)
for k=1:4
    a=architecture_definition(names{k},cfg);nom=realize_architecture(a,cfg,0);data=allData{k};  % 第 k 架构
    if all(isfinite(data(:,9)))
        [~,order]=sortrows([data(:,9) (1:size(data,1))'],[1 2]);rule='CAL1 max DNL';  % DNL 全有限→按 CAL1 DNL 排序
    else
        [~,order]=sortrows([data(:,11) (1:size(data,1))'],[1 2]);rule='CAL1 missing count (DNL invalid)';  % 否则按缺码数排序
    end
    ii=[ceil(.5*numel(order)) ceil(.99*numel(order)) numel(order)];tags={'median','P99','worst'};  % 取中位/P99/最差三档芯片
    for j=1:3
        chip=order(ii(j));real=realize_architecture(a,cfg,chip);t=transfer_tree(a,real,nom,cfg);  % 该代表芯片建树
        [m,curve]=adc_metrics(t,t.code1,a,cfg);
        stem=sprintf('%s_CAL1_%s_chip%d',a.name,tags{j},chip);
        save(fullfile(cfg.outputRoot,'raw',[stem '.mat']),'a','real','nom','t','m','curve','chip','rule');  % 存原始数据供审计
        row.architecture=string(a.name);row.selection=string(tags{j});row.rule=string(rule);row.chip=chip;
        row.seed=cfg.seedMC+100000*k+chip;row.valid_thresholds=curve.valid;row.missing=m(3);
        if isempty(rep),rep=row;else,rep(end+1)=row;end %#ok<AGROW>
        f=newfig();tiledlayout(2,1);
        if curve.valid
            nexttile;plot(1:cfg.M-1,curve.INL);ylabel('INL (LSB)');grid on;
            title(sprintf('%s CAL1 %s: die %d',a.name,tags{j},chip));
            nexttile;plot(1:cfg.M-2,curve.DNL);ylabel('DNL (LSB)');xlabel('Code');grid on;
        else
            nexttile;plot((t.lo+t.hi)/2,t.code1,'.','MarkerSize',2);ylabel('Output code');grid on;
            title(sprintf('%s CAL1 %s: die %d, NONMONOTONIC',a.name,tags{j},chip));
            nexttile;plot(0:cfg.M-1,curve.widths/a.lsb);ylabel('Total occupancy / nominal LSB');xlabel('Code');grid on;
            subtitle('Occupancy is a diagnostic, not conventional DNL');
        end
        savefigout(f,cfg,['representative_' stem]);
    end
end
writetable(struct2table(rep),fullfile(cfg.outputRoot,'csv','representative_chips.csv'));
end
function f=newfig()
f=figure('Visible','off','Color','w','Position',[100 100 1120 640]);  % 后台不可见图窗
end
function x=replace_invalid(x)
x(~isfinite(x))=NaN;  % 非单调的 Inf 转 NaN，让绘图自动留空(标 invalid)
end
function savefigout(f,cfg,name)
exportgraphics(f,fullfile(cfg.outputRoot,'figures',[name '.png']),'Resolution',150);  % 导出 150dpi PNG
savefig(f,fullfile(cfg.outputRoot,'figures',[name '.fig']));close(f);  % 另存 .fig 并关闭
end

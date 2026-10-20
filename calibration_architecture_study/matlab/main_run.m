% ============================================================================
% main_run.m —— Phase 0–3 一键主入口（地基阶段总编排）
% ----------------------------------------------------------------------------
% 角色：把“定义→实现→转换→校准→统计→报告”串成一条流水线，一键复现全文数字。
% 流水线阶段（与文件名 PHASE 对应）：
%   · 准备：设输出根目录（已存在则新建 reruns 时间戳子目录，绝不改写旧结果）、建子目录、开 diary 日志。
%   · 闸门口：run_core_tests 跑硬闸门单元测试（理想16bit/标称架构/CAL1/阈值/可复现MC/桥矩阵）。
%   · Phase 1：静态 DAC DNL 回归（legacy_static_dnl），与资料目标值比对，写 CAL0_static_regression。
%   · Phase 2：四种架构标称（无失配）下，transfer_tree + adc_metrics 求 CAL0/CAL1 名义指标。
%   · Phase 3：run_mc 蒙特卡洛（两档 mcStages），逐芯片统计；summarize_mc 出分位数与良率。
%   · 收尾：写汇总 CSV/JSON、存 phase03_results.mat、make_figures_svg 出图、write_summary_reports 出报告。
% 注意：随机流按 archIndex(1..4) 错开；本阶段不含 CAL2/优化/动态/Spectre。
% ============================================================================
function main_run()
% One-click Phase 0--3 study. Never changes an earlier output directory.
here=fileparts(mfilename('fullpath'));addpath(genpath(here));cfg=config_default();
cfg.outputRoot=cfg.studyRoot;
if isfile(fullfile(cfg.outputRoot,'csv','architecture_calibration_summary.csv'))
    cfg.outputRoot=fullfile(cfg.studyRoot,'reruns',char(datetime('now','Format','yyyyMMdd_HHmmss')));
end
for d={'raw','csv','figures','reports','logs'}
    if ~isfolder(fullfile(cfg.outputRoot,d{1})),mkdir(fullfile(cfg.outputRoot,d{1}));end
end
diary(fullfile(cfg.outputRoot,'logs','matlab_run.log'));clean=onCleanup(@()diary('off'));
fprintf('PHASE 0--3 START %s\n',char(datetime('now')));
metadata.matlab=version;metadata.computer=computer;
metadata.cpu=getenv('PROCESSOR_IDENTIFIER');metadata.logicalProcessors=getenv('NUMBER_OF_PROCESSORS');
metadata.seedRaw=cfg.seedRaw;metadata.seedMC=cfg.seedMC;
metadata.userScope='Phase 0--3 only; no CAL2, optimization, dynamics, Spectre or Virtuoso';
metadata.started=char(datetime('now'));

% The ideal and nominal tests are hard gates before any MC.
tests=run_core_tests(cfg);  % 硬闸门：任何蒙特卡洛之前先过的单元测试
rawRows=struct([]); last=zeros(1,4);
for n=cfg.rawStages
    for k=1:4
        a=architecture_definition(cfg.architectures{k},cfg);clock=tic;
        values=legacy_static_dnl(a,cfg,n);elapsed=toc(clock);
        q=quantile_linear(values,[.5 .95 .99]);  % 静态 DAC DNL 的 P50/P95/P99 分位数
        row.architecture=string(a.name);row.metric="STATIC_DAC_DNL";row.MC_runs=n;
        row.P50=q(1);row.P95=q(2);row.P99=q(3);row.target_q99=cfg.targets(k);
        row.relative_error=abs(q(3)-cfg.targets(k))/cfg.targets(k);
        row.seed=cfg.seedRaw;row.runtime_s=elapsed;
        if isempty(rawRows),rawRows=row;else,rawRows(end+1)=row;end %#ok<AGROW>
        last(k)=q(3);
        save(fullfile(cfg.outputRoot,'raw',sprintf('static_%s_%d.mat',a.name,n)),'values');
        fprintf('STATIC %s n=%d q99=%.8f target=%.8f deviation=%.2f%%\n',a.name,n,q(3),cfg.targets(k),100*row.relative_error);
    end
end
reg=struct2table(rawRows);writetable(reg,fullfile(cfg.outputRoot,'csv','CAL0_static_regression.csv'));
write_regression_report(cfg,reg);
test_CAL0_regression(cfg,last);tests{end+1}='test_CAL0_regression';
fprintf('PHASE 1 REGRESSION GATE PASSED\n');

cfg.useParallel=cfg.useParallel&&license('test','Distrib_Computing_Toolbox');
if cfg.useParallel
    try
        pool=gcp('nocreate');if isempty(pool),pool=parpool('Threads',cfg.workers);end
        metadata.parallel=class(pool);metadata.workers=pool.NumWorkers;
    catch e
        fprintf('Parallel pool unavailable: %s; using serial.\n',e.message);
        cfg.useParallel=false;metadata.parallel='serial';metadata.workers=1;
    end
else
    metadata.parallel='serial';metadata.workers=1;
end

nomRows=struct([]);allData=cell(1,4);times=zeros(1,4);
for k=1:4
    name=cfg.architectures{k};a=architecture_definition(name,cfg);r=realize_architecture(a,cfg,0);  % 定义 + 标称（chip=0，无失配）实现
    t=transfer_tree(a,r,r,cfg);  % 精确判决树：标称下 code0/code1 两种解码
    for mode=0:1
        code=t.(sprintf('code%d',mode));[m,curve]=adc_metrics(t,code,a,cfg);
        nr.architecture=string(name);nr.calibration_mode=string(sprintf('CAL%d',mode));
        nr.DNL_max=m(1);nr.INL_max=m(2);nr.missing_count=m(3);nr.monotonic=m(4);
        nr.regions=m(7);nr.down_transitions=m(8);
        if isempty(nomRows),nomRows=nr;else,nomRows(end+1)=nr;end %#ok<AGROW>
        save(fullfile(cfg.outputRoot,'raw',sprintf('nominal_%s_CAL%d.mat',name,mode)),'t','curve','m');
        if curve.valid
            writetable(table((1:cfg.M-1)',curve.thresholds,'VariableNames',{'code','threshold'}),...
                fullfile(cfg.outputRoot,'csv',sprintf('nominal_%s_CAL%d_thresholds.csv',name,mode)));
        end
    end
end
nominal=struct2table(nomRows);writetable(nominal,fullfile(cfg.outputRoot,'csv','nominal_ADC_summary.csv'));

for n=cfg.mcStages
    for k=1:4
        name=cfg.architectures{k};[data,elapsed]=run_mc(name,cfg,n,allData{k});  % Phase 3：蒙特卡洛，逐芯片跑转换+指标
        allData{k}=data;times(k)=times(k)+elapsed;
        save(fullfile(cfg.outputRoot,'raw',sprintf('ADC_%s_%d.mat',name,n)),'data','cfg');
        fprintf('ADC %s n=%d elapsed=%.2fs CAL0 pass=%.2f%% CAL1 pass=%.2f%% zero-missing=%.2f%% monotonic=%.2f%% regions median=%.0f\n',...
            name,n,elapsed,100*mean(data(:,5)),100*mean(data(:,13)),100*mean(data(:,11)==0),100*mean(data(:,12)),median(data(:,15)));
    end
end

rows=struct([]);
for k=1:4
    name=cfg.architectures{k};data=allData{k};
    for mode={'CAL0','CAL1'}
        sr=summarize_mc(name,mode{1},data,cfg,times(k));
        if isempty(rows),rows=sr;else,rows(end+1)=sr;end %#ok<AGROW>
    end
    cols={'DNL_CAL0','INL_CAL0','missing_CAL0','mono_CAL0','pass_CAL0','occupancyDNL_CAL0','regions_CAL0','down_CAL0',...
        'DNL_CAL1','INL_CAL1','missing_CAL1','mono_CAL1','pass_CAL1','occupancyDNL_CAL1','regions_CAL1','down_CAL1'};
    tab=array2table(data,'VariableNames',cols);tab.chip=(1:size(data,1))';
    tab.seed=cfg.seedMC+100000*k+tab.chip;
    writetable(tab,fullfile(cfg.outputRoot,'csv',sprintf('ADC_%s_per_chip.csv',name)));
end
summary=struct2table(rows);writetable(summary,fullfile(cfg.outputRoot,'csv','architecture_calibration_summary.csv'));
metadata.finished=char(datetime('now'));metadata.testsPassed=tests;
metadata.conditionalMetrics='finite_* columns exclude nonmonotonic dies and MUST NOT be used as unconditional yield';  % 条件指标（finite_*）排除了非单调芯片，不可当作无条件和良率
fid=fopen(fullfile(cfg.outputRoot,'logs','run_metadata.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(metadata,PrettyPrint=true));fclose(fid);
save(fullfile(cfg.outputRoot,'raw','phase03_results.mat'),'summary','nominal','reg','allData','cfg','metadata');
make_figures_svg(cfg,summary,reg,allData);
write_summary_reports(cfg,summary,nominal,reg,metadata);
fprintf('PHASE 3 COMPLETE. STOPPING AS REQUESTED. Outputs: %s\n',cfg.outputRoot);
end

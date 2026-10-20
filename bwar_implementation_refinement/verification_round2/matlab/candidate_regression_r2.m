% candidate_regression_r2.m — 第二轮验证：两候选架构(BWAR-Impl-64/72)的配对 CAL1/CAL2 回归
% 角色：对 topR=64 与 topR=72 两架构，分别在 K 模型与 PDK 失配下跑 CAL1(100/1000/10000)，并对 CAL2 做 10k 诊断。
% 模式 mode：'debug'(100)/'regression'(1000)/'final'(10000)/'cal2final'(仅 CAL2)/'all'。
% 设计：复用主项目引擎(bwar_build/run_mc_impl)与本轮 config_round2；结果按 n 与 PDK/CAL2 分文件落盘。
function out = candidate_regression_r2(mode)
% 缺省 mode='all'，即跑 debug+regression+final 三档 MC 并完成 PDK 与 CAL2 评估
% Paired CAL1/CAL2 regression for exactly the two requested architectures.
% mode = 'debug', 'regression', 'final', 'all', or 'cal2final'.
if nargin < 1, mode = 'all'; end
% 加载本轮独立配置（含候选列表、MC 规模、校准参数）
cfg = config_round2();
% 按 mode 决定要跑的 MC 次数向量（debug/regression/final/cal2final 单独，all 全跑）
switch lower(mode)
    case 'debug',      runCounts = cfg.debugMC;
    case 'regression', runCounts = cfg.regressionMC;
    case 'final',      runCounts = cfg.finalMC;
    case 'cal2final',  runCounts = [];
    case 'all',        runCounts = [cfg.debugMC cfg.regressionMC cfg.finalMC];
    otherwise, error('Unknown mode %s', mode);
end
out = struct();
% 对每个 MC 次数 n，分别评估两个候选的 CAL1 并汇总
for n = runCounts
    rows = struct([]); raw = struct();
    for ci = 1:numel(cfg.candidates)
        c = cfg.candidates(ci);
        % 去掉候选的 name 字段后构建架构 a（name 仅用于报告）
        a = bwar_build(rmfield(c,'name'), cfg);
        % 名义（无失配, seed=0）CAL1 指标，作为对照基线
        nominal = cal1_one(a, cfg, 0);
        % 跑 n 颗 MC 的 CAL1 仿真，返回 16 列指标矩阵 data
        [data, elapsed] = run_mc_impl(a, cfg, n);
        raw.(sprintf('c%d',ci)) = data;
        % 汇总成一行（模型标注 K_model，区别于下面的 PDK_sigma）
        r = summarize_cal1(c, a, nominal, data, elapsed, n, 'K_model');
        if isempty(rows), rows = r; else, rows(end+1) = r; end %#ok<AGROW>
    end
    T = struct2table(rows);
    % 写出该 n 档的 CAL1 对比 csv（candidate_64_vs_72_CAL1_<n>.csv）
    writetable(T, fullfile(cfg.implRoot,'csv',sprintf('candidate_64_vs_72_CAL1_%d.csv',n)));
    save(fullfile(cfg.implRoot,'raw',sprintf('candidate_64_vs_72_CAL1_%d.mat',n)), 'cfg','T','raw','-v7.3');
    out.(sprintf('n%d',n)) = T;
end
% 若包含 'all' 或 'final'：额外在 PDK 失配(σPDK)下跑 10k CAL1 评估最坏工艺角
if any(strcmpi(mode, {'all','final'}))
    rows = struct([]); raw = struct();
    % 用 PDK 实测失配比例放大 σ，构造最坏工艺角配置 cfgP
    cfgP = cfg; cfgP.sigmaScale = cfg.sigmaPDK_scale;
    for ci = 1:numel(cfg.candidates)
        c = cfg.candidates(ci);
        % 在 PDK 失配下构建同一架构
        a = bwar_build(rmfield(c,'name'), cfgP);
        nominal = cal1_one(a, cfgP, 0);
        [data, elapsed] = run_mc_impl(a, cfgP, cfg.finalMC);
        raw.(sprintf('c%d',ci)) = data;
        r = summarize_cal1(c, a, nominal, data, elapsed, cfg.finalMC, 'PDK_sigma');
        if isempty(rows), rows = r; else, rows(end+1) = r; end %#ok<AGROW>
    end
    T = struct2table(rows);
    % 写出 PDK 角 10k CAL1 对比 csv
    writetable(T, fullfile(cfg.implRoot,'csv','candidate_64_vs_72_CAL1_PDK_10000.csv'));
    save(fullfile(cfg.implRoot,'raw','candidate_64_vs_72_CAL1_PDK_10000.mat'), 'cfgP','T','raw','-v7.3');
    % 把 PDK 角结果存入 out.PDK
    out.PDK = T;
end
% 若包含 'all' 或 'cal2final'：对每个候选跑 10k 颗 CAL2（前台校准解码）诊断
if any(strcmpi(mode, {'all','cal2final'}))
    rows = struct([]); raw = struct();
    for ci = 1:numel(cfg.candidates)
        c = cfg.candidates(ci);
        % 去掉 name 后构建架构 a（CAL2 诊断用，标准 K 模型）
        a = bwar_build(rmfield(c,'name'), cfg);
        % 预分配 CAL2 结果矩阵（每芯片 11 列：指标 + σ_cal + 下降数 + 物理连续标志）
        data = zeros(cfg.finalMC, 11);
        for chip = 1:cfg.finalMC
            % 对单颗芯片执行完整 CAL2 流程（带噪测量平均→解码→指标）
            d = cal2_one(a, cfg, chip);
            data(chip,:) = [d.m d.sigmaCal d.nDown d.physicalContinuous];
        end
        raw.(sprintf('c%d',ci)) = data;
        r = summarize_cal2(c, a, data, cfg);
        if isempty(rows), rows = r; else, rows(end+1) = r; end %#ok<AGROW>
    end
    T = struct2table(rows);
    % 写出 CAL2 诊断对比 csv（candidate_64_vs_72_CAL2_A_10000.csv）
    writetable(T, fullfile(cfg.implRoot,'csv','candidate_64_vs_72_CAL2_A_10000.csv'));
    save(fullfile(cfg.implRoot,'raw','candidate_64_vs_72_CAL2_A_10000.mat'), 'cfg','T','raw','-v7.3');
    % 把 CAL2 结果存入 out.CAL2
    out.CAL2 = T;
end
end
% cal1_one：单颗芯片的 CAL1 名义指标（构建带失配芯片→传输树→adc_metrics(code1)）

function m = cal1_one(a,cfg,chip)
% 实例化第 chip 颗带随机失配的电容权重
real = realize_variant(a,cfg,chip);
t = transfer_tree_gen(a,real,cfg);
% 计算该芯片 CAL1（code1，前台校准码）的 5 项指标 [DNL INL missing monotonic pass]
m = adc_metrics(t,t.code1,a,cfg);
end
% cal2_one：单颗芯片的完整 CAL2 前台校准流程（测量平均→解码→统计物理连续性与下降）

function d = cal2_one(a,cfg,chip)
% 实例化第 chip 颗带随机失配的电容权重
real = realize_variant(a,cfg,chip);
t = transfer_tree_gen(a,real,cfg);
% 把判决向量展开成 K 位布尔矩阵，供重建码使用
bits = unpack_bits(t.raw,a.decisions);
st = RandStream('mt19937ar','Seed',cfg.calSeed + chip);
% CAL2 测量噪声：σ=cal2SigmaLSB、每权重测 cal2Navg=512 次
noise = cfg.cal2SigmaLSB*a.lsb*randn(st,a.decisions,cfg.cal2Navg);
% 前台校准估计权重 wHat = 真实权重 + 噪声平均
wHat = real.decW(:) + mean(noise,2);
% 用估计权重解码成输出码（clamp 到 [0,M-1]）
code = min(cfg.M-1,max(0,floor(cfg.M*(bits*wHat)+.5)));
d.m = adc_metrics(t,code,a,cfg);
% 记录校准估计误差 σ_cal（按 LSB），验证随平均下降的规律
d.sigmaCal = std(wHat-real.decW(:))/a.lsb;
d.nDown = sum(diff(code)<0);
% 物理连续性标志：判决区间是否无缝覆盖全量程（无不可达输入）
d.physicalContinuous = is_continuous(t,a,cfg);
end
% summarize_cal1：把单候选的 CAL1 MC 矩阵压成一行统计（含名义/条件 P50-P99/严格 P99/各类失败计数）

function r = summarize_cal1(c,a,nominal,data,elapsed,n,model)
% 取 CAL1 的 5 列指标，标记有限值（未缺码且 INL 有限）用于条件分位数
m = data(:,9:13); f = isfinite(m(:,1)) & isfinite(m(:,2));
q = [NaN NaN NaN]; qi = q;
if any(f), q = quantile_linear(m(f,1),[.5 .95 .99]); qi = quantile_linear(m(f,2),[.5 .95 .99]); end
r = base_row(c,a,n,model);
% 记录名义（无失配）基线指标，便于与 MC 结果对比退化量
r.nominal_DNL = nominal(1); r.nominal_INL = nominal(2); r.nominal_missing = nominal(3); r.nominal_monotonic = nominal(4);
r.DNL_P50_cond = q(1); r.DNL_P95_cond = q(2); r.DNL_P99_cond = q(3);
r.INL_P50_cond = qi(1); r.INL_P95_cond = qi(2); r.INL_P99_cond = qi(3);
r.DNL_P99_strict = quantile_linear(m(:,1),.99); r.INL_P99_strict = quantile_linear(m(:,2),.99);
r.missing_code_yield = mean(m(:,3)==0); r.monotonic_yield = mean(m(:,4)); r.pass_yield = mean(m(:,5));
r.fail_missing = sum(m(:,3)~=0); r.fail_nonmonotonic = sum(~m(:,4));
r.fail_dnl = sum(m(:,4) & m(:,3)==0 & m(:,1)>=1); r.fail_inl = sum(m(:,4) & m(:,3)==0 & m(:,2)>=4);
r.runtime_s = elapsed;
end
% summarize_cal2：把单候选的 CAL2 MC 矩阵压成一行（含 σ_cal、下降跳变、物理连续良率）

function r = summarize_cal2(c,a,data,cfg)
m = data(:,1:5); f = isfinite(m(:,1)) & isfinite(m(:,2));
q = [NaN NaN NaN]; qi = q;
if any(f), q = quantile_linear(m(f,1),[.5 .95 .99]); qi = quantile_linear(m(f,2),[.5 .95 .99]); end
r = base_row(c,a,size(data,1),'K_model');
% 记录本 CAL2 配置的测量噪声与平均次数（来自 config_round2）
r.sigma_meas_LSB = cfg.cal2SigmaLSB; r.Navg = cfg.cal2Navg;
r.DNL_P50_cond = q(1); r.DNL_P95_cond = q(2); r.DNL_P99_cond = q(3);
r.INL_P50_cond = qi(1); r.INL_P95_cond = qi(2); r.INL_P99_cond = qi(3);
r.DNL_P99_strict = quantile_linear(m(:,1),.99); r.INL_P99_strict = quantile_linear(m(:,2),.99);
r.missing_code_yield = mean(m(:,3)==0); r.monotonic_yield = mean(m(:,4)); r.pass_yield = mean(m(:,5));
r.fail_missing = sum(m(:,3)~=0); r.fail_nonmonotonic = sum(~m(:,4));
r.fail_dnl = sum(m(:,4) & m(:,3)==0 & m(:,1)>=1); r.fail_inl = sum(m(:,4) & m(:,3)==0 & m(:,2)>=4);
% 平均 σ_cal 与平均码下降跳变数（衡量校准精度与非单调程度）
r.mean_sigma_cal_LSB = mean(data(:,9)); r.mean_down_transitions = mean(data(:,10));
% 物理连续良率 = 判决区间无缝覆盖全量程的芯片占比（CAL2 关键正确性指标）
r.physical_continuity_yield = mean(logical(data(:,11))); r.runtime_s = NaN;
end
% base_row：子函数，构造每行公共字段（候选名/拓扑参数/总电容/判决数/MC 次数/模型标注）

function r = base_row(c,a,n,model)
% 填入候选身份与拓扑参数（Cb/topR/lowR1/botCap）
r.candidate = string(c.name); r.Cb_Cu = c.Cb_Cu; r.topR_Cu = c.topR; r.lowR1_Cu = c.lowR1; r.botCap_Cu = c.botCap;
r.total_cap_pF = a.totalCap_pF; r.decision_count = a.decisions; r.MC_runs = n; r.model_case = string(model);
end
% unpack_bits：子函数，把整数判决向量展开成 n×K 布尔位矩阵

function b = unpack_bits(raw,K)
% 初始化 n×K 布尔矩阵（每行一芯片，每列一位判决）
b = false(numel(raw),K);
for k = 1:K, b(:,k) = bitand(raw,uint32(2^(K-k)))~=0; end
end
% is_continuous：检查判决区间是否无缝覆盖全量程（左端对齐 domain 起点、右端对齐终点、相邻区间不重叠不裂口）

function ok = is_continuous(t,a,cfg)
% 端点到域边界容差 + 相邻区间间隙/重叠容差（20×widthTolerance）双重判定
ok = abs(t.lo(1)-a.domain(1)) < cfg.widthTolerance && abs(t.hi(end)-a.domain(2)) < cfg.widthTolerance && ...
     all(diff(t.lo) >= -cfg.widthTolerance) && all(abs(t.lo(2:end)-t.hi(1:end-1)) < 20*cfg.widthTolerance);
end

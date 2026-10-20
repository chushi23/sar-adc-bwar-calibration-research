% cal2_diagnostic_r2.m — 保存 CAL2 失败案例的完整物理区间与码分配证据
% 角色：对每个候选挑出 5 颗正常、10 颗典型微反转(typical_micro)、10 颗最严重(severe) 的 CAL2 失败芯片，
%       逐颗保存实际/估计权重、判决比特、区间边界、解码输出、下降跳变等诊断记录，并生成索引表。
% 目的：为 Phase B/C 的 CAL2 物理连续性失败提供可复核的证据链（debug 用）。
function cal2_diagnostic_r2()
% 加载本轮配置（含候选列表、raw 目录、种子等）
% Save complete physical-region and code-assignment evidence for 5 normal,
% 10 typical micro-inversion, and 10 most severe CAL2 failures per candidate.
cfg = config_round2();
% 加载 CAL2 的 10k 原始结果（含每芯片的 11 列诊断数据）
S = load(fullfile(cfg.implRoot,'raw','candidate_64_vs_72_CAL2_A_10000.mat'),'raw');
indexRows = struct([]);
% 遍历两个候选架构，分别抽取诊断样本
for ci = 1:numel(cfg.candidates)
    % 去掉 name 后构建候选架构 a
    c = cfg.candidates(ci); a = bwar_build(rmfield(c,'name'),cfg);
    % 取该候选 10k 数据：第 8 列=码下降跳变数 nDown，第 5 列=pass 标志
    D = S.raw.(sprintf('c%d',ci)); nDown = D(:,8); pass = logical(D(:,5));
    % 正常样本：pass 且零下降跳变，取前 5 颗
    normal = find(pass & nDown==0,5,'first');
    % 典型微反转池：失败但有下降跳变（轻微非单调），用于观察失效模式
    typicalPool = find(~pass & nDown>0);
    [~,ord] = sortrows([abs(nDown(typicalPool)-1), typicalPool],[1 2]);
    typical = typicalPool(ord(1:min(10,numel(ord))));
    % 严重失败池：其余失败芯片（排除典型微反转），按下降幅度排序取最严重 10 颗
    failPool = setdiff(find(~pass), typical, 'stable');
    [~,ord] = sortrows([-nDown(failPool), failPool],[1 2]);
    severe = failPool(ord(1:min(10,numel(ord))));
    % 合并三类样本（正常/典型/严重）作为本候选的诊断芯片集合
    chips = [normal(:); typical(:); severe(:)];
    labels = [repmat("normal",numel(normal),1); repmat("typical_micro",numel(typical),1); repmat("severe",numel(severe),1)];
    for k = 1:numel(chips)
        % 对单颗诊断芯片生成完整证据记录 rec
        rec = diagnostic_one(a,cfg,chips(k));
        rec.category = labels(k); rec.candidate = c.name;
        file = fullfile(cfg.implRoot,'raw',sprintf('diagnostic_%s_chip_%05d.mat',c.name,chips(k)));
        % 逐颗保存诊断记录到 raw/（文件名含候选名与芯片号）
        save(file,'rec','-v7.3');
        % 索引行：记录候选/类别/芯片号，以及用于复现的失配种子与校准噪声种子
        q.candidate = string(c.name); q.category = labels(k); q.chip = chips(k); q.seed_mismatch = cfg.seedMC+100000*a.archIndex+chips(k); q.seed_cal_noise = cfg.calSeed+chips(k);
        q.n_down = rec.n_down; q.max_drop_codes = rec.max_drop_codes; q.missing_count = rec.metrics(3); q.monotonic = rec.metrics(4); q.pass = rec.metrics(5); q.physical_continuous = rec.physical_continuous;
        if isempty(indexRows), indexRows=q; else, indexRows(end+1)=q; end %#ok<AGROW>
    end
end
% 把所有诊断索引行汇总成 table
T = struct2table(indexRows);
writetable(T,fullfile(cfg.implRoot,'csv','cal2_diagnostic_index.csv'));
save(fullfile(cfg.implRoot,'raw','cal2_diagnostic_index.mat'),'T','cfg');
end
% diagnostic_one：对单颗芯片生成完整证据记录（权重/比特/区间/解码/下降跳变/指标/物理连续）

function rec = diagnostic_one(a,cfg,chip)
% 实例化带失配芯片并生成其传输/判决树
real = realize_variant(a,cfg,chip); t = transfer_tree_gen(a,real,cfg);
% 展开判决向量为 K 位布尔矩阵
bits = unpack_bits(t.raw,a.decisions);
st = RandStream('mt19937ar','Seed',cfg.calSeed+chip);
% CAL2 估计权重 = 真实权重 + 带噪测量平均（σ=cal2SigmaLSB, Navg=512）
wHat = real.decW(:)+mean(cfg.cal2SigmaLSB*a.lsb*randn(st,a.decisions,cfg.cal2Navg),2);
% 用估计权重解码输出码（clamp 到 [0,M-1]）
rawCode = min(cfg.M-1,max(0,floor(cfg.M*(bits*wHat)+.5)));
% 记录芯片号、实际权重、估计权重、原始判决向量（证据核心数据）
rec.chip = chip; rec.actual_weights = real.decW(:); rec.estimated_weights = wHat; rec.raw_decision_vectors = t.raw(:);
rec.decision_bits = bits; rec.interval_lo = t.lo(:); rec.interval_hi = t.hi(:); rec.raw_decoder_output = rawCode(:); rec.cal2_decoder_output = rawCode(:);
% 找出码序列中所有“下降跳变”的位置与幅度（非单调/失效的直接表现）
rec.down_positions = find(diff(rawCode)<0); rec.down_magnitudes = rawCode(rec.down_positions)-rawCode(rec.down_positions+1);
rec.metrics = adc_metrics(t,rawCode,a,cfg); rec.missing_count = rec.metrics(3);
% 物理连续性标志及其反义（不可达输入标志），CAL2 正确性关键判据
rec.physical_continuous = is_continuous(t,a,cfg); rec.physical_unreachable_input = ~rec.physical_continuous;
rec.n_down = numel(rec.down_positions); rec.max_drop_codes = max([0; rec.down_magnitudes]);
end
% unpack_bits：子函数，把整数判决向量展开成 n×K 布尔位矩阵

function b = unpack_bits(raw,K)
% 初始化 n×K 布尔矩阵（每行一芯片，每列一位判决）
b = false(numel(raw),K);
for k=1:K, b(:,k)=bitand(raw,uint32(2^(K-k)))~=0; end
end
% is_continuous：检查判决区间是否无缝覆盖全量程（无不可达输入）

function ok = is_continuous(t,a,cfg)
% 端点到域边界容差 + 相邻区间间隙/重叠容差（20×widthTolerance）双重判定
ok = abs(t.lo(1)-a.domain(1)) < cfg.widthTolerance && abs(t.hi(end)-a.domain(2)) < cfg.widthTolerance && ...
     all(diff(t.lo) >= -cfg.widthTolerance) && all(abs(t.lo(2:end)-t.hi(1:end-1)) < 20*cfg.widthTolerance);
end

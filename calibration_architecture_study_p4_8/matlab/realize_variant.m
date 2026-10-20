% ============================================================================
% realize_variant.m —— 变体的失配实现（模拟真实芯片）
% ----------------------------------------------------------------------------
% 角色：对 variant_definition 生成的变体叠加电容随机失配，得到“实现后”的网络 r。
%       与 Phase 0–3 的 realize_architecture 语义一致：每颗芯片随机流可复现、
%       P/N 两侧独立抽取、单位失配服从面积律 σ(w)=σ_u·√cap（单位 Cu）。
% 输入  ：a —— 变体架构；cfg —— 配置（含 sigma、seedMC）；chip —— 芯片编号
%        （chip=0 为标称/无失配）。
% 输出  ：r —— 含 cap/bridge/armWeights/weights/decW/nomW 的实现结构体。
% 关键：decW=切换电容的名义/真实权重（按判决顺序）；nomW=CAL1 用的理想权重。
% ============================================================================
function r = realize_variant(a, cfg, chip)
% Generalized mismatch realization for variant_definition structs.
% chip=0 -> nominal. Mirrors phase03 realize_architecture semantics:
% per-die reproducible stream, P/N sides drawn independently, unit-mismatch
% law sigma(w) = sigma_u*sqrt(cap) in Cu.
r.chip = chip;
if isfield(cfg, 'sigmaScale'), sScale = cfg.sigmaScale; else, sScale = 1; end
if chip == 0
    cap = repmat(a.cap, 2, 1); bridge = repmat(a.bridge, 2, 1);
else
    seed = cfg.seedMC + 100000*a.archIndex + chip;
    st = RandStream('mt19937ar', 'Seed', seed);
    cap = a.cap + sScale*cfg.sigma*sqrt(a.cap).*randn(st, 2, numel(a.cap));  % 面积律：每个电容加 σ_u·√cap 的高斯失配（P/N 两侧独立）
    if isempty(a.bridge)
        bridge = zeros(2, 0);
    else
        bridge = a.bridge + sScale*cfg.sigma*sqrt(a.bridge).*randn(st, 2, numel(a.bridge));
    end
end
assert(all(cap(:) > 0) && all(bridge(:) > 0), 'Nonpositive physical capacitor.');
w = zeros(2, numel(a.cap));
for side = 1:2
    w(side,:) = network_weights(a, cap(side,:), bridge(side,:));
end
r.cap = cap; r.bridge = bridge;
r.armWeights = w;                      % all caps, both sides
r.weights = a.scale * mean(w, 1);      % mean-of-sides per cap (phase03 convention)：取两侧平均作为该电容权重
r.decW  = r.weights(a.decIdx);         % 按判决顺序取出的“被切换电容”权重（CAL2 校准对象）
r.decWside = a.scale * w(:, a.decIdx); % 两侧各自的切换权重（用于逐侧诊断）
if chip == 0
    r.nomW = r.decW;
else
    nom = realize_variant(a, cfg, 0);
    r.nomW = nom.decW;
end
end

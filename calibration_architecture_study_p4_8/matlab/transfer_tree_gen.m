% ============================================================================
% transfer_tree_gen.m —— 精确判决树（Phase 4–8 重写版，支持冗余变体）
% ----------------------------------------------------------------------------
% 角色：Phase 4–8 的“模拟 SAR → 数字码”核心。对输入电压区间 [lo,hi] 沿 K 次判决
%       二叉细分（精确区间传播），得到每个叶子的 Vin 区间、决策比特、名义码 code0
%       与校准码 code1；塌缩到零宽度的区间即为“缺码/死亡分支”。
% 输入  ：a —— 变体架构；real —— 实现后网络（含真实/名义权重 decW/nomW）；
%        cfg —— 配置；opt —— 偏移/权重缩放/解码权重等可选扰动（用于 Phase 7 动态）。
% 输出  ：t —— 含 lo/hi/raw/code0/code1/alive/death/margin/state 的结构体。
% 关键约定：fullstep vs monotonic 两种判决约定（同 Phase 0–3 transfer_tree）。
% 辅助：bitunpack 把打包决策比特展开为 nLeaf×K 的 {-1,+1} / {0,1} 矩阵。
% ============================================================================
function t = transfer_tree_gen(a, real, cfg, opt)
% Exact decision-region propagation, generalized for Phase 4--8 variants.
% opt.offset      comparator offset added to every threshold (Vin-domain V)
% opt.wScale      per-decision analog weight scale (settling), scalar or 1xK
% opt.decoderW    decoder weights for code1 (default: perfect = analog weights)
%
% Conventions (source-recovered in phase03 transfer_tree.m):
%   'fullstep'  (Current family): thr = state; d=1 -> state+w, d=0 -> state-w
%   'monotonic' (CBW/BWA family): thr = state+w; d=1 -> state=thr, d=0 -> keep
%
% t.lo/t.hi/t.raw  per-leaf Vin interval and packed decision bits (d=1 = bit1)
% t.code0          nominal-intent decoder (dc accumulation with nominal weights;
%                  identical to phase03 for the original architectures)
% t.code1          calibrated decoder with opt.decoderW (default perfect CAL1;
%                  equivalent to phase03 code-from-state but derived from bits)
% t.alive          alive nodes after each decision (margin diagnostics)
% t.death          branches lost at each decision
% t.state          final analog accumulation per leaf (equals sum(s.*wAnalog))

if nargin < 4, opt = struct(); end
if ~isfield(opt,'offset'),   opt.offset = 0;     end
if ~isfield(opt,'wScale'),   opt.wScale = 1;     end
if ~isfield(opt,'decoderW'), opt.decoderW = real.decW; end
if ~isfield(opt,'code0Raw'), opt.code0Raw = false; end
if isfield(a, 'cal1norm'), cal1norm = a.cal1norm; else, cal1norm = false; end
K = a.decisions;
wA = real.decW .* (opt.wScale .* ones(1, K));   % analog weights actually realized
wD = opt.decoderW(1:K);

lo = a.domain(1); hi = a.domain(2); state = 0; dc = 0; raw = uint32(0);
t.alive = zeros(1, K); t.death = zeros(1, K); t.margin = nan(1, K);
for k = 1:K
    % Exact operational margin at this level (task-book M_k): the distance
    % between the comparator state and the interval edge it must not cross,
    % minus the step it is about to take. Worst alive node, in Vin units.
    if strcmp(a.convention, 'fullstep')
        % both branches alive require state +/- w_k inside [lo,hi]
        t.margin(k) = min(min(hi - state), min(state - lo)) - wA(k);
    else
        % monotonic: branch0 never dies (lo == state); branch1 dies when
        % state + w_k >= hi
        t.margin(k) = min(hi - state) - wA(k);
    end
    switch a.convention
    case 'fullstep'
        threshold = state + opt.offset;
        statePair = [state - wA(k); state + wA(k)];
        dcPair    = [dc - real.nomW(k); dc + real.nomW(k)];
    case 'monotonic'
        threshold = state + wA(k) + opt.offset;
        statePair = [state; threshold];
        dcPair    = [dc; dc + real.nomW(k)];
    otherwise
        error('Unknown convention');
    end
    loPair = [lo; max(lo, threshold)]; hiPair = [min(hi, threshold); hi];
    lo = loPair(:)'; hi = hiPair(:)';
    state = statePair(:)'; dc = dcPair(:)';
    rawPair = [2*raw; 2*raw+1]; raw = rawPair(:)';
    valid = hi - lo > cfg.widthTolerance;  % 区间宽度低于容差视为“死亡”（缺码）
    t.death(k) = sum(~valid);               % 本层失去的分支数（= 潜在缺码数）
    lo = lo(valid); hi = hi(valid); state = state(valid); dc = dc(valid); raw = raw(valid);
    t.alive(k) = numel(lo);
end

switch a.convention
case 'fullstep'
    code0 = floor(cfg.M/2 + dc/a.lsb + .5);
    % decoder reconstruction from decision bits with decoder weights
    s = 2*bitunpack(raw, K) - 1;                 % {-1,+1}, nLeaf x K
    value = s * wD(:);                           % calibrated accumulation
    if cal1norm
        code1 = round((value/sum(wD) + 1)/2 * (cfg.M-1));
    else
        code1 = floor(cfg.M/2 + value/a.lsb + .5);
    end
case 'monotonic'
    code0 = floor(cfg.M * dc + .5);
    d = bitunpack(raw, K);
    value = d * wD(:);
    if cal1norm
        code1 = round(value/sum(wD) * (cfg.M-1));
    else
        code1 = floor(cfg.M * value + .5);
    end
end
t.lo = lo; t.hi = hi; t.raw = raw; t.state = state;
t.code0 = min(cfg.M-1, max(0, code0));
t.code1 = min(cfg.M-1, max(0, code1));
if opt.code0Raw
    t.code0 = min(cfg.M-1, max(0, double(raw)));  % phase03 CBW/BWA CAL0 convention
end
assert(abs(sum(hi - lo) - diff(a.domain)) < 1e-8, 'Decision intervals lost domain coverage.');  % 守恒校验：所有叶子区间总长必须等于输入域，否则判决树有漏洞
end

function b = bitunpack(raw, K)
% nLeaf x K matrix of decision bits, column k = decision k.
n = numel(raw);
b = false(n, K);
for k = 1:K
    b(:,k) = bitand(raw, uint32(2^(K-k))) ~= 0;  % 逐位取出第 k 个判决比特（从最高位开始）
end
end

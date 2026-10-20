% ============================================================================
% variant_definition.m —— 把 Phase 0–3 的架构定义泛化为“带冗余变体”
% ----------------------------------------------------------------------------
% 角色：Phase 4–8 的架构入口。在 architecture_definition 的四基础架构之上，新增
%       两个可调冗余变体：'CurrentR'（电流式 + 可关冗余电容 r12/r8/r4）与
%       'BWAR'（BWA 桥 + topR/rA/lowR1/botCap 冗余旋钮）。'Current'/'BWA' 冻结
%       以逐位复现 Phase 0–3 结果。
% 输入  ：name —— 变体名；cfg —— 配置；p —— 冗余参数字体（各旋钮，可缺省）。
% 输出  ：a —— 架构结构体（cap/seg/bridge/decIdx/convention/domain/scale 等）。
% 关键约定：fullstep（Current 家族）vs monotonic（BWA 家族）两种 SAR 判决约定；
%           decIdx 按“名义有效权重降序”决定判决顺序；archIndex 用 5/6 错开随机流。
% 注意：本函数直接调用 Phase 0–3 的 network_weights（addpath 只读复用）。
% ============================================================================
function a = variant_definition(name, cfg, p)
% Generalized architecture struct for Phase 4--8 variants.
%   'Current'  : original three-stage (frozen; reproduces phase03 bit-for-bit)
%   'CurrentR' : same nodes/bridges/caps shape, tunable redundancy caps.
%                p.r12a/p.r12b (TOP Cu, r12b optional split), p.r8a/p.r8b (M2),
%                p.r4 (M3). p.domMatch=true shrinks the input domain to
%                +/- nominal w(b15) — the value a fullstep binary search needs.
%   'BWA'      : original 8+8 bridge (frozen)
%   'BWAR'     : BWA + p.topR (Cu at TOP node) + p.lowR1 (Cu at LOW node);
%                decision order = descending nominal effective weight.
%
% Conventions: 'fullstep' (Current family: d=1 -> +w, d=0 -> -w, thr = state)
%              'monotonic' (CBW/BWA family: d=1 -> state += w, d=0 -> keep)

a = struct('name', name);
switch name
case 'Current'
    a.cap = [64 32 16 8 8 4 2 1 8 8 4 2 1 16 8 8 4 2 1 18];
    a.seg = [ones(1,8) 2*ones(1,5) 3*ones(1,7)];
    a.bridge = [1.65203727295828 1.83875928113993];
    a.decIdx = 1:19;
    a.dummyIdx = 20;
    a.convention = 'fullstep';
    a.domain = [-cfg.currentFS/2 cfg.currentFS/2];
    a.scale = cfg.VrefSpan;
    a.archIndex = 1;
case 'CurrentR'
    % r-values are freely tunable DOWN TO ZERO (r=0 removes the redundant cap;
    % the diagnosis showed inserted r-caps break the fullstep halving chain).
    % p.retune recomputes Cb1/Cb2 for exact 1/16 and 1/32 attenuation with the
    % ACTUAL segment totals (the frozen bridges were sized for r-caps present).
    if ~isfield(p,'r12a'), p.r12a = 8; end
    if ~isfield(p,'r12b'), p.r12b = 0; end
    if ~isfield(p,'r8a'),  p.r8a  = 8; end
    if ~isfield(p,'r8b'),  p.r8b  = 0; end
    if ~isfield(p,'r4'),   p.r4   = 8; end
    if ~isfield(p,'domMatch'), p.domMatch = false; end
    if ~isfield(p,'retune'),   p.retune   = false; end
    capTop = [64 32 16 8];
    if p.r12a > 0, capTop(end+1) = p.r12a; end
    if p.r12b > 0, capTop(end+1) = p.r12b; end
    capTop(end+1:end+3) = [4 2 1];
    capM2 = [8];
    if p.r8a > 0, capM2(end+1) = p.r8a; end
    if p.r8b > 0, capM2(end+1) = p.r8b; end
    capM2(end+1:end+3) = [4 2 1];
    capM3 = [16];
    if p.r4 > 0, capM3(end+1) = p.r4; end
    capM3(end+1:end+4) = [8 4 2 1];
    a.cap = [capTop, capM2, capM3, 18];
    a.seg = [ones(1,numel(capTop)), 2*ones(1,numel(capM2)), 3*ones(1,numel(capM3)+1)];
    M2tot = sum(capM2); M3tot = sum(capM3) + 18;
    if p.retune
        Cb2 = M3tot / 31;                         % retune：用实际段总容使 g3/g2 = 1/32 精确成立
        Cb1 = (M2tot + Cb2*M3tot/(M3tot + Cb2)) / 15;  % retune：使 g2/g1 = 1/16 精确成立（冗余电容存在时桥需重算）
    else
        Cb1 = 1.65203727295828; Cb2 = 1.83875928113993;
    end
    a.bridge = [Cb1 Cb2];
    a.dummyIdx = numel(a.cap);
    a.convention = 'fullstep';
    a.scale = cfg.VrefSpan;
    % CAL1 decoder: phase03-compatible floor mapping. (An endpoint-normalized
    % decoder was tested experimentally and made CAL1 yields WORSE.)
    g = network_weights(a, a.cap, a.bridge);  % 复用 Phase 0–3 引擎：解节点方程求各段耦合系数 g
    if p.domMatch
        % Split-healthy fullstep search: d=1 child of the root must be centered,
        % i.e. w(MSB) = half of the half-span  ->  domain = +/- 2*w(MSB).
        a.domain = [-2*a.scale*g(1), 2*a.scale*g(1)];
    else
        a.domain = [-cfg.currentFS/2 cfg.currentFS/2];
    end
    gw = g(1:end-1);
    [~, a.decIdx] = sort(gw, 'descend');
    a.decIdx = a.decIdx(gw(a.decIdx) > 0)';            % drop zero-weight entries
    a.decIdx = a.decIdx(:)';
    a.archIndex = cfg.variantIndex.CurrentR;
case 'BWA'
    a.cap = [2.^(0:7) 2.^(0:7) 1];
    a.seg = [2*ones(1,8) 1*ones(1,8) 2];
    a.bridge = 256/255;
    a.decIdx = [16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1];
    a.dummyIdx = 17;
    a.convention = 'monotonic';
    a.domain = [0 1];
    a.scale = 1;
    a.archIndex = 3;
case 'BWAR'
    % Redundancy knobs (all optional, combined in the design search):
    %   p.topR  (Cu at TOP, after b8)   - secures the TOP binary levels
    %   p.rA    (Cu at TOP, above b8)   - secures the b9/b8 boundary
    %   p.lowR1 (Cu at LOW, bridge RETUNED via Leff=L/256 so the LOW scale
    %            is preserved)          - secures the TOP/LOW boundary
    %   p.botCap(Cu at LOW, decided after b0) - LSB-end endowment step
    if ~isfield(p,'rA'),     p.rA     = 0; end
    if ~isfield(p,'topR'),   p.topR   = 0; end
    if ~isfield(p,'lowR1'),  p.lowR1  = 0; end
    if ~isfield(p,'botCap'), p.botCap = 0; end
    capLow = [2.^(0:7), 1];                  % b0..b7 + dummy (LOW node)
    nLow = 9;
    idxLowR1 = []; idxBot = [];
    if p.lowR1 > 0,  nLow = nLow + 1; idxLowR1 = nLow; capLow(end+1) = p.lowR1; end
    if p.botCap > 0, nLow = nLow + 1; idxBot    = nLow; capLow(end+1) = p.botCap; end
    capTop = [1 2 4 8 16 32 64 128];         % b8..b15 at TOP node
    idxTopR = []; idxRA = [];
    if p.topR > 0, capTop(end+1) = p.topR; idxTopR = numel(capLow) + numel(capTop); end
    if p.rA > 0,   capTop(end+1) = p.rA;   idxRA   = numel(capLow) + numel(capTop); end
    a.cap = [capLow, capTop];
    a.seg = [2*ones(1,numel(capLow)), 1*ones(1,numel(capTop))];
    L = 256 + p.lowR1 + p.botCap;            % BWAR 物理 LOW 段总容（Cu），含冗余
    if p.lowR1 > 0
        Leff = L / 256;                      % 用 Leff=L/256 保持天然 LOW 比例同时引入冗余
        a.bridge = Leff * L / (L - Leff);    % 由 Leff 反解桥电容，使 LOW 量程不被冗余破坏
    else
        a.bridge = 256/255;                  % original, untouched
    end
    a.dummyIdx = 9;
    a.convention = 'monotonic';
    a.domain = [0 1];
    a.scale = 1;
    % CAL1 decoder: phase03-compatible floor mapping (normalized variant tested worse).
    % decision order: descending nominal effective weight over SWITCHED caps
    g = network_weights(a, a.cap, a.bridge);  % 复用 Phase 0–3 引擎：解节点方程求各段耦合系数 g
    g(a.dummyIdx) = -Inf;                                 % dummy 电容权重置 -Inf：SAR 判决中永不切换该电容
    [~, a.decIdx] = sort(g, 'descend');
    a.decIdx = a.decIdx(a.decIdx ~= a.dummyIdx);          % safety: drop dummy if present
    a.decIdx = a.decIdx(:)';
    a.archIndex = cfg.variantIndex.BWAR;
otherwise
    error('Unknown variant %s', name);
end
a.decisions = numel(a.decIdx);
a.lsb = diff(a.domain) / cfg.M;
a.totalCap_pF = 2*(sum(a.cap) + sum(a.bridge)) * cfg.Cu_fF / 1000;
end

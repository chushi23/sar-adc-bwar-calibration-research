% bwar_build.m — BWAR 架构构建器（显式桥电容版本）
% 角色：本项目所有仿真的“架构定义”入口，替代 p4_8 的 variant_definition('BWAR',...)。
% 输入：p 为参数结构（topR/lowR1/botCap/Cb_Cu），cfg 为全局配置（含 Cu_fF、M 等）。
% 输出：统一结构 a，含电容阵列 cap、段归属 seg、桥电容 bridge、判决顺序 decIdx。
% 关键：Cb_Cu>0 直接取整数桥电容（如 2Cu=300fF）；Cb_Cu<0 用 Leff 公式复现旧 BWAR-final 的 1.949Cu 桥。
%       通过 network_weights 算权重，按权重降序确定逐次逼近的判决顺序（单调 CDAC 约定）。
function a = bwar_build(p, cfg)
% 初始化返回结构，先记录架构名为 'BWAR'
% BWAR variant with EXPLICIT bridge value (Cu). Cb_Cu < 0 -> Leff formula
% (Cb = Leff*L/(L-Leff), Leff = L/256) reproducing BWAR-final exactly.
% Same struct contract as p4_8 variant_definition (archIndex 6 stream).
a = struct('name', 'BWAR');
if ~isfield(p,'topR'),   p.topR = 0; end
if ~isfield(p,'lowR1'),  p.lowR1 = 0; end
if ~isfield(p,'botCap'), p.botCap = 0; end
if ~isfield(p,'Cb_Cu'),  p.Cb_Cu = -1; end
capLow = [2.^(0:7), 1];                       % b0..b7 + dummy at LOW node
% LOW 节点初始电容数 = 8 个二进权重位(b0..b7) + 1 个 dummy = 9
nLow = 9;
if p.lowR1 > 0,  nLow = nLow + 1; capLow(end+1) = p.lowR1;  end
if p.botCap > 0, nLow = nLow + 1; capLow(end+1) = p.botCap; end
capTop = [1 2 4 8 16 32 64 128];              % b8..b15 at TOP node
if p.topR > 0, capTop(end+1) = p.topR; end
% 拼接 LOW 段与 TOP 段电容阵列，形成完整的 CDAC 电容列表
a.cap = [capLow, capTop];
a.seg = [2*ones(1,numel(capLow)), 1*ones(1,numel(capTop))];
% L：归一化总单位电容数（基准 256=8bit 低位段 + 附加低位电阻 lowR1 + 底部电容 botCap）
L = 256 + p.lowR1 + p.botCap;
if p.Cb_Cu > 0
    a.bridge = p.Cb_Cu;
    a.bridgeMode = 'explicit';
else
    % Leff 公式复现旧 BWAR-final：Cb = Leff*L/(L-Leff)，令 Leff=L/256 得桥电容 1.949Cu
    Leff = L / 256;
    a.bridge = Leff * L / (L - Leff);
    a.bridgeMode = 'Leff';
end
% dummy 电容固定位于 LOW 阵列索引 9，不参与比较（后续权重置 -Inf）
a.dummyIdx = 9;
a.convention = 'monotonic';
a.domain = [0 1];
a.scale = 1;
a.cal1norm = false;                            % phase03-compatible floor decoder
% 计算每个判决节点（每颗电容）对输出的等效权重
g = network_weights(a, a.cap, a.bridge);
g(a.dummyIdx) = -Inf;
% 按权重从大到小排序，得到逐次逼近（SAR）的判决顺序 decIdx
[~, a.decIdx] = sort(g, 'descend');
a.decIdx = a.decIdx(a.decIdx ~= a.dummyIdx);
a.decIdx = a.decIdx(:)';
a.decisions = numel(a.decIdx);
% 单个 LSB 对应的输入跨度 = 全量程 domain 宽度 / 2^16（16-bit 分辨率）
a.lsb = diff(a.domain) / cfg.M;
% 总电容(差分结构×2) = 2*(所有电容和 + 桥电容和) × 单位电容 150fF，换算成 pF
a.totalCap_pF = 2*(sum(a.cap) + sum(a.bridge)) * cfg.Cu_fF / 1000;
a.archIndex = cfg.archIndex;
a.p = p;
end

% ============================================================================
% transfer_tree.m —— 用精确区间传播（判决树）得到码映射与“缺码”区间
% ----------------------------------------------------------------------------
% 角色：给定架构 a、实际实现 real、标称 nom、全局 cfg，逐判决位传播输入区间，
%       得到每个输出码对应的输入判决区间 [lo,hi]，并识别缺码(missing codes)。
% 输入  ：a/real/nom/cfg
% 输出  ：t —— 含 t.lo/t.hi(判决区间)、t.raw(原始位串)、t.code0/t.code1
%        (两种判决约定下的输出码；code0=标称域, code1=实际状态域)
% 关键算法：
%   - 每步按架构取阈值/双区间(state±w)，分裂成上/下两个子区间(二叉判决树)。
%   - 两种约定：CBW/BWA 用“fullstep”(比较点在 state+weight)；Current/SBW 用
%     对称 ±weight 的“monotonic”约定。
%   - 末位比较器不切换物理电容(SBW 的 ±0.5/M 仅用于定界)。
%   - valid 过滤掉宽度 < widthTolerance 的退化(缺)区间。
% ============================================================================
function t = transfer_tree(a,real,nom,cfg)
% Exact decision-region propagation; no input raster. Arrays stay Vin-sorted.
lo=a.domain(1); hi=a.domain(2); state=0; dc=0; raw=uint32(0);  % 初始化整个输入域为根区间；state=实际累积权重, dc=标称累积权重
if strcmp(a.name,'SBW'), state=real.initial; dc=nom.initial; end  % SBW 初始置上段权重和（首判为定初值）
for k=1:a.decisions  % 逐位判决，扩展判决树
    if any(strcmp(a.name,{'CBW','BWA'}))
        j=cfg.N-k+1; threshold=state+real.weights(j);  % fullstep 约定：比较阈值 = 当前累积 + 本位权重
        statePair=[state;threshold]; dcPair=[dc;dc+nom.weights(j)];  % 下/上分支的实际与标称态
    elseif strcmp(a.name,'Current')
        threshold=state;
        statePair=[state-real.weights(k);state+real.weights(k)];
        dcPair=[dc-nom.weights(k);dc+nom.weights(k)];
    else  % SBW 架构：上/下两段分别贡献
        threshold=state;
        if k<cfg.N
            j=cfg.N-k;
            statePair=[state-real.upper(j);state+real.lower(j)];
            dcPair=[dc-nom.upper(j);dc+nom.lower(j)];
        else
            % Last comparator does not switch a physical capacitor.
            statePair=[state-.5/cfg.M;state+.5/cfg.M];  % 末位仅作定界，±半个 LSB，不切换物理电容
            dcPair=[dc-.5/cfg.M;dc+.5/cfg.M];
        end
    end
    loPair=[lo;max(lo,threshold)]; hiPair=[min(hi,threshold);hi];  % 用阈值把当前区间切成下/上两段（fullstep 分裂）
    lo=loPair(:)'; hi=hiPair(:)';  % 行向量化：把列对展平，保持 Vin-排序(区间数量翻倍)
    state=statePair(:)'; dc=dcPair(:)';
    rawPair=[2*raw;2*raw+1]; raw=rawPair(:)';  % 二叉：左移(×2)为低位 0，×2+1 为低位 1
    valid=hi-lo>cfg.widthTolerance;  % 宽度过小的区间视为“缺码”退化，剔除
    lo=lo(valid); hi=hi(valid); state=state(valid); dc=dc(valid); raw=raw(valid);
end
if strcmp(a.name,'Current')
    code0=floor(cfg.M/2+dc/a.lsb+.5);  % Current：以中点为 0 码，标称态 dc 映射到对称码
    code1=floor(cfg.M/2+state/a.lsb+.5);  % 实际态 state 映射到对称码
elseif strcmp(a.name,'SBW')
    code0=double(raw);  % SBW：code0 直接是原始位序
    code1=floor(cfg.M*state+1e-10);  % code1 由实际状态 state(归一化) 乘以码数得到
else
    code0=double(raw);
    code1=floor(cfg.M*state+.5);  % 标准：实际状态 × 码数 → 输出码（四舍五入）
end
t.lo=lo; t.hi=hi; t.raw=raw;  % 输出所有存活判决区间与原始码
t.code0=min(cfg.M-1,max(0,code0)); t.code1=min(cfg.M-1,max(0,code1));  % 裁到合法码范围 [0,M-1]
assert(abs(sum(hi-lo)-diff(a.domain))<1e-8,'Decision intervals lost domain coverage.');  % 完整性自检：所有区间长度之和须等于域宽
end

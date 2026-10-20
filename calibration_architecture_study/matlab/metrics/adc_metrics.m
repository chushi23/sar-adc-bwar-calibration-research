% ============================================================================
% adc_metrics.m —— 由码密度计算 DNL/INL，并判定是否合格
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的“评分器”。把 transfer_tree 输出的判决区间 t 与某条码
%       序列 code 转成统计指标。非单调架构的 DNL/INL 置 Inf 作失败哨兵。
% 输入  ：t —— transfer_tree 输出(含区间 lo/hi)；code —— 输出码序列(按约定)；
%        a/cfg
% 输出  ：m —— 指标行向量；curve —— 含区间宽度、INL/DNL、LSB_EP 等
% 关键算法：
%   - width=各码判决区间长度(码密度)；缺码=宽度≤widthTolerance 的码数。
%   - monotonic=码序列是否非递减；非单调则 DNL/INL=Inf(失败)。
%   - 单调时由边界累积求端点 T，用等步长拟合得 INL=(T-理想)/LSB, DNL=差分-1。
%   - pass = 单调 & 零缺码 & DNL<1 & INL<4。
% ============================================================================
function [m,curve] = adc_metrics(t,code,a,cfg)
% Conventional T[k] is invalid for a nonmonotonic transfer. Never sort codes.
width=accumarray(code(:)+1,(t.hi-t.lo)',[cfg.M 1]);  % 每个码对应的判决区间长度(码密度直方图)；码+1 因 accumarray 下标从 1
missing=sum(width<=cfg.widthTolerance);  % 缺码数：宽度退化的码(被判决树剔除)
down=sum(diff(code)<0); monotonic=(down==0);  % 比较相邻码是否递减，全非负才单调
diagDNL=max(abs(width/a.lsb-1));  % 诊断用 DNL：单区间宽度相对理想 LSB 的最大偏差
curve.widths=width; curve.valid=monotonic;
if monotonic
    boundaries=a.domain(1)+cumsum(width);  % 由区间长度累加出各码的右边界
    T=boundaries(1:end-1);  % 取前 M-1 个边界作为判决阈值点
    step=(T(end)-T(1))/(cfg.M-2);  % 用首末阈值反推平均步长(有效 LSB)
    assert(step>0);
    INL=(T-(T(1)+(0:cfg.M-2)'*step))/step;  % INL：实际阈值相对理想等距网格的偏差(LSB)
    DNL=diff(T)/step-1;  % DNL：相邻步长相对理想步长的偏差
    im=max(abs(INL)); dm=max(abs(DNL));  % 峰值 INL / DNL
    curve.thresholds=T; curve.INL=INL; curve.DNL=DNL; curve.LSB_EP=step;
else
    % Failure-valued ensemble statistics avoid selecting only valid chips.
    dm=Inf; im=Inf;  % 非单调：置 Inf 作失败哨兵，保证良率统计不会只挑“有效”芯片
    curve.thresholds=nan(cfg.M-1,1); curve.INL=[]; curve.DNL=[]; curve.LSB_EP=NaN;
end
pass=monotonic&&missing==0&&dm<cfg.dnlLimit&&im<cfg.inlLimit;  % 合格判定：单调 & 零缺码 & DNL<1 & INL<4
% [DNL,INL,missing,monotonic,pass,occupancyDiagnostic,regions,downTransitions]
m=[dm im missing monotonic pass diagDNL numel(code) down];  % 汇总指标行：峰值DNL,峰值INL,缺码数,单调,合格,诊断DNL,码数,下跳数
end

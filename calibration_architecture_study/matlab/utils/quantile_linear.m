% ============================================================================
% quantile_linear.m —— 线性插值分位数估计（用于良率统计）
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的统计工具。给定样本 x 与概率 p，返回线性插值分位数，
%       与 NumPy 的 quantile 约定一致，且能正确处理失败哨兵值 Inf。
% 输入  ：x —— 样本向量(可含 Inf)；p —— 分位概率(标量或数组)
% 输出  ：q —— 对应分位数值（保持 p 的形状）
% 关键算法：rank h=1+(n-1)*p；取 floor/ceil 两邻点，依小数权重线性插值；
%       当两邻点相等(含 Inf 平台)时跳过插值，直接取值。
% ============================================================================
function q=quantile_linear(x,p)
% NumPy-compatible linear rank interpolation, including failure-valued Inf.
x=sort(x(:)); outsize=size(p); p=p(:); h=1+(numel(x)-1)*p; lo=floor(h); hi=ceil(h);  % 排序后算线性秩位置
q=x(lo); mask=(hi~=lo)&(x(hi)~=x(lo));  % 仅对左右邻点不同的情况做插值(mask)
q(mask)=x(lo(mask))+(h(mask)-lo(mask)).*(x(hi(mask))-x(lo(mask)));  % 小数权重线性插值
q=reshape(q,outsize);  % 还原成 p 的原始形状
end

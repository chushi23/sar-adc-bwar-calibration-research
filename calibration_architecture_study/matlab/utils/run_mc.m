% ============================================================================
% run_mc.m —— 蒙特卡洛循环：对单架构跑 nrun 颗 die，可增量续跑
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的“批量评估器”。在并行(parfor)或串行下循环调用
%       evaluate_die，把每颗 die 的 16 列指标汇成数据矩阵。支持传入
%       previous 结果实现断点续跑（不重算已有 die）。
% 输入  ：name —— 架构名；cfg —— 配置；nrun —— 总 die 数；
%        previous —— 已有的 (k×16) 结果，可选
% 输出  ：data —— (nrun×16) 指标矩阵；elapsed —— 运行耗时
% 关键算法：data 列宽 16 = 两种约定 × 8 指标(m0 8 列 + m1 8 列)。
% ============================================================================
function [data,elapsed]=run_mc(name,cfg,nrun,previous)
if nargin<4,previous=zeros(0,16);end  % 未传 previous 时视为空，从头算
nold=size(previous,1); data=zeros(nrun,16);  % 预分配结果矩阵(16 列)
if nold>0,data(1:nold,:)=previous;end  % 若有历史结果先填回，实现续跑
extra=zeros(nrun-nold,16); clock=tic;
if cfg.useParallel
    parfor j=1:nrun-nold  % 并行：每颗 die 独立，自动负载均衡
        extra(j,:)=evaluate_die(name,cfg,j+nold);
    end
else
    for j=1:nrun-nold  % 串行回退
        extra(j,:)=evaluate_die(name,cfg,j+nold);
    end
end
data(nold+1:end,:)=extra; elapsed=toc(clock);  % 拼回并计时
end

% ============================================================================
% run_variant_mc.m —— 变体的 CAL0/CAL1 蒙特卡洛
% ----------------------------------------------------------------------------
% 角色：对变体跑 nrun 颗失配芯片，逐颗建精确判决树，分别用名义码 code0（CAL0，无
%       校准）与校准码 code1（CAL1，理想权重）调用 adc_metrics，得到 [DNL INL 缺码
%       单调 通过] 双模式指标块，用于对比“不校准 vs 理想校准”的差距。
% 输入  ：name/params —— 变体；cfg —— 配置；nrun —— 蒙特卡洛规模。
% 输出  ：data —— nrun×16 矩阵（CAL0 与 CAL1 各 8 列）；elapsed —— 耗时。
% 注：当前实现未填充 rows，主结果在 data 中。
% ============================================================================
function [data, elapsed, rows] = run_variant_mc(name, cfg, params, nrun)
% CAL0/CAL1 MC for a variant. Column block per mode:
% [DNL INL missing monotonic pass diagDNL regions down]
a = variant_definition(name, cfg, params);
data = zeros(nrun, 16); clock = tic;
for j = 1:nrun
    real = realize_variant(a, cfg, j);
    t = transfer_tree_gen(a, real, cfg);
    m0 = adc_metrics(t, t.code0, a, cfg);  % CAL0：名义码（无校准）
    m1 = adc_metrics(t, t.code1, a, cfg);  % CAL1：理想校准码（架构可达性上界）
    data(j,:) = [m0 m1];                   % 拼接双模式指标块
end
elapsed = toc(clock);
end

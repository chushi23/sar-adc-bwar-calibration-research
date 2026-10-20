% run_mc_impl.m — BWAR 架构的蒙特卡洛(MC)良率仿真入口
% 角色：对给定 bwar_build 结构 a 跑 nrun 颗芯片，评估 CAL0/CAL1 两种前台校准下的 16-bit 指标。
% 输入：a=架构结构, cfg=配置(含 M/seed 等), nrun=MC 次数。
% 输出：data 为 nrun×16 矩阵（前 8 列 CAL0、后 8 列 CAL1 的 DNL/INL/缺码/单调/pass 等），elapsed=总耗时。
function [data, elapsed] = run_mc_impl(a, cfg, nrun)
% 预分配 MC 结果矩阵（每行 16 列：CAL0 与 CAL1 各 8 项指标），并启动计时
% CAL0/CAL1 MC for a bwar_build struct. Same column contract as p4_8.
data = zeros(nrun, 16); clock = tic;
for j = 1:nrun
    % 蒙特卡洛第 j 颗芯片：实例化带随机失配的电容权重 real
    real = realize_variant(a, cfg, j);
    % 生成该芯片的传输特性/判决树 t（含 code0、code1 两套判决码）
    t = transfer_tree_gen(a, real, cfg);
    % 同一芯片下分别计算 CAL0(code0) 与 CAL1(code1) 两种校准的 8 项指标，拼成一行存入
    data(j,:) = [adc_metrics(t, t.code0, a, cfg), adc_metrics(t, t.code1, a, cfg)];
end
% 停止计时，返回整轮 MC 的总耗时（秒）
elapsed = toc(clock);
end

% ============================================================================
% summarize_variant.m —— 变体蒙特卡洛结果汇总行
% ----------------------------------------------------------------------------
% 角色：把 run_variant_mc 返回的 nrun×16 矩阵压成一行统计：按 mode(CAL0/CAL1)
%       取对应 8 列块，用分位数（P50/P95/P99）给出 DNL/INL 最大值分布，以及
%       零缺码率、单调率、规格通过率。供 finalize/终选报告制表。
% 输入  ：name/mode —— 架构与校准模式；data —— MC 矩阵；elapsed —— 耗时；
%        decisions/cap_pF —— 判决数/总电容。
% 输出  ：s —— 汇总结构体（DNL*/INL* 分位数、各项良率）。
% ============================================================================
function s = summarize_variant(name, mode, data, elapsed, decisions, cap_pF)
% Summary row for a variant MC matrix from run_variant_mc.
s.architecture = string(name); s.calibration_mode = string(mode);
s.decision_count = decisions; s.total_cap_pF = cap_pF;
c = 1 + 8 * double(strcmp(mode, 'CAL1'));
dnl = data(:, c); inl = data(:, c+1); miss = data(:, c+2);
mono = data(:, c+3); pass = data(:, c+4);
finite = isfinite(dnl);
s.MC_runs = size(data, 1); s.runtime_s = elapsed;
if any(finite)
    q3 = quantile_linear(dnl(finite), [.5 .95 .99]);
    s.DNL_max_P50 = q3(1); s.DNL_max_P95 = q3(2); s.DNL_max_P99 = q3(3);
else
    s.DNL_max_P50 = Inf; s.DNL_max_P95 = Inf; s.DNL_max_P99 = Inf;
end
if all(finite)
    q3 = quantile_linear(inl(finite), [.5 .95 .99]);
    s.INL_max_P50 = q3(1); s.INL_max_P95 = q3(2); s.INL_max_P99 = q3(3);
else
    s.INL_max_P50 = Inf; s.INL_max_P95 = Inf; s.INL_max_P99 = Inf;
end
q3 = quantile_linear(miss, [.5 .95 .99]);
s.missing_P50 = q3(1); s.missing_P95 = q3(2); s.missing_P99 = q3(3);
s.missing_code_yield = mean(miss == 0);   % 零缺码良率
s.monotonic_yield = mean(mono);          % 单调良率
s.spec_pass_yield = mean(pass);          % 16-bit 规格(DNL<1,INL<4,零缺码,单调)通过良率
end

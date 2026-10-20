% mc_summary_row.m — 把一次 run_mc_impl 的 MC 矩阵汇总成单行统计结构
% 角色：供各阶段搜索将 nrun×16 的 data 压成 DNL/INL 分位数、缺码率、单调率、良率等汇总指标。
% 说明：data 的 9..13 列为 CAL1 的 [DNL INL missing monotonic pass]，本函数据此算 P95/P99 与各类 yield。
% 输出 s 为 table 行结构，含 Cb/topR/lowR1/botCap、decision_count、总电容、各良率与分位数。
function s = mc_summary_row(label, a, data, elapsed)
% Summary row for a run_mc_impl matrix (CAL1 columns).
s.label = string(label);
if isfield(a.p, 'Cb_Cu'), s.Cb_Cu = a.p.Cb_Cu; else, s.Cb_Cu = NaN; end
% 桥电容(单位 fF) = 桥电容(Cu) × 150fF 单位电容
s.Cb_fF = a.bridge(1)*150;
s.topR_Cu = a.p.topR; s.lowR1_Cu = a.p.lowR1; s.botCap_Cu = a.p.botCap;
s.decision_count = a.decisions; s.total_cap_pF = a.totalCap_pF;
% 抽取 CAL1 的 5 个关键指标列：DNL、INL、缺码计数、单调标志、pass 标志
dnl = data(:,9); inl = data(:,10); miss = data(:,11); mono = data(:,12); pass = data(:,13);
% 仅对有限值（即未缺码、DNL 有意义）的芯片做分位数统计
f = isfinite(dnl);
if any(f)
    q = quantile_linear(dnl(f), [.5 .95 .99]); s.DNL_P99 = q(3); s.DNL_P95 = q(2);
else
    s.DNL_P99 = Inf; s.DNL_P95 = Inf;
end
if all(f)
    q = quantile_linear(inl(f), [.5 .95 .99]); s.INL_P99 = q(3); s.INL_P95 = q(2);
else
    s.INL_P99 = Inf; s.INL_P95 = Inf;
end
% 零缺码良率 = 缺码计数==0 的芯片占比
s.zero_missing_yield = mean(miss == 0);
s.monotonic_yield = mean(mono);
% 总体 pass 良率 = 通过 DNL/INL/缺码/单调全部规格的芯片占比
s.pass_yield = mean(pass);
s.MC_runs = size(data,1); s.runtime_s = elapsed;
end

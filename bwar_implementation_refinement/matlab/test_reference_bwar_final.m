% test_reference_bwar_final.m — 回归闸门：验证新构建器与归档的 BWAR-final 数值完全一致
% 角色：保证 bwar_build 重构的 BWAR-final 与 p4_8 的 variant_definition 产出相同（cap/bridge/decIdx），
%       并复现归档 1000 颗 CAL1 的结果（pass=100%、DNL99=0.980、INL99=0.569），确保后续搜索基线可信。
function test_reference_bwar_final()
% Regression gate: rebuild BWAR-final via bwar_build and reproduce the
% archived p4_8 numbers (variant_MC_summary.csv, n=1000 CAL1 row).
cfg = config_impl();
% 用参考参数(ref: Cb<0 触发 Leff 公式)构建 BWAR-final 架构
a = bwar_build(cfg.ref, cfg);
% 用旧构建器构建同一架构，作为对照基准
old = bwar_build_old_ref(cfg);
% 断言两套构建器的电容列表完全一致（架构契约未变）
assert(isequal(a.cap, old.cap), 'cap list mismatch vs old builder');
assert(abs(a.bridge(1) - old.bridge(1)) < 1e-12, 'bridge mismatch');
assert(isequal(a.decIdx, old.decIdx), 'decision order mismatch');
fprintf('builder parity: OK (Cb=%.6f Cu=%.2f fF, dec=%d, cap=%.2f pF)\n', ...
    a.bridge(1), a.bridge(1)*150, a.decisions, a.totalCap_pF);
[data, ~] = run_mc_impl(a, cfg, 1000);
% 取 CAL1 的 pass 均值、DNL 的 P99、INL 的 P99（data 第 9/10/13 列）
y = mean(data(:,13)); q9 = quantile_linear(data(:,9), .99); qi9 = quantile_linear(data(:,10), .99);
fprintf('reference 1000-chip CAL1: pass=%.1f%% zero-miss=%.1f%% mono=%.1f%% DNL99=%.3f INL99=%.3f\n', ...
    100*y, 100*mean(data(:,11)==0), 100*mean(data(:,12)), q9, qi9);
% 回归判据：100% pass 且 DNL99/INL99 与归档值偏差在容差内，否则视为重构失败
ok = (y == 1) && abs(q9 - 0.980) < 0.005 && abs(qi9 - 0.569) < 0.01;
assert(ok, 'reference regression FAILED');
fprintf('test_reference_bwar_final: PASS (matches archived 100%%/0.980/0.569)\n');
end
% 旧构建器入口：直接调用 p4_8 存档的 variant_definition('BWAR',...)，作为对照

function a = bwar_build_old_ref(cfg)
a = variant_definition('BWAR', cfg, struct('rA',0,'topR',10,'lowR1',240,'botCap',1));
end

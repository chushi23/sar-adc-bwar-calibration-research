# HANDOFF — verification_round2

入口：在 MATLAB R2025b 中进入 `verification_round2/matlab`，执行 `candidate_regression_r2('all')`、`cal2_diagnostic_r2()`；decoder debug 为 `decoder_eval_r2(100,'debug100_oracleSparse')`。

结论和限制见 `reports/01` 至 `reports/06`。当前停在 NO-GO：没有验证通过的、仅由 19 位权校准驱动的 decoder C。

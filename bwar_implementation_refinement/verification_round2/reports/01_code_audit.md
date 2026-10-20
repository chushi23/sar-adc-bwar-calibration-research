# 01 — 源码与结果链路审计

审计日期：2026-10-18；执行环境：MATLAB R2025b。工程 `bwar_implementation_refinement` 不在 Git 工作树内；原始 `csv/`、`raw/`、`reports/` 未修改。所有本轮计算、脚本与输出均在 `verification_round2/`。

## 原始证据链

- `raw/phaseA_fine.mat` 的 `outf.V` 与 `csv/integer_bridge_fine_10k.csv` 仅含 topR=21–24。
- `raw/topR_probe.mat` 的 `P` 与 `csv/topR_pareto_probe.csv` 含 24/32/48/56/60/64/72 Cu，每项为 10,000 MC。故 64Cu 与 72Cu 的 CAL1 数字来自 *定向 probe*，而非 fine search。
- `raw/phaseBC_results.mat` 中 `p = {Cb=2, topR=64, lowR1=256, botCap=1}`，且其 `B1/B2/C1` 是唯一已保存的 CAL2/编码/残余 offset 数据。没有 72Cu CAL2 原始结果。
- `phaseBC_run.log` 先显示 topR=24；`phaseBC2.log` 以后显示 topR=64。当前源码不能复现这一人工切换，因而无法从当前源码、日志和 MAT 建立完整的一键再现链。

## 逐项发现与处置

| 项 | 证据 | 实际影响 | 本轮处置 |
|---|---|---|---|
| 1. 搜索范围 | `matlab/fine_search.m:8` 限制 `topR > 32` | 64/72 不可能由 fine 搜索产出；报告未清楚区分 probe | 已在本报告中追溯为 probe；新回归不再依赖搜索来源 |
| 2. Phase B/C 选型 | 当前 `main_impl_refinement.m:87–100` 从 fine `V` 选择，按现有 V 会得到 24Cu；保存 MAT 却是 64Cu | 源码与实际 CAL2 运行不一致；72Cu 没有 CAL2 实测 | 新的 `candidate_regression_r2.m` 明确固定 64/72，并为每个候选单独保存原始结果 |
| 3. GO 判定 | `finalize_impl_report.m:124` 只要 `phaseBC_results.mat` 存在即判 GO | 不检查 CAL2 pass、DNL/INL、缺码/单调性或实现复杂度 | 原判定无效；本轮在 CAL2 数据与可实现 decoder 未完成前不作 GO |
| 4. 一键报告 | `main_impl_refinement.m:115–117` 的 `write_final_report` 只打印文字，未调用 `finalize_impl_report` | `main_impl_refinement('all')` 不会生成最终报告 | 本轮入口与报告生成将独立实现；原入口不作为可复现证据 |
| 5. 统计口径 | `mc_summary_row.m:9–18` 对 DNL 排除 Inf、对 INL 只要一颗失败即设 Inf；`practical_cal2.m:59–60` 同样不对称 | 报告中的 DNL P99 是条件统计，名称却未标注；不能代表全部芯片 | 新表同时给出 `*_Pxx_cond`、`*_P99_strict`、联合 pass、缺码/单调良率和失败计数 |
| 6. CAL2 交叉归属 | `finalize_impl_report.m:104–118` 将 64Cu 的 `B1/B2` 操作点写进主表的其他行；原报告亦称结果可迁移 | 64Cu CAL2 被暗示为 72Cu 或 24Cu 性能，违反候选独立性 | 已禁止迁移；64/72 采用同一成对样本独立跑 |
| 7. 图轴 | `finalize_impl_report.m:74` 画的是 `sigma_meas*sqrt(Navg)`，而模型/理论为 `sigma_meas/sqrt(Navg)` | Fig8 横轴与校准平均规律相反 | 原 Fig8 不作为证据；新图将用 `sigma_meas/sqrt(Navg)` |
| 8. 编码公平性 | `coeff_encoding_eval.m:14` 的随机种子随 encoding 和 bits 改变 | 不同字长并非同一噪声样本，14-bit “更好”无法归因于量化本身 | 后续比较统一随机流、候选与 decoder |

## 保留的正确部分

- `realize_variant.m` 按 `seedMC + 100000*archIndex + chip` 固定 P/N 独立失配流；新回归继续使用同一芯片编号，保证 64/72 成对比较。
- `transfer_tree_gen.m` 显式传播全部决策区间，并要求区间宽度覆盖输入域；其输出足以区分物理区间连续性和数字码顺序。
- `adc_metrics.m` 不会对非单调输出排序；这一严格定义被保留。

## 结论

历史 CAL1 probe 数字可复算，但历史最终报告不是可审计的 CAL2 决策证据。尤其是 72Cu 没有历史 CAL2 测量，且“存在 Phase B/C 文件即 GO”是逻辑错误。后续结论只使用本轮独立输出的 64/72 数据。

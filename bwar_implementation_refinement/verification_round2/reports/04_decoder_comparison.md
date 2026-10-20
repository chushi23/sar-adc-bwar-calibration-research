# 04 — Decoder A/B/C 比较

验证点：每候选 100 个成对 MC，`sigma_meas=0.02 LSB`、`Navg=512`，和 10k CAL2 基线相同。所有 DNL/INL 重新由 decoder 实际输出的全 16-bit transfer 计算。

| 候选 | Decoder | 单调/无缺码/联合 pass | DNL99 / INL99（strict） | 说明 |
|---|---|---:|---:|---|
| 64Cu | A 原始位权累加 | 95% / 100% / 95% | Inf / Inf | 基线；局部下降使严格指标失败 |
| 64Cu | B oracle transition correction | 100% / 100% / 100% | 0.7923 / 0.7254 | 使用真实物理 decision-vector 顺序，仅诊断上界 |
| 64Cu | C 系数可实现预测 LUT | 95% / 100% / 95% | Inf / Inf | 不满足要求 |
| 72Cu | A 原始位权累加 | 95% / 100% / 95% | Inf / Inf | 基线 |
| 72Cu | B oracle transition correction | 100% / 100% / 100% | 0.7725 / 0.7460 | oracle 上界 |
| 72Cu | C 系数可实现预测 LUT | 95% / 100% / 95% | Inf / Inf | 不满足要求 |

## Decoder 定义

**A — 原始 weighted accumulator**：逐 decision vector 计算 `clip(floor(2^16*d*W_hat+0.5),0,65535)`；与历史 CAL2 一致。

**B — Oracle diagnostic upper bound**：按真实模拟 decision-region 的输入顺序，对 A 的输出作 cumulative maximum。这一操作仅需平均 1.16（64Cu）/1.42（72Cu）条覆盖；100 芯片 P99 分别为 21.5/24.65 条，最大修改幅度均为 1 code。它证明单调无缺码映射在理论上存在，但这种顺序来自真实物理区间，不能当成片上免费信息。

**C — 可实现的候选 sparse correction decoder**：只使用 `W_hat` 和已知 SAR tree 预测可达 raw vector，生成 `raw-vector address -> corrected output` 稀疏表。它不访问真实区间、真实 Vin 或真实 transition threshold。测试中，每片平均有约 563（64Cu）/577（72Cu）个实际 raw vector 不在预测集合内；预测表没有识别任何实际 correction 条目，因此输出退化为 A。

## 硬件含义

若 B 的地址能被可信获得，P99 的粗略存储为约 25 条 × (19-bit address + 16-bit replacement) = 875 bits，外加条目数与匹配控制；运行期为至多 25 个 19-bit 比较器、一个选择树和 16-bit override，不需要乘法器，也不增加 SAR 比较周期。系数累加本身仍为 19 个常系数加法。

但 C 证明：**仅测量 19 个有效位权不足以获得这些地址**。故上述硬件数字量虽小，地址的前台获取并不小；不能把 B 的存储量误报为已实现的 C。

原始结果：`csv/decoder_ABC_debug100_oracleSparse.csv`。由于 C 在最佳噪声点已经失败，本轮未把失败的 decoder 扩展到 Phase 5 的全噪声/字长网格或 10k 扫描。

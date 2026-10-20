# 02 — 64Cu / 72Cu 独立回归

## 固定条件

两候选均为 Cu=150 fF、Cb=2Cu、lowR1=256Cu、botCap=1Cu、16-bit、19 次决策。K-model 使用 `K=0.0399818695 fF`，即 `sigma_u=1.6326%`；PDK-sigma sensitivity 使用 1.67487%。P/N 失配独立，chip=1…N 的种子在两个候选间配对复用。

| 候选 | topR | 总电容 | 决策数 |
|---|---:|---:|---:|
| BWAR-Impl-64 | 64Cu | 250.2 pF | 19 |
| BWAR-Impl-72 | 72Cu | 252.6 pF | 19 |

## K-model CAL1

所有 Pxx 是有效芯片的条件统计；同时，表中每一行的缺码、单调和联合 pass 都以全部 MC 样本计算。三种良率均是 100%，所以本表的 conditional 与 strict P99 相同。

| MC | 候选 | max |DNL| P50/P95/P99 | max |INL| P50/P95/P99 | 缺码良率 | 单调良率 | 联合 pass |
|---:|---|---|---|---:|---:|---:|
| 100 | 64Cu | 0.7433 / 0.7859 / 0.7923 | 0.7054 / 0.7210 / 0.7237 | 100% | 100% | 100% |
| 100 | 72Cu | 0.7147 / 0.7621 / 0.7725 | 0.7235 / 0.7381 / 0.7442 | 100% | 100% | 100% |
| 1,000 | 64Cu | 0.7420 / 0.7848 / 0.7975 | 0.7037 / 0.7224 / 0.7293 | 100% | 100% | 100% |
| 1,000 | 72Cu | 0.7244 / 0.7655 / 0.7771 | 0.7233 / 0.7416 / 0.7478 | 100% | 100% | 100% |
| 10,000 | 64Cu | 0.7443 / 0.7864 / 0.7977 | 0.7046 / 0.7231 / 0.7300 | 100% | 100% | 100% |
| 10,000 | 72Cu | 0.7235 / 0.7666 / 0.7771 | 0.7239 / 0.7419 / 0.7480 | 100% | 100% | 100% |

The 10,000-run observation is **zero observed failures**, not proof of true 100% production yield. With zero failures in 10,000 independent trials, the one-sided 95% binomial lower bound is about 99.970%; it does not establish 99.9% with certainty under unmodeled effects.

## PDK-sigma sensitivity (10,000 CAL1)

| 候选 | DNL99 | INL99 | 缺码/单调/联合 pass |
|---|---:|---:|---:|
| 64Cu | 0.7972 | 0.7309 | 100% / 100% / 100% |
| 72Cu | 0.7782 | 0.7482 | 100% / 100% / 100% |

没有观察到 PDK-sigma case 的硬规格失败。64Cu 的 DNL P99 相比 K-model 的微小下降是有限样本、同一随机实现下的非单调统计波动，不能解读为失配增加改善性能。

## CAL1 判断

CAL1 下两者都满足基础硬规格和 0.8 LSB 工程 DNL 裕量。72Cu 用 +2.4 pF 换来约 0.0207 LSB 的 DNL99 改善，同时 INL99 高约 0.0180 LSB。这个差异不足以跳过 CAL2、校准可实现性和数字复杂度比较。

原始数据：`csv/candidate_64_vs_72_CAL1_{100,1000,10000}.csv`、`csv/candidate_64_vs_72_CAL1_PDK_10000.csv`，以及同名 MAT。

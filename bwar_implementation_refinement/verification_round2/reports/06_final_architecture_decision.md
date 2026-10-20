# 06 — 阶段性最终架构判定

## 判定：NO-GO（针对目前定义的简单 CAL2）

在 XMC 55 nm RFSOI、Cu=150 fF 的现有行为级模型中，BWAR-Impl-64 与 BWAR-Impl-72 的 CDAC/CAL1 本体都可行；72Cu 的 CAL1 DNL 裕量略高，64Cu 电容略小。但它们在最佳已测 CAL2 条件下的独立 10k 联合良率仅为 94.53% 与 94.40%，远低于 99%。

Oracle decoder 证明物理网络没有观察到不可修复的输入区间断裂；然而只从可实际取得的 19 个测量位权无法识别 correction address，未形成可实现 decoder C。因而不能宣称 CAL2 已能以合理数字硬件复杂度满足严格单调、无缺码、DNL<1、INL<4 和 ≥99% 联合良率。

| 项 | 64Cu | 72Cu |
|---|---:|---:|
| topR / Ctotal | 64Cu / 250.2 pF | 72Cu / 252.6 pF |
| CAL1 DNL99 / INL99 | 0.7977 / 0.7300 | 0.7771 / 0.7480 |
| CAL1 pass, 10k | 100% observed | 100% observed |
| CAL2 A pass, 10k | 94.53% | 94.40% |
| CAL2 A missing / mono | 100% / 94.53% | 100% / 94.40% |
| CAL2 C pass | 95% in debug; not viable | 95% in debug; not viable |
| Oracle B pass | 100% in debug only | 100% in debug only |

不选择 64 或 72 进入 CDAC-only Virtuoso。若用户愿意扩大范围，后续可研究：(1) 具有实际 16-bit transition characterization 的校准基准；或 (2) 调整 BWAR 冗余/decision margin，使位权测量误差不再改变 raw-vector 可达集。两者都需要新的行为级验证计划，不能沿用本轮的简单 CAL2 宣称 GO。

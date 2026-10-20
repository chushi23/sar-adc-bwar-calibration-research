# HANDOFF — BWAR 可实现性收敛（Phase A/B/C）交接文档

> 本轮（2026-10-15/16 深夜，ZCode）按用户任务书（§0–§25）执行：不进 Virtuoso，把 BWAR-final
> 收敛为整数桥可实现的 BWAR-Impl。Phase 0–3 / 4–8 两个旧目录零改动零重跑。
> 一键复现 `main_impl_refinement('all')`；本文数字均有 csv/mat 出处。

## 0. 一页结论

| 问题 | 答案 |
|---|---|
| 判决 | **CONDITIONAL GO**（唯一先决项：CAL2 解码器约定，见下） |
| 整数桥 | **Cb=2 Cu=300 fF（两单元并联）可行且优于 1.949 Cu**（DNL99 0.777 vs 0.980）；Cb=1 最高 29.7%、Cb=3 名义门全灭 |
| 推荐实现 | **BWAR-Impl = Cb 2Cu + topR 72Cu@TOP + lowR1 256Cu@LOW + botCap 1Cu；19 判决；252.6 pF；CAL1 100%@10k，DNL99=0.777，INL99=0.748** |
| 省电容档 | topR=24/lowR1=248：235.8 pF，100%@10k，DNL99=0.936（DNL 贴 1.0 红线时不选） |
| CAL2 | averaging 最好 94.8%（σ0.02/Navg512）——**卡在微反转**（每片 ~1 个码对交换；DNL99=0.795、缺码 0、mono 94.8%） |
| 编码 | ERROR-ONLY 14bit→80%（|dW|max≈11 LSB、±256 LSB 量程零饱和）；FULL 20bit→74.6%；位数再大反而更差（同一微反转机制） |
| 系统性偏置 | 权重测量的共模偏置 0.01 LSB→良率 9.8%——比白噪声致命一个量级，必须先消 |
| Phase C | 转换期残余 offset ≤0.02 LSB 可容忍（87.7%），≥0.05 塌方 |
| PDK σ | ×1.026（MOM 实测 1.67487%）：100%@2k，DNL99=0.796 ✓ |

## 1. 本轮做了什么

1. **上下文恢复与保护**：git 确认非仓库（记录于 SOURCE_CORRECTIONS.md）；旧目录零改动；
   发现旧 HANDOFF 残留 1.28 Cu 一处，按任务书不改旧文件、立 SOURCE_CORRECTIONS.md。
2. **Reference 回归门**（`test_reference_bwar_final`）：新构建器 `bwar_build` 与 p4_8 逐位一致，
   1000 颗复现 100% / DNL99=0.980 / INL99=0.569。
3. **Phase A 整数桥搜索**：4125 粗候选（Cb{1,2,3}×topR{0:2:20}×lowR1{64:8:256}×bot{0:4}）
   → 名义门 383（全部 Cb∈{1,2}，Cb=3 全灭）→ 128MC → top25×1000 → top8×10k；
   765 细候选（Cb=2 中心 (20,256,1)，topR±4 步长 1、lowR1±32 步长 4）→ 512MC → top8×10k；
   topR 定向探针 {24,32,48,56,60,64,72}×10k。**门通过**：topR=64 达 DNL99=0.7977≤0.8 且 100% pass。
4. **Phase B 实用化 CAL2**：Navg×σ_meas 全网格（8×5）+ 共模偏置 6 点；σ_cal≈σ_meas/√Navg 数值验证
   （`test_calibration_averaging`，偏差 <15%）；编码对比 FULL vs ERROR-ONLY（8–20 bit）。
5. **Phase C**：权重校准操作点 (0.05, 64) × 残余 offset 7 点联合。
6. **PDK σ 案例** + 单测×4 + Fig1–11 + §21 主表 + Q1–Q8 + 判决（见 reports/final_report.md）。

## 2. 关键技术判定（接手必读）

1. **整数桥机理**：Cb=2 使 LOW 段有效权重比设计值大 ~2.6%，等效自带 +130 LSB 重叠——比 1.949 Cu
   （按 Leff=L/256 精确设计）反而多裕度；Cb=1 让 LOW 段腰斩、Cb=3 让 LOW 位权超过 TOP 位权破坏降序。
2. **DNL99 地板由 topR 主导**：斜率 ≈ −0.003 LSB/Cu；topR=64 是 DNL99≤0.8 的最小点（250.2 pF）。
3. **微反转（本轮最重要发现）**：CAL1 完美权重时码序单调；**任何** σ_cal>0 会让相邻值差 <1 LSB 的码对
   交换（平均 ~1 对/片），在"非单调即失败"口径下全军覆没级地限制 CAL2 良率，而 DNL99/缺码完全正常。
   这不是电容问题，是解码器约定问题——合并码区解码器（数字侧）即可消除。
4. **共模测量偏置 ≠ 白噪声**：0.01 LSB 偏置（对每个权同向）→ 9.8%；白噪声同量级时 → ~85%。
   前置校准电路必须做偏置消除（chopping/差分测量）。
5. **位数越多越差**（ERROR-ONLY 16/18/20 bit 良率低于 14 bit）：更细的量化→更密的取整边界→更多微反转。
   在约定问题解决前，14 bit 是最优点。

## 3. 下一轮建议（按优先级）

1. **行为级实现合并码区/容忍微反转解码器**并重跑 practical_cal2（预期 >99% 解锁，判决转 GO）——代码框架
   都在，改动集中在 `practical_cal2.m` 的 code 映射处。
2. Virtuoso CDAC-only 原理图（Cb=2 Cu 两单元并联的共质心、lowR1=256 Cu 阵列、开关先理想开关）。
3. 若坚持严格口径：研究 σ_cal≤2e-4 LSB 的测量方案（不现实的 Navg vs 更低 σ_meas 的权衡已有数据）。
4. ERROR-ONLY 量程收窄（±16 LSB 起试）省位宽；Phase C 扩到非均匀 offset 模型。

## 4. 与旧目录关系

- 只读 addpath 复用 `calibration_architecture_study{,_p4_8}` 的引擎（realize_variant/transfer_tree_gen/
  adc_metrics/quantile_linear/svgfig）；seed 族（archIndex=6）延续，跨轮可比。
- 本轮所有新文件仅在 `results/bwar_implementation_refinement/`；旧结果未触碰。

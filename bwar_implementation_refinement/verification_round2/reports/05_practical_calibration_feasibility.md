# 05 — 前台校准可实现性

## 可行的“19 位权”前台测量架构

行为级可采用同一动态比较器的 charge-redistribution 方案：保持其余开关为已知基准状态，对第 i 个 decision capacitor 作正/反极性切换；用可编程参考 charge（或已知单元电容数组的二分组合）调到 comparator 翻转。正反结果相减消除 comparator input offset，一半和提供有效位权，重复平均抑制白噪声。

- 参考与状态：VrefP/VrefN、common-mode、待测 bit 的两极性开关，以及参考单位阵列/已校验基准比值。
- 系数形成：将每个翻转平衡点换算到 `W_hat(i)`；所有 19 个有效 decision 通常都应测量，因为桥耦合使 top/low 段不能安全地只用一个全局 scale。
- 比较器：可以复用主 SAR comparator；不必增加高精度 ADC，但需要能在约 0.02 LSB 输入等效噪声下作比值/平衡测量的 reference charge source。
- offset：每项反相（或 chopper）测量；共同 offset 不能靠 Navg 平均消除。
- 比较次数：在本模型的最佳点，19 × 512 × 2 = 19,456 次 comparator decision，仅是平均与极性反相的下限，不含每个平衡点的搜索/settling 时钟。
- 存储：19 个系数。若 ERROR-ONLY 采用 14–24 bit，需 266–456 bit，外加 reference coefficient；运行期约 19 个常系数加法。

## 阻断项：位权精度不等于 decision-vector 顺序知识

本轮 `sigma_cal≈0.000872 LSB` 的 19 位权测量已经是题设的最佳 CAL2 点。即使如此，系数预测的可达 raw-vector 集合与真实模拟集合平均仍相差 563–577 个 vector（约 0.11% 的 19-bit 状态）。这些状态差异正是局部输出交换的来源。

因此，以上 19,456 次级别的位权测量可以形成 A，却不足以形成可验证的 C correction address table。

## 若要获取 oracle-like correction address

唯一直接办法是在前台用已知的高分辨率 stimulus/ramp 扫描实际 transition order，并记录异常 raw vectors。为保证 16-bit 顺序，朴素 sweep 至少涉及约 65,536 个输入目标；若还要求 512 次平均和 polarity reversal，比较次数量级升至约 `2 × 512 × 65,536 ≈ 6.7e7` 次，且需要相当于 16-bit 的参考 DAC/ramp 可信度。这不是“不复杂的 ADC 校准”。

可做更聪明的自适应搜索，但在不知道哪些 vector 异常前仍须有可追溯的覆盖证明；本 MATLAB 模型没有给出这种低成本发现机制。

## 可实现性结论

“只校准 19 个位权 + 小 LUT”目前**不可证明可实现**。要么加入高精度 transition-characterization 基准与长校准时间，要么修改模拟架构以增大这些 path 的 margin。二者都超出原先声称的简单 foreground CAL2。

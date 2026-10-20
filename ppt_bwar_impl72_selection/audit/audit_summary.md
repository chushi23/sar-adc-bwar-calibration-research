# results 文件审计与汇报口径

- 审计范围：`D:/模拟学习/results/`，生成时共 **842** 个既有文件；逐一目录化于 `results_file_inventory.csv`。
- 文本/数据证据重点审阅：Phase 0–3、Phase 4–8、BWAR implementation refinement、verification_round2 的 CSV、报告、MATLAB 源代码和运行日志。
- 二进制 MAT/SVG 由文件清单审计；关键数值以对应 CSV/报告交叉核对。证书/私钥容器（.p12/.pem）只记录元数据，不读取内容。

## 版本优先级

1. `verification_round2`（2026-10-19）：最新 64/72 10k CAL1/CAL2 验证，**最终 NO-GO**。
2. `bwar_implementation_refinement`（2026-10-16）：整数桥与 Impl-72 的物理可实现性筛选。
3. `calibration_architecture_study_p4_8`（2026-10-15）：原始四架构、BWAR-final 搜索及早期阶段。
4. `calibration_architecture_study`（2026-10-15）：Phase 0–3 基线。

## 汇报中必须避免的过期表述

- 不能说“BWAR-Impl-72 已完成 CAL2 并可进入电路级”；最新 10k CAL2-A 是 94.40%。
- 可以说“BWAR-Impl-72 是 CAL1 物理裕量最佳、整数桥可实现的 CDAC 参考候选”。
- CAL1 的零观测失败不是量产 100% 保证；CAL2 的 oracle B 不是可实现 decoder。

## 文件类型统计

|扩展名|数量|
|---|---:|
|.mat|284|
|.svg|130|
|.m|120|
|.csv|112|
|.log|76|
|.md|55|
|.mlsettings|16|
|.json|12|
|.txt|10|
|.p12|8|
|.pem|8|
|.html|7|
|.timestamp|2|
|.py|2|

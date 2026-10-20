# SOURCE_CORRECTIONS — 文档一致性修正记录

## 1. BWAR-final 桥电容旧草稿值残留

**准确值（2026-10-15 经代码核实，`bwar_build(cfg.ref)` / p4_8 `variant_definition`）：**

```
Cb = 1.949020 Cu = 292.35 fF   (Cu = 150 fF)
```

**历史**：Phase 8 交付时的口头总结与记忆文件中曾出现旧草稿数字 "Cb ≈ 1.28 Cu"。
当日已在 `calibration_architecture_study_p4_8/LIMITATIONS.md` 与 `HANDOFF.md` 主体表格中更正为 1.949 Cu；
但 `calibration_architecture_study_p4_8/HANDOFF.md` 第 53 行（"下一步建议"一节）仍残留一处
"桥 Cb≈1.28 Cu 非整单位"字样。按本轮任务书 §1 约定，**不再修改旧文件**，特此记录：

- 旧 HANDOFF 局部仍残留 1.28 Cu 草稿值；
- 最终经代码核实的 BWAR-final **Cb = 1.949 Cu = 292.35 fF**。

本轮（bwar_implementation_refinement）一律使用 1.949 Cu 作为 reference 值。

## 2. git 状态记录（任务书 §0）

`D:\模拟学习` 及其子目录均**不是 git 仓库**（`git status` 返回 fatal: not a git repository），
因此无 branch/commit 可记录；该事实与 p4_8 `context_audit.md` 的记录一致。本轮所有新产物
仅存在于 `results/bwar_implementation_refinement/`，未改动 Phase 0–3 与 Phase 4–8 任何原始结果。

# BWAR Implementation Refinement（可实现性收敛）

承接 `../calibration_architecture_study_p4_8/`（Phase 0–8，零改动零重跑）。本轮把行为级 winner
BWAR-final（非整数桥 1.949 Cu）收敛为**整数桥可实现**的 BWAR-Impl，并完成 Phase A/B/C。

## 一键复现（MATLAB R2025b，PowerShell）

```powershell
$env:MATLAB_PREFDIR='D:\模拟学习\results\bwar_implementation_refinement\logs\matlab_prefs'
& 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe' -batch "cd('D:/模拟学习/results/bwar_implementation_refinement/matlab'); main_impl_refinement('all')"
```

分阶段：`'tests' | 'phaseA' | 'gate' | 'phaseBC' | 'report'`。已有 raw/*.mat 自动跳过。
reference 回归门：`test_reference_bwar_final` 必须先绿（已验证：100%/0.980/0.569 逐位复现）。

## 一页结论

| 项 | 结果 |
|---|---|
| 判决 | **CONDITIONAL GO**（进 Virtuoso CDAC-only 前先解决 CAL2 解码器约定，见 [reports/final_report.md](reports/final_report.md)） |
| 整数桥 | **Cb = 2 Cu（300 fF，2 单元并联）可行且优于 1.949 Cu**；Cb=1/3 不可行 |
| best-margin | Cb2 / topR=72 / lowR1=256 / bot=1：**100%@10k，DNL99=0.777，INL99=0.748，252.6 pF，19 判决** |
| min-cap | Cb2 / topR=24 / lowR1=248 / bot=1：100%@10k，DNL99=0.936，235.8 pF |
| CAL2(averaging) | 严格口径最好 94.8%（σ0.02/Navg512）；瓶颈=微反转（~1 码对/片），DNL99 仍 0.795、缺码 0 |
| 编码 | ERROR-ONLY 14 bit→80%；FULL ≥20 bit→74.6%；系统性测量偏置 0.01 LSB→9.8%（须先消偏置） |
| Phase C | 比较器 offset 校准残余须 ≤0.02 LSB（≥0.05 塌方） |
| PDK σ 案例 | σ×1.026（实测 MOM 1.67487%）：100%@2k，DNL99=0.796 ✓ |

## 目录

| 位置 | 内容 |
|---|---|
| `matlab/` | 全部源码（bwar_build 显式桥构建器、分层搜索、实用化 CAL2、编码评估、offset 联合、单测×4） |
| `reports/final_report.md` | 最终报告：判决 + Q1–Q8 + 对比表 |
| `reports/phaseA_interim.md` | Phase A 中期门报告 |
| `csv/` | coarse(4125)/fine(765)/stageB/C(10k)/topR 探针/practical_cal2/coeff_encoding/offset_residual/master_table |
| `figures/Fig1–11*.svg` | 任务书 §20 全部图 |
| `raw/*.mat` | 阶段数据 + 配置快照 |
| `SOURCE_CORRECTIONS.md` | 旧 HANDOFF 的 1.28 Cu 残留记录 + git 状态记录（非仓库） |
| `HANDOFF.md` / `LIMITATIONS.md` | 交接与模型边界 |

## 约束遵守情况

失配律/σ_u=1.6326%/Cu=150 fF/PN 独立/CAL1 定义/SAR 引擎/阈值与 DNL·INL 算法/seed 策略全部沿用
p4_8 已验证引擎（addpath 只读复用）；Phase 0–8 原始结果未修改未重跑；本轮无 Virtuoso/Spectre/版图。

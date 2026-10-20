# 四架构校准行为平台 — Phase 4–8（ZCode 接手轮）

本目录承接 `../calibration_architecture_study/`（Codex Phase 0–3，未改动、未重跑）。
Phase 5 起的全部工作由 ZCode 于 2026-10-15 完成并归档于此。

## 一键运行（MATLAB R2025b，PowerShell）

```powershell
$env:MATLAB_PREFDIR='D:\模拟学习\results\calibration_architecture_study_p4_8\logs\matlab_prefs'
& 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe' -batch "cd('D:/模拟学习/results/calibration_architecture_study_p4_8/matlab'); main_phase48('all')"
```

- 各阶段可单独跑：`main_phase48('p5'|'p4'|'p6'|'p7'|'p8')`；
- 已有阶段产物（`raw/phase*_results.mat`）自动跳过，删除对应文件即可重跑该阶段；
- Phase 0–3 引用 `../calibration_architecture_study/`（只读，addpath 复用其
  `network_weights`、`adc_metrics`、`quantile_linear`）。

## 目录

| 位置 | 内容 |
|---|---|
| `matlab/` | 全部源码（见下） |
| `reports/05_redundant_variants.md` | Phase 5：原架构逐层裕度诊断、CurrentR A/B/Z 判定、BWAR-final 设计与 MC |
| `reports/04_CAL2.md` | Phase 4：校准估计误差/系数字长扫描（所需精度结论） |
| `reports/06_final_MC.md` | Phase 6：决赛候选 10k MC（原四架构引用 phase03 归档 1k 数据） |
| `reports/07_dynamics.md` | Phase 7：offset/noise/settling 敏感性 |
| `reports/08_final_recommendation.md` | Phase 8：评分、Q1–Q10、最终推荐 |
| `csv/` | 全部数据表（margins、design_search、variant_MC、sigma_sweep、cal2、dynamics、scoring） |
| `figures/*.svg` | 任务书 §21 要求的 12+ 张图（SVG，无原生 figure 依赖） |
| `raw/*.mat` | 各阶段完整数据 + 配置快照 |
| `HANDOFF.md` | 交接文档（本轮做了什么、关键判定、如何继续） |
| `LIMITATIONS.md` | 模型边界与未验证项 |

## 核心源码

| 文件 | 职责 |
|---|---|
| `main_phase48.m` | 阶段编排 + 报告生成 |
| `variant_definition.m` | Current/CurrentR/BWA/BWAR 通用架构结构体（节点/桥/判决序/域） |
| `realize_variant.m` | 逐芯片失配实现（phase03 同款随机流规则，σ 缩放支持） |
| `transfer_tree_gen.m` | 广义精确决策区间树（两种开关约定 + M_k 逐层裕度 + offset/settling 钩子）；与 phase03 引擎逐位对拍通过 |
| `design_search.m` / `margin_profile.m` | 冗余设计网格搜索与逐层裕度统计 |
| `run_variant_mc.m` / `summarize_variant.m` | CAL0/CAL1 分阶段 MC |
| `cal2_eval.m` | CAL2 有限精度校准扫描 |
| `dynamics_eval.m` | offset（精确）/ settling（一阶统一系数）/ noise（采样统计传输） |
| `svgfig.m` | 无依赖 SVG 绘图 |
| `test_engine_compat.m` | 引擎兼容性回归门（必须全绿） |

## seed 与可复现性

- 变体沿用 phase03 规则：`seedMC + 100000*archIndex + chip`，CurrentR=5、BWAR=6；
- CAL2 估计噪声独立流 `90210+config`；噪声采样 `777000+1000*chip+…`；
- 所有报告数字均注明模式/样本量/seed，来源可一键复现。

# 四架构校准行为平台 — Phase 0–3

本轮只新增本目录。原比较 HTML、模型、MOM MC、Virtuoso bridge 与晶体管级设计均未修改。

## 一键运行

MATLAB R2025b 已实际启动并用于主仿真。在 PowerShell 中：

```powershell
$env:MATLAB_PREFDIR='D:\模拟学习\results\calibration_architecture_study\logs\matlab_prefs'
& 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe' -batch "cd('D:/模拟学习/results/calibration_architecture_study/matlab'); main_run"
```

`main_run` 依次运行六项核心单测、1k/10k历史静态回归、回归门槛测试、名义全码、100/1000芯片ADC MC、统计、图与报告。**停在Phase3，不做CAL2/优化候选/动态仿真。**

已存在最终 summary CSV 时，再次运行会自动将新结果置于 `reruns/时间戳/`，不覆盖这次已完成研究。仅本轮开发调试阶段的日志/中间文件曾在本新目录内重建；旧项目文件不动。

## 主要入口

- [可视化HTML](reports/architecture_calibration_summary.html)
- [详细结论](reports/architecture_calibration_summary.md)
- [上下文与准确拓扑审计](context_audit.md)
- [静态回归](reports/01_CAL0_regression.md)
- [统一结果CSV](csv/architecture_calibration_summary.csv)
- [局限性](LIMITATIONS.md)
- `raw/phase03_results.mat`：全部统计/逐片指标/配置。
- `raw/ADC_*_100.mat` 与 `raw/ADC_*_1000.mat`：调试及正式阶段。
- `raw/nominal_*.mat`：名义输入区间、决策映射、阈值和曲线。
- `raw/*_CAL1_*_chip*.mat`：各架构median/P99/worst代表芯片完整物理实现、区间、阈值/曲线。选片排序规则见 `csv/representative_chips.csv`。
- `csv/ADC_*_per_chip.csv`：每颗芯片的CAL0/CAL1指标、seed。
- `logs/matlab_run.log`、`logs/run_metadata.json`：运行、版本、CPU、并行、测试。
- `figures/`：MATLAB直接写出的SVG；8张主图和12张代表芯片图，不依赖图形服务。

## 任意芯片可重建

在MATLAB的 `matlab/` 目录：

```matlab
r = inspect_chip('Current',17,0.24);
r.conversion.decisions
r.conversion.code1
r.intervals        % 全部可达输入区间、原始decision整数及CAL0/CAL1 code
r.CAL1.thresholds  % 非单调时为NaN，不能伪造单值阈值
```

`chip=0` 为名义值。普通芯片seed=`26101500 + 100000*architecture_index + chip`，索引Current/CBW/BWA/SBW=1/2/3/4。每片独立RandStream，改变并行worker数不改变结果。静态回归seed=20261013；MATLAB与NumPy的高斯序列不同，不承诺逐样本等同旧100k数据。

默认四个thread workers；不可用时串行。CPU标识及版本写JSON，实际runtime写逐架构summary。100-run是1000-run前缀，不重复生成前100颗。

本机MATLAB普通figure初始化因本地Connector服务无法启动而崩溃，数值结果已在此前保存。本轮默认改为纯MATLAB SVG输出；`make_figures.m`保留为可选的常规图形实现，但未在本机验证成功，不是默认路径。

## 模型与指标

每个物理组 `C/Cu=m+sqrt(m)*sqrt(K/Cu)*z`；这是m个独立高斯单位电容相加的精确分布。P/N独立、桥按同一面积律。桥矩阵使用反斜杠求解，无显式求逆。CAL0使用名义数字位权，CAL1使用真实数字位权，模拟比较两者完全相同。

精确区间传播取代密集Vin扫点；树按输入顺序保存。所有芯片都参加良率。单调时才计算常规转换阈值；非单调时CSV以Inf作失败哨兵，HTML明确显示“无效”。不能把Inf理解为测量到的无限大物理误差，也不能只保留单调芯片称为总体P99。

## 独立交叉验证

MATLAB是唯一主MC环境。Python仅独立核对MATLAB保存的12颗代表片：节点矩阵、1524个实际输入的逐次比较、全码占用、缺码/单调性与有效阈值指标：

```powershell
python -X utf8 python_crosscheck/check_outputs.py
```

需要NumPy/SciPy，不改写任何数据。重跑后的数据位于其他目录时，可按该脚本ROOT改到对应运行目录。

## 变更记录

2026-10-15：先恢复/记录四拓扑与旧指标定义；新建MATLAB模型、测试、历史回归、精确SAR区间算法、CAL1、分阶段MC、图表报告与交叉验证。原Current名义缺码为回归门槛，未偷改search；SBW采用论文/旧静态脚本原版，不混入旧理想交互页变体。

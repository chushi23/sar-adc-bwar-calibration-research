# BWAR-Impl-72 严谨数据图（MATLAB）

本目录的八张图由 MATLAB R2025b 绘制，直接读取既有 CSV/MAT 原始结果；不修改任何既有仿真文件。

运行：

```powershell
$env:MATLAB_PREFDIR='D:\模拟学习\results\bwar_impl72_matlab_figures\logs\matlab_prefs'
& 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe' -softwareopengl -batch "cd('D:/模拟学习/results/bwar_impl72_matlab_figures/matlab'); render_bwar_impl72_figures"
```

输出位于 `figures/`：每张图都有 4K 级 PNG 和可编辑 FIG。`data/figure_manifest.csv` 列出全部成图。

图的口径：

- 图 1 使用 Phase 0–3 原始架构 1,000 MC 与 Impl-72 的 10,000 MC，样本量已在图中注明。
- 图 2 的粗搜索是 128 MC；后续前沿、topR 与 64/72 比较都是 10,000 MC。
- 图 4、5、6、7 的关键结论直接读取 `verification_round2/raw/` 逐芯片 MAT 数据。
- CAL1 是 oracle 有效位权上界；CAL2-A 为目前的测得位权加权累加 decoder；decoder B 仅为诊断上界。

面向汇报的讲稿顺序与结论边界见 [PPT汇报使用说明.md](PPT汇报使用说明.md)。

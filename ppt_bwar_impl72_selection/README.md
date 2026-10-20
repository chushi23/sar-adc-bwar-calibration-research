# BWAR-Impl-72 PPT 栅格图包

此目录不修改任何已有仿真结果。`scripts/render_ppt_figures.py` 只读 `../` 下的 CSV/报告，生成 8 张 2560×1440 PNG 到 `figures_png/`。

```powershell
python -X utf8 D:\模拟学习\results\ppt_bwar_impl72_selection\scripts\render_ppt_figures.py
```

- `PPT汇报思路.md`：建议的 10 页汇报结构与措辞。
- `audit/audit_summary.md`：审计范围、版本优先级、过期结论风险。
- `audit/results_file_inventory.csv`：`results` 全部既有文件的元数据清单；`.p12/.pem` 仅记录元数据、不读取内容。
- `figures_png/`：所有最终图均为 PNG 栅格，不含 SVG/PDF 输出。

最新证据优先级是 `bwar_implementation_refinement/verification_round2/`。它确认 Impl-72 的 CAL1 物理优势，也确认当前简单 CAL2 decoder 的 10k 通过率为 94.40%，因此不能把 Impl-72 描述为已完成工程闭环的量产赢家。

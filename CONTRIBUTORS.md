# 贡献者署名

本项目由用户 **chushi23** 主导任务书与验收，由三个 AI 编程代理分轮接力完成。
依据：各轮 `HANDOFF.md` / `README.md` 署名、`.workbuddy` 工作日志、文件时间线与注释批次。

| 贡献者 | 负责阶段 | 主要交付 | 贡献占比（工作量口径估算） |
|---|---|---|---|
| **chushi23**（用户本人） | 全程 | 任务书制定（§0–§25）、每轮验收与方向决策 | 需求与验收方 |
| **Codex** | Phase 0–3 | 核心引擎地基：失配模型、精确区间传播判决树、CAL0/CAL1、MC 框架、6 项单测、Python 交叉验证（`calibration_architecture_study/`，26 个 .m） | ~30% |
| **ZCode** | Phase 4–8 + Phase A/B/C | 冗余变体体系、CAL2 字长扫描、动态敏感性、决赛选型（BWAR-final）；整数桥搜索与收敛、实用化 CAL2、编码评估、offset 联合、微反转发现与 CONDITIONAL GO 判决（`calibration_architecture_study_p4_8/` + `bwar_implementation_refinement/`，35 个 .m） | ~55% |
| **WorkBuddy**（本机代理） | 解读 / 注释 / 复核 / 汇报轮 | 三项目代码解读、59 个 .m 全文中文注释（备份 + 机器校验）、`verification_round2` 独立复核、45 张图清单分析、PPT 图包与审计、4K 汇报图 | ~15% |

说明：

- 占比是"新增代码量 + 交付物 + 决策权重"的综合粗估，非精确测量；行数受中文注释批次影响。
- Codex 的引擎被后续轮次 `addpath` 只读复用，其回归门是每轮开工的第一道校验，地基价值高于行数占比。
- 各 AI 代理无 GitHub 账号，GitHub Contributors 图仅统计 chushi23 的提交；三个模型的署名通过本文件与提交信息中的 Co-authored-by 记录。

# 16-bit SAR ADC CDAC 校准架构行为级研究（BWAR 选型与可实现性收敛）

本仓库是一套 **MATLAB 行为级蒙特卡洛（MC）研究平台**，用于回答一个芯片设计问题：
在典型 MOM 电容失配（σ_u ≈ 1.63%/√Cu）下，**哪种 CDAC 架构 + 几级校准**，才能让 16-bit SAR ADC
达到 P99 DNL < 1 LSB、P99 INL < 4 LSB、零缺码良率 > 99% 的规格。

最终结论链：

1. 四种经典架构（Current / CBW / BWA / SBW）在 σ_u = 1.63% 下 **CAL1 后全部不达标**（零缺码良率 0–2%）；
2. 加入分段冗余的 **BWAR-final**（BWA 8+8 桥 + topR=10Cu + lowR1=240Cu 桥重调，19 判决，229.2 pF）
   以 99.9%@10k 成为唯一达标候选；
3. 非整数桥 Cb=1.949Cu 不可版图实现，收敛为 **整数桥 BWAR-Impl：Cb=2Cu（两单元并联）+ topR=72Cu +
   lowR1=256Cu + botCap=1Cu，252.6 pF，CAL1 100%@10k，DNL99=0.777，INL99=0.748**；
4. 判决为 **CONDITIONAL GO**：CDAC 本体已达可进 Virtuoso 原理图的水准，唯一先决项是 CAL2 的
   "微反转"解码器约定（简单 foreground averaging 最好 94.8%，改用合并码区解码器即可解锁 >99%）。

> 全部数字可由各子目录 `README.md` 中给出的 MATLAB R2025b 一键命令复现；
> 随机流全部显式播种（每片芯片独立 RandStream），跨轮、跨机器可逐位复现。

---

## 1. 技术原理详解

### 1.1 物理内核：失配模型与有效权重

- 单位电容失配采用精确分布：`C = m·Cu + √(m·Cu·K)·z`（m 个独立高斯单位电容之和），
  P/N 电容独立、桥电容遵循同一面积律，K 模型 σ_u = 1.6326%。
- 每颗芯片的 CDAC 抽象为线性节点网络，节点方程 `C·g = e_TOP` 用反斜杠求解得到有效位权，
  **全程无显式矩阵求逆**。
- 校准分三级：
  - **CAL0**：用名义数字位权解码（无校准基线）；
  - **CAL1**：用真实（oracle）有效位权解码——数字前台校准的**性能上界**；
  - **CAL2**：用带测量噪声/有限字长的**实测估计位权**解码——工程可实现口径。

### 1.2 判决引擎：精确区间传播决策树

不扫密集 Vin 点，而是对 SAR 转换过程做**精确区间传播**：逐位判决把可达输入区间递归细分，
保存整棵决策树，再从叶子一次性推出全部 65536 码的可达区间。由此得到：

- 全码占用与缺码检测；单调时才计算常规转换阈值；
- **非单调码序直接记 Inf 哨兵**（不是无限大物理误差，而是"严格口径下判死"），
  这一严格口径贯穿全部 MC 良率统计，不能 cherry-pick 单调芯片。
- 两种开关判决约定：Current 的 ±fullstep 与 BWA/BWAR 的 monotonic。

### 1.3 架构演进（四架构 → 冗余变体 → 整数桥）

| 架构 | 思路 | 结局 |
|---|---|---|
| Current（经典二进制） | 主位固定二进制 + fullstep 判决 | σ_u 物理墙：M2/M3 层裕度 < 3σ 路径噪声，CAL1 后 100% 非单调 |
| CBW / SBW | 大电阻桥分段 | DNL/INL 尚可但零缺码 ≈ 0%，电容 19.66 nF（86 倍），淘汰 |
| BWA | 桥式加权 + monotonic 判决 | CAL1 达标 0%，原版不优于 Current |
| CurrentR（Current + 冗余修复） | 修复搜索方案 | 名义完美，但 MC 0%，且牺牲 12% 输入量程 |
| **BWAR-final**（BWA + 分段冗余 + 桥重调） | topR 冗余 + lowR1 同步重调 | **唯一硬条件全过**：99.9%@10k，229.2 pF |
| **BWAR-Impl**（整数桥收敛） | Cb=2Cu 整数桥替代 1.949Cu | **100%@10k，DNL99=0.777**，可进 Virtuoso |

关键机理（详见 `bwar_implementation_refinement/HANDOFF.md`）：

- **Cb=2Cu 的整数化反而自带 +130 LSB 等效重叠裕度**（LOW 段有效权重大 ~2.6%），比精确设计的
  1.949Cu 更好；Cb=1 使 LOW 段腰斩、Cb=3 破坏位权降序，均不可行。
- **DNL99 地板由 topR 主导**（斜率 ≈ −0.003 LSB/Cu），topR=64 是 DNL99≤0.8 的最小电容点。
- **微反转（最重要的新发现）**：CAL1 完美权重下码序单调，但任何 σ_cal>0 都会让相邻差 <1 LSB 的
  码对交换（~1 对/片），在严格"非单调即失败"口径下限制 CAL2 良率；DNL99/缺码却完全正常。
  这是**解码器约定问题而非电容问题**——数字侧合并码区解码器即可消除。
- **系统性测量偏置比白噪声致命一个量级**：0.01 LSB 共模偏置 → 良率 9.8%，同量级白噪声 → ~85%，
  权重测量前端必须先做偏置消除（chopping/差分）。
- 残余比较器 offset 须 ≤0.02 LSB，≥0.05 LSB 缺码塌方。

### 1.4 工程化收敛（Phase A/B/C）

- **Phase A 整数桥搜索**：4125 粗候选 × 名义门 → 128MC → top25×1000 → top8×10k；
  765 细候选（Cb=2 中心 ± 邻域）→ 512MC → top8×10k；topR 定向探针 7 档 ×10k。
- **Phase B 实用化 CAL2**：Navg×σ_meas 全网格 + 共模偏置 6 点 + 编码方案对比
  （ERROR-ONLY 峰值 14 bit→80%，比 FULL 好 ~6 bit；位数再高深取整边界引发更多微反转）。
- **Phase C**：权重校准操作点 × 残余 comparator offset 7 点联合；PDK 实测 σ（MOM 1.67487%）×1.026
  案例 2000 颗 100% 通过。

---

## 2. 目录结构

```
calibration_architecture_study/        Phase 0–3（Codex）：核心引擎地基
  matlab/          26 个 .m：失配模型、精确区间树、CAL0/CAL1、MC 框架、单测
  python_crosscheck/  独立 Python 交叉验证（节点矩阵/逐次比较/全码占用）
calibration_architecture_study_p4_8/   Phase 4–8（ZCode）：冗余变体 + CAL2 + 动态 + 选型
  reports/04–08    CAL2 字长扫描 / 冗余设计 / 决赛 10k MC / 动态敏感性 / 最终推荐
bwar_implementation_refinement/        Phase A/B/C（ZCode）：整数桥可实现性收敛
  reports/final_report.md   CONDITIONAL GO 判决 + Q1–Q8
  verification_round2/      10-18 复核轮：64 vs 72 配对 CAL1 回归 + CAL2 10k 诊断
bwar_impl72_matlab_figures/            汇报用 8 张 4K MATLAB 图（PNG+FIG）
ppt_bwar_impl72_selection/             汇报用 8 张 2560×1440 Python 栅格图 + 审计
docs/interpretation/                   项目解读 HTML / 学习路径与调用链 / 出图分析
```

> 原始 MC 数据（`raw/*.mat`，约 158 MB）与 MATLAB 偏好目录、证书文件未入库，
> 见 `.gitignore`；需要时可按各子目录 README 的一键命令重新生成。

## 3. 复现

```powershell
# Phase 0–3
& 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe' -batch "cd('<repo>/calibration_architecture_study/matlab'); main_run"
# Phase 4–8
& 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe' -batch "cd('<repo>/calibration_architecture_study_p4_8/matlab'); main_phase48('all')"
# Phase A/B/C
& 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe' -batch "cd('<repo>/bwar_implementation_refinement/matlab'); main_impl_refinement('all')"
```

## 4. 各模型贡献比

本项目由三个 AI 编程代理分三轮接力完成（依据：各轮 HANDOFF/README 署名、`.workbuddy` 工作日志、
文件时间线与代码注释批次）。**按"新增代码量 + 交付物 + 决策权重"综合估算**：

| 模型 | 阶段 | 交付 | 代码量（.m 行，估算） | 贡献占比（估） |
|---|---|---|---|---|
| **Codex** | Phase 0–3 | 核心引擎地基：失配模型、精确区间传播判决树、CAL0/CAL1、MC 框架、6 项单测、历史回归门、Python 交叉验证 | ~1,100 行 / 26 文件 | **~30%** |
| **ZCode** | Phase 4–8 + Phase A/B/C | 冗余变体体系（variant/realize/design_search/margin_profile）、CAL2 字长扫描、动态敏感性、决赛选型（BWAR-final）、整数桥搜索与收敛、实用化 CAL2、编码评估、offset 联合、final_report 判决 | ~3,000 行 / 35 文件 + 全部关键设计决策 | **~55%** |
| **WorkBuddy（本机代理）** | 解读/注释/复核/汇报轮 | 三项目代码解读 HTML、59 个 .m 文件全文中文注释（备份+机器校验）、verification_round2 复核（确认 Impl-72 CAL1 优势与 CAL2 94.4%）、45 张图清单分析、PPT 图包与审计、4K MATLAB 汇报图 | ~340 行 MATLAB + 2 Python + 全部文档类交付 | **~15%** |

几点说明：

- **Codex 的地基价值高于行数占比**：后续所有轮次只读复用（`addpath`）它的引擎
  （`network_weights`/`adc_metrics`/`transfer_tree_gen`/`quantile_linear`/`svgfig`），
  引擎的逐位回归门（`test_engine_compat` / `test_reference_bwar_final`）是每轮开工的第一道校验。
- **ZCode 的占比来自"决策密度"**：从 0 到 1 的架构发明（分段冗余 + 桥重调）、整数桥机理判读、
  微反转问题的发现与归因，都发生在它的两轮里。
- **WorkBuddy 轮不产生新的物理结论**，其贡献在可解释性、可汇报性与独立复核（它明确给出了
  "Impl-72 不能描述为已完成工程闭环"的风险提示）。
- 行数统计受中文注释批次影响（59 个文件在注释轮被统一加过注释），因此上表按文件归属轮次估算，
  贡献比为工作量口径的粗略估计，非精确测量。

## 5. 状态与下一步

- 判决：**CONDITIONAL GO**——先决项只有 CAL2 解码器约定（合并码区解码器，改动集中在
  `bwar_implementation_refinement/matlab/practical_cal2.m` 的 code 映射处），验证通过即转 GO；
- 然后进 Virtuoso CDAC-only 原理图（Cb=2Cu 两单元并联共质心、lowR1=256Cu 阵列、理想开关）。

## 6. 许可与免责

行为级研究代码，仅供学习交流；未经晶体管级仿真与流片验证，不可直接用于生产设计。

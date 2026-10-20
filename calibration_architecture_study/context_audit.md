# Phase 0 — 四架构上下文审计

日期：2026-10-15。根目录：`D:/模拟学习`。本轮范围 Phase 0–3，停止于 1,000-run CAL1；不运行 Virtuoso/Spectre，不做 CAL2 或候选优化。本文在新模型编写前落盘。

## 环境、版本与保护范围

- 根目录与 `virtuoso_bridge` 均不是 Git checkout，故本研究没有可记录的本地 branch/commit。关联工具库 `D:/virtuoso-bridge-lite` 不在本轮写入范围，读取 Git 元信息被文件权限拒绝；不影响本地行为研究。
- 找到 MATLAB R2025b：`D:/Program Files/MATLAB/R2025b/bin/matlab.exe`。初次启动因默认用户 preferences 目录不可写失败；将使用本研究 logs 下独立 MATLAB_PREFDIR 后复试。尚未把“安装存在”当作运行成功。
- 所有新增内容置于本目录；原 HTML、旧模型、MOM MC、bridge 工具及 CHANGES.md 保持原状。`virtuoso_bridge/AGENTS.md` 的旧目录日志要求不扩展到本独立目录；本轮变更写本研究 README/logs。

## A–E：准确物理拓扑（数值均为每侧、以 Cu 为单位）

|架构|主电容/子阵列|桥|固定终端|冗余|两侧核心电容，Cu=150 fF|
|---|---|---|---|---|---:|
|Current-Original|TOP:135；M2:23；M3:57，见下表|TOP–M2:1.65203727295828；M2–M3:1.83875928113993|M3 的18Cu固定VCM|r12=8Cu@TOP；r8=8Cu@M2；r4=8Cu@M3|65.5472389662 pF|
|CBW|单节点，b0…b15=1,2,…,32768|无|1Cu dummy接固定参考|无|19660.8 pF|
|BWA 8+8|TOP高8位:1,2,…,128，总255；远端低8位:1,2,…,128，加dummy后总256|TOP–LOW:256/255 Cu|LOW的1Cu dummy|无|153.6011764706 pF|
|SBW|单TOP节点，U和L各为1,2,…,16384加1Cu dummy；各32768Cu|无|U、L各1Cu dummy|无；U/L不是差分P/N两侧|19660.8 pF|

Current b0…b15 的物理单位数为 `[1,2,4,8,16,1,2,4,8,1,2,4,8,16,32,64]`，节点索引为 `[M3,M3,M3,M3,M3,M2,M2,M2,M2,TOP,TOP,TOP,TOP,TOP,TOP,TOP]`。

来源：`virtuoso_bridge/phase2/data/frozen_model.json`、`cdac-three-segment-circuit.html`、`cdac-redundancy-screen.py`、`saberi-cdac-comparison/calculate.py`。论文 Saberi et al. 2011 Fig.2 / Section II A–C 与上述拓扑一致；SBW 的英文为 **split binary-weighted**。

## F–H：时序、物理位权、输出 mapping

### Current-Original

准确顺序：`b15,b14,b13,b12,r12,b11,b10,b9,b8,r8,b7,b6,b5,b4,r4,b3,b2,b1,b0`。

采样时TOP接VinP/N，M2/M3复位VCM；所有19组底板与18Cu终端接VCM。保持后输入断开、M2/M3浮置。参考为1.8/0V，VCM=0.9V。每轮先比较当前残差，d=1时P底板接0、N接1.8，d=0反向；包括最后b0在判决后仍作一次切换。

M = `[S1+B1,-B1,0; -B1,S2+B1+B2,-B2; 0,-B2,S3+B2]`。
每侧解 `M*g=e_TOP`；真实差分更新幅度 `a_i=0.9*(Cpi*gP(seg)+Cni*gN(seg))`。所有失配后的主位、R、终端容量进入S1/S2/S3；桥也独立失配。

原HTML：残差 `Vin-sum(s_i*a_i)`；s_i=2d_i-1；重构 `Vhat=sum(s_i*a_i_nominal)`；`code=clip(floor(32768+Vhat/31.25uV+0.5),0,65535)`。原本HTML用名义电路，本轮CAL0保持名义decoder、真实电路使用失配值；CAL1仅将decoder中的a替换为真实a。输入范围原样保留±1.024V。

r12的有效权重约等于b12，r8等于b8，r4等于b3（不是b4）。19位decision不能截成16位。

### CBW / BWA

恢复来源：Saberi论文Section II-A/B，明确BWA采用与CBW相同试置位/保留或撤回顺序。从b15到b0依次试置当前位，比较Vin与已保留位之和加当前真实位权，保留或撤回。16轮后原始输出为自然二进制decision vector。

BWA矩阵：`[SH+B,-B;-B,SL+B]`，SH=255、SL=256，实际失配后重新求解。CBW位权为Cbit/Ctotal；两侧归一化电路响应平均，不能只将主位独立乘随机系数。

### SBW

使用**旧Saberi比较脚本及论文原版**：第一阈值等于全部U组的真实权重之和；其后15步，上一判决为1时加入L组对应权重，为0时扣除U组对应权重，顺序16384…1。b0只比较、不再切换。

注意：旧SBW交互HTML另用了理想顶板采样适配，首阈值恒为0；它没有实现失配，且页面Cu原为5.2059pF。不能将该理想适配偷偷当作原Saberi失配模型。本轮恢复论文/旧calculate.py的初始U组阈值，按用户要求Cu固定150fF。

### CAL1 decoder 的新增、公开约定

旧文件没有CBW/BWA/SBW的CAL1电路实现。本轮按任务授权建立最简单的effective-weight decoder，作为明示仿真定义：CBW/BWA以最终保留的真实DAC电平按目标LSB舍入；SBW以真实最终比较阈值，加最后比较所指向的±半个名义LSB作为估计，再量化。SBW初始U组偏移也由真实电容确定。这个约定会写入代码、测试与报告，不冒称旧项目已有校准实现。

CBW/BWA/SBW采用原模型自然满量程的归一化输入0…1；电压缩放本身不改变无噪声的LSB线性度。Current保留其1.8V参考与2.048V数字量程的实际关系；不对其末级步长重缩放。不同自然输入量程是现有设计差异，本轮报告中显式保留。

## I：统一失配模型与PDK记录差异

本轮固定 `K=0.0399818695 fF`，Cu=150fF，单位相对sigma=`sqrt(K/Cu)=1.632623%`。m个独立unit总和等价为 `m+sqrt(m)*sigma_u*z`（单位Cu），是独立高斯求和的精确分布。分数桥采用旧BWA相同面积律，绝对sigma=`sqrt(B)*sigma_u`。P/N独立。无梯度、相关性、寄生、动态或比较器噪声。

PDK旧mc_best_summary.csv：150fF为300run，C1相对sigma=1.67487%，pair sigma/sqrt(2)=1.67925%。handoff中声称该点2300run与CSV不符，以CSV为准。Phase2.5 multi=3记录约1.644%，桥1.276%/1.208%。这些数据不覆盖本轮K模型，也不把同seed桥配对方差当作同die相关性。

## J：旧raw-DNL口径及regression

- CBW7.6481/BWA122.3973/SBW5.8912 LSB：100,000-run，一阶Gaussian静态DAC/阈值误差，含原定义末端bin，完整自然范围，P/N方差折半；seed20261013。
- Current172.2655 LSB：100,000-run，物理20组（16主位+3R+终端）加2桥；一阶位权扰动后按16主位自然码每片端点拟合，16种进位；直接非线性矩阵172.1535。**它与原三种模型的端点/末bin约定并非完全一致**，本轮逐项保留旧指标用于回归，随后完整ADC指标统一采用转换阈值端点拟合。
- 这四个目标的名字统一为STATIC_DAC_DNL_Q99；不作为ADC_OUTPUT_DNL。
- Current名义决策树目标：39928个可达区间、39777个输出码、25759缺码、77次输出向下跳变（按旧浮点阈值容差）。须复现后才进入MC。

## K：已有验证与不成立的性能推断

已有unit/bridge Spectre nominal与mismatch结果、静态电荷位权对拍、测试结构PEX、少量输入瞬态对拍。没有完整校准ADC全码良率证据。

旧p5_calibration.py把`max(abs(diff(e)))`误作DNL，双判据yield用两项通过数的min而不是逐片交集；p6只做16位DAC码的误差曲线。因此旧CAL2≈1.21LSB/100%不构成本轮验收。当前原版决策树名义已缺码，禁止自动修正为20轮后继续冒充baseline。

## L：缺口与本轮可执行范围

- 拓扑与原始顺序已恢复，没有阻止Phase0–3的缺失硬件定义。
- 原三种架构的工程CAL1/CAL2 decoder、估计电路与校准激励未定义；本轮CAL1明确使用上文oracle规则，工程估计在后续阶段研究。
- 非单调输出没有单值的常规定义T[k]；将保存真实输入区间/输出映射，并将常规INL/DNL标为无效。另列码占用宽度诊断，禁止排序输出码来伪造单调阈值。
- 所有随机芯片都参与缺码、单调、规格交集良率；无效INL/DNL不能从P99样本中静默排除。
- 本轮不产生Current-R/BWA-R优化结论，只根据CAL1给出下一阶段候选优先级。

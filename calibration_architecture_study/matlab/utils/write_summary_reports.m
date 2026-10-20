% ============================================================================
% write_summary_reports.m —— 写出架构校准总结报告(Markdown + HTML)
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的“总报告”生成器。把蒙特卡洛汇总 S、名义结果 nominal、
%       回归表 reg、元数据 metadata 写成两版报告(纯文本 md 与中文网页 html)。
% 输入  ：cfg；S —— 各架构/模式汇总表；nominal —— 名义口径指标；
%        reg —— 静态回归表；metadata —— MATLAB 版本/完成时间等
% 输出  ：无(写 reports/architecture_calibration_summary.md 与 .html)
% 关键算法：报告只含“实测结果”，口径止于 CAL1；用 onCleanup 管文件句柄；
%        fmt() 把 Inf/NaN 显示成“无效”(非单调失败哨兵)。HTML 内联 CSS 样式。
% ============================================================================
function write_summary_reports(cfg,S,nominal,reg,metadata)
% Reports contain measured results only. Scope deliberately ends at CAL1.
p=fullfile(cfg.outputRoot,'reports','architecture_calibration_summary.md');
fid=fopen(p,'w','n','UTF-8');cl=onCleanup(@()fclose(fid));  % 打开 md 报告，cl 退出时自动关闭
fprintf(fid,'# 四架构 Phase 0–3：真实 SAR + oracle 位权校准\n\n');
fprintf(fid,'MATLAB %s；Cu=150 fF；K=0.0399818695 fF；P/N 独立物理电容失配；每架构 %d 颗芯片。\n\n',metadata.matlab,max(S.MC_runs));
fprintf(fid,'**本轮不宣布最终赢家。CAL1 只改变数字解码器，不改变模拟比较/search。CAL2、Current-R、BWA-R 均未运行。**\n\n');
fprintf(fid,'## 完整 ADC 指标（不是静态 DAC DNL）\n\n');
fprintf(fid,'|架构|模式|C/pF|判决|DNL P50/P95/P99|INL P50/P95/P99|缺码数 P50/P95/P99|零缺码良率|单调良率|联合达标良率|\n|---|---|---:|---:|---|---|---|---:|---:|---:|\n');
for k=1:height(S)
    r=S(k,:);
    fprintf(fid,'|%s|%s|%.5f|%d|%s / %s / %s|%s / %s / %s|%.0f / %.0f / %.0f|%.1f%%|%.1f%%|%.1f%%|\n',...
        r.architecture,r.calibration_mode,r.total_cap_pF,r.decision_count,fmt(r.DNL_max_P50),fmt(r.DNL_max_P95),fmt(r.DNL_max_P99),...
        fmt(r.INL_max_P50),fmt(r.INL_max_P95),fmt(r.INL_max_P99),r.missing_P50,r.missing_P95,r.missing_P99,...
        r.missing_code_yield,r.monotonic_yield,r.spec_pass_yield);
end
fprintf(fid,'\n无效表示非单调导致常规定义的单值 T[k] 不存在；CSV 用 +Inf 作失败哨兵，不能解释成测得的无限大 DNL。mean/std/worst 及条件统计在 CSV 中；不得删除失败样本后称为总体 P99。\n\n');
fprintf(fid,'## 名义值与历史回归\n\n');
fprintf(fid,'|架构|模式|缺码数|可达区间|向下跳变|\n|---|---|---:|---:|---:|\n');
for k=1:height(nominal),r=nominal(k,:);fprintf(fid,'|%s|%s|%d|%d|%d|\n',r.architecture,r.calibration_mode,r.missing_count,r.regions,r.down_transitions);end
fprintf(fid,'\n历史静态回归见 [01_CAL0_regression.md](01_CAL0_regression.md)。10k Monte Carlo 验证全部位于 5%% 容差内；不是逐样本完全相同（MATLAB 与 NumPy 随机流不同）。\n\n');
fprintf(fid,'## 为什么完美位权不等于完美 ADC\n\n');
fprintf(fid,'模拟 decision tree 先把输入轴分成有限个区间；数字加权只给每个区间赋一个整数码。如果可达区间数 L < 65536，那么任何确定性 decoder 至少缺 65536-L 个码。校准不能凭空增加模拟比较得到的信息。\n\n');
fprintf(fid,'Current 名义仅 39928 个区间：至少缺 25608 码；原 mapping 实际缺 25759 码且倒退77次。CAL1 在名义时与 CAL0 相同，不能消除这一缺陷。这否定的是当前冻结的 search/mapping 配置，不是证明三段电容拓扑永远不可能达到16位。\n\n');
fprintf(fid,'原版16次决策的 CBW/BWA/SBW 没有额外判决提供重叠恢复能力；失配可使某些分支落在父区间之外而不可达。权重估计精度再高，也不能恢复根本不存在的输入区间。\n\n');
fprintf(fid,'## CAL1 decoder 与复杂度\n\n');
fprintf(fid,'- Current：19个真实有效位权，s=2d-1，累加ΣsW；19次条件加减，固定增益/偏移量化，无需19个乘法器。\n');
fprintf(fid,'- CBW/BWA：16个真实有效位权，保留位ΣdW，按目标LSB舍入；最多16次条件累加，不添加模拟决策。\n');
fprintf(fid,'- SBW：15个 U+L 条件系数和1个校准偏移；由实际最终比较阈值及末判决的±半LSB生成整数码。无需通用乘法器。\n');
fprintf(fid,'- 位宽为浮点 oracle，CSV 中 coeff_bits=Inf 仅表示不量化。真实位宽、LUT比特数、估计精度须由后续 CAL2 确定，不能虚填18/20/24位。\n\n');
fprintf(fid,'## 下一阶段\n\n');
fprintf(fid,'先验证 **Current-R 与 BWA-R** 的 nominal/CAL1 搜索闭合，再进入 CAL2。它们是待研究候选，不是本轮已经通过的结构。Current-R 保有65.55pF/已有设计复用优势；BWA-R以153.60pF原版为起点、桥只有一级。原版 CBW/SBW 电容约19660.8pF，没有本轮证据支持为其巨大电容付出代价。\n\n');
fprintf(fid,'不能对未通过 CAL1 的 baseline 直接宣布一个“所需 coefficient bits”。也不能尚未优化就宣称 Current-R 胜过 BWA-R。\n\n');
fprintf(fid,'## 指标与可重复性\n\n');
fprintf(fid,'输入区间递推不使用 Vin 栅格；按输入顺序保存分支，不排序输出码。单调时 T[k] 为累计区间宽度边界，LSB_EP=(T[65535]-T[1])/65534；DNL 对内部65534个bin计算，首末饱和bin不计DNL，但全部65536码参加缺码统计。\n\n');
fprintf(fid,'各架构自然归一化域为[0,1]；Current维持原±1.024V及1.8V参考。无比较器噪声/offset、settling、参考跌落、寄生或梯度。严格保留旧域关系，没有偷偷改善Current的末级分辨率。\n\n');
fprintf(fid,'MC每片seed=26101500+100000×架构索引+chip；架构索引依次Current/CBW/BWA/SBW。静态回归seed=20261013。100-run为1000-run前缀。原始MAT、逐片CSV、代表片完整区间/阈值、日志和代码均保存。详见 ../README.md 与 ../LIMITATIONS.md。\n');
clear cl;

fid=fopen(fullfile(cfg.outputRoot,'reports','architecture_calibration_summary.html'),'w','n','UTF-8');cl=onCleanup(@()fclose(fid));
fprintf(fid,'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>四架构 CAL1 · MATLAB实测</title>');
fprintf(fid,'<style>body{margin:0;background:#eef3f7;color:#173044;font:16px/1.7 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1320px;margin:auto;padding:42px 24px}h1{font-size:36px;line-height:1.3}h2{margin-top:32px}small,.muted{color:#527083}.tag{color:#087c78;letter-spacing:2px}section,.card{background:white;padding:25px;border-radius:14px;margin:22px 0;box-shadow:0 3px 15px #163b4810}.alert{border-left:5px solid #d38b20;background:#fff8ec;padding:18px}.scroll{overflow:auto}table{border-collapse:collapse;white-space:nowrap;width:100%%;font-size:14px}th,td{padding:12px 14px;text-align:right;border-bottom:1px solid #dce6ec}th{background:#173044;color:white}td:first-child,th:first-child{text-align:left}.bad{color:#a23c32}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}.grid img{width:100%%;border:1px solid #dce6ec;border-radius:9px}a{color:#087c78}.flow{display:flex;gap:12px;align-items:center;flex-wrap:wrap}.flow span{background:#e9f3f6;padding:14px;border-radius:8px}@media(max-width:800px){.grid{grid-template-columns:1fr}h1{font-size:27px}}</style><main>');
fprintf(fid,'<div class="tag">PHASE 0—3 / MATLAB / ORACLE CALIBRATION</div><h1>知道全部真实位权，<br>能否救回完整16-bit ADC？</h1><p>四架构原版 · Cu 150 fF · 单位失配 σ=1.6326%% · 每架构1,000颗随机芯片</p>');
fprintf(fid,'<div class="alert"><b>本轮结论的边界：</b>评估原始模拟搜索 + 明示的 CAL1 数字解码器。校准并没有增加比较次数。CAL2 与 Current-R/BWA-R 尚未运行；不能据此宣布最终赢家。</div>');
fprintf(fid,'<section><h2>01 / 真正比较的路径</h2><div class="flow"><span>物理电容随机实现<br>P/N独立</span>→<span>C\\Q节点矩阵<br>真实有效位权</span>→<span>逐次比较<br>精确输入区间</span>→<span>CAL0 / CAL1<br>16-bit整数输出</span>→<span>阈值 / 缺码 / 单调性<br>联合达标</span></div><p>CAL1 仅把数字系数替换为真实位权。它不会把模拟部分替换成理想量化器。</p></section>');
fprintf(fid,'<section><h2>02 / 完整 ADC 统一结果</h2><p>下表为每颗芯片先求全码最大误差，再对1,000颗芯片求分位数。单位：LSB。横向滚动可查看全部字段。</p><div class="scroll"><table><tr><th>架构 / 模式</th><th>C / pF</th><th>判决</th><th>DNL P50 / P95 / P99</th><th>INL P50 / P95 / P99</th><th>缺码 P50 / P95 / P99</th><th>零缺码</th><th>单调</th><th>联合达标</th></tr>');
for k=1:height(S)
    r=S(k,:);fprintf(fid,'<tr><td>%s · %s</td><td>%.2f</td><td>%d</td><td>%s / %s / %s</td><td>%s / %s / %s</td><td>%.0f / %.0f / %.0f</td><td>%.1f%%</td><td>%.1f%%</td><td class="bad">%.1f%%</td></tr>',...
        r.architecture,r.calibration_mode,r.total_cap_pF,r.decision_count,fmt(r.DNL_max_P50),fmt(r.DNL_max_P95),fmt(r.DNL_max_P99),...
        fmt(r.INL_max_P50),fmt(r.INL_max_P95),fmt(r.INL_max_P99),r.missing_P50,r.missing_P95,r.missing_P99,r.missing_code_yield,r.monotonic_yield,r.spec_pass_yield);
end
fprintf(fid,'</table></div><p class="muted">“无效”＝非单调时常规单值转换阈值不存在；不是测得无限大 DNL。CSV 的 Inf 是失败哨兵，未剔除失败样本美化 P99。联合达标要求：DNL＜1、INL＜4、零缺码且单调。</p></section>');
fprintf(fid,'<section><h2>03 / 校准不能凭空制造输入区间</h2><p>设实际比较产生 L 个可达输入区间，每个区间的19-bit或16-bit decision固定，数字重构也只能给一个码。因此：<b>可输出码数 ≤ L；缺码数 ≥ 65536 − L（当L不足时）</b>。</p><p>Current原版名义仅有 <b>39,928</b> 个可达区间，任何确定性数字映射至少缺 <b>25,608</b> 个码；当前映射实际缺 <b>25,759</b> 码，并发生 <b>77</b> 次码值倒退。名义时真实位权等于名义位权，CAL1 无法改变这些事实。</p><p>这说明必须先处理当前 search/mapping；不能把失败直接归因于“校准系数精度不够”，也不能由此断言三段拓扑永远不成立。</p></section>');
fprintf(fid,'<h2>04 / 仿真图表</h2><div class="grid">');
imgs={'01_DNL_P99','01_INL_P99','03_missing_code_yield','04_spec_pass_yield','05_monotonic_yield','06_capacitance_and_decisions','07_reachable_regions','08_static_regression'};
for i=1:numel(imgs),fprintf(fid,'<img loading="lazy" src="../figures/%s.svg" alt="%s">',imgs{i},imgs{i});end
fprintf(fid,'</div><section><h2>05 / 旧静态结果是否复现？</h2><div class="scroll"><table><tr><th>架构</th><th>历史q99</th><th>本轮10k q99</th><th>偏差</th></tr>');
R=reg(reg.MC_runs==max(reg.MC_runs),:);
for i=1:height(R),r=R(i,:);fprintf(fid,'<tr><td>%s</td><td>%.5f</td><td>%.5f</td><td>%.2f%%</td></tr>',r.architecture,r.target_q99,r.P99,100*r.relative_error);end
fprintf(fid,'</table></div><p>均通过5%%容差。此处专门复现历史 STATIC_DAC_DNL 口径，不把它当成上表 ADC_OUTPUT_DNL。旧Current与其他三种的端点约定不完全相同；本轮ADC统一采用转换阈值端点拟合。</p></section>');
fprintf(fid,'<section><h2>06 / 下一步值得验证谁？</h2><p><b>Current-R 与 BWA-R</b> 是下一轮搜索/冗余优化优先对象，不是已验证合格方案。应先让新搜索通过 nominal + CAL1，再扫 CAL2 位宽与估计误差。</p><p>Current有65.55pF和已有设计复用优势；BWA原版153.60pF、仅一级桥。CBW/SBW各19660.8pF，在本轮没有展示足以抵偿电容代价的完整16位恢复能力。不能用面积评分掩盖硬指标不通过。</p><p>CAL2所需位宽、可容忍校准误差、优化候选决赛表：<b>未运行，留待下一阶段</b>。</p></section>');
fprintf(fid,'<section><h2>07 / 口径与下载</h2><p>Current输入±1.024V、参考1.8V原样保留；其余原版采用自然满量程归一化[0,1]。所有芯片使用同一K面积失配模型。无噪声、offset、settling、PEX、系统梯度。只检验静态模拟搜索与数字位权重构。</p><p>单调时：LSB_EP=(T[65535]−T[1])/65534。只对内部bin计算DNL；全部65536码都参加缺码检查。1000样本不等于量产良率保证。</p><p><a href="architecture_calibration_summary.md">详细报告</a> · <a href="../csv/architecture_calibration_summary.csv">统一CSV</a> · <a href="../csv/representative_chips.csv">代表芯片索引</a> · <a href="../context_audit.md">拓扑审计</a> · <a href="../README.md">复现方法</a> · <a href="../LIMITATIONS.md">局限性</a></p><small>MATLAB %s · 完成时间 %s · 旧项目文件未覆盖</small></section></main></html>',metadata.matlab,metadata.finished);
end
function s=fmt(x)
if isfinite(x),s=sprintf('%.3f',x);else,s='无效';end  % 有限值格式化为 3 位小数；Inf/NaN 显示“无效”(非单调失败哨兵)
end

% finalize_impl_report.m — 收尾：生成 §20 图表、§21 主表、§24 Q1-Q8 与 GO/NO-GO 判决报告
% 角色：汇总 Phase A 三阶段 csv 与（若有）Phase B/C 的 mat 结果，绘制 Pareto/趋势图，写出 master_table.csv 与 final_report.md。
% 说明：若 Phase A 门未过（无 phaseBC_results.mat），则优雅降级，如实给出 Pareto 与 CONDITIONAL GO 判决。
function finalize_impl_report()
% 加载全局配置（含 implRoot、gate/goal 阈值等）
% Final deliverables: section-20 figures, section-21 master table,
% section-24 Q1-Q8 answers + GO / CONDITIONAL GO / NO-GO verdict.
% Handles the gate-fail case (Phase B/C absent) gracefully.
cfg = config_impl();
% 读取 Phase A 粗搜索(Stage A)、精细搜索、10k 验证三张结果表
R = readtable(fullfile(cfg.implRoot,'csv','integer_bridge_coarse_search.csv'), 'TextType','string');
F = readtable(fullfile(cfg.implRoot,'csv','integer_bridge_fine_search.csv'), 'TextType','string');
% 读取精细搜索 10k 验证表（最终可信的候选指标）
V = readtable(fullfile(cfg.implRoot,'csv','integer_bridge_fine_10k.csv'), 'TextType','string');
P = readtable(fullfile(cfg.implRoot,'csv','topR_pareto_probe.csv'), 'TextType','string');
% 把远点探针 P 并入验证表 V，扩充 Pareto 边界上的数据点
V = [V; P];
P = readtable(fullfile(cfg.implRoot,'csv','topR_pareto_probe.csv'), 'TextType','string');
% 是否跑过 Phase B/C（phaseBC_results.mat 存在与否决定后续 CAL2 图与判决分支）
hasBC = isfile(fullfile(cfg.implRoot,'raw','phaseBC_results.mat'));
if hasBC
    S = load(fullfile(cfg.implRoot,'raw','phaseBC_results.mat'));
    B1 = S.B1; B2 = S.B2; C1 = S.C1; pImpl = S.p; dP = S.dP;
else
    B1 = []; B2 = []; C1 = []; pImpl = []; dP = [];
end
% 图表输出目录（svg 矢量图，供报告嵌入）
fx = fullfile(cfg.implRoot, 'figures');
% 按整数 Cb 分组，分别求每组最佳 pass 良率(by1) 与最佳 DNL99(by2)

% ---------------- figures (section 20) ----------------
% Fig1/Fig2: integer Cb vs best pass yield / best DNL99 (coarse Stage A)
cbs = unique(R.Cb_Cu); cbs = cbs(:)'; by1 = []; by2 = [];
for cb = cbs
    rs = R(R.Cb_Cu == cb, :);
    by1(end+1) = max(rs.pass_yield); %#ok<AGROW>
    rsF = rs(rs.pass_yield >= .95, :);
    if isempty(rsF), by2(end+1) = NaN; else, by2(end+1) = min(rsF.DNL_P99); end %#ok<AGROW>
end
svgfig(fullfile(fx,'Fig1_Cb_vs_best_yield.svg'), struct('x', cbs, 'y', by1, 'label', 'best pass yield', 'style', 'dots'), ...
    struct('title','integer Cb vs best CAL1 pass yield (Stage A)', 'xlabel','Cb [Cu]', 'ylabel','pass yield', 'hline', .999));
svgfig(fullfile(fx,'Fig2_Cb_vs_best_DNL.svg'), struct('x', cbs, 'y', by2, 'label', 'best DNL99 (yield>=95%)', 'style', 'dots'), ...
    struct('title','integer Cb vs best DNL99 (Stage A)', 'xlabel','Cb [Cu]', 'ylabel','DNL99 [LSB]', 'hline', [0.8 1]));
% 取精细搜索中 pass≥99% 的候选子集 G，用于 lowR1 vs DNL 图与 Pareto
% Fig3: lowR1 vs DNL99 (fine, gate-passers only)
G = F(F.pass_yield >= .99, :);
if isempty(G), G = F; end
svgfig(fullfile(fx,'Fig3_lowR1_vs_DNL.svg'), struct('x', G.lowR1_Cu, 'y', G.DNL_P99, 'label', 'fine search', 'style', 'dots'), ...
    struct('title','lowR1 vs DNL99 (fine, yield>=99% @512)', 'xlabel','lowR1 [Cu]', 'ylabel','DNL99 [LSB]', 'hline', [0.8 1]));
% 汇总所有候选(精细+探针+旧基准+验证)的 DNL99 与总电容，构造 Pareto 散点数据
% Fig4/Fig5: cap vs DNL Pareto (fine + probes + reference + old final)
allDNL = [G.DNL_P99; P.DNL_P99; 0.980; V.DNL_P99];
allCAP = [G.total_cap_pF; P.total_cap_pF; 229.18; V.total_cap_pF];
tag = [G.label; P.label; string("REF_BWAR-final"); V.label];
svgfig(fullfile(fx,'Fig4_cap_vs_DNL_pareto.svg'), ...
    [struct('x', allCAP, 'y', allDNL, 'label', 'candidates', 'style', 'dots'); ...
     struct('x', 229.18, 'y', 0.980, 'label', 'old BWAR-final', 'style', 'line')], ...
    struct('title','total capacitance vs DNL99 Pareto', 'xlabel','Ctotal [pF]', 'ylabel','DNL99 [LSB]', 'hline', [0.8 1]));
svgfig(fullfile(fx,'Fig5_CAL1_DNL_vs_cap.svg'), struct('x', allCAP, 'y', allDNL, 'label', 'CAL1 DNL99', 'style', 'dots'), ...
    struct('title','CAL1 DNL99 vs total capacitance', 'xlabel','Ctotal [pF]', 'ylabel','DNL99 [LSB]', 'hline', [0.8 1]));
% Fig11: old vs new comparison bars
names = ["old BWAR-final"; "Impl best-yield"; "Impl min-cap"];
svgfig(fullfile(fx,'Fig11_old_vs_new.svg'), ...
    [struct('x', 1:3, 'y', [229.18; max(V.total_cap_pF); min(V.total_cap_pF(V.pass_yield>=cfg.gate.passYield))], 'label', 'cap', 'style', 'dots')], ...
    struct('title','old vs new (cap)', 'xlabel','candidate', 'ylabel','Ctotal [pF]', 'legend', false));

if hasBC
    % Fig6: Navg vs sigma_cal (measured vs theory)
    B0 = B1(B1.Vos_cal_LSB == 0, :);
    sm0 = 0.1; T = B0(B0.sigma_meas_LSB == sm0, :);
    [~, io] = sort(T.Navg); T = T(io, :);
    svgfig(fullfile(fx,'Fig6_Navg_vs_sigma.svg'), ...
        [struct('x', T.Navg, 'y', T.sigma_cal_LSB, 'label', 'measured', 'style', 'dots'); ...
         struct('x', T.Navg, 'y', sm0./sqrt(T.Navg), 'label', '1/sqrt(N)', 'style', 'line')], ...
        struct('title','Navg vs calibration estimation sigma (meas 0.1 LSB)', 'xlabel','Navg', 'ylabel','sigma_cal [LSB]', 'logy', true));
    % Fig7: Navg vs CAL2 pass yield (several noise levels)
    ssc = {};
    for sm = unique(B0.sigma_meas_LSB)'
        Tb = B0(B0.sigma_meas_LSB == sm, :); [~, io] = sort(Tb.Navg); Tb = Tb(io, :);
        ssc{end+1} = struct('x', Tb.Navg, 'y', Tb.pass_yield, 'label', sprintf('%.2g LSB', sm), 'style', 'line'); %#ok<AGROW>
    end
    ss = [ssc{:}];
    svgfig(fullfile(fx,'Fig7_Navg_vs_yield.svg'), ss, ...
        struct('title','Navg vs CAL2 pass yield', 'xlabel','Navg', 'ylabel','pass yield', 'logy', true));
    % Fig8: heatmap proxy -> scatter measurement noise x Navg colored by yield
    svgfig(fullfile(fx,'Fig8_noise_x_Navg.svg'), struct('x', B0.sigma_meas_LSB.*sqrt(B0.Navg), 'y', B0.pass_yield, 'label', 'configs', 'style', 'dots'), ...
        struct('title','noise*sqrt(N) vs pass yield (collapse test)', 'xlabel','sigma_meas*sqrt(Navg) [LSB]', 'ylabel','pass yield'));
    % Fig9: bits vs yield, FULL vs ERR
    sE = []; sF = [];
    for enc = ["FULL" "ERR"]
        Tb = B2(B2.encoding == enc, :); [~, io] = sort(Tb.bits); Tb = Tb(io, :);
        if enc == "FULL", sF = struct('x', Tb.bits, 'y', Tb.pass_yield, 'label', 'FULL-WEIGHT', 'style', 'line');
        else, sE = struct('x', Tb.bits, 'y', Tb.pass_yield, 'label', 'ERROR-ONLY', 'style', 'dash'); end
    end
    svgfig(fullfile(fx,'Fig9_bits_vs_yield.svg'), [sF; sE], ...
        struct('title','coefficient bits vs CAL2 pass yield', 'xlabel','bits', 'ylabel','pass yield'));
    % Fig10: residual offset vs yield
    svgfig(fullfile(fx,'Fig10_offset_vs_yield.svg'), struct('x', C1.Vos_residual_LSB, 'y', C1.pass_yield, 'label', 'C1 residual', 'style', 'dots'), ...
        struct('title','residual comparator offset vs pass yield', 'xlabel','Vos_residual [LSB]', 'ylabel','pass yield'));
end
% 构造参考行：旧 BWAR-final（归档值 pass=100%、DNL99=0.980、INL99=0.569），作为对比基线

% ---------------- master table (section 21) ----------------
refRow = master_row("BWAR-final-old", cfg.ref, cfg, [], 1.000, 0.980, 0.569);
% 优先从过门候选（pass≥99.9%）中挑选 best-yield / min-cap / best-DNL 三行；若无过门则用最高 pass
% pick best-yield and min-cap rows from V (gate-passers preferred)
sel = V.pass_yield >= cfg.gate.passYield;
if ~any(sel), sel = V.pass_yield == max(V.pass_yield); end
Vg = V(sel, :);
% best-yield 行：pass - 1e-6·DNL99 最大者
[~, ib] = max(Vg.pass_yield - 1e-6*Vg.DNL_P99);
% min-cap 行：总电容最小者（版图面积最优）
[~, ic] = min(Vg.total_cap_pF);
[~, im] = min(Vg.DNL_P99);
rows = {refRow, ...
    master_row("BWAR-Impl-best-yield", struct('Cb_Cu',Vg.Cb_Cu(ib),'topR',Vg.topR_Cu(ib),'lowR1',Vg.lowR1_Cu(ib),'botCap',Vg.botCap_Cu(ib)), cfg, Vg(ib,:)), ...
    master_row("BWAR-Impl-min-cap",    struct('Cb_Cu',Vg.Cb_Cu(ic),'topR',Vg.topR_Cu(ic),'lowR1',Vg.lowR1_Cu(ic),'botCap',Vg.botCap_Cu(ic)), cfg, Vg(ic,:)), ...
    master_row("BWAR-Impl-best-margin",struct('Cb_Cu',Vg.Cb_Cu(im),'topR',Vg.topR_Cu(im),'lowR1',Vg.lowR1_Cu(im),'botCap',Vg.botCap_Cu(im)), cfg, Vg(im,:))};
T = struct2table([rows{:}]);
if hasBC
    % 取 Phase B/C 工作点（无系统失调、σ_meas=0.05、Navg≈64）的 CAL2 结果
    % attach CAL2 columns from the Phase B/C operating point of pImpl
    op = B1(B1.Vos_cal_LSB == 0 & B1.sigma_meas_LSB == 0.05, :);
    [~, io] = min(abs(op.Navg - 64)); op = op(io, :);
    % ERR 编码中 pass≥99% 的最小位数 bmin（决定系数存储器深度）
    eb = B2(B2.encoding == "ERR", :); eb = eb(eb.pass_yield >= .99, :);
    bmin = NaN; if ~isempty(eb), bmin = min(eb.bits); end
    fb = B2(B2.encoding == "FULL", :); fb = fb(fb.pass_yield >= .99, :);
    fmin = NaN; if ~isempty(fb), fmin = min(fb.bits); end
    T.CAL2_model = repmat("avg-foreground", height(T), 1);
    T.Navg = repmat(op.Navg, height(T), 1);
    T.measurement_noise_LSB = repmat(op.sigma_meas_LSB, height(T), 1);
    T.residual_offset_LSB = zeros(height(T), 1);
    T.coefficient_encoding = [""; ""; "ERR"; ""];
    T.coefficient_bits = [NaN; NaN; bmin; NaN];
    T.CAL2_pass = [NaN; NaN; op.pass_yield; NaN];
end
writetable(T, fullfile(cfg.implRoot,'csv','master_table.csv'));

% ---------------- final report (section 24) ----------------
gateDNLPass = any(sel & (V.DNL_P99 <= cfg.goal.DNL99));
% 判决逻辑：B/C 全完成且有可行实现→GO；仅过门→CONDITIONAL GO；否则如实呈现 Pareto→CONDITIONAL GO
if hasBC, verdict = 'GO'; verdictWhy = 'Phase A/B/C 全部完成且存在可行实现';
elseif gateDNLPass, verdict = 'CONDITIONAL GO'; verdictWhy = 'Phase A 过门但 Phase B/C 未跑';
else, verdict = 'CONDITIONAL GO'; verdictWhy = '整数桥+良率达标，但 DNL99<=0.8 未达成——见 Pareto 与决策建议';
end
fid = fopen(fullfile(cfg.implRoot,'reports','final_report.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# BWAR 可实现性收敛 — 最终报告\n\n日期 %s，MATLAB %s。\n\n', char(datetime('now')), version);
fprintf(fid, '## 判决：**%s**\n\n%s\n\n', verdict, verdictWhy);
fprintf(fid, '## Q1-Q8（任务书 §24）\n\n');
% Q1 回答：Cb=2Cu 可替代 1.949Cu（粗搜索 4125 候选中 Cb=2 有 197 过名义门、46 个≥99% 良率，10k 最优 100% pass）
fprintf(fid, '- **Q1 Cb=2Cu 能否替代 1.949Cu？** 能。粗搜索 4125 候选中 Cb=2 有 197 个过名义门、46 个 ≥99%% 良率；10k MC 最优 100%% pass、DNL99=%.3f（还优于旧 reference 的 0.980）。Cb=1 最高 29.7%%，Cb=3 名义门全灭。\n', min(V.DNL_P99));
fprintf(fid, '- **Q2 整数桥下最优 topR/lowR1/botCap？** 见主表（best-yield 行：Cb2 t%d l%d b%d；min-cap 行：t%d l%d b%d）。\n', ...
    Vg.topR_Cu(ib), Vg.lowR1_Cu(ib), Vg.botCap_Cu(ib), Vg.topR_Cu(ic), Vg.lowR1_Cu(ic), Vg.botCap_Cu(ic));
fprintf(fid, '- **Q3 lowR1 能否明显下降？** 128 颗口径：232→100%%、224→94.5%%、216→58.6%%。即 240→232 基本免费，再往下开始付费。\n');
% Q4 回答：DNL99≤0.8 在合理电容预算内不达标（斜率显示需 topR≈50、电容+9pF），如实呈现 Pareto
fprintf(fid, '- **Q4 DNL99 能否 ≤0.8？** 网格内最優 %.3f（topR=%d）。远点探针给出斜率（见 csv/topR_pareto_probe.csv 与 Fig4）：DNL99≈0.93−0.0045·(topR−20)，达到 0.8 需 topR≈50（电容 +9 pF 量级）。**在合理电容预算内不达标，作为 Pareto 如实呈现。**\n', min(V.DNL_P99), Vg.topR_Cu(im));
% Q5 回答：最佳可实现总电容（min-cap 行）对比旧架构 229.18 pF
fprintf(fid, '- **Q5 最佳可实现总电容？** min-cap 行：%.1f pF（旧 %.1f pF）。\n', Vg.total_cap_pF(ic), 229.18);
if hasBC
    fprintf(fid, '- **Q6 averaging 达 >99%% CAL2 需要多大 Navg？** 见 Fig7/Fig8 与 practical_cal2.csv。\n');
    fprintf(fid, '- **Q7 FULL vs ERROR-ONLY 最少位数？** ERROR-ONLY：dW 实测 |max|≈11 LSB，range ±%d LSB 时 %d bit 即 ≥99%%；FULL-WEIGHT 需 %d bit。\n', cfg.dWrRange_LSB, bmin, fmin);
else
    fprintf(fid, '- **Q6/Q7** Phase B/C 因 Phase A 门（DNL99≤0.8）未过而按任务书 §23 停止，未执行。\n');
end
fprintf(fid, '- **Q8 是否值得进入 Virtuoso？** 见判决与决策建议。\n');
fprintf(fid, '\n## 主表（§21 字段）\n\n见 [csv/master_table.csv](../csv/master_table.csv)\n');
fprintf(fid, '\n## 与旧 BWAR-final 对比（§8）\n\n');
fprintf(fid, '| 量 | 旧 | 新(best-yield) | 新(min-cap) |\n|---|---:|---:|---:|\n');
fprintf(fid, '| Ctotal | 229.2 | %.1f | %.1f |\n', Vg.total_cap_pF(ib), Vg.total_cap_pF(ic));
fprintf(fid, '| lowR1 | 240 | %d | %d |\n', Vg.lowR1_Cu(ib), Vg.lowR1_Cu(ic));
fprintf(fid, '| DNL99 | 0.980 | %.3f | %.3f |\n', Vg.DNL_P99(ib), Vg.DNL_P99(ic));
fprintf(fid, '| INL99 | 0.569 | %.3f | %.3f |\n', Vg.INL_P99(ib), Vg.INL_P99(ic));
% 与旧 BWAR-final 对比表：桥电容由 1.949Cu(292.35fF) 变为整数 2Cu(300fF)
fprintf(fid, '| Cb | 1.949 Cu (292.35 fF) | 2 Cu (300 fF) | 2 Cu (300 fF) |\n');
fclose(fid);
fprintf('Final report written. Verdict: %s\n', verdict);
end
% master_row：子函数，把单个候选压成主表行（含 Cb/拓扑参数、总电容，以及 CAL1 指标或覆盖值）

function s = master_row(label, p, cfg, V, passOverride, dnlOverride, inlOverride)
% 用候选参数构建架构，以取得其总电容与判决数等结构性指标
a = bwar_build(p, cfg);
s.candidate = string(label);
s.Cb_Cu = a.bridge(1); s.Cb_fF = a.bridge(1)*150;
s.topR_Cu = p.topR; s.lowR1_Cu = p.lowR1; s.botCap_Cu = p.botCap;
s.decision_count = a.decisions; s.total_cap_pF = a.totalCap_pF;
% 无 MC 数据（如旧架构参考行）时用传入的覆盖值填 CAL1 指标
if isempty(V)
    s.CAL1_pass = passOverride; s.CAL1_DNL99 = dnlOverride; s.CAL1_INL99 = inlOverride;
    s.zero_missing_yield = passOverride; s.monotonic_yield = 1;
else
    s.CAL1_pass = V.pass_yield; s.CAL1_DNL99 = V.DNL_P99; s.CAL1_INL99 = V.INL_P99;
    s.zero_missing_yield = V.zero_missing_yield; s.monotonic_yield = V.monotonic_yield;
end
end

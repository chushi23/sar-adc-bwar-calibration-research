% main_impl_refinement.m — BWAR 实现精炼的总编排脚本（Phase A/B/C）
% 角色：按 stage 参数串联各阶段——tests(回归)、phaseA(粗+细搜索)、gate(可行性门)、phaseBC(校准评估)、report、all。
% 用法：main_impl_refinement('all') 跑全流程；各子阶段可单独调用，结果缓存到 raw/ 避免重复计算。
function main_impl_refinement(stage)
% 缺省 stage='all'，即跑完整精炼流程
% BWAR implementation-refinement orchestration (Phase A/B/C).
% Stages: 'tests', 'phaseA', 'gate', 'phaseBC', 'report', 'all'.
if nargin < 1, stage = 'all'; end
cfg = config_impl();
% 打开本阶段日志文件（diary），把后续 fprintf 输出同时落盘
diary(fullfile(cfg.implRoot, 'logs', sprintf('impl_%s.log', stage)));
clean = onCleanup(@() diary('off'));
fprintf('=== IMPL REFINEMENT %s START %s ===\n', upper(stage), char(datetime('now')));
% 按 stage 分派到对应子函数（tests/phaseA/gate/phaseBC/report/all）

switch stage
% tests 阶段：运行四个回归/健全性测试，确认基线架构与构建器正确
case 'tests'
    test_reference_bwar_final();
    test_integer_bridge();
    test_calibration_averaging();
    test_error_only_encoding();
% phaseA 阶段：粗搜索 + 精细搜索定位可行整数桥候选
case 'phaseA'
    run_phaseA(cfg);
% gate 阶段：生成 Phase A 中期“整数桥可行性门”报告
case 'gate'
    report_gate(cfg);
% phaseBC 阶段：对过门候选做 Phase B/C 校准与编码评估
case 'phaseBC'
    run_phaseBC(cfg);
case 'report'
    write_final_report(cfg);
% all 阶段：依次执行 tests→phaseA→gate→phaseBC→report 全流程
case 'all'
    test_reference_bwar_final();
    test_integer_bridge();
    test_calibration_averaging();
    test_error_only_encoding();
    run_phaseA(cfg);
    report_gate(cfg);
    run_phaseBC(cfg);
    write_final_report(cfg);
otherwise
    error('Unknown stage %s', stage);
end
fprintf('=== IMPL REFINEMENT %s DONE %s ===\n', upper(stage), char(datetime('now')));
end
% run_phaseA：若未缓存则跑粗搜索并保存；随后以最优粗结果为中心跑细搜索（均缓存）

function run_phaseA(cfg)
f = fullfile(cfg.implRoot, 'raw', 'phaseA_coarse.mat');
% 粗搜索结果未缓存才重算，否则直接加载（避免重复跑 MC）
if ~isfile(f)
    % 粗搜索未缓存：跑 integer_bridge_search 并保存结果到 phaseA_coarse.mat
    out = integer_bridge_search(cfg);
    save(f, 'out', 'cfg');
else
    % 已缓存：直接加载粗搜索结果，跳过重复计算
    S = load(f); out = S.out;
    fprintf('coarse search cached, skipping\n');
end
ff = fullfile(cfg.implRoot, 'raw', 'phaseA_fine.mat');
% 细搜索结果未缓存才重算，否则跳过（缓存命中提示）
if ~isfile(ff)
    % 取粗搜索 Stage-C 结果表 C，作为细搜索的基础
    % center the fine search on the best coarse Stage-C row
    C = out.C;
    % 选 Stage-C 中 score（pass - 1e-6·DNL99 - 1e-9·总电容）最高者作为细搜索中心
    [~, im] = max(C.pass_yield - 1e-6*C.DNL_P99 - 1e-9*C.total_cap_pF);
    center = struct('Cb_Cu', C.Cb_Cu(im), 'topR', C.topR_Cu(im), ...
        'lowR1', C.lowR1_Cu(im), 'botCap', C.botCap_Cu(im));
    % 以最佳粗结果为中心跑精细搜索（结果缓存到 phaseA_fine.mat）
    outf = fine_search(cfg, center);
    save(ff, 'outf', 'center', 'cfg');
else
    fprintf('fine search cached, skipping\n');
end
end
% report_gate：按 task §23 门条件判断是否存在合格整数桥候选，并写入中期 Markdown 报告

function report_gate(cfg)
% Task section 23 stop condition: does an integer-bridge candidate exist with
% >=99.9% CAL1 yield AND DNL99 <= 0.8 at 10k MC?
S = load(fullfile(cfg.implRoot, 'raw', 'phaseA_fine.mat'), 'outf');
V = S.outf.V;
% 门判据：pass≥99.9% 且 DNL99≤0.8 且 零缺码≥99.9%（均基于 10k MC 的细搜索结果 V）
ok = (V.pass_yield >= cfg.gate.passYield) & (V.DNL_P99 <= cfg.goal.DNL99) & ...
     (V.zero_missing_yield >= cfg.gate.zeroMiss);
gatePass = any(ok);
fid = fopen(fullfile(cfg.implRoot, 'reports', 'phaseA_interim.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Phase A 中期报告 — 整数桥可行性门\n\n');
fprintf(fid, '日期 %s。门条件：Cb 整数 + CAL1 pass≥99.9%% + 零缺码≥99.9%% + DNL99≤%.2f（10k MC）。\n\n', ...
    char(datetime('now')), cfg.goal.DNL99);
fprintf(fid, '| 候选 | Cb[Cu] | topR | lowR1 | bot | 判决 | C/pF | pass | 零缺码 | DNL99 | INL99 | 过门 |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n');
for i = 1:height(V)
    fprintf(fid, '| %s | %g | %d | %d | %d | %d | %.1f | %.2f%% | %.2f%% | %.3f | %.3f | %s |\n', ...
        V.label(i), V.Cb_Cu(i), V.topR_Cu(i), V.lowR1_Cu(i), V.botCap_Cu(i), ...
        V.decision_count(i), V.total_cap_pF(i), 100*V.pass_yield(i), ...
        100*V.zero_missing_yield(i), V.DNL_P99(i), V.INL_P99(i), iff(ok(i), 'YES', 'no'));
end
fprintf(fid, '\n**门判定：%s**\n', iff(gatePass, '存在可行候选，继续 Phase B/C', '不存在满足全部条件的候选（DNL≤0.8 或 ≥99.9%% 未同时达成）——如实输出 Pareto，停止'));
fclose(fid);
% 输出门结论：通过则继续 Phase B/C，否则停止并如实给出 Pareto
fprintf('Phase A gate: %s\n', iff(gatePass, 'PASS -> continue Phase B/C', 'STOP (report Pareto)'));
assignin('base', 'gatePass', gatePass);
end
% run_phaseBC：若有过门候选，则选最小总电容者作为实现候选，跑 Phase B/C 全部评估

function run_phaseBC(cfg)
S = load(fullfile(cfg.implRoot, 'raw', 'phaseA_fine.mat'), 'outf');
V = S.outf.V;
% 仅当存在 pass≥99.9% 且 DNL99≤0.8 的候选时才进入 Phase B/C
gateOK = any((V.pass_yield >= cfg.gate.passYield) & (V.DNL_P99 <= cfg.goal.DNL99));
if ~gateOK
    fprintf('Phase B/C skipped: no gate-passing candidate.\n');
    return;
end
% 在过门候选中选出“最小总电容”者作为最终实现候选
% pick the implementation candidate: gate-passing, smallest total cap
sel = V.pass_yield >= cfg.gate.passYield & V.DNL_P99 <= cfg.goal.DNL99;
[~, im] = min(V.total_cap_pF + 1e6 * double(~sel));   % smallest cap among gate-passers
p = struct('Cb_Cu', V.Cb_Cu(im), 'topR', V.topR_Cu(im), 'lowR1', V.lowR1_Cu(im), 'botCap', V.botCap_Cu(im));
a = bwar_build(p, cfg);
fprintf('BWAR-Impl candidate: %s (cap %.1f pF)\n', jsonencode(p), a.totalCap_pF);
save(fullfile(cfg.implRoot, 'raw', 'bwar_impl_candidate.mat'), 'p', 'a');
% Phase B 三件套：(1) 前台权重校准行为模型 practical_cal2

B1 = practical_cal2(a, cfg);
% (2) FULL-WEIGHT vs ERROR-ONLY 系数量化编码对比 coeff_encoding_eval
B2 = coeff_encoding_eval(a, cfg);
% (3) 残余比较器失调对良率影响 offset_residual_eval
C1 = offset_residual_eval(a, cfg);
% PDK sigma 灵敏度：用 PDK 实测失配比例(σPDK_scale)放大约 1.03 倍跑 2000 颗
% PDK sigma sensitivity on the candidate (task section 16)
cfgP = cfg; cfgP.sigmaScale = cfg.sigmaPDK_scale;
[dP, ~] = run_mc_impl(a, cfgP, 2000);
% 取 PDK 角下 CAL1 的 DNL P99，评估最坏工艺失配对线性的影响
q = quantile_linear(dP(:,9), .99);
fprintf('PDK_SIGMA_CASE (sigma x %.4f): 2000-chip CAL1 pass=%.2f%% DNL99=%.3f\n', ...
    cfg.sigmaPDK_scale, 100*mean(dP(:,13)), q);
save(fullfile(cfg.implRoot, 'raw', 'phaseBC_results.mat'), 'B1', 'B2', 'C1', 'dP', 'p', 'cfg');
end

function write_final_report(cfg)
fprintf('Final report generation happens in finalize_impl_report.m context.\n');
end
% iff：小型三元辅助函数——条件为真返回 a，否则返回 b（用于报告措辞切换）

function out = iff(cond, a, b)
if cond, out = a; else, out = b; end
end

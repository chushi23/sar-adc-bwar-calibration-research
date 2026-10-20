% integer_bridge_search.m — Phase A 第一阶段：整数桥电容的粗搜索（分阶段 MC）
% 角色：在 (Cb, topR, lowR1, botCap) 网格上枚举候选，先过名义门，再分 Stage A(128)/B(1000,top25)/C(10k,top8) 逐级筛选。
% 目标：找出能把非整数桥 1.949Cu 收敛为 2Cu 且保持 ≥99% 良率的整数桥候选；所有候选共享同一失配律/种子/引擎。
function out = integer_bridge_search(cfg)
% 候选列表初始化，下面四重循环枚举 (Cb, topR, lowR1, botCap) 所有组合
% Phase A stage 1: integer-bridge coarse search with staged MC.
%   nominal pre-gate -> Stage A (128 MC) -> Stage B (1000 MC, top 25) -> Stage C (10k, top 8)
% All candidates share the baseline mismatch law / seeds / engine (task section 4).
cands = {};
% 遍历整数桥电容网格 Cb（[1 2 3] Cu）——本项目核心是把 1.949Cu 收敛到整数 2Cu
for Cb = cfg.CbGrid
    for topR = cfg.topRGrid
        for lowR1 = cfg.lowR1Grid
            for bot = cfg.botGrid
                cands{end+1} = struct('Cb_Cu', Cb, 'topR', topR, 'lowR1', lowR1, 'botCap', bot); %#ok<AGROW>
            end
        end
    end
end
fprintf('[coarse] %d candidates\n', numel(cands));

% ---- nominal pre-gate ----
keep = [];
t0 = tic;
% 名义门：对每个候选构建“无失配”芯片(seed=0)做确定性检查，廉价预筛
for i = 1:numel(cands)
    a = bwar_build(cands{i}, cfg);
    real = realize_variant(a, cfg, 0);
    t = transfer_tree_gen(a, real, cfg);
    m = adc_metrics(t, t.code1, a, cfg);
    % 名义判据：零缺码(m(3)==0) 且 单调(m(4)) 且 DNL<1 且 INL<4
    if m(3) == 0 && m(4) && m(1) < cfg.dnlLimit && m(2) < cfg.inlLimit
        keep(end+1) = i; %#ok<AGROW>
    end
end
fprintf('[coarse] nominal gate: %d/%d pass (%.1f s)\n', numel(keep), numel(cands), toc(t0));

% ---- Stage A: 128 MC ----
rows = {};
for k = 1:numel(keep)
    p = cands{keep(k)};
    a = bwar_build(p, cfg);
    % Stage A：128 颗 MC 评估每个名义通过候选，生成单行汇总指标
    [data, el] = run_mc_impl(a, cfg, cfg.stageA_MC);
    s = mc_summary_row(sprintf('Cb%d_t%d_l%d_b%d', p.Cb_Cu, p.topR, p.lowR1, p.botCap), a, data, el);
    rows{end+1} = s; %#ok<AGROW>
end
% 把 Stage A 的各行汇总成 table 并写入 coarse_search.csv
A = struct2table([rows{:}]);
writetable(A, fullfile(cfg.implRoot, 'csv', 'integer_bridge_coarse_search.csv'));
fprintf('[coarse] stage A done: %d rows\n', height(A));
% 打分 = pass 良率 - 1e-6·DNL99（以极小权重用 DNL99 作并列时的 tie-break）

% ---- Stage B: top 25 at 1000 MC ----
score = A.pass_yield - 1e-6*A.DNL_P99;
[~, ord] = sort(score, 'descend');
% 取 Stage A 中 score 最高的前 25 个进入 Stage B（若不足 25 则全取）
nb = min(cfg.stageB_keep, height(A));
sel = ord(1:nb);
rowsB = {};
for k = sel'
    p = struct('Cb_Cu', A.Cb_Cu(k), 'topR', A.topR_Cu(k), 'lowR1', A.lowR1_Cu(k), 'botCap', A.botCap_Cu(k));
    a = bwar_build(p, cfg);
    % Stage B：对选中的候选跑 1000 颗 MC，给出更稳的良率/分位数
    [data, el] = run_mc_impl(a, cfg, cfg.stageB_MC);
    rowsB{end+1} = mc_summary_row(A.label(k), a, data, el); %#ok<AGROW>
end
B = struct2table([rowsB{:}]);
writetable(B, fullfile(cfg.implRoot, 'csv', 'integer_bridge_stageB_1000.csv'));
fprintf('[coarse] stage B done\n');
disp(B(:, {'label','pass_yield','DNL_P99','INL_P99','total_cap_pF'}));
% 再次按同一打分在 Stage B 结果里挑前 8 个进入 Stage C

% ---- Stage C: top 8 at 10k ----
score = B.pass_yield - 1e-6*B.DNL_P99;
[~, ord] = sort(score, 'descend');
nc = min(cfg.stageC_keep, height(B));
rowsC = {};
for k = ord(1:nc)'
    p = struct('Cb_Cu', B.Cb_Cu(k), 'topR', B.topR_Cu(k), 'lowR1', B.lowR1_Cu(k), 'botCap', B.botCap_Cu(k));
    a = bwar_build(p, cfg);
    % Stage C：10k 颗高密度 MC，给出最可信的良率与 DNL/INL 分位数
    [data, el] = run_mc_impl(a, cfg, cfg.stageC_MC);
    rowsC{end+1} = mc_summary_row(B.label(k), a, data, el); %#ok<AGROW>
end
C = struct2table([rowsC{:}]);
writetable(C, fullfile(cfg.implRoot, 'csv', 'integer_bridge_stageC_10k.csv'));
fprintf('[coarse] stage C done\n');
disp(C(:, {'label','pass_yield','DNL_P99','INL_P99','total_cap_pF'}));
% 返回三阶段结果表 A/B/C，供后续 fine_search 与 gate 报告使用
out.A = A; out.B = B; out.C = C;
end

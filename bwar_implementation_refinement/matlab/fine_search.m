% fine_search.m — Phase A 第二阶段：在粗搜索最优区域附近做精细搜索（task §7）
% 角色：以 coarse 赢家为中心，在 topR(±4)、lowR1(±32)、bot(0..4) 的小网格上局部细化，
%       先名义门 + 512 颗 MC 得 F，再对前 8 名做 10k 颗验证，给出可信良率与 DNL99。
function out = fine_search(cfg, center)
% 固定粗搜索赢家的整数桥 Cb（如 2Cu），只微调其余三个参数
% Phase A stage 2: fine search around the best coarse region (task section 7).
% center: struct with topR/lowR1/botCap (+ fixed Cb from coarse winner).
Cb = center.Cb_Cu;
cands = {};
% topR 在中心 ±4 内以步长 1 细扫（高位附加电阻，影响权重分配）
for dt = -4:1:4
    topR = center.topR + dt;
    if topR < 0 || topR > 32, continue; end
    % lowR1 在中心 ±32 内以步长 4 细扫（低位段权重，对失配最敏感，决定 DNL）
    for dl = -32:4:32
        lowR1 = center.lowR1 + dl;
        if lowR1 < 32, continue; end
        for bot = 0:4
            cands{end+1} = struct('Cb_Cu', Cb, 'topR', topR, 'lowR1', lowR1, 'botCap', bot); %#ok<AGROW>
        end
    end
end
fprintf('[fine] %d candidates around Cb=%d, topR=%d, lowR1=%d\n', ...
    numel(cands), Cb, center.topR, center.lowR1);

keep = [];
% 名义门：对每个细搜索候选做 seed=0 的确定性缺码/单调/DNL/INL 检查
for i = 1:numel(cands)
    a = bwar_build(cands{i}, cfg);
    real = realize_variant(a, cfg, 0);
    t = transfer_tree_gen(a, real, cfg);
    m = adc_metrics(t, t.code1, a, cfg);
    if m(3) == 0 && m(4) && m(1) < cfg.dnlLimit && m(2) < cfg.inlLimit
        keep(end+1) = i; %#ok<AGROW>
    end
end
fprintf('[fine] nominal gate: %d/%d pass\n', numel(keep), numel(cands));

rows = {};
for k = keep
    p = cands{k};
    a = bwar_build(p, cfg);
    % 每个名义通过候选跑 512 颗 MC，得到 F 表的初步良率/DNL99
    [data, el] = run_mc_impl(a, cfg, 512);
    rows{end+1} = mc_summary_row(sprintf('Cb%d_t%d_l%d_b%d', p.Cb_Cu, p.topR, p.lowR1, p.botCap), a, data, el); %#ok<AGROW>
end
F = struct2table([rows{:}]);
writetable(F, fullfile(cfg.implRoot, 'csv', 'integer_bridge_fine_search.csv'));
% 打分 = pass 良率 - 1e-6·DNL99 - 1e-9·总电容（兼顾良率、线性度与面积）

% 10k verification of the fine top-8 by yield, tie-break smaller cap then DNL
score = F.pass_yield - 1e-6*F.DNL_P99 - 1e-9*F.total_cap_pF;
[~, ord] = sort(score, 'descend');
% 取 F 中打分前 8 名做 10k 高密度验证
nf = min(8, height(F));
rowsV = {};
for k = ord(1:nf)'
    p = struct('Cb_Cu', F.Cb_Cu(k), 'topR', F.topR_Cu(k), 'lowR1', F.lowR1_Cu(k), 'botCap', F.botCap_Cu(k));
    a = bwar_build(p, cfg);
    % 10k 颗 MC 验证给出最可信的良率/分位数，写入 fine_10k.csv
    [data, el] = run_mc_impl(a, cfg, 10000);
    rowsV{end+1} = mc_summary_row(F.label(k), a, data, el); %#ok<AGROW>
end
V = struct2table([rowsV{:}]);
writetable(V, fullfile(cfg.implRoot, 'csv', 'integer_bridge_fine_10k.csv'));
fprintf('[fine] 10k verification done\n');
disp(V(:, {'label','pass_yield','DNL_P99','INL_P99','total_cap_pF','lowR1_Cu'}));
% 返回精细搜索表 F 与 10k 验证表 V，供 gate 与 Phase B/C 选用
out.F = F; out.V = V;
end

% ============================================================================
% design_search.m —— 冗余参数网格搜索（选型）
% ----------------------------------------------------------------------------
% 角色：在变体家族（'CurrentR' / 'BWAR'）的冗余旋钮上做网格搜索，筛选能达标的
%       候选架构。两阶段：①标称闸门——CAL1 必须零缺码、单调、DNL<1、INL<4；
%       ②裕度排序——对失配芯片取精确判决树在各层的最小裕度（末两层是量化地板，
%       不参与排序、单独报）。最终在达标候选中选“最差裕度最大者”，并以小电容破平。
% 输入  ：family —— 变体家族名；cfg —— 配置。
% 输出  ：out —— 含候选表 table、选中参数 choice/choiceParams、达标集 passed。
% ============================================================================
function out = design_search(family, cfg)
% Grid search over redundancy parameters. Two-stage:
%   1) nominal gate: CAL1 must give 0 missing, monotonic, DNL<1, INL<4
%   2) margin ranking: min over levels k<=K-2 and chips of exact tree margin
%      (last two levels are the quantization floor, excluded from ranking;
%      reported separately).
if strcmp(family, 'CurrentR')
    grid = struct('r12a', {}, 'r8a', {}, 'r4', {}, 'domMatch', {}, 'retune', {});
    for domMatch = [false true], for retune = [false true]
        for r12a = [0 5 8], for r8a = [0 5 8], for r4 = [0 12]
            grid(end+1) = struct('r12a', r12a, 'r8a', r8a, 'r4', r4, ...
                'domMatch', domMatch, 'retune', retune); %#ok<AGROW>
    end, end, end, end, end
elseif strcmp(family, 'BWAR')
    grid = struct('rA', {}, 'topR', {});
    for rA = [0 2 3], for topR = [0 1 2]
        grid(end+1) = struct('rA', rA, 'topR', topR); %#ok<AGROW>
    end, end
else
    error('Unknown family');
end

chips = 1:min(8, cfg.designMC);          % mismatch chips for margin stats
n = numel(grid);
rows = struct([]);
fprintf('[design_search:%s] %d candidates\n', family, n);
for i = 1:n
    p = grid(i);
    a = variant_definition(family, cfg, p);
    nom = realize_variant(a, cfg, 0);
    t = transfer_tree_gen(a, nom, cfg);
    m1 = adc_metrics(t, t.code1, a, cfg);
    gate = (m1(3) == 0) && m1(4) && (m1(1) < cfg.dnlLimit) && (m1(2) < cfg.inlLimit);  % 标称闸门：零缺码(m1(3))、单调(m1(4))、DNL<1、INL<4
    row.family = string(family);
    row.params = jsonencode(p);
    row.decisions = a.decisions;
    row.totalCap_pF = a.totalCap_pF;
    row.nominal_gate = gate;
    row.nominal_missing = m1(3); row.nominal_DNL = m1(1); row.nominal_INL = m1(2);
    row.worstMarginLSB = NaN; row.worstTailLSB = NaN;
    if gate
        worst = Inf; worstTail = Inf;
        for c = chips
            real = realize_variant(a, cfg, c);
            tc = transfer_tree_gen(a, real, cfg);
            marg = tc.margin / a.lsb;
            worst = min(worst, min(marg(1:end-2)));
            worstTail = min(worstTail, min(marg(end-1:end)));
        end
        row.worstMarginLSB = worst;
        row.worstTailLSB = worstTail;
    end
    if isempty(rows), rows = row; else, rows(end+1) = row; end %#ok<AGROW>
    if mod(i, 25) == 0, fprintf('  %d/%d done (%d passed gate)\n', i, n, nnz([rows.nominal_gate])); end
end
T = struct2table(rows);
passed = T(T.nominal_gate, :);
if isempty(passed)
    out.table = T; out.choice = []; 
    fprintf('[design_search:%s] NO candidate passed the nominal gate.\n', family);
    return;
end
[~, im] = max(passed.worstMarginLSB - 1e-6*passed.totalCap_pF);  % 选最差裕度最大者；-1e-6*cap 作破平（电容更小优先）
out.table = T;
out.choiceParams = passed.params{im};
out.choice = jsondecode(out.choiceParams);
out.choiceStruct = passed(im, :);
out.passed = passed;
fprintf('[design_search:%s] chosen %s (worstMargin=%.2f LSB, cap=%.3f pF, decisions=%d)\n', ...
    family, out.choiceParams, passed.worstMarginLSB(im), passed.totalCap_pF(im), passed.decisions(im));
end

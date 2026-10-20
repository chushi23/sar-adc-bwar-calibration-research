% ============================================================================
% margin_profile.m —— 逐判决层的裕度剖面（跨失配芯片）
% ----------------------------------------------------------------------------
% 角色：对一组失配芯片，统计精确判决树在每一判决层 k 的“操作裕度”（判决状态到
%       区间边缘的距离减去即将迈出的步长，单位 LSB16），以及死亡分支数/存活节点数。
% 输出最小/中位/均值/5% 分位裕度，并找出全局最差层 worstLevel，用于稳健性洞察。
% 输入  ：name/params —— 变体；cfg —— 配置；chips —— 芯片编号向量。
% 输出  ：out —— 含 minLSB/medLSB/meanLSB/p05LSB/worstLevel/M 等。
% ============================================================================
function out = margin_profile(name, cfg, params, chips)
% Per-decision-level margin statistics across mismatch chips (exact trees).
% Returns per-level worst/median margin in LSB16 and death counts.
a = variant_definition(name, cfg, params);
K = a.decisions; n = numel(chips);
M = nan(n, K); D = zeros(n, K); A = zeros(n, K);
for i = 1:n
    real = realize_variant(a, cfg, chips(i));
    t = transfer_tree_gen(a, real, cfg);
    M(i,:) = t.margin / a.lsb;
    D(i,:) = t.death;
    A(i,:) = t.alive;
end
out.a = a; out.chips = chips;
out.minLSB  = min(M, [], 1);            % 各层跨芯片最差裕度（越小越危险）
out.medLSB  = median(M, 1);
out.meanLSB = mean(M, 1);
out.p05LSB  = zeros(1, K);
for k = 1:K, out.p05LSB(k) = quantile_linear(M(:,k), .05); end
[mm, kk] = min(out.minLSB);
out.worstLevel = [kk, mm];              % 全局最危险层（层号, 最差裕度）
out.deathSum = sum(D, 2);               % 每颗芯片的死亡分支总数（= 潜在缺码数）
out.M = M;
end

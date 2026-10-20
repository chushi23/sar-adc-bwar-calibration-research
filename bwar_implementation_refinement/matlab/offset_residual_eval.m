% offset_residual_eval.m — Phase C（task §14）：权重校准 + 残余比较器失调评估
% 角色：在已完成前台权重校准(C0)后，考察“残留比较器失调 Vos”对转换性能的影响（C1 模式）。
% 方法：每颗芯片带失配，加测量噪声后平均得 wHat，用 leaf_bits 解码成码，统计 DNL/INL/pass/缺码率随 Vos 变化。
function out = offset_residual_eval(a, cfg)
% K = 判决数（即需要校准/参与的权重个数）
% Task section 14: weight calibration + residual comparator offset (conversion
% time). C0 = uncalibrated offset; C1 = residual after foreground offset cal.
K = a.decisions;
n = cfg.phaseC_chips;
sm = 0.05; Navg = 64;                        % Phase B operating point
rows = struct([]);
% 遍历残余比较器失调网格 VosResidLSB（单位 LSB），每次用独立种子保证可复现
for vo = cfg.VosResidLSB
    st = RandStream('mt19937ar', 'Seed', 70000 + round(vo*1000));
    met = zeros(n, 5);
    for j = 1:n
        real = realize_variant(a, cfg, j);
        % 在传输树中注入比较器失调 offset = vo·lsb，模拟校准后残留失调
        t = transfer_tree_gen(a, real, cfg, struct('offset', vo * a.lsb));
        bits = leaf_bits(t.raw, K);
        % 测量噪声 ~ N(0, sm²)，每权重测 Navg 次（前台校准的平均采样）
        noise = sm * a.lsb * randn(st, K, Navg);
        % wHat = 真实权重 + 噪声平均，即前台校准估计出的权重向量
        wHat = real.decW(:) + mean(noise, 2);
        % value = 判决位向量与权重估计的内积，重建出模拟输入对应的“理想码位置”
        value = bits * wHat(:);
        % 量化到码：clamp 到 [0, M-1] 并四舍五入（饱和保护，避免越界）
        code = min(cfg.M-1, max(0, floor(cfg.M*value + .5)));
        m = adc_metrics(t, code, a, cfg);
        met(j,:) = [m(1) m(2) m(3) m(4) m(5)];
    end
    r.Vos_residual_LSB = vo; r.mode = "C1";
    f = isfinite(met(:,1));
    if any(f), r.DNL_P95 = quantile_linear(met(f,1), .95); else, r.DNL_P95 = Inf; end
    if all(f), r.INL_P95 = quantile_linear(met(f,2), .95); else, r.INL_P95 = Inf; end
    % pass 良率 = 通过 DNL/INL/缺码/单调全部规格的芯片占比
    r.pass_yield = mean(met(:,5));
    % 零缺码率 = 缺码计数==0 的芯片占比
    r.missing_yield = mean(met(:,3) == 0);
    r.MC_runs = n;
    if isempty(rows), rows = r; else, rows(end+1) = r; end %#ok<AGROW>
    fprintf('PHASEC Vos_resid=%.3g: pass=%.1f%% DNL95=%.3f missingYield=%.1f%%\n', ...
        vo, 100*r.pass_yield, r.DNL_P95, 100*r.missing_yield);
end
out = struct2table(rows);
writetable(out, fullfile(cfg.implRoot, 'csv', 'offset_residual.csv'));
end
% leaf_bits：把原始判决向量 t.raw（整数码）展开成 n×K 的布尔位矩阵（每行一颗芯片，每列一位）

function b = leaf_bits(raw, K)
n = numel(raw);
b = false(n, K);
for k = 1:K
    % 用位与提取第 k 位（MSB 优先，对应 2^(K-k)），得到该权重的判决比特
    b(:,k) = bitand(raw, uint32(2^(K-k))) ~= 0;
end
end

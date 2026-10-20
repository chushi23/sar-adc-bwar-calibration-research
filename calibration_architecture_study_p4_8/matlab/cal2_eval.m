% ============================================================================
% cal2_eval.m —— Phase 4：CAL2 有限字长前台校准扫描
% ----------------------------------------------------------------------------
% 角色：评估“现实可实现”的 CAL2 校准——解码权重 = 真实权重 + 误差（绝对 LSB 或
%       相对 ppm），并可选量化为 B 位。每颗芯片的模拟判决树只建一次。
% 扫描组合：①仅 errLSB（bits=Inf）；②仅 bits（errLSB=0）；③errLSB×bits 交叉网格；
%       ④仅 errPPM（相对权重误差）。对 cfg.cal2Chips 颗芯片蒙特卡洛，用分位数
%       （P50/P95/P99）与良率（零缺码/单调/规格通过）汇总。
% 输入  ：name/params —— 变体；cfg —— 配置。
% 输出  ：out —— 每种配置的统计表（DNL/INL 分位数、各类良率）。
% ============================================================================
function out = cal2_eval(name, params, cfg)
% Phase 4: CAL2 finite-precision foreground calibration sweep.
% Decoder weights: What = w_real + error (absolute-LSB or relative-ppm),
% optionally quantized to B bits. Analog tree per chip built ONCE.
% Variants: errLSB with bits=Inf; bits with errLSB=0; and a cross grid.
a = variant_definition(name, cfg, params);
K = a.decisions;

configs = {};
for e = cfg.cal2ErrLSB
    configs{end+1} = struct('errLSB', e, 'errPPM', 0, 'bits', Inf); %#ok<AGROW>
end
for b = cfg.cal2Bits
    configs{end+1} = struct('errLSB', 0, 'errPPM', 0, 'bits', b); %#ok<AGROW>
end
for e = [0.01 0.05 0.1]
    for b = [14 16 18 20]
        configs{end+1} = struct('errLSB', e, 'errPPM', 0, 'bits', b); %#ok<AGROW>
    end
end
for pm = cfg.cal2ErrPPM
    configs{end+1} = struct('errLSB', 0, 'errPPM', pm, 'bits', Inf); %#ok<AGROW>
end

n = cfg.cal2Chips;
rows = struct([]);
for ci = 1:numel(configs)
    cf = configs{ci};
    st = RandStream('mt19937ar', 'Seed', 90210 + ci);   % CAL2 estimation noise stream
    met = zeros(n, 5);                                   % DNL INL missing mono pass
    for j = 1:n
        real = realize_variant(a, cfg, j);
        t = transfer_tree_gen(a, real, cfg);
        bits = leaf_bits(t.raw, K);
        wD = real.decW;
        if cf.errLSB > 0
            wD = wD + cf.errLSB * a.lsb * randn(st, 1, K);  % 绝对权重误差（LSB 单位，高斯）
        elseif cf.errPPM > 0
            wD = wD .* (1 + cf.errPPM * 1e-6 * randn(st, 1, K));  % 相对权重误差（ppm）
        end
        if isfinite(cf.bits)
            dQuant = max(wD) / 2^(cf.bits - 1);             % 量化步长：B 位覆盖最大权重
            wD = round(wD / dQuant) * dQuant;               % 把解码权重四舍五入到 B 位定点
        end
        switch a.convention
        case 'monotonic'
            value = bits * wD(:);
            code = floor(cfg.M * value + .5);
        case 'fullstep'
            value = (2*bits - 1) * wD(:);
            code = floor(cfg.M/2 + value/a.lsb + .5);
        end
        code = min(cfg.M-1, max(0, code));
        m = adc_metrics(t, code, a, cfg);  % 复用 Phase 0–3 引擎：由码密度算 DNL/INL/缺码/单调/规格通过
        met(j,:) = [m(1) m(2) m(3) m(4) m(5)];
    end
    r.architecture = string(name); r.errLSB = cf.errLSB; r.errPPM = cf.errPPM;
    r.bits = cf.bits; r.MC_runs = n;
    f = isfinite(met(:,1));
    if any(f)
        q = quantile_linear(met(f,1), [.5 .95 .99]);
        r.DNL_P50 = q(1); r.DNL_P95 = q(2); r.DNL_P99 = q(3);
    else
        r.DNL_P50 = Inf; r.DNL_P95 = Inf; r.DNL_P99 = Inf;
    end
    if all(f)
        q = quantile_linear(met(f,2), [.5 .95 .99]);
        r.INL_P50 = q(1); r.INL_P95 = q(2); r.INL_P99 = q(3);
    else
        r.INL_P50 = Inf; r.INL_P95 = Inf; r.INL_P99 = Inf;
    end
    r.missing_P50 = quantile_linear(met(:,3), .5);
    r.missing_yield = mean(met(:,3) == 0);
    r.monotonic_yield = mean(met(:,4));
    r.spec_pass_yield = mean(met(:,5));
    if isempty(rows), rows = r; else, rows(end+1) = r; end %#ok<AGROW>
    fprintf('CAL2 %-9s errLSB=%-5g ppm=%-5g bits=%-4g: pass=%.1f%% DNL99=%.3f INL99~%.3f\n', ...
        name, cf.errLSB, cf.errPPM, cf.bits, 100*r.spec_pass_yield, r.DNL_P99, r.INL_P99);
end
out = struct2table(rows);
end

function b = leaf_bits(raw, K)
n = numel(raw);
b = false(n, K);
for k = 1:K
    b(:,k) = bitand(raw, uint32(2^(K-k))) ~= 0;
end
end

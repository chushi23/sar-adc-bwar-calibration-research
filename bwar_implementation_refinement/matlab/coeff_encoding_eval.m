% coeff_encoding_eval.m — Phase B（task §12）：FULL-WEIGHT vs ERROR-ONLY 系数量化编码对比
% 角色：在代表性工作点(σ_meas=0.05, Navg=64)下，比较两种前台校准系数存储方式对良率/位数的影响。
%   FULL-WEIGHT：把估计权重整体量化到 [0,wmax]；ERROR-ONLY：只量化“与名义权重之差 dW”到 ±dWrRange。
% 输出：每种 (编码, 位数 b) 的 DNL99、pass 良率、饱和芯片数、平均量化误差。
function out = coeff_encoding_eval(a, cfg)
% K = 判决/权重个数
% Task section 12: FULL-WEIGHT vs ERROR-ONLY coefficient encoding.
%   FULL-WEIGHT : What_i quantized on [0, wmax], step = wmax/2^(b-1).
%   ERROR-ONLY  : dW_i = What_i - Wnom_i quantized on +/- dWrRange (LSB),
%                 decoder reconstructs Wnom_i + Q(dW_i).
% What here = mean of Navg noisy measurements at sigma_meas (Phase B context).
K = a.decisions;
n = cfg.calChips;
sm = 0.05; Navg = 64;                       % representative Phase B operating point
nomW = realize_variant(a, cfg, 0).decW(:);   % column
rows = struct([]);
% 遍历两种编码：FULL-WEIGHT（全权重量化）与 ERROR-ONLY（只量化误差 dW）
for enc = {'FULL', 'ERR'}
    % 遍历量化位数 b（8..20 bit），找满足良率的最少位数
    for b = cfg.bitsList
        st = RandStream('mt19937ar', 'Seed', 60000 + b + 1000*strcmp(enc{1}, 'ERR'));
        met = zeros(n, 5); sat = 0; qerr = 0;
        for j = 1:n
            real = realize_variant(a, cfg, j);
            t = transfer_tree_gen(a, real, cfg);
            % leaf_bits 把判决向量展开成 K 位列矩阵，用于重建模拟输入
            bits = leaf_bits(t.raw, K);
            wR = real.decW(:);
            % 每权重测 Navg=64 次，测量噪声标准差 sm·lsb
            noise = sm * a.lsb * randn(st, K, Navg);
            wHat = wR + mean(noise, 2);           % K x 1 column
            switch enc{1}
            case 'FULL'
                % FULL-WEIGHT：量化步长 = wmax/2^(b-1)，覆盖全范围 [0,wmax]
                dQ = max(wHat) / 2^(b-1);
                % 量化权重 = round(wHat/dQ)*dQ（整权重值写入系数存储器）
                wQ = round(wHat / dQ) * dQ;
            case 'ERR'
                % ERROR-ONLY：dW = 估计权重 − 名义权重（只需量化这个很小偏差）
                dW = wHat - nomW;
                % R = 允许的最大误差范围（dWrRange·lsb），决定 ERR 量化动态范围
                R = cfg.dWrRange_LSB * a.lsb;
                % ERR 量化步长 = 2R/2^b（对称 ±R 等分 2^b 级）
                dQ = 2*R / 2^b;
                % 统计误差超出 ±R 的“饱和”芯片数（ERR 模式溢出指示）
                sat = sat + any(abs(dW) > R);
                % 重建权重 = 名义权重 + 量化后的误差 dW（解码端用 nomW 基准）
                wQ = nomW + round(dW / dQ) * dQ;
            end
            qerr = qerr + mean(abs(wQ - wHat)) / a.lsb;
            % 用量化权重 wQ 重建模拟输入对应的“理想码位置”
            value = bits * wQ(:);
            code = min(cfg.M-1, max(0, floor(cfg.M*value + .5)));
            m = adc_metrics(t, code, a, cfg);
            met(j,:) = [m(1) m(2) m(3) m(4) m(5)];
        end
        r.encoding = string(enc{1}); r.bits = b;
        f = isfinite(met(:,1));
        if any(f), r.DNL_P99 = quantile_linear(met(f,1), .99); else, r.DNL_P99 = Inf; end
        if all(f), r.INL_P99 = quantile_linear(met(f,2), .99); else, r.INL_P99 = Inf; end
        r.pass_yield = mean(met(:,5));
        r.missing_yield = mean(met(:,3) == 0);
        % 记录饱和芯片数（ERR 模式误差溢出次数，越小越好）
        r.saturation_chips = sat;
        % 平均量化误差（LSB），比较两种编码的精度代价
        r.mean_quant_err_LSB = qerr / n;
        if isempty(rows), rows = r; else, rows(end+1) = r; end %#ok<AGROW>
        fprintf('ENC %-4s b=%2d: pass=%.1f%% DNL99=%.3f sat=%d qerr=%.4f LSB\n', ...
            enc{1}, b, 100*r.pass_yield, r.DNL_P99, sat, r.mean_quant_err_LSB);
    end
end
out = struct2table(rows);
writetable(out, fullfile(cfg.implRoot, 'csv', 'coeff_encoding.csv'));
end
% leaf_bits：子函数，把原始判决向量 t.raw 展开成 n×K 布尔位矩阵（每行一芯片，每列一位）

function b = leaf_bits(raw, K)
n = numel(raw);
b = false(n, K);
for k = 1:K
    % 位与提取第 k 位（MSB 优先，对应 2^(K-k)），得到该权重判决比特
    b(:,k) = bitand(raw, uint32(2^(K-k))) ~= 0;
end
end

% practical_cal2.m — Phase B：前台权重校准的行为级模型（task §9-11）
% 角色：仿真“前台校准”过程——对每权重做 Navg 次带噪测量后平均得 wHat，再解码成码评估 DNL/INL/良率。
% 关键物理：噪声 ~N(0,σ²) 独立同分布，平均使 σ_cal ~ σ_meas/√Navg；系统失调 Vos_cal 对所有权重相同、不随平均消失。
function out = practical_cal2(a, cfg)
% K = 需要前台校准的判决/权重个数
% Phase B: foreground weight calibration behavioral model (task sections 9-11).
% What(i) = mean_k( Wreal(i) + noise(i,k) + Vos_cal ), noise ~ N(0, sig^2) iid,
% Vos_cal identical for every weight (systematic, does NOT average out).
% Also verifies sigma_cal ~ sigma_meas / sqrt(Navg) empirically.
K = a.decisions;
n = cfg.calChips;
rows = struct([]);
sigCal = [];  % empirical estimation sigma per config
% 遍历测量噪声网格 σ_meas（单位 LSB），考察不同噪声下校准行为
for sm = cfg.sigmaMeasLSB
    % 遍历平均次数 Navg，验证 σ_cal 随 √Navg 下降的规律
    for Navg = cfg.NavgList
        st = RandStream('mt19937ar', 'Seed', 40000 + round(sm*1000)*100 + Navg);
        met = zeros(n, 5); calSigAcc = 0; downs = 0;
        for j = 1:n
            real = realize_variant(a, cfg, j);
            t = transfer_tree_gen(a, real, cfg);
            bits = leaf_bits(t.raw, K);
            wR = real.decW(:);
            % 每权重测 Navg 次，测量噪声标准差 = sm·lsb，独立同分布
            noise = sm * a.lsb * randn(st, K, Navg);
            wHat = wR + mean(noise, 2);           % K x 1 column                       % Vos_cal = 0 here
            % 累计实测 σ_cal（权重估计误差的 std，按 LSB 计），用于验证 1/√Navg 规律
            calSigAcc = calSigAcc + std(wHat - wR) / a.lsb;
            value = bits * wHat(:);
            code = min(cfg.M-1, max(0, floor(cfg.M*value + .5)));
            m = adc_metrics(t, code, a, cfg);
            met(j,:) = [m(1) m(2) m(3) m(4) m(5)];
            % 统计该芯片码序列中的“下降跳变”数（出现即非单调，用于评估单调性）
            downs = downs + sum(diff(code) < 0);
        end
        % 把该 (σ_meas, Navg, 无系统失调) 配置的 MC 结果汇总成一行
        rows = push_cal(rows, sm, Navg, 0, met, calSigAcc/n, downs);
    end
end
% 系统失调研究：遍历 Vos_cal（对所有权重相同的偏置，不随平均消失）
% systematic offset study at one representative noise/averaging point
for vo = cfg.VosCalLSB
    if vo == 0, continue; end
    % 系统失调研究用代表性工作点 σ_meas=0.05 LSB、Navg=64
    sm = 0.05; Navg = 64;
    st = RandStream('mt19937ar', 'Seed', 50000 + round(vo*1000));
    met = zeros(n, 5);
    for j = 1:n
        real = realize_variant(a, cfg, j);
        t = transfer_tree_gen(a, real, cfg);
        bits = leaf_bits(t.raw, K);
        wR = real.decW(:);
        % 每权重测 Navg 次，测量噪声标准差 = sm·lsb，独立同分布
        noise = sm * a.lsb * randn(st, K, Navg);
        wHat = wR + mean(noise, 2) + vo * a.lsb;              % identical bias per weight
        value = bits * wHat(:);
        code = min(cfg.M-1, max(0, floor(cfg.M*value + .5)));
        m = adc_metrics(t, code, a, cfg);
        met(j,:) = [m(1) m(2) m(3) m(4) m(5)];
    end
    % 系统失调配置：sigCal 与 downs 记为 NaN（此处只关心 pass/DNL/缺码）
    rows = push_cal(rows, sm, Navg, vo, met, NaN, NaN);
end
out = struct2table(rows);
writetable(out, fullfile(cfg.implRoot, 'csv', 'practical_cal2.csv'));
end
% push_cal：子函数，把一次 (σ_meas,Navg,vo) 的 MC 矩阵压成单行统计（P99 分位数与各 yield）

function rows = push_cal(rows, sm, Navg, vo, met, sigCal, downs)
r.sigma_meas_LSB = sm; r.Navg = Navg; r.Vos_cal_LSB = vo;
r.sigma_cal_LSB = sigCal;
f = isfinite(met(:,1));
% DNL P99 = 仅对有限值（未缺码）芯片算 99 分位，缺码芯片不计入
if any(f), r.DNL_P99 = quantile_linear(met(f,1), .99); else, r.DNL_P99 = Inf; end
if all(f), r.INL_P99 = quantile_linear(met(f,2), .99); else, r.INL_P99 = Inf; end
r.missing_yield = mean(met(:,3) == 0);
r.monotonic_yield = mean(met(:,4));
r.pass_yield = mean(met(:,5));
r.MC_runs = size(met,1);
% 平均每次配置的“码下降跳变”比例（衡量非单调程度）
r.mean_down_transitions = downs / size(met,1);
if isempty(rows), rows = r; else, rows(end+1) = r; end %#ok<AGROW>
fprintf('CAL2 meas sig=%.3g Navg=%3d Vos=%.3g: pass=%.1f%% DNL99=%.3f sigma_cal~%.4f\n', ...
    sm, Navg, vo, 100*r.pass_yield, r.DNL_P99, sigCal);
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

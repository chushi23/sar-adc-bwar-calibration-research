% ============================================================================
% dynamics_eval.m —— Phase 7：终选架构的动态敏感性评估
% ----------------------------------------------------------------------------
% 角色：在最终候选上做第二阶段稳健性分析，扫描三类非理想：
%   ① comparator offset（精确偏移，平移每个判决阈值，配 CAL1 解码）；
%   ② settling（一阶均匀因子 kappa=1-eps 乘到每个模拟权重；校准不捕获动态建立，
%      故 CAL1 解码保留未建立权重；eps = settleLSB*lsb/w(MSB)）；
%   ③ noise（采样多次转换→期望码传递→统计阈值→DNL/INL，端点拟合约定）。
% 输入  ：name/params —— 终选变体；cfg —— 配置（dyn* 扫描网格）。
% 输出  ：out —— 各扰动下的 DNL/INL 分位数与良率表。
% 辅助：noisy_transfer 用 Monte Carlo 重采样求含噪传递函数。
% ============================================================================
function out = dynamics_eval(name, params, cfg)
% Phase 7 second-stage sensitivity on the finalists.
%  offset   : exact (shifts every comparator threshold), CAL1 decoder.
%  settling : first-order uniform factor kappa=1-eps on every analog weight;
%             CAL1 decoder keeps UNSETTLED weights (calibration does not
%             capture dynamic settling). eps = settleLSB*lsb/w(MSB).
%  noise    : sampled conversions -> expected-code transfer -> statistical
%             thresholds -> DNL/INL (endpoint-fit convention).
a = variant_definition(name, cfg, params);
rows = struct([]);

for vo = cfg.dynOffsetLSB
    met = zeros(cfg.dynChips, 5);
    for j = 1:cfg.dynChips
        real = realize_variant(a, cfg, j);
        t = transfer_tree_gen(a, real, cfg, struct('offset', vo * a.lsb));  % 比较器失调：把阈值整体平移 vo(LSB)
        m = adc_metrics(t, t.code1, a, cfg);
        met(j,:) = [m(1) m(2) m(3) m(4) m(5)];
    end
    rows = push(rows, name, 'offset_LSB', vo, met); %#ok<AGROW>
end

w1 = realize_variant(a, cfg, 0).decW(1);
for vs = cfg.dynSettleLSB
    met = zeros(cfg.dynChips, 5);
    epsS = vs * a.lsb / w1;
    for j = 1:cfg.dynChips
        real = realize_variant(a, cfg, j);
        t = transfer_tree_gen(a, real, cfg, struct('wScale', 1 - epsS));  % 建立残差：把每个模拟权重乘 (1-eps)，校准不补偿该动态误差
        m = adc_metrics(t, t.code1, a, cfg);
        met(j,:) = [m(1) m(2) m(3) m(4) m(5)];
    end
    rows = push(rows, name, 'settle_LSB', vs, met); %#ok<AGROW>
end

for vn = cfg.dynNoiseLSB
    met = zeros(cfg.dynNoiseChips, 5);
    for j = 1:cfg.dynNoiseChips
        real = realize_variant(a, cfg, j);
        [dnl, inl, miss, mono] = noisy_transfer(a, real, cfg, vn * a.lsb, j);  % 比较器噪声：每点多次采样求统计传递
        met(j,:) = [dnl, inl, miss, double(mono), ...
            double(mono && miss == 0 && dnl < cfg.dnlLimit && inl < cfg.inlLimit)];
    end
    rows = push(rows, name, 'noise_LSB', vn, met); %#ok<AGROW>
end
out = struct2table(rows);
end

function rows = push(rows, name, kind, val, met)
r.architecture = string(name); r.kind = string(kind); r.value = val;
r.MC_runs = size(met, 1);
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
fprintf('DYN %-9s %s=%-5g: pass=%.1f%% DNL95=%.3f INL95=%.3f missingP50=%.0f\n', ...
    name, kind, val, 100*r.spec_pass_yield, r.DNL_P95, r.INL_P95, r.missing_P50);
if isempty(rows), rows = r; else, rows(end+1) = r; end
end

function [dnl, inl, miss, mono] = noisy_transfer(a, real, cfg, sig, chip)
nGrid = 2 * cfg.M;                          % 2 grid points per code bin
vin = linspace(a.domain(1), a.domain(2), nGrid + 1);
vin = (vin(1:end-1) + vin(2:end)) / 2;
vin = vin(:);                               % keep column orientation throughout
R = cfg.dynRepeats;
K = a.decisions;
codes = zeros(numel(vin), 1);
st = RandStream('mt19937ar', 'Seed', 777000 + 1000*chip + round(sig/a.lsb * 100));
for r = 1:R
    state = zeros(numel(vin), 1);
    for k = 1:K
        w = real.decW(k);
        if strcmp(a.convention, 'monotonic')
            thr = state + w;
            d = vin + sig * randn(st, numel(vin), 1) >= thr;
            state = state + d * w;
        else
            thr = state;
            d = vin + sig * randn(st, numel(vin), 1) >= thr;
            state = state + (2*d - 1) * w;
        end
    end
    if strcmp(a.convention, 'monotonic')
        c = floor(cfg.M * state + .5);
    else
        c = floor(cfg.M/2 + state/a.lsb + .5);
    end
    codes = codes + min(cfg.M-1, max(0, c)) / R;
end
% first grid index reaching each code level (codes is nondecreasing up to noise)
lvl = max(1, min(cfg.M, floor(codes + .5)));
F = accumarray(lvl, (1:numel(vin))', [cfg.M 1], @min, NaN);
Fback = flip(F);
Fback = cummin(Fback);
firstCross = flip(Fback);                    % firstCross(k): first idx with lvl >= k
idx = firstCross(2:cfg.M);
idx(isnan(idx)) = numel(vin);                % unreached levels saturate at top
T = vin(idx);
mono = all(diff(T) >= -1e-12);
miss = sum(diff(T) <= 0);
if mono
    step = (T(end) - T(1)) / (cfg.M - 2);
    if step > 0
        inl = max(abs((T - (T(1) + (0:cfg.M-2)' * step)) / step));
        dnl = max(abs(diff(T) / step - 1));
    else
        dnl = Inf; inl = Inf; miss = cfg.M;
    end
else
    dnl = Inf; inl = Inf;
end
end

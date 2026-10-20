% test_calibration_averaging.m — 校准平均律验证（task §19）
% 角色：验证前台权重校准的估计误差 σ_cal 随平均次数按 σ_meas/√Navg 下降（大噪声下规律更明显）。
% 方法：对每个 Navg 跑多颗芯片求 wHat 与真实权重之差的 std，与理论 1/√Navg 曲线对比，偏差<15% 即通过。
function test_calibration_averaging()
% sigma_cal must fall as sigma_meas/sqrt(Navg) (task section 19).
cfg = config_impl();
% 用参考架构（Cb 走 Leff 公式的 BWAR-final）做验证
a = bwar_build(cfg.ref, cfg);
K = a.decisions;
sm = 0.25;                                  % big noise so the law is visible
% res 预存每个 Navg 下实测的 σ_cal（校准估计误差标准差）
res = zeros(1, numel(cfg.NavgList));
for ii = 1:numel(cfg.NavgList)
    Navg = cfg.NavgList(ii);
    st = RandStream('mt19937ar', 'Seed', 1234 + Navg);
    acc = [];
    for j = 1:20
        % 每颗芯片带随机失配实例化
        real = realize_variant(a, cfg, j);
        % 测量噪声 ~ N(0, sm²)，每权重测 Navg 次（前台校准平均采样）
        noise = sm * a.lsb * randn(st, K, Navg);
        % wHat = 真实权重 + 噪声平均，即校准估计出的权重
        wHat = real.decW(:) + mean(noise, 2);
        acc = [acc; (wHat - real.decW(:))/a.lsb]; %#ok<AGROW>
    end
    % 该 Navg 下估计误差的 std 即实测 σ_cal（按 LSB 计）
    res(ii) = std(acc);
end
% 理论下降曲线：σ_cal = σ_meas / √Navg
theory = sm ./ sqrt(cfg.NavgList);
fprintf('Navg : '); fprintf('%6d ', cfg.NavgList); fprintf('\n');
fprintf('meas : '); fprintf('%.4f ', res); fprintf('\n');
fprintf('1/sN : '); fprintf('%.4f ', theory); fprintf('\n');
% 断言实测与理论相对偏差均 <15%，否则平均降噪律被破坏
ok = all(abs(res - theory) ./ theory < 0.15);
assert(ok, 'averaging law violated beyond 15%%');
fprintf('test_calibration_averaging: PASS\n');
end

% ============================================================================
% test_bwar_dummy.m —— BWAR 冗余探针测试
% ----------------------------------------------------------------------------
% 角色：探索性测试——在 BWAR + topR 基础上，把 LOW 端的 dummy 电容人为放大
%       （不重调桥），分别用归一化解码器与原始(raw)解码器跑 300 颗芯片蒙特卡洛，
%       观察缺码/DNL/INL/良率随 dummy 增大的变化。用于诊断冗余与解码方式的交互。
% 注意：本文件内部自带 margin_profile2 / run_variant_mc2 两个本地辅助函数
%       （与正式版命名相同但为局部副本，便于独立实验）。
% ============================================================================
function test_bwar_dummy()
% Probe: BWAR + topR + enlarged LOW dummy (no bridge retune), both decoders.
cfg = config_p48();
for dLow = [128 300 600]
    pb = struct('rA', 0, 'topR', 1, 'Cb', 256/255);
    ab = variant_definition('BWAR', cfg, pb);
    ab.cap(9) = ab.cap(9) + dLow;                 % 原地放大 LOW 端 dummy 电容（不重调桥，用于对照）
    nom = realize_variant(ab, cfg, 0);
    tn = transfer_tree_gen(ab, nom, cfg);
    mn = adc_metrics(tn, tn.code1, ab, cfg);
    mp = margin_profile2(ab, cfg, 1:16);
    [dd, ~] = run_variant_mc2(ab, cfg, 300);
    fprintf('BWAR(topR=1,dummy+%d) dec=%d cap=%.2fpF: nom(miss=%d DNL=%.3f) | worstMargin16=%.1f | 300chip norm: pass=%.1f%% zero-miss=%.1f%% mono=%.1f%% DNL99=%.3f INL99=%.3f\n', ...
        dLow, ab.decisions, ab.totalCap_pF, mn(3), mn(1), min(mp(1:end-2)), ...
        100*mean(dd(:,13)), 100*mean(dd(:,11)==0), 100*mean(dd(:,12)), ...
        quantile_linear(dd(:,9),.99), quantile_linear(dd(:,10),.99));
    ab2 = ab; ab2.cal1norm = false;
    [d2, ~] = run_variant_mc2(ab2, cfg, 300);
    fprintf('    raw decoder : pass=%.1f%% zero-miss=%.1f%% mono=%.1f%% DNL99=%.3f INL99=%.3f\n', ...
        100*mean(d2(:,13)), 100*mean(d2(:,11)==0), 100*mean(d2(:,12)), ...
        quantile_linear(d2(:,9),.99), quantile_linear(d2(:,10),.99));
end
end

function mp = margin_profile2(a, cfg, chips)
M = nan(numel(chips), a.decisions);
for i = 1:numel(chips)
    real = realize_variant(a, cfg, chips(i));
    t = transfer_tree_gen(a, real, cfg);
    M(i,:) = t.margin / a.lsb;
end
mp = min(M, [], 1);
end

function [data, elapsed] = run_variant_mc2(a, cfg, nrun)
data = zeros(nrun, 16); clock = tic;
for j = 1:nrun
    real = realize_variant(a, cfg, j);
    t = transfer_tree_gen(a, real, cfg);
    data(j,:) = [adc_metrics(t, t.code0, a, cfg), adc_metrics(t, t.code1, a, cfg)];
end
elapsed = toc(clock);
end

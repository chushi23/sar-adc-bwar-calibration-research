% ============================================================================
% test_engine_compat.m —— 引擎兼容性自检（Gate 1）
% ----------------------------------------------------------------------------
% 角色：验证 Phase 4–8 的泛化引擎（variant_definition / realize_variant /
%       transfer_tree_gen）能“逐位复现” Phase 0–3 的原始结果。对 Current/BWA 与
%       若干芯片，比较两侧生成的权重 decW、判决树区间 lo/hi、码 code0/code1、以及
%       adc_metrics 指标是否一致（容差 1e-12 / 1e-10）。还打印 Current 标称下各层
%       的死亡分支诊断。这是“addpath 只读复用”正确性的守门测试。
% ============================================================================
function test_engine_compat()
% Gate 1: generalized engine must reproduce phase03 results exactly.
cfg = config_p48();
ph3 = config_default();
arch = {'Current','BWA'};
for ia = 1:numel(arch)
    name = arch{ia};
    a3 = architecture_definition(name, ph3);
    av = variant_definition(name, cfg);
    for chip = [0 1 2 17]
        n3 = realize_architecture(a3, ph3, 0);   % phase03 CAL0 dc uses chip-0 nominal
        r3 = realize_architecture(a3, ph3, max(chip,1));
        t3 = transfer_tree(a3, r3, n3, ph3);
        nv = realize_variant(av, cfg, chip);
        rv = realize_variant(av, cfg, max(chip,1));
        opt = struct('code0Raw', strcmp(name,'BWA'));
        tv = transfer_tree_gen(av, rv, cfg, opt);
        wref = r3.weights;
        if strcmp(name,'BWA'), wref = fliplr(wref); end   % 顺序对齐：Phase 0–3 按电容序，本工程按判决序，需翻转对比
        fprintf('%s chip %d: regions %d vs %d', name, chip, numel(tv.lo), numel(t3.lo));
        okW = max(abs(rv.decW - wref)) < 1e-12;
        okTree = numel(tv.lo)==numel(t3.lo) && max(abs(tv.lo(:)-t3.lo(:)))<1e-10 ...
                 && max(abs(tv.hi(:)-t3.hi(:)))<1e-10;
        okC0 = isequal(tv.code0(:), t3.code0(:));
        okC1 = isequal(tv.code1(:), t3.code1(:));
        fprintf(' w=%d tree=%d c0=%d c1=%d', okW, okTree, okC0, okC1);
        if ~okC0
            dd = find(tv.code0 ~= t3.code0, 3);
            for q = dd(:)'
                fprintf('\n    leaf %d: mine c0=%d theirs c0=%d lo=%.12f/%.12f hi=%.12f/%.12f', ...
                    q, tv.code0(q), t3.code0(q), tv.lo(q), t3.lo(q), tv.hi(q), t3.hi(q));
            end
            fprintf('\n');
        end
        if chip > 0
            m3_0 = adc_metrics(t3, t3.code0, a3, ph3); m3_1 = adc_metrics(t3, t3.code1, a3, ph3);
            m0 = adc_metrics(tv, tv.code0, av, cfg);   m1 = adc_metrics(tv, tv.code1, av, cfg);
            fprintf(' m0=%d m1=%d', isequal(m0,m3_0), isequal(m1,m3_1));
        end
        fprintf('\n');
    end
end

% Margin diagnostics: alive nodes per decision level, Current nominal.
av = variant_definition('Current', cfg);
nom = realize_variant(av, cfg, 0);
tv = transfer_tree_gen(av, nom, cfg);
fprintf('\nCurrent nominal: levels with branch deaths (level: deaths, alive):\n');
for k = find(tv.death > 0)
    fprintf('  k=%2d deaths=%7d alive=%6d\n', k, tv.death(k), tv.alive(k));
end
fprintf('final leaves=%d\n', numel(tv.lo));
end

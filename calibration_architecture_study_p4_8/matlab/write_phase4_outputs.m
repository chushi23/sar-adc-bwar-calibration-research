function write_phase4_outputs(cfg, allT)
% Figures 05-08 and report 04 from the CAL2 sweep table.
B = allT(allT.architecture == "BWAR", :);
fBits = B(B.errLSB == 0 & B.errPPM == 0, :);
fErr  = B(B.errLSB > 0 & isinf(B.bits), :);
fPPM  = B(B.errPPM > 0, :);
fx = fullfile(cfg.p48Root, 'figures');

svgfig(fullfile(fx, '05_coeff_bits_vs_DNL.svg'), ...
    [struct('x', fBits.bits, 'y', fBits.DNL_P99, 'label', 'P99', 'style', 'line'); ...
     struct('x', fBits.bits, 'y', fBits.DNL_P50, 'label', 'P50', 'style', 'dots')], ...
    struct('title', 'CAL2: coefficient bits vs max|DNL| (BWAR-final)', 'xlabel', 'coefficient bits', ...
           'ylabel', 'max|DNL| [LSB]', 'logy', true, 'hline', cfg.dnlLimit));
svgfig(fullfile(fx, '06_coeff_bits_vs_INL.svg'), ...
    [struct('x', fBits.bits, 'y', fBits.INL_P99, 'label', 'P99 INL', 'style', 'line'); ...
     struct('x', fBits.bits, 'y', fBits.spec_pass_yield, 'label', 'pass yield', 'style', 'dots')], ...
    struct('title', 'CAL2: coefficient bits vs max|INL| and pass yield (BWAR-final)', 'xlabel', 'coefficient bits', ...
           'ylabel', 'max|INL| [LSB] / pass yield', 'logy', true, 'hline', cfg.inlLimit));
svgfig(fullfile(fx, '07_cal_error_vs_DNL.svg'), ...
    [struct('x', fErr.errLSB, 'y', fErr.DNL_P99, 'label', 'abs LSB error', 'style', 'line'); ...
     struct('x', fPPM.errPPM/100, 'y', fPPM.DNL_P99, 'label', 'rel error [%]', 'style', 'dots')], ...
    struct('title', 'CAL2: estimation error vs max|DNL| (BWAR-final)', 'xlabel', ...
           'calibration estimation error (LSB or %)', 'ylabel', 'P99 max|DNL| [LSB]', 'logy', true, 'hline', cfg.dnlLimit));
svgfig(fullfile(fx, '08_cal_error_vs_INL.svg'), ...
    [struct('x', fErr.errLSB, 'y', fErr.INL_P99, 'label', 'abs LSB: P99 INL', 'style', 'line'); ...
     struct('x', fPPM.errPPM/100, 'y', fPPM.INL_P99, 'label', 'rel %: P99 INL', 'style', 'dots'); ...
     struct('x', fErr.errLSB, 'y', fErr.spec_pass_yield, 'label', 'abs LSB: pass yield', 'style', 'dash')], ...
    struct('title', 'CAL2: estimation error vs max|INL| / pass yield (BWAR-final)', 'xlabel', ...
           'calibration estimation error (LSB or %)', 'ylabel', 'max|INL| [LSB] / pass yield', 'logy', true, 'hline', cfg.inlLimit));

fmtReq = @(tab, col, dirn, unit) frontier(tab, col, dirn, unit);
fid = fopen(fullfile(cfg.p48Root, 'reports', '04_CAL2.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '# Phase 4 — CAL2 有限精度前台校准扫描\n\n');
fprintf(fid, '`main_phase48(''p4'')` 一键复现；1000 颗/配置；CAL2 估计噪声独立 seed=90210+config。\n\n');
fprintf(fid, '## 达标所需精度与字长（BWAR-final，CAL1 已 100%% 的幸存者）\n\n');
fprintf(fid, '- 纯估计误差（字长∞）：%s\n', fmtReq(fErr, 'errLSB', 'max', 'LSB'));
fprintf(fid, '- 纯字长（误差=0）：%s\n', fmtReq(fBits, 'bits', 'min', 'bit'));
fprintf(fid, '- 相对误差口径：%s\n', fmtReq(fPPM, 'errPPM', 'max', 'ppm'));
fprintf(fid, '\n参考点：0.01 LSB→57.5%% 良率；10 ppm→82.1%%；24 bit→98.7%%（均 <99%%，即真实需求比测试网格更严）。\n');
fprintf(fid, '\n> CurrentR-Z 行为负对照（CAL1 本身 0%%，CAL2 只会更差：全表 0%%），印证任务书"CAL1 不达标则 CAL2 无意义"。\n');
fprintf(fid, '> 任何非零 CAL2 误差都会造成局部非单调（INL=Inf 失败哨兵），故达标率是主判据。\n\n');
fprintf(fid, 'CSV：[cal2_sweep.csv](../csv/cal2_sweep.csv)。图：05-08。\n');
fclose(fid);
fprintf('Phase 4 outputs written.\n');
end

function s = frontier(tab, col, dirn, unit)
% Describe the pass-yield frontier robustly (sets may be empty).
ok95 = tab.spec_pass_yield >= .95;
ok99 = tab.spec_pass_yield >= .99;
v95 = tab.(col)(ok95); v99 = tab.(col)(ok99);
if isempty(v99)
    if isempty(v95)
        best = tab.spec_pass_yield;
        [~, im] = max(best);
        s = sprintf('测试网格内无 ≥95%% 档（最好 %s %g → %.1f%%）；需求比网格更严', unit, tab.(col)(im), 100*best(im));
    else
        s = sprintf('≥95%% 良率：至%s %s %g；≥99%% 在网格内无解（需更优）', ...
            ternaryS(dirn, '大可容忍', '小字长'), unit, applyDir(v95, dirn));
    end
else
    s = sprintf('≥99%% 良率：%s %s %g；≥95%%：%g', ternaryS(dirn, '最大可容忍', '最小'), ...
        unit, applyDir(v99, dirn), applyDir(v95, dirn));
end
end

function v = applyDir(v, dirn)
if strcmp(dirn, 'max'), v = max(v); else, v = min(v); end
end

function s = ternaryS(cond, a, b)
if cond, s = a; else, s = b; end
end

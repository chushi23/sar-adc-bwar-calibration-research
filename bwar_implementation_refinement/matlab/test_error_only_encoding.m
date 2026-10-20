% test_error_only_encoding.m — ERROR-ONLY 系数量化往返测试
% 角色：验证“只量化权重误差 dW”的编码方案可行：先确认真实 dW 落在 ±R 内（不溢出），
%       再用 14-bit 步长量化并重建，检查量化残差 < 1 个步长。
% 说明：ERROR-ONLY 比 FULL-WEIGHT 省位数（dW 动态范围远小于全权重），是 Phase B 的编码选项之一。
function test_error_only_encoding()
% ERROR-ONLY quantization roundtrip: saturation detection + reconstruction.
cfg = config_impl();
a = bwar_build(cfg.ref, cfg);
% 名义（无失配）权重 nomW 作为解码端重建基准
nomW = realize_variant(a, cfg, 0).decW;
real = realize_variant(a, cfg, 1);
% 权重误差 dW（单位 LSB）= 真实权重与名义权重之差
dW = (real.decW - nomW) / a.lsb;
% R = 误差允许的最大范围（±R LSB），决定量化动态范围
R = cfg.dWrRange_LSB;
assert(max(abs(dW)) < R, 'dWrRange too small for realistic weight error');
b = 14;
% 14-bit 量化步长 dQ = 2R / 2^14（对称范围 ±R 等分 2^14 级）
dQ = 2*R / 2^b;
% 重建权重 = 名义权重 + 量化后的 dW（先换回电压尺度再 round 到步长，最后还原）
wQ = nomW + round(dW * a.lsb / (dQ*a.lsb)) * dQ * a.lsb;
% 量化残差（单位 LSB）= 重建权重与真实权重之差的最大值
errLSB = max(abs(wQ - real.decW)) / a.lsb;
fprintf('max |dW| = %.1f LSB (range +/-%d), 14-bit step = %.4f LSB, resid err = %.4f LSB\n', ...
    max(abs(dW)), R, dQ, errLSB);
% 断言残差不超过一个量化步长（ERROR-ONLY 编码无溢出、精度达标）
assert(errLSB <= dQ + 1e-12, 'quantization residual exceeds one step');
fprintf('test_error_only_encoding: PASS\n');
end

% ============================================================================
% test_ideal_16bit_binary.m —— 单元测试：理想 16-bit 二进制权重 ADC 是否严格线性
% ----------------------------------------------------------------------------
% 角色：tests/ 下的“地基正确性”硬门。用 CBW 架构的标称实现(chip=0, 零失配)，
%       验证传输曲线是完美的线性满量程映射。若此项失败，说明 network_weights/
%       transfer_tree/adc_metrics 整条链路有 bug，后续 MC 良率不可信。
% 主要断言：DNL/INL≈0、零缺码、单调；且阈值点精确落在 i/M 的等距网格上。
% ============================================================================
function test_ideal_16bit_binary(cfg)
% CBW 标称实现(r=chip0 即零失配)：建判决树并走 code0(标称域)约定算指标
a=architecture_definition('CBW',cfg); r=realize_architecture(a,cfg,0);
t=transfer_tree(a,r,r,cfg); [m,c]=adc_metrics(t,t.code0,a,cfg);
% 理想 ADC：DNL<1e-8, INL<1e-8, 缺码数=0, 单调标志=1(全部四位合格)
assert(m(1)<1e-8&&m(2)<1e-8&&m(3)==0&&m(4)==1);
% 阈值必须精确落在 i/M 的等距网格上(理想线性传输的判决点)
assert(max(abs(c.thresholds-(1:cfg.M-1)'/cfg.M))<1e-12);
end

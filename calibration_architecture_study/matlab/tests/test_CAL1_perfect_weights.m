% ============================================================================
% test_CAL1_perfect_weights.m —— 单元测试：完美(oracle)位权 + CAL1 解码器
% ----------------------------------------------------------------------------
% 角色：tests/ 硬门之一。验证在“已知全部真实有效位权”的 CAL1 约定下，
%       CBW/BWA/SBW 标称传输可达零误差；并做反例：即使位权完美，也无法凭空
%       填补由物理搜索间隙(权重被篡改)造成的缺码——校准不能创造不存在的区间。
% ============================================================================
function test_CAL1_perfect_weights(cfg)
for name={'CBW','BWA','SBW'}  % 三种非 Current 架构：标称+code1(真实位权)约定
    a=architecture_definition(name{1},cfg); r=realize_architecture(a,cfg,0);
    t=transfer_tree(a,r,r,cfg); m=adc_metrics(t,t.code1,a,cfg);
    assert(m(1)<1e-7&&m(2)<1e-7&&m(3)==0);
end
a=architecture_definition('CBW',cfg); r=realize_architecture(a,cfg,0);
% 反例：人为把末位权重篡改 8 个 LSB，制造一个物理搜索间隙
bad=r;bad.weights(end)=bad.weights(end)+8/cfg.M;
t=transfer_tree(a,bad,r,cfg); m=adc_metrics(t,t.code1,a,cfg);
% 物理间隙必致缺码>0；即便 oracle 解码器，pass=0(DNL/INL 哨兵不掩盖硬件缺陷)
assert(m(3)>0&&m(5)==0,'Oracle decoder must not erase a physical search gap.');
end

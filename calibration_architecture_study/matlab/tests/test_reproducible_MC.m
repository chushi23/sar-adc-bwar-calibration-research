% ============================================================================
% test_reproducible_MC.m —— 单元测试：蒙特卡洛芯片实现的可复现性与隔离性
% ----------------------------------------------------------------------------
% 角色：tests/ 硬门之一。验证 realize_architecture 的种子方案：同一芯片编号必产生
%       逐位完全相同的电容实现(可复现)，不同芯片编号必不同(各 die 独立失配流)。
%       这是良率统计可复现、报告可被他人重跑的前提。
% ============================================================================
function test_reproducible_MC(cfg)
for name=cfg.architectures
    a=architecture_definition(name{1},cfg);
    % 同一芯片编号 31 生成两次，必须完全一致(种子确定性)
    r1=realize_architecture(a,cfg,31);r2=realize_architecture(a,cfg,31);
    % 芯片 32 使用不同种子，与 31 应不同
    r3=realize_architecture(a,cfg,32);
    % r1==r2 说明可复现；r1.cap≠r3.cap 说明不同 die 独立失配
    assert(isequal(r1,r2));assert(~isequal(r1.cap,r3.cap));
end
end

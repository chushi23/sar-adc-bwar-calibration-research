% ============================================================================
% test_nominal_architectures.m —— 单元测试：四种架构标称(零失配)传输曲线回归
% ----------------------------------------------------------------------------
% 角色：tests/ 硬门之一。对四种基础架构的标称实现(chip=0)做传输树与指标计算，
%       用“冻结的标杆数值”锁定正确性与可复现性，防止后续改动破坏基线。
% 关键断言：Current 标称固定缺 25759 码、可达 39928 区间、77 次回退；其余三架构
%       (CBW/BWA/SBW) 标称必须 DNL/INL≈0、零缺码、单调。
% ============================================================================
function test_nominal_architectures(cfg)
for k=1:4  % 遍历四种基础架构，逐一用标称实现做回归检查
    a=architecture_definition(cfg.architectures{k},cfg); r=realize_architecture(a,cfg,0);
    t=transfer_tree(a,r,r,cfg); [m,~]=adc_metrics(t,t.code0,a,cfg);
    if strcmp(a.name,'Current')
        % Current 标称退化标杆：缺 25759 码(本就不足 65536 区间)
        assert(m(3)==25759,'Current nominal missing-code regression failed.');
        % Current 标称可达 39928 个判决区间、发生 77 次码值回退(非单调)
        assert(m(7)==39928&&m(8)==77,'Current nominal tree regression failed.');
    else
        % 其余三架构标称须严格线性：DNL/INL≈0、零缺码、单调
        assert(m(1)<1e-7&&m(2)<1e-7&&m(3)==0&&m(4)==1);
    end
end
end

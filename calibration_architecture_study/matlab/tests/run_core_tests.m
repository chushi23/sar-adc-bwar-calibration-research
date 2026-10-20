% ============================================================================
% run_core_tests.m —— 核心单元测试调度（硬闸门）
% ----------------------------------------------------------------------------
% 角色：按顺序运行 6 个核心单元测试，全部 PASS 后返回，否则任一测试 assert 失败即
%       中断（保证进入蒙特卡洛前的物理与引擎正确性）。这些测试是 main_run 的“闸门”。
% 测试清单：理想16bit二进制、标称架构、CAL1完美权重、阈值提取、可复现MC、桥矩阵。
% 输入  ：cfg —— 配置。输出：names —— 已通过的测试名元胞（供 main_run 记录）。
% ============================================================================
function names=run_core_tests(cfg)
names={'test_ideal_16bit_binary','test_nominal_architectures','test_CAL1_perfect_weights',...
    'test_threshold_extraction','test_reproducible_MC','test_bridge_matrix'};
for k=1:numel(names)
    feval(names{k},cfg);fprintf('PASS %s\n',names{k});  % 逐个调用测试函数（内部 assert 失败会中断）
end
end

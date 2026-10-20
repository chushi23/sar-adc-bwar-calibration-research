% ============================================================================
% test_CAL0_regression.m —— CAL0 静态回归闸门
% ----------------------------------------------------------------------------
% 角色：把 Phase 1 算出的静态 DAC DNL P99（values）与资料目标值（cfg.targets）逐架构
%       比对相对偏差，若任一超过回归容差（cfg.regressionTolerance=5%）则 assert 中断，
%       阻止后续校准阶段基于错误基线继续。是 main_run 的“Phase 1 回归闸门口”。
% 输入  ：cfg —— 配置（含 targets/regressionTolerance）；values —— 四架构实测 P99 向量。
% ============================================================================
function test_CAL0_regression(cfg,values)
relative=abs(values-cfg.targets)./cfg.targets;  % 逐架构相对偏差
assert(all(relative<cfg.regressionTolerance),'CAL0 regression exceeds 5%%; calibration stage stopped.');  % 超容差即中断
end

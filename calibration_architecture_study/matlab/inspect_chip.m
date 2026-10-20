% ============================================================================
% inspect_chip.m —— 单颗芯片检视工具
% ----------------------------------------------------------------------------
% 角色：按 (架构名, 芯片编号) 精确重建任意一颗已保存/可复现的蒙特卡洛芯片，返回
%       其架构定义、物理实现、判决区间、CAL0/CAL1 解码与指标，便于排查问题。
% 用法：result=inspect_chip('Current',17,0.24);  % 第三个参数 vin 可选，做单点 SAR 转换
% 输入  ：name —— 架构名；chip —— 芯片编号；vin —— （可选）模拟输入电压。
% 输出  ：result —— 含 definition/physical/intervals/CAL0/CAL1/metrics*/chip 的结构体。
% ============================================================================
function result=inspect_chip(name,chip,vin)
% Reconstruct any saved MC die exactly; return intervals/thresholds/decisions.
% Example: result=inspect_chip('Current',17,0.24);
addpath(genpath(fileparts(mfilename('fullpath'))));cfg=config_default();
a=architecture_definition(name,cfg);nom=realize_architecture(a,cfg,0);
real=realize_architecture(a,cfg,chip);t=transfer_tree(a,real,nom,cfg);  % 真实芯片失配实现 + 精确判决树
[m0,c0]=adc_metrics(t,t.code0,a,cfg);[m1,c1]=adc_metrics(t,t.code1,a,cfg);  % 分别算 CAL0（名义）/CAL1（理想权重）指标与码曲线
result=struct('definition',a,'physical',real,'intervals',t,'CAL0',c0,'CAL1',c1,...
    'metricsCAL0',m0,'metricsCAL1',m1,'chip',chip);
if nargin>=3,result.conversion=sar_convert(vin,a,real,nom,cfg);end
fprintf('%s die %d: CAL1 missing=%d, monotonic=%d, regions=%d, pass=%d\n',...
    name,chip,m1(3),m1(4),m1(7),m1(5));
end

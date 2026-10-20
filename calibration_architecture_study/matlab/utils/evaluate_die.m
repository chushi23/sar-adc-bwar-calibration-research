% ============================================================================
% evaluate_die.m —— 单颗芯片(die)评估：串起“架构→实现→判决树→指标”全链路
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的最小评估单元。给定架构名与芯片编号，跑通整条链路并
%       返回两种判决约定下的指标。蒙特卡洛循环会对每颗 die 调用本函数。
% 输入  ：name —— 架构名；cfg —— 配置；chip —— 芯片编号(>0 具体 die)
% 输出  ：row —— 拼接的指标行 [m0, m1]，m0/m1 为 code0/code1 约定的 [DNL,INL,...]
% 关键算法：nom=标称(chip0)，real=带失配实现；transfer_tree 用 real 造树、
%       用 nom 定标称阈值；分别用 code0/code1 喂 adc_metrics。
% ============================================================================
function row=evaluate_die(name,cfg,chip)
a=architecture_definition(name,cfg);nom=realize_architecture(a,cfg,0);  % 标称(理想)架构与实现
real=realize_architecture(a,cfg,chip);t=transfer_tree(a,real,nom,cfg);  % 带失配芯片 + 标称阈值建判决树
m0=adc_metrics(t,t.code0,a,cfg);m1=adc_metrics(t,t.code1,a,cfg);  % 两种约定分别算指标
row=[m0 m1];  % 拼接两种约定指标作为该 die 的结果行
end

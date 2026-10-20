% ============================================================================
% config_default.m —— 全局配置（地基阶段 Phase 0–3 的唯一参数源）
% ----------------------------------------------------------------------------
% 角色：本文件是整个仿真的“配置中枢”，所有脚本/函数都从这里读取全局参数。
%       项目处于地基阶段，这里的常量是“从已有资料恢复/标定”的，而非优化所得。
% 主要输出：cfg 结构体，包含
%   - N/M           ：ADC 位数(16)与码总数(2^16)
%   - Cu_fF/K_fF    ：单位电容(fF)与面积律常数 K（sigma_u = sqrt(K/Cu)）
%   - sigma         ：电容单位失配 σ_u（由面积律推导）
%   - VrefSpan/F.S  ：参考电压跨度 / 满量程电流值
%   - architectures ：四种测试基础架构名（Current/CBW/BWA/SBW）
%   - seedRaw/seedMC：原始标定与蒙特卡洛随机种子（保证可复现）
%   - rawStages/mcStages：原始基准与蒙特卡洛的扫描档位数
%   - dnlLimit/inlLimit：16-bit 规格阈值（DNL<1, INL<4）
%   - targets/regressionTolerance：标称良率目标与回归容差
% 关键算法：sigma = sqrt(K_fF / Cu_fF) 即面积律 σ(w)=σ_u·√cap 的归一化形式。
% ============================================================================
function cfg = config_default()
% Phase 0--3 only. Constants are source-recovered, not optimized.
cfg.studyRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.N = 16; cfg.M = 2^cfg.N;  % 16-bit 分辨率；M 为全码空间 2^16=65536
cfg.Cu_fF = 150; cfg.K_fF = 0.0399818695;
cfg.sigma = sqrt(cfg.K_fF/cfg.Cu_fF);  % 面积律：单位失配 σ_u = sqrt(K/Cu) ≈ 1.63%
cfg.VrefSpan = 1.8; cfg.currentFS = 2.048;
cfg.architectures = {'Current','CBW','BWA','SBW'};  % 四种基础架构：Current=电流式, CBW=桥电容分拆, BWA/BWAR=二进制加权(带/不带冗余)
cfg.seedRaw = 20261013; cfg.seedMC = 26101500;
cfg.rawStages = [1000 10000]; cfg.mcStages = [100 1000];
cfg.useParallel = true; cfg.workers = 4;
cfg.widthTolerance = 1e-14;
cfg.dnlLimit = 1; cfg.inlLimit = 4;  % 16-bit 合格阈值：DNL<1 LSB, INL<4 LSB
cfg.targets = [172.26546185 7.64808938 122.39725995 5.89120006];
cfg.regressionTolerance = .05;
end

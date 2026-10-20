% config_impl.m — BWAR 实现精炼阶段的全局配置（Phase A/B/C）
% 角色：定义 MC 规模、电容失配模型、搜索网格、硬门(gate)与目标(goal)、各阶段芯片数。
% 关键：σ_u=√(K_fF/Cu_fF)=1.6326%（面积律）；Cu=150fF；参考架构 ref 用 Leff 公式复现旧 BWAR-final(Cb=1.949Cu)。
%       仅通过 addpath 只读复用 p4_8/phase03 的已验证引擎（realize_variant、network_weights、adc_metrics 等），绝不写回。
function cfg = config_impl()
% 定位实现精炼根目录（mfilename 所在 matlab 目录上溯两级到 bwar_implementation_refinement）
% BWAR implementation-refinement configuration (Phase A/B/C).
% Reuses the verified engines read-only via addpath; never writes there.
here = fileparts(fileparts(mfilename('fullpath')));
cfg.implRoot = here;
cfg.p48Root = fullfile(fileparts(here), 'calibration_architecture_study_p4_8');
cfg.phase03Root = fullfile(fileparts(here), 'calibration_architecture_study');
% 把 phase03 与 p4_8 的 matlab 引擎加入路径（只读复用已验证的仿真内核）
addpath(genpath(fullfile(cfg.phase03Root, 'matlab')));
addpath(genpath(fullfile(cfg.p48Root, 'matlab')));
addpath(genpath(fullfile(here, 'matlab')));
% 16-bit ADC，M = 2^16 为全量程码数（也用于 LSB 与指标计算）

cfg.N = 16; cfg.M = 2^cfg.N;
% 单位电容 Cu=150fF；K_fF 为面积律失配常数（σ_u²·Cu），决定随机失配幅度
cfg.Cu_fF = 150; cfg.K_fF = 0.0399818695;
cfg.sigma = sqrt(cfg.K_fF / cfg.Cu_fF);       % 1.6326%, identical to baseline
cfg.VrefSpan = 1.8; cfg.currentFS = 2.048;
cfg.widthTolerance = 1e-14;
cfg.dnlLimit = 1; cfg.inlLimit = 4;
% 蒙特卡洛固定随机种子，保证整轮仿真结果可复现
cfg.seedMC = 26101500;
cfg.archIndex = 6;                             % same stream family as BWAR-final
cfg.variantIndex = struct('CurrentR', 5, 'BWAR', 6);   % for p4_8 variant_definition reuse

% Reference BWAR-final (Cb from Leff formula = 1.949020 Cu)
cfg.ref = struct('topR', 10, 'lowR1', 240, 'botCap', 1, 'Cb_Cu', -1);  % Cb<0 -> Leff formula
% Phase A 粗搜索：整数桥电容候选网格 [1 2 3] Cu（目标是把 1.949Cu 收敛到整数 2Cu）

% Phase A search grids (task sections 3-4)
cfg.CbGrid = [1 2 3];
% 高位附加电阻 topR 候选网格（0~20，步长 2），用于微调权重分配/失配
cfg.topRGrid = 0:2:20;
cfg.lowR1Grid = 64:8:256;
cfg.botGrid = 0:4;
% 分阶段 MC 规模：Stage A 用 128 颗快速预筛，Stage B 1000 颗、Stage C 10000 颗
cfg.stageA_MC = 128;
cfg.stageB_keep = 25;   cfg.stageB_MC = 1000;
cfg.stageC_keep = 8;    cfg.stageC_MC = 10000;

% Hard gate (task section 5)
cfg.gate.passYield = 0.999;  cfg.gate.zeroMiss = 0.999;  cfg.gate.mono = 0.999;
cfg.gate.DNL99 = 1.0;       cfg.gate.INL99 = 4.0;
cfg.goal.DNL99 = 0.80;      cfg.goal.DNL99best = 0.70;  cfg.goal.INL99 = 1.0;
cfg.goal.Ctotal = 210;      cfg.goal.CtotalBest = 200;
cfg.goal.lowR1 = 200;       cfg.goal.lowR1Best = 176;   % 160~192 band
% Phase B：前台校准平均次数 Navg 候选网格（验证 σ_cal ~ σ_meas/√Navg 规律）

% Phase B grids (task sections 9-12)
cfg.NavgList = [1 4 16 32 64 128 256 512];
cfg.sigmaMeasLSB = [0.02 0.05 0.1 0.25 0.5];
cfg.VosCalLSB = [0 0.01 0.02 0.05 0.1 0.25];
% 校准阶段(Phase B/C)每配置跑 500 颗芯片做统计
cfg.calChips = 500;
cfg.bitsList = [8 10 12 14 16 18 20];
cfg.dWrRange_LSB = 256;    % ERROR-ONLY correction word covers +/- this many LSB16
% Phase C：残余比较器失调 Vos 网格（单位 LSB），考察校准后残留失调对良率影响

% Phase C (task section 14)
cfg.VosResidLSB = [0 0.01 0.02 0.05 0.1 0.2 0.25];
cfg.phaseC_chips = 300;
% PDK sigma 比例 = PDK 实测 1.67487% / K 模型 1.6326%，用于最坏工艺角灵敏度分析

% PDK sigma case (task section 16): phase03 LIMITATIONS #8 cites the 150 fF
% MOM MC (300 runs) sigma ~1.67487% vs K-model 1.6326%.
cfg.sigmaPDK_scale = 1.67487 / (sqrt(cfg.K_fF/cfg.Cu_fF)*100);
% 创建结果输出目录（csv/raw/figures/reports/logs），不存在则新建

for d = {'csv','raw','figures','reports','logs'}
    p = fullfile(here, d{1});
    if ~isfolder(p), mkdir(p); end
end
end

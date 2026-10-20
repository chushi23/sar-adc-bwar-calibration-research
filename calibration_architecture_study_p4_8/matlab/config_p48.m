% ============================================================================
% config_p48.m —— Phase 4–8 全局配置
% ----------------------------------------------------------------------------
% 角色：冗余变体阶段（Phase 4–8）的唯一参数源。与地基阶段 config_default 不同，
%       本文件通过 addpath 把 Phase 0–3 的 matlab 引擎“只读复用”，本身只补充
%       变体相关参数：变体索引、设计搜索/终选蒙特卡洛规模、CAL2 扫描网格、
%       Phase 7 动态敏感性扫描（比较器失调/噪声/建立残差）。
% 关键约定：变体用 archIndex = 5(CurrentR) / 6(BWAR) 承接 Phase 0–3 的 1..4，
%           随机种子错开，保证与已归档的 Phase 0–3 芯片随机流永不冲突。
% 输出：cfg 结构体（N、Cu、sigma、cal2*/dyn* 扫描网格、mc 规模等）。
% ============================================================================
function cfg = config_p48()
% Phase 4--8 configuration. Reuses Phase 0--3 code read-only via addpath.
p48 = fileparts(fileparts(mfilename('fullpath')));
cfg.p48Root   = p48;
cfg.phase03Root = fullfile(fileparts(p48), 'calibration_architecture_study');  % Phase 0–3 工程根目录（只读复用其引擎）
addpath(genpath(fullfile(cfg.phase03Root, 'matlab')));  % 把地基引擎（network_weights/adc_metrics 等）加入搜索路径（只读）
addpath(genpath(fullfile(p48, 'matlab')));  % 把本阶段（Phase 4–8）脚本也加入路径

cfg.N = 16; cfg.M = 2^cfg.N;
cfg.Cu_fF = 150; cfg.K_fF = 0.0399818695;
cfg.sigma = sqrt(cfg.K_fF / cfg.Cu_fF);
cfg.VrefSpan = 1.8; cfg.currentFS = 2.048;
cfg.widthTolerance = 1e-14;
cfg.dnlLimit = 1; cfg.inlLimit = 4;

% Variant seed bookkeeping: phase03 used arch indices 1..4 with
% seedMC + 100000*idx + chip. Variants continue at idx 5 (CurrentR) and
% 6 (BWAR) so streams never collide with archived phase03 chips.
cfg.seedMC = 26101500;
cfg.variantIndex = struct('CurrentR', 5, 'BWAR', 6);  % 变体索引：5=CurrentR, 6=BWAR（承接 Phase 0–3 的 1..4，避免随机流冲突）

% Design-search Monte Carlo size (margin statistics per candidate).
cfg.designMC = 256;  % 设计搜索：每个候选跑 256 颗芯片的裕度统计
% Staged MC for candidate evaluation.
cfg.mcStages = [100 1000];
% Phase 6 finalist MC size.
cfg.mcFinal = 10000;  % Phase 6 终选蒙特卡洛规模（大量芯片求稳健良率）

% CAL2 sweeps (Phase 4).
cfg.cal2ErrLSB   = [0 0.01 0.02 0.05 0.1 0.2];      % absolute, in LSB16
cfg.cal2ErrPPM   = [10 50 100 200 500 1000];        % relative weight error
cfg.cal2Bits     = [12 14 16 18 20 22 24];          % coefficient word length
cfg.cal2Chips    = 1000;                             % MC chips per config

% Phase 7 sweeps (finalists only).
cfg.dynOffsetLSB = [0 0.25 0.5 1 2];                 % comparator offset, LSB16
cfg.dynNoiseLSB  = [0.1 0.25 0.5 1];                 % comparator noise sigma
cfg.dynNoiseChips = 20;                              % noisy runs are sampled
cfg.dynSettleLSB = [0.01 0.1 0.5 1 2];               % MSB unsettled residual, LSB16
cfg.dynChips     = 60;
cfg.dynGrid      = 2 * cfg.M;                        % Vin grid for noisy runs
cfg.dynRepeats   = 8;                                % noisy conversions per grid point

for d = {'raw','csv','figures','reports','logs'}
    p = fullfile(p48, d{1});
    if ~isfolder(p), mkdir(p); end
end
end

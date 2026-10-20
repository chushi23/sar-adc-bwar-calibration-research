% config_round2.m — 第二轮验证(verification_round2)的独立配置
% 角色：基于 config_impl() 复用主项目设置，但把 implRoot 重定向到本轮目录；仅只读复用源项目 matlab 引擎，绝不写回。
% 说明：定义两个待验证架构 BWAR-Impl-64 / -72（Cb=2Cu, lowR1=256, botCap=1, 仅 topR 不同），以及 MC 规模与校准参数。
function cfg = config_round2()
% root = 本轮 verification_round2 根目录（mfilename 所在 matlab 目录上溯两级）
% Independent configuration for verification round 2.  This function only
% writes below verification_round2; the archived implementation is read-only.
root = fileparts(fileparts(mfilename('fullpath')));
% sourceRoot = 源实现精炼项目根目录，用于只读复用其 matlab 仿真引擎
sourceRoot = fileparts(root);
addpath(fullfile(sourceRoot,'matlab'));
% 继承主项目全部设置（失配律、网格、门限等），仅覆盖 implRoot 等少量字段
cfg = config_impl();
cfg.sourceRoot = sourceRoot;
cfg.implRoot = root;
cfg.roundName = 'verification_round2';
% 校准随机种子（与主线不同，保证本轮独立可复现）
cfg.calSeed = 86241000;
cfg.debugMC = 100;
cfg.regressionMC = 1000;
cfg.finalMC = 10000;
cfg.cal2SigmaLSB = 0.02;
cfg.cal2Navg = 512;
% 两个验证候选：BWAR-Impl-64 与 -72（仅 topR 不同，其余 Cb=2Cu/lowR1=256/botCap=1 相同）
cfg.candidates = [ ...
    struct('name','BWAR-Impl-64','Cb_Cu',2,'topR',64,'lowR1',256,'botCap',1), ...
    struct('name','BWAR-Impl-72','Cb_Cu',2,'topR',72,'lowR1',256,'botCap',1)];
% 创建本轮输出目录（matlab/tests/raw/csv/figures/reports/logs）
for d = {'matlab','tests','raw','csv','figures','reports','logs'}
    p = fullfile(root, d{1});
    if ~isfolder(p), mkdir(p); end
end
end

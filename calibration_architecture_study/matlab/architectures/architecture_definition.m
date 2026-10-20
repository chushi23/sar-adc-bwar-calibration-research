% ============================================================================
% architecture_definition.m —— 定义四种基础 CDAC 架构的拓扑参数
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的“架构蓝图”生成器；给定架构名与全局 cfg，返回该架构的
%       拓扑结构体 a（节点标称电容阵列 a.cap、分段 a.seg、桥电容 a.bridge、
%       主阵列升序索引 a.mainAsc、判决/系数个数、输入域 a.domain 等）。
% 输入  ：name —— 'Current'/'CBW'/'BWA'/'SBW'；cfg —— 全局配置
% 输出  ：a    —— 架构参数结构体，供 network_weights / realize_architecture 使用
% 四种架构物理含义：
%   Current：电流式分段（带 r 冗余位），用两个桥电容做分拆，域为 ±FS/2。
%   CBW    ：标准二进制加权（含 1 个额外 LSB 桥），域 [0,1]。
%   BWA    ：两半段二进制加权 + 桥电容 s/(s-1)，域 [0,1]。
%   SBW    ：两段相同二进制堆叠（Split Binary Weighted），含条件 U+L 系数。
% 关键算法：最后两行算总电容(归一化 pF)与单 LSB 电压步长。
% ============================================================================
function a = architecture_definition(name,cfg)
a.name=name; a.N=cfg.N; a.M=cfg.M; a.bridge=[];  % 先初始化结构体公共字段，桥电容默认为空（CBW/SBW 不使用）
switch name
    case 'Current'
        assert(cfg.N==16,'Current source topology is only defined for N=16.');  % Current 拓扑只对 16-bit 定义
        a.labels={'b15','b14','b13','b12','r12','b11','b10','b9','b8','r8','b7','b6','b5','b4','r4','b3','b2','b1','b0'};
        a.cap=[64 32 16 8 8 4 2 1 8 8 4 2 1 16 8 8 4 2 1 18];  % 各节点标称电容（单位 Cu）：含 3 段 + 2 冗余(r) + 末位 LSB 微调
        a.seg=[ones(1,8) 2*ones(1,5) 3*ones(1,7)];
        a.bridge=[1.65203727295828 1.83875928113993];  % 两个标称桥电容（单位 Cu），把 3 段子 DAC 级联耦合
        a.mainAsc=[19 18 17 16 14 13 12 11 9 8 7 6 4 3 2 1];
        a.decisions=19; a.domain=[-cfg.currentFS/2 cfg.currentFS/2];
        a.coefficients=19; a.coefficientOffset=1;  % 19 个判决系数；偏移 1 表示末位为固定 LSB 而非系数
    case 'CBW'
        a.cap=[2.^(0:cfg.N-1) 1]; a.seg=ones(size(a.cap));  % CBW：标准二进制权重 1..2^(N-1) + 1 个额外桥 LSB，每段独立(分=1)
        a.mainAsc=1:cfg.N; a.decisions=cfg.N; a.domain=[0 1];
        a.coefficients=cfg.N; a.coefficientOffset=0;
    case 'BWA'
        h=cfg.N/2; assert(mod(cfg.N,2)==0); s=2^h;
        a.cap=[2.^(0:h-1) 2.^(0:h-1) 1];  % BWA：上下两半段各 h 位的二进制权重 + 1 个桥电容节点
        a.seg=[2*ones(1,h) ones(1,h) 2]; a.bridge=s/(s-1);  % 桥电容 = s/(s-1)（s=2^h），实现段间权重衔接
        a.mainAsc=1:cfg.N; a.decisions=cfg.N; a.domain=[0 1];
        a.coefficients=cfg.N; a.coefficientOffset=0;
    case 'SBW'
        b=[2.^(0:cfg.N-2) 1]; a.cap=[b b]; a.seg=ones(size(a.cap));  % SBW：两段相同的 (N-1) 位二进制 + 桥，形成 Split 结构
        a.mainAsc=[]; a.decisions=cfg.N; a.domain=[0 1];
        % 15 conditional U+L coefficients + offset; final nominal LSB fixed.
        a.coefficients=cfg.N; a.coefficientOffset=1;
    otherwise
        error('Unknown architecture');
end
a.totalCap_pF=2*(sum(a.cap)+sum(a.bridge))*cfg.Cu_fF/1000;  % 总电容（pF）：两路差分 × (主电容和+桥电容和) × 单位 Cu，再转 pF
a.lsb=diff(a.domain)/cfg.M;  % 单 LSB 对应的输入步长 = 输入域宽度 / 码总数
end

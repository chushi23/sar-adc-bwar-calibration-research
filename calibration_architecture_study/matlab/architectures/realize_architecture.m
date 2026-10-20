% ============================================================================
% realize_architecture.m —— 按面积律叠加随机失配，模拟“真实芯片”的电容实现
% ----------------------------------------------------------------------------
% 角色：把标称架构 a 变成带工艺失配的现实芯片。chip=0 为理想标称（无失配）。
%       对每个 die 用唯一随机种子生成可复现的随机流，叠加 σ·√cap 的失配，
%       再调用 network_weights 求出两臂(差分)的有效权重。
% 输入  ：a —— 标称架构；cfg —— 全局配置；chip —— 芯片编号(0=标称, >0=具体 die)
% 输出  ：r —— 实现结构体，含 r.cap(实际电容)、r.bridge(实际桥电容)、
%        r.armWeights(两臂权重)、r.weights(平均有效权重)等
% 关键算法：面积律失配模型 cap_err = σ_u · √cap · N(0,1)；按架构做权重截取/分段。
% ============================================================================
function r = realize_architecture(a,cfg,chip)
% chip=0 is nominal. Each die has its own reproducible stream.
if chip==0
    cap=repmat(a.cap,2,1); bridge=repmat(a.bridge,2,1);
else
    id=find(strcmp(cfg.architectures,a.name));  % 架构在列表中的序号，用于隔离各架构随机流
    seed=cfg.seedMC+100000*id+chip;  % 组合出每颗 die 唯一且可复现的种子
    st=RandStream('mt19937ar','Seed',seed);  % 创建独立随机流，避免污染全局随机状态
    cap=a.cap+cfg.sigma*sqrt(a.cap).*randn(st,2,numel(a.cap));  % 面积律失配：标称电容 + σ·√cap·高斯噪声（2 臂）
    if isempty(a.bridge),bridge=zeros(2,0);
    else,bridge=a.bridge+cfg.sigma*sqrt(a.bridge).*randn(st,2,numel(a.bridge));end
end
if isempty(a.bridge),bridge=zeros(2,0);end
assert(all(cap(:)>0)&&all(bridge(:)>0),'Nonpositive physical capacitor.');  % 失配后电容必须仍为正（物理可实现）
w=zeros(2,numel(a.cap));
for side=1:2
    w(side,:)=network_weights(a,cap(side,:),bridge(side,:));  % 分别计算差分两臂各自的有效权重
end
r.cap=cap; r.bridge=bridge; r.armWeights=w;
r.weights=mean(w,1);  % 取两臂平均权重作为该 die 的代表权重
if strcmp(a.name,'Current')
    r.weights=cfg.VrefSpan*r.weights(1:19);  % Current 架构：权重缩放到电压域 ±VrefSpan/2，取前 19 个系数
elseif strcmp(a.name,'SBW')
    r.upper=r.weights(1:cfg.N); r.lower=r.weights(cfg.N+1:end);  % SBW 拆成上/下两段权重
    r.initial=sum(r.upper);  % 初始判决用上段权重之和（U 段全加）
else
    r.weights=r.weights(1:cfg.N);
end
end

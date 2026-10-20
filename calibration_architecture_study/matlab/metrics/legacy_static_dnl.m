% ============================================================================
% legacy_static_dnl.m —— 历史 STATIC_DAC 静态 DNL 计算（仅用于回归对照）
% ----------------------------------------------------------------------------
% 角色：保留旧版“静态 DAC 失配→DNL”解析公式，作为新 pipeline 的回归基准。
%       不做 SAR 转换，而是用失配的线性传播直接估 DNL，仅用于验证一致性。
% 输入  ：a —— 架构；cfg —— 配置；nrun —— 蒙特卡洛样本数
% 输出  ：dm —— 每次运行的最大 DNL（向量）
% 关键算法：
%   - sig=σ/√2：差分两臂失配的等效单臂标准差。
%   - Current：用有限差分求权重对电容/桥的雅可比 J，再线性传播失配。
%   - CBW/BWA/SBW：用闭合解析式把每级失配映射为码偏移 e，算 2*e-cumsum(e) 的
%     最大偏差作为 DNL。
% ============================================================================
function dm=legacy_static_dnl(a,cfg,nrun)
% Preserve historical STATIC_DAC definitions only for regression.
st=RandStream('mt19937ar','Seed',cfg.seedRaw);
N=cfg.N; M=cfg.M; sig=cfg.sigma/sqrt(2);  % 差分结构下单臂等效失配标准差 = σ/√2
if strcmp(a.name,'Current')
    [w0,~,~]=network_weights(a,a.cap,a.bridge);
    h=1e-5; J=zeros(numel(a.cap),numel(a.cap)+numel(a.bridge));
    for k=1:size(J,2)
        cp=a.cap; cm=a.cap; bp=a.bridge; bm=a.bridge;
        if k<=numel(cp),cp(k)=cp(k)+h;cm(k)=cm(k)-h;
        else,j=k-numel(cp);bp(j)=bp(j)+h;bm(j)=bm(j)-h;end
        J(:,k)=(network_weights(a,cp,bp)-network_weights(a,cm,bm))'/(2*h);
    end
    d=randn(st,nrun,size(J,2)).*sqrt([a.cap a.bridge])*sig;  % 各电容/桥的失配样本(面积律 √cap)
    W=w0(a.mainAsc)+d*J(a.mainAsc,:)';  % 线性传播失配到主阵列权重
    carry=2*W-cumsum(W,2); step=sum(W,2)/(M-1);  % carry=进位误差; step=平均步长
    dm=max(abs(carry./step-1),[],2); return  % 最大 |carry/step - 1| 即 DNL，提前返回
end
z=randn(st,nrun,2*N);  % 2N 个独立失配源(每级上/下臂各一个)的高斯样本
switch a.name
    case 'CBW'
        n=2.^(0:N-1); raw=z(:,1:N).*sqrt(n);  % 各级失配(面积律 √n)
        te=sum(raw,2)+z(:,N+1); e=raw-te.*n/M;  % 总误差归一化到码偏移 e
        dm=max([max(abs(2*e-cumsum(e,2)),[],2),abs(sum(e,2))],[],2)*sig;  % 最大(进位误差,总误差)*sig = DNL
    case 'BWA'
        h=N/2; base=2.^(0:h-1); s=2^h; cb=s/(s-1);  % 半段位数、基础权重、桥电容
        C=[s-1+cb -cb;-cb s+cb]; G=C\eye(2); g=G(1,:);  % 桥耦合的 2 节点方程，解节点系数 g
        l=z(:,1:h).*sqrt(base); hcap=z(:,h+1:N).*sqrt(base);  % 低/高半段失配
        dummy=z(:,N+1); bridge=z(:,N+2)*sqrt(cb);  % 末级 LSB 与桥失配
        u1=g(1)*(sum(hcap,2)+bridge)-g(2)*bridge;  % 上段耦合态
        u2=-g(1)*bridge+g(2)*(sum(l,2)+dummy+bridge);  % 下段耦合态
        dg=-[u1 u2]*G;
        e=M*[l*g(2)+dg(:,2).*base,hcap*g(1)+dg(:,1).*base];  % 码偏移 e
        dm=max([max(abs(2*e-cumsum(e,2)),[],2),abs(sum(e,2))],[],2)*sig;  % 最大 DNL
    case 'SBW'
        n=[2.^(0:N-2) 1]; u=z(:,1:N).*sqrt(n); l=z(:,N+1:2*N).*sqrt(n);  % 上/下两串失配
        te=sum(u+l,2); u=u-te.*n/M; l=l-te.*n/M;  % 归一化去总误差
        du=u(:,1:end-1)-(cumsum(l(:,1:end-1),2)-l(:,1:end-1));  % 上段差分误差
        dl=l(:,1:end-1)-(cumsum(u(:,1:end-1),2)-u(:,1:end-1));  % 下段差分误差
        dm=max(abs([du dl u(:,end) l(:,end)]),[],2)*sig;  % 含末位 LSB 的最大 DNL
end
end

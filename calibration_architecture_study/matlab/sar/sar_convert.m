% ============================================================================
% sar_convert.m —— 模拟 SAR 逐次逼近，把模拟输入 vin 映射为数字码
% ----------------------------------------------------------------------------
% 角色：与 transfer_tree 互为验证。transfer_tree 用区间传播算“全码映射”，
%       本函数对“单个输入 vin”逐位做比较-切换，得到数字码。
% 输入  ：vin —— 模拟输入值；a/real/nom/cfg
% 输出  ：o —— 含 o.code0/o.code1(两种约定码)、o.decisions(每位的判决 d)、
%        o.estimate(最终累积状态)
% 关键算法：逐位 k 从高位到低位，(1) 取阈值；(2) 比较 vin 与阈值得 d∈{0,1}；
%        (3) 按 d 累加对应权重到 state(实际) / dc(标称)。CBW/BWA 用 fullstep
%        阈值(state+weight)；Current/SBW 用对称 ±weight(monotonic)。
% ============================================================================
function o = sar_convert(vin,a,real,nom,cfg)
% Direct conversion, used to independently check the interval algorithm.
state=0; dc=0; raw=0; decisions=zeros(1,a.decisions);  % state=实际累积态, dc=标称累积态, raw=位串, decisions=各判决位
if strcmp(a.name,'SBW'), state=real.initial; dc=nom.initial; end  % SBW 初始置上段权重和
for k=1:a.decisions  % 从最高位到最低位逐次逼近
    if any(strcmp(a.name,{'CBW','BWA'}))
        j=cfg.N-k+1; d=vin>=state+real.weights(j);  % fullstep：本位权重是否应加（输入超过阈值）
        state=state+d*real.weights(j); dc=dc+d*nom.weights(j);  % 加/不加本位权重到实际/标称态
    elseif strcmp(a.name,'Current')
        d=vin>=state; state=state+(2*d-1)*real.weights(k);
        dc=dc+(2*d-1)*nom.weights(k);
    else  % SBW：下分支减 upper，上分支加 lower
        d=vin>=state;
        if k<cfg.N
            j=cfg.N-k;
            state=state+d*real.lower(j)-(1-d)*real.upper(j);  % 1→加 lower, 0→减 upper（中心比较）
            dc=dc+d*nom.lower(j)-(1-d)*nom.upper(j);
        else
            state=state+(d-.5)/cfg.M; dc=dc+(d-.5)/cfg.M;  % 末位 ±0.5 LSB 定界
        end
    end
    raw=2*raw+d; decisions(k)=d;  % 累积位串：左移加 d
end
if strcmp(a.name,'Current')
    c0=floor(cfg.M/2+dc/a.lsb+.5); c1=floor(cfg.M/2+state/a.lsb+.5);  % Current：对称码(中点为 0)
elseif strcmp(a.name,'SBW')
    c0=raw; c1=floor(cfg.M*state+1e-10);
else
    c0=raw; c1=floor(cfg.M*state+.5);
end
o.code0=min(cfg.M-1,max(0,c0)); o.code1=min(cfg.M-1,max(0,c1));  % 裁到合法码范围
o.decisions=decisions; o.estimate=state;  % 输出位判决序列与最终近似态
end

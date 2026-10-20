% ============================================================================
% test_threshold_extraction.m —— 单元测试：区间树与单点 SAR 转换的交叉一致性
% ----------------------------------------------------------------------------
% 角色：tests/ 硬门之一。用两种独立算法(transfer_tree 的精确区间传播 vs
%       sar_convert 的单点逐位逼近)在抽样中点处必须给出完全相同的输出码，
%       互证二者实现一致；并用手工 2-bit 小例子独立验证缺码/非单调哨兵判定。
% ============================================================================
function test_threshold_extraction(cfg)
for k=1:4
    a=architecture_definition(cfg.architectures{k},cfg);
    % 标称 n 与带失配 r(芯片7)：树以 real=r、nom=n 建，验证两算法一致
    n=realize_architecture(a,cfg,0);r=realize_architecture(a,cfg,7);
    t=transfer_tree(a,r,n,cfg);
    % 在判决区间中均匀抽取 103 个代表中点做交叉验证
    idx=unique(round(linspace(1,numel(t.lo),103)));
    for j=idx
        % 取区间中点做单点 SAR 转换，码必须等于区间树对应码
        v=(t.lo(j)+t.hi(j))/2;o=sar_convert(v,a,r,n,cfg);
        assert(o.code0==t.code0(j)&&o.code1==t.code1(j));
    end
end
% 构造 2-bit 小例子，独立验证缺码与非单调哨兵逻辑
c=cfg;c.N=2;c.M=4;a=architecture_definition('CBW',c);
t.lo=[0 .25 .5 .75];t.hi=[.25 .5 .75 1];
% 码[0,2,2,3]有重复码2 → 缺码1，DNL≥1(台阶异常)
m=adc_metrics(t,[0 2 2 3],a,c);assert(m(3)==1&&m(1)>=1);
% 码[0,2,1,3]出现回退 2→1 → 非单调，DNL=Inf(失败哨兵)
m=adc_metrics(t,[0 2 1 3],a,c);assert(m(4)==0&&isinf(m(1)));
end

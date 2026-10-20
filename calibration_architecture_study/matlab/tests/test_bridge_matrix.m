% ============================================================================
% test_bridge_matrix.m —— 单元测试：桥电容节点方程的独立正确性验证
% ----------------------------------------------------------------------------

% 角色：tests/ 硬门之一。对含桥电容的架构(BWA/Current)，独立地通过“在单个节点
%       注入等于其电容的电荷、解节点方程 C·V=Q、取 TOP 节点电压”来复算每个电容
%       的有效权重，必须与 network_weights 输出一致；并验证节点电容矩阵正定。
% 关键意义：桥电容引入非对角耦合，此项确保权重求解不被桥结构算错。
% ============================================================================
function test_bridge_matrix(cfg)
for name={'BWA','Current'}
    a=architecture_definition(name{1},cfg);r=realize_architecture(a,cfg,17);
    for side=1:2  % 差分两臂各自独立验证桥矩阵
        % 取 network_weights 的有效权重 w 与节点电容矩阵 C 作为对照基准
        [w,~,C]=network_weights(a,r.cap(side,:),r.bridge(side,:));
        for k=1:numel(a.cap)
            % 在节点 k 注入等于其电容的电荷 Q，独立解 C·V=Q
            Q=zeros(size(C,1),1);Q(a.seg(k))=r.cap(side,k);
            V=C\Q;assert(abs(V(1)-w(k))<1e-12);
        end
        % 节点电容矩阵须正定(所有特征值>0)，保证物理可实现、方程良态
        assert(all(eig(C)>0));
    end
end
end

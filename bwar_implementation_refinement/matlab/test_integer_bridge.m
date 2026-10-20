% test_integer_bridge.m — 显式整数桥构建器的健全性测试（Cb=2Cu）
% 角色：验证 bwar_build 在 Cb=2Cu 下确定性、桥电容值、节点映射、判决顺序契约仍正确（权重非增序）。
% 说明：仅检查结构与名义（无失配）指标，确保整数桥改动未破坏 CDAC 的判决逻辑。
function test_integer_bridge()
% Sanity of the explicit-bridge builder: Cb=2 changes weights but the
% contract (node map, decision order, determinism) must stay sound.
cfg = config_impl();
% 构建 Cb=2Cu 的测试架构 a1（整数桥候选）
a1 = bwar_build(struct('Cb_Cu',2,'topR',10,'lowR1',240,'botCap',1), cfg);
a2 = bwar_build(struct('Cb_Cu',2,'topR',10,'lowR1',240,'botCap',1), cfg);
% 断言两次构建完全一致且桥电容精确等于 2Cu（确定性 + 显式桥值正确）
assert(isequal(a1.cap, a2.cap) && abs(a1.bridge(1)-2) < 1e-12, 'determinism/bridge');
% 断言 dummy 电容仍位于 LOW 节点（seg==2 标识 LOW 段），节点映射未被破坏
assert(a1.seg(a1.dummyIdx) == 2, 'dummy must sit at LOW node');
g = network_weights(a1, a1.cap, a1.bridge);
% 判决权重 w = 网络权重 × M，换算到 LSB 尺度便于比较
w = g(a1.decIdx) * cfg.M;
% 断言判决顺序按权重非增排列（SAR 逐次逼近的单调性前提）
assert(all(diff(w) <= 1e-9), 'decision order must be non-increasing weight');
nom = realize_variant(a1, cfg, 0);
t = transfer_tree_gen(a1, nom, cfg);
% 名义（无失配）指标：缺码数/单调性/DNL/判决区域数
m = adc_metrics(t, t.code1, a1, cfg);
fprintf('Cb=2Cu (10,240,1): dec=%d nominal missing=%d mono=%d DNL=%.3f regions=%d\n', ...
    a1.decisions, m(3), m(4), m(1), m(7));
fprintf('test_integer_bridge: PASS\n');
end

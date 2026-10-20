% ============================================================================
% summarize_mc.m —— 蒙特卡洛结果汇总：良率/分位数/统计表
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的“报表生成器”。把 run_mc 的 (n×16) 数据矩阵聚合成
%       单架构单校准模式的一行统计(row 结构体)，供写表/画良率用。
% 输入  ：name —— 架构名；mode —— 'CAL0'(code0 约定) 或 其他(如 CAL1/CAL2, code1);
%        data —— run_mc 输出；cfg；runtime —— 耗时
% 输出  ：row —— 含良率、DNL/INL 的 P50/P95/P99、缺码/单调/合格良率等字段
% 关键算法：CAL0 取前 8 列(code0)，其余取后 8 列(code1)；用 quantile_linear
%       算峰值 DNL/INL 的分位数；mean(...) 算各布尔指标良率(%)。
% ============================================================================
function row=summarize_mc(name,mode,data,cfg,runtime)
a=architecture_definition(name,cfg); current=architecture_definition('Current',cfg);  % 取本架构与 Current 基准(用于相对电容)
if strcmp(mode,'CAL0'),m=data(:,1:8); coeff=0;bits=0;  % CAL0=code0 约定，无校准系数
else,m=data(:,9:16);coeff=a.coefficients;bits=Inf;end  % 其他模式用 code1 约定，记录系数个数
qd=quantile_linear(m(:,1),[.5 .95 .99]);qi=quantile_linear(m(:,2),[.5 .95 .99]);  % DNL/INL 峰值分位数
row.architecture=string(name);row.variant="Original";row.calibration_mode=string(mode);  % 标识架构/变体/校准模式
row.decision_count=a.decisions;row.total_cap_pF=a.totalCap_pF;  % 判决位数与总电容
row.relative_cap=a.totalCap_pF/current.totalCap_pF;  % 相对 Current 架构的面积比(面积效率)
row.num_cal_coeff=coeff;row.coeff_bits=bits;row.cal_error=0;row.MC_runs=size(m,1);  % 校准系数数与 MC 规模
row.DNL_max_P50=qd(1);row.DNL_max_P95=qd(2);row.DNL_max_P99=qd(3);  % DNL 峰值分位数
row.INL_max_P50=qi(1);row.INL_max_P95=qi(2);row.INL_max_P99=qi(3);  % INL 峰值分位数
row.missing_code_yield=100*mean(m(:,3)==0);  % 零缺码良率(%)：缺码数==0 的比例
row.monotonic_yield=100*mean(m(:,4));row.spec_pass_yield=100*mean(m(:,5));  % 单调良率、规格合格良率(%)
row.runtime_s=runtime;
row.DNL_mean=mean(m(:,1));row.DNL_std=std(m(:,1));row.DNL_worst=max(m(:,1));  % DNL 统计
row.INL_mean=mean(m(:,2));row.INL_std=std(m(:,2));row.INL_worst=max(m(:,2));  % INL 统计
row.missing_mean=mean(m(:,3));q=quantile_linear(m(:,3),[.5 .95 .99]);  % 缺码数均值与分位数
row.missing_P50=q(1);row.missing_P95=q(2);row.missing_P99=q(3);row.missing_worst=max(m(:,3));
row.regions_P50=quantile_linear(m(:,7),.5);row.regions_below_65536_yield=100*mean(m(:,7)<cfg.M);  % 有效判决区间数及其<全码良率
row.valid_threshold_runs=sum(m(:,4));row.seed_base=cfg.seedMC+100000*find(strcmp(cfg.architectures,name));  % 单调 run 数、本架构随机种子基
row.finite_DNL_P99=NaN;row.finite_INL_P99=NaN;  % 仅对单调子集算的 P99（先置 NaN）
if any(m(:,4))
    row.finite_DNL_P99=quantile_linear(m(m(:,4)==1,1),.99);  % 单调子集的 DNL P99
    row.finite_INL_P99=quantile_linear(m(m(:,4)==1,2),.99);  % 单调子集的 INL P99
end
row.occupancy_DNL_diagnostic_P99=quantile_linear(m(:,6),.99);  % 诊断 DNL 的 P99
end

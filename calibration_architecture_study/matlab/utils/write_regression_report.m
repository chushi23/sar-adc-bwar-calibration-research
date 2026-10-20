% ============================================================================
% write_regression_report.m —— 写出 CAL0 历史静态 DAC 回归对照报告(Markdown)
% ----------------------------------------------------------------------------
% 角色：仿真 pipeline 的“回归文档”生成器。把回归表 T 写成 Markdown 报告，
%       用于把本 pipeline 的码密度 DNL 与历史 STATIC_DAC 解析式对照，确认一致。
% 输入  ：cfg —— 配置(含输出目录 outputRoot、K、seedRaw)；T —— 回归结果表
% 输出  ：无(写入 reports/01_CAL0_regression.md)
% 关键算法：用 onCleanup 保证文件句柄关闭；逐行 fprintf 写出架构/P50/P95/P99/
%       历史目标/相对误差的对照表；10k-run 为回归门限(偏差<5%)，1k 仅为调试采样。
% ============================================================================
function write_regression_report(cfg,T)
fid=fopen(fullfile(cfg.outputRoot,'reports','01_CAL0_regression.md'),'w','n','UTF-8');  % 以 UTF-8 打开报告文件
c=onCleanup(@()fclose(fid));  % 函数退出(含异常)时自动关闭文件句柄
fprintf(fid,'# Phase 1 — CAL0 historical static-DAC regression\n\n');
fprintf(fid,'MATLAB %s; Cu=150 fF; K=%.12g fF; seed=%d.\n\n',version,cfg.K_fF,cfg.seedRaw);
fprintf(fid,'The four historical metrics have different endpoint/terminal-bin conventions. Each is preserved for regression. ADC output metrics are computed separately from actual decision intervals.\n\n');
fprintf(fid,'|Architecture|Runs|P50|P95|P99|Historical target|Relative error|\n|---|---:|---:|---:|---:|---:|---:|\n');
for j=1:height(T)
    fprintf(fid,'|%s|%d|%.6f|%.6f|%.6f|%.6f|%.2f%%|\n',T.architecture(j),T.MC_runs(j),T.P50(j),T.P95(j),T.P99(j),T.target_q99(j),100*T.relative_error(j));  % 逐架构写对照行
end
fprintf(fid,'\nThe 10,000-run regression gate requires every relative deviation <5%%. 1,000-run is a debug sampling stage, not a silicon guarantee. No numerical estimate is inferred from the historical target.\n');
end

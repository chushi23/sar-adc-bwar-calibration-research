% ============================================================================
% make_figures_svg.m —— 纯 MATLAB 的 SVG 图表输出（无图形后端依赖）
% ----------------------------------------------------------------------------
% 角色：Phase 0–3 出图工具，把汇总结果 S、静态回归 reg、蒙特卡洛 allData 画成一系列
%       .svg 矢量图（DNL/INL P99 柱状、各类良率、总电容对数、可达区间经验 CDF、
%       静态回归、代表性的 median/P99/worst 芯片码曲线）。
% 输入  ：cfg —— 配置（决定输出目录）；S —— summarize_mc 汇总表；reg —— 静态回归表；
%        allData —— 四架构逐芯片数据元胞。
% 辅助：bars/linesvg/header/axes_svg/legend_svg/esc 为本地绘图子函数。
% 优点：不依赖任何图形服务器/浏览器/GPU/Python，可离线批量生成报告插图。
% ============================================================================
function make_figures_svg(cfg,S,reg,allData)
% Pure MATLAB SVG output; no graphics server, browser, GPU or Python required.
names=cfg.architectures;
for key={'DNL','INL'}
    metric=key{1};v=reshape(S.([metric '_max_P99']),2,4)';
    bars(cfg,['01_' metric '_P99'],['ADC ' metric ' P99 / LSB'],...
        '1,000 dies. Invalid = no conventional monotonic threshold statistic.',names,v,{'CAL0','CAL1'});
end
fields={'missing_code_yield','spec_pass_yield','monotonic_yield'};
titles={'Zero-missing-code yield / %','Joint specification pass yield / %','Monotonic-output yield / %'};
for j=1:3
    bars(cfg,sprintf('0%d_%s',j+2,fields{j}),titles{j},'All 1,000 dies are included; CAL2 not run.',...
        names,reshape(S.(fields{j}),2,4)',{'CAL0','CAL1'},100);
end
caps=S.total_cap_pF(1:2:end);
bars(cfg,'06_capacitance_and_decisions','Physical capacitance / log10(pF)',...
    'Current: 65.55 pF / 19 decisions; BWA: 153.60 pF / 16; CBW/SBW: 19660.8 pF / 16.',...
    names,log10(caps),{'Core capacitance, differential'});
x=cell(1,4);y=x;
for k=1:4,x{k}=sort(allData{k}(:,15));y{k}=(1:numel(x{k}))'/numel(x{k});end
linesvg(cfg,'07_reachable_regions','Reachable decision intervals / empirical CDF',...
    '65536 distinct output codes require at least 65536 reachable intervals.',x,y,names,'Reachable input intervals','Fraction of dies');
R=reg(reg.MC_runs==max(reg.MC_runs),:);
bars(cfg,'08_static_regression','Historical STATIC DAC DNL P99 / LSB',...
    'Regression only. These are NOT complete ADC output DNL results.',names,[R.P99 R.target_q99],{'MATLAB 10k','Historical 100k'});
rep=struct([]);
for k=1:4
    a=architecture_definition(names{k},cfg);nom=realize_architecture(a,cfg,0);data=allData{k};  % 对四架构分别挑代表芯片画码曲线
    if all(isfinite(data(:,9)))
        [~,order]=sortrows([data(:,9) (1:size(data,1))'],[1 2]);rule='CAL1 max DNL';
    else
        [~,order]=sortrows([data(:,11) (1:size(data,1))'],[1 2]);rule='CAL1 missing count (DNL invalid)';
    end
    ii=[ceil(.5*numel(order)) ceil(.99*numel(order)) numel(order)];tags={'median','P99','worst'};
    for j=1:3
        chip=order(ii(j));real=realize_architecture(a,cfg,chip);t=transfer_tree(a,real,nom,cfg);
        [m,curve]=adc_metrics(t,t.code1,a,cfg);stem=sprintf('%s_CAL1_%s_chip%d',a.name,tags{j},chip);
        save(fullfile(cfg.outputRoot,'raw',[stem '.mat']),'a','real','nom','t','m','curve','chip','rule');
        row.architecture=string(a.name);row.selection=string(tags{j});row.rule=string(rule);row.chip=chip;
        row.seed=cfg.seedMC+100000*k+chip;row.valid_thresholds=curve.valid;row.missing=m(3);
        if isempty(rep),rep=row;else,rep(end+1)=row;end %#ok<AGROW>
        if curve.valid
            xx={(1:cfg.M-1)',(1:cfg.M-2)'};yy={curve.INL,curve.DNL};
            labels={'INL','DNL'};desc='Full-code curves; endpoint fitted LSB. No input raster.';
            xlabel='Code';ylabel='LSB';
        else
            xx={(0:cfg.M-1)'};yy={curve.widths/a.lsb};labels={'Total code occupancy / nominal LSB'};
            desc='NONMONOTONIC: conventional INL/DNL undefined. Occupancy is diagnostic only.';
            xlabel='Code';ylabel='Occupancy / nominal LSB';
        end
        linesvg(cfg,['representative_' stem],sprintf('%s CAL1 %s die %d / missing %d',a.name,tags{j},chip,m(3)),...
            desc,xx,yy,labels,xlabel,ylabel);
    end
end
writetable(struct2table(rep),fullfile(cfg.outputRoot,'csv','representative_chips.csv'));
end

function bars(cfg,stem,title,desc,labels,values,series,upper)
if nargin<9
    v=values(isfinite(values));if isempty(v),upper=1;else,upper=max(1,max(v)*1.3);end
end
fid=header(cfg,stem,title,desc);clean=onCleanup(@()fclose(fid));
colors={'#286ba6','#078579'};left=90;top=110;bottom=455;width=830;height=345;
axes_svg(fid,left,top,width,height,0,upper,'');
n=numel(labels);ns=size(values,2);group=width/n;bw=min(65,group/(ns+1));
for i=1:n
    center=left+(i-.5)*group;
    fprintf(fid,'<text x="%.1f" y="482" text-anchor="middle">%s</text>',center,esc(labels{i}));
    for j=1:ns
        xx=center+(j-(ns+1)/2)*bw;
        if isfinite(values(i,j))
            h=height*values(i,j)/upper;
            fprintf(fid,'<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="3" fill="%s"/>',xx-bw*.43,bottom-h,bw*.86,h,colors{j});
            fprintf(fid,'<text x="%.1f" y="%.1f" text-anchor="middle" font-size="13">%.2f</text>',xx,bottom-h-9,values(i,j));
        else
            fprintf(fid,'<text x="%.1f" y="%.1f" text-anchor="middle" fill="#a23c32" font-size="13">INVALID</text>',xx,bottom-26-(j-1)*25);
        end
    end
end
legend_svg(fid,series,colors);fprintf(fid,'</svg>');
end

function linesvg(cfg,stem,title,desc,x,y,labels,xlabel,ylabel)
fid=header(cfg,stem,title,desc);clean=onCleanup(@()fclose(fid));
colors={'#286ba6','#078579','#d28b21','#ad4b64'};
xlo=Inf;xhi=-Inf;ylo=Inf;yhi=-Inf;
for j=1:numel(x)
    xlo=min(xlo,min(x{j}));xhi=max(xhi,max(x{j}));ylo=min(ylo,min(y{j}));yhi=max(yhi,max(y{j}));
end
if xhi<=xlo,xhi=xlo+1;end
if yhi<=ylo,yhi=ylo+1;end
pad=(yhi-ylo)*.06;ylo=ylo-pad;yhi=yhi+pad;
left=90;top=110;width=830;height=345;
axes_svg(fid,left,top,width,height,ylo,yhi,ylabel);
for i=0:4
    value=xlo+(xhi-xlo)*i/4;
    fprintf(fid,'<text x="%.1f" y="480" text-anchor="middle" font-size="13">%.0f</text>',left+width*i/4,value);
end
for j=1:numel(x)
    xx=left+width*(x{j}(:)-xlo)/(xhi-xlo);yy=top+height*(yhi-y{j}(:))/(yhi-ylo);
    fprintf(fid,'<polyline fill="none" stroke="%s" stroke-width="1.1" points="',colors{j});
    fprintf(fid,'%.2f,%.2f ',[xx yy]');fprintf(fid,'"/>');
end
fprintf(fid,'<text x="505" y="510" text-anchor="middle" font-size="14">%s</text>',esc(xlabel));
legend_svg(fid,labels,colors);fprintf(fid,'</svg>');
end

function fid=header(cfg,stem,title,desc)
fid=fopen(fullfile(cfg.outputRoot,'figures',[stem '.svg']),'w','n','UTF-8');
assert(fid>=0);fprintf(fid,'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 580" role="img"><title>%s</title><rect width="1000" height="580" fill="white"/><style>text{font-family:Arial,Helvetica,sans-serif;fill:#173044;font-size:16px}</style>',esc(title));
fprintf(fid,'<text x="35" y="40" style="font-size:24px;font-weight:700">%s</text><text x="35" y="72" style="font-size:13px;fill:#527083">%s</text>',esc(title),esc(desc));
end
function axes_svg(fid,left,top,width,height,ylo,yhi,label)
for i=0:4
    yy=top+height-height*i/4;value=ylo+(yhi-ylo)*i/4;
    fprintf(fid,'<path d="M %.1f %.1f H %.1f" stroke="#dce6ec"/><text x="%.1f" y="%.1f" text-anchor="end" font-size="12">%.2f</text>',left,yy,left+width,left-10,yy+5,value);
end
fprintf(fid,'<text transform="translate(20 310) rotate(-90)" text-anchor="middle" font-size="13">%s</text>',esc(label));
end
function legend_svg(fid,labels,colors)
for j=1:numel(labels)
    xx=70+(j-1)*220;
    fprintf(fid,'<rect x="%.1f" y="544" width="15" height="12" fill="%s"/><text x="%.1f" y="555" style="font-size:12px">%s</text>',xx,colors{j},xx+22,esc(labels{j}));
end
end
function s=esc(s)
s=strrep(char(s),'&','&amp;');s=strrep(s,'<','&lt;');s=strrep(s,'>','&gt;');
end

% ============================================================================
% svgfig.m —— 零依赖的 SVG 折线/散点图写入器
% ----------------------------------------------------------------------------
% 角色：Phase 4–8 的轻量出图工具，不依赖 MATLAB 图形后端，直接生成 .svg 文件。
% 输入  ：fname —— 输出路径；series —— 结构体数组（x,y,label,style:line/dots/dash）；
%        opt —— 可选：title/xlabel/ylabel/logy/hline/w/h/legend。
% 原理：把数据归一化到画布坐标，用 <polyline>/<circle>/<line> 等 SVG 基本元素绘制
%       坐标轴、网格、曲线与图例，最后整段写入 UTF-8 文件。
% 用途：把 CAL2 扫描、裕度剖面等结果画成可嵌入报告的矢量图。
% ============================================================================
function svgfig(fname, series, opt)
% Minimal dependency-free SVG line/dot chart writer.
%   series: struct array with fields x, y, label, style ('line','dots','dash')
%   opt:    title, xlabel, ylabel, logy, hline, w, h, legend
if ~isfield(opt,'w'),     opt.w = 900;     end
if ~isfield(opt,'h'),     opt.h = 560;     end
if ~isfield(opt,'logy'),  opt.logy = false; end
if ~isfield(opt,'legend'),opt.legend = true; end
if ~isfield(opt,'title'), opt.title = '';  end
if ~isfield(opt,'xlabel'),opt.xlabel = ''; end
if ~isfield(opt,'ylabel'),opt.ylabel = ''; end

tx = 74; ty = 44; rx = 18; by = 58;
W = opt.w; H = opt.h; pw = W - tx - rx; ph = H - ty - by;
ax = []; ay = [];
for si = 1:numel(series)
    ax = [ax; series(si).x(:)]; %#ok<AGROW>
    ay = [ay; series(si).y(:)]; %#ok<AGROW>
end
keep = isfinite(ax) & isfinite(ay);
ax = ax(keep); ay = ay(keep);
if opt.logy
    keep2 = ay > 0;
    ax = ax(keep2); ay = ay(keep2);
    if isempty(ay), ay = 1; ax = 1; end
    lo = log10(min(ay)); hi = log10(max(ay));
    if hi <= lo, hi = lo + 1; end
    Y = @(v) ty + ph - ph .* (log10(max(v, 10.^(lo))) - lo) ./ (hi - lo);
    tickval = @(f) 10.^(lo + (hi - lo) .* f);
else
    lo = min(ay); hi = max(ay);
    if hi <= lo, hi = lo + 1; end
    Y = @(v) ty + ph - ph .* (v - lo) ./ (hi - lo);
    tickval = @(f) lo + (hi - lo) .* f;
end
xlo = min(ax); xhi = max(ax);
if xhi <= xlo, xhi = xlo + 1; end
X = @(v) tx + pw .* (v - xlo) ./ (xhi - xlo);

col = {'#1f77b4','#d62728','#2ca02c','#9467bd','#ff7f0e','#8c564b','#17becf'};
S = {};
S{end+1} = sprintf('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="Segoe UI,Arial,sans-serif" font-size="13">', W, H);
S{end+1} = sprintf('<rect width="%d" height="%d" fill="white"/>', W, H);
if ~isempty(opt.title)
    S{end+1} = sprintf(['<text x="' num2str(tx) '" y="26" font-size="16" font-weight="600" fill="#222">' opt.title '</text>']);
end
S{end+1} = sprintf('<rect x="%d" y="%d" width="%d" height="%d" fill="none" stroke="#777"/>', tx, ty, pw, ph);
for i = 0:5
    vv = tickval(i/5);
    yy = Y(vv);
    S{end+1} = sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e8e8e8"/>', tx, yy, tx+pw, yy);
    S{end+1} = sprintf('<text x="%d" y="%.1f" text-anchor="end" dominant-baseline="middle" fill="#444">%.3g</text>', tx-6, yy, vv);
end
for i = 0:6
    vv = xlo + (xhi - xlo) .* i ./ 6;
    xx = X(vv);
    S{end+1} = sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e8e8e8"/>', xx, ty, xx, ty+ph);
    S{end+1} = sprintf('<text x="%.1f" y="%d" text-anchor="middle" fill="#444">%.3g</text>', xx, ty+ph+18, vv);
end
if isfield(opt,'hline') && ~isempty(opt.hline)
    for hv = opt.hline(isfinite(opt.hline))
        yy = Y(hv);
        S{end+1} = sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#d62728" stroke-dasharray="6,4" stroke-width="1.5"/>', tx, yy, tx+pw, yy);
    end
end
if ~isempty(opt.xlabel)
    S{end+1} = sprintf(['<text x="' num2str(tx+round(pw/2)) '" y="' num2str(ty+ph+44) '" text-anchor="middle" fill="#222">' opt.xlabel '</text>']);
end
if ~isempty(opt.ylabel)
    S{end+1} = sprintf(['<text x="18" y="' num2str(ty+round(ph/2)) '" text-anchor="middle" fill="#222" transform="rotate(-90 18 ' num2str(ty+round(ph/2)) ')">' opt.ylabel '</text>']);
end
leg = {};
for si = 1:numel(series)
    s = series(si);
    c = col{1+mod(si-1, numel(col))};
    xx = s.x(:); yy = s.y(:);
    kp = isfinite(xx) & isfinite(yy);
    if opt.logy, kp = kp & yy > 0; end
    xs = X(xx(kp)); ys = Y(yy(kp));
    if strcmp(s.style, 'dots')
        for q = 1:numel(xs)
            S{end+1} = sprintf('<circle cx="%.1f" cy="%.1f" r="2.6" fill="%s"/>', xs(q), ys(q), c);
        end
        leg{end+1} = sprintf('<circle cx="%%d" cy="%%d" r="4" fill="%s"/>;%s', c, s.label);
    else
        d = '';
        if strcmp(s.style, 'dash'), d = ' stroke-dasharray="7,4"'; end
        pts = '';
        for q = 1:numel(xs)
            pts = [pts sprintf('%.1f,%.1f ', xs(q), ys(q))]; %#ok<AGROW>
        end
        S{end+1} = sprintf('<polyline points="%s" fill="none" stroke="%s" stroke-width="2"%s/>', pts, c, d);
        leg{end+1} = sprintf('<line x1="%%d" y1="%%d" x2="%%d" y2="%%d" stroke="%s" stroke-width="3"/>;%s', c, s.label);
    end
end
if opt.legend
    lx = tx + 10; ly = ty + 16;
    for q = 1:numel(leg)
        semiPos = find(leg{q} == ';', 1);
        shapeT = leg{q}(1:semiPos-1);
        labelT = leg{q}(semiPos+1:end);
        S{end+1} = sprintf(shapeT, lx, ly, lx+22, ly);
        S{end+1} = sprintf('<text x="%d" y="%d" fill="#222">%s</text>', lx+28, ly+4, labelT);
        ly = ly + 19;
    end
end
S{end+1} = '</svg>';
fid = fopen(fname, 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', S{:});
fclose(fid);
end

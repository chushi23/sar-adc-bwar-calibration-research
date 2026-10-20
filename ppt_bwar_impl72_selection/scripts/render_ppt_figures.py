"""Render traceable, slide-ready BWAR-Impl-72 PNG figures.

Outputs are raster PNG only. Sources are read-only CSV/MD artifacts under
../results; no existing simulation result is changed.

Run from any directory:
    python -X utf8 D:\\模拟学习\\results\\ppt_bwar_impl72_selection\\scripts\\render_ppt_figures.py
"""
from __future__ import annotations

import csv
import math
import os
from collections import Counter
from datetime import datetime
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib import patheffects
from matplotlib.patches import Circle, FancyBboxPatch, Polygon, Rectangle
from matplotlib.ticker import FuncFormatter


OUT = Path(__file__).resolve().parents[1]
RESULTS = OUT.parent
FIG = OUT / "figures_png"
AUDIT = OUT / "audit"
FIG.mkdir(parents=True, exist_ok=True)
AUDIT.mkdir(parents=True, exist_ok=True)

# Stable, presentation-oriented palette.  Colors always have a direct label.
NAVY = "#12324A"
BLUE = "#1677B8"
TEAL = "#118A7E"
ORANGE = "#E38A22"
RED = "#C75050"
GOLD = "#D5A437"
GREY = "#6D7B87"
LIGHT = "#E9EFF3"
GRID = "#D9E1E6"
INK = "#173042"

plt.rcParams.update({
    "font.family": "Microsoft YaHei",
    "axes.unicode_minus": False,
    "axes.titleweight": "bold",
    "axes.labelcolor": INK,
    "xtick.color": INK,
    "ytick.color": INK,
    "text.color": INK,
})


def rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def num(value, default=math.nan):
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


def selected(rows_, predicate):
    found = [r for r in rows_ if predicate(r)]
    if len(found) != 1:
        raise RuntimeError(f"Expected exactly one source row, got {len(found)}")
    return found[0]


def make_fig(title: str, subtitle: str, source: str, figsize=(16, 9)):
    fig = plt.figure(figsize=figsize, dpi=180, facecolor="white")
    fig.text(0.055, 0.940, title, fontsize=26, weight="bold", color=NAVY)
    fig.text(0.055, 0.902, subtitle, fontsize=11.5, color=GREY)
    fig.text(0.055, 0.020, source, fontsize=8.5, color=GREY)
    fig.add_artist(plt.Line2D([0.055, 0.945], [0.875, 0.875], transform=fig.transFigure,
                              color=LIGHT, lw=1.2))
    return fig


def save(fig, name: str):
    fig.savefig(FIG / name, dpi=180, facecolor="white", bbox_inches=None)
    plt.close(fig)


def style(ax, ygrid=True):
    ax.spines[["top", "right"]].set_visible(False)
    ax.spines[["left", "bottom"]].set_color("#B9C7D0")
    ax.tick_params(labelsize=10)
    if ygrid:
        ax.grid(axis="y", color=GRID, linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)


def metric_card(ax, x, y, label, value, color=BLUE, width=0.25):
    card = FancyBboxPatch((x, y), width, 0.17, boxstyle="round,pad=0.012,rounding_size=0.018",
                          linewidth=0, facecolor="#F4F8FA", transform=ax.transAxes)
    ax.add_patch(card)
    ax.add_patch(Circle((x+0.032, y+0.125), 0.017, transform=ax.transAxes, color=color))
    ax.text(x+0.060, y+0.122, label, transform=ax.transAxes, va="center", fontsize=10, color=GREY)
    ax.text(x+0.025, y+0.045, value, transform=ax.transAxes, va="center", fontsize=18,
            weight="bold", color=NAVY)


def chip_icon(ax, x, y, scale=1.0, color=BLUE):
    """Simple raster-rendered chip icon in axes coordinates."""
    w, h = 0.054*scale, 0.040*scale
    ax.add_patch(FancyBboxPatch((x-w/2, y-h/2), w, h, boxstyle="round,pad=0.002,rounding_size=0.004",
                                transform=ax.transAxes, facecolor="#E8F3F9", edgecolor=color, lw=1.5))
    for dx in (-w/2-0.007*scale, w/2):
        for py in (-0.012, 0, 0.012):
            ax.add_patch(Rectangle((x+dx, y+py*scale-0.002*scale), 0.007*scale, 0.004*scale,
                                   transform=ax.transAxes, facecolor=color, edgecolor="none"))
    ax.add_patch(Rectangle((x-0.012*scale, y-0.009*scale), 0.024*scale, 0.018*scale,
                           transform=ax.transAxes, facecolor=color, alpha=.25, edgecolor=color, lw=.7))


def bridge_icon(ax, x, y, scale=1.0, color=TEAL):
    ax.plot([x-0.035*scale, x+0.035*scale], [y, y], transform=ax.transAxes, color=color, lw=2.5)
    ax.add_patch(Circle((x-0.035*scale, y), .008*scale, transform=ax.transAxes, color=color))
    ax.add_patch(Circle((x+0.035*scale, y), .008*scale, transform=ax.transAxes, color=color))
    ax.add_patch(Rectangle((x-0.010*scale, y-0.018*scale), .020*scale, .036*scale,
                           transform=ax.transAxes, facecolor="#EAF7F4", edgecolor=color, lw=1.5))
    ax.text(x, y, "Cb", ha="center", va="center", transform=ax.transAxes, color=color, fontsize=7*scale)


def check_icon(ax, x, y, scale=1.0, color=TEAL):
    ax.add_patch(Circle((x, y), 0.025*scale, transform=ax.transAxes, facecolor="#EAF7F4", edgecolor=color, lw=1.5))
    ax.plot([x-.011*scale, x-.003*scale, x+.013*scale], [y, y-.010*scale, y+.012*scale],
            transform=ax.transAxes, color=color, lw=2.3, solid_capstyle="round")


def warning_icon(ax, x, y, scale=1.0):
    pts = [(x, y+.027*scale), (x-.027*scale, y-.024*scale), (x+.027*scale, y-.024*scale)]
    ax.add_patch(Polygon(pts, transform=ax.transAxes, facecolor="#FFF4DE", edgecolor=ORANGE, lw=1.5))
    ax.text(x, y-.004*scale, "!", transform=ax.transAxes, ha="center", va="center", color=ORANGE,
            fontsize=13*scale, weight="bold")


def add_value_labels(ax, bars, fmt="{:.3f}", shift=0.015, color=INK):
    ylim = ax.get_ylim()
    gap = (ylim[1]-ylim[0])*shift
    for b in bars:
        h = b.get_height()
        ax.text(b.get_x()+b.get_width()/2, h+gap, fmt.format(h), ha="center", va="bottom",
                fontsize=10, color=color, weight="bold")


def fig00_cover():
    fig = make_fig("为什么选择 BWAR-Impl-72？", "先回答两层问题：CDAC 物理候选为何选它；为何系统实现仍必须过 CAL2 解码器门。",
                   "数据版本：results/ 下 Phase 0–8、implementation refinement 与 verification_round2；结论以 2026-10-19 的最新验证为准。")
    ax = fig.add_axes([.055, .10, .89, .72])
    ax.set_axis_off()
    stages = [
        ("1", "四种原始 CDAC", "CAL1 均无法满足完整 16-bit 输出", GREY),
        ("2", "BWA + 多点冗余", "唯一通过完整输入区间与 CAL1 的低电容路径", BLUE),
        ("3", "整数桥可实现化", "Cb=2 Cu；排除 Cb=1 / 3", TEAL),
        ("4", "Impl-64 / Impl-72", "72 用 +2.4 pF 换取更大 DNL 裕量", GOLD),
        ("5", "CAL2 实现验证", "当前 19 位权 decoder 仅 94.4% → NO-GO", RED),
    ]
    xs = [.07, .27, .47, .67, .87]
    for i, (n, head, body, col) in enumerate(stages):
        x = xs[i]
        ax.add_patch(FancyBboxPatch((x-.085,.39), .17,.30, boxstyle="round,pad=0.014,rounding_size=.018",
                                    facecolor="#F8FAFB", edgecolor=col, lw=2, transform=ax.transAxes))
        ax.text(x-.060,.625,n,transform=ax.transAxes,fontsize=21,color=col,weight="bold")
        ax.text(x-.060,.565,head,transform=ax.transAxes,fontsize=11.5,color=NAVY,weight="bold")
        ax.text(x-.060,.475,body,transform=ax.transAxes,fontsize=9.5,color=GREY,wrap=True)
        if i < 4:
            ax.annotate("", xy=(xs[i+1]-.095,.54), xytext=(x+.095,.54), xycoords=ax.transAxes,
                        arrowprops=dict(arrowstyle="->", color="#9FB0BC", lw=1.6))
    chip_icon(ax,.28,.78,1.3,BLUE); bridge_icon(ax,.50,.78,1.3,TEAL); check_icon(ax,.69,.78,1.3,GOLD); warning_icon(ax,.89,.78,1.3)
    ax.text(.50,.22,"推荐表述：BWAR-Impl-72 是“CAL1 物理裕量最佳的参考 CDAC”，\n不是“已完成 CAL2 工程闭环的量产架构”。",
            ha="center", va="center", transform=ax.transAxes, fontsize=16, color=NAVY, weight="bold",
            bbox=dict(boxstyle="round,pad=.6", facecolor="#FFF7E9", edgecolor=GOLD, lw=1.4))
    save(fig, "00_汇报主线_从物理筛选到CAL2门槛.png")


def fig01_architecture_filter():
    # Original four candidate evidence: phase03; BWAR-Impl-72 uses newest r2 data.
    phase03 = rows(RESULTS / "calibration_architecture_study" / "csv" / "architecture_calibration_summary.csv")
    cal1 = {}
    for name in ("Current", "CBW", "BWA", "SBW"):
        r = selected(phase03, lambda x, n=name: x["architecture"] == n and x["calibration_mode"] == "CAL1")
        cal1[name] = (num(r["total_cap_pF"]), num(r["spec_pass_yield"]) * 100, int(num(r["decision_count"])))
    latest = selected(rows(RESULTS / "bwar_implementation_refinement" / "verification_round2" / "csv" / "candidate_64_vs_72_CAL1_10000.csv"),
                      lambda x: x["candidate"] == "BWAR-Impl-72")
    cal1["BWAR-Impl-72"] = (num(latest["total_cap_pF"]), num(latest["pass_yield"]) * 100, int(num(latest["decision_count"])))
    fig = make_fig("架构筛选：原始四种均未通过 CAL1，BWA 冗余路径留下来", "横轴：CAL1 完整 ADC 联合通过率；纵轴：差分核心电容。气泡标签标明比较次数。",
                   "来源：calibration_architecture_study/csv/architecture_calibration_summary.csv（原始四种，1k）；verification_round2/csv/candidate_64_vs_72_CAL1_10000.csv（Impl-72，10k）。")
    ax = fig.add_axes([.095,.16,.62,.63])
    style(ax)
    colors = {"Current": GREY, "CBW": "#B2BFC8", "BWA": "#A9CBE3", "SBW": "#B2BFC8", "BWAR-Impl-72": GOLD}
    markers = {"Current":"s","CBW":"o","BWA":"D","SBW":"^","BWAR-Impl-72":"*"}
    for name,(cap,pas,dec) in cal1.items():
        size = 220 if name != "BWAR-Impl-72" else 520
        ax.scatter(pas, cap, s=size, marker=markers[name], color=colors[name], edgecolor=NAVY if name=="BWAR-Impl-72" else "white", lw=1.4, zorder=3)
        dx = 2 if pas < 10 else -19
        ax.text(pas+dx, cap*1.12, f"{name}\n{dec} decisions", fontsize=10, weight="bold" if name=="BWAR-Impl-72" else "normal", color=NAVY)
    ax.set_xlim(-8,110); ax.set_yscale("log"); ax.set_ylim(35,60000)
    ax.set_xlabel("CAL1 联合通过率（%）", fontsize=12); ax.set_ylabel("差分核心电容（pF，对数刻度）", fontsize=12)
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v,_: f"{v:.0f}%"))
    ax.axvline(99, color=RED, lw=1.4, ls="--"); ax.text(99.5, 45, "99% 目标", color=RED, fontsize=10, rotation=90, va="bottom")
    ax.text(.02,.96,"原始四种：CAL1 仍有缺码 / 非单调 / DNL 问题\n→ 不能靠更高精度 CAL2 挽救", transform=ax.transAxes, va="top", fontsize=10,
            bbox=dict(boxstyle="round,pad=.4", facecolor="#F7FAFB", edgecolor=GRID))
    ax2 = fig.add_axes([.765,.20,.16,.55]); ax2.axis("off")
    ax2.text(.0,.99,"筛选结论", fontsize=16, weight="bold", color=NAVY, va="top")
    check_icon(ax2,.08,.78,.9,TEAL); ax2.text(.19,.79,"BWA 可通过\n冗余重新设计\n恢复搜索覆盖", fontsize=10.5, va="center")
    warning_icon(ax2,.08,.53,.9); ax2.text(.19,.54,"Current-R：\n物理失配裕量墙\nCAL1 仍失败", fontsize=10.5, va="center")
    chip_icon(ax2,.08,.28,.85,GOLD); ax2.text(.19,.29,"进入整数桥\n与冗余尺寸\n实现优化", fontsize=10.5, va="center")
    save(fig, "01_原始架构筛选_CAL1完整ADC证据.png")


def fig02_evolution():
    r2 = rows(RESULTS / "bwar_implementation_refinement" / "verification_round2" / "csv" / "candidate_64_vs_72_CAL1_10000.csv")
    impl64 = selected(r2, lambda x: x["candidate"] == "BWAR-Impl-64")
    impl72 = selected(r2, lambda x: x["candidate"] == "BWAR-Impl-72")
    master = rows(RESULTS / "bwar_implementation_refinement" / "csv" / "master_table.csv")
    old = selected(master, lambda x: x["candidate"] == "BWAR-final-old")
    mincap = selected(master, lambda x: x["candidate"] == "BWAR-Impl-min-cap")
    labels = ["BWAR-final\n旧非整数桥", "Impl-min-cap\nCb2/topR24", "Impl-64\nCb2/topR64", "Impl-72\nCb2/topR72"]
    caps = [num(old["total_cap_pF"]), num(mincap["total_cap_pF"]), num(impl64["total_cap_pF"]), num(impl72["total_cap_pF"])]
    dnl = [num(old["CAL1_DNL99"]), num(mincap["CAL1_DNL99"]), num(impl64["DNL_P99_strict"]), num(impl72["DNL_P99_strict"])]
    fig = make_fig("整数桥实现的演进：Impl-72 用很小面积代价换取 DNL 裕量", "柱：差分核心电容；折线：10k CAL1 max |DNL| 的 P99。DNL 的 0.8 LSB 虚线是本轮采用的工程裕量线（系统硬指标为 <1 LSB）。",
                   "来源：bwar_implementation_refinement/csv/master_table.csv、integer_bridge_stageC_10k.csv；verification_round2/csv/candidate_64_vs_72_CAL1_10000.csv。")
    ax = fig.add_axes([.09,.16,.76,.63]); style(ax)
    x = list(range(4)); bars = ax.bar(x,caps,color=["#B8C9D6", "#8FC7C2", BLUE, GOLD],width=.58,zorder=3)
    ax.set_ylim(210,270); ax.set_ylabel("差分核心电容（pF）",fontsize=12); ax.set_xticks(x,labels,fontsize=10)
    add_value_labels(ax,bars,"{:.1f}",.020)
    axr=ax.twinx(); axr.spines["top"].set_visible(False); axr.spines["right"].set_color("#B9C7D0")
    axr.plot(x,dnl,color=RED,marker="o",markersize=8,lw=2.5,label="CAL1 DNL P99",zorder=5)
    axr.set_ylim(.65,1.05); axr.set_ylabel("CAL1 max |DNL| P99（LSB）",color=RED,fontsize=12); axr.tick_params(axis="y",colors=RED)
    axr.axhline(.8,color=ORANGE,ls="--",lw=1.6);axr.text(3.08,.805,"0.8 裕量线",color=ORANGE,fontsize=10,va="bottom")
    for i,v in enumerate(dnl): axr.text(i,v+.015,f"{v:.3f}",ha="center",color=RED,fontsize=10,weight="bold")
    ax.legend([bars,axr.lines[0]],["核心电容","CAL1 DNL P99"],loc="upper left",frameon=False)
    ax.text(.01,.94,"Cb=2 Cu（300 fF，两单位并联）\n排除了不可实现的 1.949 Cu 桥",transform=ax.transAxes,fontsize=10,va="top",bbox=dict(boxstyle="round,pad=.35",facecolor="#F5FBFB",edgecolor="#B6DEDA"))
    metric_card(ax,.74,.71,"Impl-72 相比 Impl-64", "+2.4 pF / −0.0207 LSB",GOLD,width=.24)
    save(fig, "02_整数桥与冗余演进_面积换DNL裕量.png")


def fig03_64v72_cal1():
    data = rows(RESULTS / "bwar_implementation_refinement" / "verification_round2" / "csv" / "candidate_64_vs_72_CAL1_10000.csv")
    k = [selected(data,lambda x,n=n:x["candidate"]==n) for n in ("BWAR-Impl-64","BWAR-Impl-72")]
    pdk = rows(RESULTS / "bwar_implementation_refinement" / "verification_round2" / "csv" / "candidate_64_vs_72_CAL1_PDK_10000.csv")
    p = [selected(pdk,lambda x,n=n:x["candidate"]==n) for n in ("BWAR-Impl-64","BWAR-Impl-72")]
    fig = make_fig("Impl-64 与 Impl-72：为什么在 CAL1 物理层保留 72 作为参考候选", "两者均为 10,000 颗、零观测硬规格失败。72 的 DNL P99 更低；INL 代价很小，面积只增加 0.96%。",
                   "来源：verification_round2/csv/candidate_64_vs_72_CAL1_10000.csv、candidate_64_vs_72_CAL1_PDK_10000.csv；K-model 与 PDK-sigma 均为 10k。")
    labels=["Impl-64\n250.2 pF", "Impl-72\n252.6 pF"]
    ax1=fig.add_axes([.085,.18,.38,.60]); style(ax1)
    x=[0,1];w=.32
    a=ax1.bar([v-w/2 for v in x],[num(r["DNL_P99_strict"]) for r in k],width=w,color=BLUE,label="K-model")
    b=ax1.bar([v+w/2 for v in x],[num(r["DNL_P99_strict"]) for r in p],width=w,color=TEAL,label="PDK σ")
    ax1.set_ylim(.70,.83);ax1.set_xticks(x,labels);ax1.set_ylabel("max |DNL| P99（LSB）",fontsize=12);ax1.axhline(.8,color=ORANGE,ls="--",lw=1.5,label="0.8 工程裕量")
    add_value_labels(ax1,a,"{:.3f}",.035);add_value_labels(ax1,b,"{:.3f}",.035);ax1.legend(frameon=False,fontsize=9,loc="upper left")
    ax1.text(.05,.06,"72 的 DNL 裕量：\n1−0.777=0.223 LSB\n64 的 DNL 裕量：\n1−0.798=0.202 LSB",transform=ax1.transAxes,fontsize=10,bbox=dict(boxstyle="round,pad=.35",facecolor="#FFF8ED",edgecolor="#F0C67A"))
    ax2=fig.add_axes([.545,.18,.38,.60]);style(ax2)
    a=ax2.bar([v-w/2 for v in x],[num(r["INL_P99_strict"]) for r in k],width=w,color=BLUE,label="K-model")
    b=ax2.bar([v+w/2 for v in x],[num(r["INL_P99_strict"]) for r in p],width=w,color=TEAL,label="PDK σ")
    ax2.set_ylim(0,1.0);ax2.set_xticks(x,labels);ax2.set_ylabel("max |INL| P99（LSB）",fontsize=12);ax2.axhline(4,color=RED,ls="--",lw=1.5)
    add_value_labels(ax2,a,"{:.3f}",.025);add_value_labels(ax2,b,"{:.3f}",.025)
    ax2.text(.07,.75,"两者都远低于\n系统 INL < 4 LSB",transform=ax2.transAxes,fontsize=11,weight="bold",color=TEAL)
    check_icon(ax2,.12,.57,.8,TEAL);ax2.text(.19,.57,"10k：缺码 / 单调 / 联合通过均为 100%",transform=ax2.transAxes,va="center",fontsize=9.6)
    save(fig,"03_Impl64_vs_Impl72_CAL1与PDK失配鲁棒性.png")


def fig04_cal2_gap():
    cal2 = rows(RESULTS / "bwar_implementation_refinement" / "verification_round2" / "csv" / "candidate_64_vs_72_CAL2_A_10000.csv")
    dec = rows(RESULTS / "bwar_implementation_refinement" / "verification_round2" / "csv" / "decoder_ABC_debug100_oracleSparse.csv")
    names=["Impl-64", "Impl-72"]
    cal2pass=[num(selected(cal2,lambda x,n=n: x["candidate"]==f"BWAR-{n}")["pass_yield"])*100 for n in names]
    dec72=[selected(dec,lambda x,n=n: x["candidate"]=="BWAR-Impl-72" and x["decoder"].startswith(n)) for n in ("A_","B_","C_")]
    decoder_pass=[num(r["pass_yield"])*100 for r in dec72]
    fig=make_fig("CAL1 证明 CDAC 物理可行；CAL2 暴露数字解码器闭环缺口", "同一 Impl-72：oracle 位权（CAL1）为上界；目前仅依赖 19 个测得位权的 decoder A/C 尚未达到 99% 目标。",
                 "来源：verification_round2/csv/candidate_64_vs_72_CAL2_A_10000.csv（10k）；decoder_ABC_debug100_oracleSparse.csv（100，诊断）。")
    ax=fig.add_axes([.075,.18,.43,.60]);style(ax)
    values=[100,cal2pass[0],cal2pass[1]]; labs=["CAL1\n64/72", "CAL2-A\nImpl-64", "CAL2-A\nImpl-72"];cols=[TEAL,BLUE,GOLD]
    bars=ax.bar(range(3),values,color=cols,width=.58,zorder=3);ax.set_ylim(88,101.5);ax.set_xticks(range(3),labs);ax.set_ylabel("联合通过率（%）",fontsize=12);ax.axhline(99,color=RED,lw=1.7,ls="--")
    ax.text(2.42,99.15,"99% 目标",color=RED,fontsize=10);add_value_labels(ax,bars,"{:.2f}",.025)
    ax.text(.03,.07,"物理区间连续率：100%\n无缺码：100%\n失败类型：局部码序微反转",transform=ax.transAxes,fontsize=10.2,bbox=dict(boxstyle="round,pad=.38",facecolor="#F6F9FB",edgecolor=GRID))
    ax2=fig.add_axes([.59,.18,.34,.60]);style(ax2)
    labs2=["A\n加权累加", "B\noracle 上界", "C\n系数预测 LUT"]
    bars=ax2.bar(range(3),decoder_pass,color=[BLUE,TEAL,ORANGE],width=.58,zorder=3);ax2.set_ylim(90,101.5);ax2.set_xticks(range(3),labs2);ax2.set_ylabel("联合通过率（%，100颗诊断）",fontsize=11.5);ax2.axhline(99,color=RED,lw=1.7,ls="--")
    add_value_labels(ax2,bars,"{:.0f}",.025)
    ax2.text(.04,.07,"B 需真实物理区间顺序\n→ 仅是诊断上界，\n不能直接当片上实现",transform=ax2.transAxes,fontsize=10,bbox=dict(boxstyle="round,pad=.35",facecolor="#FFF8ED",edgecolor="#F0C67A"))
    save(fig,"04_CAL1物理通过_vs_CAL2解码器缺口.png")


def fig05_microinversion():
    cal2=rows(RESULTS / "bwar_implementation_refinement" / "verification_round2" / "csv" / "candidate_64_vs_72_CAL2_A_10000.csv")
    d64=selected(cal2,lambda x:x["candidate"]=="BWAR-Impl-64")
    d72=selected(cal2,lambda x:x["candidate"]=="BWAR-Impl-72")
    fig=make_fig("CAL2 失败的根因：不是缺码，而是估计权重导致的 1-code 微反转", "配置：σ_meas=0.02 LSB、Navg=512，实际平均 σ_cal≈0.000872 LSB；所有物理 SAR 输入区间仍连续覆盖全量程。",
                 "来源：verification_round2/reports/03_cal2_micro_inversion_root_cause.md；candidate_64_vs_72_CAL2_A_10000.csv；cal2_diagnostic_index.csv。")
    ax=fig.add_axes([.055,.14,.52,.65]);ax.set_axis_off()
    # Process graphic
    steps=[("真实 CDAC\n+ SAR 搜索","物理区间连续\n100%",TEAL), ("19 个测得\n有效位权","白噪平均后\n仍有微小误差",BLUE), ("加权取整\n输出码","相邻 raw vector\n偶发码序交换",ORANGE), ("严格指标\n判定","任一反转 →\nDNL/INL = Inf",RED)]
    pos=[.05,.31,.57,.83]
    for i,(h,b,c) in enumerate(steps):
        ax.add_patch(FancyBboxPatch((pos[i],.36),.15,.30,boxstyle="round,pad=.012,rounding_size=.018",transform=ax.transAxes,facecolor="#FAFBFC",edgecolor=c,lw=2))
        ax.text(pos[i]+.075,.57,h,ha="center",va="center",transform=ax.transAxes,fontsize=11,weight="bold",color=NAVY)
        ax.text(pos[i]+.075,.43,b,ha="center",va="center",transform=ax.transAxes,fontsize=9.5,color=GREY)
        if i<3: ax.annotate("",xy=(pos[i+1]-.015,.51),xytext=(pos[i]+.165,.51),xycoords=ax.transAxes,arrowprops=dict(arrowstyle="->",lw=1.8,color="#9FB0BC"))
    ax.text(.50,.15,"关键判别：连续物理区间 + 零缺码 ≠ 数字重构必然单调",transform=ax.transAxes,ha="center",fontsize=14,weight="bold",color=RED)
    ax2=fig.add_axes([.64,.18,.29,.57]);style(ax2)
    labels=["物理连续", "无缺码", "严格单调", "联合通过"]
    vals=[100,100,num(d72["monotonic_yield"])*100,num(d72["pass_yield"])*100]
    bars=ax2.barh(range(4),vals,color=[TEAL,TEAL,ORANGE,RED],height=.55,zorder=3)
    ax2.set_xlim(88,101);ax2.set_yticks(range(4),labels);ax2.set_xlabel("Impl-72：10k 芯片比例（%）",fontsize=10.5);ax2.xaxis.set_major_formatter(FuncFormatter(lambda v,_:f"{v:.0f}%"))
    for b,v in zip(bars,vals):ax2.text(v+.15,b.get_y()+b.get_height()/2,f"{v:.2f}%",va="center",fontsize=10,weight="bold")
    ax2.invert_yaxis()
    ax2.text(.02,.05,f"平均下降对 / 片：{num(d72['mean_down_transitions']):.4f}\n失败：{int(num(d72['fail_nonmonotonic']))}/10,000",transform=ax2.transAxes,fontsize=10,bbox=dict(boxstyle="round,pad=.35",facecolor="#FFF8ED",edgecolor="#F0C67A"))
    save(fig,"05_CAL2微反转根因_物理区间连续但数字码序交换.png")


def fig06_averaging():
    data=rows(RESULTS / "bwar_implementation_refinement" / "csv" / "practical_cal2.csv")
    d=[r for r in data if num(r["sigma_meas_LSB"])==.02 and num(r["Vos_cal_LSB"])==0]
    d.sort(key=lambda r:num(r["Navg"]))
    x=[num(r["Navg"]) for r in d]; y=[num(r["pass_yield"])*100 for r in d]; down=[num(r["mean_down_transitions"]) for r in d]
    fig=make_fig("重复平均能降低白噪声，却不能消除微反转门槛", "BWAR-Impl-72 前台权重测量：σ_meas=0.02 LSB；每个 decision 采用正/反极性测量。512 次平均仍只有 94.8% 通过。",
                 "来源：bwar_implementation_refinement/csv/practical_cal2.csv；每点 500 颗；此图是第一轮趋势，最新 10k 复验见图04。")
    ax=fig.add_axes([.08,.18,.55,.60]);style(ax)
    ax.plot(x,y,marker="o",ms=7,lw=2.8,color=BLUE,label="CAL2 联合通过率")
    ax.set_xscale("log",base=2);ax.set_xticks(x);ax.get_xaxis().set_major_formatter(FuncFormatter(lambda v,_:str(int(v))))
    ax.set_ylim(25,102);ax.set_xlabel("每个权重的平均次数 Navg（log2 刻度）",fontsize=12);ax.set_ylabel("联合通过率（%）",fontsize=12);ax.axhline(99,color=RED,ls="--",lw=1.6,label="99% 目标")
    ax.text(512,95.5,"94.8%",ha="center",color=BLUE,weight="bold",fontsize=11);ax.legend(frameon=False,loc="lower right")
    ax2=ax.twinx();ax2.spines["top"].set_visible(False);ax2.plot(x,down,marker="s",ms=5,lw=1.8,color=ORANGE,label="平均下降对数")
    ax2.set_yscale("log");ax2.set_ylabel("每片平均下降码对数（log）",color=ORANGE,fontsize=11);ax2.tick_params(axis="y",colors=ORANGE)
    ax.text(.03,.93,"σcal 随 √Navg 下降，\n但严格单调门把尾部失败放大",transform=ax.transAxes,fontsize=10.5,va="top",bbox=dict(boxstyle="round,pad=.38",facecolor="#F8FAFB",edgecolor=GRID))
    axr=fig.add_axes([.70,.22,.23,.48]);axr.axis("off")
    bridge_icon(axr,.15,.85,1.1,TEAL);axr.text(.29,.85,"前台校准成本",transform=axr.transAxes,va="center",fontsize=14,weight="bold")
    axr.text(.02,.65,"19 个有效权重\n× 512 次平均\n× 正/反极性",transform=axr.transAxes,fontsize=13,color=NAVY)
    axr.text(.02,.43,"至少 19,456 次\n比较器判决",transform=axr.transAxes,fontsize=19,weight="bold",color=ORANGE)
    axr.text(.02,.22,"尚未包括平衡搜索、\n参考切换与 settling。",transform=axr.transAxes,fontsize=10.5,color=GREY)
    save(fig,"06_CAL2平均次数_vs_通过率与校准时长.png")


def fig07_decision():
    # Exact inputs are the latest r2 decision, deliberately shown as conditional.
    fig=make_fig("汇报应采用的工程决策：选择 Impl-72 作为 CDAC 参考，不授权量产实现", "物理层的选择理由成立；系统层的 CAL2 decoder 证据尚不成立。把这两句同时讲清楚，汇报结论才可信。",
                 "来源：verification_round2/reports/02_candidate_regression.md、03_cal2_micro_inversion_root_cause.md、04_decoder_comparison.md、06_final_architecture_decision.md。")
    ax=fig.add_axes([.055,.13,.89,.67]);ax.set_axis_off()
    # Left positive decision column
    ax.add_patch(FancyBboxPatch((.02,.10),.42,.76,boxstyle="round,pad=.02,rounding_size=.02",transform=ax.transAxes,facecolor="#F2FBF9",edgecolor=TEAL,lw=2))
    check_icon(ax,.07,.78,1.2,TEAL);ax.text(.12,.78,"为什么保留 Impl-72",transform=ax.transAxes,fontsize=17,weight="bold",va="center")
    bullets=["Cb=2 Cu：整数桥、两单位并联，可实现", "topR=72 / lowR1=256 / botCap=1：19 次判决", "CAL1 10k：DNL99=0.777、INL99=0.748", "K-model 与 PDK σ：零观测硬规格失败", "相对 Impl-64：+2.4 pF，DNL99 改善 0.0207 LSB"]
    for i,s in enumerate(bullets):
        ax.text(.07,.66-i*.105,"●",transform=ax.transAxes,fontsize=13,color=TEAL,weight="bold",va="center")
        ax.text(.11,.66-i*.105,s,transform=ax.transAxes,fontsize=11.5,va="center")
    # right red
    ax.add_patch(FancyBboxPatch((.56,.10),.42,.76,boxstyle="round,pad=.02,rounding_size=.02",transform=ax.transAxes,facecolor="#FFF6F5",edgecolor=RED,lw=2))
    warning_icon(ax,.61,.78,1.2);ax.text(.66,.78,"为什么暂不进 Virtuoso / 版图",transform=ax.transAxes,fontsize=17,weight="bold",va="center")
    risks=["CAL2-A 10k：94.40%，未达到 ≥99%", "19 个测得位权不能定位 correction address", "micro-inversion 使严格 INL/DNL 判为失败", "Oracle decoder B 只是上界，不能冒充片上实现", "需证明可实现的 transition characterization 或重设冗余 margin"]
    for i,s in enumerate(risks):
        ax.text(.61,.66-i*.105,"!",transform=ax.transAxes,fontsize=17,color=RED,weight="bold",va="center")
        ax.text(.65,.66-i*.105,s,transform=ax.transAxes,fontsize=11.5,va="center")
    ax.text(.50,.00,"建议决策：CDAC 参考候选 = BWAR-Impl-72；项目状态 = CAL2 decoder NO-GO，待数字校准闭环后再进入电路级。",
            transform=ax.transAxes,ha="center",fontsize=13.5,weight="bold",color=NAVY,
            bbox=dict(boxstyle="round,pad=.45",facecolor="#FFF8ED",edgecolor=GOLD,lw=1.4))
    save(fig,"07_工程决策_物理候选选择与CAL2_NO_GO边界.png")


def audit():
    """Make a metadata-only inventory; do not inspect certificate/key contents."""
    inventory=[]; ext=Counter(); total=0
    excluded_suffix={".p12", ".pem"}
    for path in RESULTS.rglob("*"):
        if not path.is_file() or OUT in path.parents:
            continue
        rel=path.relative_to(RESULTS).as_posix(); suffix=path.suffix.lower() or "[no extension]"
        st=path.stat(); total+=1; ext[suffix]+=1
        inventory.append((rel,suffix,st.st_size,datetime.fromtimestamp(st.st_mtime).isoformat(timespec="seconds"),"metadata only" if suffix in excluded_suffix else "catalogued"))
    with (AUDIT/"results_file_inventory.csv").open("w",encoding="utf-8-sig",newline="") as f:
        w=csv.writer(f);w.writerow(["relative_path","extension","bytes","modified_local","review_status"]);w.writerows(inventory)
    with (AUDIT/"audit_summary.md").open("w",encoding="utf-8") as f:
        f.write("# results 文件审计与汇报口径\n\n")
        f.write(f"- 审计范围：`D:/模拟学习/results/`，生成时共 **{total}** 个既有文件；逐一目录化于 `results_file_inventory.csv`。\n")
        f.write("- 文本/数据证据重点审阅：Phase 0–3、Phase 4–8、BWAR implementation refinement、verification_round2 的 CSV、报告、MATLAB 源代码和运行日志。\n")
        f.write("- 二进制 MAT/SVG 由文件清单审计；关键数值以对应 CSV/报告交叉核对。证书/私钥容器（.p12/.pem）只记录元数据，不读取内容。\n\n")
        f.write("## 版本优先级\n\n")
        f.write("1. `verification_round2`（2026-10-19）：最新 64/72 10k CAL1/CAL2 验证，**最终 NO-GO**。\n")
        f.write("2. `bwar_implementation_refinement`（2026-10-16）：整数桥与 Impl-72 的物理可实现性筛选。\n")
        f.write("3. `calibration_architecture_study_p4_8`（2026-10-15）：原始四架构、BWAR-final 搜索及早期阶段。\n")
        f.write("4. `calibration_architecture_study`（2026-10-15）：Phase 0–3 基线。\n\n")
        f.write("## 汇报中必须避免的过期表述\n\n")
        f.write("- 不能说“BWAR-Impl-72 已完成 CAL2 并可进入电路级”；最新 10k CAL2-A 是 94.40%。\n")
        f.write("- 可以说“BWAR-Impl-72 是 CAL1 物理裕量最佳、整数桥可实现的 CDAC 参考候选”。\n")
        f.write("- CAL1 的零观测失败不是量产 100% 保证；CAL2 的 oracle B 不是可实现 decoder。\n\n")
        f.write("## 文件类型统计\n\n|扩展名|数量|\n|---|---:|\n")
        for suffix,count in ext.most_common(): f.write(f"|{suffix}|{count}|\n")


def main():
    audit()
    fig00_cover(); fig01_architecture_filter(); fig02_evolution(); fig03_64v72_cal1()
    fig04_cal2_gap(); fig05_microinversion(); fig06_averaging(); fig07_decision()
    print(f"Rendered 8 high-resolution raster PNG figures to {FIG}")


if __name__ == "__main__":
    main()

# Phase 7 — 比较器 offset / noise / settling 敏感性（BWAR-final）

`main_phase48('p7')`。模型：offset=阈值平移（精确树）；settling=一阶统一系数 κ（MSB 残余=设定 LSB 数，**校准不感知**——保守口径）；noise=采样统计传输（2 点/码 × 8 次平均，20 颗）。

| 类型 | 值[LSB] | 达标率 | DNL P95 | INL P95 | 缺码P50 |
|---|---:|---:|---:|---:|---:|
| offset_LSB | 0 | 100.0% | 0.966 | 0.559 | 0 |
| offset_LSB | 0.25 | 0.0% | 1.204 | 3.690 | 1960 |
| offset_LSB | 0.5 | 0.0% | 1.454 | 7.882 | 8817 |
| offset_LSB | 1 | 0.0% | 1.954 | 15.390 | 22401 |
| offset_LSB | 2 | 0.0% | 2.954 | 30.295 | 32096 |
| settle_LSB | 0.01 | 100.0% | 0.966 | 0.559 | 0 |
| settle_LSB | 0.1 | 100.0% | 0.966 | 0.559 | 0 |
| settle_LSB | 0.5 | 100.0% | 0.966 | 0.559 | 0 |
| settle_LSB | 1 | 100.0% | 0.966 | 0.559 | 0 |
| settle_LSB | 2 | 100.0% | 0.966 | 0.559 | 0 |
| noise_LSB | 0.1 | 0.0% | 1.000 | 1.000 | 107 |
| noise_LSB | 0.25 | 0.0% | 1.500 | 1.000 | 51 |
| noise_LSB | 0.5 | 0.0% | 2.000 | 1.480 | 230 |
| noise_LSB | 1 | 0.0% | 2.500 | 1.927 | 1980 |

CSV：[dynamics_sweep.csv](../csv/dynamics_sweep.csv)

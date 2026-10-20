# Phase 1 — CAL0 historical static-DAC regression

MATLAB 25.2.0.2998904 (R2025b); Cu=150 fF; K=0.0399818695 fF; seed=20261013.

The four historical metrics have different endpoint/terminal-bin conventions. Each is preserved for regression. ADC output metrics are computed separately from actual decision intervals.

|Architecture|Runs|P50|P95|P99|Historical target|Relative error|
|---|---:|---:|---:|---:|---:|---:|
|Current|1000|63.351927|127.845441|182.115422|172.265462|5.72%|
|CBW|1000|2.786736|5.900940|7.604798|7.648089|0.57%|
|BWA|1000|44.620561|95.277390|122.850561|122.397260|0.37%|
|SBW|1000|2.444675|4.609436|5.814329|5.891200|1.30%|
|Current|10000|63.378953|132.707807|169.732238|172.265462|1.47%|
|CBW|10000|2.773293|5.869647|7.503121|7.648089|1.90%|
|BWA|10000|44.194138|93.938665|119.907674|122.397260|2.03%|
|SBW|10000|2.487834|4.729966|5.919650|5.891200|0.48%|

The 10,000-run regression gate requires every relative deviation <5%. 1,000-run is a debug sampling stage, not a silicon guarantee. No numerical estimate is inferred from the historical target.

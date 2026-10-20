"""Independent read-only checks of MATLAB representative interval results.
Not a replacement MC engine. Writes no files and does not alter MATLAB data.
Run: python -X utf8 python_crosscheck/check_outputs.py
"""
from pathlib import Path
import numpy as np
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parents[1]


def direct(x, name, w, upper, lower, initial, n=16):
    state = initial if name == "SBW" else 0.0
    bits = []
    for k in range(19 if name == "Current" else n):
        if name in ("CBW", "BWA"):
            j = n - k - 1
            d = int(x >= state + w[j])
            state += d * w[j]
        elif name == "Current":
            d = int(x >= state)
            state += (2 * d - 1) * w[k]
        else:
            d = int(x >= state)
            if k < n - 1:
                j = n - k - 2
                state += lower[j] if d else -upper[j]
            else:
                state += (d - 0.5) / 65536
        bits.append(d)
    if name == "Current":
        code = np.floor(32768 + state / (2.048 / 65536) + 0.5)
    elif name == "SBW":
        code = np.floor(65536 * state + 1e-10)
    else:
        code = np.floor(65536 * state + 0.5)
    return int(np.clip(code, 0, 65535))


def main():
    files = sorted((ROOT / "raw").glob("*_CAL1_*_chip*.mat"))
    assert len(files) == 12, f"Expected 12 representative dies, found {len(files)}"
    for file in files:
        obj = loadmat(file, simplify_cells=True)
        a, r, t, m = (obj[key] for key in ("a", "real", "t", "m"))
        lo, hi, code = [np.asarray(t[key]) for key in ("lo", "hi", "code1")]
        assert np.all(hi > lo) and np.all(np.diff(lo) >= 0)
        assert np.max(np.abs(hi[:-1] - lo[1:])) < 1e-12
        assert abs(np.sum(hi - lo) - np.ptp(a["domain"])) < 1e-10
        widths = np.bincount(code.astype(int), weights=hi-lo, minlength=65536)
        missing = np.count_nonzero(widths <= 1e-14)
        down = np.count_nonzero(np.diff(code) < 0)
        assert missing == m[2] and down == m[7]
        for j in np.linspace(0, len(lo)-1, 127).astype(int):
            c = direct((lo[j]+hi[j])/2, a["name"], r["weights"],
                       r.get("upper", []), r.get("lower", []), r.get("initial", 0))
            assert c == code[j], (file.name, j, c, code[j])
        if down == 0:
            thresholds = a["domain"][0] + np.cumsum(widths)[:-1]
            step = (thresholds[-1]-thresholds[0])/65534
            dnl = np.max(np.abs(np.diff(thresholds)/step-1))
            inl = np.max(np.abs((thresholds-thresholds[0]-np.arange(65535)*step)/step))
            assert abs(dnl-m[0]) < 1e-7 and abs(inl-m[1]) < 1e-7
        else:
            assert np.isinf(m[0]) and np.isinf(m[1])
        # Independent physical network solve, including each P/N realization.
        cap, bridge = r["cap"], np.asarray(r["bridge"])
        seg = np.asarray(a["seg"], dtype=int)-1
        for side in range(2):
            mat = np.diag(np.bincount(seg, weights=cap[side]))
            b = bridge[side] if bridge.ndim == 2 else ([bridge[side]] if bridge.size else [])
            for j, bj in enumerate(b):
                v = np.zeros(mat.shape[0]);v[j]=1;v[j+1]=-1
                mat += bj*np.outer(v,v)
            charge = np.zeros((len(mat), len(seg)))
            charge[seg, np.arange(len(seg))] = cap[side]
            weights = np.linalg.solve(mat, charge)[0]
            assert np.max(np.abs(weights-r["armWeights"][side])) < 1e-12
        print(f"PASS {file.name}: missing={missing}, downward={down}")
    print("PASS: 12 representative chips, 1524 independent conversions, physical matrices and metrics")


if __name__ == "__main__":
    main()

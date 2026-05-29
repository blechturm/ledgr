# Three-way peer comparison driver (Python side): backtrader across widths.
#
# Reads the per-width bars CSVs written by peer_three_way.R (identical data),
# runs the matched SMA(fast)/SMA(slow) crossover, and times cerebro.run() only
# (feed construction excluded) -- the same boundary as the LDG-2457 backtrader
# row. Headline unit: security_bars_sec = n_inst * n_pulses / wall.
#
# Run peer_three_way.R first (it writes the shared CSVs), then:
#   python dev/bench/peer_three_way_backtrader.py --widths 10,50,100,250
#
# Requires: backtrader, pandas (Codex's LDG-2457 row used backtrader 1.9.78.123,
# pandas 3.0.3, numpy 2.4.6 on Python 3.13).
import sys, time, csv, os
import pandas as pd
import backtrader as bt

DAYS = 1260
FAST = 20
SLOW = 50
OUT = sys.argv[sys.argv.index("--out-dir") + 1] if "--out-dir" in sys.argv else "dev/bench/results"
widths = [int(x) for x in (sys.argv[sys.argv.index("--widths") + 1].split(",")
          if "--widths" in sys.argv else ["10", "50", "100", "250"])]


class SmaCross(bt.Strategy):
    params = dict(fast=FAST, slow=SLOW)

    def __init__(self):
        for d in self.datas:
            f = bt.ind.SMA(d.close, period=self.p.fast)
            s = bt.ind.SMA(d.close, period=self.p.slow)
            setattr(self, "x_" + d._name, bt.ind.CrossOver(f, s))

    def next(self):
        for d in self.datas:
            cross = getattr(self, "x_" + d._name)
            if self.getposition(d).size == 0:
                if cross[0] > 0:
                    self.buy(data=d, size=1)
            elif cross[0] < 0:
                self.close(data=d)


rows = []
for w in widths:
    df = pd.read_csv(os.path.join(OUT, f"peer3_bars_{w}.csv"), parse_dates=["ts_utc"])
    cerebro = bt.Cerebro()
    for sym, g in df.groupby("instrument_id"):
        g = g.set_index("ts_utc").sort_index()
        feed = bt.feeds.PandasData(dataname=g, open="open", high="high", low="low",
                                   close="close", volume="volume", openinterest=None)
        cerebro.adddata(feed, name=str(sym))
    cerebro.addstrategy(SmaCross)
    cerebro.broker.setcash(1e7)
    t = time.perf_counter()
    cerebro.run(runonce=True, preload=True)
    el = time.perf_counter() - t
    bc = w * DAYS
    rows.append(("backtrader", w, DAYS, el, bc / el))
    print(f"[w={w}] backtrader {el:.2f}s ({bc/el:.0f} b/s)", flush=True)

with open(os.path.join(OUT, "peer_three_way_results.csv"), "a", newline="") as fh:
    wr = csv.writer(fh)
    for r in rows:
        wr.writerow([r[0], r[1], r[2], f"{r[3]:.6f}", f"{r[4]:.6f}", ""])
print("DONE", flush=True)

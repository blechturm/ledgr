"""Backtrader peer harness for ledgr LDG-2476."""

import argparse
import csv
import importlib.metadata
import json
import time

import backtrader as bt
import pandas as pd


class SmaCross(bt.Strategy):
    params = dict(fast=5, slow=10)

    def __init__(self):
        self.equity_rows = []
        self.fill_rows = []
        self.trade_pnls = []
        self.cross = {}
        for data in self.datas:
            fast = bt.ind.SMA(data.close, period=self.p.fast)
            slow = bt.ind.SMA(data.close, period=self.p.slow)
            self.cross[data._name] = bt.ind.CrossOver(fast, slow)

    def next(self):
        for data in self.datas:
            pos = self.getposition(data).size
            cross = self.cross[data._name][0]
            if pos == 0 and cross > 0:
                self.buy(data=data, size=1)
            elif pos != 0 and cross < 0:
                self.close(data=data)
        ts = self.datas[0].datetime.datetime(0)
        equity = float(self.broker.getvalue())
        cash = float(self.broker.getcash())
        self.equity_rows.append({
            "engine": "backtrader",
            "ts_utc": ts.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "equity": equity,
            "cash": cash,
            "positions_value": equity - cash,
            "position_proxy": equity - cash,
        })

    def notify_trade(self, trade):
        if trade.isclosed:
            self.trade_pnls.append(float(trade.pnl))

    def notify_order(self, order):
        if order.status != order.Completed:
            return
        dt = bt.num2date(order.executed.dt)
        self.fill_rows.append({
            "engine": "backtrader",
            "ts_utc": dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "instrument_id": order.data._name,
            "side": "BUY" if order.isbuy() else "SELL",
            "qty": abs(float(order.executed.size)),
            "price": float(order.executed.price),
        })


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version-only", action="store_true")
    parser.add_argument("--bars")
    parser.add_argument("--equity-out")
    parser.add_argument("--fills-out")
    parser.add_argument("--trades-out")
    parser.add_argument("--metadata-out")
    parser.add_argument("--fast", type=int, default=5)
    parser.add_argument("--slow", type=int, default=10)
    args = parser.parse_args()
    if args.version_only:
        assert callable(bt.Cerebro)
        print(
            "backtrader",
            importlib.metadata.version("backtrader"),
            "pandas",
            importlib.metadata.version("pandas"),
            "cerebro_callable=True",
        )
        return
    required = [args.bars, args.equity_out, args.fills_out, args.trades_out, args.metadata_out]
    if any(x is None for x in required):
        parser.error("--bars, --equity-out, --fills-out, --trades-out, and --metadata-out are required unless --version-only is used")

    start = time.perf_counter()
    bars = pd.read_csv(args.bars, parse_dates=["ts_utc"])
    cerebro = bt.Cerebro()
    for sym, group in bars.groupby("instrument_id"):
        group = group.sort_values("ts_utc").set_index("ts_utc")
        feed = bt.feeds.PandasData(
            dataname=group,
            open="open",
            high="high",
            low="low",
            close="close",
            volume="volume",
            openinterest=None,
        )
        cerebro.adddata(feed, name=str(sym))
    cerebro.broker.setcash(1e7)
    cerebro.addstrategy(SmaCross, fast=args.fast, slow=args.slow)
    ingestion_done = time.perf_counter()
    strategies = cerebro.run(runonce=True, preload=True)
    strategy = strategies[0]
    engine_done = time.perf_counter()

    with open(args.equity_out, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=["engine", "ts_utc", "equity", "cash", "positions_value", "position_proxy"],
        )
        writer.writeheader()
        writer.writerows(strategy.equity_rows)

    with open(args.fills_out, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=["engine", "ts_utc", "instrument_id", "side", "qty", "price"],
        )
        writer.writeheader()
        writer.writerows(strategy.fill_rows)

    pnls = strategy.trade_pnls
    with open(args.trades_out, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=["engine", "trade_count", "win_rate", "average_trade", "trade_level_status"],
        )
        writer.writeheader()
        writer.writerow({
            "engine": "backtrader",
            "trade_count": len(pnls),
            "win_rate": (sum(1 for pnl in pnls if pnl > 0) / len(pnls)) if pnls else "",
            "average_trade": (sum(pnls) / len(pnls)) if pnls else "",
            "trade_level_status": "available_realized_pnl" if pnls else "available_empty",
        })

    results_done = time.perf_counter()
    phase_sec = {
        "ingestion_sec": ingestion_done - start,
        "engine_sec": engine_done - ingestion_done,
        "results_sec": results_done - engine_done,
    }
    wall_sec = sum(phase_sec.values())
    with open(args.metadata_out, "w", encoding="utf-8") as fh:
        json.dump({
            "engine": "backtrader",
            "wall_sec": wall_sec,
            "phase_sec": phase_sec,
            "backtrader": importlib.metadata.version("backtrader"),
            "pandas": importlib.metadata.version("pandas"),
            "boundary_check": ["bars_csv_read", "feed_construction", "engine_run", "canonical_equity_write", "fills_write", "trades_write"],
        }, fh, indent=2)


if __name__ == "__main__":
    main()

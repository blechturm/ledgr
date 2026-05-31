"""Full zipline-reloaded peer harness for ledgr LDG-2476.

This script exercises zipline-reloaded's bundle ingestion and
``run_algorithm`` path. It uses a temporary csvdir bundle built from the shared
bars CSV, a 24/5 calendar to match ledgr's synthetic weekday timestamps, and
the same SMA crossover target semantics as the other peer rows.
"""

from __future__ import annotations

import argparse
import csv
import importlib.metadata
import json
import math
import os
import tempfile
import time
from pathlib import Path

import pandas as pd


ENGINE = "zipline-reloaded-full"
INITIAL_CASH = 10_000_000.0


def write_csvdir_bundle(bars: pd.DataFrame, csvdir: Path) -> list[str]:
    daily_dir = csvdir / "daily"
    daily_dir.mkdir(parents=True, exist_ok=True)
    symbols = sorted(str(x) for x in bars["instrument_id"].unique())
    for instrument_id, group in bars.groupby("instrument_id", sort=True):
        out = group.sort_values("ts_utc").copy()
        out = out[["ts_utc", "open", "high", "low", "close", "volume"]]
        out["dividend"] = 0.0
        out["split"] = 1.0
        out = out.rename(columns={"ts_utc": "date"})
        out.to_csv(daily_dir / f"{instrument_id}.csv", index=False)
    return symbols


def parse_asset_key(txn: dict) -> str:
    asset = txn.get("asset", txn.get("sid", ""))
    symbol = getattr(asset, "symbol", None)
    if symbol is not None:
        return str(symbol)
    return str(asset)


def summarize_transactions(perf: pd.DataFrame) -> tuple[int, float | None, float | None]:
    trade_pnls: list[float] = []
    entry_price: dict[str, float] = {}
    for txns in perf.get("transactions", []):
        if not isinstance(txns, list):
            continue
        for txn in txns:
            if not isinstance(txn, dict):
                continue
            amount = int(txn.get("amount", 0))
            price = float(txn.get("price", 0.0))
            asset_key = parse_asset_key(txn)
            if amount > 0:
                entry_price[asset_key] = price
            elif amount < 0:
                entry = entry_price.get(asset_key, price)
                trade_pnls.append((price - entry) * abs(amount))
                entry_price.pop(asset_key, None)
    if not trade_pnls:
        return 0, None, None
    wins = sum(1 for pnl in trade_pnls if pnl > 0)
    return len(trade_pnls), wins / len(trade_pnls), sum(trade_pnls) / len(trade_pnls)


def run_zipline_full(bars: pd.DataFrame, fast: int, slow: int):
    with tempfile.TemporaryDirectory(prefix="ledgr_zipline_full_", ignore_cleanup_errors=True) as tmp:
        tmp_path = Path(tmp)
        os.environ["ZIPLINE_ROOT"] = str(tmp_path / "zipline_root")

        from zipline import run_algorithm
        from zipline.api import order_target, set_commission, set_slippage, symbol
        from zipline.data.bundles import ingest, register
        from zipline.data.bundles.csvdir import csvdir_equities
        from zipline.finance import commission, slippage
        from zipline.utils.calendar_utils import get_calendar, register_calendar_alias

        csvdir = tmp_path / "csvdir"
        csv_start = time.perf_counter()
        symbols = write_csvdir_bundle(bars, csvdir)
        csv_write_sec = time.perf_counter() - csv_start

        bundle_name = f"ledgr_peer_{os.getpid()}_{int(time.time() * 1000000)}"
        register_calendar_alias("CSVDIR", "24/5", force=True)
        sessions = pd.to_datetime(bars["ts_utc"]).sort_values()
        start_naive = pd.Timestamp(sessions.iloc[0]).tz_localize(None)
        end_naive = pd.Timestamp(sessions.iloc[-1]).tz_localize(None)
        start = start_naive
        end = end_naive

        ingest_start = time.perf_counter()
        register(
            bundle_name,
            csvdir_equities(["daily"], str(csvdir)),
            calendar_name="24/5",
            start_session=start_naive,
            end_session=end_naive,
        )
        ingest(bundle_name, environ=os.environ, show_progress=False)
        ingest_sec = time.perf_counter() - ingest_start

        def initialize(context):
            set_commission(commission.PerShare(cost=0.0, min_trade_cost=0.0))
            set_slippage(slippage.FixedSlippage(spread=0.0))
            context.assets = [symbol(s) for s in symbols]
            context.fast = fast
            context.slow = slow
            context.prev_above = {}
            context.bar_idx = 0

        def handle_data(context, data):
            for asset in context.assets:
                if context.bar_idx < context.slow:
                    valid = False
                    closes = None
                else:
                    closes = data.history(asset, "close", context.slow, "1d")
                    valid = len(closes) == context.slow and not closes.isna().any()
                if valid:
                    fast_value = float(closes.tail(context.fast).mean())
                    slow_value = float(closes.mean())
                    above = fast_value > slow_value
                else:
                    above = False
                was_above = bool(context.prev_above.get(asset, False))
                position = int(context.portfolio.positions[asset].amount)
                if above and not was_above and position == 0:
                    order_target(asset, 1)
                elif (not above) and was_above and position != 0:
                    order_target(asset, 0)
                context.prev_above[asset] = above
            context.bar_idx += 1

        run_start = time.perf_counter()
        perf = run_algorithm(
            start=start,
            end=end,
            initialize=initialize,
            handle_data=handle_data,
            capital_base=INITIAL_CASH,
            data_frequency="daily",
            bundle=bundle_name,
            trading_calendar=get_calendar("CSVDIR"),
            benchmark_returns=pd.Series(dtype=float),
        )
        run_sec = time.perf_counter() - run_start
    return perf, csv_write_sec, ingest_sec, run_sec


def write_equity(path: str, perf: pd.DataFrame) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=["engine", "ts_utc", "equity", "cash", "positions_value", "position_proxy"],
        )
        writer.writeheader()
        for ts, row in perf.iterrows():
            equity = float(row["portfolio_value"])
            cash_raw = row["cash"] if "cash" in row.index else row.get("ending_cash", math.nan)
            cash = float(cash_raw) if pd.notna(cash_raw) else math.nan
            positions_value = equity - cash if math.isfinite(cash) else math.nan
            writer.writerow(
                {
                    "engine": ENGINE,
                    "ts_utc": pd.Timestamp(ts).tz_convert("UTC").strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "equity": equity,
                    "cash": cash,
                    "positions_value": positions_value,
                    "position_proxy": positions_value,
                }
            )


def write_trades(path: str, perf: pd.DataFrame) -> None:
    trade_count, win_rate, average_trade = summarize_transactions(perf)
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=["engine", "trade_count", "win_rate", "average_trade", "trade_level_status"],
        )
        writer.writeheader()
        writer.writerow(
            {
                "engine": ENGINE,
                "trade_count": trade_count,
                "win_rate": "" if win_rate is None else win_rate,
                "average_trade": "" if average_trade is None else average_trade,
                "trade_level_status": "available_realized_pnl" if trade_count else "available_empty",
            }
        )

def write_fills(path: str, perf: pd.DataFrame) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=["engine", "ts_utc", "instrument_id", "side", "qty", "price"],
        )
        writer.writeheader()
        for ts, txns in perf.get("transactions", []).items():
            if not isinstance(txns, list):
                continue
            for txn in txns:
                if not isinstance(txn, dict):
                    continue
                amount = float(txn.get("amount", 0))
                if amount == 0:
                    continue
                writer.writerow(
                    {
                        "engine": ENGINE,
                        "ts_utc": pd.Timestamp(ts).tz_convert("UTC").strftime("%Y-%m-%dT%H:%M:%SZ"),
                        "instrument_id": parse_asset_key(txn),
                        "side": "BUY" if amount > 0 else "SELL",
                        "qty": abs(amount),
                        "price": float(txn.get("price", 0.0)),
                    }
                )


def main() -> int:
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
        from zipline import run_algorithm
        assert callable(run_algorithm)
        print("zipline-reloaded", importlib.metadata.version("zipline-reloaded"), "run_algorithm_callable=True")
        return 0
    required = [args.bars, args.equity_out, args.fills_out, args.trades_out, args.metadata_out]
    if any(x is None for x in required):
        parser.error("--bars, --equity-out, --fills-out, --trades-out, and --metadata-out are required unless --version-only is used")

    wall_start = time.perf_counter()
    bars = pd.read_csv(args.bars, parse_dates=["ts_utc"])
    perf, csv_write_sec, ingest_sec, run_sec = run_zipline_full(bars, args.fast, args.slow)
    engine_done = time.perf_counter()

    write_equity(args.equity_out, perf)
    write_fills(args.fills_out, perf)
    write_trades(args.trades_out, perf)
    results_done = time.perf_counter()
    phase_sec = {
        "ingestion_sec": (engine_done - wall_start) - run_sec,
        "engine_sec": run_sec,
        "results_sec": results_done - engine_done,
    }
    wall_sec = sum(phase_sec.values())
    with open(args.metadata_out, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "engine": ENGINE,
                "wall_sec": wall_sec,
                "phase_sec": phase_sec,
                "csvdir_write_sec": csv_write_sec,
                "ingest_sec": ingest_sec,
                "run_algorithm_sec": run_sec,
                "zipline_reloaded": importlib.metadata.version("zipline-reloaded"),
                "pandas": importlib.metadata.version("pandas"),
                "execution_boundary": "zipline-reloaded csvdir bundle ingestion plus run_algorithm on a temporary 24/5 bundle",
                "boundary_check": ["bars_csv_read", "csvdir_write", "bundle_ingest", "engine_run", "canonical_equity_write", "fills_write", "trades_write"],
            },
            fh,
            indent=2,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Real LEAN CLI peer harness for ledgr LDG-2476 follow-up.

This driver invokes the local LEAN CLI and extracts a canonical equity curve
from its result files, or marks the row UNAVAILABLE with the CLI failure reason.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


ENGINE = "LEAN"


def run_cmd(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def lean_executable() -> str | None:
    return shutil.which("lean")


def write_empty_csv(path: str, fieldnames: list[str]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()


def write_unavailable(args, reason: str, wall_sec: float = 0.0) -> int:
    if args.equity_out:
        write_empty_csv(args.equity_out, ["engine", "ts_utc", "equity", "cash", "positions_value", "position_proxy"])
    if args.fills_out:
        write_empty_csv(args.fills_out, ["engine", "ts_utc", "instrument_id", "side", "qty", "price"])
    if args.trades_out:
        with open(args.trades_out, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(
                fh,
                fieldnames=["engine", "trade_count", "win_rate", "average_trade", "trade_level_status"],
            )
            writer.writeheader()
            writer.writerow(
                {
                    "engine": ENGINE,
                    "trade_count": "",
                    "win_rate": "",
                    "average_trade": "",
                    "trade_level_status": "unavailable",
                }
            )
    if args.metadata_out:
        with open(args.metadata_out, "w", encoding="utf-8") as fh:
            json.dump(
                {
                    "engine": ENGINE,
                    "status": "UNAVAILABLE",
                    "reason": reason,
                    "wall_sec": wall_sec,
                    "phase_sec": {
                        "ingestion_sec": None,
                        "engine_sec": None,
                        "results_sec": None,
                    },
                    "boundary_check": ["bars_csv_read", "lean_cli_subprocess", "engine_run", "canonical_equity_write"],
                },
                fh,
                indent=2,
            )
    return 0


def inspect_bars(path: str) -> dict[str, object]:
    symbols: list[str] = []
    seen: set[str] = set()
    start_date: str | None = None
    end_date: str | None = None
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            ts = str(row["ts_utc"])[:10]
            symbol = str(row["instrument_id"])
            if symbol not in seen:
                seen.add(symbol)
                symbols.append(symbol)
            if start_date is None or ts < start_date:
                start_date = ts
            if end_date is None or ts > end_date:
                end_date = ts
    if start_date is None or end_date is None or not symbols:
        raise ValueError("bars CSV had no rows")
    return {"symbols": symbols, "start_date": start_date, "end_date": end_date}


def copy_project_template(project_dir: Path) -> None:
    src = Path(__file__).resolve().parent / "lean_project"
    shutil.copytree(src, project_dir, dirs_exist_ok=True)


def find_results_json(output_dir: Path) -> Path | None:
    candidates = sorted(output_dir.rglob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    for path in candidates:
        if path.name.lower() in {"results.json", "backtest.json"} or "result" in path.name.lower():
            return path
    return candidates[0] if candidates else None


def extract_equity_rows(results_path: Path) -> list[dict[str, object]]:
    with open(results_path, encoding="utf-8") as fh:
        payload = json.load(fh)
    charts = payload.get("Charts") or payload.get("charts") or {}
    strategy_equity = charts.get("Strategy Equity") or charts.get("strategy equity") or {}
    series = strategy_equity.get("Series") or strategy_equity.get("series") or {}
    equity_series = series.get("Equity") or series.get("equity") or {}
    values = equity_series.get("Values") or equity_series.get("values") or []
    rows: list[dict[str, object]] = []
    for point in values:
        if isinstance(point, dict):
            ts = point.get("x") or point.get("time") or point.get("Time")
            equity = point.get("y") or point.get("value") or point.get("Value")
        elif isinstance(point, list) and len(point) >= 2:
            ts, equity = point[0], point[1]
        else:
            continue
        rows.append(
            {
                "engine": ENGINE,
                "ts_utc": str(ts),
                "equity": equity,
                "cash": "",
                "positions_value": "",
                "position_proxy": "",
            }
        )
    return rows


def write_equity(path: str, rows: list[dict[str, object]]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=["engine", "ts_utc", "equity", "cash", "positions_value", "position_proxy"],
        )
        writer.writeheader()
        writer.writerows(rows)


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

    lean = lean_executable()
    if args.version_only:
        if lean is None:
            print("LEAN UNAVAILABLE lean_cli_subprocess=False reason=lean executable not found")
            return 0
        version = run_cmd([lean, "--version"])
        ok = version.returncode == 0
        text = (version.stdout or version.stderr).strip().replace("\n", " | ")
        print(f"LEAN {text} lean_cli_subprocess={ok}")
        return 0

    required = [args.bars, args.equity_out, args.fills_out, args.trades_out, args.metadata_out]
    if any(x is None for x in required):
        parser.error("--bars, --equity-out, --fills-out, --trades-out, and --metadata-out are required unless --version-only is used")

    wall_start = time.perf_counter()
    if lean is None:
        return write_unavailable(args, "lean executable not found", time.perf_counter() - wall_start)

    with tempfile.TemporaryDirectory(prefix="ledgr_lean_cli_") as tmp:
        tmp_path = Path(tmp)
        project_dir = tmp_path / "lean_project"
        output_dir = tmp_path / "lean_output"
        copy_project_template(project_dir)
        data_dir = project_dir / "data"
        data_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(args.bars, data_dir / "shared_bars.csv")
        bars_info = inspect_bars(args.bars)
        config = {
            "bars_csv": str((data_dir / "shared_bars.csv").resolve()),
            "fast": args.fast,
            "slow": args.slow,
            "symbols": bars_info["symbols"],
            "start_date": bars_info["start_date"],
            "end_date": bars_info["end_date"],
        }
        with open(project_dir / "ledgr_peer_config.json", "w", encoding="utf-8") as fh:
            json.dump(config, fh, indent=2)

        cmd = [lean, "backtest", str(project_dir), "--backtest-name", "ledgr_peer", "--output", str(output_dir)]
        proc = run_cmd(cmd, cwd=project_dir)
        wall_mid = time.perf_counter()
        if proc.returncode != 0:
            reason = (proc.stdout + "\n" + proc.stderr).strip().replace("\n", " | ")
            return write_unavailable(args, reason, wall_mid - wall_start)
        results_path = find_results_json(output_dir)
        if results_path is None:
            return write_unavailable(args, "lean CLI completed but no results JSON was found", wall_mid - wall_start)
        equity_rows = extract_equity_rows(results_path)
        if not equity_rows:
            return write_unavailable(args, f"lean results JSON had no Strategy Equity series: {results_path}", wall_mid - wall_start)

    write_equity(args.equity_out, equity_rows)
    write_empty_csv(args.fills_out, ["engine", "ts_utc", "instrument_id", "side", "qty", "price"])
    with open(args.trades_out, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=["engine", "trade_count", "win_rate", "average_trade", "trade_level_status"],
        )
        writer.writeheader()
        writer.writerow(
            {
                "engine": ENGINE,
                "trade_count": "",
                "win_rate": "",
                "average_trade": "",
                "trade_level_status": "unavailable",
            }
        )
    wall_sec = time.perf_counter() - wall_start
    phase_sec = {
        "ingestion_sec": 0.0,
        "engine_sec": wall_sec,
        "results_sec": 0.0,
    }
    with open(args.metadata_out, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "engine": ENGINE,
                "status": "DONE",
                "wall_sec": wall_sec,
                "phase_sec": phase_sec,
                "boundary_check": ["bars_csv_read", "lean_cli_subprocess", "engine_run", "canonical_equity_write", "fills_write", "trades_write"],
            },
            fh,
            indent=2,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

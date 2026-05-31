# Zipline-Reloaded Peer Project

This directory is the separate `uv` project for the optional
zipline-reloaded peer in `dev/bench/peer_benchmark/peer_benchmark.qmd`.

Zipline-reloaded is optional for LDG-2476. The primary benchmark row is:

- `peer_zipline_full.py`: full zipline-reloaded harness for this benchmark. It
  writes the shared bars to a temporary csvdir bundle, ingests that bundle, and
  runs `zipline.run_algorithm()` on a `24/5` calendar.

```powershell
python -m uv lock --project dev/bench/peer_benchmark/python/zipline
$env:LEDGR_PEER_UV_HOME = "C:\tmp\ledgr-peer-uv"
$env:UV_CACHE_DIR = "$env:LEDGR_PEER_UV_HOME\zipline\cache"
$env:UV_PYTHON_INSTALL_DIR = "$env:LEDGR_PEER_UV_HOME\zipline\python"
$env:UV_PROJECT_ENVIRONMENT = "$env:LEDGR_PEER_UV_HOME\zipline\venv"
python -m uv run --project dev/bench/peer_benchmark/python/zipline python dev/bench/peer_benchmark/python/zipline/peer_zipline_full.py --version-only
```

The R harness sets `UV_CACHE_DIR`, `UV_PYTHON_INSTALL_DIR`, and
`UV_PROJECT_ENVIRONMENT` under `LEDGR_PEER_UV_HOME` or a temporary directory so
generated Python environments do not live under the package tree.

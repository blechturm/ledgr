# Backtrader Peer Environment

This directory is the `uv` project for the repo-local Backtrader peer row in
`dev/bench/peer_benchmark/peer_benchmark.qmd`.

The environment is optional for ordinary R package checks. It is required only
when producing same-host Backtrader parity and timing rows for the maintainer
benchmark report.

Setup from the repository root:

```powershell
python -m uv lock --project dev/bench/peer_benchmark/python/backtrader
$env:LEDGR_PEER_UV_HOME = "C:\tmp\ledgr-peer-uv"
$env:UV_CACHE_DIR = "$env:LEDGR_PEER_UV_HOME\backtrader\cache"
$env:UV_PYTHON_INSTALL_DIR = "$env:LEDGR_PEER_UV_HOME\backtrader\python"
$env:UV_PROJECT_ENVIRONMENT = "$env:LEDGR_PEER_UV_HOME\backtrader\venv"
python -m uv run --project dev/bench/peer_benchmark/python/backtrader python dev/bench/peer_benchmark/python/backtrader/peer_backtrader.py --version-only
```

The R harness sets `UV_CACHE_DIR`, `UV_PYTHON_INSTALL_DIR`, and
`UV_PROJECT_ENVIRONMENT` under `LEDGR_PEER_UV_HOME` or a temporary directory so
generated Python environments do not live under the package tree.

The Batch 8 workspace used `python -m uv` because the user-level script
directory was not on `PATH` as plain `uv`. It also used a repo-local
`UV_CACHE_DIR` because the default user AppData uv cache was not writable from
this shell.

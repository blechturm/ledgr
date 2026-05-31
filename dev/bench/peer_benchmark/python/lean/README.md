# LEAN Python Peer Project

This directory is the separate `uv` project for the optional QuantConnect LEAN
CLI peer used by the LDG-2476 follow-up benchmark plan.

The benchmark records LEAN as unavailable unless the real local LEAN CLI can
run `lean backtest`. Installing the Python CLI package alone is not enough if
the CLI cannot load its local module metadata or engine runtime. The harness
does not emit a local Python substitute row.

```powershell
python -m uv lock --project dev/bench/peer_benchmark/python/lean
$env:LEDGR_PEER_UV_HOME = "C:\tmp\ledgr-peer-uv"
$env:UV_CACHE_DIR = "$env:LEDGR_PEER_UV_HOME\lean\cache"
$env:UV_PYTHON_INSTALL_DIR = "$env:LEDGR_PEER_UV_HOME\lean\python"
$env:UV_PROJECT_ENVIRONMENT = "$env:LEDGR_PEER_UV_HOME\lean\venv"
python -m uv run --project dev/bench/peer_benchmark/python/lean python dev/bench/peer_benchmark/python/lean/peer_lean.py --version-only
```

The `lean_project/` directory is the project skeleton copied into a temporary
workspace before invoking `lean backtest`.

The R harness sets `UV_CACHE_DIR`, `UV_PYTHON_INSTALL_DIR`, and
`UV_PROJECT_ENVIRONMENT` under `LEDGR_PEER_UV_HOME` or a temporary directory so
generated Python environments do not live under the package tree.

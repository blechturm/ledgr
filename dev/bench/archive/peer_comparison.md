# Peer Comparison Index

The current repo-local peer benchmark and parity artifact is:

- `dev/bench/peer_benchmark/peer_benchmark.qmd`
- harness: `dev/bench/peer_benchmark/peer_benchmark.R`

This is an internal maintainer report, not package documentation, not pkgdown
content, and not a public speed ranking.

The older three-way timing-only scripts remain under `dev/bench/` as historical
inputs and helper material:

- `peer_three_way.R`
- `peer_three_way_backtrader.py`
- `peer_sweep_three_way.R`
- `peer_sweep_verify.R`

Those older scripts are orientation/timing harnesses. They do not replace the
current parity report because they do not emit the canonical per-engine equity
curves, parity tiers, status rows, and parity history required by v0.1.8.8.

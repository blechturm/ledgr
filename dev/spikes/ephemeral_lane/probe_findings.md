# ephemeral_lane: probe findings

`probe.R --lib=<pin library> --shape=10x300` on 2026-11-14 (lean loop
installed as in `dev/spikes/lean_fifo_cpp/lean_env.R`):

- `ledgr_sweep(exp, ledgr_grid_named(a = list(strategy = list())), seed = ...)`
  with one candidate and one worker runs the lean loop: one lean fold per
  sweep. A `ledgr_run()` of the same experiment adds one more.
- The sweep returns one row per candidate with the metrics and its own
  phase timings (`t_engine`, `t_results`, `t_fills_extract`). Nine metrics
  are also produced by `ledgr_compute_metrics(bt)` for the durable run:
  `total_return`, `annualized_return`, `volatility`, `sharpe_ratio`,
  `max_drawdown`, `n_trades`, `win_rate`, `avg_trade`, `time_in_market`.
  On this shape all nine are bit-identical between the lanes, so the
  charter's economic parity is checkable by `identical()` on those nine.
- The sweep row also carries `final_equity`; `ledgr_compute_metrics()` does
  not, but the durable equity table does.
- The two lanes use different execution seeds (the sweep derives a
  candidate seed); the descriptors' strategies draw no random numbers, so
  results agree.

Consequence for the runner: time the whole call in both lanes, the fold
(`ledgr_fold_envelope`) in both, and record the sweep's own `t_engine`;
require the nine metrics identical and the final equities equal.

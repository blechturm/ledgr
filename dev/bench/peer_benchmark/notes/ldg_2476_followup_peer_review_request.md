# Claude Peer Review Prompt: LDG-2476 Follow-up

Status: prompt for external Claude review

This note is a prompt to paste into Claude, the separate Anthropic agent. It is
not itself the review result.

## Prompt

Please peer review the LDG-2476 follow-up findings and optimization-target
summary in the local ledgr workspace.

The working conclusion is:

> The apparent ledgr peer-benchmark regression is primarily a workload mismatch
> plus high fill/event turnover and expensive fills read-back, not a broad
> fold-core regression. The old comparison used SMA 20/50 continuous-target
> semantics with 13,355 fills; the current peer parity run used SMA 5/10
> crossover-event semantics with 68,324 fills. Re-running the old-shape style on
> current source lands back in the 31s class, close to the previous 30.75s
> current-source row.

Please check whether that conclusion is supported by the evidence and whether
the optimization targets are accurately ranked.

Inspect these files/artifacts:

- `dev/bench/peer_benchmark/notes/ledgr_regression_source_analysis.md`
- `dev/bench/peer_benchmark/notes/backtrader_scale_check.md`
- `inst/design/horizon.md` section:
  `2026-05-31 [optimization] LDG-2476 peer-benchmark turnover cost decomposition`
- `dev/bench/results/ledgr_bench_record_20260530T193039Z_results.json`
- `dev/bench/results/ledgr_regression_continuous_20260531T101455Z.csv`
- `dev/bench/results/ledgr_regression_continuous_20_50_20260531T101945Z.csv`
- `dev/bench/results/peer_benchmark_record_20260531T053230Z_performance.csv`
- `dev/bench/results/peer_benchmark_record_20260531T053230Z_divergence_summary.csv`
- `dev/bench/peer_benchmark/peer_benchmark.R`
- `R/fold-engine.R`
- `R/backtest.R`
- `R/backtest-runner.R`

Requested output:

- Verdict: approve / approve with caveats / block.
- Blocking issues, if any.
- Unsupported or over-strong claims, if any.
- Missing caveats, especially around benchmark boundary differences.
- Whether the horizon optimization target summary is accurate.
- Whether any target should move up/down in priority.
- Any better next diagnostic to distinguish:
  - fill/event emission during the fold,
  - fills read-back reconstruction,
  - snapshot/data ingestion,
  - strategy-state persistence,
  - target/state vector copying.

Do not edit files during the review.

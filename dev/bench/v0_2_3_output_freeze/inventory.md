# A0 inventory: what runs the two output handlers today

Tree: `release/v0.2.3` at `20034e00`. P = persistent handler
(`ledgr_persistent_output_handler`, `R/backtest-runner.R:252`, reached through
`ledgr_run`, `ledgr_promote`, `ledgr_backtest`, `ledgr_run_config`,
walk-forward test runs). M = memory handler (`ledgr_memory_output_handler`,
`R/sweep.R:1982`, reached through `ledgr_sweep` and walk-forward train
sweeps, or called directly). Found by searching `tests/testthat` and
`dev/bench` for both handler names and `ledgr_sweep(`; the four named parity
files and the resume/terminal tests were read in full.

## Tests that hold the two handlers (or one handler across modes) equal

| File (test line) | Handlers | What it compares | Fixture |
| --- | --- | --- | --- |
| `test-sweep-parity.R` (203, 300, 364, 410, 449) | P, M | sweep row `final_equity` + 9 metrics vs promoted run (1e-10); promoted vs direct run ledger/fills/trades/equity detail/final positions (1e-10); memory reconstruction of the run ledger vs persisted equity/fills/metrics | inline `ledgr_parity_bars()` AAA/BBB 4 days; spread 5 bps + fee 1; opening lots; seeded `runif`; `pulse_seed`; SMA factory |
| `test-sweep-persistence-parity.R` (186, 195, 210, 221, 244) | P, M | retained sweep returns vs inline summary and vs run equity and `ledgr_equity_from_events` (1e-12), R and compiled spot-FIFO; final-bar and failed-candidate edges | inline AAA/BBB 8 days, grid flat/partial/open_end |
| `test-ledger-writer.R` (213, 559, 629, 293) | P, M direct | pulse-flush visibility, buffer growth across capacity 2, failed write exposes no partial row, both handlers identical rows and typed attrs | fake writes, in-memory DuckDB |
| `test-availability-parity.R` (554, 585, 915) | P, M | `completion_json` workers 1 = 2 = direct terminal evidence; opening-time cutoff final equity; walk-forward on gapped calendar (status only) | `availability_runtime_fixture()` |
| `test-terminal-outcomes.R` (524, LTB-0169) | P, M | straight vs interrupted+resumed run tables identical (minus ids); reopen; sweep final equity and returns path vs run equity | AAA/BBB/CLK, BBB bankruptcy on day 5 |
| `test-risk-fold.R` (345) | P, M mocked | injected `write_fill_events` / `record_accounting_fact` faults in each handler | `ledgr_test_make_bars` dense and with sessions |
| `test-strategy-schedule.R` (77, 1366, 1791) | P, M | manual vs scheduled valuation; workers 1/2/3 status and final equity; run equity vs workers=2 sweep returns | `ws42_history_fixture` |
| `test-scoring-boundary.R` (36, 122, 202) | P, M | run, backtest, sweep, promote, window, walk-forward equity vs a hand vector; availability sweep returns/trades vs run | inline 10-day AAA |
| `test-history-continuity.R` (126, 332) | P (M at 332) | walk-forward chain vs one run (fills, ledger dividends, equity, trades, diagnostics, availability); ctx spy | dividend fixture |
| `test-history-substrate.R` (1446, 1618) | M (P at 1618) | workers 1/2/3 candidate status, final equity, trades, seed; run vs sweep final equity; walk-forward workers | history substrate fixture |
| `test-sweep-parallel.R` (71, 129, 180, 227, 270, 297) | M | workers 1/2/3 vs sequential frames (opening lots, risk max_weight); warnings; no run-store writes | `ledgr_parallel_sweep_test_bars()` |
| `test-sweep.R` (146, 220, 303, 369, 1037) | M | inline summary vs ordered-event summary; compiled vs R (with risk chain, 1e-12); pulse-view variants equal `events()` | inline bars |
| `test-execution-spec.R` (576, 749, 928) | M direct | compiled vs R fold events, typed attrs, summary, lot state | inline bars |
| `test-cross-asset-corrections.R` (240, 494) | M, P | compiled vs R sweep stable columns identical; default vs explicit calendar | `ledgr_ws59_*` |
| `test-backtest-audit-log-equivalence.R` | P | `db_live` vs `audit_log` fills/ledger equal | inline BTC bars |
| `test-cost-model.R` (253), `test-sweep-persistence-roundtrip.R` (444), `test-indicator-history-calculation.R` (417), `test-availability-features.R` (242) | P, M | promoted vs direct equity; reopened sweep vs promoted final equity (1e-12); warning/message parity run vs sweep vs workers=2 | inline |

`test-workstream8-exact-parity.R` is named in the brief but compares hot-path
substitutions (feature lookup, marks) against oracles, not handler output.

## Single-handler output assertions

- P, resume and recovery: `test-run-continuity.R`, `test-run-continuity-ii.R`,
  `test-pit-consistency.R`, `test-runner.R`, `test-acceptance-v0.1.0.R`,
  `test-experiment-run.R`, `test-fifo-opening-positions.R`,
  `test-corporate-action-recovery.R` (101), `test-corporate-action-cash.R`
  (252), `test-availability-parity.R` (41, 276, 347, 406, 477),
  `test-availability-economics.R` (836, 1066), `test-strategy-schedule.R`
  (1233). Interrupts use `options(ledgr.interrupt = TRUE)`,
  `rlang::interrupt()`, `ledgr_run_fold(control = list(max_pulses = N))` or a
  mocked `DBI::dbWithTransaction` finalization failure.
- M: `test-corporate-action-recovery.R` (153, failed candidate discards its
  disposition), `test-risk-fold.R` (direct handler calls),
  `test-research-cycle-scale.R` (135, diagnostics pruning), `test-sweep.R`,
  `test-sweep-retention.R`, `test-sweep-single-feature-persistence.R`.
- Incidental `ledgr_sweep` callers (aliases, feature maps, grids, RNG,
  precompute, promotion lineage, connection counts, filters, walk-forward
  orchestration) assert their own topic, not handler output.

## dev/bench runners

Asserting: `parallel_sweep/parallel_sweep_measurement.R` (workers vs 1),
`v0_2_2_history_substrate/worker_transport.R` (workers 2 vs 1),
`peer_benchmark/peer_benchmark.R` (public sweep vs a memory-handler oracle,
1e-8), `v0_2_2_scoring_boundary/{run_record,check_record}.R`,
`v0_2_2_workstream7/explicit_map_benchmark.R`,
`v0_2_2_workstream8/strict_feature_benchmark.R`. Timing or probe only:
`v0_2_2_antipattern_repairs/writer_arm.R`,
`v0_2_2_sharadar_run/probe_diagnostic_append.R`,
`v0_2_2_real_data_scale/{run_record,probes,profile,fold_phase_all_fill}.R`,
`v0_2_2_residual_performance/*_h1.R`, and the long-window, peer-sweep,
workstream-31 and history-simplification runners.

## Gaps the parity suite leaves (and A0 closes)

No test runs one risk chain through both `ledgr_run` and `ledgr_sweep` and
compares full artifacts; no dividend outcome is compared between run and
sweep output (no split runs through either comparison); run-versus-sweep
comparisons use tolerances (1e-10, 1e-12) or final equity only, not bytes;
and the memory handler's kept diagnostics are never compared with the
persisted trace.

## Chosen workload set

| Workload | Handler paths | Why it is in the set | Fixture source |
| --- | --- | --- | --- |
| `dense_cost` | run, run_db_live, sweep_w1, sweep_w2, sweep_compiled | committed run and sweep on one workload; cost chain; last-bar no-fill warning; one and two workers; compiled spot-FIFO memory path; `db_live` persistent mode | `test-sweep-persistence-parity.R` |
| `dense_risk_features` | run, sweep_w1, sweep_w2 | risk chain (long_only + max_weight with a grid parameter) through both paths; SMA warmup; opening lot; `pulse_seed`; non-default metric context | `test-sweep-parity.R`, `test-sweep-parallel.R` |
| `dense_dividend_state` | run, sweep_w1 | dense corporate action (cash dividend CASHFLOW); `strategy_state` writes | `test-corporate-action-cash.R` |
| `avail_terminal_resume` | run, run_resumed, sweep_w1, sweep_w2 | availability mode; stale freeze; bankruptcy write-off; interrupted run resumed by `ledgr.interrupt` | `test-terminal-outcomes.R` LTB-0169 |
| `avail_acquisition` | run, sweep_w1 | cash acquisition disposition at the deal price | `test-corporate-action-recovery.R` |
| `avail_incomplete` | run, sweep_w1, sweep_w2 | INCOMPLETE terminal outcome and completion evidence | `test-availability-parity.R` |
| `walk_forward` | run, sweep_w1, walk_forward | train sweeps (M) and carried test runs (P) on a gapped calendar with fees | `test-availability-parity.R` LTB-0024 |

Demoted: promotion (`ledgr_promote` writes wall-clock and sweep-id
context; its fold is `ledgr_run`), `ledgr_run_window` and `ledgr_sweep_window`,
precomputed features, and failed candidates (see closeout open points).

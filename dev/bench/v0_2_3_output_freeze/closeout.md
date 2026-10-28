# A0 closeout: current native outputs frozen before WS1

**Answer (green).** Today's tree (`release/v0.2.3` at `20034e00`) produces
byte-reproducible outputs through both output handlers on seven synthetic
workloads (12 handler paths). `records/` holds them (192 files, 398.9 KB,
one SHA-256 each in `records/manifest.csv`). `check.R` re-runs everything and
passes; every gut corruption makes it fail and names the table. No stop
condition in brief section 6 fired (harness 1,129 R lines, records 0.4 MB,
no product change, output deterministic). WS1 gate: `Rscript
dev/bench/v0_2_3_output_freeze/check.R` exits 0 on the WS1 tree.

## Workloads

See `inventory.md` for the reasons and fixture sources. Paths: `run` =
`ledgr_run` per candidate (persistent, `audit_log`); `run_db_live` =
`ledgr_backtest(execution_mode = "db_live")`; `run_resumed` = interrupted by
`ledgr.interrupt`, then resumed; `sweep_w1`/`sweep_w2` = `ledgr_sweep` with
one/two workers (memory); `sweep_compiled` = spot-FIFO memory path;
`walk_forward` = folds, scores and carried test runs.

| Workload | Paths | Record |
| --- | --- | --- |
| dense_cost | run, run_db_live, sweep_w1, sweep_w2, sweep_compiled | 81.6 KB |
| dense_risk_features | run, sweep_w1, sweep_w2 | 41.2 KB |
| dense_dividend_state | run, sweep_w1 | 21.1 KB |
| avail_terminal_resume | run, run_resumed, sweep_w1, sweep_w2 | 50.1 KB |
| avail_acquisition | run, sweep_w1 | 28.0 KB |
| avail_incomplete | run, sweep_w1, sweep_w2 | 33.0 KB |
| walk_forward | run, sweep_w1, walk_forward | 142.9 KB |

Persistent paths record every run-store table with a `run_id` column (runs,
run_provenance, run_telemetry, run_completion, run_diagnostics, ledger_events,
equity_curve, strategy_state, run_tags, run_promotion_context), plus the
public readers (fills, trades, `ledgr_compute_metrics`) and the warnings each
run raised. Memory paths record the sweep row, its attributes, and retained
returns and closed trades. An unknown run-store table fails the harness. Each
table has a declared unique key and radix order; doubles print with `%.17g`
(lossless); records are LF, UTF-8, and `.gitattributes` keeps git from
converting them.

## Determinism

Two consecutive `record.R` runs gave identical manifests (manifest SHA-256
`81bc80f9...e99b8`). The first trial found two varying fields, both fixed
by declaration rather than tolerance: the random `sweep_id` repeated in the
returns and trades tables, and absolute temp paths inside `runs.config_json`.
The paths become `<DB_PATH>`.

## Gut demonstration (`gut.R`, `gut_results.csv`)

| Corruption (raw product output, before canonicalization) | check.R |
| --- | --- |
| control, none | exit 0, PASS |
| FILL qty +1 in `ledger_events` (dense_cost) | exit 1: ledger_events and fills, row 2, qty |
| one `equity_curve` value moved 1 ulp (dense_risk_features) | exit 1: equity_curve row 13 (`...498` vs `...6775`), metrics |
| one `run_diagnostics` row deleted (avail_terminal_resume) | exit 1: run_diagnostics row 6 |
| two ledger events written in swapped order (dense_dividend_state) | exit 1: ledger_events row 2, fills event_seq |
| memory path: retained sweep equity moved 1 ulp (dense_cost) | exit 1: sweep_returns row 19 |

## Baseline timing (`timing.R`, `timing.csv`; descriptive, not a gate)

Medians of three alternating repetitions, warm snapshot, all candidates per
path. Host: i9-12900K, 24 logical cores, High performance plan, no affinity
pinning, CPU load 4% before and 9% after; Positron, Spotify, GalaxyClient
and codex running. R 4.6.1, ledgr 0.2.2 via pkgload, duckdb 2.0.0, collapse
2.1.8, mirai 2.7.2 (`timing_host.txt`).

| Workload | Run s | Sweep s | Run/sweep |
| --- | --- | --- | --- |
| dense_cost | 0.59 | 0.25 | 2.36 |
| dense_risk_features | 0.43 | 0.17 | 2.53 |
| dense_dividend_state | 0.41 | 0.15 | 2.73 |
| avail_terminal_resume | 0.27 | 0.16 | 1.69 |
| avail_acquisition | 0.51 | 0.18 | 2.83 |
| avail_incomplete | 0.45 | 0.17 | 2.65 |
| walk_forward | 0.52 | 0.19 | 2.74 |
| timing_scale (20 x 252, timing only) | 1.10 | 0.75 | 1.47 |

The record fixtures have 3 to 10 bars. Their times mostly measure fixed
per-call cost (store open, registration, finalization), so they must not be
ranked. The H6 gap on bar-bound work is closer to the scale row.

## Excluded fields (`records/excluded_fields.csv`)

The `created_at_utc` columns of runs, run_provenance and run_tags are wall
clock. `elapsed_sec` and `updated_at_utc` (run_telemetry) and the sweep row's
`t_engine`, `t_results` and `t_fills_extract` are wall-clock telemetry.
`engine_version` (runs) and `ledgr_version` (run_provenance) are version
strings that change with a bump, not with handler behavior. `R_version` and
`dependency_versions_json` describe the host. `sweep_id` in the attributes,
returns and trades is drawn at random per call. Path tokens replace absolute
DB paths in text.

## Today's handler agreement (`agreement.csv`, 167 checks, 5 differ)

Run and sweep agree, with byte-identical canonical values, on status, final
equity, every metric, the equity path, closed trades, stop reason and warning
codes. The other comparisons also agree:

- `db_live` and `audit_log` produce the same output.
- The resumed run matches the straight run.
- Two workers match one, apart from the transport detail noted below.
- Compiled and R sweeps match on every output table.
- The memory handler's internal `events()` equal the persisted `ledger_events`.
- Its kept diagnostics equal the persisted rows with the same `diagnostic_seq`.

Known differences:

1. On INCOMPLETE runs the sweep row reports `annualized_return = 0`, while
   `ledgr_compute_metrics()` on the run withholds it (`NA`). This is
   avail_incomplete, both candidates.
2. The memory handler keeps only summary diagnostic rows, for example 7 of 33
   or 2 of 33. Sweeps never expose the full trace.
3. With two workers, `staged_invariant_bytes` is non-zero (96784 and 73040 on
   availability workloads). This is transport detail and is recorded per path.
4. `execution_assumptions` names `compiled_accounting_model = spot_fifo` on
   the compiled path, as expected.

## Open points for the WS1 cut

1. Failure paths are not in the record set. These are `record_failure`,
   `abort_run`, `write_exception_diagnostic`, a FAILED sweep candidate and a
   finalization failure. Add a failing candidate before WS1 if the cut
   touches them.
2. Records cover public surfaces. The internal-buffer rows in
   `agreement.csv` report "skipped" once the memory factory is gone. That is
   expected and is not a failure.
3. Difference 1 above is a semantic choice for the unified handler. WS1 must
   keep both values byte-identical or decide the change explicitly and
   re-record.
4. The records embed the fixtures' strategy source (config_json,
   strategy_hash). Any edit to `lib.R` fixtures must be re-recorded on
   `20034e00`, never on the WS1 tree.
5. Two-worker paths load the source tree through pkgload, so run `check.R`
   from a source checkout. Re-run `timing.R` after WS1 on the same host to
   re-measure H6.

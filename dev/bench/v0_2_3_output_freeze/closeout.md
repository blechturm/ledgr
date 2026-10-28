# A0 closeout: current native outputs frozen before WS1

**Answer (green).** Today's tree (`release/v0.2.3` at `20034e00`; this
harness changes no product file) produces byte-reproducible outputs through
both output handlers on eight synthetic workloads (15 handler paths).
`records/` holds them (279 files, 530.6 KB, one SHA-256 each in
`records/manifest.csv`). `check.R` re-runs everything and passes; all 15
corruptions in `guts.R` make it fail and name the table or the missing
observation point. No stop condition in brief section 6 fired: the harness is
1,383 R lines, the records 0.5 MB, no product file changed and the output is
deterministic. WS1 gate: `Rscript dev/bench/v0_2_3_output_freeze/check.R`
exits 0 on the WS1 tree. Revision 2 answers `reviews/codex_review_1.md`.

## Workloads

Reasons and fixture sources are in `inventory.md`. Paths:

- `run`: `ledgr_run` per candidate (persistent, `audit_log`); expected
  failures are recorded, not raised.
- `run_db_live`: `ledgr_backtest(execution_mode = "db_live")`.
- `run_resumed`: soft-stopped by `ledgr.interrupt`, then resumed.
- `run_abort`: a refusal through `abort_run`.
- `sweep_w1`/`sweep_w2`: `ledgr_sweep` with one or two workers (memory).
- `sweep_compiled`: the spot-FIFO memory path.
- `walk_forward`: folds, scores and carried test runs.

| Workload | Paths | Record |
| --- | --- | --- |
| dense_cost | run, run_db_live, sweep_w1, sweep_w2, sweep_compiled | 104.2 KB |
| dense_risk_features | run, sweep_w1, sweep_w2 | 56.0 KB |
| dense_dividend_state | run, sweep_w1 | 28.8 KB |
| avail_terminal_resume | run, run_resumed, sweep_w1, sweep_w2 | 61.2 KB |
| avail_acquisition | run, sweep_w1 | 37.0 KB |
| avail_incomplete | run, sweep_w1, sweep_w2 | 41.2 KB |
| walk_forward | run, sweep_w1, walk_forward | 155.3 KB |
| failures | run, run_abort, sweep_w1, sweep_w2 | 45.6 KB |

What each path records:

- **Persistent paths:**
  - every run-store table with a `run_id` column (runs, run_provenance,
    run_telemetry, run_completion, run_diagnostics, ledger_events,
    equity_curve, strategy_state, run_tags, run_promotion_context);
  - the public readers (fills, trades and `ledgr_compute_metrics`) for runs
    that returned;
  - `run_conditions`: every warning and expected error in order, with its
    class chain and message.
- **Memory paths:** the sweep row, its attributes, retained returns and closed
  trades.
- **In-process memory paths (`sweep_w1`, `sweep_compiled`):** also the memory
  sink's native buffers, through `a0_observe_memory()`:
  - `memory_events`, with typed `cash_delta`, `position_delta`,
    `event_realized`, `event_cost_basis` and `meta`;
  - `memory_diagnostics` (the retained rows) and `memory_completion`;
  - `memory_equity` and `memory_fills` (the inline summary);
  - `memory_state` (counts, and which of these were NULL).
- **Not recorded:** a FAILED candidate's buffers, which are discarded by
  contract (LTB-0055); its failure is recorded in the sweep row.

How the files are written:

- Each table has a declared unique key and is sorted in a locale-independent
  order.
- The header carries `name:class`.
- Present values are quoted; SQL NULL or R `NA` is an unquoted `NA`.
- Nested values mark missing as `\N` and escape their delimiters.
- Text escapes `\` first, then line breaks.
- Doubles print with `%.17g`, which is lossless.
- Files are LF and UTF-8, and `.gitattributes` keeps git from converting
  them.

## What WS1 must expose

`a0_observe_memory()` in `lib.R` is the only part of the harness WS1 may
adapt. For each sweep candidate (`run_id` = candidate label), the replacement
sink must deliver the same native output today's memory handler does:

- `events()` with the typed attributes
  `ledgr_event_{cash_delta,position_delta,realized,cost_basis,meta}`;
- the retained `diagnostics()`, NULL when none;
- `completion()`, NULL in dense mode;
- the `inline_summary()` equity and fills.

If the factory is gone and the adapter is not updated, `check.R` stops with
"no memory-sink observation point" and exits non-zero. It does not skip
(gut `memory_observer_missing`). Canonicalization, fixtures and `records/`
must not change in WS1.

## Determinism

Three `record.R` runs on the same tree gave identical manifests. That
includes the final code; the manifest SHA-256 is `21285a80…20b2fb`. The
varying fields found earlier are handled by declaration:

- the random `sweep_id`, which is excluded;
- absolute temp paths, now `<DB_PATH>`;
- rlang source references in error messages (`at R/file.R:30:5:`), now
  `<SRCREF>`. They move with any product edit and name the worktree.

## Gut demonstration (`gut.R`, `gut_results.csv`)

Every corruption edits raw product output before canonicalization: the run
store, the sweep result, the memory sink's buffers, or a patched handler.

| Corruption | check.R names |
| --- | --- |
| none (control) | exit 0, PASS |
| FILL qty +1 | dense_cost/run/ledger_events and fills, qty |
| equity value moved 1 ulp | dense_risk_features/run/equity_curve row 13 |
| one run_diagnostics row deleted | avail_terminal_resume/run/run_diagnostics row 6 |
| two ledger events swapped | dense_dividend_state/run/ledger_events, fills |
| `runs.error_msg` NULL changed to text 'NA' | avail_terminal_resume/run/runs, error_msg |
| retained sweep equity moved 1 ulp | dense_cost/sweep_w1/sweep_returns row 19 |
| memory sink: one event_id altered | dense_cost/sweep_w1/memory_events, event_id |
| memory sink: retained diagnostic's detail_json replaced | avail_terminal_resume/sweep_w1/memory_diagnostics |
| memory factory absent, no observer | stops: "no memory-sink observation point" |
| handler warns on each telemetry write in walk-forward | walk_forward/walk_forward/run_conditions |
| failed run: error_msg altered | failures/run/runs, error_msg |
| failed run: exception diagnostic lost | failures/run/run_diagnostics |
| failed run: rolled-back fill survives | failures/run/ledger_events |
| FAILED sweep candidate: error_msg altered | failures/sweep_w1/sweep, error_msg |
| abort_run refusal left RUNNING | failures/run_abort/runs, status |

Every corruption exits 1.

## Baseline timing (`timing.R`, `timing.csv`; descriptive, not a gate)

These are the medians of three alternating repetitions on a warm snapshot.
They were measured on revision 1. The product is unchanged since then, and
revision 2 only skips the failures workload.

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

Host conditions are in `timing_host.txt`:

- i9-12900K, 24 logical cores, High performance plan, no affinity pinning;
- CPU load 4% before and 9% after;
- other programs running: Positron, Spotify, GalaxyClient and codex;
- R 4.6.1, ledgr 0.2.2 via pkgload, duckdb 2.0.0, collapse 2.1.8, mirai 2.7.2.

The 3- to 10-bar record fixtures mostly measure fixed per-call cost, so do
not rank them. The scale row is closer to the H6 gap on work that scales
with bars.

## Excluded fields (`records/excluded_fields.csv`)

- **Wall clock:** `created_at_utc` (runs, run_provenance, run_tags),
  `updated_at_utc` (run_telemetry).
- **Wall-clock telemetry:** `elapsed_sec`, and the sweep row's `t_engine`,
  `t_results` and `t_fills_extract`.
- **Version strings:** `engine_version` and `ledgr_version`.
- **Host:** `R_version` and `dependency_versions_json`.
- **Random per call:** `sweep_id` in the sweep attributes, returns and trades.
- **Transport detail:** `staged_invariant_bytes` and `staged_payload_census`.
  These are `object.size()` of worker payloads (`R/sweep.R:1347,1385`), so
  they change with R representation, not with handler output. This was the
  review's optional item; they are now excluded.

The text normalizations `<DB_PATH>` and `<SRCREF>` are described under
Determinism.

## Today's handler agreement (`agreement.csv`, 213 checks, 4 differ)

**Agreements.**

- Run and sweep agree byte for byte on status, final equity, all metrics, the
  equity path, closed trades, stop reason and warning codes.
- The memory sink's events, retained diagnostics, completion and equity facts
  equal the persisted rows.
- `db_live` matches `audit_log`, the resumed run matches the straight run, and
  two workers match one.
- The compiled sweep matches the R sweep on every table, including the memory
  buffers.

**Known differences.**

1. On INCOMPLETE runs the sweep row reports `annualized_return = 0`, while
   `ledgr_compute_metrics()` on the run withholds it (`NA`).
2. A FAILED candidate's sweep `error_msg` names `run_id=bad`, while the run's
   names `run_id=a0-failures-bad`; the class is the same.
3. The memory sink keeps only summary diagnostic rows (for example 7 of 33),
   by design.
4. The compiled path's `execution_assumptions` names `spot_fifo`, as expected.

## Open points for the WS1 cut

1. Two-worker sweeps run the sink in mirai daemons, so only their public
   output is frozen. WS1 should keep the sink observable in-process for the
   `sweep_w1` and `sweep_compiled` paths.
2. Difference 1 is a semantic choice for the unified handler. WS1 must keep
   both values or decide the change explicitly and re-record on `20034e00`.
3. Re-recording is only legitimate on `20034e00`, because the records embed
   the fixture strategy source (`config_json`, `strategy_hash`). The same
   applies to any edit to `fixtures.R`.
4. The harness has dependencies that WS1 must keep available:
   - it runs from a source checkout through pkgload (workers load the source
     tree); `<SRCREF>` assumes rlang adds source references to messages;
   - it uses the internals `ledgr_run_store_open/close` and `ledgr_fold_list`.
5. A finalization failure is not frozen: only a mocked
   `DBI::dbWithTransaction` reaches it. Re-run `timing.R` after WS1 on the
   same host to re-measure H6.

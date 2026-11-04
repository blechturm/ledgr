# A0 closeout: native outputs frozen at the Cut 11 final format

**Answer (green).** The WS25 final-format candidate produces byte-reproducible
outputs through durable and memory paths on eight synthetic workloads.
`records/` holds them (300 files, 634,264 bytes, one SHA-256 each in
`records/manifest.csv`). `check.R` re-runs everything and passes; all registered
corruptions in `guts.R` make it fail and name the table or the missing
observation point. The records remain bounded at about 0.5 MB and the output is
deterministic. `Rscript dev/bench/v0_2_3_output_freeze/check.R` exits 0 on the
candidate. Revision 2 answers `reviews/codex_review_1.md`; revision 3 answers
`reviews/codex_review_2.md`; this WS25 revision records the current codec and
fresh-restart format.

## Workloads

Reasons and fixture sources are in `inventory.md`. Paths:

- `run`: `ledgr_run` per candidate (persistent, `audit_log`); expected
  failures are recorded, not raised.
- `run_failed`: the failed attempt before a restart replaces its output.
- `run_restarted`: the same identity after an atomic restart from pulse one.
- `run_abort`: a refusal through `abort_run`.
- `sweep_w1`/`sweep_w2`: `ledgr_sweep` with one or two workers (memory).
- `sweep_compiled`: the spot-FIFO memory path.
- `walk_forward`: folds, scores and carried test runs.

| Workload | Paths | Record |
| --- | --- | --- |
| dense_cost | run, sweep_w1, sweep_w2, sweep_compiled | 118.2 KB |
| dense_risk_features | run, sweep_w1, sweep_w2 | 83.4 KB |
| dense_dividend_state | run, sweep_w1 | 38.2 KB |
| avail_terminal_resume | run, run_failed, run_restarted, sweep_w1, sweep_w2 | 80.2 KB |
| avail_acquisition | run, sweep_w1 | 37.6 KB |
| avail_incomplete | run, sweep_w1, sweep_w2 | 49.0 KB |
| walk_forward | run, sweep_w1, walk_forward | 164.8 KB |
| failures | run, run_abort, sweep_w1, sweep_w2 | 46.7 KB |

`dense_dividend_state` is failure-sensitive to both parts of its name. Its
day-two target is reachable only when the prior pulse's declared
`observed_cash` update returns through `ctx$state`; the harness then requires
the durable add candidate to contain both a `corporate_action_cash` event and
a fill. An undeclared/broken state carrier or a missing dividend posting stops
the recorder instead of freezing a failed or economically empty workload.

What each path records:

- **Persistent paths:**
  - every run-store table with a `run_id` column (runs, run_provenance,
    run_telemetry, run_completion, the logical `run_diagnostics` trace,
    `run_diagnostic_implicit`, `run_diagnostic_coverage`,
    `run_diagnostic_summary`, ledger_events, equity_curve, run_tags and
    run_promotion_context);
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
- Nested values (list columns, attributes) use a prefix-free encoding.
  Every string is length-prefixed (`<nchar>:<text>`, `~` when missing).
  Every list carries its class, its length and explicit boundaries. Named
  entries (`@<name>`) are marked apart from positional ones (`#`).
  Distinct structures therefore cannot collide. `serialization_probe.R`
  checks 15 such cases, for example `list(a = list(b = 1))` against
  `list("a/b" = 1)`, and `list(1)` against `list("[1]" = 1)`.
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

`record.R` followed by `check.R` on the final code gave byte-identical
manifests (committed manifest SHA-256
`5f1a698744a28d81a4acbcdebd746d240ef34dbe7ff7c55e9ec1714509c31`). The
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
| FILL qty +1 | refuses: diagnostic association evidence is corrupt |
| equity value moved 1 ulp | dense_cost/run/equity_curve |
| one compact diagnostic pair deleted | refuses before logical trace recording |
| two ledger events swapped | refuses: dense_cost diagnostic association evidence is corrupt |
| `runs.error_msg` NULL changed to text 'NA' | avail_terminal_resume/run/runs, error_msg |
| retained sweep equity moved 1 ulp | dense_cost/sweep_w1/sweep_returns row 19 |
| sweep attribute `execution_assumptions$opening` replaced by `opening/<field>` siblings | dense_cost/sweep_w1/sweep_attrs |
| failed attempt persists pulse_count -999 before restart | avail_terminal_resume/run_failed/run_telemetry |
| memory sink: one event_id altered | dense_cost/sweep_w1/memory_events, event_id |
| memory sink: retained diagnostic's detail_json replaced | avail_terminal_resume/sweep_w1/memory_diagnostics |
| memory factory absent, no observer | stops: "no memory-sink observation point" |
| handler warns on each telemetry write in walk-forward | walk_forward/walk_forward/run_conditions |
| failed run: error_msg altered | failures/run/runs, error_msg |
| failed run: exception diagnostic lost | refuses: diagnostic coverage is corrupt |
| failed run: rolled-back fill survives | failures/run/ledger_events |
| FAILED sweep candidate: error_msg altered | failures/sweep_w1/sweep, error_msg |
| failed run status changed to RUNNING | failures/run/runs, status |

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

## Current handler agreement (`agreement.csv`, 204 checks, 2 differ)

**Agreements.**

- Run and sweep agree byte for byte on status, final equity, all metrics, the
  equity path, closed trades, stop reason and warning codes.
- The memory sink's events, retained diagnostics, completion and equity facts
  equal the persisted rows.
- The fresh restart matches the straight run, and two workers match one.
- The compiled sweep matches the R sweep on its public rows and every native
  memory buffer.
- INCOMPLETE annualized return is missing on both durable and sweep paths, the
  accepted WS23 correction.

**Known differences.**

1. A FAILED candidate's sweep `error_msg` names `run_id=bad`, while the run's
   names `run_id=a0-failures-bad`; the class is the same.
2. The compiled path's `execution_assumptions` names `spot_fifo`, as expected.

## Current scope and open points

1. Two-worker sweeps run the sink in mirai daemons, so only their public
   output is frozen. Native sink buffers are observed in-process through
   `sweep_w1` and `sweep_compiled`; the separate worker witness owns native
   daemon evidence.
2. The removed `ledgr_backtest()` entry point is no longer represented by a
   dead `run_db_live` arm. The durable path is `ledgr_run()`; its returned
   handle still exercises durable readers and lifecycle behavior.
3. The dense risk/feature fixture uses the current flat context columns. This
   is why its records and strategy hash are intentionally re-frozen here.
4. The harness still depends on source-checkout capabilities:
   - it runs from a source checkout through pkgload (workers load the source
     tree); `<SRCREF>` assumes rlang adds source references to messages;
   - it uses the internals `ledgr_run_store_open/close` and `ledgr_fold_list`.
5. Finalization-failure recovery is not frozen; only a mocked
   `DBI::dbWithTransaction` reaches it. The registered recovery tests retain
   that ownership.
6. The private rebuild, milestone timing and paired H1 memory gate remain
   outside this public A0 record and keep LDG-3209 open.

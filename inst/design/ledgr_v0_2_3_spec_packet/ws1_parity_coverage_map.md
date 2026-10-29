# WS1 parity coverage map: the handler parity suite after one output handler

**Role:** record; LDG-3131 coverage map for v0.2.3 cut 1.
**Status:** draft, checked by the workstream close review.
**Authority:** `tickets.yml` LDG-3131 and cut decision (5); the design note
`ws1_output_handler_design.md`. Lines cite the tree at the LDG-3131 commit.

## Result in one paragraph

Every test block in the three parity files is inventoried below: 26 blocks
(6, 5 and 15). **No claim is retired.** A claim may be retired only with an
exact replacement that has matching input conditions, and none exists: the
A0 records that come closest use adapted fixtures (for example the A0
`dense_cost` grid adds a final-bar candidate and closed-trade retention that
`test-sweep-persistence-parity.R` does not use), and the parity blocks assert
public run, sweep, promotion and walk-forward surfaces that remain distinct
after WS1, because a committed run and a sweep candidate still publish
through different sinks. The blocks were written against the two old
handlers only through public calls, so none needed a test change in
LDG-3130. Two new blocks close the gaps the cut names: the worker-executed
native-buffer witness (LTB-0519) and a direct event-semantics comparison
between a persisted run and a sweep candidate with nonzero fills (LTB-0520).

Disposition key: **retained** means the block runs unchanged (no assertion or
oracle edit) and keeps its claims. "Cross-sink" marks a block that compares
DuckDB-sink output with memory-sink output.

## `tests/testthat/test-sweep-parity.R`

| Line | Block | Distinct claims | Cross-sink | Disposition |
| --- | --- | --- | --- | --- |
| 203 | sweep candidates match persistent run and promoted run artifacts | sweep row final equity and nine metrics equal the promoted run (1e-10); promoted and direct runs have identical ledger, fills, trades, equity detail and final positions; the persisted ledger replayed through the memory reconstruction (`ledgr_equity_from_events`, `ledgr_fills_from_events`, metrics) equals the persisted equity, fills and metrics; final-bar no-fill warning on `partial`; zero-trade and open-end edges | yes, nonzero fills (`partial`) | retained; the cut's retained cross-sink equivalence test, with LTB-0520 |
| 300 | sweep parity covers opening-position lots and non-default metric context | opening lot realized and unrealized P&L; sweep metric-context hash and risk-free rate; Sharpe differs from the zero-rate metric | yes | retained (metric-context claim) |
| 364 | seeded stochastic sweep promotion reproduces the selected candidate | seeded `runif` candidate reproduces under promotion; promotion context names candidate, execution seed, sweep ID, master seed and final equity | yes | retained (promotion-provenance and reproduction-key claims) |
| 410 | pulse_seed sweep promotion reproduces the selected candidate | `ctx$pulse_seed` candidate reproduces under promotion and direct run | yes | retained (reproduction-key claim) |
| 449 | feature-factory sweep parity covers candidate-varying feature sets and warmup | candidate-specific feature-set hashes; per-candidate feature values equal across sweep and run; SMA warmup NA prefix | yes | retained (feature and warmup claim) |
| 513 | scalar execution config hash remains pinned across sweep parity work | `config_hash` of a fixed config is pinned | no | retained (identity pin, not a handler comparison) |

## `tests/testthat/test-sweep-persistence-parity.R`

| Line | Block | Distinct claims | Cross-sink | Disposition |
| --- | --- | --- | --- | --- |
| 186 | retained series match inline-memory summary on R accounting | retained returns end at the sweep row's final equity and their period returns recompute (1e-12) | no (memory only) | retained (retention claim) |
| 195 | [LTB-0017] retained series match inline-memory summary on compiled spot FIFO | the same on the compiled lane; execution assumptions name `spot_fifo` | no (memory only) | retained |
| 210 | retained series match ordered-event reconstruction on R accounting | retained returns equal the committed run's equity and the ordered-event reconstruction of its ledger (1e-12), every candidate | yes | retained |
| 221 | [LTB-0014] retained series match ordered-event reconstruction on compiled spot FIFO | compiled sweep retained returns equal the canonical run's reconstruction for `partial` and `open_end` | yes | retained |
| 244 | retained-series parity matrix covers final-bar and failed-candidate edges | final-bar warning; FAILED candidate has no retained series and its returns read is refused | no | retained (retention and failure claims) |

## `tests/testthat/test-availability-parity.R`

| Line | Block | Distinct claims | Cross-sink | Disposition |
| --- | --- | --- | --- | --- |
| 41 | [LTB-0064] incomplete completion evidence matches persisted record | INCOMPLETE completion fields across `ledgr_run_info`, `ledgr_run_completion`, inventory, compare, summary and print; rerun of a terminal run replays nothing; reopen equality | no (DuckDB) | retained |
| 204 | completion affected IDs come only from stopped diagnostics | affected IDs derive from stopped diagnostic rows only | no | retained |
| 276 | terminal completion recovers projections without strategy replay | mocked `DBI::dbWithTransaction` finalization failure leaves FAILED with INCOMPLETE completion evidence; the rerun recovers projections without calling the strategy | no | retained (recovery claim, in-process) |
| 347 | complete availability runs recover finalization without strategy replay | the same for an intended DONE completion | no | retained (recovery claim, in-process) |
| 406 | malformed terminal completion evidence fails closed | tampered completion refuses | no | retained |
| 429 | terminal completion validation rejects invalid incomplete bounds | validator rejects bad bounds | no | retained |
| 477 | achieved incomplete shortcuts require their finalized prefix | a tampered prefix refuses the shortcut without strategy replay | no | retained |
| 511 | availability completion propagates through sweep persistence | INCOMPLETE status and completion survive save and reopen; retained returns readable | no (memory) | retained (retention claim) |
| 554 | parallel availability sweeps return the same compact terminal evidence | workers 1 and 2 give identical status, completion and candidate IDs; equal to the direct run's terminal evidence | yes | retained; public surfaces only, so LTB-0519 now supplies the worker native-buffer evidence |
| 585 | direct and sweep paths both apply the opening-time status cutoff | the opening-time status cutoff leaves no fill on the run path and zero trades on the sweep row, with matching equity | yes | retained |
| 637 | [LTB-0063] explanation history is durable read-only evidence | explain-history rows, completion and read-only behavior | no | retained |
| 822 | [LTB-0065] dense runs expose typed absent completion evidence | dense completion is typed-absent; no diagnostics | no | retained |
| 860 | walk-forward stops a carry-state chain on incomplete test evidence | PARTIAL walk-forward on an INCOMPLETE test run | yes (train sweep, test run) | retained |
| 915 | [LTB-0024] walk-forward hydrates heterogeneous gaps on the session calendar | direct run, sweep and walk-forward all complete DONE on a gapped session calendar; the second test window opens with the first window's cash, positions and FIFO cost basis | yes (train sweep, test runs) | retained |
| 1037 | [LTB-0069] walk-forward preserves incomplete status when prefix metrics fail | INCOMPLETE score row keeps its completion when metrics fail | no | retained |

## Claims the cut requires to stay covered

| Claim | Covered by |
| --- | --- |
| promotion provenance | test-sweep-parity.R:364 (and :203, :410, :449 promotions) |
| reproduction key | test-sweep-parity.R:364, :410 |
| non-default metric context | test-sweep-parity.R:300 |
| candidate-varying features and warmup | test-sweep-parity.R:449 |
| retention | test-sweep-persistence-parity.R:186, :195, :244; test-availability-parity.R:511 |
| recovery | test-availability-parity.R:276, :347 (finalization failure through mocked `DBI::dbWithTransaction`, in-process) |
| event-buffer growth | test-ledger-writer.R "both event handlers preserve rows across two injected growth boundaries" (in-process, not a worker witness), now constructing both sinks of the one handler; LTB-0521 for the typed stores |

## Worker native-buffer witness

`tests/testthat/test-output-handler-sinks.R`, **[LTB-0519] a worker-executed
memory sink delivers the in-process native surfaces** (review profile).

- **Worker execution:** `ledgr_sweep(..., workers = 2L)`, ledgr's own mirai
  path. The test wraps `ledgr_parallel_ledgr_load_expr()` so each worker, after
  loading ledgr, installs an observer around `ledgr_output_handler()`; every
  memory-sink handler saves its native surfaces to a test directory when the
  sweep asks for its inline summary. The saved process IDs differ from the
  test process.
- **Same declared inputs in-process:** the identical observer, experiment
  (availability fixture, 4 sessions with a gap, fixed fee) and grid run through
  a one-worker sweep in the test process.
- **Asserted surfaces, per candidate:** the typed event table with all five
  `ledgr_event_*` attributes (identical), the retained diagnostics and their
  `diagnostic_seq` (identical), and the completion (identical); public status
  and `completion_json` also agree. The inputs carry nonzero fills, retained
  stopped diagnostics and INCOMPLETE completion evidence, asserted in the test.
- **Event-ID corruption demonstration:** a third, two-worker run alters the
  first buffered event ID inside each worker. Status, `completion_json` and
  final equity stay identical to the sequential sweep, while the native event
  table differs from the in-process one, so the witness's event comparison
  fails; the test asserts both facts.
- A skip (covr, missing `mirai`, coverage workers) is missing evidence for
  this cut.

## Cross-sink event semantics

`tests/testthat/test-output-handler-sinks.R`, **[LTB-0520] a persisted run and
a sweep candidate publish the same fill events**: for both candidates, the
committed run's persisted ledger and the in-process memory sink's native
events agree on row count, event type, instrument, side, quantity, price,
fee, sequence and timestamp, and every fill's typed cash and position deltas
equal the persisted `meta_json` deltas. Both candidates have nonzero fills.

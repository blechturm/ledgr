# WS1 design note: one output handler, sink boundary and the R3 sentence

Role: record; the LDG-3128 design note for v0.2.3 cut 1, workstream 1.
Status: draft, written by the implementer before any handler change; it
directs LDG-3129 to LDG-3131 and is checked by the workstream close review.
Authority: `tickets.yml` cut 1 (decisions (1) to (7)) and LDG-3128 scope;
`contracts.md` rule groups `contract-execution-fold-core` and
`contract-execution-accounting-events`; fold-phase synthesis Sections 5.6
and 11. Source lines cite `release/v0.2.3` at `07dbbc87`.

## 1. The shape in one paragraph

One constructor, `ledgr_output_handler(sink, .event_initial_capacity = 1024L)`,
owns every mechanism both handlers duplicate today: the event column buffer,
pulse fill staging, capacity growth, status and completion bookkeeping, and
diagnostic numbering. Two sink constructors own only what differs by storage:
`ledgr_output_sink_duckdb(con, run_id, run_wall_start, execution_mode)` (the
`audit_log` and `db_live` stores) and `ledgr_output_sink_memory(run_id)`. The
handler exposes, per sink kind, exactly the method names that kind's handler
exposes today (21 for DuckDB, 27 for memory), so every `is.function()` guard
and the compiled dispatch guard see the same capabilities as before.
`ledgr_persistent_output_handler` and `ledgr_memory_output_handler` are
deleted with no alias.

## 2. Constructors and storage-mode selection

| Mode | Constructed by | Call | Fold `event_mode` |
| --- | --- | --- | --- |
| DuckDB `audit_log` | `ledgr_run()` / `ledgr_backtest()` via the runner (`R/backtest-runner.R:793`) | `ledgr_output_handler(ledgr_output_sink_duckdb(con, run_id, run_wall_start, "audit_log"))` | `"buffered"` |
| DuckDB `db_live` | same site, `execution_mode = "db_live"` | `ledgr_output_handler(ledgr_output_sink_duckdb(con, run_id, run_wall_start, "db_live"))` | `"live"` |
| memory | `ledgr_sweep_candidate_execution()` (`R/sweep.R:1706`), used by the sweep, walk-forward train sweeps and pulse inspection | `ledgr_output_handler(ledgr_output_sink_memory(run_id))` | `"buffered"` |

- The sink carries `run_id`; the handler reads it from the sink.
- The mode is selected where it is today: the runner maps `execution_mode`
  to the fold's `event_mode` (`R/backtest-runner.R:1377`), and the fold's
  existing `identical(services$event_mode, "live")` branches choose the
  immediate fill and strategy-state writes. The handler never reads a mode
  string. No execution-mode branch is added to fold, run, sweep or
  walk-forward code.
- Composition happens once, at construction: the sink declares its kind and
  capabilities; the handler attaches the matching method closures.
- Classes: the handler is `ledgr_output_handler`; the sinks are
  `ledgr_output_sink_duckdb` and `ledgr_output_sink_memory`. No code tests
  the old handler classes (checked by `grep` over `R/`, `tests/`, A0 and the
  peer benchmark).

## 3. Shared handler logic (one implementation each)

| Mechanism | Owner | Behaviour preserved from both handlers |
| --- | --- | --- |
| Event column buffer | `ledgr_output_handler` | One environment of typed columns: the 11 ledger columns, plus the typed columns the sink declares (memory: `cash_delta`, `position_delta`, `event_realized`, `event_cost_basis`, `meta`; DuckDB: none). Appends write by index with `ledgr_event_buffer_setv()` / `ledgr_event_buffer_write_rows()`. `buffer_event()` is the unstaged append path; production code has no caller, registered tests drive it. A DuckDB sink drains the buffer on `flush_pending()`; a memory sink retains it and reads it through `events()` / `typed_events()`. |
| Pulse fill staging | `ledgr_output_handler` | Closure-local `pulse_fill_rows[[i]] <<- entry` (LTB-0188). Entry = the payload row; for a sink with typed columns also its typed values. `flush_pulse_events()` writes the staged block by index, then calls the sink's leg flush when the sink has the accounting projection. |
| Capacity growth | `ledgr_output_handler` | `ledgr_event_buffer_initial_capacity()` / `ledgr_event_buffer_next_capacity()` unchanged. `init_buffers(max_events)` sets the cap to buffered rows plus `max_events`, allocates `min(cap, initial)` for an empty buffer (today's DuckDB result) or grows from the retained rows (today's memory result), and resets staging. |
| Status and completion bookkeeping | `ledgr_output_handler` | `record_run_status()` records status, message and the terminal flag, then calls the sink's status write when it has one. `record_failure()` and `abort_run()` are shared; `abort_run()` keeps its non-strict FAILED telemetry attempt, which the memory sink's telemetry discard makes a no-op exactly as today. `write_run_evidence()` keeps the completion, then hands it to the sink's completion persistence when present. |
| Diagnostic numbering | `ledgr_output_handler` | `diagnostic_seq` is assigned by `seq.int(next, length.out = n)` and `next` advances by `n` for every written block, kept or not. The first `next` comes from the sink's seed (DuckDB: `MAX(diagnostic_seq) + 1` through `ledgr_next_diagnostic_seq()`, lazily; memory: 1). The exception diagnostic takes the sink's post-failure seed when the sink declares one (DuckDB re-reads after the rolled-back transaction), otherwise `next`. |

## 4. Sink capabilities

"Required" methods are called without a guard and exist on every handler;
a sink states a policy for them (persist, retain or discard). "Optional"
capabilities are tested with `is.function()` (or by the compiled guard) and
are **absent** where unsupported, never a callable no-op.

**Failure rule.** Every method lets an error propagate unchanged. The only
catches are the ones that exist today and stay where they are: non-strict
`write_telemetry()` returns `invisible(FALSE)` instead of raising; `abort_run()`
wraps its FAILED telemetry write in `try(silent = TRUE)` before raising its own
condition; DuckDB `run_transaction()` rolls back on an error or interrupt and
re-raises an interrupt that `DBI::dbWithTransaction()` would otherwise
swallow. Warnings propagate as warnings and roll nothing back. (The fold's own `try()` around `write_exception_diagnostic()` is
fold code and unchanged.) Buffer writes keep raising
`ledgr_event_buffer_capacity_exceeded` past the cap and `ledgr_invalid_state`
for out-of-range writes.

| Capability | DuckDB sink | Memory sink |
| --- | --- | --- |
| Transaction and interrupt re-raise (required: `run_transaction`) | Exists. `DBI::dbWithTransaction()` around `fn()`, re-raises an interrupt after the rollback; returns `fn()`'s value. | Policy: no transaction; returns `fn()`. |
| Run status and completion persistence (required: `record_run_status`, `write_run_evidence`) | Exists. `UPDATE runs`; `DELETE` + append `run_completion`. | Policy: retained in bookkeeping only; `completion()` returns it. |
| Terminal-status query (optional: `terminal_status_written`) | Exists. | Absent (as today). |
| Durable append (required: `append_event_rows`, `flush_pending`, `pending_event_count`, `pending_state_count`) | Exists. `append_event_rows()` appends to `ledger_events` at once; `flush_pending()` drains the buffer, then the staged states. | Policy: retain into the shared buffer; counts are `0L`, so the fold never calls `flush_pending()`. |
| `db_live` immediate write (required: `write_fill_events(..., use_transaction = TRUE)`, `write_strategy_state`) | Exists. `ledgr_write_fill_events(use_transaction = FALSE)` inside the fold transaction; `INSERT` into `strategy_state`. | Not reachable (the sweep is buffered): `use_transaction` is ignored as today and `write_strategy_state` discards. |
| Diagnostic seeding and post-failure refresh | Exists (seed by query; refresh for the exception row). | Seed 1; no refresh. |
| Diagnostic retention (required: `write_run_diagnostics`, `write_exception_diagnostic`) | Keep all: append to `run_diagnostics`. | Keep summary rows only (`keep_summary_rows()` predicate unchanged). |
| Telemetry (required: `write_telemetry`, `store_session_telemetry`; DuckDB-only `set_schedule_counts`) | Exists. | Policy: discard; `set_schedule_counts` absent (as today). |
| Strategy-state persistence (required: `buffer_strategy_state`) | Exists; drained by `flush_pending()`. | Policy: discard. |
| Inline accounting and equity projections (optional: `record_accounting_fact`, `record_equity_fact`, `inline_summary`) | Absent (as today; the fold guards at `R/fold-engine.R:584`, `:1370`). | Exists. |
| Typed events (optional: `typed_events`; memory-only `events`, `diagnostics`, `completion`) | Absent (as today). | Exists. |
| Compiled spot batch (optional: `append_compiled_spot_batch`) | **Absent.** | Exists. |

### 4.1 Return and side effect of every method

"Absent" means no binding in the handler list. Returns are today's.

| Method | DuckDB handler | Memory handler |
| --- | --- | --- |
| `run_transaction(fn)` | Returns `fn()`'s value; commits on success. | Returns `fn()`'s value. |
| `record_run_status(status, error_msg)` | Sets bookkeeping (terminal flag for FAILED, DONE, INCOMPLETE), `UPDATE runs`; `invisible(TRUE)`. | Sets bookkeeping; `invisible(TRUE)`. |
| `terminal_status_written()` | `TRUE` once a terminal status was recorded, else `FALSE`. | Absent. |
| `set_schedule_counts(d, s)` | Stores both as integers for telemetry; `invisible(TRUE)`. | Absent. |
| `write_telemetry(status, strict, telemetry, processed)` | `INSERT OR REPLACE run_telemetry`; `invisible(TRUE)` on success; on a DB error `strict = TRUE` aborts with `ledgr_run_telemetry_failed` (parent attached), `strict = FALSE` returns `invisible(FALSE)`. | Discards; `invisible(TRUE)`. |
| `store_session_telemetry(telemetry)` | Assigns into the session telemetry registry; `invisible(TRUE)`. | Discards; `invisible(TRUE)`. |
| `record_failure(msg)` | `record_run_status("FAILED", msg)`; `invisible(TRUE)`. | Same; `invisible(TRUE)`. |
| `abort_run(msg, class)` | Records the failure, tries a non-strict FAILED telemetry write, then raises `msg` with `class`; never returns. | Records the failure, then raises; never returns. |
| `init_buffers(max_events)` | Allocates `min(max_events, initial)` rows, resets staging and staged states; `invisible(TRUE)`. | Raises the cap to retained rows plus `max_events`, ensures room for one more row, resets staging; `invisible(TRUE)`. |
| `buffer_event(write_res)` | Non-WROTE: `invisible(FALSE)`, nothing written. WROTE before `init_buffers()`: aborts `ledgr_invalid_state`. Otherwise appends the row; `invisible(TRUE)`. | Appends a WROTE row with its typed values; returns `invisible(TRUE)` for every input. |
| `flush_pulse_events()` | Writes the staged rows into the buffer by index, clears staging; `invisible(TRUE)` (also when nothing is staged). | Writes staged rows and typed values, then staged legs into the inline fills, clears both; `invisible(TRUE)`. |
| `pending_event_count()` | Buffered row count (integer). | `0L`. |
| `pending_state_count()` | Staged strategy-state count (integer). | `0L`. |
| `write_run_diagnostics(d)` | NULL or zero rows: nothing; otherwise numbers and appends; `invisible(TRUE)`. | NULL or zero rows: nothing; otherwise numbers and retains summary rows; `invisible(TRUE)`. |
| `write_run_evidence(completion, d)` | Replaces the run's `run_completion` row, then `write_run_diagnostics(d)`; `invisible(TRUE)`. | Stores the completion, then `write_run_diagnostics(d)`; `invisible(TRUE)`. |
| `write_exception_diagnostic(row)` | Numbers it from a fresh `MAX + 1`, appends; `invisible(TRUE)`. | Numbers it `next`, retains it if a summary row; `invisible(TRUE)`. |
| `buffer_strategy_state(ts, json)` | Stages the state row; `invisible(TRUE)`. | Discards; `invisible(TRUE)`. |
| `write_strategy_state(ts, json)` | `INSERT` into `strategy_state`; `invisible(TRUE)`. | Discards; `invisible(TRUE)`. |
| `write_fill_events(fill, seq, use_transaction)` | `TRUE`: returns `ledgr_write_fill_events()`'s result (WROTE without `row`, or NO_OP), stages nothing. `FALSE`: returns the payload result (`serialize_meta_json = TRUE`) and stages it when WROTE; NO_OP returned unstaged. | Ignores `use_transaction` (also when `TRUE`); returns the payload result (`serialize_meta_json = FALSE`) and stages it with its typed values when WROTE; NO_OP returned unstaged. |
| `append_event_rows(rows)` | NULL or zero rows: nothing; otherwise appends to `ledger_events`; `invisible(TRUE)`. | NULL or zero rows: nothing; otherwise appends into the buffer with typed values parsed from each row's `meta_json` (realized and cost basis `NA`); `invisible(TRUE)`. |
| `flush_pending()` | Appends the buffered rows as one frame and resets the count, then appends the staged states and resets them; `invisible(TRUE)`. | Writes nothing; `invisible(TRUE)`. |
| `append_compiled_spot_batch(batch)` | Absent. | Empty batch: nothing; otherwise appends the batch's columns and typed deltas into the buffer and its fill legs into the inline fills; `invisible(TRUE)` in both cases. |
| `record_accounting_fact(write_res, lot_res, lot_state)` | Absent. | `invisible(FALSE)` when `write_res` is not a WROTE `ledgr_ledger_write_result` or when neither a staged nor a buffered event exists. Otherwise sets realized P&L and cost basis on the latest staged entry (or, with nothing staged, on the last buffered event), then the close leg if `close_qty > 0`, then the open leg if `open_qty > 0`, each with its `ledgr_fill_leg_fees()` share (staged, or added to the inline fills directly); `invisible(TRUE)`. |
| `record_equity_fact(ts, cash, positions_value, realized_pnl, cost_basis)` | Absent. | Stores one fact; `invisible(TRUE)`. |
| `inline_summary(run_id, metric_kernel)` | Absent. | `list(equity, fills, metrics, final_equity)`; with no equity facts `equity` is the empty equity curve and `final_equity = NA_real_`, otherwise the last row's equity. |
| `completion()` | Absent. | The stored completion, or `NULL` when none was written (dense mode). |
| `diagnostics()` | Absent. | `NULL` when nothing was written or nothing was kept; otherwise the kept rows bound in emission order. |
| `typed_events()` | Absent. | No buffered event: `ledgr_empty_event_table()`, with no memory attributes or class. Otherwise a tibble of class `ledgr_memory_events` with the five `ledgr_event_*` attributes and `meta_json` as stored (NA for fills). |
| `events()` | Absent. | As `typed_events()`, with each missing `meta_json` serialized from the stored `meta` (or from the typed columns when `meta` is NULL). |

Each handler's method set equals today's set for its kind; LDG-3130 adds a
witness test comparing `sort(names(handler))` per sink with the frozen lists
in Section 5.

## 5. Method map (every method of both handlers, one row each)

P = `ledgr_persistent_output_handler` (21), M = `ledgr_memory_output_handler`
(27). 19 names are shared.

| Method | Today | New owner |
| --- | --- | --- |
| `run_transaction` | P, M | Sink capability: transaction (memory policy: direct call) |
| `record_run_status` | P, M | Shared: status bookkeeping + sink status persistence |
| `terminal_status_written` | P | Shared bookkeeping flag; attached for DuckDB only |
| `set_schedule_counts` | P | Sink capability: telemetry (DuckDB) |
| `write_telemetry` | P, M | Sink capability: telemetry (memory policy: discard) |
| `store_session_telemetry` | P, M | Sink capability: telemetry (memory policy: discard) |
| `record_failure` | P, M | Shared: status bookkeeping |
| `abort_run` | P, M | Shared: status bookkeeping (+ telemetry attempt) |
| `init_buffers` | P, M | Shared: capacity growth and staging reset |
| `buffer_event` | P, M | Shared: event column buffer |
| `flush_pulse_events` | P, M | Shared: pulse fill staging (+ memory leg flush) |
| `pending_event_count` | P, M | Sink capability: durable append (memory: 0) |
| `pending_state_count` | P, M | Sink capability: strategy-state persistence (memory: 0) |
| `write_run_diagnostics` | P, M | Shared: diagnostic numbering + sink retention |
| `write_run_evidence` | P, M | Shared: completion bookkeeping + sink persistence + numbering |
| `write_exception_diagnostic` | P, M | Shared: numbering with sink refresh + sink retention |
| `buffer_strategy_state` | P, M | Sink capability: strategy-state persistence (memory: discard) |
| `write_fill_events` | P, M | Shared staging for buffered fills (payload + stage); sink capability `db_live` immediate write for `use_transaction = TRUE` |
| `append_event_rows` | P, M | Sink capability: durable append (memory: retain into the shared buffer) |
| `write_strategy_state` | P, M | Sink capability: `db_live` immediate write (memory: discard) |
| `flush_pending` | P, M | Sink capability: durable append drain (memory: retain) |
| `append_compiled_spot_batch` | M | Sink capability: compiled spot batch (writes the shared buffer) |
| `record_accounting_fact` | M | Sink capability: inline accounting projection (updates the shared staged entry) |
| `record_equity_fact` | M | Sink capability: inline equity projection |
| `inline_summary` | M | Sink capability: inline projections |
| `completion` | M | Shared bookkeeping read; attached for memory only |
| `diagnostics` | M | Sink capability: diagnostic retention read |
| `typed_events` | M | Sink capability: typed events (reads the shared buffer) |
| `events` | M | Sink capability: typed events with `meta_json` (reads the shared buffer) |

## 6. Consumer map

| Consumer | Uses | After WS1 |
| --- | --- | --- |
| Fold (`ledgr_execute_fold()`, stage functions, `ledgr_finalize_fold_telemetry()`, `R/fold-engine.R`) | 17 members: required calls plus guarded `record_equity_fact`, `record_accounting_fact`, `flush_pulse_events`, `write_exception_diagnostic`, direct `append_compiled_spot_batch` after the guard | Unchanged code; same names and guards. |
| `ledgr_run` (runner, registration `R/run-registration.R:166`, resume `R/run-resume.R:17`, finalize `R/run-finalize.R:556-587`, exit guard `R/backtest-runner.R:680`) | DuckDB handler: status, failure, abort, telemetry, schedule counts, terminal flag | One constructor call changes (`:793`); the rest call the same names. |
| `ledgr_sweep` (`ledgr_sweep_candidate_execution()`, `ledgr_sweep_run_candidate()`, `R/sweep.R:1706-1920`) | Memory handler: `append_event_rows`; guarded `inline_summary`, `typed_events`; direct `completion`, `diagnostics` | One constructor call changes (`:1706`). |
| Walk-forward (`R/walk-forward*.R`) | No direct handler use: train sweeps through `ledgr_sweep_window()`, test runs through `ledgr_run_window()` | No change. |
| `ledgr_require_compiled_spot_fifo_dispatch()` (`R/compiled-spot-fifo.R:54-83`) | Refuses unless `is.function(output_handler$append_compiled_spot_batch)` | Unchanged. Admits the memory handler; refuses DuckDB handlers because the method is absent; live mode is refused earlier by `event_mode`. |
| Pulse inspection (`R/pulse-snapshot.R:517-523`, additional) | Memory handler via `ledgr_sweep_candidate_execution()`; `completion()` | No change. |
| Event posters (`R/corporate-action-settlement.R:603`, `R/terminal-outcomes.R:215`, `R/availability-diagnostic-writer.R:138`, additional) | `append_event_rows`, `write_run_diagnostics` | No change. |
| Tests | 38 direct constructor calls (14 `test-ledger-writer.R`, 9 `test-risk-fold.R`, 7 `test-sweep.R`, 6 `test-execution-spec.R`, 2 `test-research-cycle-scale.R`); factory captures and mocks (`test-risk-fold.R:412-458`, `test-availability-economics.R:1066-1086`, `test-corporate-action-recovery.R:157-160`); source assertions (`test-ledger-writer.R:207`, `:293-307`, `test-corporate-action-recovery.R:202-207`); export pin (`test-api-exports.R:199`); hand-built list handlers (`test-execution-spec.R:513`, `test-corporate-action-disposition.R:118`) | Migrated within decision (5); Section 9. |
| A0 harness (`dev/bench/v0_2_3_output_freeze/`) | Memory observer, memory-state adapter, two persistent patches | Attachment points only, decision (1); Section 8. |
| Active peer benchmark (`dev/bench/peer_benchmark/peer_benchmark.R:702-743`) | Memory handler; `typed_events()` | Constructor call becomes `ledgr:::ledgr_output_handler(ledgr:::ledgr_output_sink_memory(run_id))`. |

## 7. Compiled dispatch

The guard is not edited. A DuckDB handler has no `append_compiled_spot_batch`
binding at all (not NULL-valued, not a stub), so the guard raises
`ledgr_compiled_spot_fifo_unavailable` with its existing memory-handler
message. LDG-3130 adds the negative test: a buffered DuckDB handler with
`compiled_accounting_model = "spot_fifo"` is refused; the existing memory
admission tests (`test-execution-spec.R:216`, `:345`), the live-mode refusal
(`:503-511`) and the empty-handler refusal (`:513-519`) stay.

## 8. A0 attachment points (decision (1))

| Attachment | Today | After WS1 |
| --- | --- | --- |
| Memory observer `a0_observe_memory()` (`lib.R:357-386`) | Patches `ledgr_memory_output_handler(run_id, ...)` and registers each handler by run ID | `a0_memory_factory <- "ledgr_output_handler"`; the wrapper takes `(sink, ...)`, and registers by `sink$run_id` only when `inherits(sink, "ledgr_output_sink_memory")`. The `gut$memory_factory` override and its stop message are unchanged, so `memory_observer_missing` still fails. |
| Memory-state adapter `a0_sink_state()` (`guts.R:11`) | `get("state", environment(handler$events))` | Returns an environment with active bindings `event_cols` (the handler's buffer columns) and `diagnostic_parts`, `diagnostic_part_n` (the memory sink's retention), read and write. `memory_event` and `memory_diagnostic` keep their code and injected change. |
| `interrupted_telemetry`, `wf_warning` (`guts.R:74-82`, `:107-116`) | Patch `ledgr_persistent_output_handler` | Patch key `ledgr_output_handler`; the wrapper applies the same `write_telemetry` override only when the sink inherits `ledgr_output_sink_duckdb`. |

Records, canonicalization, fixtures, expected tables and messages, the
control and the 17 identities do not change. LDG-3130 shows each corruption
reaching and altering its raw surface (gut.R's named-difference check).

## 9. Test migration (decision (5))

- Constructor calls: `ledgr_persistent_output_handler(con = c, run_id = r, run_wall_start = w, execution_mode = m, .event_initial_capacity = k)` becomes `ledgr_output_handler(ledgr_output_sink_duckdb(c, r, w, m), .event_initial_capacity = k)`; `ledgr_memory_output_handler(r, .event_initial_capacity = k)` becomes `ledgr_output_handler(ledgr_output_sink_memory(r), .event_initial_capacity = k)`.
- Factory captures and mocks bind `ledgr_output_handler` with the same wrapper bodies and fault locations; the capacity mock keeps `.event_initial_capacity = 2L`.
- Structural assertions inspect the new owner with the same predicate:
  - LTB-0188 row staging (`state\$pulse_fill_rows` forbidden, `pulse_fill_rows\[\[i\]\] <<-` required): `ledgr_output_handler`;
  - LTB-0188 leg staging (`state\$pulse_fill_legs` forbidden, `pulse_fill_legs\[\[i\]\] <<-` required): `ledgr_output_sink_memory`;
  - `MAX\(diagnostic_seq\)` forbidden (`test-ledger-writer.R:207`): `ledgr_output_handler` and `ledgr_output_sink_duckdb` (the query stays in `ledgr_next_diagnostic_seq()`);
  - transaction or recovery tokens forbidden in the memory owner (`test-corporate-action-recovery.R:202-207`): `ledgr_output_handler` and `ledgr_output_sink_memory`. Neither may therefore contain `begin_transaction`, `commit_transaction`, `rollback` or `reopen` anywhere in its deparsed source, comments included under `load_all()`; the post-failure seed refresh and the transaction wrapper live in the DuckDB sink.
  - Each relocated assertion is shown failing on its own predicate's violation, as decision (5) lists.
- Export pin: `ledgr_output_handler`, `ledgr_output_sink_duckdb` and `ledgr_output_sink_memory` are not exported.
- Hand-built list handlers are untouched.

## 10. R3: one publication delta computation

**Computation.** New `ledgr_fill_publication_deltas(side, qty, fill_price, fee)`
in `R/ledger-writer.R` returns `list(cash_delta, position_delta)` with
today's arithmetic and operation order (`R/backtest-runner.R:132-137`,
`R/ledger-writer.R:66-71`, which agree): BUY `-(qty * price + fee)`, SELL
`+(qty * price - fee)`, position delta `+qty` or `-qty`, all `as.numeric`.

**Consumers.** `ledgr_fill_event_payload()` (buffered DuckDB fills and,
through the handler's buffered `write_fill_events`, memory fills) and
`ledgr_write_fill_events()` (`db_live`). The memory path consumes it only
through the payload; nothing computes a second publication delta for the same
fill. Each keeps its validation, NO_OP short circuit, event-sequence choice
and transaction behaviour in place.

**Scope boundary (unchanged arithmetic).** Planner affordability
`ledgr_availability_fill_cash_delta()` (`R/availability-economics.R:326-332`),
fold state cash (`R/fold-engine.R:1383-1393`) and the compiled batch's typed
deltas (`ledgr_cpp_spot_fifo_batch`) are economic computations of the fold
and planner, outside this obligation. Projections of stored values (the
memory sink's typed values parsed from a non-fill row's `meta_json`, and its
`meta_json` fallback from typed columns) compute nothing new.

**Leg fees.** `ledgr_fill_leg_fees(fee, close_qty, open_qty)`
(`R/lot-accounting.R:124-138`) is the named projection of the resolved fee
over the lot result's close and open quantities. It is unchanged, called
where it is called today, in the same order.

**Contract sentence.** The code cannot satisfy the existing clause by letter,
because handlers call the payload builder. LDG-3129 replaces the first bullet
of `contract-execution-accounting-events` with:

> Cost resolution belongs inside the fold before any output handler sees
> events. Output handlers must not resolve, reinterpret, or rewrite fill
> prices, fees, cash deltas, or cost metadata. When a handler materializes a
> fill row from a resolved fill intent on the canonical R path, the row's cash
> and position deltas come only from the one publication computation,
> `ledgr_fill_publication_deltas()`, applied to the fill's resolved side,
> quantity, price and fee. On that path a resolved fee is split across the
> fill's close and open legs only by `ledgr_fill_leg_fees()`. These are row
> projections of the resolved fill, not a second economic computation.
> Compiled spot-FIFO batches supply the fold's already computed typed deltas
> and leg fees, which the handler publishes unchanged; this clarification
> changes neither compiled arithmetic nor its parity obligations against
> canonical R.

LDG-3129 closes only the R3 part of the `fold-execution-phase-ownership`
pipeline row.

## 11. Identity and release impact (decision (3))

Snapshot content identity: none. Run configuration identity: none. Store
format fingerprint: none (`ledgr_store_format_bindings()` compared on the
base and final commits). Release impact: product tests and performance
records; one NEWS line; no taught behaviour, documentation or dependency
change.

## 12. Moved code and the seven shapes

The handler adds no loop over events, fills, diagnostics or pulses. Moving
code into sinks exposes three existing instances, which LDG-3130 repairs
because the close review walks the shapes over every moved helper. Each
repair keeps the produced frames byte-identical (A0 `memory_equity`,
`memory_diagnostics`, `strategy_state` tables are the witnesses):

- DuckDB `buffer_strategy_state()` builds one data frame per pulse and binds
  them at flush (shape 1). It becomes two typed character columns written by
  index, manifested once at flush.
- Memory `record_equity_fact()` grows an environment-held list per pulse
  (shape 7) and `inline_summary()` re-reads it with five `vapply()` passes. It
  becomes five typed columns with doubling growth, read directly.
- Memory diagnostic retention grows an environment-held list of kept chunks
  (shape 7). It becomes a closure-local list written with `<<-`, like pulse
  staging.

When LDG-3130 implements these repairs, its tests drive each typed buffer
(strategy states and equity facts) past its initial capacity and compare
values, classes and row order across the growth boundary with today's
output.

Left as recorded debt, not multiplied: the per-row `meta_json` parse in
memory `append_event_rows()` (opening and corporate-action rows only) and the
per-event `meta_json` serialization in `events()` (A0 and tests; the sweep
reads `inline_summary()`).

## 13. Checks LDG-3130 must make while implementing

- `buffer_event()` returns `invisible(FALSE)` for a non-WROTE result on
  DuckDB and `invisible(TRUE)` on memory today; keep each sink's return.
- DuckDB `buffer_event()` before `init_buffers()` raises
  `ledgr_invalid_state`; memory appends opening rows before `init_buffers()`.
  The shared buffer keeps both behaviours (sink flag).
- Allocation-bound tests (`test-ledger-writer.R:559-626`,
  `test-availability-economics.R:1066-1086`) must observe today's capacities.
- `ledgr_write_fill_events()` uses `canonical_json()` and the payload
  `ledgr_canonical_json_encode()`; the bytes agree and stay as they are.

## 14. Implementation notes (LDG-3130)

Recorded where the implementation chose among options this note left open:

- The handler composes its methods from sink flags set once at construction
  (`drains`, `requires_init`, `typed_columns`, `serialize_meta_json`,
  `refresh_seq_on_exception`, `nonwrote_buffer_result`); no mode string is
  read and no fold, run or sweep code changed.
- `init_buffers()` keeps the DuckDB argument check exact (`max_events` itself,
  not a coerced sum) and allocates through `ledgr_event_buffer_next_capacity()`
  from an empty buffer, which yields today's `min(max_events, initial)`.
- The memory handler's `abort_run()` now calls its discard `write_telemetry()`
  inside the same `try()` as the DuckDB handler; the discard makes it a no-op.
  The memory bookkeeping also records the terminal flag, which only the DuckDB
  handler exposes.
- The three Section 12 repairs are implemented and exercised past their
  growth boundaries by LTB-0521.
- The maintainer manual's sweep article names the new constructors.


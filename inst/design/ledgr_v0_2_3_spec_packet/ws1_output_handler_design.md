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

| Capability | DuckDB sink | Memory sink |
| --- | --- | --- |
| Transaction and interrupt re-raise (required: `run_transaction`) | Exists. `DBI::dbWithTransaction()` around `fn()`, re-raises an interrupt after the rollback; returns `fn()`'s value; an error rolls back and propagates. | Policy: no transaction; returns `fn()`; errors propagate. |
| Run status and completion persistence (required: `record_run_status`, `write_run_evidence`) | Exists. `UPDATE runs`; `DELETE` + append `run_completion`; DB errors propagate. | Policy: retained in bookkeeping only; `completion()` returns it (NULL in dense mode). |
| Terminal-status query (optional: `terminal_status_written`) | Exists; returns the bookkeeping flag; no side effect. | Absent (as today). |
| Durable append (required: `append_event_rows`, `flush_pending`, `pending_event_count`, `pending_state_count`) | Exists. `append_event_rows()` appends to `ledger_events` at once; `flush_pending()` drains the buffer and staged states, returns `invisible(TRUE)`; counts are the pending rows. | Policy: retain. `append_event_rows()` appends into the buffer and derives typed values from each row's `meta_json`; counts return `0L`, so the fold never calls `flush_pending()`, which returns `invisible(TRUE)` and writes nothing. |
| `db_live` immediate write (required: `write_fill_events(..., use_transaction = TRUE)`, `write_strategy_state`) | Exists. Calls `ledgr_write_fill_events(use_transaction = FALSE)` inside the fold transaction and returns its result (no row, nothing staged); `INSERT` into `strategy_state`. Writer validation errors propagate. | Not reachable (the sweep is buffered): `use_transaction` is ignored as today and `write_strategy_state` discards. |
| Diagnostic seeding and post-failure refresh | Exists (seed by query; refresh for the exception row). | Seed 1; no refresh. |
| Diagnostic retention (required: `write_run_diagnostics`, `write_exception_diagnostic`) | Keep all: append to `run_diagnostics`; DB errors propagate. | Keep summary rows only (`keep_summary_rows()` predicate unchanged); `diagnostics()` returns the kept rows or NULL. |
| Telemetry (required: `write_telemetry`, `store_session_telemetry`; DuckDB-only `set_schedule_counts`) | Exists. `INSERT OR REPLACE run_telemetry`, strict errors abort with `ledgr_run_telemetry_failed`, non-strict returns `invisible(FALSE)`; session registry write; schedule counts stored. | Policy: discard (`invisible(TRUE)`); `set_schedule_counts` absent (as today). |
| Strategy-state persistence (required: `buffer_strategy_state`) | Exists. Buffered rows drained by `flush_pending()`. | Policy: discard. |
| Inline accounting and equity projections (optional: `record_accounting_fact`, `record_equity_fact`, `inline_summary`) | Absent (as today; the fold guards at `R/fold-engine.R:584`, `:1370`). | Exists. Sets the staged entry's realized P&L and cost basis, stages close/open legs with `ledgr_fill_leg_fees()`, stores equity facts, builds the summary. Returns `invisible(FALSE)` for a non-WROTE result as today. |
| Typed events (optional: `typed_events`; memory-only `events`, `diagnostics`, `completion`) | Absent (as today). | Exists. Materializes the buffer with the five `ledgr_event_*` attributes; `events()` also serializes `meta_json`. |
| Compiled spot batch (optional: `append_compiled_spot_batch`) | **Absent.** | Exists. Appends the batch's typed columns into the shared buffer and its legs into the inline fills. |

Each handler's method set equals today's set for its kind; LDG-3130 adds a
witness test comparing `sort(names(handler))` per sink with the frozen lists
below.

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
> fill row, the row's cash and position deltas come only from the one
> publication computation, `ledgr_fill_publication_deltas()`, applied to the
> fill's resolved side, quantity, price and fee, and a resolved fee is split
> across a fill's close and open legs only by `ledgr_fill_leg_fees()`. Both
> are row projections of the resolved fill, not a second economic
> computation.

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

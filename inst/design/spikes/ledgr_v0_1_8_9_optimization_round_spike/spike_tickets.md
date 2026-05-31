# v0.1.8.9 Optimization-Round Spike Tickets

Version: v0.1.8.9-pre-rfc
Date: 2026-05-31
Total Tickets: 15 (Round 1: LDG-2480..LDG-2489; Round 2: LDG-2490..LDG-2494; closeout: LDG-2492)
Status: Archival (see Status Metadata Disclaimer below)

## Status Metadata Disclaimer

This file is **pre-RFC archival scaffolding**, not active governance
metadata. The per-ticket `Status: Pending` headers and the
`status: "pending"` entries in `tickets.yml` were captured at ticket
creation time and were **not actively maintained** as the spikes ran,
the synthesis was written, or the Codex Round 1, 2, and 3 reviews
closed. They do not reflect current execution state.

The load-bearing artifacts for the round's current state are:

- `architecture_synthesis.md` (the Codex-approved synthesis, Round 3
  verdict: Approve With Caveats).
- The per-spike logs under `dev/spikes/spike-*.md` (each carries the
  authoritative proceed/park decision).
- `README.md` for the round-level summary table.

When the v0.1.8.9 spec packet is cut from the synthesis, this ticket
file is archived alongside the round directory.

## Ticket Organization

This file holds ticket entries for the v0.1.8.9 pre-RFC spike investigation
documented in `README.md`. These tickets do **not** belong to the v0.1.8.8
release packet (`inst/design/ledgr_v0_1_8_8_spec_packet/`), and do not
gate the v0.1.8.8 release. They are pre-RFC investigation feeding the
v0.1.8.9 single-core optimization spec and round.

The structure follows the v0.1.8.8 ticket markdown format. Numbering
continues from v0.1.8.8 (last ticket LDG-2479) to make LDG numbers
monotonic across releases.

Each spike ticket follows the v0.1.8.7 spike round model: write a
self-contained R script under `dev/spikes/spike-<name>.R`, run it,
write a paired log under `dev/spikes/spike-<name>.md` documenting the
mechanism evidence and the Amdahl-bounded wall translation, and record
a proceed-or-park decision in the log.

## Priority Levels

- P0: Round-kickoff or round-close (none in this round).
- P1: Spike on a candidate with `MEASURED` evidence and large estimated
  impact on the reference cell. These spikes feed the v0.1.8.9 spec's
  headline lanes.
- P2: Spike on a candidate with `INFERRED` or `HYPOTHESIZED` evidence,
  or a smaller estimated impact. These spikes either confirm a secondary
  v0.1.8.9 candidate or are negative results that park the candidate.

## Dependency DAG

```text
(no dependencies; all spikes are independent)

LDG-2480 Spike 1 - Per-pulse position valuation vectorize
LDG-2481 Spike 2 - Per-target delta vectorize
LDG-2482 Spike 3 - state$positions representation
LDG-2483 Spike 4 - Batch fill writes DuckDB
LDG-2484 Spike 5 - Per-fill next-bar extraction
LDG-2485 Spike 6 - Memory output handler scaling
LDG-2486 Spike 7 - Fills reconstruction scaling
LDG-2487 Spike 8 - Event-stream reconstruction scaling
LDG-2488 Spike 9 - Fills extraction xlarge breakdown
LDG-2489 Spike 10 - DuckDB equity round-trip noise
```

All ten spikes can run in parallel. The cross-cutting synthesis
(`architecture_synthesis.md`) is written after the spikes complete.

---

## LDG-2480: Spike 1 - Per-Pulse Position Valuation Vectorize

Priority: P1
Effort: S
Dependencies: none
Status: Pending

### Description

Confirm or reject the hypothesis that the per-pulse position valuation
loop at `R/fold-engine.R:164-170` is the dominant per-pulse O(n_inst)
cost contributor on the reference workload.

Mechanism hypothesis: The `for (j in seq_along(instrument_ids))` loop
runs every pulse with no fill dependency, doing R-interpreted list
lookups and matrix indexing per instrument. At 1000 instruments x 1260
pulses this is 1.26M R-interpreted iterations. Replacing with a single
`sum(as.numeric(state$positions) * bars_mat$close[, i])` should be
10x-100x faster in isolation.

Estimated wall recovery on `density_high_xlarge_durable`: ~9s of 413s
loop time. Amdahl bound on wall: ~2%.

### Tasks

- Write `dev/spikes/spike-position-valuation-vectorize.R` following the
  v0.1.8.7 spike conventions in
  `dev/spikes/spike-event-buffer-rewrite.R`.
- Build a synthetic `state$positions` named numeric vector of length
  {50, 100, 500, 1000} and a `bars_mat$close` matrix of compatible
  shape and 1260 columns.
- Time three variants per shape: (a) the current loop body, (b) the
  vectorized replacement, (c) the vectorized replacement with explicit
  ordering via `state$positions[instrument_ids]` to handle the
  alignment risk.
- Verify byte-identical output of all three variants on a fixture
  across all 1260 pulses.
- Write `dev/spikes/spike-position-valuation-vectorize.md` following
  the spike log template in `README.md`.
- Record proceed-or-park decision in the log with Amdahl-bounded wall
  translation.

### Acceptance Criteria

- Spike script exists at `dev/spikes/spike-position-valuation-vectorize.R`
  and runs reproducibly from a clean R session.
- Spike log exists at `dev/spikes/spike-position-valuation-vectorize.md`
  with Date, Host, Script reference, Question, Method, Results, Findings,
  Wall translation, Caveats, Recommendation.
- The log documents the isolated speedup ratio across at least two
  shapes ({100, 1000} instruments).
- The log explicitly addresses the alignment risk: does `state$positions`
  preserve `instrument_ids` order, or does the production fix need
  explicit ordering.
- Wall-translation paragraph computes the Amdahl-bounded wall
  improvement using grid-record numbers and records proceed/park
  decision.
- Synthetic CSV scratch artifact under `dev/bench/results/` is
  gitignored; only the script and the log are committed.

### Verification

Re-run the spike script on the host. Manually review the log for
mechanism evidence, alignment-risk treatment, and honest Amdahl
translation. No production code changes are made in this ticket.

### Source Reference

- `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/README.md`
- `dev/bench/notes/per_pulse_complexity_findings.md` (Suspect 1)
- `dev/bench/notes/single_core_optimization_inventory.md` (A1)
- `R/fold-engine.R:164-170`
- `dev/spikes/spike-event-buffer-rewrite.R` (v0.1.8.7 spike template)

### Classification

```yaml
type: spike
surface: fold_engine_per_pulse
scope: position_valuation_vectorize
```

---

## LDG-2481: Spike 2 - Per-Target Delta Vectorize

Priority: P1
Effort: S
Dependencies: none
Status: Pending

### Description

Confirm or reject the hypothesis that the per-target early-skip loop
at `R/fold-engine.R:277-359` contributes meaningfully to per-pulse
O(n_inst) cost.

Mechanism hypothesis: The strategy returns `targets` as a length-n_inst
named numeric vector. The loop iterates n_inst times per pulse and
does the `[[id]]` lookups on both `targets` and `state$positions`
before deciding whether to fire a fill. At 1000 x 1260 the loop body
runs 1.26M times to do ~133k real fills (~10:1 skip-to-fill ratio).
Computing a delta vector once and iterating only over non-zero
indices should drop loop iterations to ~133k total and recover ~12s
of 413s loop time on the xlarge cell.

### Tasks

- Write `dev/spikes/spike-target-delta-vectorize.R`.
- Build synthetic `targets` and `state$positions` named vectors of
  length {100, 1000} with a configurable fill-density factor (default
  ~135 fills per instrument across 1260 pulses).
- Time three variants: (a) current early-skip loop, (b) vectorized
  delta + `which()` + iterate, (c) variant (b) with `names(targets)`
  not equal to `names(state$positions)` ordering to surface alignment
  bugs.
- Verify byte-identical fill set (instrument_id, delta sign,
  delta magnitude) across all three variants.
- Write paired log following the spike log template.

### Acceptance Criteria

- Spike script and log exist.
- Isolated speedup ratio reported across at least two universe sizes.
- Skip-to-fill ratio computed empirically from the spike data and
  reported as the scaling input.
- Alignment risk addressed: log explicitly states the safe production
  pattern (use `state$positions[names(targets)]` subset).
- Wall translation with Amdahl. Proceed/park decision.

### Verification

Re-run spike, review log.

### Source Reference

- `dev/bench/notes/per_pulse_complexity_findings.md` (Suspect 2)
- `dev/bench/notes/single_core_optimization_inventory.md` (A2)
- `R/fold-engine.R:277-359`

### Classification

```yaml
type: spike
surface: fold_engine_per_pulse
scope: target_delta_vectorize
```

---

## LDG-2482: Spike 3 - state$positions Representation

Priority: P1
Effort: M
Dependencies: none
Status: Pending

### Description

Confirm or reject the hypothesis that `state$positions[[id]] <- value`
at `R/fold-engine.R:354-355` triggers whole-vector copy-on-write under
refcount-elevated conditions, contributing to per-fill cost growth with
universe size.

Mechanism hypothesis: R's copy-on-modify semantics may copy a named
numeric vector when one element is mutated, depending on reference
count. The pulse-context constructor at `R/fold-engine.R:180-194` puts
`positions = state$positions` into the `ctx` list, which holds a
reference. That reference may force a copy on mutation. At 1000 inst
x 133k fills, potentially 133M element copies per run.

This spike must also test two candidate fixes: (a) `state` as an
environment instead of a list, (b) `state$positions` as
integer-indexed numeric with a one-time id-to-idx map. Both should
remove the copy.

### Tasks

- Write `dev/spikes/spike-state-positions-representation.R`.
- Set up a synthetic state that mimics the production refcount-
  elevated condition: build `state` as a list, attach a closure that
  references `state$positions`, then mutate `state$positions[[id]]`
  in a loop. Use `tracemem` to confirm copy.
- Time three variants per shape ({100, 1000} instruments, {1k, 10k,
  100k} mutations): (a) current named-list with refcount-elevated
  closure, (b) environment-backed state, (c) integer-indexed numeric
  with id-to-idx map.
- Confirm `tracemem` shows copy for (a) and no copy for (b) and (c).
- Verify byte-identical final positions across all three variants on a
  fixture.
- Write paired log following the spike log template.

### Acceptance Criteria

- Spike script and log exist.
- `tracemem` output documented in the log as mechanism evidence.
- Per-mutation cost reported across at least two universe sizes and
  three variants.
- Log addresses the production blast radius: `state` and
  `state$positions` are referenced from multiple places (pulse context
  construction, reconstruction, telemetry). The log enumerates the
  read-site count and recommends sequencing (after Spikes 1 and 2
  given larger blast radius).
- Wall translation. Proceed/park decision.

### Verification

Re-run spike, review log.

### Source Reference

- `dev/bench/notes/per_pulse_complexity_findings.md` (Suspect 3)
- `dev/bench/notes/single_core_optimization_inventory.md` (A3)
- `R/fold-engine.R:354-355`
- `inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd` -
  section "In R, 'preallocate to be safe' is often actively harmful"

### Classification

```yaml
type: spike
surface: fold_engine_state_mutation
scope: positions_representation
```

---

## LDG-2483: Spike 4 - Batch Fill Writes (DuckDB)

Priority: P1
Effort: M
Dependencies: none
Status: Pending

### Description

Measure the per-fill cost of single-row DuckDB inserts vs batched
inserts at production fill scales. The current durable output handler
calls `write_fill_events` once per fill; the LDG-2479 grid suggests
this is the next-largest single-lane wall-time win after the per-pulse
fixes.

Mechanism hypothesis: Per-fill DuckDB row insertion has a per-call
overhead (transaction, statement parse, write-ahead log fsync) that
dominates the actual write time. Batching N fills into one insert
should amortize that overhead by N. Expected sharp per-fill cost drop
between batches of 1 and batches of 100, with diminishing returns past
1000.

Estimated wall recovery on `density_high_xlarge_durable`: 30-80s.

### Tasks

- Write `dev/spikes/spike-batch-fill-writes.R`.
- Open a fresh DuckDB connection. Create a fills table matching ledgr's
  ledger schema.
- Insert 68,000 single-row INSERTs. Record total wall and per-fill cost.
- Insert the same 68,000 rows as batches of {10, 100, 1000, 10000}.
  Record wall per batch size.
- Plot batch-size vs per-fill cost. Identify the knee.
- Repeat with the production output handler's path (call into
  `ledgr_durable_output_handler` or whatever the current path is) to
  confirm the isolated DuckDB result reproduces in the handler
  wrapper.
- Verify row count matches input across all batch sizes.
- Write paired log following the spike log template.

### Acceptance Criteria

- Spike script and log exist.
- Per-fill cost reported at batch sizes {1, 10, 100, 1000, 10000} and
  at 68k total fills.
- Knee batch size identified and recommended.
- Log addresses the parity-gate risk: batched writes must preserve
  event ordering, ts_utc monotonicity within instrument, and seq
  integer continuity. The grow-by-doubling B0 buffer pattern is named
  as the model.
- Wall translation. Proceed/park decision.

### Verification

Re-run spike, review log, confirm row count parity.

### Source Reference

- `dev/bench/notes/single_core_optimization_inventory.md` (B1)
- `R/fold-engine.R:336-340` (call site)
- v0.1.8.7 B0 buffer fix as the architectural template
- `R/fold-event-buffer.R`

### Classification

```yaml
type: spike
surface: durable_output_handler
scope: batch_fill_writes
```

---

## LDG-2484: Spike 5 - Per-Fill Next-Bar Extraction

Priority: P2
Effort: S
Dependencies: none
Status: Pending

### Description

Measure whether the `b[i+1L, , drop = FALSE]` data.frame row subset at
`R/fold-engine.R:290` is a visible per-fill cost.

Mechanism hypothesis: data.frame row subset allocates a new sub-frame
per fill with class-dispatch overhead. Replacing with a matrix scalar
lookup (`bars_mat$open[inst_idx, i+1L]`) is O(1) with no allocation.
At 133k fills, the cumulative cost may be visible.

### Tasks

- Write `dev/spikes/spike-next-bar-extraction.R`.
- Time 68k subsets of a 1260-row tibble vs 68k matrix scalar lookups.
- Time the same against a 1000-instrument matrix (the production scale).
- Confirm byte-identical values returned for each method on a fixture.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Isolated speedup reported at production-scale fill count.
- Log states whether this is a SIM-CONFIRMED candidate for the v0.1.8.9
  spec or a park (Amdahl too small).

### Verification

Re-run, review.

### Source Reference

- `dev/bench/notes/single_core_optimization_inventory.md` (B2)
- `R/fold-engine.R:290`

### Classification

```yaml
type: spike
surface: fold_engine_per_fill
scope: next_bar_extraction
```

---

## LDG-2485: Spike 6 - Memory Output Handler Scaling

Priority: P1
Effort: M
Dependencies: none
Status: Pending

### Description

Confirm or reject the hypothesis that the memory output handler used
by the ephemeral sweep path has an O(n_events) component in per-event
append cost that explains the +178.85s xlarge ephemeral delta vs
durable.

Mechanism hypothesis: The handler uses the same B0 grow-by-doubling
buffer as durable but accumulates ALL events for the run before
reconstruction. At 133k fills the buffer's final size is large; per-
event append cost may have a hidden O(n_events) component from name-
vector or metadata-list growth, or from a per-append operation that
inadvertently re-scans the buffer.

### Tasks

- Write `dev/spikes/spike-memory-output-handler-growth.R`.
- Instantiate `ledgr_memory_output_handler()` directly from the
  benchmark (the ephemeral peer benchmark row already does this; lift
  that code path).
- Push 133k synthetic fill events in a loop. Measure per-event elapsed
  at intervals (every 1000th event). Record per-event cost as a function
  of accumulated event count.
- Compare against pushing 133k events into a fresh B0 event buffer
  directly (no handler wrapper).
- If a growth pattern is visible, instrument the handler to identify
  the operation responsible.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-event cost reported at intervals of 1000 events from 1k to 133k.
- Mechanism either confirmed (per-event cost grows with accumulated
  count) or rejected (per-event cost is flat).
- If confirmed, the log names the responsible operation.
- Wall translation against the +178.85s ephemeral xlarge delta.

### Verification

Re-run, review.

### Source Reference

- `dev/bench/notes/single_core_optimization_inventory.md` (C1, C2)
- `R/fold-event-buffer.R`
- `dev/bench/peer_benchmark/peer_benchmark.R` (ephemeral path)

### Classification

```yaml
type: spike
surface: memory_output_handler
scope: per_event_growth
```

---

## LDG-2486: Spike 7 - Fills Reconstruction Scaling

Priority: P1
Effort: M
Dependencies: none
Status: Pending

### Description

Confirm or reject the hypothesis that `ledgr_results(bt, "fills")`
exhibits super-linear scaling at production fill counts, and that the
mechanism is either a regression to the list-of-data.frames + rbind
anti-pattern from v0.1.8.7 Batch 6 or a second O(N^2) site that the
v0.1.8.7 rewrite did not catch.

Mechanism hypothesis: Reconstruction took 6.75s at 13k fills and
82.28s at 68k fills (13.5x slower for 5.1x more fills). At xlarge
(~133k fills) it ran 197s and failed to return a row count. The
super-linear scaling matches the O(N^2) signature of iterative rbind.

### Tasks

- Write `dev/spikes/spike-fills-reconstruction-scaling.R`.
- Build synthetic events tables of {13k, 30k, 68k, 130k} rows matching
  the ledger schema.
- Run the current `ledgr_results(bt, "fills")` path on each. Time it.
- Build a primitive-column rewrite (per v0.1.8.7 Lane C pattern):
  preallocate one typed vector per column, fill by index in the loop,
  materialize the data.frame once at the end.
- Run both paths on the same event tables. Time the rewrite.
- Plot scaling for both paths. Identify the crossover where the
  rewrite wins.
- Verify byte-identical output across paths on the fixture.
- Audit the current path for any list-of-data.frames + rbind sub-paths
  that may have re-emerged or were missed in v0.1.8.7.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Scaling curves plotted for both paths across at least four scales.
- Mechanism either confirmed (super-linear matches O(N^2)) or rejected.
- Log identifies the responsible sub-path in the current code (if a
  rbind anti-pattern is found, the file:line is named).
- Wall translation against the 197s xlarge fills_extract cost.

### Verification

Re-run, review, byte-identical parity check on fixture.

### Source Reference

- `dev/bench/notes/single_core_optimization_inventory.md` (D1)
- `R/fold-reconstruction.R`
- `inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd` -
  Batch 6 Lane C reference for the primitive-column rewrite pattern.

### Classification

```yaml
type: spike
surface: fold_reconstruction
scope: fills_reconstruction_scaling
```

---

## LDG-2487: Spike 8 - Event-Stream Reconstruction Scaling

Priority: P2
Effort: M
Dependencies: none
Status: Pending

### Description

Same mechanism hypothesis as Spike 7 but for the in-memory
reconstruction path used by the ephemeral row:
`ledgr_equity_from_events()` and `ledgr_fills_from_events()`. The
ephemeral results phase shows +40.9s vs durable on the same fills
count.

### Tasks

- Write `dev/spikes/spike-event-stream-reconstruction.R`.
- Build synthetic event lists of {13k, 30k, 68k, 130k} rows.
- Run `ledgr_equity_from_events()` and `ledgr_fills_from_events()` on
  each. Time both.
- Build a primitive-column rewrite for each.
- Plot scaling for both paths and both functions.
- Verify byte-identical output across paths.
- Write paired log.

### Acceptance Criteria

- Same shape as Spike 7. Per-function scaling reported.

### Verification

Re-run, review.

### Source Reference

- `dev/bench/notes/single_core_optimization_inventory.md` (D3)
- `R/fold-reconstruction.R`
- `dev/bench/peer_benchmark/peer_benchmark.R` (ephemeral results path)

### Classification

```yaml
type: spike
surface: fold_reconstruction
scope: event_stream_reconstruction_scaling
```

---

## LDG-2488: Spike 9 - Fills Extraction Xlarge Breakdown

Priority: P2
Effort: S
Dependencies: none
Status: Pending

### Description

Diagnose why `ledgr_results(bt, "fills")` returns no row count on the
`density_high_xlarge_durable` cell (~133k fills), forcing the LDG-2479
harness to fall back to the ledger row count.

Mechanism hypothesis (open): query returns a lazy-evaluated DuckDB
cursor that errors on materialization; chunked reader silently drops
rows; memory pressure kills conversion to data.frame; or the reader
hits a hard-coded buffer ceiling.

This is a robustness diagnostic, not a perf simulation. The output is
a named cause + a proposed fix path, not a speedup number.

### Tasks

- Write `dev/spikes/spike-fills-extract-xlarge-breakdown.R`.
- Build a synthetic events table at 130k rows (matching the xlarge
  density).
- Instrument `ledgr_results(bt, "fills")` to log intermediate stages
  (query plan, chunk count, row count per chunk, materialization wall,
  any errors raised, memory high-water).
- Run on the synthetic table. Identify which stage fails.
- If the stage is reproducible at smaller scale (e.g., 100k or 200k
  rows), report the threshold.
- Write paired log identifying the cause and proposing a fix path.

### Acceptance Criteria

- Spike script and log exist.
- The failing stage is named.
- A reproducible threshold (rows at which the failure begins) is
  reported.
- The log proposes a fix path or escalates as an unknown.

### Verification

Re-run, review, confirm the failure is reproducible.

### Source Reference

- `dev/bench/notes/single_core_optimization_inventory.md` (D2, L1)
- `dev/bench/notes/workload_grid_baseline_closeout.md` (the fills count
  fallback at xlarge)
- `R/fold-reconstruction.R`

### Classification

```yaml
type: spike
surface: fold_reconstruction
scope: fills_extract_xlarge_robustness
```

---

## LDG-2489: Spike 10 - DuckDB Equity Round-Trip Noise

Priority: P2
Effort: S
Dependencies: none
Status: Pending

### Description

Identify the origin of the ~8e-9 per-bar equity divergence between
durable and ephemeral ledgr rows that forced the LDG-2476 three-phase
parity gate to relax from byte-identical to `tolerance = 1e-8`.

Mechanism hypothesis (open):

- (a) DuckDB internally promotes DOUBLE through DECIMAL/NUMERIC at some
  boundary in the chunked reader.
- (b) Accumulation order differs between durable read-back (which reads
  pre-aggregated equity from a table) and ephemeral reconstruction
  (which walks the event stream and re-accumulates).
- (c) A cast through different precision in the chunked reader path.

If (b), the relaxation is correct and final. If (a) or (c), the cast
can be fixed and byte-identical parity restored.

### Tasks

- Write `dev/spikes/spike-duckdb-equity-roundtrip.R`.
- Write a 100-element double vector to DuckDB, read it back. Byte-
  compare to original. If identical, the mechanism is (b)
  accumulation order.
- If not identical, instrument the chunked reader to find the cast or
  promotion boundary.
- If accumulation order: time both paths on a synthetic 1260-row equity
  series. Confirm the 8e-9-class noise reproduces in isolation.
- Document the identified mechanism in the paired log.
- Recommend: keep the 1e-8 tolerance (mechanism is b) or fix the
  responsible boundary (mechanism is a or c).

### Acceptance Criteria

- Spike script and log exist.
- The mechanism is named and supported by byte-compare evidence.
- The log recommends either keeping the tolerance or fixing the
  boundary, with rationale.

### Verification

Re-run, review.

### Source Reference

- `dev/bench/notes/single_core_optimization_inventory.md` (D5)
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_design.md` -
  "Parity Gate" section
- `R/fold-reconstruction.R` (durable read-back)
- `R/fold-engine.R` and `R/fold-event-buffer.R` (in-memory walk)

### Classification

```yaml
type: spike
surface: fold_reconstruction
scope: float_round_trip_origin
```

---

## After All Spikes Complete

Write `architecture_synthesis.md` in this directory following the v0.1.8.7
precedent (`inst/design/spikes/ledgr_optimization_round_spike/architecture_synthesis.md`).
The synthesis should:

- Summarize each spike's mechanism finding (confirmed/rejected/open).
- Identify cross-cutting lessons (e.g., "R-idiom debt concentrates in
  per-pulse loops" or "DuckDB writes are the next-largest lane").
- Rank the v0.1.8.9 candidate lanes by combined Amdahl headroom and
  mechanism confidence.
- Name the v0.1.8.9 spec inputs: which spikes feed which proposed v0.1.8.9
  ticket, with the spike log as the load-bearing source reference.

The synthesis is the load-bearing input for the v0.1.8.9 spec packet. Until
the synthesis exists, the v0.1.8.9 spec packet cannot be cut.

---

## Round 2: Post-Peer-Review Corrections (LDG-2490 through LDG-2492)

The Codex peer review of the round identified three blocking findings
that affect the synthesis's projected wall recovery and lane ordering:

1. **Spike 4 (LDG-2483) is not faithful to the default durable path.**
   The persistent output handler at `R/backtest-runner.R:425-435` already
   batches via `pending_cols` and flushes with `DBI::dbAppendTable`. The
   per-row INSERT pattern Spike 4 measured applies only to live mode,
   not to the measured `density_high_xlarge_durable` workload. The
   ~75s wall recovery claim is unsupported for the measured path.
2. **Spike 7's buffer is an environment with vector slots, not a list
   of vectors.** `ledgr_fill_row_buffer()` at
   `R/fold-reconstruction.R:155-170` returns `new.env(parent = emptyenv())`.
   The mechanism (copy-on-modify via transient binding) and fix
   (`collapse::setv`) are unchanged, but the writeup wording needs
   correction.
3. **Spike 7's wall translation is too direct.** Durable
   `ledgr_results(bt, "fills")` goes through `ledgr_extract_fills_impl()`
   at `R/backtest.R:1021` with a chunked reader at xlarge
   (`stream_threshold = 100000L`). Per-chunk buffers are much smaller
   than the monolithic 260k-slot buffer Spike 7 measured, so the
   production durable path's actual O(N^2) cost is bounded by chunk
   size, not by total events. The ~170s wall recovery estimate is
   likely an over-projection.

Three follow-up tickets close these gaps before the synthesis is
finalized.

### Updated Dependency DAG

```text
LDG-2490 Spike 11 - Persistent Durable Handler pending_cols Buffer
  (depends on LDG-2483, LDG-2485)

LDG-2491 Spike 12 - Chunked Extractor Wall Recovery Measurement
  (depends on LDG-2486)

LDG-2493 Spike 13 - yyjsonr Read-Path Parity And Recovery
  (depends on LDG-2491; soft input to LDG-2492 if it lands in time)

LDG-2492 Synthesis Revision And Re-Review
  (depends on LDG-2490, LDG-2491; soft dependency on LDG-2493)
```

LDG-2490, LDG-2491, and LDG-2493 are post-review investigation work.
The v0.1.8.9 spec packet cannot be cut until LDG-2492 completes. LDG-2493
is a soft input: if it lands before LDG-2492 closes, the synthesis
incorporates its result; if not, LDG-2493's outcome is recorded as a
v0.1.8.10 follow-up.

---

## LDG-2490: Spike 11 - Persistent Durable Handler pending_cols Buffer

Priority: P1
Effort: S
Dependencies: LDG-2483, LDG-2485
Status: Pending

### Description

Confirm or reject the hypothesis that the persistent durable output
handler's `pending_cols` buffer at `R/backtest-runner.R:425-435` has the
same O(N^2) per-row column-buffer write anti-pattern as the memory output
handler (Spike 6, LDG-2485) and the fills reconstruction buffer (Spike 7,
LDG-2486).

Mechanism hypothesis: the persistent durable handler's `buffer_event`
function does 11 per-row column writes:

```r
state$pending_cols$event_id[[i]] <- write_res$row$event_id
state$pending_cols$run_id[[i]] <- write_res$row$run_id
state$pending_cols$ts_utc[[i]] <- write_res$row$ts_utc
...
```

This is the SAME pattern as `R/sweep.R:1016-1029` (memory handler) and
`R/fold-reconstruction.R:219-227` (fills reconstruction). At production
fill counts the per-row copy-on-modify cost dominates. If confirmed, the
fix is the same `collapse::setv` replacement, applied to a third site.

This spike replaces Spike 4 (LDG-2483) for the default durable path.
Spike 4's per-row DBI INSERT measurement was correct but applies only to
live mode, not buffered mode used by the workload grid.

### Tasks

- Write `dev/spikes/spike-persistent-handler-buffer.R`.
- Replicate the persistent output handler's `buffer_event` structure
  from `R/backtest-runner.R:415-437` faithfully (env-based state,
  ensure_pending_capacity logic, 11 column writes per event).
- Time per-event append cost at intervals from 1k to 130k accumulated
  events. Same methodology as Spike 6 (LDG-2485).
- Compare against a `collapse::setv` variant of the same 11 column
  writes.
- Confirm tracemem (or equivalent) evidence: current path copies,
  setv path does not.
- Verify parity: both variants produce the same in-memory column
  values for a fixture (event_id, qty, price, etc. byte-identical).
- Write paired log `dev/spikes/spike-persistent-handler-buffer.md`
  following the spike log template.

### Acceptance Criteria

- Spike script and log exist.
- Per-event cost reported at intervals from 1k to 130k events on both
  variants.
- O(N^2) signature confirmed (or rejected) by the per-event growth
  pattern.
- setv speedup at 130k events reported as a single number.
- Wall translation: estimate the recovery on `density_high_xlarge_durable`
  if the persistent handler in production were fixed. Include this as a
  separate number from Spike 6's ephemeral-only number — the persistent
  handler is the durable path.
- Log explicitly states whether this lane replaces, supplements, or
  invalidates Spike 4 (LDG-2483) for the v0.1.8.9 spec.

### Verification

Re-run spike, review log. tracemem or refcount evidence documented.
Column-value byte-identical parity confirmed.

### Source Reference

- `R/backtest-runner.R:415-437` (the production durable handler's
  `buffer_event`)
- `dev/spikes/spike-memory-output-handler-growth.R` (LDG-2485 template
  to copy from)
- `dev/spikes/spike-memory-output-handler-growth.md` (LDG-2485 results
  to compare against)
- Codex peer review finding 1.

### Classification

```yaml
type: spike
surface: persistent_durable_output_handler
scope: pending_cols_buffer_writes
```

---

## LDG-2491: Spike 12 - Chunked Extractor Wall Recovery Measurement

Priority: P1
Effort: S
Dependencies: LDG-2486
Status: Pending

### Description

Measure the actual production durable path's wall recovery from a
`collapse::setv` fix at `R/fold-reconstruction.R:219-227`. Spike 7
(LDG-2486) measured monolithic `ledgr_fills_from_events()` and projected
~170s recovery, but the production durable path goes through
`ledgr_extract_fills_impl()` at `R/backtest.R:1021` with a chunked
reader (`stream_threshold = 100000L`). Per-chunk buffers are much
smaller than the 260k-slot buffer Spike 7 measured, so the actual O(N^2)
cost is bounded by chunk size and the wall recovery from setv is
likely smaller than Spike 7's estimate.

This spike measures how the chunked extractor interacts with the
`ledgr_fill_row_buffer_add` hot function: per-chunk buffer size, total
buffer-write work across chunks, and the realistic wall recovery from
applying setv to lines 219-227 in production durable runs.

### Tasks

- Write `dev/spikes/spike-chunked-extractor-wall-recovery.R`.
- Read `R/backtest.R:1021-1276` (`ledgr_extract_fills_impl`) to
  identify the chunk size pattern. Document whether the chunked
  reader uses DBI's default fetch size or an explicit chunk size.
- Build a synthetic ledger_events DuckDB table at 130k rows.
- Call `ledgr:::ledgr_extract_fills_impl` on a synthetic bt-shaped
  object that exercises the streaming path. Time it.
- Apply a `collapse::setv` patch (in a forked copy under
  `dev/spikes/patched-fold-reconstruction.R`) at lines 219-227 of
  `R/fold-reconstruction.R`. Call the patched extractor on the same
  events. Time it.
- Report the wall recovery as a single measured number, not an
  estimate.
- If constructing a bt-shaped object is too brittle, fall back to
  measuring per-chunk buffer-write cost at chunk sizes {1k, 10k, 50k,
  100k} and computing the implied total for a 130k-row run as the
  sum of per-chunk costs. Document this as the fallback methodology.
- Write paired log `dev/spikes/spike-chunked-extractor-wall-recovery.md`.

### Acceptance Criteria

- Spike script and log exist.
- The chunk size pattern used by `ledgr_extract_fills_impl` is
  documented (either measured empirically or read from source).
- Production durable wall recovery from setv is reported as a measured
  number, NOT an extrapolation from Spike 7's monolithic measurement.
- The recovery number replaces Spike 7's ~170s projection in the
  synthesis's L6 lane ordering.
- Log explicitly states whether the durable fills extraction lane is
  still the largest single-lane recovery or whether the lane ordering
  needs adjustment.

### Verification

Re-run spike, review log. Confirm the chunk-size pattern claim against
the source. Confirm parity of the patched extractor's output vs the
production extractor on a small fixture.

### Source Reference

- `R/backtest.R:1021-1276` (`ledgr_extract_fills_impl`)
- `R/fold-reconstruction.R:219-227` (the setv fix site)
- `dev/spikes/spike-fills-reconstruction-scaling.R` (LDG-2486 baseline)
- `dev/spikes/spike-fills-reconstruction-scaling.md` (LDG-2486 results
  to compare against)
- Codex peer review finding 3.

### Classification

```yaml
type: spike
surface: fold_reconstruction
scope: chunked_extractor_wall_recovery
```

---

## LDG-2493: Spike 13 - yyjsonr Read-Path Parity And Recovery

Priority: P2
Effort: S
Dependencies: LDG-2491
Status: Pending

### Description

Assess whether `yyjsonr` (https://github.com/coolbutuseless/yyjsonr) is
a viable drop-in replacement for `jsonlite::fromJSON(..., simplifyVector
= FALSE)` in ledgr's hot READ paths, and measure the actual production
wall recovery.

Context: Spike 12 (LDG-2491) Rprof showed `jsonlite::fromJSON`
consumes ~15s of the 52s patched-baseline at 130k events in the chunked
extractor. yyjsonr claims 2-10x speedup over jsonlite. If a real-path
spike confirms (a) byte/structural parity between yyjsonr and jsonlite
on representative ledger meta_json shapes, and (b) measurable wall
recovery in the 5-15s range on xlarge, yyjsonr becomes a v0.1.8.9
candidate lane sitting between Spike 5 (~5s) and Spikes 1+2 (~15s).

**SCOPE CONSTRAINT (mandatory).** This spike covers ONLY Class A read
paths — `jsonlite::fromJSON(meta_json, simplifyVector = FALSE)` call
sites where the parsed R object is consumed for computation and
discarded. The 8 known call sites are in `R/backtest.R`,
`R/backtest-runner.R`, `R/derived-state.R`, `R/config-canonical-json.R`
(the read-side of the cache lookup only), and similar.

Class B WRITE paths (specifically `canonical_json`'s `jsonlite::toJSON`
call at `R/config-canonical-json.R:115`) are EXPLICITLY OUT OF SCOPE.
The output bytes of canonical_json feed durable identity hashes
(`snapshot_hash`, `config_hash`, indicator fingerprints, reproduction
keys). Any byte difference in canonical_json output would break all
existing reproducibility. yyjsonr must NOT be applied to that call
site without a separate, comprehensive byte-identity parity gate which
is out of scope for v0.1.8.9.

### Tasks

- Write `dev/spikes/spike-yyjsonr-readpath-parity.R`.
- Install yyjsonr from CRAN if not already available.
- Collect 100-1000 representative `meta_json` strings. Options:
  (a) extract from an existing LDG-2479 grid record's ledger_events
  table; (b) synthesize matching the production schema
  (`{"cash_delta":...,"position_delta":...,"realized_pnl":...}` plus
  occasional opening-position metadata with cost_basis).
- For each string, parse with both:
  - `jsonlite::fromJSON(s, simplifyVector = FALSE)` (current production)
  - `yyjsonr::read_json_str(s, opts = ...)` (with whatever yyjsonr opts
    most closely match `simplifyVector = FALSE` — investigate the
    `yyjsonr::opts_read_json` function)
- Compare R-object parity with `identical()` (not `all.equal()`). The
  hot path expects nested lists; verify yyjsonr produces them. If it
  auto-simplifies vectors or arrays, document the gap.
- If parity holds: time both parsers on the full set at production
  call frequency. Report speedup ratio and projected wall recovery.
- If parity fails: document the structural difference. Determine
  whether downstream consumers (`ledgr_lot_apply_event` etc.) care
  about the specific differences or whether they only care about
  scalar values (cash_delta, position_delta, realized_pnl). If only
  scalar values matter, propose a wrapper that extracts those via
  yyjsonr and matches the jsonlite-derived consumption pattern.
- Write paired log `dev/spikes/spike-yyjsonr-readpath-parity.md`.
- Record a CLEAR decision: proceed to v0.1.8.9 implementation ticket,
  park, or defer to v0.1.8.10.

### Acceptance Criteria

- Spike script and log exist.
- Parity gate result reported per fixture string (pass/fail by
  identical()).
- Wall recovery from yyjsonr reported as a measured number across the
  test set, scaled to 133k events.
- Class B (canonical_json write) is explicitly NOT TOUCHED by the spike.
- Recommendation is one of: PROCEED (parity holds, recovery > 5s
  projected), PARK (recovery insufficient or parity fails non-trivially),
  DEFER (parity holds but blast radius higher than expected).
- If PROCEED: the implementation ticket sketch lists the 8 call sites
  to replace and the wrapper or option-set needed for parity.
- If PARK or DEFER: log explicitly states the reason so v0.1.8.10
  reviewers don't re-investigate.

### Verification

Re-run spike, review log. Parity decisions documented explicitly.

### Source Reference

- Codex peer review (Round 2 context).
- `dev/spikes/spike-chunked-extractor-wall-recovery.md` (LDG-2491)
  Rprof finding showing ~15s jsonlite cost in chunked extractor.
- `R/backtest.R:1127` (the chunked extractor's per-event fromJSON).
- `R/backtest-runner.R:1336, 1546, 1766, 1824` (additional fromJSON
  read sites in derived-state and extraction paths).
- `R/derived-state.R:29, 70` (more derived-state read sites).
- `R/config-canonical-json.R:115` (the WRITE site that is OUT OF
  SCOPE for this spike).
- https://github.com/coolbutuseless/yyjsonr (yyjsonr documentation).

### Classification

```yaml
type: spike
surface: hot_path_json_read
scope: yyjsonr_parity_and_recovery
```

---

## LDG-2494: Spike 14 - yyjsonr canonical_json Write Byte-Identity Test

Priority: P2
Effort: S
Dependencies: none
Status: Pending

### Description

Empirically test whether `yyjsonr::write_json_str()` can produce
byte-identical output to `jsonlite::toJSON()` for the input shapes
canonical_json accepts in production. The LDG-2493 ticket carved Class
B (canonical_json writes) out of scope on the assumption that byte
parity would be hard or impossible. This spike turns that assumption
into measurement.

If yyjsonr happens to already match jsonlite byte-for-byte (or with a
specific options combination), the canonical_json switch becomes much
cheaper and unlocks an additional ~12s wall recovery on
state_update-heavy workloads with no durable-identity disruption.

If yyjsonr differs in specific characterizable ways (e.g., always adds
a space after colons, formats integers differently), the spike
documents the gap so a future RFC for "ledgr canonical JSON byte
format v2" has hard evidence to work from.

### Tasks

- Write `dev/spikes/spike-yyjsonr-write-byte-identity.R`.
- Construct test inputs covering every shape `canonical_json` sees in
  production:
  - Scalar atomic (integer, double, character, logical)
  - Named list with sorted keys (post-canonicalize)
  - Nested named lists (multiple depths)
  - Empty list `list()`
  - Empty named list `setNames(list(), character())`
  - NULL values
  - NA values (logical, integer, double, character)
  - POSIXt that has been pre-converted to ISO string by canonicalize()
  - Numeric values exercising IEEE 754 precision (1e-12, 1e10, 2^53)
  - Negative numbers
  - Strings with special characters (quotes, backslashes, newlines,
    Unicode)
  - Integer vs double (R distinguishes 1L from 1.0; JSON may not)
  - Booleans
- Pass each through ledgr's `canonicalize()` step (extract from
  `R/config-canonical-json.R`).
- Serialize via `jsonlite::toJSON(payload, auto_unbox = TRUE, null =
  "null", na = "null", digits = NA, pretty = FALSE)` — the exact
  production options at `R/config-canonical-json.R:115-122`.
- Serialize via `yyjsonr::write_json_str(...)` with whatever options
  most closely match. Investigate `yyjsonr::opts_write_json()` for
  available knobs.
- Byte-compare the two outputs via `identical()` AND
  `charToRaw()` byte-by-byte. Document EVERY difference: position,
  jsonlite byte, yyjsonr byte, hypothesized cause.
- Test convergence: try multiple yyjsonr option combinations to find
  the closest match. If parity achievable, document the options. If
  not, characterize the remaining gap.
- Write paired log
  `dev/spikes/spike-yyjsonr-write-byte-identity.md`.

### Acceptance Criteria

- Spike script and log exist.
- Test set covers at least 15 distinct input shapes spanning every
  production canonical_json input class.
- For each test case, byte-identity result reported (pass/fail) plus
  the specific difference (if any).
- If parity achievable with a specific yyjsonr option combination: the
  combination is documented and the spike recommends a follow-up
  ticket to wire canonical_json onto yyjsonr.
- If parity NOT achievable: the specific structural differences are
  enumerated. The spike documents what a "canonical JSON byte format
  v2" RFC would have to address.
- Recommendation is one of:
  - **PROCEED (parity achievable with specific yyjsonr options).**
    Follow-up ticket for switch is straightforward; recommend
    cutting it.
  - **PROCEED-WITH-BUMP (parity NOT achievable vs jsonlite but
    yyjsonr is deterministic across versions/platforms).** Pre-CRAN
    blast radius is small (test fixtures don't store specific hash
    values per audit; parity history is gitignored). Document the
    canonical-format version bump in NEWS, regenerate parity history,
    switch.
  - **DEFER / PARK only if yyjsonr is non-deterministic across
    versions or platforms** — that's the actual reproducibility risk,
    not byte difference vs jsonlite. Pre-CRAN blast radius assessment:
    no hard-coded hash literals in tests; no user-generated artifacts
    exist; only 2 gitignored parity history files exist. Cost of byte
    format change is ~hours, not weeks.

### Verification

Re-run spike, review log. Confirm byte differences (if any) are
characterized at the granularity that would allow a future RFC author
to design a v2 byte format.

### Source Reference

- `R/config-canonical-json.R` (production canonical_json)
- LDG-2493 (the read-path spike that explicitly excluded this scope)
- The risk inventory in the assessment that motivated LDG-2493's
  scope carve-out.
- https://github.com/coolbutuseless/yyjsonr (yyjsonr documentation,
  particularly `opts_write_json`)

### Classification

```yaml
type: spike
surface: canonical_json_byte_identity
scope: yyjsonr_write_parity_test
```

---

## LDG-2492: Synthesis Revision And Re-Review

Priority: P0
Effort: M
Dependencies: LDG-2490, LDG-2491
Status: Pending

### Description

Apply Codex peer review's three verified corrections to the round's
documentation, incorporate the measured numbers from LDG-2490 and
LDG-2491, and re-submit the synthesis to Codex for sign-off. The
synthesis cannot be used as v0.1.8.9 spec input until this ticket
completes.

### Tasks

- **Synthesis updates** in
  `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`:
  - L2: clarify that `ledgr_fill_row_buffer()` returns an env with
    vector slots, not a list of vectors. The copy-on-modify mechanism
    is via transient binding during evaluation of `env$col[[i]] <-
    value`, not via refcount-elevated function argument. setv fix
    unchanged.
  - L2: add the persistent durable handler
    (`R/backtest-runner.R:425-435`) as the THIRD documented site of the
    per-row-write-into-shared-buffer trap. Reframe the coding rule as
    demonstrated four times (v0.1.8.7 B0 + Spikes 6, 7, 11 of this
    round).
  - L6: replace the ~250s projected recovery with the measured numbers
    from LDG-2490 (persistent handler setv) and LDG-2491 (chunked
    extractor wall recovery). Drop Spike 4 (LDG-2483) from the durable
    projection.
  - L6: rewrite the lane sequencing to reflect Codex's recommended
    order: (1) Spike 7 setv against the chunked extractor, (2)
    output-handler column-buffer setv (memory + persistent), (3) Spikes
    1+2 vectorization, (4) Spike 5 cleanup, (5) Spike 9 robustness
    once extraction is faster, (6) Spike 4 only if scoped to live mode
    or a new path-specific profile.
  - L7: confirm the work is still mechanical after the corrections.
- **Spike log corrections**:
  - `dev/spikes/spike-fills-reconstruction-scaling.md` (Spike 7):
    correct the "function argument with refcount > 1" wording per
    Codex finding 2. The mechanism is transient binding during
    `env$col[[i]] <- value` evaluation, not function-argument
    refcount.
  - `dev/spikes/spike-batch-fill-writes.md` (Spike 4): add a
    correction header noting the spike measured live-mode INSERTs,
    not default-buffered-mode INSERTs. Point at LDG-2490 as the
    correct lane for the default durable path. Reclassify Spike 4 as
    "applies only to live mode" rather than "lead lane for v0.1.8.9".
- **README updates** in
  `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/README.md`:
  - Update Spike 4's headline cell to reflect the live-mode-only scope.
  - Update Spike 7's headline cell to reference LDG-2491's measured
    durable recovery.
  - Add Spike 11 and Spike 12 rows to the table.
  - Update the cross-cutting coding rule section: the buffer can be a
    list OR an env; the mechanism is the per-row column write under
    transient refcount bump. Note that the fix has now been validated
    at FOUR sites (B0 + Spikes 6, 7, 11).
- **Re-submit to Codex** for verification. Use the same peer-review
  prompt structure as the original review, scoped to verify that the
  corrections accurately address findings 1, 2, and 3 and that the
  measured numbers replace the over-projected estimates.

### Acceptance Criteria

- All synthesis updates landed and verifiable against the LDG-2490 and
  LDG-2491 spike logs.
- All spike log corrections landed without rewriting the underlying
  evidence (only the wording / scope clarifications change).
- README updates landed; Spike 11 and Spike 12 rows added; Spike 4
  reclassified.
- Codex re-review returns approve / approve with minor caveats. Block
  is not acceptable for this ticket to close.
- The v0.1.8.9 spec packet can now be cut against the synthesis.

### Verification

Manual review of the synthesis against the spike logs. Codex re-review
returns sign-off. The v0.1.8.9 spec writer can pull from the synthesis
without encountering the three blocking issues Codex identified.

### Source Reference

- Codex peer-review response (recorded as the response to the
  peer-review prompt drafted alongside the synthesis).
- `dev/spikes/spike-persistent-handler-buffer.{R,md}` (LDG-2490 output)
- `dev/spikes/spike-chunked-extractor-wall-recovery.{R,md}` (LDG-2491
  output)
- `R/backtest-runner.R:415-437` (the persistent durable handler)
- `R/backtest.R:1021-1276` (the chunked extractor)

### Classification

```yaml
type: documentation_revision
surface: spike_round_synthesis
scope: post_peer_review_corrections
```

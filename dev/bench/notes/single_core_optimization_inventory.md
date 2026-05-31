# Single-Core Optimization Inventory

Created: 2026-05-31
Scope: All single-core ledgr engine optimizations identified across LDG-2476
(three-phase peer benchmark) and LDG-2479 (self-profiling workload grid),
regardless of v0.1.8.9 scoping decisions.

This is the v0.1.8.9 spec input. It is not a v0.1.8.9 ticket. Each item below
records:

- **What** the candidate optimization is, and **where** in the codebase it lives.
- **Evidence status** (measured / inferred / hypothesized).
- **Simulation status** (sim-confirmed / sim-confirmable / profile-needed).
- **Mechanism hypothesis** (the load-bearing assumption being tested).
- **Suggested verification** (the minimum experiment that confirms or rejects).

The discipline mirrors the v0.1.8.7 optimization round captured in
`inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd`: every
candidate goes through spike-or-simulation to establish mechanism, then
real-run re-profile on a fixed workload to confirm wall-time impact, before
any production code changes land.

## Status Legend

**Evidence status** (what we already know):

- `MEASURED`: confirmed by wall-time or phase delta in the LDG-2479 workload
  grid record or the LDG-2476 peer benchmark record. We have a number.
- `INFERRED`: identified by reading the relevant code path. We can see the
  mechanism but have not isolated its cost.
- `HYPOTHESIZED`: speculation from architectural reasoning. The mechanism
  could exist but is not visible in either the code we have read or the
  measurements we have run.

**Simulation status** (what we can find out cheaply):

- `SIM-CONFIRMED`: an isolated reproducer has already shown the mechanism is
  real (no v0.1.8.9 candidate currently carries this label).
- `SIM-CONFIRMABLE`: a small isolated R script can prove or reject the
  mechanism in under an hour. Most A/B/C-class items below sit here.
- `PROFILE-NEEDED`: only a real-run Rprof on a grid cell will surface this.
- `N/A`: the cost is structural and not amenable to isolated simulation
  (e.g., snapshot creation wall time).

Both classifications are independent. An item can be `MEASURED` but
`PROFILE-NEEDED` (we know the wall-time but not the line-level attribution).
An item can be `INFERRED` and `SIM-CONFIRMABLE` (we see the loop in the code
and can build a synthetic refcount-elevated copy test).

## Reference workload for verification

Unless an item specifies otherwise, the canonical before/after measurement
cell is `density_high_xlarge_durable` from the LDG-2479 grid (1000
instruments x 1260 daily bars, SMA 5/10 crossover, durable). It currently
runs in 445.02s wall, 413.47s loop, 197.11s fills extract.

The secondary cell is `density_high_large_durable` (500 x 1260, same
strategy). Both should improve for a scaling fix; xlarge alone improving is
suspicious because it suggests a constant-cost win rather than a scaling
win.

## A. Per-Pulse Fold Loop (Hot Path)

| ID | Optimization | Code location | Evidence | Sim status | Expected impact (xlarge) |
| --- | --- | --- | --- | --- | --- |
| A1 | Vectorize per-pulse position valuation | `R/fold-engine.R:164-170` | INFERRED | SIM-CONFIRMABLE | ~9s of 413s loop |
| A2 | Vectorize per-target delta computation, iterate only non-zero | `R/fold-engine.R:277-359` | INFERRED | SIM-CONFIRMABLE | ~12s of 413s loop |
| A3 | Replace named-vector `state$positions` with environment or integer-indexed numeric | `R/fold-engine.R:354-355` | INFERRED | SIM-CONFIRMABLE | ~1.5s of 413s loop |
| A4 | Replace per-pulse SHA-256 + canonical_json in pulse_seed with cheaper deterministic mixer | `R/rng.R:33-57` | MEASURED (small) | SIM-CONFIRMABLE | ~0.25s at 1260 pulses |
| A5 | Reuse ctx list across pulses instead of fresh allocation per pulse | `R/fold-engine.R:180-194` | INFERRED | SIM-CONFIRMABLE | Unknown; bounded by 1260 allocations |
| A6 | Skip `ledgr_update_pulse_context_helpers` allocation when fast_context already cached | `R/pulse-context.R` | INFERRED | PROFILE-NEEDED | Unknown |
| A7 | One-time normalization of `active_alias_map` outside the loop | `R/fold-engine.R:61, 204-218` | INFERRED | SIM-CONFIRMABLE | Low |
| A8 | Skip telemetry accumulator zero-init when stride is 0 | `R/fold-engine.R:140-147` | MEASURED (small) | SIM-CONFIRMABLE | Sub-second |
| A9 | Replace `[[id]]` named-list lookups with vector subset (subsumed by A1-A3) | throughout fold-engine | INFERRED | SIM-CONFIRMABLE | Subsumed |

### A1, A2, A3 simulation plan (the headline lane)

**Mechanism hypothesis:** Per-pulse O(n_inst) R-interpreted loops dominate
non-fill engine time. Vectorizing them reduces engine work proportionally to
universe size and flattens the per-fill cost curve.

**Isolated simulation (one R script):**

1. Build a synthetic `state$positions` named numeric vector of length 1000.
2. Build a `bars_mat$close` matrix of size 1000 x 1260.
3. Run the current per-pulse position valuation loop 1260 times. Record wall.
4. Run the vectorized replacement `sum(as.numeric(state$positions) * bars_mat$close[, i])` 1260 times. Record wall.
5. Verify byte-identical output of the two paths on a fixture across all 1260 pulses.
6. Repeat for A2 (target loop) and A3 (state mutation) with their isolated reproducers.

**Expected sim signature:** A1 should show ~10x-100x speedup per pulse on
the isolated loop alone. A2 should show similar magnitude. A3 should show a
smaller but visible difference (the copy-on-write only fires under
refcount-elevated conditions). If A3's isolated simulation does not show a
difference, build a second variant where `state$positions` is captured by a
held reference (mimicking the ctx list closure) to force refcount > 1.

**Real-run gate:** Apply each fix individually to `R/fold-engine.R`, re-run
`density_high_xlarge_durable` and `density_high_large_durable`, confirm
`t_loop_sec` drops on both, confirm `mus_per_fill_engine` flattens between
large and xlarge (the scaling curve becomes less super-linear).

**Parity gate:** All `tests/testthat/` tests pass byte-identically. Peer
benchmark Tier 1 parity within float-noise tolerance. Workload grid scenario
definitions unchanged.

### A4 simulation plan

**Mechanism hypothesis:** SHA-256 + canonical_json per pulse adds ~200us
per pulse to engine time. Total impact at 1260 pulses is ~0.25s, small but
non-zero.

**Isolated simulation:** time 1260 calls to `ledgr_derive_pulse_seed(42L,
1:1260)` vs 1260 calls to a cheap deterministic mixer (e.g., xoshiro128
seeded from `(execution_seed, pulse_idx)`).

**Decision rule:** if total simulation cost is < 1s at 1260 pulses, this is
not a v0.1.8.9 candidate. Park.

### A5, A6 profile plan

**Mechanism hypothesis:** Per-pulse list allocations and accessor
attachments contribute to engine time at high pulse counts (5000+ pulses).

**Required diagnostic:** Rprof pass on `density_high_xlarge_durable` with
`line.profiling = TRUE, memory.profiling = TRUE`. If A5/A6 do not appear in
the top-10 self-time, drop them from the v0.1.8.9 candidate stack.

## B. Per-Fill Operations (Event Emission)

| ID | Optimization | Code location | Evidence | Sim status | Expected impact (xlarge) |
| --- | --- | --- | --- | --- | --- |
| B1 | Batch DuckDB `write_fill_events` — chunked inserts of 100-1000 fills | `R/fold-engine.R:336-340` + handler | MEASURED (gap) | SIM-CONFIRMABLE | 30-80s estimated |
| B2 | Replace `b[i+1L, , drop=FALSE]` per fill with pre-extracted next-open price matrix | `R/fold-engine.R:290` | INFERRED | SIM-CONFIRMABLE | Unknown, mechanical |
| B3 | Inline `ledgr_next_open_fill_proposal()` if profile shows per-fill function-call dominance | `R/fold-engine.R:291-294` | HYPOTHESIZED | PROFILE-NEEDED | Unknown |
| B4 | Inline cost_resolver if profile shows per-fill dispatch dominance | `R/fold-engine.R:300` | HYPOTHESIZED | PROFILE-NEEDED | Unknown |
| B5 | Pre-build integer-indexed bars structure (subsumed by B2) | `R/fold-engine.R:289` | INFERRED | SIM-CONFIRMABLE | Subsumed |
| B6 | Lot-map update per fill (FIFO accounting) — depends on opening-position bug fix first | downstream | HYPOTHESIZED | PROFILE-NEEDED | Unknown |
| B7 | `event_seq` increment + flush bookkeeping per fill | `R/fold-engine.R:336-346` | HYPOTHESIZED | PROFILE-NEEDED | Likely low |

### B1 simulation plan (the next-largest lane after A1-A3)

**Mechanism hypothesis:** Per-fill DuckDB row insertion has a per-call
overhead (transaction, statement parse, write-ahead log fsync) that
dominates the actual write time. Batching N fills into one insert
amortizes that overhead by N.

**Isolated simulation:**

1. Open a fresh DuckDB connection. Create a fills table matching ledgr's
   ledger schema.
2. Insert 68,000 single-row INSERTs. Record total wall and per-fill cost.
3. Insert the same 68,000 rows as 68 batches of 1000. Record wall.
4. Insert as 680 batches of 100. Record wall.
5. Plot batch-size vs per-fill cost; identify the knee.

**Expected sim signature:** Per-fill cost should drop sharply between
batches of 1 and batches of 100, with diminishing returns past 1000.

**Real-run gate:** Implement chunked writes in the durable output handler
(simplest version: buffer N events in memory, flush on N=512 or fold end).
Re-run xlarge cell, confirm `t_loop_sec` drops, confirm parity, confirm the
durable event log replays byte-identically.

**Parity-gate risk:** Batched writes must preserve event ordering, ts_utc
monotonicity within instrument, and seq integer continuity. The grow-by-
doubling buffer pattern from B0 in v0.1.8.7 is the model: small initial
buffer, double on growth, flush on capacity or pulse boundary.

### B2 simulation plan

**Mechanism hypothesis:** `b[i+1L, , drop=FALSE]` on a tibble or data.frame
allocates a new sub-frame per fill, with class dispatch overhead. Replacing
with `bars_mat$open[next_inst_idx, i+1L]` (matrix scalar lookup) is O(1)
with no allocation.

**Isolated simulation:** time 68,000 row subsets of a 1260-row tibble vs
68,000 matrix scalar lookups. Difference should be 10x-100x.

**Real-run gate:** apply, re-measure, confirm.

### B3, B4, B6, B7 profile plan

**Mechanism hypothesis:** Function-call dispatch overhead at 68k-130k fills
is material. Inlining hot paths might recover seconds.

**Required diagnostic:** Rprof pass with `function-level profiling enabled.
If any of these appear in top-10 self-time, promote to v0.1.8.9 candidate.
If not, park.

## C. Memory Output Handler (Ephemeral Path)

| ID | Optimization | Code location | Evidence | Sim status | Expected impact (xlarge) |
| --- | --- | --- | --- | --- | --- |
| C1 | Memory output handler per-fill cost reduction | `R/fold-event-buffer.R` + handler | MEASURED | SIM-CONFIRMABLE | ~16s at 68k fills |
| C2 | Memory output handler buffer growth pattern | internal handler | MEASURED | SIM-CONFIRMABLE | Tens of seconds at xlarge |
| C3 | Expose per-pulse telemetry on ephemeral sweep path | `bench_run_sweep_once` + sweep internals | MEASURED (gap) | N/A | Required for fix targeting, no direct savings |

### C1, C2 simulation plan

**Mechanism hypothesis:** The memory output handler uses the same B0
event-buffer grow-by-doubling helper as durable, but it accumulates ALL
events for the run before reconstruction. At 133k fills the buffer's final
size is large, and the per-fill append cost may have a hidden O(n_events)
component (e.g., from name-vector or metadata-list growth).

**Isolated simulation:** instantiate a `ledgr_memory_output_handler()`
directly. Push 133k synthetic fill events in a loop. Measure per-event
elapsed at intervals (every 1000th event). If per-event cost grows with
event count, the mechanism is confirmed and the fix targets the growth
pattern in the handler.

**Real-run gate:** apply, re-measure ephemeral xlarge cell. Confirm
ephemeral engine phase improves toward durable engine phase.

### C3 (telemetry exposure)

**Mechanism hypothesis:** N/A. The ephemeral sweep path currently does not
surface `t_loop_sec`, `t_pre_sec`, or per-result-call timings. Without
those numbers we cannot attribute the +178.85s xlarge ephemeral delta to
engine vs results phases.

**Required work:** wire `bench_run_sweep_once` to read the sweep's
internal telemetry env (the same `ledgr_sweep_telemetry_env()` already used
by the ephemeral peer benchmark row). Add phase columns to the sweep CSV
output. This is bench-harness work, not engine work.

**Real-run gate:** re-run xlarge ephemeral with telemetry exposed; the
+178.85s gap should now decompose into engine vs results contributions.

## D. Post-Run Results Materialization

| ID | Optimization | Code location | Evidence | Sim status | Expected impact (xlarge) |
| --- | --- | --- | --- | --- | --- |
| D1 | Rewrite `ledgr_results(bt, "fills")` for scale | `R/fold-reconstruction.R` durable path | MEASURED | SIM-CONFIRMABLE | ~80s at 68k, ~200s at 133k |
| D2 | Fix `ledgr_results(bt, "fills")` returning no row count at xlarge | same | MEASURED (bug) | SIM-CONFIRMABLE | Robustness, not perf |
| D3 | In-memory event-stream reconstruction (`ledgr_equity_from_events`, `ledgr_fills_from_events`) | `R/fold-reconstruction.R` | MEASURED | SIM-CONFIRMABLE | ~40s at 68k fills |
| D4 | `ledgr_results(bt, "equity")` reconstruction at extreme scale | same module | INFERRED | PROFILE-NEEDED | Low on SMA workloads |
| D5 | Investigate 8e-9 DuckDB equity round-trip noise | durable reconstruction path | MEASURED | SIM-CONFIRMABLE | Correctness/discipline win |

### D1 simulation plan (the largest single-lane wall-time win)

**Mechanism hypothesis:** The current `ledgr_results(bt, "fills")` follows
the same list-of-data.frames + `do.call(rbind, ...)` anti-pattern documented
in the v0.1.8.7 round (Batch 6, Lane C). At 13,355 fills the old pattern
took 6.75s; at 68,324 fills it takes 82.28s. That super-linear scaling
(13.5x slower for 5.1x more fills) is the exact O(N^2) signature of
iterative `rbind`.

**Isolated simulation:**

1. Build a synthetic events table of 68k rows matching the ledger schema.
2. Run the current `ledgr_results(bt, "fills")` path on it. Time it.
3. Build a primitive-column rewrite (per the v0.1.8.7 Lane C pattern):
   preallocate one typed vector per column, fill by index in the loop,
   materialize the data.frame once at the end.
4. Run both paths on event tables of {13k, 30k, 68k, 130k} rows. Plot
   scaling.

**Expected sim signature:** Current path scales super-linearly (O(N^2) or
worse). Rewrite scales linearly. Crossover where rewrite wins should be at
or below 10k fills.

**Real-run gate:** apply the rewrite, re-run xlarge cell, confirm
`fills_extract_sec` drops from 197s to a small number. Confirm the durable
ledger is byte-identical to pre-rewrite (this is a reconstruction-only
change, not an event-write change).

**v0.1.8.7 prior art:** Batch 6 already did this rewrite for the durable
fills path and got 1.68x on 13k fills. The fact that we are now seeing
super-linear scaling at 68k and 133k suggests either (a) a regression to
the old pattern in some sub-path, or (b) a second O(N^2) site that the
v0.1.8.7 rewrite did not catch. Either way, the rewrite mechanism is
already established.

### D2 simulation plan

**Mechanism hypothesis:** At ~133k fills, `ledgr_results(bt, "fills")`
returns a result whose row count cannot be determined by `nrow()`. Possible
causes: the query returns a lazy-evaluated DuckDB cursor that errors on
materialization; the chunked reader silently drops rows; memory pressure
kills the conversion to data.frame.

**Required diagnostic:** instrument `ledgr_results(bt, "fills")` to log
intermediate stages (query plan, chunk count, row count per chunk,
materialization wall). Run on `density_high_xlarge_durable`. Identify which
stage fails.

**Real-run gate:** once the failure stage is identified, fix the relevant
boundary. Confirm `nrow(ledgr_results(bt, "fills")) == events_count` at
xlarge.

### D3 simulation plan

**Mechanism hypothesis:** `ledgr_equity_from_events()` and
`ledgr_fills_from_events()` walk the in-memory event list with the same
list-of-data.frames anti-pattern. The ephemeral results phase shows
+40.9s vs durable on the same fills count, even though both paths
reconstruct from the same data.

**Isolated simulation:** same scaling experiment as D1 but on the in-memory
event functions. Compare against rewrites that use the primitive-column
pattern.

**Real-run gate:** rewrite, re-run xlarge ephemeral, confirm
`results_sec` drops materially.

### D5 (float noise investigation)

**Mechanism hypothesis (open):** DuckDB stores DOUBLE which is identical
to R numeric IEEE 754, so a pure round-trip should be byte-identical. The
8e-9 noise indicates one of: (a) DuckDB internally promotes/demotes through
DECIMAL or NUMERIC; (b) the reconstruction uses a different accumulation
order than the in-memory equity walk; (c) a cast to/from a different
precision somewhere in the chunked reader path.

**Isolated simulation:** write a 100-element double vector to DuckDB, read
it back, compare byte-by-byte with the original. If identical, the
mechanism is accumulation order (b). If differs, it is DuckDB precision (a)
or cast (c).

**Decision rule:** if accumulation order, document it as expected and keep
the 1e-8 parity tolerance. If precision or cast, fix the responsible
boundary and restore byte-identical parity.

## E. Ingestion / Snapshot Creation

| ID | Optimization | Code location | Evidence | Sim status | Expected impact |
| --- | --- | --- | --- | --- | --- |
| E1 | `ledgr_snapshot_from_df` at 630k rows | `R/snapshots-create.R`, `R/snapshots-import-bars.R` | MEASURED | SIM-CONFIRMABLE | ~12s flat |
| E2 | Harness-side CSV read | `peer_run_ledgr` | MEASURED | SIM-CONFIRMABLE | Harness only |
| E3 | Harness-side `as.POSIXct` | same | MEASURED | SIM-CONFIRMABLE | Harness only |
| E4 | DuckDB seal/hash inside snapshot creation | `R/snapshots-seal.R`, `R/snapshots-hash.R` | INFERRED | PROFILE-NEEDED | Bounded |

### E1 profile plan

**Mechanism hypothesis (open):** Snapshot creation at 12s is more than the
sum of "write a 630k-row DuckDB table" should be. Suspects: per-row
canonical metadata serialization, per-row type validation,
backstop-precision checks (the sub-second rejection added in v0.1.8.7), and
the snapshot seal hash pass over all bars.

**Required diagnostic:** Rprof pass on `ledgr_snapshot_from_df` only,
called against a 1000 x 1260 synthetic bars df. Identify top self-time.

**Decision rule:** if E1 cost can be attributed to a small number of named
functions, file v0.1.8.9 tickets. If diffuse, park.

### E2, E3 (harness only)

Not product code, no engine implication. Park unless harness wall becomes a
documentation problem.

## F. Indicator / Feature Engine

| ID | Optimization | Code location | Evidence | Sim status | Expected impact |
| --- | --- | --- | --- | --- | --- |
| F1 | `series_fn` dual-API on `ledgr_indicator()` for vectorized fast path | `R/indicator.R` + pre-compute path | HYPOTHESIZED (parked) | SIM-CONFIRMABLE | 3.5x previously observed on custom ATR20 |
| F2 | Session-scoped feature cache by `(snapshot_id, indicator_fingerprint)` | engine / cache layer | HYPOTHESIZED | SIM-CONFIRMABLE | Amortizes across sweep candidates |
| F3 | Confirm TTR fast path always beats builtin (diagnostic) | `R/indicator-ttr.R`, `R/indicator-builtins.R` | MEASURED | N/A | Working as expected |

### F1, F2 status (parked from v0.1.8.9 lead lanes)

The growing-window O(n_inst x n_bars) cost the prior project memory flagged
is **NOT the dominant cost on SMA workloads**: `t_pre_sec` stays at 0.9s -
2.75s across all grid cells. F1 + F2 remain useful for non-vectorized
custom-R indicator users, but they are not on the v0.1.8.9 lead lane.

If a v0.1.8.9 user reports slow indicator performance with custom-R features,
revisit. Until then, parked.

## G. Strategy Callback Overhead

| ID | Optimization | Code location | Evidence | Sim status | Expected impact |
| --- | --- | --- | --- | --- | --- |
| G1 | `ledgr_call_strategy_fn` signature dispatch per pulse | `R/fold-engine.R:230-238` | INFERRED | PROFILE-NEEDED | Small |
| G2 | `ledgr_validate_strategy_targets` per pulse — input validation | `R/fold-engine.R:263-266` | INFERRED | PROFILE-NEEDED | Small |
| G3 | `ledgr_apply_target_risk_noop` per pulse — currently a no-op layer | `R/fold-engine.R:267` | INFERRED | PROFILE-NEEDED | Very small |
| G4 | Strategy preflight analysis growth | `R/strategy-preflight.R` | MEASURED (small) | N/A | Sub-second one-time |

All G-class items require Rprof confirmation before scoping. Profile pass
will show whether any are top-10 contributors. If not, park.

## H. State Persistence (Strategy `state_update`)

| ID | Optimization | Code location | Evidence | Sim status | Expected impact |
| --- | --- | --- | --- | --- | --- |
| H1 | `canonical_json` per pulse on `state_update` | `R/fold-engine.R:363` | MEASURED | SIM-CONFIRMABLE | ~15s at 1260 pulses on stateful crossover |
| H2 | `output_handler$write_strategy_state` per pulse | `R/fold-engine.R:366-369` | MEASURED | N/A (batched by buffered mode) | Same as H1 |
| H3 | `output_handler$buffer_strategy_state` flush sizing tunable | same | HYPOTHESIZED | PROFILE-NEEDED | Low |

### H1 simulation plan

**Mechanism hypothesis:** `canonical_json` on a 500-instrument state object
costs ~12 ms per pulse (10.3 MB JSON / 1260 pulses). At 1260 pulses, total
is ~15s. This is only paid by strategies that emit `state_update`; baseline
strategies pay 0.

**Isolated simulation:** time 1260 calls to `canonical_json()` on a
synthetic 500-instrument state object. Compare against alternative
encodings: (a) base R `serialize()` to raw, (b) `qs::qserialize`, (c)
a length-prefixed flat encoding similar to the v0.1.8.7 feature cache key.

**Decision rule:** if a cheaper encoding preserves byte-identical
deterministic replay, fix. If the encoding choice is load-bearing for
audit-log equivalence, park.

**Parity-gate risk:** state_update bytes are part of the durable run
identity. Changing the encoding requires migration tooling or pre-CRAN
break.

## I. Parallel / Dispatch Infrastructure

| ID | Optimization | Code location | Evidence | Sim status | Expected impact |
| --- | --- | --- | --- | --- | --- |
| I1 | Parallel-workers dispatcher one-time setup at single worker | `R/parallel-workers.R` | INFERRED | SIM-CONFIRMABLE | Bounded one-time |
| I2 | Execution spec validation (~20 checks) | `R/execution-spec.R:103-223` | MEASURED (small) | N/A | < 0.01s |

I1: time a no-op single-worker dispatch loop, isolated. Compare to
sequential. Only act if > 1s.

## J. Telemetry / Diagnostic Overhead

| ID | Optimization | Code location | Evidence | Sim status | Expected impact |
| --- | --- | --- | --- | --- | --- |
| J1 | `ledgr_time_now()` per sampled pulse (9 calls when stride > 0) | `R/fold-engine.R:140-162` | MEASURED (small) | SIM-CONFIRMABLE | Sub-second at production stride |
| J2 | Telemetry slot writes (8 fields per sampled pulse) | `R/fold-engine.R:382-391` | MEASURED (small) | SIM-CONFIRMABLE | Sub-second |

J1, J2 are off by default in record runs (stride 0). Documented for
completeness.

## K. Broader Architectural Levers (Longer Horizon)

| ID | Lever | Scope | Status |
| --- | --- | --- | --- |
| K1 | Compiled fold core (`ledgrcore` sister package, byte-identical event-stream parity) | Major restructure | RECORDED in v0.1.8.8 spec, gated on v0.1.8.9 measurement |
| K2 | Phased pulse for portfolio-level risk | Architecture change | DEFERRED in v0.1.8.8 spec |
| K3 | Batch-aware transaction cost / liquidity model | Cost model change | DEFERRED in v0.1.8.8 spec |
| K4 | Matrix-canonical public strategy surface | Public API change | DEFERRED in v0.1.8.8 spec |
| K5 | One production replay kernel | Major restructure | DEFERRED in v0.1.8.8 spec |

K1 (compiled core) becomes a credible question only after A1-A3, B1, D1, D3
land and the residual engine gap to Backtrader is re-measured. If the
remaining gap is < 1.5x after the cheap fixes, K1 has insufficient Amdahl
headroom. If it's > 2x, K1 is the next conversation.

## L. Robustness Gaps (Adjacent to Perf)

| ID | Gap | Location | Evidence | Status |
| --- | --- | --- | --- | --- |
| L1 | `ledgr_results(bt, "fills")` returns no row count at xlarge | grid xlarge durable cell | MEASURED | CONFIRMED bug, bundled with D2 |
| L2 | Opening-position cost basis not seeded into lot map | 5 locations needing shared FIFO helper | MEASURED elsewhere | Pre-existing release blocker, separate from v0.1.8.9 perf |

## Measurement and Simulation Methodology

Lifted verbatim from the v0.1.8.7 cycle (see
`inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd`,
section "Lessons learned"). Three principles are load-bearing:

### Principle 1: Spike to confirm mechanism, real-run to confirm magnitude

For every candidate in this inventory, the workflow is:

1. **Isolated simulation** (the "spike"): a small R script that reproduces
   the suspected mechanism in isolation. The output is a per-call cost and
   a scaling signature.
2. **Mechanism confirmation**: the spike either confirms or rejects the
   hypothesis. If rejected, the candidate is parked.
3. **Production prototype**: implement the fix in `R/fold-engine.R` (or
   wherever applies), preserving public APIs and byte-identical event
   stream.
4. **Real-run re-profile**: re-run `density_high_large_durable` and
   `density_high_xlarge_durable` on the workload grid. The wall delta on
   both cells is the production verdict.
5. **Parity gate**: all `tests/testthat/` byte-identical. Peer benchmark
   Tier 1 within tolerance. Workload grid scenario definitions unchanged.

**Why both steps:** isolated micro-benchmarks lie. They use synthesized
data with idealized refcount conditions that do not match production. The
spike establishes mechanism; the real run establishes magnitude. Several
candidates in this inventory could pass an isolated benchmark and fail to
deliver a wall improvement because of Amdahl's law (small slice of total
time) or hidden interactions with the surrounding R code.

### Principle 2: Within-run share is more honest than wall-to-wall comparison

For wall-time across runs, local CPU power-profile drift can silently
inflate or deflate the apparent speedup. Always report the within-run
share of R-level time as the apples-to-apples claim, and use wall-to-wall
as a sanity check on direction (faster, slower, no change) without
quantitative weight.

For the workload grid, this means: report `t_loop_sec` deltas and
`mus_per_fill_engine` deltas as the primary claims. Report `t_wall_sec`
direction as sanity, not magnitude.

### Principle 3: Amdahl is non-negotiable

Before implementing any candidate, compute the maximum possible wall
improvement using Amdahl:

```text
max_wall_speedup = 1 / ((1 - p) + p / s)
```

where `p` is the fraction of total wall the candidate addresses and `s` is
the achievable speedup on that fraction. Most candidates in this inventory
have `p < 0.05` on the xlarge cell, so `s = infinity` still caps the wall
win at 5%. That is fine as long as the candidate ticket scopes the work
appropriately and does not over-promise.

The candidates with `p > 0.05` are:

- B1 (batch fill writes): if writes are ~25% of loop, `p ~ 0.25` of wall.
- D1 (fills reconstruction rewrite): `p ~ 0.20` of wall on xlarge.
- A1 + A2 + A3 combined: `p ~ 0.05` of wall, but flatten the scaling
  curve, which is the architectural win.

Everything else is < 5% Amdahl headroom on the reference cell. They may
still be worth fixing for code clarity, robustness, or for workloads
where the cell composition is different. But they are not the headline
v0.1.8.9 candidates.

### Principle 4: Pre-CRAN means we can break things

Most of the candidates in this inventory would be impossibly expensive
with users in the field. The named-list `state$positions` representation,
the canonical_json encoding for `state_update`, the cost_resolver dispatch
contract — each would require deprecation cycles, dual-path support, and
migration tooling under a stable public API.

Pre-CRAN status means we can change these directly. Aggressive cleanup of
performance-critical paths now is cheaper than ever. Every removable
surface that survives to CRAN is a long-term maintenance liability.

### Principle 5: Sim-confirmed before implementation

For each `SIM-CONFIRMABLE` candidate above, the sequence is:

1. Write the simulation script under `dev/bench/spikes/` with a clear name
   (e.g., `spike-position-valuation-vectorize.R`).
2. Run it. Record before/after numbers and the scaling signature.
3. Write a one-paragraph spike note in
   `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/`
   documenting mechanism, measurement, and decision (proceed / park).
4. Cut the v0.1.8.9 ticket with the spike note as the load-bearing source.
5. Implement, re-profile, parity-gate, merge.

This is the v0.1.8.7 B0 workflow applied to v0.1.8.9. It is slow per
candidate but cheap to verify and easy to defend.

## Suggested v0.1.8.9 Lane Sequence

Ordered by combination of confirmed Amdahl headroom, simulation
confirmability, and blast radius.

| Lane | Candidate | Why this position |
| --- | --- | --- |
| 1 | D1 + D2 (fills reconstruction rewrite + xlarge robustness) | Largest measured impact (~80-200s xlarge), prior art from v0.1.8.7 Batch 6, robustness gap surfaced in grid run |
| 2 | B1 (batch fill writes) | Next-largest expected impact, simple mechanism, established pattern |
| 3 | A1 + A2 + A3 (per-pulse loop vectorization) | Flattens scaling curve, biggest architectural win, three mechanical fixes |
| 4 | D3 (in-memory event reconstruction) | Same rewrite pattern as D1, applies to ephemeral path |
| 5 | C1 + C2 + C3 (memory output handler + ephemeral telemetry) | Required to make ephemeral row a viable diagnostic; cost reduction unblocks future fast-path discussion |
| 6 | H1 (state_update encoding) | Only matters for `state_update` strategies; conditional priority |
| 7 | E1 (snapshot creation) | Fixed cost; amortizes at scale; low priority unless small-workload UX matters |
| 8 | A4-A9, B2-B7, G1-G4, J1-J2 (cleanup / micro) | Profile-confirm before scoping |
| 9 | F1 + F2 (series_fn / cache) | Only matters for non-vectorized custom-R indicators; conditional |
| 10 | K1 (compiled fold core) | Decision point after lanes 1-5 land and engine gap is re-measured |

This is a proposal, not a commitment. Final v0.1.8.9 lane order should be
set in the v0.1.8.9 spec after the spike scripts in lanes 1-3 produce
mechanism numbers.

## What This Document Is Not

- Not authorization to change `R/fold-engine.R` or any other production
  source. Cut v0.1.8.9 tickets first, with spike notes attached.
- Not a public performance claim. Numbers are local-host, current-source,
  ledgr-only.
- Not a contract change. Public APIs (`ledgr_run`, `ledgr_sweep`,
  function-strategy contract) remain unchanged through these fixes.
- Not a parallel-dispatch story. Single-core hot-path work lands before
  parallelism becomes the answer.

## Source Evidence

- `dev/bench/results/ledgr_bench_record_20260531T132910Z_summary.csv` —
  LDG-2479 workload grid baseline record.
- `dev/bench/notes/workload_grid_baseline_closeout.md` — grid closeout.
- `dev/bench/notes/per_pulse_complexity_findings.md` — diagnosis of A1-A3.
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md`
- `dev/bench/peer_benchmark/notes/ledgr_regression_source_analysis.md`
- `inst/design/horizon.md`, `2026-05-31 [optimization] LDG-2476
  peer-benchmark turnover cost decomposition` entry.
- `inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd` — prior
  cycle methodology and B0 reference fix.
- `R/fold-engine.R` per-pulse loop body.
- `R/fold-reconstruction.R` durable results path.
- `R/fold-event-buffer.R` event buffer (the v0.1.8.7 B0 helper).

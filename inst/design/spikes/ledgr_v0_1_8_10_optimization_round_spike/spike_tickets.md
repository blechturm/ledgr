# v0.1.8.10 Optimization-Round Spike Tickets

Version: v0.1.8.10-pre-rfc
Date: 2026-06-01
Total Tickets: 11 (LDG-2505..LDG-2515)
Status: Archival (see Status Metadata Disclaimer below)

## Status Metadata Disclaimer

This file is **pre-RFC archival scaffolding**, not active governance
metadata. The per-ticket `Status: Pending` headers and the
`status: "pending"` entries in `tickets.yml` reflect ticket creation state.
Statuses are not actively maintained as the spikes execute, the synthesis
gets written, or peer reviews close. The load-bearing artifacts for the
round's current state are:

- `architecture_synthesis.md` (written after all spikes complete; the
  Codex-reviewed synthesis is the implementation-scope input).
- The per-spike logs under `dev/spikes/spike-*.md` (each carries the
  authoritative proceed/park decision).
- `README.md` for the round-level summary table.

When the v0.1.8.10 spec packet is cut from the synthesis, this ticket file
is archived alongside the round directory.

## Ticket Organization

This file holds ticket entries for the v0.1.8.10 pre-RFC spike investigation
documented in `README.md`. These tickets do **not** belong to the v0.1.8.9
release packet (`inst/design/ledgr_v0_1_8_9_spec_packet/`), and do not
gate the v0.1.8.9 release. They are pre-RFC investigation feeding the
v0.1.8.10 single-core optimization spec packet (the closing round of the
v0.1.8.x single-core arc).

The structure follows the v0.1.8.9 spike-round ticket markdown format.
Numbering continues from v0.1.8.9 (last ticket LDG-2504) so LDG numbers
remain monotonic across releases.

Each spike ticket follows the v0.1.8.7 spike-round model: write a
self-contained R script (or compiled-core scaffold for Spike 12) under
`dev/spikes/`, run it, write a paired log under `dev/spikes/spike-<name>.md`
documenting the mechanism evidence and the Amdahl-bounded wall translation,
and record a proceed-or-park decision in the log.

## Priority Levels

- P0: Round-kickoff, synthesis revision, or load-bearing architectural gate
  (Spike 12 K1 measurement spike falls here).
- P1: Spike on a candidate with `MEASURED` evidence and large estimated
  impact on the reference cell. These spikes feed the v0.1.8.10 spec's
  headline lanes.
- P2: Spike on a candidate with `INFERRED` or `HYPOTHESIZED` evidence,
  or a smaller estimated impact. These spikes either confirm a secondary
  v0.1.8.10 candidate or are negative results that park the candidate.

## Dependency DAG

```text
Batch A (ephemeral redesign) and Batch B (substrate) run in parallel.
Batch C and Batch D run after Batch A confirms ephemeral path direction.

LDG-2505 Spike 1  - Inline equity accumulation
LDG-2506 Spike 2  - split() reconstruction bucket
LDG-2507 Spike 3  - state$positions primitive re-spike
LDG-2508 Spike 4  - Reusable pulse-context env
LDG-2509 Spike 5  - Integer-indexed strategy accessors
LDG-2510 Spike 6  - Next-bar matrix lookup re-spike
LDG-2511 Spike 7  - yyjsonr read-path recovery
LDG-2512 Spike 8  - Cheap pulse_seed mixer
LDG-2513 Spike 9  - active_alias_map normalization
LDG-2514 Spike 10 - Inline lot-state in memory handler
LDG-2515 Spike 11 - Ephemeral subphase telemetry
```

K1 / `ledgrcore` compiled-core measurement spike is out of v0.1.8.10
scope. It moved to a dedicated `ledgrcore-spike` repo per the horizon's
2026-06-01 K1 entry update, and is timed to run after v0.1.8.10 ships so
the comparison runs against post-v0.1.8.10 production R rather than a
substrate-emulated baseline. The horizon's K1 entry remains the
authoritative spec for what the spike must measure.

The cross-cutting synthesis (`architecture_synthesis.md`) is written after
the spikes complete. It is the load-bearing input for the v0.1.8.10 spec
packet.

---

## LDG-2505: Spike 1 - Inline Equity Accumulation In Memory Output Handler

Priority: P1
Effort: M
Dependencies: none (Spike 11 telemetry is helpful for attribution but not a
hard prerequisite; Spike 1 can run with wall-only attribution)
Status: Pending

### Description

Confirm or reject the hypothesis that replacing `ledgr_sweep_summary_from_ordered_events`
with an inline-equity-accumulation memory output handler eliminates the
reconstruction-pass cost on the ephemeral path.

Mechanism hypothesis: at `R/fold-reconstruction.R:376-572`, the current
reconstruction does a second pass over events to rebuild equity curve,
positions matrix, and lot state. The fold engine maintains `state$cash`
and `state$positions` during execution; per-pulse equity can be computed
inline as `state$cash + sum(state$positions * close_at_pulse)` and emitted
to a running equity vector. The memory output handler can then capture
this inline rather than accumulating events for later reconstruction.
Expected wall recovery on `density_high_xlarge_ephemeral`: 150-200s.

Decision rule: if isolated wall recovery > 100s at 130k events, proceed
to v0.1.8.10 lead implementation ticket. If < 30s, park (the reconstruction
pass isn't where the cost lives).

### Tasks

- Write `dev/spikes/spike-inline-equity-accumulation.R`.
- Build a synthetic events stream at scales {13.5k, 30k, 68k, 130k} events
  matching the LDG-2479 grid cells.
- Variant A: current memory output handler + `ledgr_sweep_summary_from_ordered_events`
  call path (the production baseline).
- Variant B: prototype memory output handler with inline equity vector
  accumulation per pulse + fills tibble appended during fold + no event-log
  accumulation.
- Variant C: hybrid — both event log AND inline equity, for the case where
  downstream consumers still want event-stream visibility.
- Verify byte-identical equity curve between variants on a fixture.
- Time each variant at each scale. Record per-event accumulated cost and
  per-pulse equity-computation cost separately.
- Write `dev/spikes/spike-inline-equity-accumulation.md` following the
  spike log template.

### Acceptance Criteria

- Spike script and log exist.
- Per-event and per-pulse costs reported across all four scales.
- Byte-identical equity vector parity confirmed for Variant B vs Variant A.
- Wall translation estimates production recovery on
  `density_high_xlarge_ephemeral` using Amdahl bounds.
- Log explicitly addresses whether Variant B can replace Variant A
  cleanly or whether Variant C is needed for compatibility (e.g., if
  downstream sweep candidates query the event log).
- Regression-test verification: new equity-parity test fails against the
  unfixed implementation (the production memory handler without inline
  accumulation).

### Verification

Re-run spike, review log. Confirm parity gate on fixture.

### Source Reference

- `R/fold-reconstruction.R:376-572` (ledgr_sweep_summary_from_ordered_events)
- `R/sweep.R` (memory output handler)
- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
  residual 1 (ephemeral reconstruction-pass cost)
- v0.1.8.9 Spike 6 / LDG-2485 (memory output handler scaling) for prior
  per-event cost baselines

### Classification

```yaml
type: spike
surface: memory_output_handler
scope: inline_equity_accumulation
```

---

## LDG-2506: Spike 2 - collapse::gsplit() / split() Over Per-Instrument which() In Reconstruction

Priority: P1
Effort: S
Dependencies: none
Status: Pending

### Description

Measure the standalone wall recovery from replacing the per-instrument
`which(events$instrument_id == id)` loop at
`R/fold-reconstruction.R:514-526` with a single bucket operation. Compare
base R `split()` against `collapse::gsplit()` based on prior v0.1.8.7
findings that collapse's grouped operations are materially faster than
their base R equivalents at production scale.

Mechanism hypothesis: the current loop runs O(n_inst x n_events) character
equality comparisons just to bucket events by instrument. At xlarge
(1000 inst x ~133k events) that is 133M character-equality comparisons.
Both `split(seq_along(events$instrument_id), events$instrument_id)` and
`collapse::gsplit(seq_along(events$instrument_id), events$instrument_id)`
reduce this to a single O(n_events) pass plus O(n_inst) bucket lookups.

**Prior collapse-vs-split finding**: v0.1.8.7 spike work showed
`collapse::gsplit()` is materially faster than base R `split()` at
production scale. Spike 2 measures both at the v0.1.8.10 reconstruction
shape to confirm the finding still holds and pick the right variant for
the production ticket.

This spike is largely subsumed if Spike 1 lands (which eliminates the
reconstruction pass entirely). It is worth measuring standalone as a
fallback for the case where Spike 1 doesn't pan out and the
reconstruction path stays.

### Tasks

- Write `dev/spikes/spike-reconstruction-split-bucket.R`.
- Build a synthetic events stream at scales {30k, 68k, 130k} events.
- Variant A: current per-instrument `which()` loop.
- Variant B: base R `split()`-based bucket lookup.
- Variant C: `collapse::gsplit()`-based bucket lookup.
- Verify byte-identical positions matrix output across variants.
- Time each variant at each scale, recording the collapse-vs-split delta
  explicitly so the prior v0.1.8.7 finding can be confirmed or refined
  at the new shape.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-instrument-loop, base R `split()`, and `collapse::gsplit()` costs
  reported across scales.
- Byte-identical positions matrix parity confirmed across all three
  variants.
- Wall translation explicitly notes whether Spike 1 subsumes this lane.
- Log explicitly states the collapse-vs-split speedup at the v0.1.8.10
  reconstruction shape and cross-references the v0.1.8.7 prior finding.
- Log states either "ship as Spike 1 fallback" or "subsumed by Spike 1; no
  separate ticket needed".

### Verification

Re-run spike, review log.

### Source Reference

- `R/fold-reconstruction.R:514-526` (per-instrument loop)
- v0.1.8.9 Spike 12 / LDG-2491 (chunked extractor) for related setv work
- v0.1.8.7 collapse-vs-split prior finding (prior cycle that established
  `collapse::gsplit()` materially beats base R `split()` at production
  scale)
- `inst/design/collapse_optimization_map.md` for the documented collapse
  usage doctrine

### Classification

```yaml
type: spike
surface: fold_reconstruction
scope: split_bucket_instrument_index
```

---

## LDG-2507: Spike 3 - state$positions Primitive Representation Re-Spike

Priority: P1
Effort: M
Dependencies: none
Status: Pending

### Description

Re-spike the `state$positions` primitive representation candidate at
production xlarge shape, post-v0.1.8.9. The v0.1.8.9 round measured this
as Spike 3 at 1000-element scale and found the wins modest (1.9x for
`intvec_id_map`, 1.9x for `collapse::setv`); the disposition was to defer
to v0.1.8.10+ / substrate audit per LDG-2502 triage.

The re-spike is part of the substrate-round investigation. The new
question is not "does it move a meaningful number standalone" but "does
it serve as substrate for compiled-core boundary cost reduction AND
deliver measurable R-side wins at the post-v0.1.8.9 shape." The Spike 12
K1 measurement spike depends on this spike's substrate-emulated R baseline.

Mechanism hypothesis: replacing named-vector `state$positions` with
integer-indexed numeric + one-time `id_to_idx` map gives O(1) lookups
instead of O(n_inst) named-vector scans. After Batches 4/5 (per-pulse
vectorize) absorbed the read-side cost in v0.1.8.9, the residual is the
per-fill write side at `R/fold-engine.R:360`
(`state$positions[[instrument_id]] <- cur_qty + qty`). At 133k fills on
xlarge this is 133k named-vector write operations.

### Tasks

- Write `dev/spikes/spike-state-positions-primitive.R`.
- Build a synthetic state structure at scales {500, 1000, 2000} instruments
  with a realistic id-to-idx map.
- Variant A: current named-vector with per-fill `[[id]] <- value` write
  (production baseline).
- Variant B: integer-indexed numeric + one-time `id_to_idx` map; per-fill
  write becomes `positions[idx] <- value`.
- Variant C: environment-backed positions with per-fill `env[[id]] <- value`.
- Variant D: collapse::setv-based write on integer-indexed numeric.
- Verify byte-identical final positions vector across variants for a
  fixture sequence of 100k writes.
- Time each variant at each scale.
- Measure tracemem evidence for refcount-elevated cases (does write
  trigger copy in Variant A?).
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-write cost reported across variants and scales.
- tracemem evidence documented for the copy-on-write hypothesis on
  Variant A.
- Wall translation distinguishes write-only recovery (per-fill cost on
  xlarge durable) from substrate-effect (boundary-cost reduction for a
  hypothetical compiled core).
- Log explicitly recommends a variant for the v0.1.8.10 substrate ticket
  and addresses snapshot-semantics risk for env-backed variants.
- Output is consumable as the substrate-emulated R baseline for Spike 12.

### Verification

Re-run spike, review log.

### Source Reference

- `R/fold-engine.R:354-360` (state$positions write site)
- v0.1.8.9 Spike 3 / LDG-2482 (prior re-spike) — output to compare against
- `inst/design/horizon.md` 2026-06-01 substrate framing entry
- `dev/bench/notes/single_core_optimization_inventory.md` (A3)

### Classification

```yaml
type: spike
surface: fold_engine_state_mutation
scope: positions_primitive_representation
```

---

## LDG-2508: Spike 4 - Reusable Pulse-Context Env Across Pulses

Priority: P1
Effort: S
Dependencies: none
Status: Pending

### Description

Measure the wall recovery from converting the per-pulse pulse-context
constructor at `R/fold-engine.R:180-194` from a fresh list allocation per
pulse to a reusable env with slot mutation per pulse.

Mechanism hypothesis: the current constructor allocates a fresh list with
12+ slots per pulse. At 1260 pulses on xlarge that is 1260 list allocations
plus per-slot binding work. A reusable env mutated slot-by-slot per pulse
removes the allocation cost while preserving the strategy-observable shape.
Inventory items A5 and A6 estimated this as profile-needed; never spiked.

### Tasks

- Write `dev/spikes/spike-pulse-context-env-reuse.R`.
- Variant A: current fresh-list construction per pulse (production
  baseline).
- Variant B: reusable env with named slots, mutated per pulse.
- Variant C: reusable env with class attribute restored per pulse (matches
  `class(ctx) <- "ledgr_pulse_context"` semantics).
- Variant D: reusable env via `new.env(parent = emptyenv())` with helper
  cache restored per pulse.
- Verify byte-identical strategy observation across variants on a fixture
  that touches every ctx slot.
- Time each variant at 1260 and 5000 pulses (the latter exposes long-run
  GC effects).
- Profile for per-pulse allocation count via `gc()` diagnostic before /
  after each pulse-batch.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-pulse construction cost reported across variants and scales.
- Allocation count diagnostic confirms Variant B/C/D allocate fewer R
  objects per pulse than Variant A.
- Strategy observation parity confirmed (every ctx accessor returns the
  same values in the same shape across variants).
- Wall translation against `density_high_xlarge_durable` loop time.
- Log explicitly addresses class-attribute restore overhead and whether
  it eats the win.
- Output is consumable as the substrate-emulated R baseline for Spike 12.

### Verification

Re-run spike, review log.

### Source Reference

- `R/fold-engine.R:180-194` (pulse context constructor)
- `R/pulse-context.R` (helper updates)
- `dev/bench/notes/single_core_optimization_inventory.md` (A5, A6)
- `inst/design/horizon.md` 2026-06-01 substrate framing entry

### Classification

```yaml
type: spike
surface: fold_engine_per_pulse
scope: pulse_context_env_reuse
```

---

## LDG-2509: Spike 5 - Integer-Indexed Strategy Callback Accessors

Priority: P1
Effort: M
Dependencies: none
Status: Pending

### Description

Measure the per-pulse strategy-callback cost across the current named-list
ctx access pattern, an integer-indexed atomic-vector pattern, and an
integer-indexed env-slot pattern. The spike is a feasibility check for
the strategy callback contract addendum that will need RFC-style
discussion before any v0.1.8.10 ticket cut.

Mechanism hypothesis: strategies that use
`ctx$bars$close[ctx$bars$instrument_id == "AAA"]` pay character-vector
indexing cost per lookup. An integer-indexed accessor pattern like
`ctx$close[idx]` (where `idx` is the instrument's position in the
universe) is O(1) and ergonomically cleaner. At 1260 pulses x 1000
instruments x several accessors per pulse, even small per-access savings
compound.

### Tasks

- Write `dev/spikes/spike-integer-indexed-accessors.R`.
- Build a representative synthetic strategy with three access patterns:
  position lookup, close-price lookup, feature lookup.
- Variant A: current data.frame access (`ctx$bars$close[ctx$bars$instrument_id == "AAA"]`).
- Variant B: integer-indexed atomic-vector access via reusable env
  (`ctx$close[idx]`).
- Variant C: integer-indexed env-slot access via `env$close[[idx]]`.
- Variant D: integer-indexed env-slot access via `collapse::setv` for
  writes, atomic-vector reads.
- Verify the strategy produces byte-identical targets across variants on a
  fixture.
- Time each variant at 1260 pulses with 100, 500, 1000 instruments.
- Profile per-pulse callback cost vs per-pulse engine cost to isolate the
  callback share.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-pulse callback cost reported across variants and universe sizes.
- Strategy target parity confirmed across variants.
- Wall translation distinguishes the strategy-callback share from the
  rest of per-pulse cost.
- Log recommends an accessor surface for the RFC and addresses
  backward-compatibility (named-list patterns remain first-class for
  user-facing strategies).
- Output is consumable as the substrate-emulated R baseline for Spike 12.

### Verification

Re-run spike, review log.

### Source Reference

- `R/fold-engine.R:181-220` (ctx construction and helper attachments)
- `R/pulse-context.R` (helper functions for ctx accessors)
- `inst/design/horizon.md` 2026-06-01 substrate framing entry (strategy
  callback contract addendum)
- `dev/bench/notes/single_core_optimization_inventory.md` (related to
  A5/A6 but new item; integer-indexed accessors are not currently in the
  inventory)

### Classification

```yaml
type: spike
surface: strategy_callback_contract
scope: integer_indexed_accessors
```

---

## LDG-2510: Spike 6 - Next-Bar Matrix Lookup Re-Spike

Priority: P2
Effort: S
Dependencies: none
Status: Pending

### Description

Re-confirm the per-fill matrix-lookup recovery at post-v0.1.8.9 baseline
and quantify the fill-proposal contract surface change cost. The v0.1.8.9
Spike 5 confirmed 166x in isolation, ~5s wall recovery; deferred from
LDG-2502 because the contract surface change (row-shaped `next_bar` to
scalar `next_open_price`) didn't clear the v0.1.8.9 threshold.

Mechanism hypothesis: `b[i+1L, , drop=FALSE]` at `R/fold-engine.R:295`
allocates a new data.frame per fill. Replacing with
`bars_mat$open[inst_idx, i+1L]` is O(1) without allocation.

### Tasks

- Re-run `dev/spikes/spike-next-bar-extraction.R` from the v0.1.8.9 round
  (or write `dev/spikes/spike-next-bar-matrix-lookup.R` if the prior
  script no longer applies post-v0.1.8.9).
- Confirm per-fill speedup at production-fill counts (68k and 133k).
- Variant A: current data.frame row subset.
- Variant B: matrix scalar lookup via pre-extracted next-open price
  matrix.
- Verify byte-identical fill values across variants.
- Document the fill-proposal contract change explicitly: which fields
  change, which downstream consumers care, what cost / liquidity model
  work this enables or blocks.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist (or prior script re-run with new log).
- Per-fill speedup confirmed at production-fill counts.
- Wall translation against post-v0.1.8.9 baseline (not v0.1.8.8 baseline).
- Fill-proposal contract change scope documented explicitly.
- Decision rule clear: ship in v0.1.8.10 (bundled with strategy callback
  addendum if both land), defer to matrix-canonical RFC, or park.

### Verification

Re-run spike, review log.

### Source Reference

- `R/fold-engine.R:295` (next-bar extraction)
- v0.1.8.9 Spike 5 / LDG-2484 (prior measurement and disposition)
- `inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md` LDG-2502
  Spike 5 disposition
- `dev/bench/notes/single_core_optimization_inventory.md` (B2)

### Classification

```yaml
type: spike
surface: fold_engine_per_fill
scope: next_bar_matrix_lookup
```

---

## LDG-2511: Spike 7 - yyjsonr Read-Path Recovery Investigation

Priority: P2
Effort: S
Dependencies: none
Status: Pending

### Description

Investigate whether the yyjsonr read-path regression from LDG-2501 is
recoverable through different yyjsonr configurations, helper-indirection
removal, or a thin jsonlite fallback. LDG-2501's helper benchmark measured
yyjsonr reads 2.3x slower than jsonlite on production metadata shapes
(0.53s jsonlite vs 1.21s yyjsonr at 50k payloads).

Mechanism hypothesis: the read regression has multiple possible recovery
paths. The spike measures each.

### Tasks

- Write `dev/spikes/spike-yyjsonr-read-recovery.R`.
- Build 50k representative meta_json payloads matching the LDG-2501
  benchmark.
- Variant A: current `ledgr_json_read_nested` helper (production
  baseline).
- Variant B: direct `yyjsonr::read_json_str` call without helper
  indirection.
- Variant C: yyjsonr with `length1_array_asis = FALSE` (test whether
  downstream consumers need AsIs preservation).
- Variant D: yyjsonr binary-mode read if available.
- Variant E: thin jsonlite read-fallback (`jsonlite::fromJSON(...)`) while
  keeping yyjsonr for canonical writes.
- Verify structural parity across variants (consumers receive equivalent
  nested-list outputs).
- Time each variant on the 50k-payload set.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-payload read cost reported across all variants.
- Structural parity confirmed (or differences documented).
- Decision rule: any variant achieving 1.5x recovery over Variant A
  proceeds to v0.1.8.10 ticket; otherwise the read-path stays as
  documented LDG-2501 trade-off.
- Log explicitly addresses whether maintaining a hybrid yyjsonr-write +
  jsonlite-read pattern is acceptable governance.

### Verification

Re-run spike, review log.

### Source Reference

- `R/config-canonical-json.R` (ledgr_json_read_nested helper)
- `inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md` LDG-2501
  read-path regression caveat
- `dev/spikes/spike-yyjsonr-readpath-parity.md` from v0.1.8.9 (original
  parity work)

### Classification

```yaml
type: spike
surface: canonical_json_read
scope: yyjsonr_read_recovery
```

---

## LDG-2512: Spike 8 - Cheap Deterministic pulse_seed Mixer

Priority: P2
Effort: S
Dependencies: none
Status: Pending

### Description

Measure the per-pulse cost of the current SHA-256 + canonical_json
`ledgr_derive_pulse_seed` against cheap deterministic mixers (xoshiro128,
splitmix64) and decide whether the inventory's A4 candidate clears the
v0.1.8.10 threshold.

Mechanism hypothesis: SHA-256 + canonical_json per pulse adds ~200us per
pulse. At 1260 pulses on xlarge this is ~0.25s. Cheap deterministic
mixers should be 10x-100x faster while preserving deterministic replay.

### Tasks

- Write `dev/spikes/spike-pulse-seed-mixer.R`.
- Variant A: current `ledgr_derive_pulse_seed` (production baseline).
- Variant B: xoshiro128 seeded from `(execution_seed, pulse_idx)`.
- Variant C: splitmix64 seeded from same inputs.
- Verify deterministic replay parity: same `execution_seed` and
  `pulse_idx` produce same output across variants and across processes
  (the SHA-256 path guarantees this; the mixer path needs explicit
  verification).
- Time each variant at 1260 and 5000 pulses.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-pulse cost reported across variants and pulse counts.
- Deterministic-replay parity confirmed across variants.
- Decision rule: if total isolated cost < 1s at 1260 pulses, park (not
  v0.1.8.10 scope); if > 1s, ticket.
- Log explicitly addresses cross-platform determinism for the mixer
  variants (xoshiro128 and splitmix64 are well-specified; verify R
  implementations match the reference).

### Verification

Re-run spike, review log.

### Source Reference

- `R/rng.R:33-57` (ledgr_derive_pulse_seed)
- `dev/bench/notes/single_core_optimization_inventory.md` (A4)

### Classification

```yaml
type: spike
surface: rng
scope: pulse_seed_mixer
```

---

## LDG-2513: Spike 9 - active_alias_map One-Time Normalization

Priority: P2
Effort: S
Dependencies: none
Status: Pending

### Description

Measure the per-pulse cost of `active_alias_map` normalization and decide
whether lifting it outside the loop saves wall time. Inventory item A7.

Mechanism hypothesis: the alias map is currently re-normalized per pulse
inside `R/fold-engine.R:61, 204-218`. Lifting normalization outside the
loop saves per-pulse cost.

### Tasks

- Write `dev/spikes/spike-alias-map-normalize.R`.
- Build a synthetic alias map at scales {10, 50, 100} aliases.
- Variant A: current per-pulse normalize (production baseline).
- Variant B: one-time normalize before the loop, lookup-only per pulse.
- Variant C: pre-resolved aliases at execution-spec construction time, no
  per-pulse normalize or lookup at all.
- Verify alias resolution parity across variants.
- Time each variant at 1260 pulses across alias-count scales.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-pulse normalize cost reported across variants and scales.
- Decision rule: if isolated cost < 0.5s at 1260 pulses x 100-alias map,
  park; if > 0.5s, ticket.

### Verification

Re-run spike, review log.

### Source Reference

- `R/fold-engine.R:61, 204-218` (alias map normalize)
- `dev/bench/notes/single_core_optimization_inventory.md` (A7)

### Classification

```yaml
type: spike
surface: fold_engine_per_pulse
scope: alias_map_normalize
```

---

## LDG-2514: Spike 10 - Inline Lot-State In Memory Output Handler

Priority: P1
Effort: M
Dependencies: LDG-2505 (design pairing with Spike 1)
Status: Pending

### Description

Confirm or reject the hypothesis that capturing lot state inline during
fold execution (in the memory output handler) eliminates the per-event
lot-machinery replay in `ledgr_sweep_summary_from_ordered_events` at
`R/fold-reconstruction.R:454-504`.

Mechanism hypothesis: the reconstruction pass replays `ledgr_lot_apply_event`
per event to derive `event_realized` and `event_cost_basis`. The fold
engine already runs lot machinery during execution to emit fill events.
Capturing per-pulse (or per-event) lot state in the memory output handler
removes the replay entirely. Bundled with Spike 1 in the eventual design
but measured separately to attribute the lot-replay vs equity-recompute
portions of the reconstruction cost.

### Tasks

- Write `dev/spikes/spike-inline-lot-state.R`.
- Build a synthetic events stream at scales {30k, 68k, 130k} events.
- Variant A: current reconstruction-pass lot replay (production baseline).
- Variant B: memory output handler captures lot state per pulse;
  reconstruction reads pre-captured state without replay.
- Variant C: memory output handler captures lot state per event;
  reconstruction reads per-event without replay.
- Verify byte-identical `event_realized` and `event_cost_basis` vectors
  across variants.
- Time each variant at each scale.
- Write paired log.

### Acceptance Criteria

- Spike script and log exist.
- Per-event lot-replay cost reported standalone (separate from
  equity-recompute cost measured in Spike 1).
- Byte-identical lot-state vectors confirmed across variants.
- Wall translation against `density_high_xlarge_ephemeral`.
- Log explicitly addresses whether Spike 1 plus Spike 10 deliver
  attributable independent recovery or whether they should be bundled
  into one v0.1.8.10 ephemeral-redesign ticket.

### Verification

Re-run spike, review log.

### Source Reference

- `R/fold-reconstruction.R:454-504` (lot replay)
- `R/lot-accounting.R` (lot machinery)
- LDG-2505 / Spike 1 (paired design)

### Classification

```yaml
type: spike
surface: memory_output_handler
scope: inline_lot_state_capture
```

---

## LDG-2515: Spike 11 - Ephemeral Sweep Subphase Telemetry

Priority: P1
Effort: S
Dependencies: none
Status: Pending

### Description

Add subphase telemetry exposure for ephemeral sweep rows so the
workload-grid harness can report `loop_sec`, `results_sec`, and
`fills_extract_sec` for sweep candidates the same way it reports them for
durable rows. This is infrastructure, not optimization, but it is a
prerequisite for clean attribution of Spike 1's reconstruction-pass
elimination.

Mechanism: the sweep candidate flow currently does not capture per-phase
timing because the memory output handler and `ledgr_sweep_summary_from_ordered_events`
don't have telemetry hooks. Add hooks at handler entry/exit and
reconstruction entry/exit; verify the telemetry round-trips through the
workload-grid harness to the summary CSV.

### Tasks

- Write `dev/spikes/spike-ephemeral-subphase-telemetry.R`.
- Identify the telemetry hooks needed in `R/sweep.R` and
  `R/fold-reconstruction.R`.
- Prototype telemetry capture inline with the existing
  `ledgr_sweep_telemetry_env()` pattern used by the peer benchmark
  ephemeral row.
- Verify telemetry output captures the expected subphases.
- Verify workload-grid harness CSV reports the subphases for ephemeral
  rows after the prototype.
- Write paired log documenting the smallest production change required
  to expose the telemetry without changing other ephemeral behavior.

### Acceptance Criteria

- Spike script and log exist.
- Telemetry hooks identified and prototype implementation works.
- Workload-grid harness verified to capture and report ephemeral
  subphases.
- Log states this is infrastructure to ship alongside the Spike 1
  implementation ticket, not a separate optimization lane.

### Verification

Re-run spike, review log. Confirm the workload-grid CSV from the
prototype run has non-NA values for ephemeral subphase columns.

### Source Reference

- `R/sweep.R` (memory output handler + telemetry env)
- `R/fold-reconstruction.R` (reconstruction pass)
- `dev/bench/peer_benchmark/peer_benchmark.R` (ephemeral telemetry env
  pattern)
- `dev/bench/notes/single_core_optimization_inventory.md` (C3)
- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
  residual 2 (ephemeral phase visibility)

### Classification

```yaml
type: spike
surface: telemetry
scope: ephemeral_subphase_exposure
```

---

## After All Spikes Complete

Write `architecture_synthesis.md` in this directory following the v0.1.8.9
precedent (`inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`).
The synthesis should:

- Summarize each spike's mechanism finding (confirmed / rejected / open).
- Identify cross-cutting lessons (e.g., "ephemeral redesign delivers the
  ephemeral fast-path inversion the original ephemeral design intended").
- Rank the v0.1.8.10 candidate lanes by combined Amdahl headroom and
  mechanism confidence.
- Name the v0.1.8.10 spec inputs: which spikes feed which proposed
  v0.1.8.10 ticket, with the spike log as the load-bearing source
  reference.

The synthesis is the load-bearing input for the v0.1.8.10 spec packet.
Until the synthesis exists, the v0.1.8.10 spec packet cannot be cut.

K1 decision verdict is recorded separately in the dedicated
`ledgrcore-spike` repo's measurement output and flows back to a future
ledgr horizon update. It is not part of the v0.1.8.10 architecture
synthesis.

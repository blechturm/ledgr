# RFC Seed v2: Compiled Hot Frame B2 — Per-Pulse Fill Batch Compilation (v0.1.9.x)

**Status:** Seed v2. Incorporates Codex Round-1 response. Not accepted.
Not authorized implementation scope.
**Cycle:** Architecture B2 measurement gate (v0.1.8.10 Ticket 5) plus
promotion ticket (v0.1.9.x if gate passes).
**Promotion candidate:** v0.1.8.10 Ticket 5 (gate measurement; lives
in `ledgrcore-spike`). Promotion to v0.1.9.x if gate passes.
**Authored:** 2026-06-02. Seed v1 author was Claude; this v2 is the
same author per `inst/design/rfc_cycle.md` role rotation. Synthesis
will be authored by the response-stage reviewer (Codex) per the
rotation.
**Relates to:** seed v1 (`rfc_compiled_hot_frame_b2_v0_1_9_x_seed.md`);
response (`rfc_compiled_hot_frame_b2_v0_1_9_x_response.md`); the
2026-06-01 horizon entries on Architecture B, K1 verdict, and
ephemeral wall attribution; the v0.1.8.10 Round-3 architecture
synthesis L7 Tickets 1-3.

## Revision notes (v1 → v2)

Codex's Round-1 response identified eight blocking findings and two
caveats. All ten are addressed in this v2. The structural changes:

1. **Maintainer-override request** (new section, top of document) per
   Finding 1. The horizon's attribution-first sequencing is explicitly
   contested; the maintainer is asked to override and run B2
   measurement before the attribution spike.
2. **Hypothesis table replacing the 85-120s estimate** per Finding 2.
   The v0.1.8.9 memory-output-handler recovery has already shipped
   (LDG-2498: 508s → 346s = ~161s recovery). The corrected
   B2-recoverable slice estimate is ~30-55s and explicitly labeled as
   a hypothesis the measurement will quantify.
3. **Production fill-semantics section** per Finding 3. Replaces the
   current-close K1 shortcut with the next-open `ledgr_next_open_fill_proposal`
   pipeline. The hot frame consumes validated next-open inputs.
4. **Measurement gate split** per Finding 4. Feasibility comparison
   (Rust vs C++ in ledgrcore-spike) is separate from the
   decision-bearing gate (ledgr's production fold engine with hot
   frame swapped in).
5. **K1 ceiling rates re-cited** per Finding 5. Per-pulse R-to-compiled
   FFI cost is treated as unknown, to be measured by B2. The 30s gate
   threshold remains as the measurement rule.
6. **Scope contradictions resolved** per Finding 6. Equity stays R
   (single answer). User-supplied cost resolvers are explicitly out
   of the B2 fast path (single answer).
7. **Parity contract inherits all 8 substrate-decision gates** per
   Finding 7, plus a B2-specific gate for production lot semantics.
8. **Event buffer contract section** per Finding 8. The compiled
   buffer must participate in `ledgr_memory_output_handler()`'s
   contract (event ids, sequence, typed meta, `meta_json`
   materialization).
9. **Build-flag standardization narrowed** per Finding 9. A measured
   gate variant with explicit no-fast-math + cross-platform parity
   requirements; not a blanket production policy.
10. **"All eight compilable" softened** per Finding 10 to
    "compilation candidates" with explicit production-contract gating.

Confirmed claims from the response (K1 authorization, batching as
the correct response, strategy callback in R, durable adoption
deferral, substrate dependency) are preserved without change.

## Maintainer override request

The current horizon sequencing (2026-06-01 ephemeral wall attribution
gate entry) makes the attribution spike binding before B2 measurement
runs:

> "The 2026-05-30 ledgrcore entry's gates and the Architecture B2
> entry's gates are now joined by an 'xlarge ephemeral wall
> attribution must complete before either compiled-core path is
> authorized' gate."

This seed v2 requests a maintainer override of that sequencing.
Specifically: B2 measurement gate runs in v0.1.8.10 Ticket 5
(parallel to substrate work); attribution spike becomes a fallback
that runs only if B2 measurement fails.

### Rationale for override

1. **K1 verdict + Spike 12 + Architecture B horizon framing are
   collectively sufficient warrant for B2 measurement.** K1
   established that compiled fold cores meet the 5x build-authorized
   threshold on inline-output designs (verdict.md:9-27). Spike 12
   measured the lot machinery slice independently. Architecture B
   horizon entry recognises B2 as the cheaper path with the
   per-pulse batching architecture. The "we don't know if the slice
   is meaningful" framing the attribution gate addresses is
   substantially answered by these three lines of evidence in
   combination.

2. **B2 measurement is binary (pass/fail with a 30s threshold) and
   uses existing infrastructure.** ledgrcore-spike already has the
   Rust extendr + C++ cpp11 toolchains, parity infrastructure, and
   measurement harness from K1. The marginal effort to add the
   per-pulse hot frame variant is roughly one extra function per
   language plus a benchmark harness in ledgr's `dev/bench/`.

3. **Attribution spike runs ≥5 candidate sub-frames and produces a
   distribution.** Per the attribution spec at
   `inst/design/spikes/ephemeral_wall_attribution_spike/spec.md`, the
   methodology requires instrumented copies of `ledgr_execute_fold`
   and `ledgr_sweep_summary_from_ordered_events`, ~13-15 measurement
   reps per session, 4-6 hour session length, parity gates against
   the uninstrumented installed package. The attribution spike is
   measurement-heavy and decision-distributional.

4. **B2-first sequencing reduces total decision time.**
   - IF B2 measurement passes: the attribution spike's primary
     question ("is the fold-loop slice meaningful?") is answered
     directly. The attribution spike's other questions become lower
     priority (we know what the dominant lever is).
   - IF B2 measurement fails: the attribution spike becomes
     warranted with concrete prior evidence (B2 didn't capture the
     expected slice → either the slice is smaller than estimated or
     B2's per-pulse batching doesn't deliver the K1 ceiling). The
     attribution then runs with a sharper question.
   - Net calendar time is similar to attribution-first; decision
     quality is higher because the B2 measurement is decisive and
     the attribution spike (if needed) starts with concrete evidence
     to anchor its hypotheses.

5. **The attribution gate was added before K1 verdict landed.** The
   2026-06-01 ephemeral attribution horizon entry was authored on
   2026-06-01; the K1 verdict was authored the same day, slightly
   later. The attribution gate's rationale was "K1 only addresses
   ~15% of wall" which assumed the fold-loop slice was small. K1's
   verdict structure (build authorized for inline-output design
   only) plus Spike 12's lot machinery measurement plus the
   Architecture B framing have collectively sharpened the picture
   since the attribution gate was added.

### Risks of override (acknowledged)

- **B2 measurement might fail** and the ledgrcore-spike work would
  have been spent on an unsuccessful prototype. Mitigation: the
  ledgrcore-spike B2 implementation work IS the prototype the
  attribution spike would otherwise sequence after — if B2 fails,
  the implementation evidence still informs the attribution work.
- **Production-faithful B2 implementation may be harder than seed v1
  implied.** This v2's Production Fill Semantics and Production Lot
  Semantics sections (below) are more conservative about
  implementation scope; the gate's parity surface is broader than
  v1 specified.
- **Override sets precedent for bypassing horizon gates.** The
  override is requested specifically for this gate, not as a general
  policy. The horizon's attribution gate remains the fallback if B2
  measurement fails. The override does not invalidate the
  attribution spec, which stays available for deployment if needed.

### What the override changes

| Sequencing | Without override (current horizon) | With override (proposed v2) |
|:-----------|:-----------------------------------|:----------------------------|
| First post-v0.1.8.10 measurement | Ephemeral attribution spike | B2 measurement gate (Ticket 5) |
| If meaningful fold-loop slice surfaced | Run B2 spike | Promote to v0.1.9.x ticket |
| If fold-loop slice small/diffuse | Optimize whatever attribution surfaces | Run attribution spike |
| Outcome quality | Distribution across sub-frames | Binary pass/fail + (conditional) attribution |

If maintainer rejects the override: this seed v2's content stays
useful, but its measurement gate gets re-sequenced as a
post-attribution B2 spike per the original horizon framing. The
production fill / lot / event semantics work in v2 stays valid in
either ordering.

## Problem

ledgr's post-v0.1.8.9 xlarge ephemeral wall is **372.55s** per the
workload-grid measurement
(`inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md:83-88`).
The v0.1.8.10 substrate work (Tickets 1-4) is expected to compress
this further, but the post-v0.1.8.10 baseline is not yet measured.

The K1 measurement spike established that compiled fold cores
authorize a build under the inline-event-accumulation boundary
(`ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md:9-27`).
The Architecture B horizon entry proposes that the same K1 ceiling
can be reached without building a separate `ledgrcore` package by
compiling a per-pulse hot frame inside ledgr (`inst/design/horizon.md`
2026-06-01 Architecture B entry).

The architectural question this RFC seeks to answer:

> **Can the per-pulse fill batch be compiled as a cpp11 / extendr
> hot frame inside ledgr, called once per pulse from an R fold loop,
> consuming the post-v0.1.8.10 substrate shape, with byte-identical
> production semantics and a measured wall recovery that justifies
> the integration cost?**

The B2 measurement gate proposed below produces a binary answer with
the language verdict as a secondary output.

## Background / current state

### What runs in ledgr's fold loop today (post-v0.1.8.10 substrate)

After Tickets 2 and 3 land per the Round-3 synthesis, the
post-v0.1.8.10 fold loop has this shape (engine phase, per pulse).
Cell shading marks the B2 candidate scope:

| Sub-frame | Code path | Post-v0.1.8.10 expected | B2 candidate? |
|:----------|:----------|:------------------------|:--------------|
| Pulse-context list allocation | `R/fold-engine.R:181-194` | Small (Spike 4 measurement floor) | No |
| Helper attachment | `R/fold-engine.R:196-221` | Larger — v0.1.8.8 Batch 2 telemetry attributed ~0.9% of fold-loop time to ctx surface | No |
| Feature engine + projection lookup | `R/runtime-projection.R` plus per-accessor calls | Workload-dependent | No |
| Strategy callback invocation | `R/fold-engine.R:228-247` | Small (user-decision floor ~6 μs/pulse per Amdahl-floor spike) | No (user code) |
| Per-pulse position valuation | `R/fold-engine.R:164-170` | Small (vectorized in v0.1.8.9) | **Yes** |
| Target validation + target-risk noop | `R/fold-engine.R:248-268` | Unknown | Candidate (R contract boundary; defer for v2 scope) |
| **Fill-loop body** | `R/fold-engine.R:288-365` | **Load-bearing** | **Yes (primary B2 target)** |
| Pulse-seed RNG | `R/rng.R:33-57` | ~0.14s xlarge (Spike 8) | Yes but too small to ticket |

The fill-loop body is the primary compilation target. It runs per
fill (~130k times at xlarge) and contains a chain of production
contract surfaces (next-open proposal → cost resolver → lot
accounting → state mutation → event emission). The exact wall share
on the post-v0.1.8.10 baseline is **unmeasured**; this RFC's
measurement gate quantifies it.

### Evidence hypothesis table (replaces seed v1's 85-120s claim)

Per Codex Round-1 Finding 2, the seed v1's 85-120s estimate
double-counted the v0.1.8.9 memory-output-handler lane that already
shipped. The corrected evidence table separates "already measured
and delivered" from "B2-relevant residual hypothesis":

| Component | Pre-v0.1.8.9 cost or estimate | v0.1.8.9 work delivered | Post-v0.1.8.10 B2-relevant residual hypothesis |
|:----------|:------------------------------|:------------------------|:-----------------------------------------------|
| Memory output handler (event emission) | ~75s recovery estimate per v0.1.8.9 L8 | LDG-2498 delivered ~161s of xlarge ephemeral recovery (508s → 346s, per `per_lane_attribution.md:193-264`) | **DELIVERED** — already absorbed into the 372s baseline; not available for B2 |
| FIFO lot machinery (post-Ticket-2 fold-owned) | ~30s at xlarge synthetic (Spike 12 measurement, `dev/spikes/spike-fold-time-lot-accounting.md:116-145`) | Spike 12 quantified the move (22-27% savings vs reconstruction-time on synthetic) | **Hypothesis: ~15-30s on production xlarge**, conditional on Codex's lot-depth-of-1 finding on real peer fills (per Round-3 synthesis L1) |
| Default cost resolver per fill | Unmeasured; ~130k invocations of `ledgr_default_cost_resolve` (`R/fill-model.R:162-195`) at xlarge | None | **Hypothesis: ~5-15s** — depends on the cost-resolver hot frame cost in R |
| Per-fill cash + positions mutation | Small per fill (vectorized in v0.1.8.9) | Mostly absorbed | **Hypothesis: ~1-3s** — residual per-fill scalar R writes |
| Per-pulse equity computation | Small (vectorized) | Already vectorized | **No B2 scope** — stays in R |
| Next-open fill proposal construction (`R/fill-model.R:18-96`) | Unmeasured per-fill cost | None | **Hypothesis: ~3-8s** — proposal struct construction + validation per fill |
| **Total fill-loop body B2-relevant** | — | — | **Hypothesis: ~25-55s** |

The corrected estimate range is **~25-55s of post-v0.1.8.10 xlarge
ephemeral wall**, narrower than seed v1's 85-120s claim and entirely
hypothesis. The B2 measurement quantifies the actual share; the gate
threshold (30s) is calibrated against the lower end of the
hypothesis range.

The gate's outcome:

- IF measurement recovers ≥30s: hypothesis is broadly correct; B2 is
  worth promoting.
- IF measurement recovers 15-30s: hypothesis lower-bound holds but
  margin is thin; maintainer judgment on promotion cost-benefit.
- IF measurement recovers <15s: hypothesis broken; B2 doesn't
  capture the slice; attribution spike becomes warranted.

### K1 evidence (corrected per Codex Round-1 Finding 5)

The K1 verdict table at `ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md:57-62`
reports xlarge per-pulse and per-fill rates by boundary variant:

| Boundary | Rust extendr | C++ cpp11 |
|:---------|:-------------|:----------|
| `strat_static_handler_inline` | 3.78 μs/pulse, 0.04 μs/fill | 17.46 μs/pulse, 0.17 μs/fill |
| `strat_R_handler_inline` | 11.90 μs/pulse, 0.12 μs/fill | 55.56 μs/pulse, 0.54 μs/fill |
| `strat_R_handler_R` | ~115 ms/pulse | ~110 ms/pulse |
| `strat_static_handler_R` | ~114 ms/pulse | ~105 ms/pulse |

K1's verdict explicitly notes: "Architecture B is not measured by
K1; the closest cell is still Architecture A"
(per `inst/design/horizon.md` 2026-06-01 K1 verdict entry).

**What K1 tells us about B2:**

1. Compiled fold work at the inline-event-accumulation boundary runs
   in single-digit microseconds per pulse and sub-microsecond per
   fill. This is the ceiling B2's compiled work approaches.
2. R-callback-per-fill boundaries (the `*_handler_R` cells) cost
   ~1 ms per call and dominate total wall. B2 avoids this trap by
   batching FFI hops to per-pulse.
3. **K1 does NOT measure R-to-compiled per-pulse FFI cost** with
   marshalling of vector positions, vector lots, mutable state, and
   a per-pulse event buffer. This is B2's load-bearing cost
   unknown. The K1 boundary cost numbers (compiled→R per-fill
   ~1 ms) are NOT directly applicable to B2's R→compiled per-pulse
   cost. The B2 measurement quantifies this.

The seed v1's `1260 hops × ~100 μs` overhead estimate was an
extrapolation, not a measurement. v2 treats per-pulse FFI overhead
as unknown and measures it.

## Production fill semantics

Per Codex Round-1 Finding 3, the seed v1 pseudo-code used current
close prices for fill resolution. Production fills at next-open via
the `ledgr_next_open_fill_proposal` pipeline. This v2 corrects the
hot frame's input contract.

### What the hot frame must consume

The R fold loop is responsible for next-bar lookup and fill-proposal
construction. The hot frame receives the **post-resolution fill
intent** for each fill in the pulse's batch:

| Input | Source | Per-fill scalar values |
|:------|:-------|:-----------------------|
| `instrument_idx` | R fold loop's `id_to_idx` map (post-Ticket-3 substrate) | integer index into universe |
| `instrument_id` | universe character vector at `instrument_idx` | character (for event emission only) |
| `ts_exec_utc` | from `ledgr_fill_intent$ts_exec_utc` (`R/fill-model.R:184-191`) | POSIXct scalar |
| `side` | from `ledgr_fill_intent$side` ("BUY" or "SELL"; production extends to COVER/BUY_TO_COVER/SHORT/SELL_SHORT — see Production Lot Semantics) | character scalar |
| `fill_price` | from `ledgr_fill_intent$fill_price` (already spread-adjusted + rounded by cost resolver) | numeric scalar |
| `qty` | from `ledgr_fill_intent$qty` | numeric scalar |
| `commission_fixed` | from `ledgr_fill_intent$commission_fixed` | numeric scalar |

The hot frame does NOT call `ledgr_next_open_fill_proposal` or the
cost resolver internally. Both stay in R. The R fold loop:

1. Looks up `next_bar` for each instrument with non-zero delta
   (`R/fold-engine.R:295-300`).
2. Calls `ledgr_next_open_fill_proposal(desired_qty_delta, next_bar)`
   per fill (`R/fill-model.R:18-96`).
3. Resolves cost via the configured cost resolver (default
   `ledgr_cost_spread_commission_internal` at `R/fill-model.R:118-146`,
   user-supplied resolvers also stay R).
4. Filters out `ledgr_fill_none` results (LEDGR_LAST_BAR_NO_FILL and
   zero-delta cases).
5. Passes the resulting `ledgr_fill_intent` batch to the hot frame.

**This narrows the B2 scope vs seed v1.** The cost resolver and
fill proposal stay R; the hot frame does only state-transition work
post-resolution.

### Why this scoping is right

- **Cost resolvers can be user-supplied.** The public cost-API
  surface (per the v0.1.9.x cost-API synthesis) allows user
  resolvers. The hot frame cannot call back into R per fill for
  these (per K1 evidence: ~1 ms per call destroys the speedup).
  Keeping cost resolution in R means user resolvers work unchanged.
- **`ledgr_next_open_fill_proposal` is contract surface.** It
  validates `instrument_id`, `ts_utc`, `open` per the production
  contract (`R/fill-model.R:54-66`); returns `LEDGR_LAST_BAR_NO_FILL`
  on final pulse (`R/fill-model.R:33-42`); constructs the
  `execution_bar` for downstream consumers
  (`R/fill-model.R:76-84`). Moving this into compiled code would
  duplicate validation surface. Keeping it in R preserves the
  contract.
- **Performance impact of the narrower scope.** The fill proposal
  + cost resolver work is per-fill R cost. The hypothesis table
  above estimates this at ~8-23s of xlarge wall (fill proposal
  ~3-8s + cost resolver ~5-15s). The B2 gate's 30s threshold is
  achievable even without compiling these surfaces if the lot
  machinery + event emission slice is ≥15s on production.

The trade-off: B2's wall recovery is bounded by what stays compiled
in the hot frame. The narrower scope is the right product decision
because it preserves the public cost-API contract; if the
measurement shows we're leaving recovery on the table, a future B2
extension can move the default cost resolver into the hot frame
behind a "use compiled default cost path" flag, but that's a
separate ticket post-promotion.

### Final-bar no-fill semantics

`ledgr_next_open_fill_proposal` returns a `ledgr_fill_none` with
`warn_code = "LEDGR_LAST_BAR_NO_FILL"` when no next bar exists for
an instrument (`R/fill-model.R:33-42`). The R fold loop filters
these BEFORE calling the hot frame; the hot frame never sees
no-fill cases. This preserves the production warning surface
(strategies that try to trade on the final pulse get the warning;
the warning code is reachable from `ledgr_results(bt, "warnings")`).

## Production lot semantics

Per Codex Round-1 Finding 7, K1's R reference implements only
long-only fills (errors on short lot creation; see
`ledgrcore-spike/R/k1_r_reference.R:64-99`). Production lot
accounting at `R/lot-accounting.R` supports both directions plus
opening-position CASHFLOW handling. The hot frame must match
production semantics, not K1's simplified reference.

### What the hot frame must implement

From `R/lot-accounting.R:13-19, 74-162, 180-217`:

1. **Side-to-direction mapping** (`R/lot-accounting.R:13-19`):
   - BUY / COVER / BUY_TO_COVER → direction +1
   - SELL / SHORT / SELL_SHORT → direction -1
   - All other values → NA (treated as invalid; production returns
     a fill with NA realized values per `R/lot-accounting.R:85-93`)

2. **Net position vs direction determines close vs open** (`R/lot-accounting.R:95-107`):
   - net_pos = sum of all lots' qty for the instrument (positive
     for long, negative for short)
   - If direction > 0 (BUY/COVER) AND net_pos < 0: `close_qty =
     min(qty, |net_pos|)` covers short lots first
   - If direction < 0 (SELL/SHORT) AND net_pos > 0: `close_qty =
     min(qty, net_pos)` closes long lots first
   - Otherwise: `close_qty = 0`; full qty opens new lot
   - `open_qty = qty - close_qty`

3. **FIFO close walk with realized PnL** (`R/lot-accounting.R:109-141`):
   - Direction > 0 closing shorts: realized += (lot_price - fill_price) × take
   - Direction < 0 closing longs: realized += (fill_price - lot_price) × take
   - Front lot consumed; remaining qty stays in front
   - Empty lots removed (drop front when qty == 0)

4. **Open-side lot creation** (`R/lot-accounting.R:143-148`):
   - If open_qty > 0: append lot with qty = ±open_qty (sign matches
     direction) and price = fill_price
   - Lot list order matters (FIFO closes consume from front)

5. **Realized PnL accumulation** (`R/lot-accounting.R:150-152`):
   - `realized_delta = realized_close - fee`
   - State's running `realized_pnl` updated via
     `ledgr_lot_add_realized` (Kahan-compensated sum,
     `R/lot-accounting.R:49-55`)

6. **Per-instrument cost basis** (`R/lot-accounting.R:33-47`):
   - `state$cost_basis_by_inst[instrument_id]` updated to
     `ledgr_lot_basis(lots)` after the lot change
   - `state$total_cost_basis` updated by delta

7. **Opening-position CASHFLOW handling** (`R/lot-accounting.R:180-217`):
   - When event_type == "CASHFLOW" AND
     `ledgr_lot_meta_is_opening(meta)`:
     - Call `ledgr_lot_apply_opening` with `qty = meta$position_delta`
       and `cost_basis = meta$cost_basis`
     - Opens a single lot at the given cost basis without going
       through fill-resolution logic
   - The hot frame must handle the CASHFLOW opening branch OR the R
     fold loop must apply CASHFLOW events outside the hot frame
     (preferred: opening positions are processed at fold setup, not
     in the per-pulse fill loop, so the hot frame only handles FILL
     events).

### Per-fill output the hot frame returns

For each fill processed, the hot frame contributes to the per-pulse
event batch:

| Field | Source | Type |
|:------|:-------|:-----|
| `pulse_idx` | from R fold loop's pulse counter | integer |
| `event_seq` | from R fold loop's monotonic counter (output handler manages this) | integer |
| `instrument_id` | from fill intent | character |
| `ts_utc` | from `ts_exec_utc` | POSIXct |
| `side` | from fill intent (full direction support) | character |
| `qty` | from fill intent | numeric |
| `price` | from fill intent's `fill_price` (already cost-resolved) | numeric |
| `fee` | from fill intent's `commission_fixed` | numeric |
| `cash_delta` | computed by hot frame: -sign(direction) × qty × fill_price - commission_fixed (sign reversed for SELL) | numeric |
| `position_delta` | computed by hot frame: sign(direction) × qty | numeric |
| `realized_pnl` | computed by hot frame: realized close PnL minus fee | numeric |
| `cost_basis_after` | computed by hot frame: weighted-average cost basis of remaining lots | numeric |
| `event_type` | "FILL" or "FILL_PARTIAL" (production uses both; needs clarification — see Open Questions) | character |
| `meta` (typed) | hot frame produces typed metadata for the memory handler's typed-events path (`R/sweep.R:1083-1101`) | list |

The hot frame's per-fill outputs feed into the memory output
handler's event buffer; see Event Buffer Contract section below for
how this integrates.

## Event buffer contract

Per Codex Round-1 Finding 8, the seed v1 mutated
`output_handler$event_buffer` directly without addressing how the
compiled buffer participates in the existing memory output handler
contract. This v2 ties the hot frame's buffer interaction back to
`R/sweep.R:957-1190`.

### What the memory output handler provides

The production memory output handler
(`ledgr_memory_output_handler` at `R/sweep.R:957-1190`) owns:

1. **Capacity management** (`R/sweep.R:987-1009`): typed column
   buffers grow geometrically; `ensure_event_capacity` reallocates
   when needed.
2. **Typed event columns** (`R/sweep.R:966-985`): 14 columns
   including `event_id` (character), `run_id`, `ts_utc` (POSIXct),
   `event_type`, `instrument_id`, `side`, `qty`, `price`, `fee`,
   `meta_json` (character), `event_seq` (integer), `cash_delta`,
   `position_delta`, `meta` (list).
3. **Per-event setv writes** (`R/sweep.R:1011-1033`): `set_event_value`
   uses `collapse::setv` for numeric / integer / POSIXct columns;
   base R `[[<-` for character columns.
4. **Materialization endpoints**: `handler$events()`
   (`R/sweep.R:1186-1188`) produces a data.frame with `meta_json`
   derived from typed meta on demand; `handler$typed_events()`
   (`R/sweep.R:1183-1185`) returns typed events without
   `meta_json` materialization.
5. **`meta_json` deferral** (`R/sweep.R:1059-1075`): typed meta is
   serialized to canonical_json only when requested by the consumer
   (sweep summary path uses typed meta; durable path materializes
   `meta_json` on write).
6. **Strategy state buffering**: `handler$buffer_strategy_state`
   (`R/sweep.R:1181`) and other downstream surfaces.

### How the B2 hot frame interacts with the handler

The hot frame **does not bypass the memory output handler**. It
participates through one of two patterns; the choice is an open
question for the seed v2 response stage:

**Pattern A (preferred): hot frame returns a per-pulse event batch
to R; the R fold loop calls `handler$buffer_event` per fill in the
batch.**

- Hot frame returns a list of typed vectors (one vector per event
  column) for the pulse's fills.
- R fold loop iterates through the vectors and calls
  `handler$buffer_event(write_res)` for each, where `write_res` is a
  reconstructed `ledgr_ledger_write_result` (the same shape
  `handler$write_fill_events` produces in the current production
  path — `R/sweep.R:1171-1180`).
- The handler's setv buffer writes happen in R as today; the hot
  frame just supplied the values.
- Cost: per-pulse FFI returns batch of 14 typed vectors;
  per-fill R-side setv writes are unchanged from current production.
- Benefit: the handler's contract is unchanged; meta_json deferral,
  capacity management, materialization endpoints all work as today.

**Pattern B: hot frame writes into the handler's typed columns
directly via a buffer pointer.**

- Hot frame receives the handler's typed column buffers (as `R`
  vectors via extendr/cpp11 marshalling) plus the current event
  count.
- Hot frame writes events into the columns using its own setv-shape
  operations.
- At pulse end, hot frame returns the updated event count; R fold
  loop updates `state$event_count` to match.
- Cost: per-pulse FFI sends/receives buffer pointers (cheap if R
  vectors are passed by reference; expensive if copied).
- Benefit: no per-fill R-side setv work; hot frame does the writes.
- Risk: requires the hot frame to know the handler's internal column
  layout AND respect capacity. Any handler refactor (e.g. adding a
  new column) breaks the hot frame.

The **gate measurement runs Pattern A** because it has the smaller
contract surface and matches current production semantics directly.
Pattern B is a possible v0.1.9.x optimization if Pattern A measures
clean and the per-fill setv work becomes the binding cost.

### Specific contract obligations

Regardless of pattern, the hot frame's output must satisfy:

- `event_id` matches the handler's id generation contract
  (currently `paste0` of run_id + event_seq per
  `R/ledger-writer.R`; the R fold loop owns ID generation).
- `event_seq` is monotonic and matches the handler's `event_count`
  state.
- `event_type` is "FILL" or "FILL_PARTIAL" per production
  classification (open question — see below).
- `meta` (typed) is a list with at minimum `cash_delta`,
  `position_delta`, `realized_pnl` keys; the handler uses these to
  derive `meta_json` on materialization
  (`R/sweep.R:1067-1074`).
- `cash_delta` and `position_delta` are also typed-attribute fields
  (`event_cols$cash_delta`, `event_cols$position_delta`) that the
  handler reads via `attr(out, "ledgr_event_cash_delta")` etc. for
  the sweep summary fast path.

The gate's parity test must cover end-to-end:
`handler$typed_events()` from a B2 run equals
`handler$typed_events()` from the production R fold engine on the
same fixture.

## Compilation candidates (renamed from "all eight compilable")

Per Codex Round-1 Finding 10, the seed v1 said "all eight components
are compilable" too broadly. The corrected categorization:

| Component | Category | Why |
|:----------|:---------|:---|
| Per-pulse position valuation | **Compilable** | Numeric vector op; no R contract surface beyond input/output |
| Target validation + target-risk noop | **Compilation candidate, deferred** | R contract surface (`R/fold-engine.R:248-268`); requires more analysis. Out of v0.1.9.x B2 first-cut |
| Fill-loop body (post-resolution) | **Compilable** | Numeric/lot-state work post-R-resolution; no R callbacks inside |
| Cost resolver dispatch | **Out of B2 scope** | R contract surface; user-supplied resolvers must stay R |
| Output handler write | **Compilable (Pattern A) or pass-through (Pattern A)** | Contract is the handler's typed column shape; hot frame produces values, handler writes them |
| Per-pulse equity computation | **Out of B2 scope** | Stays in R (single equity value per pulse; cheap; consistency with helper attachment in R) |
| Pulse-seed RNG | **Compilable but too small to ticket** | ~0.14s xlarge per Spike 8 |

The B2 first-cut compiles only "compilable" rows (per-pulse position
valuation + fill-loop body + Pattern A output handler integration).
"Compilation candidate, deferred" rows (target validation) move to a
future v0.1.9.x+ B2 extension if measurement justifies.

## Proposed direction

### The hot frame's compiled scope (corrected)

The compiled hot frame implements ONLY:

1. Per-fill state transition: for each fill in the pulse's batch,
   apply production lot semantics (FIFO close + open with full
   short/cover/CASHFLOW support per Production Lot Semantics
   section).
2. Per-fill state mutation: update `cash` and `positions[idx]`.
3. Per-fill event row construction: assemble the per-fill values for
   the memory output handler's typed columns (`cash_delta`,
   `position_delta`, `realized_pnl`, `cost_basis_after`, side, qty,
   price, fee, etc.).
4. Return per-pulse event batch (Pattern A) or write to handler's
   typed columns (Pattern B; gate runs Pattern A).

### What stays in R

- Next-bar lookup per instrument
- `ledgr_next_open_fill_proposal` call per fill (validates,
  constructs `ledgr_fill_proposal`)
- `ledgr_resolve_fill_proposal` call per fill (runs cost resolver,
  produces `ledgr_fill_intent` with `fill_price`)
- Strategy callback invocation
- ctx construction + helper attachment
- Feature engine + projection lookups
- Target validation + target-risk noop (deferred)
- Per-pulse equity computation
- Memory output handler buffer state (the handler stays in R; the
  hot frame produces values the handler writes)
- Reconstruction-pass work (none required post-Ticket-2 fold-owned;
  reconstruction is a verifier path per Round-3 L7 Ticket 2)

### Pseudo-code (corrected)

```r
# R fold loop (lives in ledgr post-promotion)
for (t in seq_len(n_pulses)) {
  ctx <- build_ctx(t, ...)                                  # R: unchanged
  targets <- strategy_fn(ctx, params)                       # R: user code
  targets <- ledgr_validate_targets(targets, ctx)           # R: contract surface
  deltas <- targets - state$positions                       # R: vectorized
  fill_idx <- which(deltas != 0)                            # R: vectorized

  # Per-fill next-open proposal + cost resolution stays R
  fill_intents <- vector("list", length(fill_idx))
  for (k in seq_along(fill_idx)) {
    i <- fill_idx[k]
    next_bar <- bars_by_id[[instrument_ids[i]]][t + 1L, , drop = FALSE]
    proposal <- ledgr_next_open_fill_proposal(deltas[i], next_bar)  # R: contract
    if (inherits(proposal, "ledgr_fill_none")) next                  # R: filter
    fill_intents[[k]] <- ledgr_resolve_fill_proposal(proposal,
                                                    cost_resolver)   # R: contract
  }
  fill_intents <- Filter(Negate(is.null), fill_intents)

  if (length(fill_intents) > 0L) {
    # ONE compiled call per pulse; all post-resolution fills batched
    pulse_result <- ledgr_b2_apply_pulse_fills(
      pulse_idx       = t,
      cash            = state$cash,
      positions       = state$positions,     # bare numeric per Ticket-3
      lots_state      = state$lots,          # fold-owned per Ticket-2
      fill_intents    = fill_intents,        # list of ledgr_fill_intent
      event_seq_base  = state$event_seq      # for monotonic id assignment
    )
    # compiled function returns updated state and per-pulse event batch
    state$cash       <- pulse_result$cash
    state$positions  <- pulse_result$positions
    state$lots       <- pulse_result$lots
    state$event_seq  <- pulse_result$event_seq_next

    # Pattern A: hand the batch to the existing memory output handler
    for (write_res in pulse_result$event_batch) {
      output_handler$buffer_event(write_res)
    }
  }

  # per-pulse equity stays R (vectorized, cheap)
  equity[t] <- state$cash + sum(state$positions * prices)
}
```

### Why per-pulse batching is still the right shape

Per the K1 evidence at `verdict.md:57-72`: per-fill R-callback
boundaries cost ~1 ms each; at 130k fills that's ~130s of pure FFI
overhead. Per-pulse boundaries cost the same ~1 ms per call but at
1260 invocations that's ~1.3s — negligible. The per-pulse batching
collapses ~130k R↔compiled hops to ~1260.

Note: the seed v1 estimated FFI overhead at ~100 μs per hop. The
actual per-pulse R-to-compiled hop cost with vector marshalling
(positions, lots, fill_intents list) is **unknown**. The gate
measures it. If per-pulse FFI cost is materially higher than 1 ms
(say, 5 ms), the overhead is 6.3s — still small but worth knowing.

## Parallel implementation in ledgrcore-spike (Rust + C++)

### Why ledgrcore-spike

Per the 2026-06-01 ledgrcore repo-split decision: implementation
work in ledgrcore-spike; promotion into ledgr's tree only if the
gate passes. Both languages implemented in parallel because the
marginal cost is small (one extra ~300-line compiled function) and
the benefit per Codex's K1 review is:

1. **Equalizes K1's build-flag asymmetry** as a measurement side
   effect (B2 gate sets `PKG_CXXFLAGS = -O3 -flto` for cpp11; Rust
   release default already uses opt-level=3 + LTO).
2. **Empirical language verdict at production-shape workload**, not
   just K1's synthetic minimum-viable loop.
3. **Reduces commitment risk**: if Rust extendr surfaces unexpected
   integration friction during promotion, C++ cpp11 is the immediate
   fallback.

### Files to add in ledgrcore-spike

```
ledgrcore-spike/
├── R/
│   └── k1_b2_prototype.R           # R prototype fold loop calling compiled per-pulse fn
├── src-rust/src/
│   └── b2_pulse_fills.rs           # Rust extendr per-pulse hot frame
├── src/
│   └── k1-b2.cpp                   # C++ cpp11 per-pulse hot frame
├── tests/testthat/
│   └── test-k1-b2-parity.R         # 3-way parity (R reference / Rust / C++)
└── inst/design/spikes/
    └── k1_b2_prototype_spike/
        └── spec.md                  # spike scope document (mirrors K1 pattern)
```

### Parity test scope in ledgrcore-spike

The ledgrcore-spike parity test covers:

1. **R reference matches K1 R reference on the K1 fixture** (regression
   guard for the lot-machinery + state-mutation work).
2. **Rust B2 matches R reference on the K1 small fixture**.
3. **C++ B2 matches R reference on the K1 small fixture**.
4. **Rust B2 matches C++ B2** (three-way agreement at the
   ledgrcore-spike level).

The ledgrcore-spike parity test does NOT cover the production
semantics (next-open, short/cover, CASHFLOW, memory output handler
integration). Those are covered by the ledgr-side production-harness
gate (Sub-B below).

## Measurement gate (v0.1.8.10 Ticket 5)

Per Codex Round-1 Finding 4, the seed v1 had a measurement gate that
contradicted itself (prototype loop vs production fold swap-in). The
corrected design splits the work into two distinct measurement
phases.

### Sub-A: feasibility benchmark in ledgrcore-spike (parallel, language comparison)

Runs in ledgrcore-spike. Compares:
- R reference (ledgrcore-spike's K1 R reference, extended with full
  production lot semantics)
- Rust B2 (ledgrcore-spike's extendr per-pulse hot frame)
- C++ B2 (ledgrcore-spike's cpp11 per-pulse hot frame)

Workload: K1's synthetic LDG-2479-shaped fixtures (small/large/xlarge).
Build flag equalization: cpp11 build uses
`PKG_CXXFLAGS = -O3 -flto` to match Rust release. **Explicit
restriction: no `-ffast-math`, no `-funsafe-math-optimizations`**;
the equity Kahan tolerance per v0.1.8.9 L4 doctrine depends on
IEEE-754 strict semantics.

Output:
- Per-cell wall (median / min / max over 5 reps + 1 warm)
- Three-way parity outcome at small fixture
- Cross-platform check: same harness runs on Windows (primary) +
  Linux + macOS at small scale (parity only; timing comparison
  out of scope for Sub-A)

Sub-A produces:
- Language verdict: which is faster on this workload
- Toolchain-friction assessment: integration friction observed for
  each language
- Build-flag verdict: do `-O3 -flto` builds preserve byte-identical
  parity (and what additional flags break it)

Sub-A is NOT the promotion gate. It's the language-decision input.

### Sub-B: production-harness measurement in ledgr (decision-bearing gate)

Runs in ledgr's `dev/bench/`. Compares:
- **Production R**: ledgr's normal post-v0.1.8.10 fold engine
  (Tickets 1-4 must have landed)
- **Production R + B2 hot frame swap**: same production fold engine
  with `output_handler$buffer_event` replaced by a path that calls
  the chosen B2 hot frame (Rust or C++ per Sub-A verdict)

The swap is via `assignInNamespace()` per the v0.1.8.10 attribution
spike spec's instrumentation discipline OR via an explicit
`use_compiled_fills = TRUE` flag in the execution spec (v2 open
question — see below).

Workload: LDG-2479 `density_high_xlarge_ephemeral` cell at production
scale.

Output:
- Wall recovery (median over 5 reps + 1 warm) of B2-swapped run vs
  production-R run
- Parity outcome against the 8 substrate-decision gates (see Parity
  Contract section below)
- Methodology note recording the swap mechanism, build flags, and
  reproducibility steps

### Gate threshold (decision-bearing)

Sub-B's outcome gates the v0.1.9.x promotion ticket. Three components,
all must hold for the gate to pass:

1. **Wall recovery ≥ 30s** on LDG-2479 `density_high_xlarge_ephemeral`
   vs the post-v0.1.8.10 production R baseline at release-gate
   closeout.
2. **All 8 substrate-decision parity gates pass** (see Parity Contract
   section below); plus the B2-specific gate that production lot
   semantics are preserved.
3. **No measurement-integrity concerns**: build flags equalized;
   instrumentation-overhead bound ≤ 5% of total wall;
   cross-rep variance ≤ 1.5× max/min; cross-platform parity
   (Linux/macOS/Windows) on the small fixture verified.

### Outcome matrix

| Rust B2 (Sub-A) | C++ B2 (Sub-A) | Production gate (Sub-B) | Action |
|:----------------|:----------------|:------------------------|:-------|
| Faster | — | Pass | Promote Rust; v0.1.9.x integration ticket |
| Slower | — | Pass | Promote C++; v0.1.9.x integration ticket (Rust loses on production-shape) |
| Pass | Pass | Pass | Promote winner by Sub-A speed; tiebreaker at ≤ 20% gap is integration friction → C++ |
| — | — | Fail | Defer; ephemeral attribution spike at `inst/design/spikes/ephemeral_wall_attribution_spike/` becomes the next v0.1.9 work |

## Parity contract (corrected to inherit 8 substrate-decision gates)

Per Codex Round-1 Finding 7, the seed v1 listed 5 parity items; the
v0.1.8.10 Round-3 substrate-decision review bound 8 gates for
fold-owned accounting (per `architecture_synthesis.md:392-423`). B2
inherits all 8 plus a B2-specific gate:

| # | Gate | Source |
|:--|:-----|:-------|
| 1 | Event log preserved: all event records byte-identical (same row order, same column values, same integer / side codes) | Round-3 Ticket 2 gate |
| 2 | Equity parity: equity vector byte-identical OR within Kahan-vs-cumsum tolerance (per v0.1.8.9 L4 doctrine) | Round-3 Ticket 2 gate |
| 3 | Fill table parity: `ledgr_results(bt, "fills")` byte-identical | Round-3 Ticket 2 gate |
| 4 | Lot-state parity: `state$lots` byte-identical (FIFO queue contents in same order with same qty/price pairs) | Round-3 Ticket 2 gate |
| 5 | Opening-position CASHFLOW coverage: CASHFLOW opening events produce the same lot state as the production path (`R/lot-accounting.R:180-217`) | Round-3 Ticket 2 gate |
| 6 | Invalid / semantic-violation coverage: invalid sides (NA from `ledgr_lot_direction`), zero qty, negative qty all produce the same fill_none / warning outcomes | Round-3 Ticket 2 gate |
| 7 | Durable readback compatibility: `ledgr_run` with durable output produces the same `ledger_events` rows as production | Round-3 Ticket 2 gate |
| 8 | No strategy lookahead: strategy callback sees the same `ctx` shape and values as production; B2 changes no input to the strategy | Round-3 Ticket 2 gate |
| 9 | **B2-specific**: full production lot direction support (BUY/COVER/BUY_TO_COVER; SELL/SHORT/SELL_SHORT); negative-lot opening; per-instrument cost basis tracking; realized PnL Kahan accumulation per `R/lot-accounting.R:49-55` | NEW for B2 |

Gates 7 (durable readback) and 8 (no strategy lookahead) are
intrinsically satisfied if the hot frame is called only on the
ephemeral path and produces the same event-buffer values as
production (see Event Buffer Contract section). The gate measurement
must verify both explicitly.

## Backward compatibility

Pre-CRAN with zero known external users. The compatibility
considerations:

- **Strategy contract unchanged**. The hot frame is invisible to user
  strategy code.
- **Event stream unchanged**. Byte-identical event output is gate
  #1 above.
- **Public API unchanged**. The hot frame is internal infrastructure.
  No exported function signatures change.
- **Default cost resolver semantics unchanged**. The cost resolver
  stays R; user-supplied resolvers work as today.
- **Build requirement change at promotion**. ledgr's main package
  gains a compiled-code dependency (extendr or cpp11). R
  contributors need the corresponding toolchain to build from source.
  This is the contributor-tax cost the repo-split decision wanted to
  avoid; the gate is the justification. Mitigation in the promotion
  ticket: clearly document the new build requirement; add
  cross-platform CI; provide pre-built binaries if feasible.

## Substrate dependencies

| Substrate | Provides | This RFC needs |
|:----------|:---------|:---------------|
| Round-3 Ticket 1 (subphase telemetry) | `t_engine`, `t_results`, `t_fills_extract` on workload-grid rows | Sub-B's wall measurement reads telemetry to confirm fill-loop body is where the wall lives |
| Round-3 Ticket 2 (fold-owned accounting) | FIFO lot state owned by fold engine; production lot semantics in fold path | Hot frame consumes the fold-owned lot state directly; production lot semantics carry through |
| Round-3 Ticket 3 (matrix-canonical substrate) | `state$positions` as bare numeric + `id_to_idx` map; integer-indexed accessors | Hot frame receives integer-indexed positions; FFI marshalling is cheap |

If any of Tickets 1-3 ships in a materially different shape than the
Round-3 synthesis specified, this RFC's hot-frame design adapts.

## Open questions (5 — reduced from v1's 6 by resolving scope contradictions)

### Q1: Pattern A vs Pattern B for event buffer interaction

The seed proposes Pattern A (hot frame returns batch; R fold loop
calls `handler$buffer_event` per fill). Pattern B (hot frame writes
typed columns directly) is a possible v0.1.9.x optimization.

**Recommended for v0.1.8.10 Ticket 5 gate**: Pattern A. Smaller
contract surface; matches production semantics directly. Pattern B
deferred to post-promotion optimization if Sub-B measurement shows
per-fill setv overhead dominates.

### Q2: Swap mechanism for Sub-B production-harness measurement

Two options:

- **`assignInNamespace`**: monkey-patches the fold engine to call
  the hot frame; matches the attribution spike's instrumentation
  pattern.
- **`use_compiled_fills = TRUE` flag**: explicit execution-spec
  field that the fold engine reads to dispatch to the hot frame.

**Recommended**: `assignInNamespace` for Sub-B (measurement
discipline matches attribution spike; no production code change to
add the flag prematurely). The flag-based approach gets added
during promotion if Sub-B passes.

### Q3: event_type classification (FILL vs FILL_PARTIAL)

Production distinguishes "FILL" (complete fill) from "FILL_PARTIAL"
(partial fill); the hot frame's per-fill output needs to set the
right one. ledgr v0.1.8.x has not yet introduced partial fills
(production fills are always complete). The hot frame can emit
"FILL" exclusively for v0.1.9.x.

**Recommended**: "FILL" only. FILL_PARTIAL becomes a follow-up RFC
when partial-fill semantics land.

### Q4: How does the gate handle Kahan-vs-LTO interactions?

Compiled code with `-O3 -flto` may reorder floating-point
operations. The equity Kahan tolerance (per v0.1.8.9 L4) depends on
strict floating-point semantics.

**Recommended**: gate explicitly requires no `-ffast-math` /
`-funsafe-math-optimizations`. Cross-platform parity check at small
fixture verifies that `-O3 -flto` preserves byte-identical equity
under strict-math constraints. If parity fails: roll back to `-O2`
for ledgr's main build; document in NEWS.

### Q5: Where does extendr live in ledgr's tree (if Rust wins promotion)

Two options: `src/rust/` (rextendr standard) or `src-rust/`
(ledgrcore-spike research convention).

**Recommended**: `src/rust/` for the promotion. rextendr's standard
pattern; cleaner R-package convention.

## Risk and failure modes

- **Gate fails**: ephemeral attribution spike at
  `inst/design/spikes/ephemeral_wall_attribution_spike/` becomes the
  next v0.1.9 work. The ledgrcore-spike B2 implementation stays as
  research evidence and informs the attribution spike's
  hypotheses.
- **Sub-A passes but Sub-B fails**: indicates the K1-shape compiled
  speedup doesn't carry to production-shape workload (maybe due to
  per-pulse FFI cost being higher than expected with vector
  marshalling, or production lot semantics being more expensive
  than K1's simpler shape). The maintainer can choose to: defer
  promotion and run the attribution spike; OR pursue Pattern B
  (handler integration) as a follow-up optimization.
- **Parity gate failure in production semantics edge cases**:
  short/cover, opening-position CASHFLOW, FILL_PARTIAL semantics
  may surface only on broader fixtures. The gate's small-fixture
  parity check needs to cover at minimum the 9-gate scope.
  Recommended: parity fixture explicitly exercises all 9 gates'
  edge cases.
- **`-O3 -flto` breaks Kahan equity parity**: roll back to `-O2`
  for ledgr's main build; gate's Sub-A measurement at `-O2` still
  decides language choice but the C++ speedup measured at `-O3
  -flto` is for reference only.
- **Cross-platform build friction (Rust extendr on macOS / Windows)**:
  the K1 spike ran Windows-only. Sub-A's cross-platform check at
  small scale catches build-system issues before the promotion
  decision. Failure here blocks promotion until resolved.
- **Per-pulse FFI overhead is much larger than 1 ms**: if Sub-B
  shows pulse-batching FFI cost is 5-10 ms (5x worse than K1's
  per-fill cost), the per-pulse boundary still beats per-fill by
  100×+. The gate threshold (30s) absorbs an FFI overhead up to
  ~24 ms per pulse before the slice is uncoverable. Worst case is
  unlikely but bounded.

## What this RFC does NOT propose

- Promoting B2 to ledgr immediately. Promotion is empirically gated.
- A specific language. Sub-A measures both; gate's outcome matrix
  decides.
- Compiling anything beyond the per-pulse fill batch. Helper
  attachment, ctx construction, feature engine, and similar
  surfaces stay R.
- Compiling user-supplied cost resolvers, risk steps, or other
  user-facing R callbacks. Those stay R.
- Adopting B2 on the durable path. Ephemeral only for v0.1.9.x.
- Replacing the K1 measurement spike's verdict. K1's "build
  authorized for inline-output design only" stands; B2 IS an
  inline-output design and inherits that authorization.
- Building a separate `ledgrcore` package. Architecture A stays
  parked unless B2's Sub-B fails AND attribution surfaces something
  unexpected.
- Bypassing the horizon's attribution gate as a general policy. The
  override is specifically for this gate with the rationale above.

## References

- K1 measurement spike verdict:
  `ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md`
- v0.1.8.10 architecture synthesis Round 3:
  `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md`
- 2026-06-01 horizon entries: Architecture B; K1 verdict;
  Ephemeral wall attribution gate (in `inst/design/horizon.md`)
- v0.1.8.9 lane attribution (LDG-2498 memory output handler
  delivered recovery):
  `inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md:193-264`
- v0.1.8.9 release closeout (delivered lanes confirmed):
  `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md:35-43, 83-88`
- Production fill model: `R/fill-model.R`
- Production lot accounting: `R/lot-accounting.R`
- Production memory output handler: `R/sweep.R:957-1190`
- Spike 12 (fold-time vs reconstruction-time lot accounting):
  `dev/spikes/spike-fold-time-lot-accounting.md`
- Amdahl-floor spike: `dev/spikes/spike-amdahl-floor.md`
- Pre-CRAN compatibility policy: 2026-05-25 horizon entry
- RFC cycle conventions: `inst/design/rfc_cycle.md`
- Seed v1: `rfc_compiled_hot_frame_b2_v0_1_9_x_seed.md`
- Response: `rfc_compiled_hot_frame_b2_v0_1_9_x_response.md`

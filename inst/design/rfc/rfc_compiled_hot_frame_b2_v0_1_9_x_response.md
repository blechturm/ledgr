# RFC Response: Compiled Hot Frame B2 (v0.1.9.x)

**Status:** Response-stage adversarial review. Not accepted. Not
authorized implementation scope.
**Cycle:** Architecture B2 measurement gate / v0.1.9.x promotion scoping.
**Relates to:** `rfc_compiled_hot_frame_b2_v0_1_9_x_seed.md`.
**Authored:** Codex (response stage; seed author was Claude per
`inst/design/rfc_cycle.md` role rotation).

## Verdict

Reject as written. The B2 direction is technically plausible, and the
seed correctly identifies the per-fill R callback trap from K1, but the
seed cannot be used as a binding ticket-cut input yet. It conflicts with
the current horizon sequencing, overstates the evidence for an 85-120s
recoverable fill-loop slice, uses K1 ceiling numbers imprecisely, and
sketches a hot-frame path that would violate current next-open fill
semantics unless substantially corrected. Push to seed v2.

## Blocking findings

### 1. B2 is sequenced before the attribution gate that the horizon currently makes binding

**Claim challenged:** The seed frames itself as "Architecture B2 measurement
gate (v0.1.8.10 Ticket 5) plus promotion to v0.1.9.x if gate passes"
(`rfc_compiled_hot_frame_b2_v0_1_9_x_seed.md:4-5`) and says that if the
gate fails, "ephemeral attribution spike becomes the next v0.1.9 work"
(`seed.md:578-580`).

**Evidence:** The 2026-06-01 K1 verdict horizon entry says the xlarge
ephemeral wall attribution must complete before either compiled-core
path is authorized (`inst/design/horizon.md:1018-1021`). Its sequencing
section says the next ledgr-side spike is the attribution spike, and B2
runs next only if attribution surfaces the fold-loop slice as meaningful
(`inst/design/horizon.md:1023-1031`). The Architecture B entry records B2
as a roadmap hook, not as authorization, and says B2 is unmeasured
(`inst/design/horizon.md:784-808`).

**What the seed should say instead:** Either (a) explicitly escalate a
maintainer decision to override the horizon sequencing and run B2 before
the attribution spike, or (b) scope this RFC as a post-attribution B2
spike design that only runs when attribution confirms the fold-loop
slice is worth compiling.

**Severity:** Blocking. This changes the v0.1.8.10 / v0.1.9 work order.

### 2. The 85-120s recoverable fill-loop slice uses stale v0.1.8.9 recovery as current residual

**Claim challenged:** The seed estimates the fill-loop body at 85-120s,
including "Memory output handler event emission ~50-75s" from "v0.1.8.9
L8" (`seed.md:116-126`), and then projects 85-120s B2 wall recovery
(`seed.md:137-155`).

**Evidence:** The memory-output-handler lane already landed in v0.1.8.9.
LDG-2498 changed the memory handler and routed sweep-summary fill buffer
(`inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md:193-206`)
and measured xlarge ephemeral wall 508.08s -> 346.63s, -161.45s
(`per_lane_attribution.md:254-264`). The release closeout records the
same lane as delivered (`v0_1_8_9_release_closeout.md:35-43`). The
remaining post-v0.1.8.9 xlarge ephemeral wall is 372.55s, but its
subphases are explicitly not attributed by the workload-grid harness
(`v0_1_8_9_release_closeout.md:83-88`).

Spike 12 only supports the fold-owned lot-accounting move as a 7-10s
R-side recovery on synthetic xlarge fixtures: reconstruction lot work
30.0s, fold-time typed-input lot work 23.1s, direct lot work 21.8s
(`architecture_synthesis.md:155-184`; `dev/spikes/spike-fold-time-lot-accounting.md:116-145`).

**What the seed should say instead:** Treat the 85-120s fill-loop slice
as a hypothesis requiring B2 measurement, not prior evidence. Do not sum
the already-delivered v0.1.8.9 memory-output recovery into a current
post-v0.1.8.10 compilable residual unless a new post-substrate
attribution measurement re-establishes it.

**Severity:** Blocking. This evidence chain is the main ROI argument for
B2 and currently double-counts a historical lane.

### 3. The hot-frame pseudo-code violates current next-open fill semantics

**Claim challenged:** The seed's pseudo-code uses current close prices:
`prices <- bars_mat$close[, t]`, then passes `prices[fill_idx]` into the
compiled hot frame (`seed.md:175-205`).

**Evidence:** Production fold semantics do not fill at current close.
The fold engine looks up the next bar for each instrument
(`R/fold-engine.R:295-300`), calls `ledgr_next_open_fill_proposal()`,
then resolves cost from that proposal (`R/fold-engine.R:306`). The fill
model requires a one-row `next_bar`, validates `instrument_id`,
`ts_utc`, and `open`, returns `LEDGR_LAST_BAR_NO_FILL` when no next bar
exists, and constructs the fill from next-open data
(`R/fill-model.R:18-70`). The default resolver then uses
`fill_context$execution_bar$open` and spread / rounding semantics
(`R/fill-model.R:148-195`).

K1's reference implementation uses current matrix prices
(`ledgrcore-spike/R/k1_r_reference.R:197-225`), but K1 is a minimum-loop
spike, not ledgr's production fill model.

**What the seed should say instead:** B2's compiled hot frame must
consume either validated next-open fill proposals or scalar next-open
execution inputs including instrument id, execution timestamp, open
price, side, quantity, and no-fill status. It must preserve final-bar
no-fill behavior and default cost resolver rounding. Current-close K1
pseudo-code is not production-faithful.

**Severity:** Blocking. This would change trading semantics.

### 4. The measurement gate contradicts itself: prototype loop vs production fold swap-in

**Claim challenged:** The gate says Rust B2 and C++ B2 are measured as
"R prototype fold loop calling ledgrcore-spike's ... hot frame"
(`seed.md:373-378`). Later the risk mitigation says the gate uses "the
actual production fold engine ... with the hot frame swapped in, not a
separate prototype loop" (`seed.md:583-588`).

**Evidence:** K1 itself warns that its R baseline is a post-v0.1.8.10
substrate model, not current production, and says ledgr should rerun
against the actual production R substrate once v0.1.8.10 ships
(`ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md:144-149`).
B2 is even more sensitive to this distinction because the value
proposition is a production wall delta on the LDG-2479 xlarge ephemeral
cell, not a minimum-loop microbenchmark.

**What the seed should say instead:** Separate the two stages. A sibling
repo prototype can compare Rust vs C++ implementation feasibility, but
the promotion gate must be a ledgr-side production-harness A/B run
against the post-v0.1.8.10 fold engine with only the hot frame swapped.
The gate cannot be passed by a separate prototype loop.

**Severity:** Blocking. This determines whether the measurement would be
decision-bearing.

### 5. K1 ceiling rates and FFI overhead are quoted too aggressively

**Claim challenged:** The seed says the compiled fold loop runs at
"0.6-2.0 us/pulse and 0.06-0.18 us/fill" (`seed.md:39-44`) and models
B2 overhead as `1260 hops x ~100us = 126ms` (`seed.md:141-145`).

**Evidence:** K1's verdict table reports for `strat_static_handler_inline`
3.78 us/pulse / 0.04 us/fill in Rust and 17.46 us/pulse / 0.17 us/fill
in C++ (`verdict.md:57-62`). For the more realistic
`strat_R_handler_inline`, it reports 11.90 us/pulse / 0.12 us/fill in
Rust and 55.56 us/pulse / 0.54 us/fill in C++ (`verdict.md:60`). The
verdict explicitly says Architecture B is not measured by K1; the closest
cell is still Architecture A (`inst/design/horizon.md:762-766`).

The ~1ms boundary cost in K1 is measured on compiled-to-R per-fill output
handler callbacks with R list/event construction (`verdict.md:18-27`,
`verdict.md:57-62`). It does not measure R-to-compiled per-pulse calls
that pass vectors, mutable state, lots, and event buffers.

**What the seed should say instead:** Cite K1's actual us/pulse and
us/fill rates by boundary. Treat per-pulse R-to-compiled overhead as an
unknown to be measured by B2, not as 100us. Keep the 30s gate as a
measurement rule, not as an extrapolated conclusion.

**Severity:** Blocking for the numeric recovery table; caveat-worthy for
the B2 direction.

### 6. The seed has internal scope contradictions around equity and cost resolvers

**Claim challenged:** The seed first says the compiled function does
"per-pulse equity inside compiled code" (`seed.md:65-71`) but later says
equity stays R (`seed.md:204-205`, `seed.md:485-494`). It also says
user-supplied cost resolvers call back to R per fill (`seed.md:263-269`)
while Q2 recommends pre-resolving costs in R before calling the hot frame
(`seed.md:496-517`).

**Evidence:** Current production separates target validation, fill
proposal, cost resolution, output write, and state mutation
(`R/fold-engine.R:248-365`). The default cost resolver is a closure over
spread / commission / rounding (`R/fill-model.R:118-146`) invoked through
`ledgr_resolve_fill_proposal()` (`R/fill-model.R:148-160`). K1 shows
per-fill R callbacks destroy the compiled win (`verdict.md:18-27`).

**What the seed should say instead:** Bind one scope. The defensible B2
scope is "per-fill state-transition and event-buffer work after R has
produced strategy targets and production-faithful fill/cost inputs."
Default-cost compilation can be in scope only if it preserves
`ledgr_cost_spread_commission_internal()` semantics. User-supplied cost
resolvers should either be explicitly out of the B2 fast path or
pre-resolved without an in-hot-frame per-fill R callback.

**Severity:** Blocking. The current seed leaves the implementation
boundary ambiguous.

### 7. The parity contract is weaker than the eight gates already bound for fold-owned accounting

**Claim challenged:** The seed lists five parity items
(`seed.md:276-295`) and the gate threshold says it uses a subset of the
eight Codex substrate-decision gates (`seed.md:405-409`).

**Evidence:** The Round-3 v0.1.8.10 synthesis binds eight parity gates
for fold-owned accounting: event log preserved, equity parity, fill
table parity, lot-state parity, opening-position CASHFLOW coverage,
invalid / semantic-violation coverage, durable readback compatibility,
and no strategy lookahead (`architecture_synthesis.md:392-423`).

The K1 lot implementation is also narrower than ledgr production. K1's R
reference errors on short lot creation (`ledgrcore-spike/R/k1_r_reference.R:64-99`),
whereas production lot accounting supports BUY/COVER/BUY_TO_COVER and
SELL/SHORT/SELL_SHORT directions and opens negative lots when needed
(`R/lot-accounting.R:13-19`, `R/lot-accounting.R:74-162`). Production
also has explicit opening-position CASHFLOW handling
(`R/lot-accounting.R:180-217`).

**What the seed should say instead:** B2 inherits all eight fold-owned
accounting gates, plus a B2-specific gate that the compiled hot frame
matches production `ledgr_lot_apply_fill()` / `ledgr_lot_apply_event()`
semantics rather than K1's simplified no-short model. Do not narrow the
parity surface because B2 is "only" a measurement gate; the measurement
is meant to support promotion.

**Severity:** Blocking. A smaller parity surface could approve a hot
frame that cannot implement ledgr semantics.

### 8. The event-buffer design risks becoming a second output path unless it is tied back to the fold-core handler contract

**Claim challenged:** Q3 recommends a long-lived compiled buffer with
bulk materialization at fold end (`seed.md:519-539`), and the proposed
hot frame mutates `output_handler$event_buffer` in-place
(`seed.md:185-201`).

**Evidence:** The current ephemeral output path is the
`ledgr_memory_output_handler()` contract. It owns capacity management,
typed event columns, meta list columns, event materialization, and
`write_fill_events()` (`R/sweep.R:957-1190`). Its materialization step
also derives `meta_json` from typed meta when required
(`R/sweep.R:1059-1101`). The repository rule is that `ledgr_run()` and
`ledgr_sweep()` share the same fold core; adding a parallel compiled
event path that only the prototype loop uses would weaken that
discipline.

**What the seed should say instead:** The B2 measurement must specify
how the compiled buffer participates in the existing output-handler
contract: event ids, event sequence, typed meta, `meta_json`
materialization, `handler$events()`, `handler$typed_events()`, and
release of the buffer at fold end. If a long-lived compiled buffer is
used, the final materialization cost is part of the B2 wall measurement.

**Severity:** Blocking for production promotion; caveat-worthy for a
throwaway feasibility prototype.

## Caveat-worthy findings

### 9. Build-flag standardization is over-broad and mis-cited

**Claim challenged:** The seed says "K1's verdict has an open caveat
about C++ build-flag asymmetry" (`seed.md:541-544`) and recommends
applying `-O3 -flto` across ledgr if promoted (`seed.md:546-552`).

**Evidence:** The external K1 verdict file's caveats cover platform,
synthetic fixture, and post-substrate model limits (`verdict.md:133-149`).
The build-flag asymmetry is recorded in ledgr's horizon entry, not in
that verdict file (`inst/design/horizon.md:970-987`). The same horizon
entry says the build-flag check is a precondition for the language
decision, not a blanket production policy.

**What the seed should say instead:** Correct the citation. Make
`-O3 -flto` a measurement-gate variant and promotion-time decision,
with explicit "no fast-math / no unsafe floating-point flags" language
and cross-platform parity before applying it to ledgr's package build.

**Severity:** Caveat-worthy. It does not invalidate B2, but it can
contaminate parity and language selection.

### 10. The "all eight are compilable" claim is too broad

**Claim challenged:** The seed says all eight fill-loop components are
compilable (`seed.md:95-112`).

**Evidence:** Some pieces are straightforward numeric state transitions,
but others are R-contract boundary surfaces: target validation and
target-risk noop (`R/fold-engine.R:248-268`), default-vs-user cost
resolver dispatch (`R/fill-model.R:118-160`), and output handler
materialization (`R/sweep.R:957-1190`). The seed itself excludes ctx
construction, helper attachment, feature engine, and strategy callback
from the hot frame (`seed.md:221-251`).

**What the seed should say instead:** Use "compilation candidates" or
"potentially compilable under a narrowed default-cost / ephemeral-output
contract." The ticket writer should not treat all eight as automatically
safe to move into compiled code.

**Severity:** Caveat-worthy. It is overstatement rather than a direct
correctness bug.

## Confirmed claims

- K1 really does authorize only inline-output compiled designs. The
  verdict says inline event accumulation clears the threshold by a wide
  margin, while per-fill R output-handler cells are near 1x
  (`verdict.md:9-27`, `verdict.md:57-72`).
- The B2 batching idea is the right response to the K1 per-fill callback
  trap. The Architecture B horizon entry explicitly says B2 should call
  compiled code per pulse, not per fill (`inst/design/horizon.md:696-702`).
- Keeping the strategy callback in R is coherent with current production
  shape: the fold engine calls `strategy_fn(ctx, params)` before target
  validation and fill resolution (`R/fold-engine.R:181-268`).
- Deferring durable adoption is reasonable. The seed correctly notes
  that durable economics include persistent write and readback surfaces
  that are not the same as the ephemeral K1-relevant case (`seed.md:564-574`).
- The v0.1.8.10 substrate dependency is real. Current production
  `state$positions` is still a named vector write in the fill loop
  (`R/fold-engine.R:354-361`), and current fold does not own lot
  accounting; B2 must wait for the post-Ticket-2/Ticket-3 shape before
  it can be production-faithful.

## Suggested additions for seed v2

1. Add a "sequencing decision" box: either this RFC requests maintainer
   override of the attribution-first horizon gate, or it explicitly waits
   for the attribution spike to confirm fold-loop share.
2. Split the measurement gate into feasibility and decision-bearing
   phases: sibling-repo language feasibility vs ledgr production-harness
   wall recovery. Only the latter can pass the promotion gate.
3. Replace the 85-120s table with a hypothesis table that names which
   components are already measured post-v0.1.8.9 and which are unknown.
4. Add a production fill-semantics section covering next-open execution,
   final-bar no-fill, spread/commission/rounding, and `ts_exec_utc`.
5. State that B2 must implement production lot-accounting semantics,
   including short/cover and opening-position CASHFLOW, not K1's simpler
   no-short reference.
6. Add an event-buffer contract section tied to
   `ledgr_memory_output_handler()`: event ids, event sequence, typed meta,
   `meta_json`, `events()`, and `typed_events()`.
7. Make build flags an explicit measured variant and require no unsafe
   floating-point flags plus cross-platform parity before promotion.

## Recommendation on next step

Push to seed v2. The direction is worth preserving, but the current seed
has enough blocking evidence and correctness issues that direct synthesis
would be unsafe. The most important v2 changes are: fix sequencing
against the attribution gate, remove stale v0.1.8.9 recovery from the
current ROI estimate, make the gate production-harness based, and correct
the fill semantics from K1 current-price shorthand to ledgr next-open
semantics.

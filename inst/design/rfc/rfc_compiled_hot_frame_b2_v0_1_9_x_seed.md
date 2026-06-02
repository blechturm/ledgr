# RFC Seed: Compiled Hot Frame B2 — Per-Pulse Fill Batch Compilation (v0.1.9.x)

**Status:** Seed v1. Not accepted. Not authorized implementation scope.
**Cycle:** Architecture B2 measurement gate (v0.1.8.10 Ticket 5) plus
promotion ticket (v0.1.9.x if gate passes). The seed covers both: the
gate-measurement spec for v0.1.8.10 and the proposed promotion shape
for v0.1.9.x.
**Promotion candidate:** v0.1.8.10 Ticket 5 (gate measurement; lives
in `ledgrcore-spike`). Promotion to v0.1.9.x if gate passes.
**Relates to:**
- the 2026-06-01 horizon entry "Architecture B: in-place hot-frame
  compilation as alternative to ledgrcore" (the architectural
  framing this RFC operationalizes);
- the 2026-06-01 horizon entry "K1 measurement-spike verdict"
  (which authorizes inline-output compiled designs and provides the
  ceiling numbers cited as evidence);
- the v0.1.8.10 Round-3 architecture synthesis L7 Ticket 2
  (fold-owned accounting) and L7 Ticket 3 (matrix-canonical
  substrate); both are prerequisites and providers of the substrate
  shape this RFC consumes;
- `ledgrcore-spike` `inst/design/spikes/k1_measurement_spike/verdict.md`
  for the K1 measurement evidence cited throughout;
- the 2026-06-01 horizon entry "Ephemeral-mode xlarge wall
  attribution as gate" (which becomes the fallback if this RFC's
  gate fails).

## Problem

ledgr's xlarge ephemeral wall is ~372s pre-v0.1.8.10 (workload-grid
baseline per `v0_1_8_9_release_closeout.md:95-100`, cited via
the v0.1.8.10 Round-2 review). The v0.1.8.10 substrate work (Tickets
1-4) is expected to compress this to ~320-355s. The remaining wall
is dominated by per-fill machinery that runs at R-interpreter speed
even after v0.1.8.10 substrate cleanups.

The K1 measurement spike (2026-06-01, `ledgrcore-spike` repo)
established two relevant findings:

1. **The compiled fold core can be very fast**: 151x speedup
   (Rust extendr) and 33x speedup (C++ cpp11) over R at xlarge on
   the `strat_static_handler_inline` boundary (both
   `ledgrcore-spike` `inst/design/spikes/k1_measurement_spike/verdict.md:60-69`).
   The compiled fold loop runs at 0.6-2.0 us/pulse and 0.06-0.18
   us/fill at xlarge.

2. **The per-fill R callback boundary dominates total wall** in
   hybrid designs: K1's `strat_R_handler_R` and
   `strat_static_handler_R` cells at xlarge are 132-145s and show
   only 0.97-1.08x compiled-vs-R ratios. The per-fill R callback
   boundary cost is ~1 ms per call regardless of which language
   wraps it (verdict.md:60-72).

K1's verdict therefore authorizes "compiled-core work only for
inline event accumulation" (verdict.md:9-11). It does NOT authorize
a hybrid compiled-fold + R-output-handler architecture, because that
shape pays the per-fill FFI cost and gets ~1x recovery.

The architectural question this RFC seed addresses is:

> Can ledgr capture the K1 ceiling's compiled-fold speedup on the
> ephemeral path **WITHOUT** building a separate `ledgrcore` package,
> by compiling the per-pulse fill batch as a single hot frame inside
> ledgr's R fold loop?

Per the 2026-06-01 Architecture B2 horizon entry, the answer is
"probably yes" — R fold loop calls the compiled function once per
pulse with the batch of fills for that pulse, paying ~1260 R-to-
compiled FFI hops per run instead of ~130k, and the compiled
function does FIFO lot accounting + position/cash updates + event
buffer writes + default cost resolver + per-pulse equity inside
compiled code with no R hops.

This RFC seed proposes the exact shape of that hot frame, the
parallel measurement gate in `ledgrcore-spike`, and the v0.1.8.10
Ticket 5 that captures the gate decision for ledgr's release.

## Background / current state

### What runs in ledgr's fold loop today (post-v0.1.8.10 substrate)

After Tickets 2 and 3 land per Round-3 synthesis, the post-v0.1.8.10
fold loop has this shape (engine phase, per pulse):

| Sub-frame | Code path | Approximate xlarge cost | Compilable under B2? |
|:----------|:----------|:------------------------|:---------------------|
| Pulse-context list allocation | `R/fold-engine.R:181-194` | ~7.5ms total (Spike 4) | No (R object construction) |
| Helper attachment | `R/fold-engine.R:196-221` | ~1.8s total per v0.1.8.8 telemetry attribution | No (R closures and R-side helpers) |
| Feature engine lookup | per-accessor in `ledgr_projection_pulse_views` | unknown; bounded by accessor count | Partial (lookups compilable; declarative features stay R) |
| Strategy callback invocation | `R/fold-engine.R:228-247` | small wrapper + user code | No (user code stays R) |
| Per-pulse position valuation | `R/fold-engine.R:164-170` | small (vectorized v0.1.8.9) | Yes |
| Target validation + target-risk noop | `R/fold-engine.R:248-268` | unknown; likely small | Yes |
| **Fill loop body** | `R/fold-engine.R:288-365` | unknown; **load-bearing** | **YES** |
| Pulse-seed RNG | `R/rng.R:33-57` | ~0.14s total (Spike 8) | Yes (but too small to ticket) |

The **fill loop body** is the headline compilation target. It runs
per fill (~130k times at xlarge) and contains:

1. Delta resolution, side code (`R/fold-engine.R:289-294`)
2. Next-bar lookup (post-v0.1.8.10 Ticket 3: scalar matrix lookup)
3. Cost resolver invocation (per-fill default
   `cost_spread_commission_internal` at `R/fill-model.R:148-195`)
4. Fill proposal construction + resolution
5. Lot machinery (post-v0.1.8.10 Ticket 2: fold-owned via
   `ledgr_lot_apply_event` / `ledgr_lot_apply_fill`)
6. Cash + positions vector mutation
7. Event buffer write via memory output handler
   (`R/sweep.R:957-1190`; v0.1.8.9 setv path)
8. (Per-pulse aggregate) equity computation from cash + positions
   times prices

All eight are compilable. Together they are the largest single
architectural compilation target ledgr has.

### Evidence: estimated wall share of the fill-loop body

Pulling together prior spike measurements (Round-3 synthesis L1,
Spike 10, Spike 12, v0.1.8.9 L8, Amdahl-floor spike):

| Component | Estimated xlarge wall share | Source |
|:----------|:----------------------------|:-------|
| FIFO lot machinery (post-Ticket-2 in fold) | ~30s | Spike 12 measurement at xlarge synthetic |
| Memory output handler event emission | ~50-75s | v0.1.8.9 L8 (recovery estimate; residual bounded by `meta` list column) |
| Default cost resolver per fill | unknown; likely 5-15s | Per-fill cost; ~130k invocations of `cost_spread_commission_internal` |
| Per-fill cash + positions mutation | small (vectorized v0.1.8.9) | Round-3 L1 |
| Per-pulse equity computation | small (vectorized) | Round-3 L1 |
| **Total fill-loop body** | **~85-120s estimated** | Sum |

This is a more aggressive estimate than the "~15%" framing carried
in earlier horizon entries. The earlier number lumped only lot
machinery into the fold-loop slice; the corrected estimate above
includes event emission and the default cost resolver, both of which
B2 can compile. The estimated share is **23-32% of pre-v0.1.8.10
xlarge ephemeral wall** (85-120s of 372s baseline).

### Evidence: what B2 would deliver at K1 ceiling rates

If the fill-loop body is 85-120s of xlarge ephemeral wall and the K1
ceiling shows compiled fill processing runs at 0.06-0.18 us/fill,
then the compiled hot frame's per-run cost for ~130k fills is:

| Language | us/fill (K1 ceiling) | Compiled work for 130k fills | + FFI overhead (1260 hops × ~100us) | Net B2 cost |
|:---------|---------------------:|-----------------------------:|------------------------------------:|------------:|
| Rust extendr | 0.056 | 7.3ms | 126ms | ~133ms |
| C++ cpp11 | 0.184 | 24ms | 126ms | ~150ms |

Wall recovery for the fill-loop body slice:

| Language | Lower bound (85s slice) | Upper bound (120s slice) |
|:---------|------------------------:|-------------------------:|
| Rust extendr | ~85s | ~120s |
| C++ cpp11 | ~85s | ~120s |

Both languages compress the slice to negligible cost. Wall recovery
on xlarge ephemeral is **~85-120s = 23-32% of pre-v0.1.8.10 baseline,
or ~25-37% of post-v0.1.8.10 baseline (if post-substrate is ~320s)**.

### Build-flag caveat (open)

The K1 verdict cites Rust as 4.6x faster than C++ on the
inline-output cells. The verdict's confidence section flags this as
partially attributable to build-flag asymmetry (Rust release builds
with opt-level=3 + LTO by default; C++ via `R CMD INSTALL .`
inherits R's Makevars defaults, typically -O2 without LTO). The B2
measurement gate proposed below equalizes build flags for both
languages, which closes this caveat as a side effect.

## Proposed direction

### The hot frame's scope: per-pulse fill batch

The compiled hot frame is a single function exposed from compiled
code, callable from R once per pulse, that processes all fills for
that pulse:

```r
# R fold loop (lives in ledgr)
for (t in seq_len(n_pulses)) {
  prices  <- bars_mat$close[, t]                    # R: scalar matrix lookup
  targets <- strategy_fn(ctx, params)               # R: user code
  deltas  <- targets - state$positions              # R: vectorized
  fill_idx <- which(deltas != 0)                    # R: vectorized

  if (length(fill_idx) > 0) {
    # ONE compiled call per pulse, all fills batched
    pulse_result <- ledgr_b2_apply_pulse_fills(
      pulse_idx     = t,
      cash          = state$cash,
      positions     = state$positions,           # bare numeric, post-Ticket-3
      lots          = state$lots,                # post-Ticket-2 fold-owned shape
      event_buffer  = output_handler$event_buffer,
      instrument_idx = fill_idx,                # integer indices into universe
      deltas        = deltas[fill_idx],          # numeric subset
      prices        = prices[fill_idx],          # numeric subset
      cost_params   = ledgr_default_cost_params(execution),  # static per run
      universe      = instrument_ids             # character; for event records
    )
    # compiled function returns updated state
    state$cash       <- pulse_result$cash
    state$positions  <- pulse_result$positions
    state$lots       <- pulse_result$lots
    # event_buffer was extended in-place inside compiled code
  }

  # equity computation stays R (vectorized, cheap)
  equity[t] <- state$cash + sum(state$positions * prices)
}
```

The compiled function does:

1. For each (instrument_idx, delta, price) in the batch:
   - Compute cash_delta from default cost resolver
   - Apply FIFO lot machinery (BUY appends; SELL FIFO closes with
     realized PnL; weighted average cost basis post-event)
   - Mutate cash + positions[instrument_idx]
   - Append event row to event_buffer (typed columns: pulse_idx,
     instrument_idx, quantity, price, cash_delta, position_delta,
     realized_pnl, cost_basis_after, side_code)
2. Return updated (cash, positions, lots) to R.

The R fold loop owns: ctx construction, helper attachment, strategy
callback, feature engine, telemetry hooks, equity computation, all
out-of-loop setup, all reconstruction work.

### Why "per-pulse" not "per-fill"

Per the K1 measurement: per-fill R↔compiled hops cost ~1 ms each.
At 130k fills that's ~130s of pure FFI overhead. Per-pulse hops cost
the same ~1 ms but at 1260 invocations that's ~1.3s — negligible.
The batching from per-fill to per-pulse is the load-bearing
architectural choice; it's why B2 captures the slice rather than
being dominated by FFI cost like K1's `*_handler_R` cells.

### Why this scope, not larger or smaller

**Smaller (lot machinery only)** would deliver ~30s recovery
(Spike 12 evidence) at higher integration cost relative to wall
recovery — adding a Rust/C++ build dependency to ledgr should
deliver more than a single sub-frame compilation. The combined hot
frame at ~85-120s expected recovery is roughly 3-4x the lot-only
scope at marginal additional implementation cost.

**Larger (also compile ctx construction, helper attachment, feature
engine)** would require compiling R-object construction patterns
that fundamentally need R-side state. The architectural framing in
the 2026-06-01 Architecture B horizon entry is: "Fold emits
accounting facts, not metrics" — the hot frame stays bounded to the
per-fill state-transition work. Helper attachment and ctx
construction are R-side R-object work; they belong on a different
optimization track (the attribution-spike work this RFC's gate
defers).

### Strategy callback semantics

The strategy callback stays R. The R fold loop invokes
`strategy_fn(ctx, params)` per pulse exactly as it does today; the
compiled hot frame is called AFTER the strategy returns its target
vector. The strategy never sees the compiled hot frame; the user
contract is unchanged.

### Cost resolver semantics

The hot frame compiles the DEFAULT internal
`cost_spread_commission_internal`. User-supplied cost resolvers
(via the public cost-API surface bound by the v0.1.9.x cost-API
synthesis) stay R callbacks. The hot frame branches at function
entry: if `cost_params` indicates "default internal", run the
compiled cost path; otherwise call back to R per fill via an
extendr/cpp11 Function callback.

This split means the hot frame's wall recovery applies to the
default-cost-resolver case (which the LDG-2479 workload-grid uses).
User-supplied cost resolvers retain current cost characteristics;
they were never part of the B2 scope.

### Parity contract

The compiled hot frame's output (updated cash, positions, lots; event
buffer rows appended) must be byte-identical to the R fold loop's
output on the same inputs, modulo the Kahan-vs-cumsum tolerance the
v0.1.8.9 L4 doctrine names. Specifically:

1. `state$cash` byte-identical after each pulse (the cash sum order
   inside the hot frame must match the R fold loop's order).
2. `state$positions[i]` byte-identical for every i after each pulse.
3. `state$lots` byte-identical: FIFO queue contents (quantity,
   cost_basis pairs in same order); per-instrument cost-basis
   weighted average byte-identical.
4. `event_buffer` rows byte-identical: same row order, same column
   values, same integer/side-code values. Numerical fields
   (realized_pnl, cost_basis_after) within Kahan tolerance only if
   the hot frame uses Kahan summation; otherwise byte-identical.
5. Final equity vector byte-identical (computed in R after pulse end
   from compiled-mutated state; same inputs produce same outputs).

The K1 spike's three-way parity discipline (R reference vs Rust vs
C++) carries forward: each of the three implementations must match
the other two on the same fixture.

## Parallel implementation in ledgrcore-spike

### Why ledgrcore-spike, not ledgr

Per the 2026-06-01 ledgrcore repo-split decision: "Adding Cargo.toml
plus a C++ toolchain to the ledgr repo would force every R
contributor to install Rust or full C++ tooling just to clone and
run tests, a tax that delivers nothing to R-side contributors."
That logic still binds. B2 implementation happens in
`ledgrcore-spike` (which already has both toolchains scaffolded from
K1) and only gets promoted into ledgr's tree after the measurement
gate passes.

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

### Both languages in parallel

The marginal cost of implementing both Rust extendr and C++ cpp11
versions is small (one extra ~300-line compiled function). The
benefits per the K1 verdict are:

- **Resolves the K1 build-flag caveat as a side effect.** B2's
  Makevars patch sets `PKG_CXXFLAGS = -O3 -flto` to equalize C++
  build flags with Rust release defaults. The B2 Rust-vs-C++ gap is
  then a real language comparison at production scale.
- **Empirical language choice at production-shape workload.** K1's
  language verdict was on the synthetic minimum-viable fold loop. B2
  measures at the production fill-batch shape. If Rust is still ~4x
  ahead after build-flag equalization, that confirms K1's verdict.
  If the gap closes to <2x, C++'s integration-friction advantage
  becomes dispositive.
- **Reduces commitment risk.** If Rust extendr surfaces unexpected
  friction during the promotion-into-ledgr step, C++ cpp11 is the
  immediate fallback without restarting the spike.

### Parity test infrastructure

The K1 measurement spike already has three-way parity test
infrastructure (`tests/testthat/test-k1-cpp-parity.R` and
`test-k1-rust-parity.R`). The B2 parity tests follow the same
pattern: synthetic fixture at the LDG-2479 small scale (50 inst x
1260 pulses x ~7k fills); run R reference + Rust B2 + C++ B2; assert
byte-identical events, Kahan-tolerant equity, three-way state
agreement.

## Measurement gate (v0.1.8.10 Ticket 5)

### Sub-A: benchmark harness in ledgr `dev/bench/`

A script in `ledgr/dev/bench/architecture_b2_measurement/` that:

1. Loads ledgr (post-v0.1.8.10 substrate; Tickets 1-4 must have
   landed).
2. Optionally loads ledgrcore-spike as a `Suggests` dependency (the
   benchmark script gates on its presence; if not installed, the
   benchmark exits with a clear message).
3. Builds the LDG-2479 `density_high_xlarge_ephemeral` cell fixture
   (1000 inst x 1260 pulses x ~130k fills).
4. Runs three implementations against the fixture:
   - **R reference**: ledgr's normal post-v0.1.8.10 fold engine.
   - **Rust B2**: R prototype fold loop calling
     ledgrcore-spike's Rust extendr hot frame.
   - **C++ B2**: R prototype fold loop calling
     ledgrcore-spike's C++ cpp11 hot frame.
5. Records median, min, max wall over 5 reps per implementation.
   Discards one warm-cache rep before each measured batch.
6. Validates parity: events from Rust B2 and C++ B2 must be
   byte-identical to events from R reference (within Kahan tolerance
   for numerical fields).
7. Writes results to
   `dev/bench/results/architecture_b2_measurement_<YYYYMMDD>.csv`
   and a methodology note at
   `dev/bench/notes/architecture_b2_measurement_methodology.md`.

Sub-A lands during v0.1.8.10 implementation (parallel to Tickets
1-4; no critical-path dependency).

### Sub-B: closeout measurement (after Tickets 2+3 land)

Run Sub-A's harness against the actual post-v0.1.8.10 ledgr build at
release-gate closeout. The measurement is part of v0.1.8.10's
release-note attribution and gates the v0.1.9.x promotion decision.

### Gate threshold

Three components, all must hold for the gate to pass:

1. **Wall recovery ≥ 30s** on LDG-2479 `density_high_xlarge_ephemeral`
   vs the post-v0.1.8.10 substrate baseline measured at release-gate
   closeout.
2. **Parity gates passed**: byte-identical event stream + Kahan-
   tolerant equity + byte-identical lot state + opening-position
   CASHFLOW coverage + invalid-side handling + short-position guard
   semantics + matches durable extraction logic. (Subset of the
   8-gate Codex substrate-decision review scope, adapted for B2.)
3. **No measurement-integrity concerns**: build flags equalized
   (`PKG_CXXFLAGS = -O3 -flto` for cpp11; Rust release default);
   cross-rep variance ≤ 1.5x max/min; no warm-cache bias > 10%
   between reps.

### Outcome matrix

| Rust B2 | C++ B2 | Action |
|:--------|:-------|:-------|
| Pass | Pass | Promote winner by speed; tiebreaker at ≤20% gap is integration friction → C++ wins |
| Pass | Fail | Promote Rust; K1's language verdict reaffirmed at production-shape |
| Fail | Pass | Promote C++; reverses K1's runtime verdict (notable finding worth a horizon update) |
| Fail | Fail | Defer; ephemeral attribution spike (already spec'd in `inst/design/spikes/ephemeral_wall_attribution_spike/`) becomes the next v0.1.9 work |

### Promotion ticket scope (v0.1.9.x, if gate passes)

The promotion ticket integrates the chosen language's hot frame into
ledgr's tree. The shape is small but real:

1. Patch DESCRIPTION: `LinkingTo: cpp11` (if C++ wins) or
   `SystemRequirements: Cargo (Rust toolchain)` plus
   `rextendr::use_extendr()` setup (if Rust wins).
2. Copy the hot-frame source from ledgrcore-spike into ledgr's
   `src/` (or `src/rust/` for Rust).
3. Promote the parity test from ledgrcore-spike into ledgr's
   `tests/testthat/`.
4. Wire the R fold engine to call the compiled hot frame in the
   ephemeral path (durable path stays R-only for v0.1.9.x; durable
   integration is a separate later ticket if measurement justifies).
5. Documentation update: NEWS, vignette mention, internal manual
   article.
6. Cross-platform CI: GitHub Actions on Linux/macOS/Windows
   confirming the build works.

## Backward compatibility

Pre-CRAN with zero known external users (per the pre-CRAN
compatibility policy at the 2026-05-25 horizon entry).

- **Strategy contract unchanged.** Strategies see the same `ctx`
  surface; the hot frame is invisible to user code.
- **Event stream unchanged.** Byte-identical event output is a
  parity gate; downstream consumers (durable reload, sweep summary,
  metrics) see the same bytes.
- **Public API unchanged.** No exported function signatures change.
  The hot frame is internal infrastructure.
- **Build requirement change.** ledgr's main package gains a
  compiled-code dependency (cpp11 or extendr). R contributors need
  the corresponding toolchain to build from source. This is the
  contributor-tax cost that the repo-split decision wanted to avoid;
  the measurement gate is what justifies paying it.
- **Cross-platform**: pre-CRAN means we can ship the change without
  a deprecation cycle. The promotion-ticket cross-platform CI step
  validates the build works on Linux/macOS/Windows before release.

## Substrate dependencies

This RFC's hot frame consumes the post-v0.1.8.10 substrate shape:

| Substrate dependency | Provides | This RFC needs |
|:--------------------|:---------|:---------------|
| Round-3 L7 Ticket 2 (fold-owned accounting) | FIFO lot state in fold engine; `realized_pnl`/`cost_basis_after` emitted per-fill | Hot frame consumes the same fold-owned lot state structure |
| Round-3 L7 Ticket 3 (matrix-canonical substrate) | `state$positions` as bare numeric + `id_to_idx` map; `ctx$vec` namespace | Hot frame receives integer-indexed positions/instrument_idx; FFI marshalling is cheap |
| Round-3 L7 Ticket 1 (subphase telemetry) | `t_engine`, `t_results`, `t_fills_extract` on workload-grid rows | Sub-B closeout measurement reads these to confirm fill-loop body is where the wall lives |

If any of Tickets 1-3 ships in a materially different shape than the
Round-3 synthesis specified, this RFC's hot-frame design adapts. The
seed assumes the Round-3 substrate shape lands as designed; the
synthesis (when it lands) should verify this assumption.

## Open questions

Six questions need maintainer or response-stage resolution. Listed
roughly in decreasing impact on the final shape.

### Q1: Hot frame scope — fill batch only, or also per-pulse equity?

The proposed scope is "fill batch only; equity stays R". Per-pulse
equity computation is `cash + sum(positions * prices)` — vectorized
in R, cheap (~6 us/pulse per the Amdahl-floor spike). Moving it into
the compiled hot frame would save ~7.5ms at xlarge, which is below
the measurement-noise floor.

**Recommended**: equity stays R. The scope boundary is "per-fill
state-transition work compiles; per-pulse aggregation stays R".

### Q2: Cost resolver branching for user-supplied resolvers

The default `cost_spread_commission_internal` is compiled inside the
hot frame. User-supplied cost resolvers stay R callbacks. The hot
frame branches at entry on a `cost_params` indicator.

**Sub-question**: how does the hot frame call back to R for the
user-supplied case? Two options:

- **Per-fill R callback** (matches K1's `*_handler_R` semantics).
  Adds ~1ms per fill of FFI overhead for user-resolver runs. ~130s
  of additional wall at xlarge — destroys the B2 win.
- **Pre-resolve all fills' costs in R before calling the hot
  frame**. The R fold loop calls the user resolver upfront for the
  pulse's batch; the hot frame receives pre-computed cash_delta
  values. No FFI hops inside; user resolver gets its R callback per
  fill but only ONCE per pulse instead of per fill.

**Recommended**: pre-resolve. User-resolver runs still pay per-fill
R cost (the resolver itself), but the FFI overhead drops to per-pulse
1260 hops, not 130k. This is the same pattern that makes B2 work in
the default case.

### Q3: Event buffer marshalling

The compiled hot frame writes events to a buffer. Three options for
how the buffer crosses the FFI boundary:

- **Compiled buffer; one bulk transfer per pulse**: hot frame
  appends to a Rust Vec / C++ std::vector. At pulse end, the hot
  frame returns the new rows to R as a list of typed vectors. R
  appends them into its own event accumulator.
- **R-owned buffer; compiled writes into shared memory**: hot frame
  receives the R event buffer's column pointers and writes directly.
  Faster but requires shared-mutable-state discipline (compiled code
  mutating R-allocated memory).
- **Compiled buffer that lives across the fold; bulk materialization
  at end**: hot frame appends to a long-lived compiled buffer that
  the R fold loop never touches mid-fold. At fold end, the compiled
  code materializes to an R-side event table.

**Recommended**: option 3 (long-lived compiled buffer). Mirrors K1's
`*_handler_inline` design. Best performance. Requires the hot frame
to expose an "end of fold" finalizer that materializes the buffer.

### Q4: Build flag standardization

K1's verdict has an open caveat about C++ build-flag asymmetry. B2's
gate measurement equalizes them via `PKG_CXXFLAGS = -O3 -flto`.

**Sub-question**: should this standard apply across ledgr (i.e.
ledgr's `src/Makevars` when promoted) or only at the B2 measurement
gate?

**Recommended**: apply across ledgr. There's no reason to ship
production C++ at -O2 if -O3 + LTO is byte-identical and faster.
Document this in NEWS for the promotion release.

### Q5: Where does extendr live in ledgr's tree (if Rust wins)?

Standard rextendr scaffold uses `src/rust/`. ledgrcore-spike used
`src-rust/` (a research-spike choice; per Stage 3 decision log).

**Recommended**: use `src/rust/` for the promotion. Aligns with
rextendr's standard pattern; cleaner R-package convention; the
ledgrcore-spike `src-rust/` was an explicit research deviation per
its decision log.

### Q6: Durable path adoption

This RFC scopes the ephemeral path only. The durable path also has
the per-fill lot machinery + event emission cost, but it ALSO has
the DuckDB write per fill which adds I/O cost the hot frame can't
optimize.

**Recommended**: defer durable adoption to a separate v0.1.9.x or
v0.2.x ticket. Ephemeral path is the K1-verdict-relevant case; the
durable path's optimization economics are different (I/O bound) and
deserve their own measurement gate.

## Risk and failure modes

- **Gate fails (both languages)**: ephemeral attribution spike
  becomes the next v0.1.9 work, per the existing spec at
  `inst/design/spikes/ephemeral_wall_attribution_spike/`. The B2
  prototype implementation in ledgrcore-spike stays as research
  evidence; no ledgr-side promotion.
- **Gate passes but production wall doesn't drop as much as
  prototype**: the prototype's R fold loop may differ from
  production's fold engine in ways that affect the wall slice the
  compiled hot frame addresses. Mitigation: the gate measurement
  uses the actual production fold engine (post-v0.1.8.10) with the
  hot frame swapped in, not a separate prototype loop.
- **Parity gate fails on edge cases not covered by small fixture**:
  the small-fixture three-way parity test may miss BUY_TO_COVER
  while long, SELL_SHORT while short, opening-position CASHFLOW
  with cost basis, or other edge cases. Mitigation: extend parity
  fixture to cover at least the eight gates from the Codex
  substrate-decision review.
- **Build-flag standardization breaks parity**: enabling LTO across
  ledgr might surface floating-point reduction order changes that
  invalidate byte-identical equity parity. Mitigation: the
  measurement gate includes a "byte-identical equity within Kahan
  tolerance" check; if -O3 + LTO breaks this, document and roll back
  to -O2 for ledgr's main build.
- **Cross-platform build friction (if Rust wins)**: Rust toolchain
  availability on contributor machines is less universal than C++.
  Mitigation: promotion ticket includes cross-platform CI; failure
  there blocks promotion until resolved.

## What this RFC does NOT propose

- Promoting B2 to ledgr immediately. Promotion is empirically gated.
- A specific language. The gate measurement decides.
- Compiling anything beyond the per-pulse fill batch. Helper
  attachment, ctx construction, feature engine, and similar surfaces
  stay R.
- Compiling user-supplied cost resolvers, risk steps, or other
  user-facing R callbacks. Those stay R.
- Adopting B2 on the durable path. Ephemeral only for v0.1.9.x.
- Replacing the K1 measurement spike's verdict. K1's "build
  authorized for inline-output design only" stands; B2 IS an inline-
  output design and inherits that authorization.
- Building a separate `ledgrcore` package. Architecture A stays
  parked unless B2's measurement surfaces something unexpected.

## References

- K1 measurement spike verdict:
  `ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md`
- v0.1.8.10 architecture synthesis Round 3:
  `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md`
- 2026-06-01 horizon entries: Architecture B; K1 verdict;
  Ephemeral wall attribution gate
- Spike 12 (fold-time vs reconstruction-time lot accounting):
  `dev/spikes/spike-fold-time-lot-accounting.md`
- v0.1.8.9 architecture synthesis (L8 memory output handler
  finding): `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`
- Amdahl-floor spike: `dev/spikes/spike-amdahl-floor.md`
- Pre-CRAN compatibility policy: 2026-05-25 horizon entry

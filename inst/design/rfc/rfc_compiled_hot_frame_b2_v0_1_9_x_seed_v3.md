# RFC Seed v3: Compiled Hot Frame B2 - Per-Pulse Fill Batch Compilation (v0.1.9.x)

**Status:** Seed v3. Incorporates Codex seed-v2 interstitial review and maintainer decision. Not accepted. Not authorized implementation scope.
**Cycle:** Architecture B2 measurement gate (v0.1.8.10 Ticket 5) plus promotion ticket (v0.1.9.x if gate passes).
**Promotion candidate:** v0.1.8.10 Ticket 5 (Sub-A in `ledgrcore-spike`; Sub-B in ledgr `dev/bench/`). Promotion to v0.1.9.x conditional on Sub-B gate.
**Authored:** 2026-06-02. Seed v3 author is Claude (same as v1 and v2 per `rfc_cycle.md` role rotation; synthesis will be authored by Codex per the rotation).
**Relates to:** seed v1, v2; response; seed-v2 review; maintainer decisions; 2026-06-01 horizon entries on Architecture B, K1 verdict, ephemeral attribution; v0.1.8.10 Round-3 architecture synthesis L7 Tickets 1-3.

## Revision notes (v2 -> v3)

Codex's seed-v2 review (2026-06-02) identified three blocking findings remaining after maintainer decisions resolved Finding 1, plus three caveats. The maintainer decision artifact (`rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`) accepts B2-first sequencing as binding input.

Structural changes from v2:

1. **Binding maintainer decision** - new section near top recording the accepted B2-first override; v2's override-request section retired.
2. **Recoverable-slice table re-bucketed** per v2-review Finding 2. Three explicit buckets: B2 first-cut recoverable (matches compiled scope), R residual outside first-cut (next-open proposal, cost resolver, target validation, ctx/helpers/features, equity), Future B2 extension candidates. 30s gate threshold calibrated against the first-cut compiled scope only.
3. **Pattern B promoted to decision-bearing** per v2-review Finding 3. Pattern A is now a contract-preserving conservative shim used as a parity/debug staging path. Pattern B (compiled event accumulation; no per-fill R handler writes) is the K1-equivalent design that inherits K1's inline-output authorization. Pattern A failure alone does NOT park B2; triggers Pattern B follow-up.
4. **Sub-B swap mechanism resolved** per v2-review Finding 4 and post-synthesis maintainer clarification. An internal unexported execution-spec enum (`compiled_accounting_model = NULL | "spot_fifo"`) dispatches the production fold engine to the scoped spot-FIFO compiled path. `NULL` is the default canonical R fold path; not public API. Instrumented copies are explicitly NOT acceptable for the promotion gate.
5. **Fresh-fill side semantics clarified** per v2-review Finding 5. Fresh fold path emits BUY/SELL only (matches `R/fill-model.R:68-96`, `R/backtest-runner.R:163-218`, `R/ledger-writer.R:27-39`). Lot-accounting side aliases (COVER, BUY_TO_COVER, SHORT, SELL_SHORT) live in `ledgr_lot_apply_event()` replay semantics for persisted events. Parity requirement split between fresh-fill path and reconstruction/verifier path.
6. **Ticket 5 ownership split** per v2-review Finding 6. Sub-A artifact lives in `ledgrcore-spike`. Sub-B artifact lives in ledgr `dev/bench/`. Both belong to v0.1.8.10 Ticket 5; the synthesis identifies them as separate ledger items under the same ticket.
7. **Middle-band review disposition added** per v2-review Finding 7. Outcome matrix gains a 15-30s "review band" row: does not pass promotion automatically; triggers maintainer review on Pattern B follow-up vs attribution sequencing.

Preserved from v2 (per v2-review confirmed absorption):
- K1 rates quoted correctly with R-to-compiled per-pulse FFI cost treated as unknown
- Next-open fill semantics restored
- User-supplied cost resolvers stay R
- Equity stays R
- Durable path deferred
- Build flags measured with no `-ffast-math` / `-funsafe-math-optimizations`
- Cross-platform parity gate
- All 8 substrate-decision parity gates inherited from Round-3 Ticket 2

## Binding maintainer decision

Per `rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`:

> "The maintainer accepts the B2-first sequencing override requested in seed v2."

The horizon's attribution-first gate is reversed for this cycle:

- **B2 measurement runs before the ephemeral attribution spike.**
- Rationale: the Rust/C infrastructure already exists in `ledgrcore-spike`. Building the compiled core components the project actually wants to measure is more direct than first building a redundant R telemetry path that may be abandoned.
- This decision does **not** authorize promotion. The compiled path must still earn its keep.
- The ephemeral attribution spike remains fallback / follow-up if B2 fails or produces an ambiguous result.

The horizon entry at `inst/design/horizon.md` 2026-06-01 ephemeral wall attribution gate will be patched post-synthesis to record the override and re-sequence the gates.

The phrase preserved for synthesis: **"The compiled path must earn its keep. If it does not meet parity, wall recovery, and integration-cost gates, it is parked and the ephemeral attribution spike becomes the next diagnostic path."**

## Problem and scope

ledgr's post-v0.1.8.9 xlarge ephemeral wall is **372.55s** per the workload-grid measurement (`v0_1_8_9_release_closeout.md:83-88`). The v0.1.8.10 substrate work (Tickets 1-4) is expected to compress this further; the post-v0.1.8.10 baseline is not yet measured.

The K1 measurement spike established that compiled fold cores meet the 5x build-authorized threshold on inline-output designs (`ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md:9-27`). The Architecture B horizon entry proposes that the same K1 ceiling can be reached without building a separate `ledgrcore` package by compiling a per-pulse hot frame inside ledgr.

The architectural question:

> **Can the per-pulse fill batch be compiled as a cpp11 / extendr hot frame inside ledgr, called once per pulse from a production R fold loop, consuming the post-v0.1.8.10 substrate shape, with byte-identical production semantics and a measured wall recovery on the LDG-2479 xlarge ephemeral cell that justifies the integration cost?**

The Sub-A feasibility benchmark in `ledgrcore-spike` produces the language verdict (Rust extendr vs C++ cpp11). The Sub-B production-harness measurement in ledgr produces the promotion verdict (pass / review band / fail) by running the production fold engine with the compiled path dispatched via an internal unexported execution-spec flag.

Scope is the per-pulse fill batch only. Helper attachment, ctx construction, feature engine, strategy callback, target validation, default cost resolver, and per-pulse equity remain R. Durable-path compilation is deferred.

## Corrected evidence - recoverable-slice table

Per v2-review Finding 2, the v2 table double-counted R-resident work in the B2-relevant total. The corrected table separates three buckets. **The 30s gate threshold below is calibrated against the B2 first-cut bucket only.**

### B2 first-cut recoverable (compiled in v0.1.9.x B2 first-cut, Pattern B)

| Component | Production source | Hypothesis range | Anchor |
|:----------|:------------------|:-----------------|:-------|
| Fold-owned FIFO lot accounting (post-Ticket-2) | `R/lot-accounting.R:74-162` invoked from fold-owned position | ~15-30s | Spike 12 measured 22-27% savings on synthetic xlarge (`dev/spikes/spike-fold-time-lot-accounting.md:116-145`); Codex lot-depth-of-1 finding caveats production upside |
| Cash and positions mutation per fill | `R/fold-engine.R:354-361` | ~1-3s | Residual after v0.1.8.9 vectorize work; per-fill scalar R writes at 130k fills |
| Event-row value construction per fill (cash_delta, signed_qty, meta payload assembly) | `R/backtest-runner.R:170-188` | ~3-8s | Currently per-fill R object construction inside `ledgr_fill_event_payload`; compilable as scalar arithmetic |
| Pattern B compiled event accumulation (typed column writes) | `R/sweep.R:1011-1057` per-fill setv writes; bounded by `meta` list column per v0.1.8.9 L8 | ~10-30s | Post-LDG-2498 residual; the lane delivered ~161s recovery already (`per_lane_attribution.md:193-264`); remaining residual is bounded by the list-column meta path |
| **Total first-cut compiled recoverable hypothesis** | - | **~29-71s** | - |

The 30s gate sits at the lower end of this range. If Pattern B measurement recovers >=30s, the hypothesis holds and promotion is justified. Below 30s but above 15s: review band (see Outcome matrix). Below 15s: hypothesis broken.

### R residual outside first-cut B2 (stays in R in v3 scope)

| Component | Production source | Notes |
|:----------|:------------------|:------|
| Next-open fill proposal construction | `R/fill-model.R:18-96` (`ledgr_next_open_fill_proposal`) | Contract surface; validates `instrument_id`, `ts_utc`, `open`; emits `LEDGR_LAST_BAR_NO_FILL` |
| Cost resolver call | `R/fill-model.R:118-195` (`ledgr_cost_spread_commission_internal`, `ledgr_resolve_fill_proposal`, `ledgr_default_cost_resolve`) | Default internal stays R; user-supplied resolvers must stay R |
| Target validation + target-risk noop | `R/fold-engine.R:248-268` | R contract surface; not in v3 first-cut |
| Pulse context construction + helper attachment | `R/fold-engine.R:181-221` | R-side object construction; not in v3 first-cut |
| Feature engine + runtime projection lookup | `R/runtime-projection.R` plus per-accessor calls | R contract surface |
| Strategy callback invocation | `R/fold-engine.R:228-247` | User code; cannot be moved |
| Per-pulse equity computation | computed by fold engine after pulse fills | Vectorized in R; cheap; consistency with helper attachment in R |

These components are NOT counted toward the gate threshold. If post-Sub-B residual measurement shows any of them dominate the post-B2 wall, they become candidates for future RFCs.

### Future B2 extension candidates (post-promotion, separate RFCs if surfaced)

| Component | Expected hypothesis | Trigger to revisit |
|:----------|:--------------------|:-------------------|
| Default-cost resolver compilation | ~5-15s additional | Sub-B residual measurement shows cost resolver as >=20% of remaining wall |
| Target validation fast path | unknown | Attribution evidence or production profiling |
| Pattern A -> Pattern B migration of the contract-preserving shim (if Pattern A is used as staging) | small once Pattern B lands | Always - Pattern A is staging, not destination |

## Production semantics

### Next-open fills

Production fills at next-open via `ledgr_next_open_fill_proposal()` (`R/fill-model.R:18-96`). The R fold loop:

1. Reads `next_bar` for each instrument with non-zero delta (`R/fold-engine.R:295-296`).
2. Calls `ledgr_next_open_fill_proposal(desired_qty_delta, next_bar)` (`R/fold-engine.R:297-300`). Validates `instrument_id` (non-empty character), `ts_utc` (required), `open` (finite numeric > 0). Returns `ledgr_fill_proposal` with `execution_bar` OR `ledgr_fill_none` with `warn_code = "LEDGR_LAST_BAR_NO_FILL"` on final pulse.
3. Resolves cost via `ledgr_resolve_fill_proposal(proposal, cost_resolver)` (`R/fold-engine.R:306`). Returns `ledgr_fill_intent` with `fill_price` (spread-adjusted, rounded to `price_round_digits`), `side` ("BUY" or "SELL" only), `qty`, `ts_exec_utc`, `commission_fixed`.
4. Filters `ledgr_fill_none` (emits `LEDGR_LAST_BAR_NO_FILL` warning when applicable) and invalid `fill_price` (`R/fold-engine.R:308-332`).
5. Hands the surviving `ledgr_fill_intent` batch to the compiled hot frame.

The hot frame consumes post-resolution intents only. Next-bar lookup, proposal construction, cost resolution all stay R.

### Cost resolver boundary

Default cost resolver is `ledgr_cost_spread_commission_internal()` (`R/fill-model.R:118-146`). Closure over `spread_bps`, `commission_fixed`, `price_round_digits`. Default resolution at `R/fill-model.R:162-195` applies spread multiplier (`(1 + spread_bps / 10000)` for BUY, `(1 - spread_bps / 10000)` for SELL), rounds to `price_round_digits`. Stays R.

User-supplied cost resolvers (per the v0.1.9.x cost-API surface) also stay R. The hot frame never calls back into R for cost resolution; the fold loop pre-resolves all fill intents for the pulse before invoking the hot frame.

### Lot semantics (fresh fold path vs replay)

Production has two lot-accounting code paths with **different side support**.

**Fresh fold path** (this is what B2's compiled hot frame implements):

- `ledgr_fill_intent$side` is "BUY" or "SELL" only (`R/fill-model.R:68`).
- `ledgr_fill_event_payload` emits `event_type = "FILL"` and signed_qty logic based on BUY/SELL (`R/backtest-runner.R:170-175`, `R/backtest-runner.R:196`).
- Durable write validation accepts only BUY/SELL at the fill-intent boundary (`R/ledger-writer.R:27-39`).
- Per-fill cash mutation per `R/fold-engine.R:354-361`: BUY = -(qty x price + commission); SELL = qty x price - commission.

**Replay / verifier path** (`ledgr_lot_apply_event`, `ledgr_lot_apply_fill`):

- Accepts broader aliases via `ledgr_lot_direction()` (`R/lot-accounting.R:13-19`): BUY/COVER/BUY_TO_COVER map to direction +1; SELL/SHORT/SELL_SHORT map to direction -1.
- Handles negative-lot opening, FIFO close walk in both directions, opening-position CASHFLOW (`R/lot-accounting.R:180-217`).
- Used for replaying persisted events from `ledger_events` (durable readback, sweep summary reconstruction).

**B2 first-cut implements fresh-fold-path semantics only.** Reconstruction/verifier parity must preserve the broader replay semantics, but the compiled hot frame is invoked only in the fresh-fold path, so the alias surface for B2 is BUY/SELL only.

Parity tests split accordingly:
- **Fresh fold parity**: hot frame's per-fill outputs (signed_qty, cash_delta, position_delta, fold-owned lot state) byte-identical to production `R/fold-engine.R:288-365` on the same fixture.
- **Replay parity (unchanged)**: persisted events through `ledgr_lot_apply_event` continue to produce the same reconstructed state. B2 does not modify replay semantics; the parity test simply confirms reconstruction-time results still match.

### Event output contract

The compiled fast path must preserve every observable surface of `ledgr_memory_output_handler()` (`R/sweep.R:957-1190`):

- `event_id` (constructed as `paste0(run_id, "_", sprintf("%08d", event_seq))` per `R/backtest-runner.R:191`)
- `event_seq` (monotonic; handler manages `state$event_count`)
- `event_type` ("FILL" for v3 first-cut; `FILL_PARTIAL` deferred until partial-fill semantics land in a separate RFC)
- `instrument_id`, `side` (BUY/SELL), `qty`, `price` (= `fill_price`), `fee` (= `commission_fixed`)
- Typed `meta` list with `cash_delta`, `position_delta`, `commission_fixed`, `realized_pnl` (NULL for fresh fills per `R/backtest-runner.R:183-188`)
- `cash_delta` / `position_delta` typed attributes accessible via the sweep summary fast path
- `meta_json` materialization behavior - deferred serialization per `R/sweep.R:1059-1075`; typed consumers (sweep summary) skip materialization; durable consumers materialize via `canonical_json(meta)`
- `handler$events()` (`R/sweep.R:1186-1188`) returns full data.frame including materialized `meta_json`
- `handler$typed_events()` (`R/sweep.R:1183-1185`) returns typed events without `meta_json` materialization

**Preserving the contract** is mandatory. **Using the current R handler write loop** is what Pattern A does. **Compiling event accumulation** is what Pattern B does. Pattern A and Pattern B can both preserve the contract; only Pattern B inherits K1's inline-output authorization.

## B2 compiled path

### First-cut compiled scope (Pattern B)

The compiled hot frame `ledgr_b2_apply_pulse_fills` is called once per pulse with the post-resolution `ledgr_fill_intent` batch for that pulse. Inside the hot frame:

1. **For each fill in the batch:**
   - Apply fold-owned FIFO lot semantics (fresh fold path: BUY/SELL only; signed_qty from side; cash_delta from BUY/SELL formula in `R/fold-engine.R:354-359`).
   - Mutate `cash` and `positions[idx]`.
   - Compute event row values (cash_delta, position_delta = signed_qty, meta values).
   - Append to compiled-side typed column buffers - this is the inline event accumulation that makes the design K1-equivalent.
2. **At pulse end:**
   - Return updated (cash, positions, lots) to R.
   - Compiled buffers persist across pulses inside the hot frame (long-lived buffer).
3. **At fold end:**
   - Bulk materialize compiled buffers into the memory output handler's typed columns via a finalizer call.
   - Handler's downstream surfaces (`handler$events()`, `handler$typed_events()`, sweep summary fast path) work unchanged from production.

The bulk materialization preserves the handler contract while keeping per-fill writes inside compiled code.

### What stays R

- Next-bar lookup
- `ledgr_next_open_fill_proposal` (production contract surface)
- `ledgr_resolve_fill_proposal` (default + user-supplied cost resolvers all stay R)
- `ledgr_fill_none` filtering + `LEDGR_LAST_BAR_NO_FILL` warning emission
- ctx construction + helper attachment
- Strategy callback invocation
- Target validation + target-risk noop
- Feature engine + runtime projection
- Per-pulse equity computation
- Handler initialization, capacity policy, materialization endpoints (`handler$events()`, `handler$typed_events()`)
- Reconstruction-pass work (post-Ticket-2 is a verifier path; not invoked on the ephemeral fresh-fold path)

### Event accumulation strategy

Pattern B is the decision-bearing path. Two staging options exist for the implementation:

**Option B.1 - long-lived compiled buffer:** the hot frame owns typed column buffers across the entire fold (one allocation per fold, geometric growth on overflow). At fold end, a finalizer marshals the buffers into the handler's columns. Per-pulse FFI overhead is one round-trip per pulse; per-fill cost stays compiled.

**Option B.2 - per-pulse compiled buffer:** the hot frame allocates a typed buffer per pulse, fills it, returns it to R, and R appends into the handler's columns. Per-pulse FFI overhead includes one buffer return; per-fill cost stays compiled; per-pulse buffer materialization adds R-side append cost.

The first-cut implements B.1 (matches K1's `*_handler_inline` model and inherits K1's authorization most directly). B.2 is documented as a fallback if B.1 surfaces marshalling difficulties.

**Pattern A** (contract-preserving shim) returns a per-pulse event batch and the R fold loop calls `handler$buffer_event` per fill. Pattern A may be used as a parity/debug staging step during implementation, but Pattern A is **not the decision-bearing gate** and Pattern A passing does **not** authorize promotion. See Outcome matrix below.

## Measurement gate

### Sub-A - feasibility / language benchmark in `ledgrcore-spike`

**Purpose:** language comparison and toolchain-friction assessment. Not the promotion gate.

**Scope:**
- Implement Pattern B per-pulse hot frame in Rust extendr (`src-rust/src/b2_pulse_fills.rs`) and C++ cpp11 (`src/k1-b2.cpp`).
- R prototype fold loop in `R/k1_b2_prototype.R` invoking either implementation.
- Three-way parity test against ledgrcore-spike's R reference (extended with fresh-fold-path lot semantics; long-only no-short is acceptable for Sub-A because the K1 fixture doesn't exercise short paths).
- Workload: K1's synthetic LDG-2479-shaped fixtures (small / large / xlarge).
- Build flag equalization: `PKG_CXXFLAGS = -O3 -flto` for cpp11; Rust release default (opt-level=3 + LTO). **No `-ffast-math` / `-funsafe-math-optimizations`**.
- Cross-platform parity check (Windows / Linux / macOS at small scale; parity only, not timing).

**Output:**
- Per-cell wall (median / min / max over 5 reps + 1 warm)
- Three-way parity outcome at small fixture
- Language verdict: which is faster on this workload
- Build-flag verdict: does `-O3 -flto` preserve byte-identical parity under strict-math
- Cross-platform parity outcome

Sub-A produces inputs to the promotion language choice; it does NOT pass or fail the promotion gate.

### Sub-B - production decision-bearing gate in ledgr `dev/bench/`

**Purpose:** measure wall recovery and parity of the compiled Pattern B path against the post-v0.1.8.10 production R fold engine. This IS the promotion gate.

**Swap mechanism:** internal unexported execution-spec enum `compiled_accounting_model`, defaulting to `NULL`. In the first scoped gate the closed set is `NULL` and `"spot_fifo"`: `NULL` means the production R loop (`R/fold-engine.R:288-365`), and `"spot_fifo"` means the scoped spot-asset FIFO compiled hot frame.

- **Not public API.** Documented in internal-only context.
- **Tested:** unit tests exercise both dispatch paths; `compiled_accounting_model = "spot_fifo"` path requires the chosen language toolchain installed (`Suggests`-style availability gate). Test fixtures cover BUY/SELL fresh-fill semantics, `LEDGR_LAST_BAR_NO_FILL` semantics, invalid-fill_price path, unsupported accounting-model fail-closed behavior, and the 8 substrate-decision parity gates.
- **Production-grade integration:** lives in `R/fold-engine.R` and the compiled function is registered via the ledger-spike crate (Sub-A) or ledgr-internal compiled source (post-promotion).

Instrumented-copy / `assignInNamespace()` is explicitly NOT acceptable for the Sub-B gate. The attribution spike's instrumented-copy approach is for attribution measurement, not for production integration validation.

**Workload:** LDG-2479 `density_high_xlarge_ephemeral` cell at production scale (1000 inst x 1260 pulses x ~130k fills).

**Output:**
- Wall recovery (median over 5 reps + 1 warm): production R baseline vs `compiled_accounting_model = "spot_fifo"` run
- Parity outcome against all 9 parity gates (8 substrate + B2-specific lot semantics; see Parity Contract)
- Build flags actually used (recorded for reproducibility)
- Cross-platform parity confirmation at small fixture
- Methodology note recording the swap mechanism, build flags, and reproducibility steps

### Gate thresholds and outcome matrix

| Wall recovery (Sub-B, xlarge ephemeral) | Parity gates | Disposition |
|:----------------------------------------|:-------------|:------------|
| >= 30s | All 9 pass | **PASS** - promote chosen language per Sub-A verdict; v0.1.9.x integration ticket |
| 15s <= recovery < 30s | All 9 pass | **REVIEW BAND** - does not pass automatically. Maintainer review on: (a) revisit Pattern B materialization strategy (Option B.1 vs B.2); (b) profile post-B2 residual to identify next lever; (c) consider running ephemeral attribution spike to characterize the remaining wall. Promotion deferred to a follow-up RFC. |
| < 15s | All 9 pass | **FAIL** - B2 hypothesis broken; the fold-loop slice is smaller than the 30s gate threshold OR Pattern B doesn't deliver K1 ceiling rates at production-shape. Park B2. Ephemeral attribution spike becomes next diagnostic path. |
| any | Any parity gate fails | **FAIL** - production-faithful parity is non-negotiable. Park B2. Investigate parity failure mechanism. |

Pattern A failure is **not** in the matrix. If Pattern A is used as a parity/debug staging step and fails, the appropriate response is to debug Pattern A toward correctness (parity-only) before measuring Pattern B. Pattern A's measurement is informational, not decision-bearing.

### Ticket 5 ownership split

| Sub-artifact | Repository | Owner |
|:-------------|:-----------|:------|
| Sub-A: Rust + C++ Pattern B implementations + ledgrcore-spike parity tests + cross-platform check | `ledgrcore-spike` | Sub-A artifact within Ticket 5 |
| Sub-B: ledgr `compiled_accounting_model = "spot_fifo"` dispatch + production-harness benchmark + parity test suite | `ledgr` | Sub-B artifact within Ticket 5 |

Both Sub-A and Sub-B belong to the same Ticket 5. The synthesis lists them as separate ledger items under the ticket. If the maintainer ever revisits the B2-first decision and restores attribution-first sequencing, Sub-A's design remains as a reusable spike input; Sub-B does not run until B2 is re-sequenced.

## Parity contract

Inherits all 8 substrate-decision gates from Round-3 Ticket 2 (`architecture_synthesis.md:392-423`) plus a B2-specific lot-semantics gate.

| # | Gate | Source | Applies to fresh-fold path? | Applies to replay path? |
|:--|:-----|:-------|:----------------------------|:------------------------|
| 1 | Event log preserved (byte-identical row order, column values, integer / side codes) | Round-3 Ticket 2 | Yes | Yes (unchanged by B2) |
| 2 | Equity parity (byte-identical OR Kahan-vs-cumsum tolerance) | Round-3 Ticket 2 | Yes | Yes |
| 3 | Fill table parity (`ledgr_results(bt, "fills")` byte-identical) | Round-3 Ticket 2 | Yes | Yes |
| 4 | Lot-state parity (`state$lots` byte-identical FIFO queue) | Round-3 Ticket 2 | Yes | Yes |
| 5 | Opening-position CASHFLOW coverage (same lot state as `R/lot-accounting.R:180-217`) | Round-3 Ticket 2 | N/A (CASHFLOW is set up before fold loop) | Yes (replay path unchanged) |
| 6 | Invalid / semantic-violation coverage (invalid sides, zero qty, negative qty produce same fill_none / warning outcomes) | Round-3 Ticket 2 | Yes (BUY/SELL only at fresh boundary) | Yes (broader alias coverage unchanged) |
| 7 | Durable readback compatibility (`ledger_events` rows match production) | Round-3 Ticket 2 | Yes | Yes |
| 8 | No strategy lookahead (strategy callback sees same `ctx` shape and values) | Round-3 Ticket 2 | Yes (B2 changes no strategy input) | N/A |
| 9 | **B2-specific:** fresh-fold path emits BUY/SELL only with signed_qty per `R/backtest-runner.R:170-175`; per-instrument cost basis tracking; realized PnL Kahan accumulation per `R/lot-accounting.R:49-55`. Replay-path side aliases unchanged. | NEW for B2 | Yes (BUY/SELL only) | Yes (replay path preserves broader aliases) |

The fresh-fold parity gate is the load-bearing one for v3 first-cut. Replay parity is satisfied automatically because B2 does not modify the replay code path; the gate is included to verify nothing accidentally broke.

## Open questions promoted to synthesis / spec-cut

These are decisions the synthesis stage (or spec-cut writer) should bind:

### Q1 - Pattern B materialization strategy: Option B.1 (long-lived buffer + finalizer) vs Option B.2 (per-pulse buffer + R append)

Seed recommends B.1 (matches K1's `*_handler_inline` model most directly). The synthesis can confirm or revise based on Sub-A measurement of marshalling cost. If B.1 surfaces FFI marshalling complexity that B.2 avoids, B.2 becomes the fallback.

### Q2 - `compiled_accounting_model` field placement on the execution spec

The seed places this as an unexported field on the execution spec. The synthesis should bind:
- exact field placement (`compiled_accounting_model` is the post-synthesis field shape);
- which `ledgr_execution_spec_v1` slot it lives in;
- default value (`NULL`) and visibility (unexported);
- behavior when the toolchain is unavailable (graceful error vs silent fallback to R).

### Q3 - Long-lived buffer lifetime and reset semantics

Option B.1's compiled buffer is owned by the hot frame across the fold. The synthesis should bind:
- buffer initialization (per fold start or per execution spec setup);
- buffer reset on retry / re-run / sweep candidate reuse;
- buffer destruction on fold end / error / interrupt.

### Q4 - Language choice mechanism after Sub-A produces verdict

Sub-A outputs the language verdict. The synthesis should bind whether v3-first-cut implements both languages and the promotion ticket selects one, or whether Sub-A's verdict is sufficient to commit to one language for the promotion ticket directly. (Recommended: commit at promotion ticket; Sub-A produces the verdict; ledgrcore-spike retains both implementations as research evidence.)

### Q5 - Where extendr lives in ledgr's tree if Rust wins promotion

Seed recommends `src/rust/` (rextendr standard) over `src-rust/` (ledgrcore-spike research convention). Synthesis confirms.

### Q6 - Cross-platform CI scope for promotion

Sub-A confirms cross-platform parity at small fixture. Promotion requires Linux / macOS / Windows CI. The synthesis should bind:
- CI workflow scope (parity-only or parity + timing);
- platform matrix (R version x OS x toolchain version);
- failure modes that block release.

## Risks and failure modes

- **Sub-B fails on parity:** production-faithful parity is non-negotiable. Investigate the specific gate failure; common causes include side-alias drift between fresh-fold and replay paths, Kahan accumulation order differences, event_seq sequencing mismatch on retry paths.
- **Sub-B passes parity but wall recovery falls in the review band:** maintainer reviews per the disposition matrix; possible outcomes include Pattern B materialization revision (Option B.1 -> B.2), targeted attribution to identify the post-B2 residual, or escalation to the ephemeral attribution spike for the unexplained slice.
- **Sub-B fails the wall threshold (< 15s recovery):** B2 hypothesis broken; ephemeral attribution spike becomes the next diagnostic path; ledgrcore-spike B2 implementations preserved as research evidence informing the attribution.
- **`-O3 -flto` breaks Kahan-tolerant equity parity:** roll back to `-O2` for ledgr's main build; Sub-A's language verdict at `-O3 -flto` becomes reference-only; promotion-time build flags stay `-O2`.
- **Cross-platform build friction (Rust extendr on macOS / Windows):** Sub-A's small-fixture cross-platform check catches build-system issues. Failure blocks promotion until resolved.
- **Per-pulse R-to-compiled FFI overhead is materially higher than 1ms:** the 30s gate absorbs FFI overhead up to roughly 24ms per pulse before the slice is uncoverable. Sub-A measures the actual FFI cost; Sub-B's measurement quantifies it at production-shape.
- **Replay-path side alias regression:** B2 does not modify the replay path, but the parity test suite must exercise replay explicitly to confirm. A regression here is a parity gate failure (#9 caveat).
- **`compiled_accounting_model` surface broadens beyond intended:** the field is unexported, closed to `NULL | "spot_fifo"` in the first gate, and tests cover both paths plus unsupported values. Any future RFC that exposes the field publicly or adds a non-spot accounting value requires its own RFC.

## What this RFC does NOT propose

- Promoting B2 to ledgr immediately. Promotion is empirically gated by Sub-B parity + 30s wall recovery.
- A specific language. Sub-A measures both Rust extendr and C++ cpp11; outcome matrix decides at promotion ticket.
- Compiling anything beyond the per-pulse fill batch. Helper attachment, ctx construction, feature engine, target validation, default cost resolver, equity all stay R.
- Compiling user-supplied cost resolvers, risk steps, or other user-facing R callbacks.
- Adopting B2 on the durable path. Ephemeral only for v0.1.9.x.
- Modifying replay-path side semantics. Lot-accounting aliases (COVER, BUY_TO_COVER, SHORT, SELL_SHORT) for persisted events are unchanged.
- Replacing the K1 measurement spike's verdict. K1's "build authorized for inline-output design only" stands; B2 Pattern B IS an inline-output design and inherits that authorization. Pattern A does not.
- Making `assignInNamespace()` an acceptable Sub-B mechanism. The promotion gate requires production-grade dispatch via the unexported `compiled_accounting_model` enum.
- Bypassing the horizon's attribution gate as general policy. The override is specifically for this cycle with the binding maintainer decision above.
- Authorizing FILL_PARTIAL semantics. Hot frame emits `event_type = "FILL"` only; partial-fill semantics live in a separate RFC if ever scoped.
- Authorizing public API surface for `compiled_accounting_model`. The field is internal-only; exposing it publicly requires its own RFC.

## References

- K1 measurement spike verdict: `ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md`
- v0.1.8.10 architecture synthesis Round 3: `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md`
- 2026-06-01 horizon entries (Architecture B; K1 verdict; Ephemeral wall attribution gate): `inst/design/horizon.md`
- v0.1.8.9 lane attribution (LDG-2498 memory output handler delivered recovery): `inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md:193-264`
- v0.1.8.9 release closeout: `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md:35-43, 83-88`
- Production fold engine fill loop: `R/fold-engine.R:275-365`
- Production fill model: `R/fill-model.R:18-96, 118-195`
- Production fill event payload (fresh-fold semantics): `R/backtest-runner.R:141-218`
- Production lot accounting (replay semantics): `R/lot-accounting.R`
- Production ledger writer (fresh-fold validation): `R/ledger-writer.R:27-39`
- Production memory output handler: `R/sweep.R:957-1190`
- Spike 12 (fold-time vs reconstruction-time lot accounting): `dev/spikes/spike-fold-time-lot-accounting.md`
- Amdahl-floor spike: `dev/spikes/spike-amdahl-floor.md`
- Pre-CRAN compatibility policy: 2026-05-25 horizon entry
- RFC cycle conventions: `inst/design/rfc_cycle.md`
- Seed v1: `rfc_compiled_hot_frame_b2_v0_1_9_x_seed.md`
- Seed v2: `rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2.md`
- Response (Round 1): `rfc_compiled_hot_frame_b2_v0_1_9_x_response.md`
- Seed v2 review: `rfc_compiled_hot_frame_b2_v0_1_9_x_seed_v2_review.md`
- Maintainer decisions: `rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`



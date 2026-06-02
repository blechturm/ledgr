# RFC Synthesis: Compiled Hot Frame B2 (v0.1.9.x)

**Status:** Synthesis. Binding artifact pending final review.
**Cycle:** Architecture B2 measurement gate and v0.1.9.x promotion scoping.
**Synthesizes:** seed v1, response, seed v2, seed-v2 review,
maintainer decisions, seed v3.
**Consumes:** v0.1.8.10 Round-3 architecture synthesis, K1 verdict,
and maintainer decision artifact as binding inputs.
**Authored:** Codex (synthesis stage; seed v3 author was Claude per
`inst/design/rfc_cycle.md` role rotation).
**Next stage:** final review by Claude (verification, not design).

## Summary verdict

This synthesis accepts seed v3's direction and binds the B2-first
measurement path. The maintainer decision overrides the prior
attribution-first sequencing: v0.1.8.10 Ticket 5 measures a production-
faithful compiled per-pulse fill-batch hot frame before the ephemeral
wall attribution spike. This is not promotion authorization. Promotion
requires Pattern B, not Pattern A, to pass production parity and deliver
at least 30s wall recovery on the LDG-2479 xlarge ephemeral cell. A
15-30s recovery is a review band, not an automatic pass. Below 15s or
any parity failure parks B2 and makes the ephemeral attribution spike
the next diagnostic path.

## Decisions bound by this synthesis

### D1: B2-first sequencing override

**Binding answer:** Accept the maintainer override recorded in
`rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`: B2
measurement runs before the ephemeral wall attribution spike.

**Reason:** The maintainer's premise is product-level and explicit:
since the `ledgrcore-spike` repo already has compiled infrastructure,
the more direct test is to build the compiled components intended for
use and let them earn their keep under production parity and wall gates.
The override changes sequencing only. It does not weaken the gate or
authorize compiled code if the production result is weak.

**Disposition:** Closed decision.

### D2: Decision-bearing pattern

**Binding answer:** Pattern B is the only decision-bearing compiled
design. Pattern A may be used as a parity/debug staging shim, but Pattern
A timing cannot promote or park B2.

**Reason:** Pattern A preserves R handler writes and therefore does not
measure the K1-relevant inline-output surface. K1's large ceiling came
from inline accumulation, not from paying per-fill R callback/handler
cost. Seed v3 correctly promotes Pattern B to the measured path: compiled
event accumulation with no per-fill R handler writes. Pattern A failure
means the staging shim needs debugging; it is not evidence against
Pattern B.

**Disposition:** Closed decision.

### D3: First-cut compiled scope

**Binding answer:** The first-cut B2 hot frame owns the post-resolution
per-pulse fill batch: FIFO lot-state transition for fresh fold fills,
cash and positions mutation, event row value construction, and compiled
typed event accumulation. R keeps strategy execution, ctx construction,
target validation, target risk, next-open proposal, cost resolution,
features, equity reconstruction, metrics, durable persistence, and event
replay.

**Reason:** Current production fold code resolves next-open fills before
state mutation (`R/fold-engine.R:288-365`). The proposal and cost
resolver live in R (`R/fill-model.R:18-96`, `R/fill-model.R:118-195`);
user cost resolvers must remain R for this first cut. The fresh fold
event payload is built in `R/backtest-runner.R:141-218`, while the
memory handler owns event buffering/materialization in
`R/sweep.R:957-1190`. Moving the per-fill mutation plus event
accumulation into the compiled hot frame is the narrow surface that
matches the maintainer's direct-measurement premise without prematurely
compiling strategy or cost-model semantics.

**Disposition:** Closed decision.

### D4: Fresh-fill and replay semantics

**Binding answer:** Fresh fold fills emit BUY/SELL only. Replay aliases
such as COVER, BUY_TO_COVER, SHORT, and SELL_SHORT remain
lot-accounting/reconstruction semantics and must not be introduced into
the fresh fold event stream.

**Reason:** The fill proposal returns BUY/SELL for executed fills
(`R/fill-model.R:68-96`), event construction records that side in the
fresh fold path (`R/backtest-runner.R:163-218`), and ledger writing
validates BUY/SELL events (`R/ledger-writer.R:27-39`). The wider side
alias set is part of `ledgr_lot_apply_event()` replay semantics in
`R/lot-accounting.R`, not the fresh execution contract.

**Disposition:** Closed decision.

### D5: Production measurement mechanism

**Binding answer:** Sub-B must measure through the real ledgr fold path
using an internal, unexported execution-spec field such as
`use_compiled_fills`, defaulting to `FALSE`. Instrumented copies,
`assignInNamespace` swaps, or benchmark-only alternate fold engines are
not acceptable for the promotion gate.

**Reason:** The gate is whether production ledgr should adopt the
compiled path. That requires the same fold entry, output handler
contract, validation boundary, and result materialization surfaces the
package will actually ship. A benchmark-only wrapper can test a
mechanism, but it cannot authorize promotion.

**Disposition:** Closed decision, with exact field naming/placement
promoted to spec-cut.

### D6: Ticket 5 ownership split

**Binding answer:** Ticket 5 has two sub-artifacts under one decision:
Sub-A in `ledgrcore-spike` proves language feasibility and small-fixture
parity; Sub-B in ledgr `dev/bench/` is the production decision-bearing
gate.

**Reason:** Sub-A answers whether Rust/C/C++ can implement the hot frame
cleanly with acceptable build and parity behavior. Sub-B answers whether
the chosen compiled path earns its keep in ledgr at production shape.
Conflating them would either over-promote a toy fixture or overburden the
language spike with package integration details.

**Disposition:** Closed decision.

### D7: Gate thresholds

**Binding answer:** On the LDG-2479 `density_high_xlarge_ephemeral`
production cell, B2 passes only if Pattern B delivers at least 30s wall
recovery and all parity gates pass. A 15-30s recovery with parity is a
maintainer review band. Less than 15s, or any parity failure, fails the
B2 promotion gate.

**Reason:** Seed v3 correctly calibrates the threshold against the
first-cut recoverable slice, not against residual R costs outside B2
scope. The middle band prevents a hard false negative for a useful but
not-yet-decisive result, while avoiding automatic promotion for a path
that may not justify permanent compiled-core complexity.

**Disposition:** Closed decision.

### D8: Parity gate scope

**Binding answer:** Promotion requires the eight substrate-decision gates
from the v0.1.8.10 Round-3 synthesis plus the B2 fresh/replay side
semantics gate. Required coverage includes event realized PnL and cost
basis parity, equity-time-series parity, opening-position and CASHFLOW
coverage, event ordering/identity preservation, BUY/SELL fresh-fill
semantics, replay alias preservation, and memory-handler output shape
preservation.

**Reason:** Current metrics derive from equity plus fills, but users and
reconstruction paths still rely on events as evidence. The memory output
handler exposes both materialized event columns and typed-event
internals (`R/sweep.R:1035-1101`, `R/sweep.R:1157-1188`). The compiled
path must preserve those observables, not merely final portfolio value.

**Disposition:** Closed decision.

### D9: Build flags and platform policy

**Binding answer:** Sub-A may measure optimized builds such as
`-O3 -flto`, but promotion must not use `-ffast-math` or
`-funsafe-math-optimizations`. If the more aggressive optimization
profile breaks parity, ledgr promotion falls back to the fastest
parity-preserving build profile. Cross-platform parity is required;
cross-platform timing is informative but not a release blocker unless it
reveals a functional integration problem.

**Reason:** ledgr's deterministic contracts make mathematical drift a
correctness issue, not a benchmark detail. The compiled path must earn
wall recovery without weakening numeric reproducibility.

**Disposition:** Closed decision, with exact CI matrix promoted to
spec-cut.

### D10: Public API and durable scope

**Binding answer:** `use_compiled_fills` remains internal and disabled
by default. No public compiled-mode flag ships in this RFC. Durable-path
compiled integration is explicitly deferred until the ephemeral gate
passes and a separate durable integration design is justified.

**Reason:** The decision under test is whether compiled per-pulse fill
batches are worth promoting at all. Public API and durable persistence
semantics add surfaces that would obscure the first production gate.

**Disposition:** Closed decision.

## v3 absorption verification

Seed v3 absorbed the response and seed-v2 review findings sufficiently
for synthesis.

- The B2-first maintainer decision is recorded as binding, and the
  earlier override-request framing is retired.
- The recoverable-slice table is re-bucketed into first-cut compiled
  scope, R residual, and future B2 extension candidates. The 30s gate is
  now calibrated to first-cut scope.
- Pattern B is decision-bearing; Pattern A is parity/debug staging only.
- The production swap uses an internal execution-spec field rather than
  instrumented copies or `assignInNamespace`.
- Fresh BUY/SELL fold semantics are separated from replay aliases.
- Ticket 5 ownership is split cleanly between `ledgrcore-spike` Sub-A
  and ledgr Sub-B.
- The 15-30s review band prevents automatic promotion on marginal wall
  recovery.
- K1 rates, next-open semantics, R cost resolvers, R equity, durable
  deferral, no-fast-math build flags, and cross-platform parity are all
  preserved from v2.

One synthesis-stage hygiene fix was applied directly to seed v3: mojibake
characters were mechanically cleaned in place at the maintainer's request.
No seed v4 is required for that cleanup.

## Code-citation verification

The load-bearing citations in seed v3 and this synthesis are verified
against current source, with one interpretation constraint:

| Surface | Verified source | Synthesis read |
| --- | --- | --- |
| Fold fill loop | `R/fold-engine.R:288-365` | R currently performs next-open lookup, proposal, cost resolution, event creation, handler write, cash mutation, and position mutation in the per-fill loop. |
| Cash/position mutation | `R/fold-engine.R:354-361` | This is inside the first-cut compiled scope once the fill has been resolved. |
| Fill proposal | `R/fill-model.R:18-96` | Fresh fills emit BUY/SELL and use next-open semantics. |
| Cost resolver | `R/fill-model.R:118-195` | User cost models stay in R for the first cut. |
| Event payload | `R/backtest-runner.R:141-218` | The compiled path must reproduce fresh event fields and typed metadata. |
| Event side validation | `R/ledger-writer.R:27-39` | Fresh ledger-side events are BUY/SELL. |
| Memory output handler | `R/sweep.R:957-1190` | Handler columns, typed events, materialization, and event identity must be preserved. |
| Lot replay machinery | `R/lot-accounting.R` | Replay alias handling remains R-side reconstruction semantics unless a later RFC expands scope. |
| Round-3 parity scope | `inst/design/spikes/ledgr_v0_1_8_10_optimization_round_spike/architecture_synthesis.md:392-423` | The substrate parity gates are inherited by B2. |
| K1 verdict | `ledgrcore-spike/inst/design/spikes/k1_measurement_spike/verdict.md:9-27`, `:57-72` | K1 supports measuring a compiled hot frame directly but does not itself authorize ledgr promotion. |

No phantom citation requires seed v3 revision. The only correction needed
at synthesis stage was encoding cleanup in the original seed v3 file.

## Open questions promoted to spec-cut

These are same-window ticket-cut choices. They do not require another RFC
unless implementation discovers a contract conflict.

1. **Execution-spec field placement and name.** Ticket cut should choose
   the exact internal field name, default value, constructor validation,
   and fail-loud behavior when a compiled backend is unavailable. The
   bound behavior is internal-only, default `FALSE`, no public API.

2. **Pattern B buffer materialization strategy.** Option B.1
   (long-lived compiled buffer plus fold-end finalizer) is the preferred
   first-cut target because it best preserves K1's inline-output shape.
   Option B.2 (per-pulse compiled buffer plus R append) is an
   implementation fallback only if Sub-A proves B.1 disproportionately
   complex. The promotion gate must state which option was measured.

3. **Compiled buffer lifetime and reset semantics.** Ticket cut must pin
   allocation, growth, finalization, teardown on error, and per-run reset.
   The handler-facing output must remain indistinguishable from the R
   memory handler.

4. **Language choice after Sub-A.** Sub-A should select the implementation
   language by parity, integration cost, build reproducibility, and
   production-shape timing, not by toy-fixture timing alone.

5. **Cross-platform CI matrix.** Promotion requires functional parity on
   Windows, macOS, and Linux. Timing can be single-host/local unless the
   ticket writer decides to add informational CI timing.

6. **Toolchain availability behavior.** Ticket cut must define how ledgr
   behaves when the compiled backend is unavailable: the default R path
   must remain correct, and test/benchmark paths must fail loudly when
   they explicitly request the compiled path.

## Future obligations recorded

These concerns are outside this RFC's promotion gate and require separate
design work if B2 passes or if residual profiles justify them.

1. **Compile cost resolution.** User-supplied cost resolvers stay R-side.
   A compiled default-cost fast path or cost-model ABI belongs to a later
   cost-API/compiled-boundary RFC.

2. **Compile target validation or strategy callbacks.** The strategy,
   target validation, risk layer, and feature surfaces remain R. Moving
   them into compiled code would reopen callback semantics and is outside
   B2.

3. **Durable compiled integration.** Durable persistence, replay, and
   reopen/resume semantics need a separate design after the ephemeral
   gate passes.

4. **Partial fills and expanded side semantics.** If ledgr later adds
   partial fills, shorting, or richer OMS side types, the compiled hot
   frame must be revisited under the target-risk/OMS boundary.

5. **Public compiled execution controls.** A user-facing flag, package
   option, or backend selector is deferred until the compiled path has
   shipped internally and proven stable.

6. **Ephemeral wall attribution fallback.** If B2 fails, falls below
   threshold, or lands in the review band without a clear promotion
   story, the ephemeral attribution spike becomes the next diagnostic
   path for v0.1.9 direction.

## Implementation handoff to ticket cut

Ticket cut should work from this sequence:

1. Sub-A in `ledgrcore-spike`: implement the Pattern B hot frame on
   K1-shaped fixtures, including fresh BUY/SELL FIFO transitions, cash
   and position mutation, typed event accumulation, small-fixture parity,
   build-flag comparison, and cross-platform parity smoke tests.

2. Sub-B in ledgr `dev/bench/`: add an internal production switch,
   route the real fold through the compiled path when explicitly enabled,
   and benchmark the LDG-2479 `density_high_xlarge_ephemeral` cell with
   five measured reps plus one warmup.

3. Parity tests: cover event field identity, event ordering, realized PnL
   and cost basis, cash and position mutation, final positions, equity
   tolerance, opening-position and CASHFLOW cases, BUY/SELL fresh side
   semantics, replay alias preservation, and memory-handler materialized
   output shape.

4. Documentation artifacts: record methodology, build flags, Sub-A
   language verdict, Sub-B wall/parity result, exact measured Pattern B
   materialization option, and disposition against the threshold matrix.

5. Governance: if Sub-B passes, cut a v0.1.9.x integration ticket. If it
   falls in the review band, require maintainer review before promotion.
   If it fails, park B2 and run or revive the ephemeral attribution spike.

## Recommendation on next step

Proceed to final review. Seed v3 absorbed the substantive findings, the
maintainer's sequencing decision is now explicit, and this synthesis
closes the remaining design choices tightly enough for ticket cut. No
seed v4 is needed. Final review should verify citations, threshold
language, parity scope, and the distinction between Pattern A staging and
Pattern B promotion.

## Process notes

Role rotation is compliant: Claude authored seed v3, Codex authored this
synthesis. File naming follows `rfc_compiled_hot_frame_b2_v0_1_9_x_*`.
The original seed v3 was cleaned in place per maintainer instruction; no
additional seed file was created. This cycle is intentionally measurement-
first but not promotion-first: compiled code is allowed to prove itself
directly, and it is rejected or deferred if the production gate does not
justify the complexity.

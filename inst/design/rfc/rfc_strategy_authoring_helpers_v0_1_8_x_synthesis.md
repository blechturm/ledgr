# RFC Synthesis: Strategy Authoring Helpers (v0.1.8.x)

**Status:** Synthesis. Binding artifact pending final review.
**Cycle:** v0.1.8.x ergonomics.
**Synthesizes:** seed v1, response, seed v2.
**Consumes:**
`rfc_strategy_callback_contract_addendum_v0_1_8_10_synthesis.md` and
its final review as binding accessor substrate.
**Authored:** Codex (synthesis stage; v2 author was Claude per
`rfc_cycle.md` section "Role rotation").
**Next stage:** final review by Claude (verification, not design).

## Summary verdict

Accept seed v2's direction and bind the RFC as an extension of the existing
strategy helper pipeline, not as a new helper library. The binding answers are:
preserve the current naming split (`ledgr_` for value types, unprefixed verbs
for pipeline operations), keep sizing helpers ctx-aware when they need full
universe expansion, use stage-specific NA rules, implement only Pass 1 internal
optimization in v0.1.8.10, defer Pass 2 public helper extensions to v0.1.9, and
update existing documentation surfaces in place. Q6's pure-helper boundary is
already verified and remains bound. No seed v3 or maintainer escalation is
needed; proceed to final review, then cut v0.1.8.10 tickets against Pass 1.

## Decisions bound by this synthesis

### Q1: Naming policy for new helpers

**Binding answer:** preserve the existing split: value-type constructors use
the `ledgr_` prefix; pipeline verbs remain unprefixed.

**Status:** closed decision.

**Reason:** the current public surface is coherent and already documented.
Value types are exported as `ledgr_selection`, `ledgr_signal`,
`ledgr_target`, and `ledgr_weights` (`NAMESPACE:117-118`, `136`, `140`).
Pipeline verbs are exported as `select_top_n`, `signal_return`,
`target_rebalance`, and `weight_equal` (`NAMESPACE:142-145`). The contract pins
the helper pipeline with those names at `inst/design/contracts.md:254-260`,
and the strategy guide teaches the same names at
`vignettes/strategy-development.qmd:456-559`.

Pre-CRAN status means a rename is technically available, but internal
coherence argues against it. New Pass 2 helpers should follow the same stage
verb style, for example `select_bottom_n`, `weight_score`, `target_dollar`,
and `rebalance_when_drift`, unless a later RFC introduces a broader naming
consolidation.

### Q2: Sizing-helper signature and partial-selection contract

**Binding answer:** new sizing helpers that convert sparse selections or
weights into executable targets are ctx-aware. The bound shape for the Pass 2
candidate is `target_dollar(weights, ctx, budget)`, returning a full-universe
`ledgr_target`. Empty selection produces a full zero target, not a length-zero
target and not an error.

**Status:** closed decision for the design; implementation deferred to Pass 2.

**Reason:** `ledgr_target()` is a thin wrapper around full named target
quantities and rejects invalid target vectors (`R/strategy-types.R:216-228`).
The validator unwraps `ledgr_target` at `R/strategy-contracts.R:24-31` and
reorders valid targets to universe order at `R/strategy-contracts.R:95`.
Existing `target_rebalance()` already solves the partial-selection problem by
taking `ctx`, reading `ctx$universe`, constructing a full zero vector, and
filling selected instruments (`R/strategy-helpers.R:211-251`).

A no-ctx signature such as `target_dollar(weights, prices, budget)` is not
bound because it cannot safely expand a sparse selection to a full executable
target without either a `universe` argument or full-universe input vectors.

### Q3: Stage-aligned NA policy

**Binding answer:** use stage-specific NA handling, not a uniform permissive or
uniform strict rule.

**Status:** closed decision.

**Reason:** the existing helper value types already encode stage semantics.
`ledgr_signal()` permits warmup `NA` and rejects infinite values
(`R/strategy-types.R:108-122`). `select_top_n()` ignores missing signal values,
returns a classed empty selection when all values are missing, and warns on
partial selection (`R/strategy-helpers.R:117-145`). `ledgr_weights()` and
`ledgr_target()` reject non-finite executable values
(`R/strategy-types.R:180-228`). `target_rebalance()` preserves the existing
target-stage special case: selected instruments with missing, non-finite, or
non-positive close prices warn and target zero (`R/strategy-helpers.R:238-249`).

Pass 2 helpers must inherit their stage's rule:

- signal transforms may carry warmup `NA`;
- selection helpers must document explicit NA exclusion / empty-selection
  behavior;
- weighting helpers must produce finite weights;
- target constructors must produce finite full-universe target quantities;
- trigger and diagnostic helpers must state their NA policy explicitly.

### Q4: Pass 1 in v0.1.8.10, Pass 2 in v0.1.9

**Binding answer:** v0.1.8.10 includes Pass 1 only: internal optimization of
the existing helper pipeline to consume the accessor RFC's `ctx$vec` surface,
with no public helper-surface change. Pass 2 public helper extensions move to
v0.1.9.

**Status:** closed decision.

**Reason:** v0.1.8.10 is the closing round of the v0.1.8.x single-core arc.
Pass 1 is contract-preserving and directly tied to the accessor substrate:
`signal_return()` currently loops through scalar `ctx$feature()` over
`ctx$universe` (`R/strategy-helpers.R:76-87`), and `target_rebalance()` loops
through selected ids with scalar `ctx$close(id)` (`R/strategy-helpers.R:211-251`).
Rewriting those internals to use `ctx$vec$feature(feature_id)` and
`ctx$vec$close` is the smallest coherent follow-through from the accessor RFC.

Pass 2 adds new public helpers and documentation surface. The horizon already
records those additions as a conservative extension queue:
rank-weight helpers, inverse-volatility weighting, explicit normalization,
rebalance bands/no-trade zones, and diagnostics
(`inst/design/horizon.md:1225-1243`). That is real v0.1.9 ergonomics work, not
a closing-round optimization requirement. Pulling Pass 2 into v0.1.8.10 would
turn the single-core closeout into a public API expansion and would dilute the
measurement discipline of the accessor / substrate round.

The v0.1.9 ticket writer may use this synthesis as the binding starting point
for Pass 2 if the helper extensions remain within the stage model recorded
here. A separate RFC is required only if v0.1.9 wants to add long-short,
levered, cost-aware, declarative-strategy, or compiled-boundary helper shapes.

### Q5: Documentation policy

**Binding answer:** update existing documentation surfaces in place. Do not add
a parallel "Common Strategy Patterns" vignette page for Pass 1.

**Status:** closed decision.

**Reason:** the strategy guide already teaches the helper pipeline at
`vignettes/strategy-development.qmd:456-559` and troubleshoots invalid helper
outputs at `vignettes/strategy-development.qmd:762-790`. The contract already
pins helper semantics at `inst/design/contracts.md:240-272`, and the signal
wrapper is documented at `vignettes/strategy-development.qmd:843-846`.

For v0.1.8.10 Pass 1, documentation work is small: state that existing helpers
now consume `ctx$vec` internally where useful and that public strategy code is
unchanged. For v0.1.9 Pass 2, extend the same stage sections in place, update
troubleshooting for new helper error classes, and add roxygen cross-references.

### Q6: Pure-helper boundary

**Binding answer:** helpers stay pure authoring transformations that produce
signals, selections, weights, diagnostics, or target quantities. Target-risk,
walk-forward, and cost layers chain outside this helper RFC.

**Status:** closed decision, recorded without relitigation per response F2 Q6.

**Reason:** the chainable-risk synthesis binds a `targets -> targets` risk
chain after strategy target validation; it does not authorize target-risk to
perform sizing, cost, liquidity, ranking, or OMS work. The walk-forward
synthesis preserves `function(ctx, params) -> full named numeric target vector`.
The cost-API synthesis states that strategies do not receive cost-related
state. The helper pipeline therefore terminates in ordinary validated targets,
and downstream layers remain separate.

## v2 absorption verification

Seed v2 absorbed the response's load-bearing findings correctly.

| Response finding | v2 absorption | Synthesis read |
|---|---|---|
| v1's greenfield framing was wrong because a helper pipeline already exists. | v2 revision note flips the RFC to extension of the existing pipeline and cites `R/strategy-helpers.R:76-251`, tests, contracts, and vignette. | Correctly absorbed. |
| Q1 needed naming policy over existing exports. | v2 reframes naming around `ledgr_` value types and unprefixed pipeline verbs. | Correctly absorbed; synthesis binds preserving the split. |
| Q2 needed exact `ledgr_target()` signature and partial-selection handling. | v2 records `ledgr_target(x, universe = NULL, origin = NULL)` and recommends ctx-aware sizing. | Correctly absorbed; synthesis binds ctx-aware shape. |
| Q3 needed stage-aligned NA policy. | v2 replaces uniform permissive policy with per-stage semantics. | Correctly absorbed. |
| Q4 needed extension scope by pipeline stage, not core/tier greenfield list. | v2 reframes as Pass 1 internal optimization and Pass 2 per-stage extensions. | Correctly absorbed; synthesis binds Pass 1 only for v0.1.8.10. |
| Q5 should update existing docs, not create parallel docs. | v2 points to the existing strategy guide and contract sections. | Correctly absorbed. |
| Q6 was verified correct. | v2 records pure-helper boundary as bound. | Correctly absorbed; no relitigation. |
| Citation corrections: target-risk noop line range, `feature_id` naming, removal stubs. | v2 corrects `R/backtest-runner.R:542-544`, uses `ctx$vec$feature(feature_id)`, and labels `targets` / `current_targets` as removal stubs. | Correctly absorbed. |
| Pass 1 vector inputs. | v2 mentions `ctx$vec$positions` as part of Pass 1 helper optimization. | Synthesis narrows Pass 1 to the vectors the current helpers actually read. `target_rebalance()` uses `ctx$universe`, `ctx$equity`, and scalar `ctx$close(id)` at `R/strategy-helpers.R:211-251`; it does not read positions today. Ticket cut should not add `ctx$vec$positions` use unless implementation proves a real need. |

No seed v3 is needed. No synthesis-stage patch requests are recorded.

## Code-citation verification

Load-bearing v2 citations were spot-checked against current source:

| Citation | Verification |
|---|---|
| `R/strategy-helpers.R:76` | `signal_return()` exists and reads a `return_<lookback>` feature over `ctx$universe`. |
| `R/strategy-helpers.R:117` | `select_top_n()` exists and handles missing signal values, empty selection, partial warnings, and deterministic tie-breaking. |
| `R/strategy-helpers.R:163` | `weight_equal()` exists and converts `ledgr_selection` to `ledgr_weights`. |
| `R/strategy-helpers.R:211` | `target_rebalance()` exists, validates ctx, rejects negative/leverage, builds a full zero target, and returns `ledgr_target`. |
| `R/strategy-types.R:108`, `143`, `180`, `216` | `ledgr_signal`, `ledgr_selection`, `ledgr_weights`, and `ledgr_target` definitions exist. |
| `R/strategy-contracts.R:24-31`, `95` | `ledgr_target` unwrap logic exists and validated targets are reordered to universe. |
| `R/fold-engine.R:248-268` | Fold engine rejects intermediate helper outputs, wraps numeric results, validates targets, then applies target risk. |
| `R/pulse-context.R:375-412` | Existing ctx helper bundle exists; `targets` and `current_targets` are removal stubs. |
| `R/signal-strategy.R:32-104` | `ledgr_signal_strategy()` compatibility wrapper exists. |
| `R/backtest-runner.R:542-544` | `ledgr_apply_target_risk_noop()` exists and returns `targets`. |
| `NAMESPACE:117-145` | Value types, helper verbs, and `ledgr_signal_strategy` are exported. |
| `inst/design/contracts.md:240-272` | Helper pipeline contract exists and names the current four verbs. |
| `inst/design/contracts.md:286` | `ledgr_signal_strategy()` compatibility wrapper is contractually recognized. |
| `inst/design/contracts.md:380-385` | Scalar `ctx$feature(instrument_id, feature_id)` contract exists. |
| `vignettes/strategy-development.qmd:456-559` | Existing helper pipeline teaching exists. |
| `vignettes/strategy-development.qmd:762-790` | Existing helper troubleshooting section exists. |
| `vignettes/strategy-development.qmd:843-846` | Signal-wrapper documentation exists. |
| `tests/testthat/test-strategy-types.R:1-65` | Value-type and invalid-output tests exist. |
| `tests/testthat/test-strategy-reference.R:1-178` | Existing helper pipeline tests and execution fixture exist. |
| `inst/design/horizon.md:543-606` | R-side substrate entry exists and frames v0.1.8.x / v0.1.9 substrate work as the no-regret path before compiled core. |
| `inst/design/horizon.md:1225-1243` | Helper-extension queue exists and already says the public pipeline should be extended conservatively. |

No phantom citations were found in seed v2.

## Open questions promoted to spec-cut

These are same-window implementation decisions. They do not need another RFC.

### Pass 1 fallback strategy

Ticket cut must decide whether `signal_return()` and `target_rebalance()` use
`ctx$vec` unconditionally after the accessor RFC lands, or whether they keep a
small fallback to scalar helpers when an old synthetic/test context lacks
`ctx$vec`. Decision rule: public pulse contexts produced by ledgr should use
`ctx$vec`; lightweight test-only list contexts may either be upgraded or
covered by a narrow fallback if that keeps tests clearer.

### File organization

For v0.1.8.10 Pass 1, edit `R/strategy-helpers.R` in place. For v0.1.9 Pass 2,
ticket cut can decide whether new helpers live in `R/strategy-helpers.R` or a
new `R/strategy-helpers-extensions.R`. Decision rule: use a new file if Pass 2
adds more than a small number of helpers or diagnostics; otherwise keep the
pipeline in one file.

### Performance wording

Pass 1 docs may say the helpers consume the vector accessor internally. They
should not claim material speedup until implementation measurement shows it.
If measurement is neutral, docs should frame the change as implementation
alignment with the accessor substrate rather than a user-visible speed lane.

### v0.1.9 Pass 2 helper subset

This synthesis records the stage model and likely candidate families. The
v0.1.9 ticket writer chooses the exact first Pass 2 subset within the bound
stage categories. Decision rule: prioritize helpers named in the horizon queue
(`inst/design/horizon.md:1234-1239`) and avoid any helper that requires
shorting, leverage, cost-aware decision-time estimates, or order-policy
semantics.

## Future obligations recorded

### Long-short, hedged, and levered helpers

Current target construction rejects negative and levered weights
(`R/strategy-helpers.R:226-230`), and the contract states that v0.1.x does not
define supported broker-style short-selling semantics
(`inst/design/contracts.md:282-284`). Long-short, hedged, market-neutral, and
levered helper families require a separate RFC after shorting/leverage
semantics are designed. Target window: v0.1.9+ or v0.2.x, depending on
roadmap priority.

### Cost-aware sizing helpers

The cost-API synthesis keeps cost as experiment-level engine work and says
strategies do not receive cost-related state. Any helper that estimates or
optimizes against transaction costs inside the strategy callback needs a
separate read-only estimator RFC and must not blur fill-time cost resolution.
Target window: after the public cost API lands.

### Declarative `ledgr_strategy()` constructor

A declarative constructor that composes signal, selection, weighting, sizing,
and triggers is larger than this RFC. It would create a new strategy-authoring
DSL and should get its own RFC if the helper family grows enough to justify it.
Target window: v0.2.x or later.

### Compiled-strategy callback boundary

The compiled boundary remains out of scope. The 2026-06-01 horizon update moved
K1 measurement into a separate `ledgrcore-spike` repo, and this helper RFC does
not reopen that decision. Any compiled strategy callback contract belongs to a
future RFC after the separate spike reports.

### Bulk feature-map vector helpers

This helper RFC consumes only the accessor synthesis's bound
`ctx$vec$feature(feature_id)` surface. Bulk multi-feature reads,
feature-map-vector helpers, and lookback-window vector access belong to a
future feature-engine RFC if the single-feature vector surface proves
insufficient. Target window: v0.1.9 or later.

## Implementation handoff to ticket cut

### v0.1.8.10 Pass 1

Ticket cut should scope only contract-preserving optimization of existing
helpers:

- `R/strategy-helpers.R:76-87`: update `signal_return()` to consume
  `ctx$vec$feature(feature_id)` for ledgr-produced pulse contexts while
  preserving current output shape and error behavior.
- `R/strategy-helpers.R:211-251`: update `target_rebalance()` to consume
  `ctx$vec$close` where useful while preserving the existing full-zero target
  expansion, negative/leverage rejection, invalid-price warning, whole-share
  flooring, and `ledgr_target` output.
- `tests/testthat/test-strategy-reference.R`: retain existing tests and add
  parity coverage showing helper-composed strategies produce the same targets,
  fills, and equity as before.
- `tests/testthat/test-strategy-types.R`: keep existing value-type tests
  unchanged.
- `vignettes/strategy-development.qmd:456-559`: add a small note that the
  public helper pipeline now uses the vector accessor internally where useful;
  no public code change.
- `inst/design/contracts.md:240-272`: update only if implementation needs a
  one-sentence note about internal vector access. Do not alter the strategy
  output contract.

Verification gates:

- existing helper pipeline tests pass unchanged;
- byte-identical or tolerance-identical run outputs for representative
  helper-composed strategies before/after Pass 1;
- scalar helper error classes remain unchanged for unknown feature ids and
  invalid prices;
- no new public helper exports in v0.1.8.10 from this RFC.

### v0.1.9 Pass 2

Ticket cut may use this synthesis as input for a public helper-extension
packet:

- preserve unprefixed verb naming for new pipeline helpers;
- use the stage categories: signal transform, selection, weighting, target
  construction, trigger/no-trade-zone, diagnostics;
- bind stage-specific NA policy per Q3;
- extend `inst/design/contracts.md:240-272` in place;
- extend `vignettes/strategy-development.qmd` in place;
- add per-helper unit tests and composition parity tests;
- do not add long-short, levered, cost-aware, declarative-constructor, or
  compiled-boundary helpers without a separate RFC.

## Recommendation on next step

Proceed to final review by Claude. If final review verifies the synthesis, cut
v0.1.8.10 tickets for Pass 1 only. No maintainer escalation is needed because
Q4 can be defensibly closed from code and roadmap evidence: Pass 1 is
contract-preserving optimization directly tied to the accessor substrate, while
Pass 2 is new public helper surface already queued as conservative future
extension work. No seed v3 is needed because v2 absorbed the response findings
cleanly and no citation defects were found.

## Process notes

Role rotation is satisfied: Claude authored seed v1 and seed v2, Codex authored
the response and this synthesis, and Claude should author final review. File
naming follows `rfc_cycle.md`. This synthesis does not edit v1, v2, or the
response. It separates same-window spec-cut questions from future obligations
per `rfc_cycle.md` and treats pre-CRAN status precisely: no external migration
burden, but existing contracts, tests, exports, and vignette examples remain
binding internal coherence surfaces.

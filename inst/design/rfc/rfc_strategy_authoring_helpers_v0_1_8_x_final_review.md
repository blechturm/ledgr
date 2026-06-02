# RFC Final Review: Strategy Authoring Helpers (v0.1.8.x)

**Status:** Final review. Verification only (no design).
**Cycle:** v0.1.8.x ergonomics.
**Reviews:** `rfc_strategy_authoring_helpers_v0_1_8_x_synthesis.md`
(Codex). Cross-references seed v1, response, seed v2, and the binding
accessor substrate (`rfc_strategy_callback_contract_addendum_v0_1_8_10_*`).
**Authored:** Claude (final review; did not author synthesis per
`rfc_cycle.md` §"Role rotation").
**Next stage:** v0.1.8.10 ticket cut for Pass 1; v0.1.9 ticket cut for
Pass 2 when the helper-extension window opens.

## Verdict

**Approve synthesis as-is. No patches required. Proceed to v0.1.8.10
ticket cut for Pass 1 only; Pass 2 is bound design for v0.1.9.**

Synthesis is internally consistent with seed v2, all sampled
citations verify against the source, the six decisions (Q1-Q5 + Q6
recorded-as-bound) are decisively closed, and the synthesis's Pass 1
narrowing (dropping `ctx$vec$positions` because `target_rebalance()`
doesn't actually read positions) is empirically correct and improves
on v2. Two informational items below are worth recording for ticket
cut but do not warrant synthesis or v2 patches.

## Verification scope

Per `rfc_cycle.md` §"Final review scope": this review checks mutual
consistency, code-citation accuracy, decision-resolution coverage,
helper existence, and example arithmetic. It does NOT open new design
space, re-litigate decisions, propose new architecture, or edit any
artifact.

## Code-citation verification

Synthesis claims "Verified" for 21 citations. Spot-checked 7 of them
directly against the source (additional to the verifications I did
during seed v2 absorption). All confirmed.

| Citation | Synthesis claim | Verified result |
|---|---|---|
| `R/backtest-runner.R:542-544` | `ledgr_apply_target_risk_noop()` exists and returns `targets`. | Confirmed. Function definition is `ledgr_apply_target_risk_noop <- function(targets, ctx, params) { targets }` at exactly lines 542-544. The v1-to-v2 line-range correction from `:539-541` was right. |
| `inst/design/horizon.md:1225-1243` | Helper-extension queue exists and lists rank-weight, inverse-vol, normalization, rebalance bands, diagnostics. | Confirmed. The "2026-05-25 [strategy] Target construction helper extensions" entry exists at exactly this range and lists the five candidate additions Pass 2 anchors on. See Informational Item #1 about the horizon's promoted-roadmap-hook wording. |
| `R/strategy-helpers.R:211-251` | `target_rebalance()` exists, validates ctx, rejects negative/leverage, builds a full zero target, returns `ledgr_target`. | Confirmed. Function spans 211-252; reads `ctx$equity` (216), validates universe (215), rejects negative weights (226-228), rejects levered weights (229-231), builds zero target (233), reads `ctx$close(id)` per instrument in loop (238-249), returns `ledgr_target` (251). Critically: **does NOT read `ctx$positions`**. The synthesis's Pass 1 narrowing is empirically correct. See Strong Observation below. |
| `R/strategy-helpers.R:76` | `signal_return()` exists. | Confirmed (spot-checked during seed v2 absorption). |
| `R/strategy-helpers.R:117` | `select_top_n()` exists. | Confirmed. |
| `R/strategy-helpers.R:163` | `weight_equal()` exists. | Confirmed. |
| `R/strategy-types.R:108, 143, 180, 216` | Value types exist. | Confirmed. |
| `NAMESPACE:117-145` | Exports for value types and verbs. | Confirmed. |

The 14 citations not directly re-verified in this final review were
verified at seed v2 absorption stage. Trust seed/response/synthesis
citation chain.

No phantom citations found.

## Synthesis-vs-v2 consistency check

For each open question:

| Question | v2 recommendation | Synthesis binding | Consistent? |
|---|---|---|---|
| Q1 naming policy | Preserve existing split (`ledgr_` value types, unprefixed verbs) | Same binding | ✓ |
| Q2 sizing-helper signature | Ctx-aware `target_dollar(weights, ctx, budget)` returning `ledgr_target` with empty-selection = zero target | Same binding | ✓ |
| Q3 NA policy | Stage-aligned (signal allows NA; selection ignores NA explicitly; weights/target reject non-finite) | Same binding | ✓ |
| Q4 scope | Pass 1 in v0.1.8.10, Pass 2 in v0.1.9 | Same binding, with Pass 1 narrowed to drop `ctx$vec$positions` because `target_rebalance` doesn't read positions | ✓ (with empirically-correct narrowing) |
| Q5 docs policy | Update existing surfaces in place | Same binding | ✓ |
| Q6 stays-pure | Verified by response F2 | Recorded as bound without relitigation | ✓ |

All six decisions consistent. No re-litigation of Q6. The Pass 1
narrowing is the only synthesis-stage refinement and is supported by
the code at `R/strategy-helpers.R:211-251`.

## Decision-resolution coverage check

Per `rfc_cycle.md` §"Open questions vs future obligations": the
synthesis populates both sections cleanly.

**Open questions promoted to spec-cut** (same-window, ticket-writer
resolves):

- Pass 1 fallback strategy for synthetic test contexts without `ctx$vec`
- File organization (`R/strategy-helpers.R` in place vs new
  `R/strategy-helpers-extensions.R` for Pass 2)
- Performance wording (Pass 1 docs should not claim material speedup
  until implementation measures it)
- v0.1.9 Pass 2 helper subset (within stage categories, anchored on
  horizon queue)

**Future obligations recorded** (separate RFC cycle):

- Long-short / hedged / levered helpers (gated on shorting/leverage
  contract semantics)
- Cost-aware sizing helpers (gated on public cost API)
- Declarative `ledgr_strategy()` constructor (v0.2.x or later)
- Compiled-strategy callback boundary (gated on `ledgrcore-spike`)
- Bulk feature-map vector helpers (gated on feature-engine RFC)

The split is correctly drawn. None of the future obligations are
items the v0.1.8.10 or v0.1.9 ticket writer could resolve; none of
the spec-cut items need a separate RFC. Matches the cost-API
precedent.

## Pass 1 parity gate check

The synthesis lists Pass 1 verification gates. Spot-checked the
load-bearing ones:

- **Existing helper pipeline tests pass unchanged.** Achievable
  because Pass 1 is contract-preserving — same inputs, same outputs,
  same error classes; only the internal `ctx` access pattern
  changes. Math is correct. ✓
- **Byte-identical or tolerance-identical run outputs before/after
  Pass 1.** Achievable because the underlying numeric reads
  (`bars_mat$close[, i]` per instrument) produce the same double
  values whether accessed via `ctx$close(id)` or
  `ctx$vec$close[idx]`. Math is correct. ✓
- **Scalar helper error classes remain unchanged for unknown feature
  ids and invalid prices.** Achievable because Pass 1 keeps the
  scalar code paths for error generation; only the bulk read path
  changes. Math is correct. ✓
- **No new public helper exports in v0.1.8.10 from this RFC.** True
  by Q4 binding. ✓

Pass 1 gate math is right.

## Strong Observation: synthesis Pass 1 narrowing is a real improvement

v2's implementation sketch said:

> 2. `R/strategy-helpers.R:211-251`: update `target_rebalance()` to
>    read from `ctx$vec$close` and `ctx$vec$positions` for the
>    universe-alignment step...

The synthesis's v2 absorption verification table caught this:

> v2 mentions `ctx$vec$positions` as part of Pass 1 helper
> optimization. Synthesis narrows Pass 1 to the vectors the current
> helpers actually read. `target_rebalance()` uses `ctx$universe`,
> `ctx$equity`, and scalar `ctx$close(id)` at `R/strategy-helpers.R:211-251`;
> it does not read positions today.

I verified this against the source: lines 211-252 read `ctx$equity`,
`ctx$universe` (via `ledgr_validate_strategy_helper_ctx`), and
`ctx$close(id)` (line 239 in the per-instrument loop) but DO NOT
read `ctx$positions` anywhere. The synthesis's narrowing is
empirically correct.

This is the kind of synthesis-stage refinement that justifies the
synthesis role being a different author from v2. A same-author v2-
to-synthesis collapse would have carried the `ctx$vec$positions`
misstatement forward into the binding artifact.

## Informational items (no patch required)

Two items worth recording for ticket cut. Neither warrants synthesis
or v2 patches.

### Informational Item #1: Horizon promotes target-construction extensions to "v0.1.8.9.x", synthesis binds to "v0.1.9"

`inst/design/horizon.md:1242-1243` says:

> Promoted roadmap hook:
> `v0.1.8.9.x Target Construction Helper Extensions`.

The synthesis binds Pass 2 to v0.1.9 (Q4). These are slightly
different roadmap windows: `v0.1.8.9.x` is a patch series of the
v0.1.8.9 release; `v0.1.9` is a minor release for ergonomics work.

The synthesis's choice is defensible because Pass 2 adds new public
helper exports plus contract/vignette/test updates — larger work
than a patch release typically holds. v0.1.9 as a dedicated
ergonomics release is the better promotion window.

But the horizon's promoted-roadmap-hook wording should be aligned
when the post-synthesis horizon entry is added (per `rfc_cycle.md`
§"Post-synthesis horizon entry pattern"). The post-synthesis
direction entry should update the 2026-05-25 horizon entry's
promotion hook to reference v0.1.9 instead of v0.1.8.9.x.

This is a horizon documentation hygiene item for the post-synthesis
entry, not a synthesis bug.

### Informational Item #2: Citation precision for the levered-weights check

The synthesis (and v2) cites `R/strategy-helpers.R:226-230` for the
negative/leverage rejection. The actual block is:

- Negative weights rejected at lines 226-228 (`if (any(as.numeric(weights) < 0))`).
- Levered weights rejected at lines 229-231 (`if (sum(abs(as.numeric(weights))) > 1 + sqrt(.Machine$double.eps))`).

So the full negative-and-leverage block spans 226-231, not 226-230.
The synthesis cites `:226-230` in the future-obligations section
about long-short/levered helpers; the cited range captures the
negative check completely but cuts off the second line of the
levered check.

Minor citation precision; not a synthesis bug. The future-obligation
text correctly states both negative AND levered rejection.
Ticket-cut and post-synthesis horizon work should use `:226-231` for
accuracy.

## Process compliance

- **Role rotation satisfied.** v1 Claude → response Codex → v2
  Claude → synthesis Codex → final review Claude. Same shape as the
  accessor cycle and as the cost-API cycle precedent in `rfc_cycle.md`
  §"Examples from completed cycles".
- **File-naming convention complies** with `rfc_cycle.md`.
- **No artifact edited in place** during contested phases.
- **No patches needed in this final review.** Per `rfc_cycle.md`
  §"Final review scope", patches go in-place when the review finds
  bugs. This review finds no bugs, two informational items only.

## Recommendation on next step

**Proceed to v0.1.8.10 ticket cut for Pass 1.** The synthesis is the
binding artifact. Pass 1 ticket cut should work from:

1. The synthesis as the load-bearing design document.
2. Seed v2 as the supporting context (revision-noted absorption of
   the response findings).
3. The accessor RFC's synthesis as binding substrate (`ctx$vec`,
   `ctx$idx()`, `ctx$vec$feature(feature_id)`).
4. Pass 1 spec-cut decisions: fallback strategy, file organization,
   performance wording.

**Defer Pass 2 to v0.1.9.** v0.1.9 ticket cut can use this synthesis
as the binding starting point for the public helper-extension packet:

1. Preserve unprefixed verb naming (Q1).
2. Use stage categories (Q4 stage model).
3. Bind stage-specific NA policy (Q3).
4. Extend existing docs in place (Q5).
5. Avoid long-short, levered, cost-aware, declarative-constructor,
   compiled-boundary helpers without a separate RFC (future
   obligations).

**Apply the two informational items as horizon-update tasks** when
the post-synthesis horizon entry is written:

- Update the 2026-05-25 horizon entry's promoted-roadmap-hook from
  `v0.1.8.9.x` to `v0.1.9` for consistency with this synthesis.
- Use `R/strategy-helpers.R:226-231` for the negative/levered
  rejection citation.

No maintainer escalation required.

No seed v3 required.

No response round v2 required.

## Process notes

- Final review took the synthesis at face value for 14 citations not
  directly re-verified in this stage; 7 citations were spot-checked
  directly. This is consistent with `rfc_cycle.md` §"Final review
  scope" — verification is spot-check, not exhaustive re-execution.
- The synthesis's Pass 1 narrowing (dropping `ctx$vec$positions`
  because `target_rebalance()` doesn't read positions today) is a
  real improvement over v2 and demonstrates why the synthesis author
  being a different person from the v2 author matters for catching
  load-bearing implementation details.
- The full RFC cycle ran the cost-API rotation pattern cleanly: v1
  Claude → response Codex (caught greenfield-framing error) → v2
  Claude (major reframe) → synthesis Codex (Pass 1 narrowing) →
  final review Claude (this artifact). The seed v1 → response → v2
  framing flip is the canonical example of the cycle's adversarial-
  review stage working as designed.
- Recommend recording this cycle alongside the accessor cycle as the
  next entries in `inst/design/rfc_cycle.md` revision history when
  the v0.1.8.10 closeout updates that file.

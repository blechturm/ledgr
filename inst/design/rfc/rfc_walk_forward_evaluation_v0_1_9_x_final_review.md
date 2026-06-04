# RFC Final Review: Walk-Forward Evaluation For ledgr

**Status:** Final review for the v0.1.9.x walk-forward synthesis. Verification, not new design space. Closure strengthened by Amendment 2 + Section 17 ticket-cut gates on 2026-06-04 (see Routing Summary below).
**Date:** 2026-06-04
**Cycle stage:** post-synthesis, pre-ticket-cut.
**Reviews:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
**Source seed v1:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed.md`
**Source seed v2:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_seed_v2.md`
**Reviewer response:** `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_response.md`

**Editorial note:** This file uses ASCII section notation ("Section N") and ASCII dashes ("--") rather than the typographic glyphs, to avoid encoding mojibake on downstream tooling. Where the reviewer's original text used Unicode section signs or em dashes, the equivalent ASCII is substituted here.

**Process note:** This artifact is the cycle's final-review stage per `inst/design/rfc_cycle.md`. Its findings route to a maintainer amendment of the synthesis (one correctness bug in bound text), bound constraints on open spec-cut questions (two validity gates), and Section 10 / Section 12 augmentations (one disclosure obligation, two test items, one compute-scaling caveat). It does not open a new RFC chain; the architecture, deferrals, scope, and wrapper-not-engine choice are accepted as the synthesis bound them.

**Closure update (2026-06-04):** A post-Amendment-1 review by Claude (online) observed that four of the seven routings in Amendment 1 were procedural ("must justify", "must address", "visually unavoidable") rather than substantive defaults, and that no ticket-cut enforcement mechanism gated the amendment's obligations. A subsequent Codex review proposed substantive replacements for those four findings and a ticket-cut gate matrix. The maintainer accepted both and bound them as Amendment 2 (synthesis Section 16) and Section 17 ticket-cut gates. The "cycle is complete on the v0.1.9.x walk-forward design direction" closing sentence below is retained as the original final-review judgment, but is qualified: the cycle's *design direction* is accepted; *ticket-cut enforcement* is gated by Section 17. This distinction is now codified as the precedent in `inst/design/rfc_cycle.md`.

---

## Review

I read all four documents -- the v1 seed, the Codex response, the v2 revision, and the binding synthesis. The process itself is sound: the adversarial-response stage caught the things most likely to rot a spec (windowing scope creep, the scalar-matrix overclaim, excluding the nondeterministic `sweep_id` from identity, pulling `opening_state_policy` into `session_id`). So I'll skip what's already handled and push on what survived the review.

**1. The train-fold scoring binding contradicts your own fold definitions -- and I'd stop the ticket-cut on it.**

Both Section 7.8 and the synthesis bind:

```
train fold:
  scoring_start = previous train scoring_end, or snapshot_start for first fold
  scoring_end   = train_window_end
  execution_start = scoring_start
```

For a *rolling* scheme, `ledgr_folds_rolling(train_window = "1 year", step = "3 months")` defines a fixed-width train window where `train_start = train_end - train_window`. But this binding scores from the *previous* fold's train end forward -- i.e., the 3-month increment, not the 1-year window. So the sweep would rank 50 candidates on the incremental slice while the stored `train_start_utc`/`train_end_utc` describe the full window. That's incoherent for selection: you can't fairly argmax candidates over a window you're not scoring. It's also wrong for *anchored* -- there `scoring_start` should always be `snapshot_start`, never the previous train end. The only scheme this binding describes is non-overlapping incremental train scoring, which is neither of your two v1 schemes.

It also breaks your own parity gate: "fold train sweep == direct windowed `ledgr_sweep()`" with identical window -- but the binding scores a different window than the fold stores. Either this is a genuine error, or the wording is conflating a stitched-train-equity view with the sweep scoring range. Either way it needs an explicit fix: `scoring_start = train_start_utc`, score the full fold window, accept overlap across folds, and if you want a non-overlapping aggregate train view, derive that separately rather than redefining the scoring range.

**2. The v1 evidence can be fully deterministic and still be biased -- opening-state and metric comparability decide whether the score matrix means anything.**

You've correctly made `opening_state_policy` part of identity, but you deferred *which* policy to spec-cut while binding everything downstream of it. That's the wrong thing to defer last, because the policy determines whether the OOS metric is meaningful. If test folds start flat, every fold eats a cold-start entry cost and a rebalancing transient that a continuous backtest never sees; across 20 folds that's a systematic, repeated distortion of exactly the OOS Sharpe you're selecting and reporting on. quantstrat's `walk.forward()` carries the account across test slices precisely to avoid this. Your parity test proves the windowing is consistent; it does *not* prove the OOS evidence is unbiased -- those are different claims, and the synthesis treats parity as if it settles validity.

Relatedly: train windows (1yr) and test windows (3mo) differ in length, so any *level* metric (total return, drawdown, trade count) is not comparable train-to-test, and your proposed default report (train-vs-test scatter) will read as "degradation" that's partly just the unit mismatch. Even rate metrics like Sharpe have a length problem -- a 3-month test Sharpe is a very noisy estimate, so the scatter shows estimation noise dressed up as overfitting. I'd bind now that selection metrics must be rate/annualized, and put a health-warning on short test windows.

**3. The default surfaces make the weakly-justified path the easy one -- which is the exact failure mode the RFC exists to prevent.**

Section 1.4 cites the multiplicity literature, then v1 ships `argmax(train metric)` as the only selection rule and `extract_candidate(fold_seq = "latest")` as the promotion default. Argmax-on-a-single-train-metric is the most overfitting-exposed selection you can do, and "latest" promotes one fold's argmax. The honesty thesis is "don't make the dishonest pattern teachable in default workflows" -- but the default vignette will teach `argmax("sharpe")` -> per-fold OOS curve -> "validated." I'd either make the train-to-test degradation visually unavoidable in the default print method (this is open Q10, so resolve it in that direction), or drop the `"latest"` default and force an explicit `fold_seq` + rationale, consistent with how you treat promotion notes elsewhere.

**4. Bind the survivorship caveat as a v1 doc obligation, not just a future RFC.**

Single-snapshot + fixed universe over multiple years is the precise setup where survivorship bias bites hardest, and it's structurally invisible. Deferring the *fix* is fine; deferring the *disclosure* isn't. One bound sentence in the vignette -- "walk-forward OOS honesty is conditional on point-in-time-correct universe construction, which v1 does not provide" -- costs nothing and stops users over-trusting multi-year results. Right now it's only recorded as a future obligation.

**5. Two missing tests, and a scaling caveat for your edge-hardware target.**

The parity tests cover windowing equivalence. Add (a) a feature-windowing determinism test -- feature value at bar *t* must be identical whether the run starts at `hydration_start` or `snapshot_start` -- and (b) a train-score cross-fold stability test: two fold definitions with the same train window must yield identical train scores. Those guard the no-leakage and identity-stability claims that parity alone doesn't.

On compute: "1000 train runs" undercounts. With rolling overlap (75% at train=1yr/step=3mo) you re-backtest the same (candidate, bar) pairs ~4x across folds, and for anchored the train window grows each fold, making total cost super-linear in fold index. Because the snapshot is sealed and deterministic, this is exactly where per-(candidate, bar) memoization would pay -- but "just call `ledgr_sweep()` per fold" forecloses it. Defensible for v1 simplicity; worth stating explicitly as a known trade-off given the no-cloud deployment vision, so it's a conscious choice rather than a surprise at scale.

Net: the architecture and deferrals are right, and the review process worked. The exposure left is that v1 can produce reproducible-but-misleading evidence -- finding #1 is a correctness bug, #2 and #3 are the gap between "deterministic" and "honest." I'd fix #1 before ticket-cut and bind #2's metric/opening-state constraints into the parity-and-validity gate rather than spec-cut.

---

## Routing Summary

The findings above route through Amendment 1 to the synthesis (see `rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` Section 14 for binding text).

| Finding | Mechanism | Synthesis section affected |
| --- | --- | --- |
| #1 train-fold scoring binding (correctness bug in bound text) | Maintainer amendment -- bound text correction | Section 3 Hydration, Scoring, Execution, Opening |
| #2 opening_state policy + metric comparability (validity gates) | Bound constraints on spec-cut Open Questions | Section 11 Q1, Q5 |
| #3 default selection rule + extract_candidate default (validity gates) | Bound constraints on spec-cut Open Questions | Section 11 Q7, Q10 |
| #4 survivorship disclosure obligation | Section 10 Minimum Scope augmentation | Section 10 item 13 (vignette) |
| #5a feature-windowing determinism test | Section 10 Minimum Scope augmentation | Section 10 item 11 (tests) |
| #5b cross-fold train-score stability test | Section 10 Minimum Scope augmentation | Section 10 item 11 (tests) |
| #5c compute scaling caveat | Section 12 Future Obligations augmentation | Section 12 |

No finding required re-deliberation of architecture, deferrals, scope boundaries, or the wrapper-not-engine choice. The cycle is complete on the v0.1.9.x walk-forward design direction.

---

## Closure Update -- Amendment 2 and Section 17 (2026-06-04)

The routing table above remained accurate but was insufficient as a closure mechanism. After Amendment 1 landed, a Claude (online) review observed that:

1. Findings #2 and #3 were bound as procedural constraints on Section 11 open questions ("must address", "must make visually unavoidable") rather than as substantive defaults. A spec-cut writer could satisfy each constraint with a justification paragraph and ship the very default the original finding warned against.
2. Finding #1 was correctly bound as text correction but lacked a written trace verifying the original v2 binding's incoherence; later readers would need to re-derive the bug themselves.
3. No ticket-cut enforcement mechanism gated any Amendment 1 obligation. The synthesis bound text but did not bind the spec-cut packet's acceptance criteria.

A Codex review of that critique proposed:

- A substantive `carry_test_state` v1 default for Q1 with `flat_test_state` permitted only as a warned opt-in;
- Fail-closed selection-rule behavior for Q5 with a metric-classification field on the metric registry;
- Unconditional no-default extraction for Q7 with a `selection_rationale` arg and a `ledgr_walk_forward_latest_without_rationale` condition class;
- An operational data contract for Q10's default print (per-fold degradation table with named fields, scale contract, render-order contract);
- A ticket-cut gate matrix with packet-open and release-gate enforcement points.

The maintainer accepted all five and bound them as synthesis Section 16 (Amendment 2) and Section 17 (ticket-cut gates). Amendment 2 also adds Section 16.1 (worked trace verification of the Section 14.1 train-fold scoring correction) and Section 16.6 (path-dependency obligation for `carry_test_state`).

Amendment 1 Sections 14.1, 14.4, and 14.5 stand unchanged. Amendment 1 Sections 14.2 and 14.3 are superseded in part by Amendment 2 Sections 16.2 through 16.5.

The closure is now: **design direction accepted (Amendment 1 Section 14 + Amendment 2 Section 16); ticket-cut gated by Section 17**. The cycle proceeds to the v0.1.9.x walk-forward ticket packet, subject to Section 17 gate matrix enforcement at packet-open and release-gate review.

This closure update is recorded as the precedent for post-amendment review findings in `inst/design/rfc_cycle.md`. The pattern: an amendment that routes findings to procedural constraints alone is insufficient; either the amendment binds substantive defaults / operational contracts, or it names a ticket-cut gate matrix, or both.

# v0.1.9.4 Vignette Screening Audit

**Date:** 2026-06-11
**Reviewer:** Claude (full read of all twelve installed vignettes, ~6,400
lines, against `inst/design/vignette_styleguide.md`, the v0.1.8.5 / v0.1.8.11
teachability precedents, and the planned v0.1.9.5 workstreams).
**Trigger:** Maintainer request during v0.1.9.5 pre-planning: identify
vignettes that should split into a concept-teaching article plus a
technical-details article, list missing vignettes, and assess the teaching
surface against the R for Data Science (R4DS) north star.
**Consumers:** the v0.1.9.4 release gate (Batch 9 / LDG-2626) for the stale
items in Section 2, and the v0.1.9.5 spec packet for everything else.

**Disposition:** No item blocks the v0.1.9.4 release gate except the three
stale-reference fixes in Section 2, which are exactly the release-gate checks
`vignette_styleguide.md` Section 12 already requires. All structural work
(splits, new articles, nav regrouping) is v0.1.9.5 scope and must sequence
AFTER the API-naming-consistency RFC renames land (see
`../rfc/rfc_api_naming_consistency_v0_1_9_5_seed.md`) so new articles teach
the final vocabulary exactly once.

---

## 1. Screening verdicts

| Vignette | Lines | Job clarity | Styleguide fit | Verdict |
| --- | --- | --- | --- | --- |
| strategy-development | 961 | strong | high | Split A: two jobs in one article |
| indicators | 843 | strong | high | Split B: concept + TTR adapter depth |
| metrics-and-accounting | 821 | strong | high | Split C: accounting model + metric-context machinery |
| sweeps | 718 | strong | high | Split E (borderline): workflow + artifact/retention depth |
| research-workflow | 671 | excellent | high | Keep whole; stale fixes (Section 2) |
| experiment-store | 585 | diluted | high | Split D: data input vs store inspection |
| reproducibility | 449 | excellent | high | Keep |
| custom-indicators | 364 | excellent | high | Keep |
| execution-semantics | 302 | good | high | Keep; one actively wrong callout (Section 2) |
| leakage | 277 | excellent | highest | Keep; the model article |
| research-to-production | 261 | good | high | Keep; stale roadmap section (Section 2) |
| walk-forward | 106 | thin by design | n/a | Expand to executable (Workstream C) |

Overall quality is high: the styleguide is followed, voice is consistent,
examples execute, exercises are concrete, cross-links are intentional. The
finding is not quality. It is that the four largest articles each carry two
jobs - a concept arc and a technical-details payload - and the payload
dilutes the arc.

---

## 2. Stale items (v0.1.9.4 release-gate severity, NOT v0.1.9.5)

These are the checks `vignette_styleguide.md` Section 12 ("Release-Gate
Roadmap Sections") already requires at every release gate. The Batch 9 gate
has not run yet; these are its findings in advance.

1. **execution-semantics.qmd lines 158-164 - actively wrong, not just
   stale.** A `ledgr-callout-important` says "The stable public
   transaction-cost model API is planned for v0.1.9.x / v0.2.0 ... Do not
   treat this list interface as the stable public cost API" directly above a
   chunk that uses the shipped v0.1.9.1 public API (`ledgr_cost_chain()`,
   `ledgr_cost_spread_bps()`, `ledgr_cost_fixed_fee()`). Delete or rewrite
   the callout to describe the shipped API boundary.
2. **research-to-production.qmd line ~245.** "v0.1.9.4 plans walk-forward
   evaluation" - shipped. Update the delivered/planned section against the
   v0.1.9.4 closeout. The same section's "later v0.1.9.x work may add ..."
   list should be re-checked against the post-arc roadmap (v0.1.9.5 docs
   release now precedes those items).
3. **research-workflow.qmd line ~656 and sweeps.qmd lines ~620-621.**
   "the public roadmap places walk-forward evaluation at v0.1.9.x" /
   "use walk-forward evaluation when that layer lands in v0.1.9.x" - both
   should now point at `vignette("walk-forward", package = "ledgr")`.

---

## 3. Split recommendations (concept / technical-details pairs)

The maintainer hypothesis - several vignettes should split into a vignette
that teaches the general concept and another that carries the important
technical details within that concept - is confirmed for four articles,
borderline for a fifth.

### Split A: strategy-development

- **"Strategy Basics" (concept):** the policy mental model, `ctx`, leakage
  wrong/right, `flat()`/`hold()`, first trading rule, `params`, run one
  backtest, when-ledgr-complains. Roughly the current teaching arc through
  line ~615.
- **"Strategy Authoring Tools" (technical):** the signal -> select -> weight
  -> target helper pipeline, feature maps, the troubleshoot-helper-pipelines
  tables, preflight tier detail, debug checklists.

### Split B: indicators

- **"Indicators And Features" (concept):** feature lifecycle, IDs vs aliases
  vs fingerprints, pulse inspection, warmup, accessing features in a
  strategy, contract checks. Roughly current lines 59-500.
- **"TTR And Adapter Indicators" (technical):** the entire TTR section -
  single/multi-output, bundle naming and prefix-collision rules, MACD
  argument consistency, warmup-rule verification, `requires_bars` overrides.
  ~300 lines of real detail that currently buries the concept arc. Pairs
  naturally with the existing custom-indicators article (custom = write your
  own; TTR = adapt a package).

### Split C: metrics-and-accounting

- **"The Accounting Model" (concept):** the evidence-hierarchy diagram, the
  tiny hand-checkable run, ledger/fills/trades/equity, recompute-the-metrics,
  zero-trades-can-be-correct, open positions.
- **"Metric Contexts And Conventions" (technical):** context templates,
  stored-context vs sensitivity overrides, comparison/sweep/promotion context
  propagation, the risk-metric contract, annualization snapping,
  compiled-accounting fail-closed classes, the zero-trade diagnostic
  checklist.

### Split D: experiment-store

- **"Data Input And Snapshots" (concept):** `from_df`/`from_csv`/
  `from_yahoo`, snapshot lifecycle and anti-patterns, seal verification, the
  Yahoo boundary, backup conventions. Note: the v0.1.8.5 reading flow in
  `vignette_styleguide.md` Section 12 names "Data Input / Snapshot Creation"
  as its own article - it was never created. This split retroactively fills
  that named gap.
- **"Experiment Store" (refocused):** runs, labels/tags/archive, compare,
  reopen, stored-source extraction, the task intent map.

### Split E (borderline, lowest priority): sweeps

- Keep the exploration workflow (grids, active aliases, inspect, promote);
  move retention, save/reopen, three-evidence-tiers, PerformanceAnalytics
  interop, `spot_fifo` opt-in, and parallel dispatch into **"Sweep Artifacts
  And Retention" (technical)**. Ranked last because sweeps.qmd holds together
  better than the other three; deferring this split is defensible.

### Explicitly not split

research-workflow (its job IS the end-to-end arc), leakage, reproducibility,
custom-indicators, execution-semantics, research-to-production. All
single-job and right-sized.

---

## 4. Missing vignettes (priority order)

1. **Risk and cost execution policy** (already planned as Workstream C
   "risk-and-cost"; this audit confirms its priority). The largest genuine
   hole: v0.1.9.3 shipped target-risk with no vignette home at all. Cost
   teaching is scattered across three articles; risk chains appear only in
   callout asides. One article teaching the layer order - validated targets
   -> risk chain -> timing -> cost -> fill - with the half-spread
   convention, chain ordering, and identity hashes.
2. **Walk-forward research arc** (already planned, Workstream C). Expand the
   106-line design-only stub into the headline executable article: folds,
   selection rules, the degradation table as the primary read, extraction
   with rationale, promotion. Also resolves the standing `eval: false`
   tension with the vignettes-must-execute stance.
3. **Quickstart / "the whole game"** (new proposal). R4DS opens with a
   complete miniature analysis before any tool chapters. research-workflow
   plays this role today at 671 lines - a chapter, not an on-ramp. Propose a
   ~150-line "ledgr in ten minutes": demo data -> snapshot -> one run ->
   glance at a sweep -> pointer to research-workflow.
4. **Data Input And Snapshots** - delivered by Split D; closes the gap the
   v0.1.8.5 reading flow already named.
5. **TTR And Adapter Indicators** - delivered by Split B.
6. **Debugging a ledgr run** (optional / stretch; can defer to v0.1.9.6).
   Troubleshooting content currently lives in three places
   (strategy-development tables, indicators warmup section, metrics
   zero-trade checklist) with partial duplication. One consolidated
   diagnostic article with the symptom -> likely cause -> first check
   framing lets the concept articles shed their troubleshooting weight.

---

## 5. Other documentation items for the v0.1.9.5 packet

Beyond the already-planned Workstreams D (maintainer manual), E (identity
contract v2), F (performance/decisions narrative), and G (release surfaces):

- **Sequencing with the API-naming RFC.** The rename batch from
  `../rfc/rfc_api_naming_consistency_v0_1_9_5_seed.md` must land BEFORE the
  vignette batches so every new and split article teaches the final
  vocabulary once. The v0.1.9.5 packet should bind this ordering.
- **pkgdown nav regrouping.** After the splits, the "Core Workflow" group
  grows from 8 to ~12 articles. Add a third group (e.g. "Going Deeper") so
  the two-tier concept/technical structure is visible in the nav, not only
  in cross-links.
- **Reading-flow update** in `vignette_styleguide.md` Section 12 - the
  current flow predates walk-forward, target-risk, and the splits.
- **Doc-contract test updates** - splits move locked strings between files;
  mechanical, but must be named in the ticket.
- **who-ledgr-is-for / why-r refresh** against the post-v0.1.9.x surface
  (walk-forward and the peer benchmark change the positioning story).
- **Demo-data span check.** Confirm `ledgr_demo_bars` has enough span for an
  executable multi-fold walk-forward example. The 2019-H1 window used across
  articles gives ~125 daily bars; a two-fold rolling example needs either a
  longer window from the demo data or deliberately compact fold sizes.

---

## 6. R4DS north-star assessment

Conclusion: the teaching surface can match R4DS, and is closer than the
backlog suggests, because `vignette_styleguide.md` already encoded the
load-bearing R4DS principles.

Already matched: outcome-first openings ("You have an idea for a trading
rule..." is textbook R4DS), second-person workflow voice, one shared teaching
dataset (`ledgr_demo_bars` is the `flights` equivalent), runnable chunks with
real rendered output, concrete exercises placed at tradeoff-revealing
moments, disciplined cross-linking instead of repetition. leakage.qmd is
R4DS-grade or better: it teaches a subtle statistical trap with a concrete
numerical demonstration (the quantile-gap example) rather than an admonition;
the tidyverse corpus has no equivalent of that article.

Gaps and how they close:

1. **The "whole game" opening.** R4DS shows a complete miniature analysis
   before any tool chapters. The quickstart (Section 4 item 3) closes this.
2. **The two-tier structure.** R4DS's deepest structural idea is whole-game
   -> tools -> deeper topics. The split plan creates precisely this: concept
   articles are the tools tier, technical-details articles are the deeper
   tier. This is the strongest argument for the splits - they are the R4DS
   architecture, not just length management.
3. **Continuous narrative arc.** R4DS is a book; pkgdown articles are
   discrete. The navbar grouping plus consistent "Where Next" trails
   substitute adequately; the three-group nav makes the arc visible.
4. **Gentleness gradient.** R4DS assumes near-zero R knowledge; ledgr
   articles assume a competent R user new to ledgr. That is the correct
   calibration for the audience. Matching the north star means matching its
   craft, not its starting line - do not dilute technical precision chasing
   imagined beginners.

The operative test from R4DS worth holding every article to: each article
answers "what will I be able to DO" before "what is this CALLED." The best
current articles (research-workflow, leakage, the first half of
strategy-development) already pass. The split work is mostly about letting
the second halves of the big four stop diluting that property.

---

## 7. Suggested v0.1.9.5 consumption order

1. Batch 9 release gate consumes Section 2 (stale fixes) - before tag.
2. Naming RFC cycle completes; rename batch lands first in v0.1.9.5.
3. Splits A-D plus the two planned Workstream C articles (risk-and-cost,
   walk-forward) as the core vignette batches.
4. Quickstart article.
5. Nav regrouping + reading-flow + styleguide updates as the closing
   structure batch.
6. Split E and the debugging article as cut-line candidates if the packet
   runs long.

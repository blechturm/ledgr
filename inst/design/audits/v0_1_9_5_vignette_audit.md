# v0.1.9.5 Vignette Audit

**Date:** 2026-06-13
**Reviewer:** Claude, via a five-way parallel sub-agent audit of all twenty
installed vignette/article sources against `inst/design/vignette_styleguide.md`,
followed by maintainer-side verification of the load-bearing factual claims
(DESCRIPTION imports, trades-table schema, dependency lists, cross-link paths).
**Trigger:** Maintainer request to audit the full vignette surface after the
v0.1.9.5 split/rename/teaching work, covering: styleguide compliance, stale or
wrong content, the R for Data Science (R4DS) north star, length, UX gaps, and
other improvements.
**Scope:** All twenty sources under `vignettes/` and `vignettes/articles/`.
**Consumers:** the v0.1.9.5 spec packet. Per maintainer direction (2026-06-13),
the stale-fact fixes AND the highest-value missing helpers are pulled INTO
v0.1.9.5 rather than deferred; this audit is the scoping input for that rescope.

**Disposition summary:** No item is release-blocking in the correctness sense.
The four confirmed stale facts (Section 2) are wrong today and should be fixed.
The two highest-value UX helpers (Section 3: `ledgr_sweep_review()`,
`ledgr_temp_store()`) each retire duplicated boilerplate across multiple
articles and are pulled into this release. The callout-overuse and weak-opening
cleanups (Section 1) are mechanical editorial work.

**Review:** Codex reviewed this audit (2026-06-13) and confirmed the Section 2
stale facts, the trades-schema and dependency findings, and the
`ledgr_sweep_review()` choice. Corrections applied from that review: the
`who-ledgr-is-for` relative-link item was downgraded (resolves under pkgdown
flattening; not stale), the Section 1.1 callout counts were corrected, and
narrow scope boundaries were added to both proposed helpers.

---

## 1. Cross-cutting styleguide findings

These patterns recur across many articles and are the bulk of the editorial
work.

### 1.1 [High] Callout overuse -- "Definition" boxes as a glossary

Styleguide Section 4 reserves `ledgr-callout` divs for scan-critical guidance
and warns that "too many callouts flatten visual hierarchy"; Section 13 lists
"callouts used as decoration" as an anti-pattern. Several articles use
`ledgr-callout-note` "Definition" boxes as an inline glossary:

- `indicators.qmd`: five Definition callouts of six total (worst offender).
- `sweeps.qmd`: nine callouts, four of them Definition boxes.
- `strategy-development.qmd`: three Definition callouts of five total (one
  immediately restated in plain prose).
- `metrics-and-accounting.qmd`: three Definition callouts of five total
  (ledger event / fill / trade / equity).
- `custom-indicators.qmd`: one decorative Definition callout.

(Counts verified 2026-06-13; earlier draft overstated the Definition counts.)

Fix: convert most Definition callouts to inline bold-term prose; reserve
callouts for the genuinely scan-critical warnings (validation/selection-bias,
runnability, roadmap boundaries) that are currently drowned out.

### 1.2 [High] Version-stamping current behavior (Section 3)

Section 3 forbids stamping current behavior with a version ("in vX, ledgr
does..."); describe shipped behavior as current and anchor only genuine future
work to a named release.

- `execution-semantics.qmd:159`: "v0.1.9.1 ships the public transaction-cost
  model API" (also mistyped as an `important` callout for ordinary current
  behavior).
- `sweeps.qmd`: "v0.1.9.2 store" (L483), "the v0.1.8.6 cycle documented" (L622,
  internal cycle archaeology), "not part of the v1 cost surface" (L685).
- `research-to-production.qmd:196`: "In v0.1.9.1, ledgr makes timing and
  transaction costs explicit..." (delivered behavior stamped to a release).
- `research-workflow.qmd:515`: "carried forward from the v0.1.8.6 cycle".
- `metric-contexts-and-conventions.qmd:109`: "now live in a `metric_context`"
  (minor "now" framing).
- `experiment-store.qmd:430`: "kept out of v0.1.8.5" -- see Section 2 (this one
  is also flatly stale).

### 1.3 [High] Missing "Where Next" closing (Section 11)

- `custom-indicators.qmd`: no closing section at all (ends at "What To
  Remember").
- `leakage.qmd`: no closing section (ends at "What To Remember"); also only one
  cross-link, in raw `.html` form rather than `vignette()` form.
- `research-to-production.qmd`: no closing; the arc article dead-ends with no
  exit path.
- `experiment-store.qmd`: has a closing but mis-headed "What's Next?" with only
  two links.

### 1.4 [Medium] Topic-list openings instead of a user outcome (Sections 1/2)

Openings that lead with a scope/function list rather than a named user outcome:
`strategy-authoring-tools.qmd` (the Section 1 "Weak" example almost verbatim),
`indicators.qmd` (opens with a Definition callout before any motivation),
`metric-contexts-and-conventions.qmd` (a table-of-contents-in-prose),
`sweeps.qmd` (definition + vocabulary in line 2). Exemplary openings to imitate:
`research-workflow.qmd` (the styleguide's own Section 1 "Good" example),
`walk-forward.qmd`, `risk-and-cost.qmd`, `reproducibility.qmd`, `leakage.qmd`.

### 1.5 [Medium] Duplication across the two strategy articles (Section 13)

`strategy-development.qmd` and `strategy-authoring-tools.qmd` share a
near-verbatim boilerplate opening (the "three steps" list, the
"sequence of decision moments" paragraph, the `spot_fifo` accelerator
paragraph, the leakage paragraph) AND both rebuild the same snapshot from
scratch (same `snapshot_id = "strategy_chapter_snapshot"`). One canonical home
plus a cross-link; the shared three-step list also mis-scopes "Strategy Basics"
by promising the companion article's helper-pipeline content.

### 1.6 [Medium] Wrong canonical cross-link for snapshots (Section 9)

Both strategy articles point readers at `vignette("experiment-store")` for
sealed-snapshot familiarity; Section 9 names `data-input-and-snapshots` as the
canonical home for "snapshot creation and sealed-data boundaries".

### 1.7 [Medium] `eval: false` chunks that hide the lesson (Sections 5/6)

Most `eval: false` chunks are justified (artifact-writing, external/network
data, labeled fragments, intentional anti-examples). These are NOT:

- `metric-contexts-and-conventions.qmd` `metric-context-provenance` (L191-200):
  `bt` is in scope and runnable; this hides the one chunk that renders context
  provenance values -- the article's core deliverable. (High)
- `strategy-authoring-tools.qmd` `helper-debug-checklist` (L514): runnable
  diagnostic code (`snapshot` is open), marked non-executing.
- `custom-indicators.qmd` `adapter-r` (L232): `ledgr_adapter_r(stats::median)`
  has no external dependency and could show the constructed object.
- `ttr-and-adapter-indicators.qmd` `ttr-pulse-snapshot` (L336): references a
  `snapshot` object that does not exist in scope -- an orphan that would error
  if run (papering over missing setup rather than a legitimate exemption).

### 1.8 [Low] `ttr-and-adapter-indicators.qmd` qualified calls (Section 5)

The `demo-bars` chunk (L75-81) uses `dplyr::filter`/`dplyr::between` despite
`library(dplyr)` being attached -- the explicit Section 5/13 anti-pattern. The
other articles use unqualified verbs.

---

## 2. Confirmed stale / wrong facts (verified)

Each verified against the codebase, not just reported.

1. **[High] `why-r.qmd:78` -- wrong dependency.** The Imports list reads
   "codetools, collapse, DBI, digest, duckdb, jsonlite, rlang, tibble".
   `DESCRIPTION` imports `yyjsonr (>= 0.1.22)`, not `jsonlite` (the canonical
   JSON switch landed in v0.1.8.9). The full list should be reconciled against
   `DESCRIPTION`. An inaccurate dependency list directly undercuts this
   article's own "lean footprint" argument.

2. **[High] `research-to-production.qmd` -- the release-gate roadmap article is
   stale.** The "What v0.1.x Delivers Today" list omits shipped capabilities:
   sweep artifact persistence / retained return series (v0.1.9.2) and the public
   target-risk API with risk identity (`ledgr_risk_chain()`, `risk_chain_hash`;
   v0.1.9.3). The validation toolkit is described as "next planned... may add"
   with no anchor -- the roadmap binds it to v0.1.9.6. The paper/live/
   observability ranges are imprecise (paper = v0.3.0, observability = v0.4.0,
   live = v1.0.0). Per styleguide Section 12 this article must be reconciled
   against `ledgr_roadmap.md` and `NEWS.md` at every release gate.

3. **[High] `execution-semantics.qmd:279` -- nonexistent trades columns.** The
   trades example selects
   `any_of(c("entry_ts_utc","exit_ts_utc","entry_ts","exit_ts","qty","pnl",
   "realized_pnl"))`. `ledgr_closed_trade_rows()` returns close-action fill rows
   whose columns are `event_seq`, `ts_utc`, `instrument_id`, `side`, `qty`,
   `price`, `fee`, `realized_pnl`, `action`. Five of the seven listed names
   (`entry_ts_utc`, `exit_ts_utc`, `entry_ts`, `exit_ts`, `pnl`) do not exist;
   `any_of()` silently drops them. This both teaches wrong column names and
   masks a real product observation (the trades table carries no paired
   entry/exit timestamps -- a "trade" is a single close-fill row). See Section
   3.3.

4. **[Medium] `experiment-store.qmd:430` -- past-release boundary.** "The public
   roadmap keeps that work out of v0.1.8.5" stamps a past release as the scope
   boundary; the current release is v0.1.9.5. Should name the actual planned
   cycle with no current-version anchor.

5. **[Checked -- NOT stale] `who-ledgr-is-for.qmd:158-159` relative links.** The
   "Reading on" links to `research-workflow` and `research-to-production` use
   `../articles/`. pkgdown flattens all articles into a single `articles/`
   output directory, so `../articles/research-workflow.html` from
   `articles/who-ledgr-is-for.html` resolves to `articles/research-workflow.html`
   correctly. This is not a stale fact and is not pulled into the fixes; recorded
   here so it is not re-flagged. (Downgraded from the draft on Codex review,
   2026-06-13.)

---

## 3. UX gaps and proposed helpers

The recurring "clutter signals a missing helper/default/constructor" pattern
(styleguide Section 5). This is the highest-value section: each item is a real
API affordance whose absence forces boilerplate into the articles. Ordered by
value.

### 3.1 [High] `ledgr_sweep_review()` -- missing sweep-inspection helper

An identical ~15-line rank / `select` / `glimpse` / issues block is hand-
maintained in BOTH `sweeps.qmd` (L555-589) and `research-workflow.qmd`
(L395-417), and BOTH already carry an in-article design note admitting "a future
sweep-review helper may package this review shape." One helper retires
duplicated boilerplate in two articles and resolves two standing design notes.
This is the single highest-value fix.

Scope boundary (required for the additive/identity-neutral claim to hold): the
helper RETURNS review tables only -- rank, top-N, and issue/flag columns. It
must NOT choose or promote a winner; selection and promotion stay with
`ledgr_candidate()` / `ledgr_promote()`.

### 3.2 [High] `ledgr_temp_store()` -- disposable-store helper

`db_path <- tempfile(fileext = ".duckdb"); if (file.exists(db_path)) unlink(...)`
boilerplate repeats in `data-input-and-snapshots.qmd` and `experiment-store.qmd`;
`reproducibility.qmd` inconsistently omits `db_path` entirely. A small
disposable-store convenience removes the repeated dance and standardizes the
demo idiom across articles. Reconcile the "no `db_path`" idiom while doing this.

Scope boundary (keep it narrow): the helper RETURNS a disposable `.duckdb` path
and removes any stale file already at that path -- nothing more. It must NOT
initialize, open, seal, or manage an experiment store, or it drifts into
store-lifecycle API.

### 3.3 [Medium] Trades table has no paired entry/exit timestamps

A "trade" is a close-action fill row with a single `ts_utc`; there is no
entry/exit pairing. This is why `execution-semantics.qmd` guessed four
nonexistent timestamp columns (Section 2.3). Decide between documenting the
real shape clearly or adding an entry/exit-paired trades view. At minimum, fix
the vignette to use the real columns.

### 3.4 [Low] `ledgr_target` value accessor

`strategy-authoring-tools.qmd:269` uses `unclass(target)[["DEMO_01"]]` to read
one quantity out of a `ledgr_target`. A `[[`/accessor method would remove the
`unclass()` reach-in.

### 3.5 [Low] Annualization accessor

`metrics-and-accounting.qmd` hardcodes `bars_per_year <- 252` in its hand-
recompute, and the prose then admits ledgr auto-detects and may disagree on
non-daily data. A `ledgr_annualization(bt)` accessor surfaced in the chunk would
let the recompute provably match `ledgr_compute_metrics()` and remove the
caveat.

### 3.6 [Low] Vectorized feature-read / "set targets where condition"

The `for (id in ctx$universe) { if (is.finite(ctx$feature(id, ...))) targets[id]
<- ... }` loop is rewritten across `custom-indicators.qmd`,
`strategy-development.qmd`, and others. The articles flag it as a taught
progression, but a `ctx`-level vectorized feature-read or set-where helper would
shorten every example. Lower priority; the loop is also pedagogically useful.

(Precedent: the walk-forward degradation curated-print and fold-list print
helpers shipped in v0.1.9.5 are exactly this pattern resolved.)

---

## 4. Per-vignette quick reference

Severity tags mark the top issue per article. "OK" = strong, no significant
finding.

- **quickstart** -- OK. Low: repeated `arrange(desc(sharpe_ratio))` (use one
  intermediate); "Where Next" is prose not a bulleted list.
- **strategy-development ("Strategy Basics")** -- Med: shared boilerplate
  opening + three Definition callouts; slightly over-scoped (carries the helper
  pipeline). Weak inverted-pyramid opening.
- **strategy-authoring-tools** -- High: topic-list opening; duplicated opening +
  snapshot setup; unjustified `eval:false` debug chunk; `unclass(target)` UX
  gap.
- **indicators** -- High: five Definition callouts; opens with a callout before
  motivation. Good lifecycle diagram and exercise.
- **ttr-and-adapter-indicators** -- Med: `dplyr::` qualified calls; orphan
  `ttr-pulse-snapshot` chunk; no exercise; MACD arg-block repetition (use
  `ledgr_ind_ttr_outputs()`).
- **custom-indicators** -- High: no "Where Next"; decorative Definition callout;
  `adapter-r` should execute; `for`/`is.finite` strategy-loop UX gap.
- **execution-semantics** -- High: trades-schema `any_of()` (Section 2.3);
  "v0.1.9.1 ships" version-stamp; no exercise.
- **metrics-and-accounting** -- OK/Med: three Definition callouts; hardcoded
  `bars_per_year`; equity curve computed but never plotted. Best R4DS recompute
  chunk.
- **metric-contexts-and-conventions** -- High: overloaded (three jobs);
  `metric-context-provenance` hidden; man-page-y formula/condition-class blocks;
  no exercise; topic-list opening. Split candidate.
- **data-input-and-snapshots** -- Med: snapshot created but never inspected with
  output; temp-store boilerplate; field tables lean man-page-y; no exercise.
- **experiment-store** -- High: stale "v0.1.8.5" (Section 2.4); mis-headed
  "What's Next?"; `trust=TRUE`/hash-not-safety caveat not elevated to a callout;
  no exercise.
- **reproducibility** -- OK. Strong opening, disciplined callouts, executed
  preflight output, good exercise. Confirm the `TTR::SMA()` chunk renders
  without TTR; reconcile no-`db_path` snapshot idiom.
- **leakage** -- High (structural): no "Where Next"; only one raw-`.html`
  cross-link. Otherwise the R4DS exemplar of the set (executed numerical
  leak proof).
- **sweeps** -- High: too long (717L, split candidate); nine callouts
  (overuse); three version-stamps; `ledgr_sweep_review()` UX gap; topic-list
  opening.
- **walk-forward** -- OK. Exemplary opening and fold-timeline visualization.
  Low: name the degradation columns to read before printing.
- **risk-and-cost** -- OK. Med: three stacked Boundaries callouts (de-stack);
  dangling lot-size/rounding admission with no surface to link.
- **research-workflow** -- OK (defensibly long, 671L). High UX: shared
  `ledgr_sweep_review()` boilerplate; v0.1.8.6 cycle reference; prescribes
  equity/drawdown plots it never shows.
- **research-to-production** -- High: stale delivered-list + mis-anchored
  roadmap (Section 2.2); no callouts/cross-links/Where-Next.
- **articles/who-ledgr-is-for** -- OK. Med: relative-link paths (Section 2.5);
  no walk-forward beat in the "not fooling yourself" thesis.
- **articles/why-r** -- OK. High: stale `jsonlite` dependency (Section 2.1).

---

## 5. R4DS north-star assessment

The teaching surface splits cleanly:

- **Exemplars** (motivate-before-mechanism, learn-by-doing exercises,
  visualization-as-explanation): `research-workflow`, `leakage`,
  `reproducibility`, `walk-forward`, `risk-and-cost`, `metrics-and-accounting`.
- **Laggards** (topic-first, no exercise, no visualization): `metric-contexts`,
  `strategy-authoring-tools`, `ttr-and-adapter-indicators`, `data-input`,
  `experiment-store`, `sweeps`.

Two specific practice-what-you-preach visualization gaps now that
`walk-forward.qmd` proved the in-vignette ggplot pattern works:
`metrics-and-accounting` computes an equity curve but never plots it, and
`research-workflow`'s report outline prescribes "equity and drawdown plots" it
never demonstrates.

---

## 6. Length and split recommendations

- **`sweeps.qmd` (717L) -- split.** The retention / save-reopen / three-
  evidence-tiers / PerformanceAnalytics-interop cluster (roughly L366-517) is a
  technical-companion's worth of density inside a concept article. Recommended
  split: keep the concept article as declare -> grid -> run -> inspect ->
  promote -> non-goals; move retention + save/reopen + external-metric
  conventions into a companion (e.g. "Sweep Retention And External Metrics"), or
  fold save/reopen into `experiment-store`. This also lets several Definition
  callouts go.
- **`metric-contexts-and-conventions.qmd` (444L) -- consider splitting.** It
  carries three jobs (context construction, the risk-metric contract, a
  zero-trade/warmup/compiled-accounting diagnostic playbook). The diagnostic
  half (~L326-428) is nearly a separate "Diagnosing Runs" article.
- **`strategy-development.qmd` -- trim.** Move the helper-pipeline strategy to
  the companion, leaving a pointer, so "Basics" covers only the raw
  `function(ctx, params)` contract.
- **Defensibly long:** `research-workflow.qmd` (671L) -- the end-to-end arc is
  its job; not a split candidate.
- **No article is too short.**

Splitting is real work, not a doc patch: `sweeps` and
`metric-contexts-and-conventions` are pinned in `_pkgdown.yml` navigation
(around L27, L35) and in `tests/testthat/test-documentation-contracts.R`
(navigation pins around L1012/L1019, plus the saved-sweep section pin around
L1225). A split must update those pins. This is why Section 7 defers the splits.

---

## 7. Disposition and v0.1.9.5 rescope

Per maintainer direction (2026-06-13), the following are pulled INTO v0.1.9.5
rather than deferred:

- **Stale-fact fixes (Section 2):** `why-r` jsonlite -> yyjsonr (reconcile full
  list against DESCRIPTION); `research-to-production` delivered-list + roadmap
  anchors; `execution-semantics` trades columns; `experiment-store` v0.1.8.5.
  (The `who-ledgr-is-for` links were checked and resolve under pkgdown
  flattening -- not a fix.)
- **Missing helpers (Section 3):** `ledgr_sweep_review()` (3.1) and
  `ledgr_temp_store()` (3.2) -- the two that retire duplicated boilerplate
  across multiple articles. The lower-value helpers (3.4-3.6) and the
  trades-pairing decision (3.3) may be horizon items unless naturally touched.
- **Editorial cleanups (Section 1):** callout de-duplication, weak-opening
  rewrites, missing "Where Next" sections, the strategy-article duplication, and
  the snapshot cross-link fix.

Sequencing note: the two new helpers are additive and identity-neutral (review
display and disposable-store convenience), so they do not interact with the
naming-synthesis or contracts surfaces. The vignette edits that consume them
must land after the helpers exist. The `sweeps` and `metric-contexts` splits
(Section 6) are larger and may stay deferred if the release is already full;
they are recorded here for scheduling.

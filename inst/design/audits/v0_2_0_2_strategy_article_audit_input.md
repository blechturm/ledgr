# Strategy Article Audit Input For LDG-2859

**Status:** Agent-provisional evidence input to LDG-2859, the release-gate
article audit. This is not the audit artifact LDG-2859 requires; it is the
input from one editorial pass, for the auditor to verify, adopt or reject.
**Date:** 2026-09-28
**Baseline:** `b419733` on branch `v0.2.0.2`, after Cut 16 closed.
**Scope:** the 19 installed articles that define a `function(ctx, params)`
strategy. Ten were reviewed in full; nine were scanned for strategy code only.
**Method:** Strategy Basics and Strategy Authoring Tools were read in full by
the main session. Three reviewers read the rest against the shipped API and
`inst/design/vignette_styleguide.md`, reading as a learner who has read only
Strategy Basics. Nothing in the articles was edited by the reviewers.

Markers: **[M]** verified by the main session in source or by execution;
**[R]** verified by a reviewer's execution and not re-checked; unmarked items
are reading judgments. Line numbers refer to `b419733` unless stated.

---

## 1. Product defects the articles expose

These cannot be fixed in prose. P1 and P2 are drafted as Cut 17 in
`tickets.yml`; P3 is routed to a design decision.

**P1. Pulse snapshots compute features differently from a run. [M]**
`ledgr_pulse_snapshot()` calls `ind$fn(window_sub)` with one argument on the
last `requires_bars` rows (`R/pulse-snapshot.R:305-307`). A run uses
`series_fn` when present, otherwise `fn(window, params)` over `stable_after`
rows (`R/features-engine.R:196-202`, `:268-283`). Built-in window features
agree. Recursive TTR indicators do not: TTR RSI(14) for DEMO_01 at 2019-06-03
is 25.39 on a pulse and 41.02 in the run [R]. A custom `fn(window, params)`
fails on a pulse [R]. This falsifies the one-pulse claims in Indicators
(~323-326), TTR And Adapter Indicators (~328-332) and Custom Indicators
(~131, "equivalent after warmup"). Strategy Authoring Tools now qualifies its
claim to built-in indicators. Route: LDG-2876. Old triage: THEME-006.

**P2. The slow-loop warning ignores feature reads. [M]**
`ledgr_scalar_accessor_loop` records bar, OHLCV, position and index reads
(`R/pulse-context.R:524-561`), not `ctx$feature()` or `ctx$features()`. Loops
over feature accessors in Custom Indicators and TTR stay silent at scale [R].
Strategy Authoring Tools now states the boundary. Route: LDG-2877, which
covers `ctx$feature()` only; see P3 for `ctx$features()`.

**P3. Active aliases have no whole-universe read. [R]**
`ctx$vec$feature()` and `ledgr_signal_feature()` accept engine IDs only; in an
active-alias sweep candidate, `ctx$vec$feature("fast")` fails. An active-alias
strategy must loop over `ctx$features(id)`: Sweeps (~162-173), Research
Workflow (~270-284), Indicators' parameter-grid section and
`ledgr_demo_sma_crossover_strategy()` all do. Under style guide section 5 this
is an API gap, not an article fault. Route: design decision for the
feature-engine RFC named by the strategy-authoring-helpers synthesis.

**D1. Rendered articles hide the warnings their prose describes. [M]**
`_quarto.yml:13` sets `warning: false`. Execution Semantics (~190, ~215) and
Metrics And Accounting (~449-451) describe `LEDGR_LAST_BAR_NO_FILL`, which the
render never shows [R]. Decide per chunk (`#| warning: true`) or project-wide.

**D2. Affordability differs by run type, and one article states one rule as
general. [M]** Availability-aware fills are refused with `insufficient_cash`
(`R/availability-economics.R:262`); dense fills let cash go negative, as
Strategy Basics' "Affordability is not automatic" callout says. Survivorship
Bias (~982-994) says "Full allocation is not what rejects an order; the
overnight move against you is" without the availability qualifier [R].

**Incidental product findings [R]:** `ledgr_feature_contracts()` and
`ledgr_feature_contract_check()` fail with an unclassed "values must be length
1" error on an active-alias map; `ledgr_snapshot_from_df()` reports "likely
duplicate PKs" for an integer-typed POSIXct `ts_utc` (as `seq(by = "day")`
returns in R 4.6) and hides the real cause; a named TTR bundle inside a
feature map drops its alias silently; `print(ledgr_run_info())` shows
`Elapsed Sec: 0.430000000000001` and `Persist Features:TRUE`.

---

## 2. Release-gate items

- **Stale render: `vignettes/sweeps.md`. [M]** The freshness check fails at
  line 119. A reviewer's claim that `leakage.md` is stale is wrong: the same
  check re-rendered it and found it fresh [M].
- **Research To Production's release section is stale** (style guide section
  12, "Release-Gate Roadmap Sections"). It is framed as v0.1.x (~35-37, 225,
  227, 268-269) and omits v0.2 work: point-in-time availability, equity cash
  distributions, the CSV ingestion surface, the point-in-time demo bundle,
  `ctx$vec` planes and `ctx$tradable()`, `ledgr_run_explain()` and the Cut 16
  helpers. It also describes paper and live runtime in the present tense
  (~88-94, 147-163) and calls selection "validation" (~98-100, 136-140).
- **Style guide section 12 is stale.** Its reading flow is labelled v0.1.9.5,
  lists none of the point-in-time, missing-data, corporate-action,
  survivorship or selection-integrity articles, and disagrees with
  `_pkgdown.yml:32-33`, which puts Leakage and Reproducibility under Start
  Here. Section 9 assigns adapter declarations to TTR And Adapter Indicators,
  but `ledgr_adapter_r()` and `ledgr_adapter_csv()` are taught in Custom
  Indicators.

---

## 3. Corrected in the same change as this input

Strategy Basics (`vignettes/strategy-development.qmd`):
- removed the spot-FIFO accelerator paragraph (internal shorthand; Sweeps is
  its home);
- replaced the four `for (id in ctx$universe)` loops with whole-vector rules
  (`targets[which(ctx$vec$close > ctx$vec$open)] <- 1`), explained once, so
  the article no longer teaches the pattern its own tip calls slow; removed
  the stale `signal_*()` / `select_*()` names;
- moved "Remembering Between Pulses" after `params`, cut it to the contract,
  and pointed to `?ledgr_strategy_context` for availability `asset_state`;
- "When ledgr Complains" now executes an incomplete target and shows the
  real message;
- `{r cleanup}` became `#| label: cleanup`; the circular Indicators
  prerequisite is gone; Where Next links Sweeps.

Strategy Authoring Tools (`vignettes/strategy-authoring-tools.qmd`):
- the pulse claim is limited to built-in indicators and separates instrument
  choice from share counts (P1);
- the loop tip states the warning's real coverage (P2);
- `keep` is a subsection with an interpreted output instead of an executed
  example inside a warning callout (style guide section 4);
- the short-ranking example follows the object table it depends on;
- the availability `asset_state` pointer goes to `?ledgr_strategy_context`.

Remaining notes on these two articles: Strategy Basics still opens its body
with a three-step list (style guide section 2, minor); Strategy Authoring
Tools never executes `ledgr_signal_feature()`, and its holding-pulse prose
does not name `missing = "exclude"` as the cause of the sale.

---

## 4. Per-article findings

Ranked within each article by how much they would hurt a learner.

### Indicators And Features

1. The article contradicts itself on how strategies read features. The
   accessor table (~116-121) omits `ctx$vec$feature()`; "The canonical
   workflow ... through ctx$feature() or ctx$features() inside the strategy"
   (~123-125), lifecycle step 5 (~216-217), the section intro (~330-337) and
   the crossover loop fragment (~258-266) teach per-instrument reads, while
   the strategy (~371-389) reads whole vectors and ~401-403 keeps the scalar
   and mapped accessors for inspection. Make `ctx$vec$feature()` the strategy
   row and label the others "inspect one instrument".
2. The duplicate-ID statement is wrong (~227-231) [R]: ledgr refuses duplicate
   IDs with `ledgr_duplicate_feature_id`, including two aliases for one
   definition, so an alias cannot separate them.
3. The warmup diagnostic never shows a FALSE row (~556-571) [R]: the DEMO_02
   cut leaves 19 bars; cut at 2019-01-10 and select `warmup_achievable`.
4. The TTR chunk (~140-154) is not guarded on TTR, a Suggests package [R].
5. Parameter grids (~463-531) teach the discouraged string-lookup grid first;
   both `eval: false` chunks run [R]; the chunk rebinds `features`,
   `strategy` and `exp` and uses a closed `snapshot` (style guide section 5
   naming collision).
6. The Expected Sessions section (~127-181) comes second and uses
   availability vocabulary a Strategy Basics reader has not met; move it late.
7. Run output (~434) is uninterpreted; the dead pointer "the TTR bundle
   section below" (~533-536) points nowhere.

### Custom Indicators

1. The example threshold never binds [R]: `range_3` runs 0.76-2.32, so
   `max_range = 5` always holds (2 fills, 0 trades). The Try-it (~333-338)
   premise is false: at 2 the run adds fills. Show the scale on a pulse, run
   at 2, and ask about 1.5.
2. The taught `fn(window, params)` signature breaks pulse inspection (P1);
   `?ledgr_indicator` shows `function(window)`.
3. `gap_contract` is never taught, yet custom indicators are refused in
   availability runs without `gap_contract = "strict_window"`; Indicators
   (~168) sends readers here for "a truthful declaration".
4. The strategy loop (~284-295) can read `ctx$vec$feature("range_3")` with
   identical fills [R]; `summary(custom_bt)` (~324) now prints about 30
   corporate-action lines [R].
5. The `series_fn` chunk (~133-154) is `eval: false` without a reason; the
   opening puts the library chunk first; the diagram repeats Indicators'.

### TTR And Adapter Indicators

1. The pulse debugging recipe (~328-353) gives wrong values for recursive TTR
   indicators (P1): under the article's own RSI < 30 rule, the pulse says buy
   and the run does not [R].
2. The `requires_bars` advice (~369-371) contradicts ledgr's own error
   message, which says to count leading NAs and add one [R].
3. The RSI loop (~180-189) can read `ctx$vec$feature("rsi_14")`, which also
   makes the strategy Tier 1 instead of Tier 2 [R].
4. Warmup is split across three sections (~308-326, 355-373, 375-394) and
   `ledgr_ind_ttr_warmup_rules()` prints twice.
5. The availability boundary is missing: most TTR shapes are unsupported in
   availability-aware runs (Indicators ~170-173).
6. `{r demo-bars}` header syntax (~75); the title promises adapters that live
   in Custom Indicators.

### Sweeps

1. Stale render (section 2).
2. The reader never sees which parameters produced which row [R]: the print
   hides `params` and `feature_params`, candidate IDs are hashes, and the
   promoted winner's parameters are never named. Showing them takes clutter,
   which style guide section 5 treats as an API gap for the candidate print.
3. The central strategy exists only as a shape-only block (~156-174), which
   section 5 forbids when the article's teaching depends on it; P3 explains
   why it loops.
4. Non-goals (~646-648) list shipped features: `risk_chain`, objective
   criteria, DSR and PBO.
5. Failure rows (~580) come after selection and promotion although the text
   says to inspect them first; the failed-rows `select()` (~611-612) hides the
   error columns it selects [R].
6. Outputs are uninterpreted; the Try-it (~284-286) breaks on rerun with
   `ledgr_precomputed_grid_mismatch` [R]; "Three Evidence Tiers" collides with
   reproducibility tiers; "the scoped B2 accelerator" (~497) is shorthand.

### Reproducibility

1. The fix for the most common Tier 3 case is never taught [R]: a function in
   `params` is rejected (`ledgr_invalid_strategy_params`), and defining the
   helper inside the strategy body is Tier 1. Strategy Authoring Tools sends
   readers here for exactly this.
2. "The same rule matters for future sweep workers" (~124-126) is stale:
   parallel workers shipped and accept Tier 1 and Tier 2; "Tier 2 is allowed
   for ordinary runs and sequential sweeps" (~303) implies otherwise.
3. The `eval: false` params chunk (~107-122) could run as a Tier 2 / Tier 1
   pair and prove the captured-value point [R].
4. The provenance prose (~165-179) lists fields the printed run info does not
   show [R]; tier callouts are followed by near-verbatim paragraphs.
5. The main strategy loop (~135-146) can be a whole-vector rule with identical
   fills [R]; the Tier 2 and Tier 3 examples should keep their form because
   the qualification is the lesson.

### Research To Production

1. Release section and runtime tense (section 2).
2. The cost and timing example (~199-212) fails if run: it declares no
   `features` but reads `ttr_sma_20` [R].
3. "Every decision ... is recorded as an immutable event" (~67-69) overstates:
   ledger events are `FILL`, `CASHFLOW` and `DISPOSITION`; targets are not
   events.
4. The strategy-contract example (~172-182) uses exact-ID lookup built from
   `params$window`, a section 13 anti-pattern; a whole-vector version gives
   identical fills [R].

### Leakage

1. The "honest" threshold (~140-156) is itself future-inclusive within the
   quarter it judges [R]; compare with an expanding threshold and print the
   counts the prose asserts.
2. The responsibility table (~245-251) and Where Next (~281-286) read as if
   ledgr had no point-in-time tools; link Survivorship Bias and Point-In-Time
   Inputs while keeping the vendor-data non-claim.
3. The article opens with code (~31-48); the "obvious leak" duplicates
   Strategy Basics (~114-132); three runnable chunks are `eval: false`.

### Survivorship Bias

1. The article never shows a strategy behaving in an availability run [R]:
   `equal_weight_once` trades only on the first pulse. Removing its date guard
   aborts with `ledgr_target_sizing_unavailable`; a guard that holds when a
   member's close is missing runs and shows held-nonmember preservation; a
   selection on `is.finite(close)` liquidates the book on a feed gap. One
   "Try it" built from these would teach the behaviour Strategy Authoring
   Tools sends readers here for.
2. The affordability claim (D2).
3. `equal_weight_once` (~523-533) hand-builds equal weights; a bare
   `ledgr_selection(ctx)` pipeline gives identical fills [R].
4. `summary(point_in_time)` (~857) prints about 30 corporate-action lines and
   an unexplained "Price basis: UNDECLARED" line; the ending drifts into a
   maintainer-facing bundle section (~996-1023). Several of these lines are
   pinned by `tests/testthat/test-documentation-contracts.R:1484-1623` and
   `test-pit-input-documentation.R:259-299`.
5. `achieved_end` (~877) should be `achieved_end_utc` [R]; `fig-` labels
   without captions render bare "Figure 1/2/3".

### Execution Semantics

1. It uses the compatibility wrapper `ledgr_backtest(data =, initial_cash =)`
   (~158-164, ~204-210) [M] while Strategy Basics teaches
   `ledgr_experiment()` and `ledgr_run()`.
2. The warning it teaches is invisible in the render (D1).
3. As the canonical page for how targets become fills it lacks the decision
   and fill timestamps (taught in Survivorship Bias ~647-659) and the reasons
   a target does not fill.
4. "Zero Fills And Zero Trades Are Different" (~220-235) shows one trade and
   no zero-trade case; its P&L cannot be reproduced from the rounded prices.

### Articles scanned for strategy code only

No hard API errors [R]. Experiment Store's `trend_strategy` (~112-121) loops
and can read whole vectors with identical fills [R]; Metric Contexts And
Conventions (~99-105) uses `ledgr_backtest()` without the disclaimer Metrics
And Accounting has; Metrics And Accounting (~478) uses `{r cleanup}`.
Corporate-action cash, missing-data-and-sessions, point-in-time inputs and
risk-and-cost strategies are idiomatic.

---

## 5. Suggested grouping

1. Product fixes first: Cut 17 (P1, P2), then the P3 decision.
2. Release-gate blockers: the Sweeps render and Research To Production's
   release section.
3. Feature articles together (Indicators, Custom Indicators, TTR), after
   LDG-2876 so their one-pulse sentences are corrected once.
4. Workflow articles (Sweeps, Reproducibility, Leakage, Research To
   Production).
5. Availability articles (Survivorship Bias, Execution Semantics).

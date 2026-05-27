# Maintainer Decisions: Public Transaction-Cost API RFC

**Status:** Resolved 2026-05-27. Both decisions adopt Option B. Ready for synthesis.
**Date:** 2026-05-27
**Applies to:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_seed_v2.md`
**Inputs:** v1 seed, Claude response, current code, transaction-cost research.

This note records the two product-facing choices that the maintainer resolved
before the cost API RFC moves to synthesis.

---

## Resolution

**Decision 1 (Public Timing Argument Name):** Option B — rename to `timing_model`.

**Decision 2 (Spread / Price-Adjustment Convention):** Option B — adopt quoted-spread semantics under `ledgr_cost_spread_bps()`.

**Maintainer rationale (2026-05-27):** ledgr is pre-CRAN with no external users. The cost model is being designed from a clean slate alongside the rename. The "silent breakage of existing research" and "documentation churn" concerns that the v2 seed leaned on are phantom in this context — there is no existing user-facing documentation surface that teaches `fill_model` outside roxygen (verified: no `.Rmd` vignettes or `README.md` mention `fill_model`), and there is no existing research to break. Both decisions adopt the cleaner long-run semantics now.

**Actions for v2 seed (applied 2026-05-27):**

- §5 binds `timing_model` as the public argument; legacy `fill_model` removed from the v1 public surface.
- §7 binds quoted-spread semantics under `ledgr_cost_spread_bps()`: BUY pays `open * (1 + spread_bps / 20000)`, SELL receives `open * (1 - spread_bps / 20000)`, so `spread_bps = 5` is ~5bps round-trip cost.
- §4.2 primitive catalog uses `ledgr_cost_spread_bps()` as the v1 primitive name; `ledgr_cost_price_adjust_bps()` reserved as a future asymmetric-adjustment constructor.
- §17 open questions Q1 and Q2 removed (bound here).
- §18 next step updated to "ready for synthesis."

The historical analysis of both decisions (Options A and B trade-offs) is preserved below as audit trail. The resolution above is the binding answer.

---

## 1. Public Timing Argument Name

Decision:

```text
Keep `fill_model` as the timing/fill argument and add `cost_model`, or rename
the timing/fill argument to `timing_model` while ledgr is pre-CRAN?
```

### Option A: Keep `fill_model`

Shape:

```r
ledgr_experiment(
  ...,
  fill_model = ledgr_fill_next_open(),
  cost_model = ledgr_cost_chain(...)
)
```

Arguments for:

- lowest migration and documentation churn;
- current code, config validation, examples, and stored config JSON already use
  `fill_model`;
- once `cost_model` exists, `fill_model` can be taught as timing/fill mechanics
  rather than cost;
- avoids another broad rename immediately after the active-alias and workflow
  documentation cycles.

Arguments against:

- `fill_model` historically included costs, so the name carries old meaning;
- `timing_model` is conceptually cleaner for the long-run pipeline;
- pre-CRAN is the cheapest time to pay the rename cost.

Codex recommendation: keep `fill_model` for v1 public cost API and add
`cost_model` beside it. Use docs to reframe `fill_model` as timing/fill
mechanics.

### Option B: Rename to `timing_model`

Shape:

```r
ledgr_experiment(
  ...,
  timing_model = ledgr_timing_next_open(),
  cost_model = ledgr_cost_chain(...)
)
```

Arguments for:

- cleanest mental model;
- matches the execution-policy pipeline language;
- breaks the historical timing/cost conflation decisively.

Arguments against:

- touches public examples, docs, config validation, stored config shape, and
  reopen/migration wording;
- the cleanup benefit may not justify the churn if only one timing model exists.

---

## 2. Spread / Price-Adjustment Naming And Convention

Decision:

```text
Should the first public spread-like constructor preserve ledgr's current
per-leg price-adjustment convention, or introduce quoted-spread semantics?
```

Current behavior:

```text
BUY  fill_price = open * (1 + spread_bps / 10000)
SELL fill_price = open * (1 - spread_bps / 10000)
```

So `spread_bps = 5` costs about 10 bps over a buy/sell round trip before fixed
fees.

### Option A: Preserve Current Semantics With Clear Naming

Shape:

```r
ledgr_cost_price_adjust_bps(5)
```

or another name that does not imply a quoted bid/ask spread.

Arguments for:

- preserves existing research economics;
- matches current public docs;
- avoids silently rewriting every old `spread_bps` config;
- lets ledgr introduce a separate quoted-spread helper later if needed.

Arguments against:

- users may still expect a "spread" value to mean total bid/ask spread;
- the name is less finance-native than `spread_bps`.

Codex recommendation: preserve current semantics and avoid the ambiguous
`ledgr_cost_spread_bps()` name in v1 unless the help page loudly states
"per-leg adjustment, not quoted spread."

### Option B: Switch To Quoted-Spread Semantics

Shape:

```r
ledgr_cost_spread_bps(5)
```

Semantics:

```text
BUY  fill_price = open * (1 + spread_bps / 20000)
SELL fill_price = open * (1 - spread_bps / 20000)
```

So `spread_bps = 5` costs about 5 bps over a buy/sell round trip before fixed
fees.

Arguments for:

- more intuitive for users who think of spread as full bid/ask width;
- cleaner finance vocabulary for the public constructor.

Arguments against:

- silently changes the meaning of `spread_bps`;
- requires explicit migration notes and parity tests that distinguish old and
  new semantics;
- makes old and new config equivalence more complicated.

---

## Recommended Process Step

Pick Option A or B for both decisions before synthesis. The v2 seed is otherwise
ready for a synthesis pass; another adversarial response round is only useful if
the maintainer rejects the v2 scope.

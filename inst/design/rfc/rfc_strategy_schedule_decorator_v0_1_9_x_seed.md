# RFC: Strategy Schedule Decorator -- Hold Until The Next Date

**Status:** Seed v1, written 2026-06-12 as design preservation. THE CYCLE
IS NOT OPENED: no response stage is scheduled until the proposed window
approaches. Nothing here is binding.
**Date:** 2026-06-12
**Author:** Claude (seed v1; standard role rotation applies when the
cycle opens: response by a different model, synthesis by whoever does
not write v2).
**Proposed window:** a small strategy-authoring tick after v0.1.9.5,
plausibly paired with the Pass 2 target-construction helper extensions
("schedule decorator + Pass 2 helpers"). No optimizer dependency, no
fold-core rework, strategy-layer surface only. Window placement is
maintainer decision MD-1.
**Origin:** 2026-06-12 design conversation; maintainer generalization
recorded in the horizon weight-strategy entry's status update: "in
general all strategies could use that -- hold until the next date."

**Context files:**
- `../horizon.md` entry `2026-06-09 [ux] Weight-strategy wrapper as
  alternative authoring surface`, status update 2026-06-12 (the seven
  pre-recorded design considerations this seed expands)
- `../horizon.md` entry `2026-05-25 [strategy] Target construction
  helper extensions` (Pass 2; "rebalance bands" parking)
- `R/fold-engine.R` (pulse loop, ctx construction, strategy call)
- `R/execution-spec.R` (where a decision-mask init hook would land)
- `R/strategy-preflight.R`, `R/strategy-provenance.R` (predicate
  tiering and wrapped-strategy provenance)
- `R/demo-strategies.R` (`ledgr_demo_sma_crossover_strategy()` --
  constructor-returning-strategy precedent)
- `R/backtest-runner.R` resume path (the constraint that kills option
  A in Section 5)
- `rfc_api_naming_consistency_v0_1_9_5_seed_v2.md` (naming rules;
  D1-resolved prefixed DSL names used throughout)

> This RFC uses "v1" as shorthand for the first implementation of the
> schedule decorator; ledgr's roadmap has no schedule-decorator v1
> milestone.

---

## 1. Problem Statement

Every periodic strategy in ledgr today hand-rolls the same boilerplate:

```r
strategy <- function(ctx, params) {
  if (!is_first_pulse_of_month(ctx)) return(ctx$hold())   # user-invented
  ...actual logic...
}
```

-- where `is_first_pulse_of_month` does not exist, so users invent
date-comparison logic per strategy, each slightly differently, with no
identity, no sweepability, and no teaching surface. Per the vignette
styleguide's own rule, repeated boilerplate is the API asking for a
constructor.

The maintainer-decided shape: a general schedule decorator applicable
to ANY `function(ctx, params)` strategy -- "hold until the next date"
-- with the future `ledgr_weight_strategy()` wrapper as one consumer of
the same machinery rather than its owner.

## 2. Ecosystem Survey (condensed from the 2026-06-12 review)

Four patterns in the field:

1. **Engine-registered scheduled callbacks** (zipline
   `schedule_function`, LEAN Scheduled Events, backtrader timers,
   Nautilus clock timers). Most expressive; couples the engine to
   calendar machinery; the schedule lives in imperative code that
   nothing can hash, store, or sweep. REJECTED for ledgr.
2. **Period controls on the runner** (quantstrat `rebalance_on`,
   PerformanceAnalytics `Return.portfolio(rebalance_on=)`,
   portfolioBacktest `optimize_every`/`rebalance_every`, PMwR
   `do.signal`/`do.rebalance`). PMwR is the strongest precedent:
   period strings OR arbitrary predicate functions.
3. **Schedule as a composable strategy element** (Python `bt`:
   `RunMonthly()` in algo stacks). Structurally identical to the
   decorator proposed here; independent validation of the shape.
4. **Index masks** (vectorbt). Paradigm-specific; not applicable.

ledgr's design is patterns 2+3 merged, with two differentiators no
surveyed framework has: the schedule is **identity-bearing** (hashed,
stored, provenance-visible) and **sweepable** (frequency-vs-cost as a
grid axis). Drift-band rebalancing is additionally absent from the OSS
field (commercial vectorbt PRO excepted); ledgr's Pass 2 parking is
ahead, not behind.

## 3. Proposed Public Shape (illustrative, not contractual)

```r
monthly <- ledgr_strategy_schedule(
  my_strategy,
  rebalance = "month_start"
)
```

- Returns an ordinary strategy: drop-in everywhere a strategy goes
  (run, sweep, walk-forward, promotion, preflight). No downstream
  surface changes.
- Calendar menu, v1: `"month_start"`, `"month_end"`, `"week_start"`,
  `"quarter_start"`, explicit date vectors (snapped forward to the
  next pulse; fail-closed past sample end). Each string has exactly
  one bound meaning against the pulse calendar; no market-calendar
  dependency; EOD/whole-second clean.
- Predicate escape hatch, PMwR-style: `rebalance = function(ctx) ...`
  returning a logical scalar over pulse-known ctx. Same contract as
  the menu semantically; preflighted and source-hashed like any
  strategy code, so custom schedules stay identity-bearing. Menu
  strings are predefined predicates internally; observed common
  predicates are candidates for menu promotion later.

**Bound semantics -- skip-callback.** On non-decision pulses the inner
strategy is NOT called: no feature reads, no `state_prev` advance; the
decorator emits hold-shaped targets. This is the honest reading of
"hold until next date" and the cheap one (a monthly EOD strategy skips
~95% of callbacks). Stateful strategies that expect per-pulse state
updates behave differently under a schedule -- documented prominently
(one warning callout on the help page), not papered over.

## 4. Sweepability Via The Existing ledgr_param Pattern

The UX goal is rebalance frequency as a grid axis. A fixed decorator
argument cannot vary per candidate, so the seed proposes reusing the
active-alias declaration pattern already established for indicator
parameters:

```r
scheduled <- ledgr_strategy_schedule(
  my_strategy,
  rebalance = ledgr_param("rebalance")
)

grid <- ledgr_strategy_grid(
  lookback  = c(60, 120),
  rebalance = c("week_start", "month_start", "quarter_start")
)
```

Concrete values resolve per candidate before execution, flow into
params identity, and need zero new sweep machinery. Fixed
(non-`ledgr_param`) schedule arguments remain the simple case. This
consistency -- the same declaration pattern for feature knobs and
schedule knobs -- is a deliberate design constraint, not a convenience.

## 5. The Core Design Question: How Does The Decorator Know It Is month_start?

The one genuinely unresolved mechanism. Calendar rules need
neighbor-pulse information ("the previous pulse was in a different
month"); `ctx` today carries no pulse index, no calendar facts, no
previous-pulse state. Three options:

- **Option A -- mutable closure state in the decorator** (remember the
  last seen month). REJECTED in this seed: it collides with the
  determinism conventions and, fatally, with resume -- a resumed run
  reconstructs positions from events, and decorator closure state
  would silently reset mid-month. Same bug class as the documented
  ambient-RNG resume limitation, but introduced by ledgr-owned code.
- **Option B -- precomputed decision mask.** The engine knows the full
  pulse calendar before the loop (`pulses_posix` exists at
  execution-spec build time). Calendar schedules resolve to a boolean
  mask at run start: deterministic, resume-safe (recomputable from the
  same pulses), cheap to evaluate per pulse. Cost: the decorator needs
  an init hook from the execution spec -- so the honest claim is
  MINIMAL fold-core touch (one hook), not zero.
- **Option C -- extend ctx with schedule facts** (`ctx$schedule$...`).
  Most general at pulse time; grows the strategy-visible context
  surface for one feature; heaviest contract change.

**Seed lean: a two-tier design built on B.** Calendar rules (strings,
date vectors) precompute to a decision mask via the init hook;
predicate rules evaluate at pulse time over ordinary ctx and therefore
cannot express neighbor-pulse calendar logic themselves (they do not
need to -- the strings cover it; a predicate that wants "month start
AND drawdown gate" composes as `mask AND predicate`, which suggests the
public shape may want `rebalance = "month_start", unless = function(ctx)`
or predicate-receives-mask-verdict; exact composition surface is open
question OQ-2). The response stage should pressure-test the init-hook
placement against `R/execution-spec.R` and the resume path.

## 6. Identity And Provenance

- Schedule parameters (string, date vector, or resolved
  `ledgr_param` value) enter candidate/params identity; two runs
  differing only in schedule hash differently.
- Wrapped-strategy provenance: the stored record carries the inner
  strategy source hash plus the schedule declaration. The
  constructor-returning-strategy precedent
  (`ledgr_demo_sma_crossover_strategy()`) is the implementation
  template; preflight tiers the predicate (a Tier 3 predicate fails
  closed exactly like a Tier 3 strategy).
- Print/info surface: decision-pulse and held-pulse counts on the run
  header (`12 decision pulses / 240 held`), doubling as
  misconfiguration diagnostics (0 decision pulses is loudly visible,
  not silently flat).

## 7. Composition Notes

- **Walk-forward:** folds partition time; the schedule decides decision
  pulses within each window. A monthly strategy in a 3-month test
  window has ~3 decision pulses -- fine, but the degradation table's
  short-test-window flag becomes doubly relevant; one doc sentence.
  `carry_test_state` unaffected (state carries at fold boundaries
  regardless of schedule).
- **Risk chain, timing, cost:** all downstream of targets; unaffected.
  Held pulses emit hold targets, which produce no fills by the
  existing no-delta rule.
- **Metrics:** computed from equity rows as today; `time_in_market`
  semantics unchanged. Zero-trade diagnostics gain one case: many held
  pulses is expected under a schedule, not a warmup symptom.
- **LEDGR_LAST_BAR_NO_FILL:** unchanged; a decision pulse on the final
  bar warns exactly as today.

## 8. Scope Cut And Non-Goals

In scope: the general decorator, the v1 calendar menu, the predicate
hatch, identity/provenance, the decision-mask mechanism.

Explicitly NOT this RFC:

- the weight-wrapper knob triple (`optimize` re-estimation frequency,
  `bands` drift triggers) -- stays with the weight-strategy wrapper /
  portfolio-construction RFC per the 2026-06-12 horizon routing;
- turnover constraints (`||w - w0||_1 <= u`) -- risk-chain family; the
  schedule decides WHEN, turnover limits HOW MUCH;
- market calendars, third-Friday/options-expiry exotica, intraday time
  rules -- the v1 menu is pulse-calendar-only;
- engine-level scheduled callbacks (zipline pattern) -- rejected;
- skip-ctx-construction on held pulses -- a later fold-core
  optimization lever with its own gate (the v1 decorator still
  receives ctx on held pulses to emit `ctx$hold()`).

## 9. Pre-CRAN Framing

No external users; no compatibility cost. Internal costs: one
execution-spec init hook (Option B), provenance capture for wrapped
strategies, preflight extension for predicate tiering, help page +
one vignette section, doc-contract locks. All additive.

## 10. Acceptance Criteria Sketch

- A scheduled strategy is drop-in across run/sweep/walk-forward/
  promotion with byte-identical downstream surfaces.
- Calendar strings produce deterministic decision masks; identical
  pulses -> identical masks; resume reproduces the mask exactly.
- Inner strategy is provably not called on held pulses (callback-count
  test); `state_prev` advances only on decision pulses.
- Schedule participates in params identity; sweep over
  `rebalance = c(...)` yields distinct candidate identities.
- Predicate preflight: Tier 3 predicates fail closed pre-execution.
- Print/info shows decision/held counts; 0-decision-pulse
  configurations are visibly diagnosed.
- Help page carries the stateful-strategy warning callout.

## 11. Open Questions, Maintainer Decisions, Future Obligations

**Maintainer decisions (when the cycle opens):**

- **MD-1.** Window placement: the proposed "schedule decorator + Pass 2
  helpers" authoring tick after v0.1.9.5, vs folding into another
  packet.
- **MD-2.** Predicates in v1, or strings-only first with the hatch as
  fast-follow? (Strings cover the dominant use; predicates add the
  preflight/provenance surface.)

**Open questions (spec-cut):**

- **OQ-1.** Exact v1 string set (is `"year_start"` in? are `_end`
  variants all needed?).
- **OQ-2.** Mask-and-predicate composition surface (single `rebalance`
  arg accepting either, vs `rebalance` + `unless`/`gate` split, vs
  predicate receiving the mask verdict as an argument).
- **OQ-3.** Provenance capture shape for wrapped strategies (what the
  stored record looks like; interaction with `ledgr_extract_strategy`
  recovery).
- **OQ-4.** Whether `ctx` gains any schedule facts at all in v1
  (Option C surface), or the mask stays entirely decorator-internal.

**Future obligations:**

- weight-wrapper consumption of the schedule machinery (the
  portfolio-construction RFC inherits, not redefines);
- rebalance bands (Pass 2 parking stands);
- skip-ctx-construction optimization (fold-core lever, own gate);
- menu promotion pipeline for observed common predicates.

## 12. Cycle State

Seed written 2026-06-12 as preservation while the design conversation
was fresh. The cycle is NOT opened: no response is scheduled. It opens
when MD-1's window approaches -- at which point the response stage
verifies Section 5 against `R/execution-spec.R` and the resume path,
checks the `ledgr_param` reuse claim in Section 4 against the
active-alias machinery, and re-validates the naming against the (by
then accepted) naming-consistency synthesis.

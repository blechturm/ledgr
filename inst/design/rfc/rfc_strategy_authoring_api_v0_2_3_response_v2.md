# Strategy Authoring API: Type 2 Response To Seed v2

2026-10-28. Non-binding response to the maintainer's Type 2 brief. Reviewed
seed v2, its v1 response, cold read v3, stage 5 evidence and the relevant
contracts; executed `spike/strategy-grammar` at `ee377f31`. This agent also
authored stage 5: this is an adversarial own-session review, not independent
certification of that spike.

**Verdict: USABLE_AFTER_CHANGES.** Adopt the flat read surface and ctx-first
two-verb API, but settle declared-state operations and correct the position-fact
replay claim before freezing the first CRAN surface.

The target, decision-time, long-only and no-leverage contracts stand. So do
the cited maintainer decisions: capital-base defaults and required choices,
explicit leaver policy, FIFO basis, recording-bar timestamps and shared bar
counts. None of the findings chooses cash-shortfall fill policy.

## Findings, ranked by damage to readability

### R1 — High: declared state still lacks an operational meaning for “keep” and “forget”

Seed §4.5 is a better authoring surface. Declare a field once and read
`ctx$state$peak`; stop repeating defaults inside every callback. However,
“fields not returned keep their values” changes the state operation. It is
not achieved by changing `state_prev` to `state`.

The executed prototype still drops unread state fields, accepts and removes
`NaN`, and puts `intent_reason` inside `state_update`. Its experiment
constructor rejects `asset_state =`; `ctx$state` is unknown. These are
**unimplemented v2 promises**, not evidence against declarations themselves.
F1 remains open until the patch operation is specified and exercised.

Bind these rules in the synthesis:

- Helper returns are **declared-field patches**. Resolve them against the
  previous complete state at the existing fold normalization boundary,
  before committing the existing stored form. The result helper need not
  discover a hidden current `ctx` through an environment.
- Raw `state_update` remains **complete replacement**, including
  `state_update = list()` to clear it. Validate it against the same declared
  schema; it must not bypass typo/type checks. State retention applies within
  a run, not across walk-forward windows contrary to the existing contract.
- Add an explicit helper equivalent, for example
  `ledgr_strategy_result(targets, reset_state = TRUE)`. Reset to the declared
  defaults; reject combining a whole-state reset with field updates.
- Asset and portfolio field names are unique in the shared state namespace.
  Reserve result-role names such as `targets`, `intent_reason` and
  `reset_state` at declaration. Banning collisions with every top-level ctx
  name is unnecessary for the separate `ctx$state$name` namespace.
- Broadcast only unnamed scalars. Align named asset vectors by ID and reject
  incomplete coverage. Reject `NaN`/infinity **before** interpreting `NA` as
  reset. Reject undeclared persisted fields rather than silently discard them.

Defaults also need a typed identity encoding: the native canonical JSON
encoder rejects a raw `c(peak = NA_real_)`. Preserve that encoder's rule;
normalize declarations before hashing. A flat list earns its place when
defaults have different types:

```r
# c() silently makes hwm character in this declaration.
portfolio_state = c(hwm = NA_real_, regime = "risk_on")
# Preserve each field's type without nesting another constructor.
portfolio_state = list(hwm = NA_real_, regime = "risk_on")
```

Require a small executable declaration/patch/reset example before synthesis
claims F1 closed. No storage redesign is indicated.
Authority: [outputs](../contracts.md#contract-strategy-outputs),
[state](../contracts.md#contract-availability-context-and-state).

### R2 — High: a fills-only replay cannot establish these ledger facts

Seed §4.2 says the bar vectors are “written only by fills” and rebuilt from
fills. The cash-acquisition probe reuses the unchanged
`corporate_action_axis_snapshot(TRUE)` fixture. The strategy only holds.
Native evidence records **zero fills**, a `DISPOSITION` closing AAA at bar
4, an exit buffer of **4**, and public exit age **1** at bar 5.

The prototype observes held/unheld transitions after settlement; it does not
distinguish fills from other accounting events. The contract explicitly says
a disposition is not a fill. Thus the stage 5 replay result is valid for its
trade-only fixture, not a general reconstruction result.

Honor the fixed fill-based definition: update these facts from actual fill
transitions against the canonical book, not from an unexplained change in
quantity. Specify invalidation when a non-fill event closes or creates a
holding. Replay the **committed accounting-event prefix**, including opening
provenance and quantity-changing actions, through the existing rebuild core.
Fills alone cannot establish the book against which an opening/closing fill
is classified. Do not build a second replay engine for the new columns.

The fixed names also require literal teaching: `entry_price` is remaining
FIFO basis, not the original purchase quote; `entry_at` is a bar label, not
the opening execution instant. Those definitions are coherent and binding,
but the names cannot carry those distinctions unaided. Keep the accounting
example next to the first percentage-stop example.

The semantic port of §4.7's trailing rule, using `Inf` for unobserved exits
and one asset-state peak, preserves **all ten columns of all 58 fills**.
That supports its rule, not declared-state merging or cross-run fact carry.
Authority: [accounting events](../contracts.md#contract-execution-accounting-events),
[walk-forward lifecycle](../contracts.md#walk-forward-fold-lifecycle).

### R3 — Medium: Turtle does not justify another public weights abstraction

F5 is still open. In the executed target probe, requests
`c(SPY = 0.03, AGG = 0.6)` beside retained gold give AGG **15** under the
existing quantity cap and **14** under a continuous bounded-weight cap.
Flooring before scaling differs from scaling before flooring. Calling the
second operation “bounded sizing” does not preserve the first operation.

Use ordinary named quantity steps for this outlier. The probe rewrites Turtle
with requested risk exposure, whole-unit quantities, reserved holding value
and a budget cap, then updates a complete `ctx$hold()` target. It reproduces
**all ten columns of 741 fills** on the existing 30-stock fixture. No levered
weights, new target verb or `fit_to_remaining` argument is needed.

```r
quantity <- floor(requested * ctx$equity / price[buy])
cost <- sum(quantity * price[buy])
if (cost > invest_fraction * remaining_equity)
  quantity <- floor(quantity * invest_fraction * remaining_equity / cost)
targets <- ctx$hold()
targets[sell] <- 0
targets[buy] <- quantity
```

Here `requested`, `remaining_equity`, `buy` and `sell` are named rule steps;
the runner contains their complete definitions. Prefer that explicit recipe
for CRAN. A general sizing helper can follow demonstrated repeated need.
This is not a 300-instrument performance claim. Retain strict weight
validation and the seed's explicit reservation formula.
Also carry forward F5's unpriced-weight question: state how the existing
skip-and-preserve rule reserves a weighted holding without a current close.
“Outside the weighted set” alone does not describe that case. Preserve the
contract's mark and sizing failures instead of letting the choice disappear
inside a default base.
Authority: [helper values](../contracts.md#contract-strategy-outputs).

### R4 — Medium: fail-closed choices need teaching before they become runtime errors

The leaver error is useful: the probe names STK04 and both policy values.
It also fires with `keep = "STK04"`, so it is an independent required
portfolio policy, not merely a missing per-ID decision. Honor that maintainer
rule and teach it in the **first indexed-universe recipe**. Show that retained
leavers can make actual holdings exceed the selected count. Distinguish this
rebalance policy from `adjust`, whose unmentioned holdings already stay put;
its proposed signature has no `index_leavers` argument.

Do not extend the “friendly defaults” argument to `n < 0`. Zero selecting
nothing is clear. A negative count can be a bad parameter and, under
rebalance, can liquidate an eligible allocation. Keep a classed negative-count
error and write `open_slots <- max(0, slots - held_after_sales)` where that
rule genuinely needs a clamp. The current prototype already rejects negatives.

### R5 — Low: keep the flat reader and ctx-first consistency; avoid a new style law

`ctx$rsi_2` and `ctx$close` make a condition recognisable without resolving
different readers. The retained-view and lazy-read probes pass again. Adopt
this surface. Keep `within = ctx$buyable` in the first stock-ranking example:
plain columns no longer carry automatic eligibility, and “buyable” is the
existing permission plane, not a price or cash guarantee.

Adopt ctx-first verbs for one argument convention. Delete “a ranking pipeline
ends at the weights” as a restriction: ordinary R also supports
`weights |> ledgr_target_rebalance(ctx, weights = _)`. A local argument-order
adapter executed that form with identical targets. Teach a named `weights`
step first if that reads better; neither form needs another helper.

## F1–F7 disposition

| v1 finding | v2 disposition |
| --- | --- |
| F1: state replacement and result roles | **Open.** Better declarations, but patch/replacement/reset, typed defaults and result-name collisions need R1's operational rules and execution. |
| F2: unknown preservation decisions | **Resolved in the tested view path.** `NA` keep/exit fail; unknown buy candidates are excluded. Preserve that distinction in the cut. |
| F3: adjust units | **Resolved.** `weights =` sets, `add_value =` adds; unmentioned positions remain. Ctx-first is a separate unimplemented argument-order change. |
| F4: schedule scope | **Resolved in the framing.** The whole callback is gated and the existing internal decorator remains. A calendar predicate is still a missing convenience. |
| F5: capital and bounded sizing | **Partial.** Reservation and defaults are explicit; the cap's rounding contract still needs R3. The named quantity recipe is executable evidence. |
| F6: readers and params | **Resolved in the proposed authoring surface.** Flat raw columns plus an explicit eligible pool replace the two-reader burden; heterogeneous params remain a list. Complete the declared-state reader separately. |
| F7: evidence claims | **Partial.** The earlier speed, peer and state-size overclaims are withdrawn. Narrow the fills-only reconstruction claim per R2; retain one-host and experiment-construction clock limits. |

## Answers to the eight questions

| # | Answer |
| --- | --- |
| 1 | **Cash 100,000 disclosed; cost model explicit.** Same recommendation as v1. The defaults experiment establishes less setup, not a universally appropriate cost assumption. Do not revive “zero flatters every result.” |
| 2 | **A named quantity-sizing step, not another kind of weights.** R3's full Turtle recipe preserves 741 fills. If bounded weights remain a release requirement, specify the rounding operation and prove equivalence before naming its helper. |
| 3 | **Keep the declaration and `ctx$state$name` spelling.** Use typed flat defaults, field patches, raw complete replacement and an explicit whole-state reset as in R1. Clear every field to its declared default. |
| 4 | **Facts follow the economic book.** A contiguous `carry_test_state` chain must retain known entry/exit provenance and count the shared calendar across windows. External openings retain unknown entry time; flat test windows start fresh. Declared strategy-state values still reset between windows, as the contract requires. Rebuild from the accounting prefix, not each window's fills alone. Resume and candidate isolation need explicit cut tests; this probe establishes neither. |
| 5 | **One public reader and one authoritative eligibility plane.** Target helpers read the same flat primitives/cache. A private lazy `vec` adapter may remain temporarily; it earns no public API promise. Error reporting should use the declared column manifest, and explicit frame helpers retain their inspection obligations. `holding_value` is still a proposal, unknown to stage 5. |
| 6 | **Yes, for teaching mixed cadence before CRAN.** A pure predicate over the existing schedule/calendar, e.g. `ledgr_schedule_due(ctx, month_end)`, earns its vocabulary. Keep the experiment daily and gate allocation inside it. Execute an example with an off-month-end stop; do not ask authors to hand-roll the session calendar. This predicate is a proposal, not an executed capability here. |
| 7 | **Advisory only.** Warn from inspected opening metadata without invoking arbitrary strategy callbacks. Name the observed holdings and missing choice. Future holdings/signals still require the authoritative decision-time check; a clean plan is no guarantee. |
| 8 | **Confirmed: no decision-graph promise.** Literal names, explicit arguments, existing origins and native intent notes remain useful evidence. Ordinary R arithmetic and plain vectors do not provide parent/operation identity or automatic explanations. No recording registrations belong in this authoring API. |

## Evidence and boundaries

New artifacts are uncommitted under
`C:/Users/maxth/ledgr-wt/strategy-grammar/dev/spikes/strategy-grammar/rfc_response_v2/`:
`probe.R`, `check.R`, `inventory.md` and `evidence/`. They load the package,
use the sealed simulated snapshot and an unchanged corporate-action fixture,
and record native fills, diagnostics and accounting events. The ctx-first
adapter and trailing semantic port are labelled; neither implements declared
state. `environment.txt` records source, snapshot hash and R/package versions.
No new timing claim is made.

From that spike worktree, run the absolute script paths:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" "C:/Users/maxth/ledgr-wt/strategy-grammar/dev/spikes/strategy-grammar/rfc_response_v2/probe.R"
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" "C:/Users/maxth/ledgr-wt/strategy-grammar/dev/spikes/strategy-grammar/rfc_response_v2/check.R"
```

The checker reruns into scratch, diffs the recorded CSVs and demonstrates
that changing explicit leaver sale to preservation breaks the comparison.
That demonstrates a useful checker, not acceptance of every observed behavior.
Seed §9's bare `stage5/gut.R` invocation needs arguments; `stage5/check.R`
already runs all three intended corruptions. No prototype, contract or
existing strategy was edited; the protected v1 probes were untouched.

Review record: one Type 2 invocation; R1–R5 are proposed findings awaiting
maintainer disposition. Correct the state and event-source contracts, retain
the readable core, and replace the unresolved Turtle abstraction with the
ordinary quantity recipe before synthesis freezes the API.

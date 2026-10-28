# Synthesis: Strategy Authoring API

Role: record; RFC-cycle synthesis and durable decision record.
Status: accepted
Authority: accepted synthesis; binds only its stated scope.

**Status:** Accepted by the maintainer on 2026-10-28 after the Type 1
[final review](rfc_strategy_authoring_api_v0_2_3_final_review.md) (PASS), with
FR1 resolved as precedence (D3). FR2 is applied in Section 4; FR3 is a note
for the spec cut. Acceptance does not claim implementation or authorize work
without a ticket cut.
**Date:** 2026-10-28
**Author:** Codex, who did not write seed v2.
**Source baseline:** `7d236038`; executed prototype evidence at `ee377f31`
on `spike/strategy-grammar`.
**Synthesizes:** [seed v2](rfc_strategy_authoring_api_v0_2_3_seed_v2.md),
[response to v2](rfc_strategy_authoring_api_v0_2_3_response_v2.md), and
[response review and maintainer decisions](rfc_strategy_authoring_api_v0_2_3_decisions.md).
Seed v1 and its response are history. Where they differ, the maintainer's
2026-10-27 decisions as amended on 2026-10-28 govern.

## 1. Decision

Adopt the flat strategy-authoring surface for the first CRAN release:
ordinary R conditions and named weights, two ctx-first target verbs, declared
state, and an experiment-level decision schedule. Readability governs the
choice of public words; a pipeline and extra constructors are optional.

Accept the v2 response's R1–R5 with the review's dispositions and the
maintainer's refinements. In particular:

1. State helper returns patch declared fields; raw state returns replace them.
2. Position facts use canonical accounting transitions and accounting-prefix
   replay; the fills-only reconstruction claim is withdrawn.
3. Turtle uses named quantity steps, without a bounded-weights helper or
   `fit_to_remaining`.
4. A character `keep` decides its named leavers; a logical mask does not.
5. Negative selection counts fail. Capital and costs are required investor
   inputs. Rounding and machinery defaults are disclosed.
6. One executed article teaches the patterns and passes the maintainer's cold
   read as an implementation acceptance criterion.

The execution core remains `ledgr_run()` and its shared fold. Strategies remain
`function(ctx, params)` returning complete named quantity targets, directly or
in the existing structured result. No orders, shorting, leverage, second
execution/replay engine, implicit zero for missing targets, or future context
data is introduced. Cash-shortfall fill allocation stays with its separate RFC.

## 2. Bound Design

### D1. One flat, lazy decision view

`ctx` exposes these asset-ID-named columns over `ctx$universe`, in its order:
`open`, `high`, `low`, `close`, `volume`, `position`, `held`, `member`,
`buyable`, `holding_value`, D2's facts, and declared features. The decision axis
retains held nonmembers; it is not merely the current index membership.

`buyable` is the existing authoritative eligibility plane: member and not
target-restricted. It is not a price or cash guarantee. Do not derive a second
eligibility plane in helpers. `holding_value` is quantity times the permitted
decision valuation mark, zero when unheld. An unavailable held mark is not
silently zero; reservation follows D3's failure rule.

Portfolio fields keep their names, including `equity`, `cash`, `universe` and
`ts_utc`; `hold()` returns current full quantities and `flat()` returns explicit
full zero quantities. Declared state is under `ctx$state$name`.

Prepare the read service, indices and feature lookup once per run or candidate.
Build each requested column on first read and cache it for that view. A kept
view retains its cutoff, book values and state values after later pulses.
Neither laziness nor cached mutable buffers may expose later information.
`names(ctx)` and `str(ctx)` list available columns without computing every
feature. Unknown reads fail with a classed error, not `NULL`.

Feature-map aliases are the primary feature column names; unmapped features
use registered IDs. Preserve alias-first, then registered-ID resolution for
feature reads, including dynamic `ctx[[name]]` reads. Inspection distinguishes
aliases from concrete IDs. Reject a feature read name that would collide with
a context field at declaration/resolution, before callback execution; no key
may silently select a bar field instead of the promised feature. Reuse the
accepted map collision and candidate-local identity rules.

Replace public `ctx$vec`, `ctx$feature()` and `ctx$features()` with this read
surface. A private lazy `vec` adapter may temporarily serve internal helpers;
it is not a public compatibility surface. Prepared context frames and
`ctx$bar(id)` move to on-demand helpers through the context-frame-retirement
route in Section 7. Their inspection obligations remain.

### D2. Position facts follow the canonical book

| Column | Binding meaning |
| --- | --- |
| `entry_price` | Remaining FIFO cost basis divided by held quantity; `NA` while flat. |
| `entry_at` | Recording-bar timestamp of the fill that opened the current holding from flat; `NA` while flat or without an evidenced opening fill for this holding. |
| `exit_at` | Recording-bar timestamp of the last fill that closed the position to zero; `NA` without an evidenced closing fill. |
| `bars_since_entry` | Current shared-calendar bar index minus that entry index; `NA` wherever `entry_at` is unknown. |
| `bars_since_exit` | Current shared-calendar bar index minus that exit index; `Inf` without an evidenced closing fill. |

Timestamps are bar labels, not execution instants. Counts are zero on the
recording bar and include skipped decision bars; neither calendar days nor an
instrument's observed-bar count defines them. A supplied opening has its
supplied basis but no invented entry timestamp or age. `peak_since_entry` and
day-count facts are not provided.

Maintain two indexed integer bar vectors at the canonical accounting boundary.
A fill's pre/post book classifies flat-to-held entry and held-to-flat exit.
An addition or partial reduction that stays held does not restart entry age.
A closing fill clears the current entry anchor and records exit; subsequent
re-entry retains the known last exit. Process actual event order, including
multiple transitions within one bar, rather than compare end-of-pulse masks.

Non-fill accounting events do not manufacture fill facts. A non-fill closure
invalidates the current entry anchor without writing a new exit. A non-fill
opening starts with unknown entry time/age. A non-fill change that stays held
retains its entry anchor while basis and quantity follow accounting. Previously
evidenced closing-fill provenance remains the last exit. This specifies the
cash-acquisition case that falsified the prototype's held-mask inference.

Reconstruction replays the committed accounting-event prefix, with opening
provenance, through the existing rebuild core. Splits, dispositions and other
quantity/basis changes participate in the book against which fills are
classified. A fills-only scan is not a general reconstruction algorithm.
Read the other facts from those indices and the canonical book. No future data
or R loop over instruments is introduced.

Resume restores the same facts. A contiguous `carry_test_state` chain carries
their known economic provenance using one shared calendar index across window
boundaries, including boundary executions. A fresh external opening or flat
test window starts without invented history. Sweep candidates are isolated.
Declared strategy state still resets between walk-forward windows under D5;
ledger facts are not strategy memory.

### D3. Two ctx-first target verbs, with visible book policy

| Call | Meaning |
| --- | --- |
| `ledgr_target_rebalance(ctx, weights, keep = NULL, index_leavers = NULL, invest_fraction = 1, capital_base = NULL)` | Replace the eligible allocation. Unweighted eligible holdings go to zero unless kept. |
| `ledgr_target_adjust(ctx, weights = NULL, add_value = NULL, exit = NULL, invest_fraction = 1, capital_base = NULL)` | Change only the named positions; everything else keeps its quantity. |

Both return complete quantity targets through one shared sizing implementation.
`weights =` sets an exposure and may sell; `add_value =` adds currency exposure
using decision prices. It does not promise a currency-sized fill. Empty adjust
holds; empty rebalance clears its eligible allocation subject to preservation.
Zero weights target eligible IDs to zero without a price lookup.

`keep` accepts IDs or a logical mask. `exit` accepts a logical mask. Logical
keep/exit decisions cover the decision axis, align by ID when named, and reject
`NA`, duplicate/off-axis names and invalid coverage. Missing targets remain a
separate, unconditional error. Weighted-and-kept, weighted-and-exited, and
added-and-weighted/exited instructions are contradictions and fail.

For rebalance, each held nonmember needs a leaver decision. A character
`keep = "STK04"` decides preservation for STK04; a logical keep mask does not
satisfy this requirement. `index_leavers = "sell"` or `"keep"` applies to
the remaining undecided leavers. Named keeps are explicit exceptions to that
remaining-set policy. Without a decision, fail at that pulse and name the
undecided assets and both choices. Precedence for a leaver, specific over
general (maintainer, 2026-10-28, final review FR1): a character `keep`, then
`index_leavers`, then a logical keep mask. So `keep = ctx$held & !signal`
with `index_leavers = "sell"` sells unsignalled leavers and keeps other
unsignalled holdings; the overlap is not a contradiction. Document this
precedence where the leaver policy is taught. No default sells leavers. `adjust` has no leaver-policy
argument: its unmentioned positions already stay held, and its explicit exit
mask may close them. Ineligible IDs are never bought by either helper.

#### Capital base and reservations

Let `E` be decision equity; `P` the permitted marked exposure of quantities
preserved outside the weighted set; and `A` the separately requested additions.
Existing quantities in addition IDs contribute to `P`, and each requested
addition contributes to `A` once. Do not also reserve its increment inside
`P`. Exited quantities reserve nothing. Define:

```r
remaining_equity <- max(0, E - P - A)
```

For weighted rebalance, require `capital_base` whenever total and remaining
equity differ; otherwise default to `"total_equity"`, disclosed. A decision
with no positive weight sizing needs no otherwise meaningless base choice.
Weighted adjust defaults to `"total_equity"`, disclosed; the explicit override
is `"remaining_equity"`. `invest_fraction` multiplies the chosen base. It
does not cap kept positions or promise settled cash. Retain these defaults in
target origin and ordinary experiment/run disclosure.

#### Unpriced weighted holdings

In availability contexts, a positive-weight ID without a positive accepted
current close keeps its quantity, zero if unheld; its weight is not
redistributed. A held skipped ID
must have a finite permitted mark, as must every other reserved holding, or
sizing fails. Record the skip as `sizing_unavailable` through the existing
decision diagnostic path, including memory consumers.

Let `B` be the chosen base, `V` the sum of priced requests
`weight * invest_fraction * B`, and `U` the marked exposure of held skipped
weighted IDs. Preserve the existing guard: if `V + U > B`, scale the priced
requests by `max(0, B - U) / V` when `V > 0`; otherwise leave them unchanged.
Then floor their quantities. `U` is reserved within the weighted budget by this guard;
it is not also added to `P` or subtracted a second time from remaining equity.
This guard neither renames the base nor excuses a required base choice due to
other preserved holdings/additions. No skip becomes a silent zero sale.
An unpriced addition likewise preserves quantity, reports unavailable sizing
and retains its requested budget reservation once.

Inspection follows the semantics of its represented context. Existing dense
missing-price behavior stays frozen until execution-core consolidation; this
read-surface change authorizes no new execution-mode branch. Fill affordability
and cash-shortfall allocation are unchanged.

### D4. Plain selection, strict weights, ordinary quantity steps

`ledgr_select_top(score, n =, fraction =, within =)` and
`ledgr_select_lowest()` accept plain named numeric scores. Supply exactly one
of `n` or `fraction`. Counts are non-negative integers: zero selects nothing,
negative/missing counts fail. Fractions are in `(0, 1]`, taking the floored
share of the candidate pool before dropping missing scores, with at least one
requested from a nonempty pool. Missing scores and unknown candidate decisions
are excluded. Fewer usable candidates than requested is allowed by default.
Ties use instrument-ID C-locale order.

`within` names the pool; without it, the supplied score axis is the pool.
Logical vectors align by ID or exact positional length; invalid/duplicate IDs
fail. Teach `within = ctx$buyable` for stock ranking. A plain score does not
carry automatic eligibility, and the target boundary rejects ineligible buys.
Holding/sale/keep sets are ordinary logical expressions, with D3's stricter
preservation/exit validation.
Excluding an unknown score does not preserve a holding; that requires an
explicit keep decision.

`ledgr_weight_equal(selection)` divides the base equally;
`ledgr_weight_equal(selection, each = 0.2)` assigns 20% to each selected ID.
No selection yields empty named weights. Weights are finite named numbers over
known eligible IDs, non-negative and summing to at most one. Do not normalize
invalid weights, admit levered requests through a switch, or redistribute
rounding/skip residuals. Empty weights still mean what the chosen verb says.

Retire `ledgr_select_top_n()`, `ledgr_signal_feature()`,
`ledgr_select_held()`, context selection/missing-policy ceremony and
`ledgr_weight_each()` from the strategy-authoring surface. Research value
types do not become mandatory wrappers. No bounded-weights helper or
`fit_to_remaining` is adopted. Turtle names its requested exposure, whole-unit
quantity, preserved value and budget, then updates a complete target vector.
Preserve its floor-before-cap ordering; continuous weight scaling is not
equivalent. Raw complete quantity targets remain public.

### D5. Declared state, field patches and complete replacement

Declare defaults once as flat typed lists:

```r
asset_state = list(peak = NA_real_)
portfolio_state = list(hwm = NA_real_, regime = "risk_on")
```

`ctx$state$peak` is an asset-ID-named vector over the decision axis;
portfolio fields retain their declared shape/type. Unknown reads and returned
fields fail. This replaces the author-facing `state_prev` read and repeated
`ledgr_asset_state()` default declarations.
Asset and portfolio names share one unique namespace. Reserve result-role
names, including `targets`, `state_update`, `asset_state`, `intent_reason` and
`reset_state`.
The separate state namespace need not ban every top-level ctx name. Defaults
must not undergo heterogeneous `c()` coercion.

`ledgr_strategy_result(targets, ..., intent_reason = NULL, reset_state = FALSE)`
returns a declared-field patch. Validate it at the existing fold normalization
boundary and merge into the previous complete state before persistence.
Omitted fields retain their values. The helper does not discover a hidden
current context through mutable ambient state. `intent_reason` is result
metadata and emits the existing native intent note, never a state field.

Only unnamed asset scalars broadcast. Named asset vectors align by ID and
must cover the axis; malformed coverage fails. Declarations and updates reject
numeric `NaN`/infinity before treating `NA` as reset to the declared default.
Other values must match the declared field contract. `reset_state = TRUE`
restores every default and cannot combine with field updates; it may accompany
result metadata.

Raw `list(targets = ..., state_update = ...)` remains public complete
replacement under the same schema, not another patch path. Omitted fields in
a replacement revert to defaults; `state_update = list()` clears stored state
and hence restores defaults on read. Omitting `state_update` retains state.
Neither raw nor helper returns bypass schema, target or result validation.

Retain list-per-ID asset storage and existing axis lifecycle: remove departed
keys, initialize newly visible/re-entering IDs from defaults, reject returned
off-axis IDs. Reject undeclared persisted fields; do not silently erase them.
State views are pulse snapshots. Carry within a run and resume preserves known
values; walk-forward windows reset strategy-state values under the existing
contract even when the economic book and D2 facts carry.

Normalize scope, names, types and defaults before configuration hashing, with
an explicit typed representation for missing defaults. Do not weaken canonical
JSON's non-finite rule. Schema/default changes participate in identity.
No new storage format is required by this decision; any necessary format
change follows the pre-CRAN current-format refusal policy, without fallbacks.

### D6. Schedule and flat setup

`ledgr_experiment(..., schedule = month_end)` replaces public
`ledgr_strategy_schedule()`. Internally retain the classed function declaration,
compiler, schedule identity, skip verdicts and inner-strategy preflight. This
changes public construction, not scheduler ownership or execution semantics.
An omitted schedule means the existing every-executable-pulse behavior.

The schedule gates the whole callback, including stops and memory updates.
For mixed cadence, provide a pure `ledgr_schedule_due(ctx, schedule)` predicate
over the same calendar/compiler semantics before CRAN. Invoke every executable
pulse and gate allocation inside the callback. Reuse the authoritative parent
axis, partial-period and no-lookahead rules; no second calendar or data-dependent
scheduler is introduced. The predicate cannot make an outer skipped callback
run.

Keep `ledgr_feature_map(name = indicator)` declarations, named indicator steps
where they express an idea, and heterogeneous `params` lists. Time shape such
as skip-month momentum belongs in named feature steps and `ledgr_ind_lag()`.
Do not name every one-use constructor merely to move nesting into lookups.
Ctx-first verbs allow both named weights and ordinary `weights = _` piping.

### D7. Experiment inputs describe the investor

Require an explicit opening/capital and an explicit cost model in the public
experiment workflow. Use the existing `opening = ledgr_opening(cash = ...)`
shape; zero cash with explicitly supplied holdings is valid. Remove the
implicit experiment opening and cash defaults. `ledgr_cost_zero()` remains a
valid explicit research choice, never the missing-cost fallback. Missing-input
errors explain what capital/costs describe and how to supply them.

Extraction, resume and carried openings propagate their evidenced investor
inputs/book; they do not ask again or invent fresh cash. Machinery keeps
disclosed defaults, including the meanings of scheduling, sizing and
investment fractions. Ordinary plan/experiment/run printing identifies the
effective defaults and supplied capital/cost model. A future cash default
requires demonstrated demand and a new maintainer decision.

`ledgr_experiment_plan()` may warn when inspected opening metadata already
needs a capital-base or leaver choice. It does not execute arbitrary callbacks,
invent signals, promise future validity or replace authoritative checks at
each decision. Report the observed holdings and the missing choice.

### D8. Disclose whole-share rounding

Keep decision-time whole-share flooring in package-owned sizing. Run summaries
and ordinary `print()` must report positive intended quantities rounded to zero
and rounded exposure against corresponding intended exposure, with their clock,
currency and aggregation stated. Distinguish a zero addition from liquidation
of a full holding. Do not label unavailable-price skips, deliberate zeros,
risk reductions or cash-shortfall fills as rounding losses.

In shared sizing, distinguish the author's requested exposure, post-guard
pre-floor sizing exposure, and rounded exposure at the same decision prices.
The rounding denominator is priced pre-floor sizing exposure; it must not
overwrite the author's original intent or hide availability adjustments.
Report these values without a recording registration layer.
Actual invested exposure comes from native execution and valuation and must
be labelled separately from target sizing coverage. Neither
one silently substitutes for the other. No ratio with an undefined denominator
is reported as full investment.

Raw quantity returns may contain user-authored rounding whose earlier intent
is unobservable. Explicitly report that rounding-intent coverage is unavailable
for those decisions; do not invent it from zero targets or claim complete
coverage. The cut binds the exact summary fields/aggregation before coding and
tests both measured and unavailable coverage. Fractional shares remain with
the asset-precision RFC.

### D9. Teach by pattern and execute the whole recipe

One executed article teaches fixed mix, filter, rank and rotate, slots,
preservation, position rules and memory. Each example includes its meaningful
setup and passes the maintainer's cold read. The acceptance question is whether
an R user can read the code aloud and recognise its paragraph; line count
alone is not an oracle.

Use plain conditions and named weights first. Teach `within` with the first
stock ranking and leaver policy with the first indexed universe. Show the
selected-count versus retained-holdings distinction. Name `open_slots` and clamp
it explicitly where needed. Place the FIFO-basis and bar-label examples beside
the first percentage stop. Include declared-state reset, mixed cadence with
an off-month-end stop, the ordinary Turtle quantity recipe, explicit investor
inputs and rounding disclosure. Examples are complete strategies returning
full targets, not isolated API demonstrations.

## 3. Contract Changes

The implementation cut amends these stable rule groups with the following
sentences; this synthesis does not edit shipped contracts in advance:

| Rule group | Binding amendment |
| --- | --- |
| [Pulse data](../contracts.md#contract-context-pulse-data), [feature resolution](../contracts.md#contract-context-feature-resolution), [strict features](../contracts.md#contract-context-strict-features) | Context exposes D1's strict named lazy columns, uses the common feature resolver and preserves earlier views; unknown reads fail. |
| [Prepared views](../contracts.md#contract-context-prepared-views), [inspection](../contracts.md#contract-context-inspection) | Retire prepared context frames through the focused frame-retirement design; explicit helpers retain axis, cutoff, value, alias/ID and state inspection obligations. |
| [Context and state](../contracts.md#contract-availability-context-and-state) | Rename the eligibility read to `buyable` without creating another plane; add D2 facts and D5 declared state, patch/replacement/reset and existing axis rules. |
| [Strategy outputs](../contracts.md#contract-strategy-outputs), [target semantics](../contracts.md#contract-availability-targets) | Bind D3's two ctx-first verbs, explicit units, leaver decisions, capital bases and once-only reservations, including the unpriced guard; keep complete literal quantities and execution affordability unchanged. |
| [Decision axis](../contracts.md#contract-strategy-decision-axis) | Plain scores and sets follow D4; candidate unknowns exclude, preserve/exit unknowns fail, short selections are allowed, negative counts fail, and target helpers reject ineligible buys. |
| [Fold core](../contracts.md#contract-execution-fold-core), [accounting events](../contracts.md#contract-execution-accounting-events), [reconstruction](../contracts.md#contract-result-reconstruction) | Maintain fact indices from classified canonical transitions and rebuild from the accounting prefix through the existing core; do not infer fill facts from dispositions or add another engine. |
| [Walk-forward folds](../contracts.md#contract-execution-walk-forward-folds), [window start](../contracts.md#contract-execution-window-start) | Carry known economic fact provenance across contiguous test windows and resume; reset strategy state between windows and isolate fresh openings/candidates. |
| [Construction](../contracts.md#contract-config-construction), [identity](../contracts.md#contract-execution-identity), [durable JSON](../contracts.md#contract-json-durable-bytes) | Require investor capital/cost inputs; normalize typed declarations into identity without admitting raw non-finite configuration JSON or compatibility fallbacks. |
| [Preflight](../contracts.md#contract-execution-preflight) | Opening-policy warnings are advisory metadata inspection; decision checks remain authoritative. |
| [Standard metrics](../contracts.md#contract-result-standard-metrics), [result reads](../contracts.md#contract-result-read-surfaces) | Ordinary summary/print disclose D8's rounding, intended versus rounded exposure, actual invested exposure and unavailable intent coverage. |
| [Strategy teaching](../contracts.md#contract-documentation-strategy-context), [example style](../contracts.md#contract-documentation-example-style) | One executed pattern article and maintainer cold read are cut acceptance criteria, including explicit investor inputs, mixed cadence and literal accounting definitions. |
| [Public names](../contracts.md#contract-public-name-shapes) | Allow the selected `ledgr_select_*` spellings and conforming schedule predicate/result helpers; reconcile `ledgr_passed_warmup` and `ledgr_align_weights` in the cut's export inventory. |

### 3.1 Accepted decisions amended

- **Feature-map read surface:** replace D1/D5's public strategy reader
  locations with D1's flat columns. Keep the prepared alias-first resolver,
  explicit-map anti-shadowing on surviving inspection consumers, alias-keyed
  mapped inspection, candidate identity and parameterized inspection rules.
  Add the reserved context-name
  check at declaration/resolution. Remove obsolete scalar/bundle loop warnings
  when those public readers retire; do not invent replacement alias-access
  tracking. On-demand inspection consumes the retained resolution rules.
- **Scheduler D1/public model:** replace public decorator construction with
  the experiment argument. Retain the internal classed declaration, extraction,
  compiler, fingerprint protection, skip phases, partial-period rules and
  existing identity/provenance. D6's predicate queries the same semantics.
- **2026-10-27 decision 1:** weighted `adjust` now has the disclosed total-equity
  default of 2026-10-28 decision 1; rebalance still requires a base only where
  the bases differ. D3 fixes reservation and unpriced terminology.
- **2026-10-27 decision 2:** no default leaver sale remains binding. D3 adopts
  the teaching error and the 2026-10-28 decision 7 character-keep exception.
- **Other 2026-10-28 decisions:** D2, D4 and D7–D9 incorporate facts, shared
  bars, negative counts, required investor inputs, rounding and pattern teaching.
  These decisions are not promoted back into open questions.

## 4. Detecting Evidence Required By The Ticket Cut

The accepted design is not a claim that seed v2's unimplemented spellings
already passed. Register failure-sensitive acceptance evidence before coding:

1. **Views/resolver:** named values and order, empty/holdings-only axes, alias
   and ID reads, parameters, restricted members, unknown/reserved names,
   one build per repeated read, unused features unbuilt, and saved views after
   book/state changes. Detect shared mutable data or candidate lookup leakage.
2. **Facts/replay:** additions, partial/full sales, re-entry, external openings,
   split/recipient changes, a zero-fill disposition and multiple transitions
   in one bar. A prefix rebuild equals live facts, including resume, boundary
   fills and carried/flat windows. A disposition-as-fill mutation must fail.
3. **Targets:** ctx-first and placeholder equivalence; both empty verbs;
   named versus logical keeps; leaver precedence (character keep, then
   `index_leavers`, then a logical mask); only undecided leavers in the error;
   each contradiction; `holding_value` marks and zero for unheld IDs; zero/unpriced weights; once-only additions and skipped
   exposure. Test both named bases and their required/defaulted cases.
4. **State:** typed defaults/identity, typo/type/refusal, missing versus NaN,
   scalar versus named alignment, patch retention, raw complete/empty
   replacement, whole reset, metadata, axis lifecycle, resume, walk-forward
   reset and sequential/parallel candidate isolation. A merge-to-replacement
   or metadata-to-state mutation must fail.
5. **Integration/teaching:** reproduce unchanged-meaning strategy fills,
   including the 58-fill trailing semantic port and 741-fill quantity Turtle
   evidence at their stated fixture sizes. Name intentional policy changes;
   never modify a registered oracle merely to hide a product failure. Execute
   the mixed-cadence example, required-input errors and complete pattern article.
6. **Disclosure/cost:** detect omission of rounding-to-zero, incorrect
   pre/post exposure, missing raw-intent coverage and lost default disclosure.
   Preregister paired timing thresholds/repetitions for the completed design;
   include experiment construction when claiming warm research iteration.

The stage 5 four-workload clock is prior one-host run-through-fill evidence,
excluding experiment-object construction. It is not performance evidence for
declared state, new disclosures or the whole final API. The trade-only fact
rebuild and peer readability judgments retain their recorded limits.

## 5. Rejected Alternatives

| Alternative | Decision and reason |
| --- | --- |
| One verb with `otherwise`/mode switches | Rejected: obscures whether unmentioned eligible holdings sell or keep quantity. |
| Mandatory pipelines, extra feature-view objects or registrations | Rejected: containers precede the idea; ordinary R and one ctx reader suffice. |
| Default sale of leavers, or a logical keep silently deciding them | Rejected: violates the explicit policy decision; only named keeps identify an exception. |
| Universal cash/zero-cost defaults | Rejected by maintainer decision 8: investor assumptions must be supplied. A possible later cash default is demand-driven, not a current promise. |
| Negative counts silently selecting nothing | Rejected by decision 6: bad parameters must not become liquidation policy; clamp the named slot count explicitly. |
| Fills-only replay or end-of-pulse held-mask inference | Rejected: dispositions and other accounting changes invalidate that proof. |
| Supplied peak, day counts, instrument-local clocks or non-FIFO average-cost accounting | Rejected: peak is strategy memory; shared bars and remaining FIFO basis are the fixed definitions. |
| State patching disguised as complete replacement; undeclared fields; mutable `self` | Rejected: hides forgetting, accepts typos or undermines deterministic reconstruction/isolation. |
| Homogeneous `c()` for heterogeneous defaults | Rejected: silently changes field types; one flat typed list earns its container. |
| Bounded-weights helper, levered-weight exception or `fit_to_remaining` | Rejected: ordinary quantity steps reproduce Turtle; continuous scaling changes rounding and adds vocabulary. |
| Fill-price value targets, automatic normalization or residual redistribution | Rejected: quantity targets use decision data; no new execution or hidden sizing policy. |
| Decision-graph promise or per-alias expression recording | Rejected: plain R arithmetic and vectors do not expose that provenance. |
| Storage redesign or pre-CRAN compatibility readers | Rejected: no evidence requires a new state store, and current-format refusal remains binding. |

## 6. Open Questions Promoted To The Spec Cut

The cited product choices are settled. The cut must resolve and record these
bounded details before their tickets execute:

1. Exact typed declaration/patch encoding, supported portfolio-field shapes
   beyond the scalar examples, and condition/export names. Numeric, integer,
   logical and character scalar defaults, typed missing defaults, asset-vector
   alignment and every D5 operation are required; the encoding cannot weaken
   schema checks or the existing canonical serializer.
2. The native summary fields, decision/asset aggregation and presentation for
   D8. They must expose pre/post rounding, actual versus intended boundaries
   and explicit unavailable raw intent; the decision to disclose is not open.
3. Ticket ownership at canonical fill/rebuild and scheduler boundaries, exact
   failure-sensitive fixtures, and paired timing repetitions/thresholds.
   These calibrate verification, not alternative semantics.
4. The conforming export/contract inventory, including the named F8 conflicts,
   and coordination with the frame-retirement owner's helper/inspection cut.

These are this release's spec-cut work, not reasons to create another RFC or
to defer declared-state, lifecycle or mixed-cadence acceptance evidence.

## 7. Future Obligations And Downstream Consumers

| Accepted obligation / boundary | Route and trigger |
| --- | --- |
| Explicit on-demand frames must preserve inspection obligations. | [Context frame retirement](README.md#ctx-frame-retirement), already due; consumes D1 before removing prepared frame reads. This synthesis fixes its input layout, not all helper spellings. |
| Fractional quantities need their own precision/tradability contract. | [Asset precision](README.md#asset-precision-tradability), before fractional shares are promised; D8's whole-share disclosure ships now. |
| Cash-shortfall allocation is not decided by these sizing bases. | [Execution policy](README.md#execution-policy); preserve existing fills until its owning RFC changes them. |
| Independent sleeves/strategy trees need explicit capital and state ownership. | [Portfolio construction](README.md#portfolio-construction), before separate-capital composition is promised. Ordinary composition inside one callback remains valid. |
| A recorder cannot infer a general decision graph from this API. | A focused recording/provenance RFC before making that promise; literal names, origins, explicit arguments and native intent notes are the current limit. |
| State storage optimization requires its own measured case and format/replay design. | A dedicated storage/optimization RFC if a measured dense workload justifies changing list-per-ID storage; this cycle makes no dense-state speed claim. |

Do not create implementation duties from speculation about a cash default,
extra sizing helpers or additional context statistics. Preserve them in the
non-binding horizon only if useful; demand/evidence is the reopening trigger.
At acceptance, route accepted handoffs to the RFC pipeline with this section
as their source; an owning ticket cut or an explicit maintainer disposition
removes an obligation. Do not silently drop displaced rejection reasons.

## 8. Sequence

1. Type 1 final review checks this synthesis against the binding decisions;
   maintainer acceptance establishes its additional scope. Add the decision
   bridge and route Section 7 obligations at acceptance, without claiming code
   has shipped or rewriting historical responses.
2. The spec cut resolves Section 6, assigns the boundary owners and registers
   Section 4 evidence in `tickets.yml`, the sole implementation sequence.
3. Implement through the existing fold/rebuild core, review each workstream,
   migrate the public surface and complete the inspection handoff. No parallel
   compatibility grammar or fallback reader is introduced.
4. Execute the pattern article and cold reads, verify rounding and input
   disclosure, then consolidate the contract amendment sentences and accepted
   decision amendments. Update release evidence only after the cut's checks.

No production code, registered test, ticket, pipeline or contract is changed
by writing this synthesis. No first-CRAN readiness claim precedes its accepted
implementation and teaching evidence.

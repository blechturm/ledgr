# RFC Synthesis: Strategy Context Surface And Helper Composability

**Status:** Amended draft awaiting focused verification and maintainer acceptance.
**Date:** 2026-09-26
**Author:** ChatGPT, at the maintainer's request. This is also the response author;
that requested role reuse overrides the operative seed's third-author preference.
**Implementation window:** After the v0.2.0.2 release gate.
**Accepted question:** How does a strategy read current information and express
portfolio intent without alignment tricks or hidden allocation policy?
**Inputs:** [Operative seed](rfc_strategy_context_surface_v0_2_x_seed_v2.md),
[response](rfc_strategy_context_surface_v0_2_x_response.md), historical seed,
existing [probes](../../../dev/spikes/strategy-context-surface/probe_findings.md),
contracts, UX decisions and the implementation sources named below.

Citation baseline **D** is design commit `289e13e3e2b516ab50eb89b731f0c7c0f2cee095`.
Baseline **I** is implementation commit `b47b83f46db99842955e10e6ccaf88300213a96f`.
Unprefixed code/contract citations refer to D; I citations are explicitly marked.
Decisions below bind on acceptance, not by publication of this draft.
The [final review](rfc_strategy_context_surface_v0_2_x_synthesis_review.md) passed
the original synthesis at `71c2a3ab`; its evidence and verdict remain unchanged.
The maintainer requested this amendment after a strategy-family usability exercise.
It changes predicate projection and zero-weight sizing explicitly; the original
PASS does not cover those changes. Section 8 bounds the focused follow-up.

## 1. Decisions and costs

| Item | Decision | Implementation cost |
| --- | --- | --- |
| Inspection boundary, seed D1 | Retain `bars`, `feature_table` and `features_wide` in this cut. No repair by automatic table materialization. A removal needs its own focused seed. | Precise reference text now; no inspection reconstruction or cache redesign. |
| Empty domains, seed D2 | Allow empty value objects and complete empty targets; distinguish no members from no visible holdings. | Shared validators, constructors and helper early returns; existing classes remain. |
| Position reads, seed D3 | Remove public `ctx$positions`; rename `vec$positions` to `vec$position`. Keep `position(id)` and `hold()` with distinct roles. | Internal read-site and documentation updates, including the WS16 warning's suggested spelling. |
| Entrances, seed D4 | Keep value constructors and add context-first forms with named payloads. Default selection, predicates and scores operate on investment membership. Explicit nonmember IDs and weights still error. | One small shared alignment/validation path; no new object class or execution path. |
| Zero-weight sizing | An explicit zero member weight produces quantity zero without requiring a sizing close. Positive weights retain their price requirements. | Bounded rebalance-helper correction and detecting examples; no new API. |
| Scalar and feature reads | Retain scalar accessors, feature planes and alias bundles. | No representation rewrite; document the two feature dimensions. |
| Other naming | Remove both tombstones, privatize `safety_state`, rename candidate-rule constructors to `ledgr_rule_argmax()` and `ledgr_rule_argmin()`. | Export/help/call-site amendments; rule payload and type stay unchanged. |
| Disclosure | One documented-surface gate covers actual dense and availability runtime contexts. No member-count target. | Extend the existing documentation-contract tests and reference table. |

No compatibility shims or replacement tombstones are owed. None of these changes
alters execution timing, availability facts, financing, fees, valuation or risk.

## 2. Evidence and corrections to the inputs

**Executed:** The existing source-level probe and its reservation mutant reproduce
at D under R 4.5.2 / rlang 1.1.3. Rerunning that probe at I changes only the census
rows: 29 names, 15 functions, and `tradable()` present. The other recorded helper
observations, including empty-domain failures, remain the same. These executions
source production functions; they are not installed-package or full-fold tests.

Focused source-level execution at I also confirms a warning on the 100th scalar
close read in a 100-asset context, no warning before it, and no second warning on
another pass over that context. The implementation is at I `R/pulse-context.R:463-542`.
The warning remains WS16's responsibility; this synthesis does not redesign it.

The branch publication resolves the code-access limitation. It does not publish
the ignored `.tmp/ws19-*` records: none is tracked in I, and
I `inst/design/ledgr_v0_2_0_2_spec_packet/fast_profile_headroom_closeout.md:95-101`
locates them in local worktrees. The original timing pair and fill counts are
still author-reported here. No decision or acceptance threshold depends on them.

The withdrawal ledger needs four qualifications:

- Equal values did not justify replacing state with `hold()`. That withdraws
  the argument, not the option to remove a duplicate read spelling. Section 5
  chooses removal while retaining a proper state read.
- The practical benefit of plane-based authoring survives. An unverified speed
  ratio does not invalidate that interface or the executed allocation examples.
- Sparse intermediates remain legitimate. Keep the no-data-masking decision
  because explicit evaluated inputs suffice, not because row filtering would
  inherently violate final-target completeness.
- Seed section 2's printed formulation C ends in weights. It needs the final
  target constructor to substantiate target parity; do not teach it as printed.

There is one further distinction the revised seed must preserve: missing numeric
scores and missing logical decisions differ. `select_top_n()` already excludes
missing scores (`contracts.md:617-623`; `R/strategy-helpers.R:129-156`). Execution
with two all-missing member scores produces two zero member targets, not a hold.
The new entrances must disclose that existing ranking policy, not silently change it.

**Executed during the usability exercise:** At D, with NAV 100, AAA close 10
and two held BBB shares marked at 20 but no current BBB close, weights
`c(AAA = 1)` produce `AAA=10, BBB=0`; adding `BBB=0` to the weights errors.
Restoring BBB's quantity afterwards requests exposure 140, not a residual-budget
allocation. If BBB is instead a nonmember, AAA weights 1 and 0.6 produce 6 and
3 shares respectively, with BBB held at 2. These are source-level helper probes,
not fill or full-fold results. The price loop and reservation are visible at
`R/strategy-helpers.R:252-303`. Section 3 corrects only the sizing-price requirement
for zero weights; it does not add automatic partial preservation of members.

## 3. Binding entrance contract

Let **Daxis** be `ctx$universe`, in its current order, equal to `ctx$vec$id`.
Let **M** be Daxis for dense contexts, or the current `ctx$members` subset in
Daxis order for availability contexts. Daxis can also contain held nonmembers;
M cannot (`contracts.md:346-353,375-400`). Constructors use the supplied current
context, never the snapshot's full or future population.

The supported forms are:

```r
ledgr_selection(ctx) |>
  ledgr_weight_equal() |>
  ledgr_target_rebalance(ctx)

ledgr_signal(ctx, values = ctx$vec$feature("return_20")) |>
  ledgr_select_top_n(10) |>
  ledgr_weight_equal() |>
  ledgr_target_rebalance(ctx)

ledgr_selection(ctx, ids = c("AAA", "BBB"))
ledgr_selection(ctx, where = ctx$vec$close > 100)
ledgr_signal(c(AAA = 0.1, BBB = NA_real_))  # existing value form
```

**Dispatch decision:** Recognize a `ledgr_pulse_context` list or environment as
context mode; numeric/logical first arguments retain value-constructor mode.
This is bounded type dispatch, not data masking or a new S3 hierarchy. The seed
cannot simultaneously retain these positional examples, retain value forms, and
forbid all behavior depending on the first argument's class. This synthesis
keeps the examples and corrects that prohibition. Malformed contexts fail closed.

Context mode requires named payload arguments: `values`, `ids`, or `where`.
`origin` remains optional. `signal(ctx)` without `values` is an error. A selection
accepts neither payload (select all M), exactly `ids`, or exactly `where`.
Explicit `NULL` is not an omitted payload; matrix/list/factor payloads are not
coerced into vectors. Supplying `universe` in context mode,
combining payloads, or using a context payload in value mode is an error.
Value forms retain their existing `x`, `universe`, `origin` meanings.

| Input | Bound meaning and validation |
| --- | --- |
| Unnamed `values` or `where` | Exactly length(Daxis); positional alignment to Daxis. No recycling or guessing a shorter member axis. |
| Named `values` or `where` | Unique, nonempty, nonmissing IDs from Daxis; every M ID must occur. Align by ID. Held nonmembers may be omitted. Partial names, unknown IDs or a missing member are errors. |
| `values` | Numeric; finite values and `NA`/`NaN` missing scores are allowed, infinity is not. Return a named `ledgr_signal` on M in canonical order. Supplied nonmember scores are outside the allocation population and are not ranked. No price/restriction quality mask is added. |
| `where` | Logical. Validate type, shape, names and M coverage, then project to M and reject NA on M. Return a named `ledgr_selection` on all M, preserving explicit FALSE. TRUE, FALSE and NA for held nonmembers do not participate in selection; nonmember preservation belongs downstream. |
| `ids` | Character IDs, unique, nonempty and nonmissing, all in M; `character()` explicitly selects none. Return an all-M logical selection, TRUE exactly for these IDs in M order. |
| Deliberate subset | Use `ids` in context mode, or an existing standalone named value constructor. A missing named member in `where`/`values` is not a subset declaration. |

No intermediary is required to span Daxis. No constructor silently screens
members for missing observations, restrictions, valuation age or orderability.
Validate supplied type, shape, names and coverage before projecting to M.
Numeric score validation still rejects infinity anywhere in supplied `values`;
logical missingness is checked on M because only members receive a decision.
This changes context-mode `where` only: standalone logical value constructors
still reject NA. An explicit nonmember `ids` request is an error, not a predicate
to project. Validation uses vectors and the context's prepared axis/index; do not
revalidate sealed facts or materialize a frame to perform alignment.

Use existing condition families, with messages naming the argument, reason and
affected IDs or expected/actual sizes. Exact prose is not an API:

| Failure | Condition class |
| --- | --- |
| Invalid context, missing/conflicting payload, context `universe` override | `ledgr_invalid_strategy_helper` |
| Wrong payload type/length, invalid or unknown names, missing M entries, infinite score, NA on M in `where`, invalid IDs | `ledgr_invalid_strategy_type` |
| Explicit `ids` or weights naming a known nonmember | `ledgr_invalid_strategy_helper` |
| Missing accepted sizing close for a positive member weight under availability | Existing `ledgr_target_sizing_unavailable` |
| Missing/extra/duplicate final target entries | Existing `ledgr_invalid_strategy_result` |

An ID in Daxis but outside M is a known nonmember, not an unknown name.
Explicit membership violations use the helper family; nonmember predicate
entries are projected out and are not membership violations.

`ledgr_target_rebalance()` still completes intent from ctx: unselected members
get zero; held nonmembers retain quantity and reserve absolute marked exposure
before member sizing. Nonmember weights error, including explicit zero weights
bearing a nonmember name; nothing is silently dropped. Whole-share flooring and
negative/leverage rejection stay as bound
(`R/strategy-helpers.R:226-305`; `contracts.md:396-404,614-632`).

**Zero-weight correction:** After validating weights and member eligibility,
set zero-weight member targets to zero without consulting their sizing close,
in dense and availability modes. Positive weights keep the availability error
and dense warn-and-zero price behavior. This is an intentional correction to
the existing price loop, not a claim of unchanged helper behavior. It neither
bypasses pre-strategy valuation nor promises that a requested exit will fill.

**Budget meaning:** Weights and `equity_fraction` apply to allocatable capital A,
not necessarily total NAV. Dense A equals NAV. Under availability, A is
`max(0, NAV - sum(abs(quantity * mark)))` over preserved held nonmembers.
For a positive member weight, quantity is `floor(weight * equity_fraction * A / close)`.
With NAV 100, OLD exposure 40 and AAA close 10, A is 60: weight 1 targets
6 AAA shares; weight 0.6 allocates 36 before flooring, yielding 3 shares.
An optimizer's total-NAV weights must not be passed as residual-budget weights
without conversion. The helper does not infer the optimizer's convention.

After construction, `targets[["OLD"]] <- 0` explicitly requests that held
nonmember's exit. It does not increase other targets using anticipated proceeds.

`ledgr_signal_return()` retains its existing availability-specific substitution
of NA for inadmissible member scores (`R/strategy-helpers.R:90-98`). Document this
as an explicit convenience-helper policy. It is not identical to the new raw
feature-plane entrance under restrictions. `select_top_n()` continues its
missing-score exclusion and tie policy; no new ranking policy is introduced.
If an author wants an unavailable input to skip a rebalance, guard that decision
and return `ctx$hold()`. Deliberate omission, zero and hold remain distinct.

Teach two authoring paths: the selection/weight pipeline constructs a new member
allocation; `targets <- ctx$hold()` followed by explicit quantity edits preserves
other holdings. Returning hold does not bypass downstream risk or guarantee no
fills. Preserving one current member while reallocating others requires reserving
its marked exposure before sizing the remainder. Restoring its quantity after
full-budget sizing is not a safe recipe. Explicit targets can express that policy;
this cut adds no partial-rebalance engine or richer missing-intent object.

## 4. Empty-domain contract

Allow `character()` as an explicit zero-length universe in the four value types.
Normalize names of zero-length numeric/logical payloads to `character()`.
Allow empty `ledgr_signal` and `ledgr_target`, without adding classes. Existing
nonempty validation and full-target name matching remain strict
(`R/strategy-types.R:1-47,108-123,143-159,180-230`).

- Empty M with nonempty Daxis is a holdings-only context. Default selection and
  a signal from valid context input are empty; equal weighting is empty; rebalance returns the
  full named holding quantities, subject to existing valuation prerequisites.
- Empty Daxis yields an empty named target through both selection and signal
  pipelines. Portfolio cash, equity and portfolio-level state remain untouched.
- An explicit empty selection with nonempty M means zero member targets. It
  does not mean skip the decision; held nonmembers are still preserved.
- `select_top_n(empty_signal, n)` returns the existing classed empty selection,
  without warning, for a valid positive n. Argument validation still runs.
- `signal_return()` with empty M returns an empty signal after validating
  lookback; there is no member feature lookup to perform. It registers nothing.
- `ledgr_target(numeric(), universe = c("AAA"))` still errors. Empty input does
  not authorize filling a missing final target. The fold's existing
  availability-only empty-target allowance is unchanged.

Amend the core context constructor, type validators and helper guards. This is
not authorization to permit empty snapshot/config universes or redesign the
interactive `ledgr_pulse_snapshot()` constructor. The authoritative runtime
promise is `contracts.md:375-379`; its validator already handles this case at
`R/strategy-contracts.R:34-58` and `R/fold-engine.R:689`.

## 5. State reads and the deferred inspection boundary

Read quantities with `ctx$position(id)` or the unnamed `ctx$vec$position` plane.
Use `ctx$idx(id)` for a scalar bridge. `ctx$hold()` constructs full named intent;
mutating that result must not alter any state read. Removing `ctx$positions`
does not remove the engine's position snapshot or change pulse timing.

Keep planes unnamed with one explicit axis and strict constructor alignment.
This is a representation decision, not a measured claim about name-allocation
cost. No general axis class, extra scalar availability methods or table DSL is
introduced. Preserve scalar/plane/alias-bundle value and warmup semantics.

**Inspection decision:** My response proposed the removal. It was not backed by
a complete replacement design, and this synthesis does not accept it. Existing
inspection reads depend on the long table or its private projection fallback
(`R/feature-inspection.R:266-317`). `ledgr_pulse_snapshot()` takes an explicit
universe and mock state and requires a bar at the requested timestamp
(`R/pulse-snapshot.R:35-46,74-95,213-230`). These sources do not establish a
replacement for the actual availability-aware callback state.

Retain `bars`, `feature_table`, `features_wide` and `bar(id)` for now. Reference
their present mode-dependent shapes honestly: a schema-only long table may be
empty while registered feature access works. Do not populate that table merely
to make it look complete. Existing prepared views are reused; no per-pulse
frame construction, implicit coercion or history replay is authorized here.

A focused inspection-boundary seed is required before removal: specify what
state is inspected, how its axis and knowledge cutoff are preserved, how a
frozen view survives later pulses, and where table materialization occurs.
It must demonstrate parity on a real availability-aware callback. This is a
future option triggered by prioritizing inspection UX, not a prerequisite to
this cut and not authorization for a new inspection subsystem.

I `ctx$tradable()` remains an explicit, non-default helper. Its current
availability predicate is `admissible & priced`; dense behavior tests a positive
finite close (I `R/pulse-context.R:589-600`). Execution confirmed that it may
include a stale-valued member that still fails sizing. Document that limitation:
it guarantees neither a current sizing close nor execution at the next open.

## 6. Required contract amendments

Acceptance authorizes these precise amendments alongside implementation; the
current contract file is not silently rewritten by this draft.

| Contract location at D | Required amendment |
| --- | --- |
| Public Naming, lines 17-31 | Bind `ledgr_rule_argmax/min` as constructors of the unchanged `ledgr_selection_rule`; remove the old exported spellings without aliases. Rule payload, selection behavior and hashes are unchanged. |
| Availability, lines 375-400 | Keep axis, preservation and reservation rules. Clarify M projection for context predicates/scores, empty-axis behavior and the residual-capital budget. No quality screening. Missing sizing evidence applies to positive weights; zero member weights need no sizing close. |
| Strategy, lines 600-632 | Add section 3's constructor modes, validation, error classes and explicit zero-weight correction, plus section 4's empty objects. Preserve final-target completeness, ranking policy, flooring and the single execution path. |
| Context, lines 743-762 | State unnamed alignment to Daxis; bind `vec$position`, remove the public `positions` view, retain its read-only semantics on the plane, and distinguish `hold()` as intent. Remove tombstone entries from active contracts/help; `safety_state` becomes private. |
| Context, lines 738-742,763-783 | Retain rectangles and the feature routes, disclose the long table's schema-only runtime mode, and document `tradable()`'s exact predicate and limits if WS16 is merged. No inspection equivalence is claimed. |
| Documentation, lines 1197-1247 | Add section 7's surface-table gate and representative authoring examples. Teach residual-budget units and allocation versus hold-and-edit paths; no export/member-count target. |

## 7. Binding documented-surface gate and acceptance

`man/ledgr_strategy_context.Rd` owns one explicit reference table, with dense and
availability applicability, shape, axis, units, missingness and counterpart (or
"not applicable"). Include public top-level members and public `vec` members,
including conditional planes. Distinguish metadata, data reads and intent
constructors. Explain Daxis versus M and named versus positional inputs there.

`tests/testthat/test-documentation-contracts.R` compares that table with contexts
captured from actual dense and availability callbacks, with registered features,
a held nonmember, and an empty availability axis. Compare both directions and
observable shapes, not just counts. The documented expectation must not be
generated from the observed fixture. Added names, stale rows, callable/vector
changes, misaligned lengths/order and wrong namedness must fail. No new registry
or generator is needed. Interactive-only metadata must not be mistaken for a
runtime field when documenting the inspection object.

The following are detecting acceptance checks, not claims that new APIs ran:

| Check and existing owner | Required result / defect it detects |
| --- | --- |
| Surface gate: `test-documentation-contracts.R` | An added public field or a plane changed to a function fails; a stale documented name fails. Dense and availability variants cannot pass by checking only their intersection. |
| Composition: `test-strategy-types.R` | Dense equity 300, closes 10/20: 15/7 shares. Equity 100, AAA close 10 and two OLD shares marked 20: default member target AAA=6, OLD=2; AAA weight 0.6 yields AAA=3, OLD=2. Gut reservation: AAA=10 must fail. Explicit none: AAA=0, OLD=2; explicit OLD zero remains zero. |
| Alignment/errors: `test-strategy-types.R` | Named reversed member scores realign; equivalent full-axis unnamed scores agree. Missing member, short unnamed vector, duplicate/unknown name, NA on M in `where`, NULL/conflicting payload and explicit nonmember IDs/weights fail with section 3's classes. |
| Predicate projection: `test-strategy-types.R` | With M=AAA and Daxis=AAA,OLD, where=(TRUE,TRUE), (TRUE,FALSE) and (TRUE,NA) all select AAA and preserve held OLD after rebalance. Check named reversed order and positional forms. NA for AAA errors; explicit `ids="OLD"` errors. With empty M, logical predicates on held nonmembers yield an empty selection, not an error or liquidation. |
| Zero-weight correction: `test-strategy-types.R` | Members AAA/BBB, AAA close 10, BBB close unavailable but its held mark permissible: weights (AAA=1,BBB=0) and (AAA=1) produce identical full targets, BBB=0, without a price warning/error. Cover dense and availability helper contexts. Weights (AAA=0.5,BBB=0.5) still trigger the existing mode-specific price behavior; zero weight for nonmember OLD still errors. |
| Missingness: `test-strategy-types.R` | A positive-weight member lacking a current close fails under availability even when `priced=TRUE`. All-NA scores yield zero member targets through top-N; an explicit hold guard preserves quantities. No default quality screen may make these cases identical. |
| Empty domains: `test-strategy-types.R` | Both pipelines distinguish Daxis empty, M empty with OLD held, and explicit none with members present. Empty final intent passes only for an empty allowed axis; missing AAA is still rejected. |
| Read/naming parity: `test-pulse-context-accessors.R`, `test-api-exports.R`, `test-walk-forward-selection.R` | Scalar/plane quantities agree; editing hold leaves state unchanged; feature aliases and warmup survive. Old names are absent; renamed rule constructors reproduce the same payload/hash and selection. |
| Runtime/teaching: existing documentation and execution tests | Run and sweep use the same helper outcomes. New entrances and changed state reads create no frames or history queries inside callbacks. Teach equal-member allocation and predicates with held OLD, momentum with an explicit missing-input hold guard, custom weights containing zeros, and stateful entry/exit using hold. Use existing example/test owners; no new strategy harness. |

No equity-invariance condition for fewer fills, timing ratio, or maximum member
count is an acceptance gate. Feature-frame removal and rebalance bands are absent.

## 8. Scope, next step and future obligations

The original final review stands for `71c2a3ab`. Focused verification of this
amendment checks predicate projection, zero-weight sizing and their detecting
examples, plus consistency of budget teaching, contract amendments and scope.
Then cut one scoped implementation workstream after maintainer acceptance.
No new broad spike, full review cycle or package campaign is required here.

Implement only after the v0.2.0.2 release gate. First align contract/reference
text with these decisions, then change constructor/empty-domain behavior and
surface names with their detecting tests. Finish with the documented-surface
gate and executed teaching examples. Current-release articles teach shipped APIs.

After acceptance, record the inspection-boundary deferral in `horizon.md` with
section 5's trigger and evidence requirement. Rebalance bands remain in existing
portfolio-policy work. The [scheduler seed](rfc_strategy_schedule_decorator_v0_1_9_x_seed.md)
remains separate; this RFC neither chooses decision dates nor adds scheduler state.
Per the maintainer's sequencing, causal frames for ML, clustering and estimation
are the next separate RFC after this one; their design and APIs are not bound here.
Warning effectiveness remains with its owning workflow. None blocks this cut.

This work improves composition of supported context and helper surfaces; it does
not change preflight rules for arbitrary user-defined helper functions.
`contracts.md:678-695` and `tests/testthat/test-strategy-preflight.R:82-93`
document the current external-helper restriction. A later wrapped-strategy or
estimator design must address that boundary explicitly, not silently exempt it.
No dependency registry, new weight constructor mode or provenance layer is added.

Historical seeds, responses, the original review and recorded evidence remain
unchanged. No schema, cache, ledger, provenance, availability-policy or financing
redesign is authorized.
Rewriting strategy source may change its normal provenance;
this RFC does not rewrite stored run identities or promise old-source replay.

## 9. Revision history

- 2026-09-26: Initial decision synthesis at D/I. Retains the revised seed's
  question, defers the response's inspection removal, selects one position
  read surface, and binds alignment, dispatch, empty domains and detecting gates.
- 2026-09-26: Maintainer-requested usability amendment following the strategy-family
  exercise, after Claude's PASS on `71c2a3ab` (review committed at `4e65378`).
  Supersedes the rule that TRUE on a nonmember predicate errors: predicates now
  project to M, with NA rejected on M. Explicit nonmember IDs/weights still error.
  Adds the bounded zero-weight sizing correction, residual-budget teaching and
  representative examples. Records the helper-preflight boundary and separate
  scheduler/causal-frame work. Original review preserved; focused verification pending.

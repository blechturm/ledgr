# H4 Focused Confirmation: Historical Projection Synthesis v12

Role: record; Type 1 focused re-review.
Status: complete; PASS_AFTER_PATCHES.
Reviewer: Codex, 2026-10-16.
Authority: verification findings only; no design or implementation authorization.

## 1. Verdict

**PASS_AFTER_PATCHES.** The eight original findings have substantive fixes.
Two small document corrections remain: narrow an added restriction on
estimator admission and correct two supersession-map receivers. Neither
requires a new product decision or another design round.

Reviewed the current uncommitted tree at
`99a3b067f323eb2b5470650f0c4422a517eed8dd`, including the synthesis and routing
edits. The reviewed synthesis has 709 lines and SHA-256
`D2ED0A0E8472FCBE56AB3BDDF33347118BB78E9934C971CBDD17A96BB16BD0D1`.
Line numbers below refer to that version.

Scope: confirm the eight findings in
[rfc_point_in_time_historical_projection_v0_2_x_final_review.md](rfc_point_in_time_historical_projection_v0_2_x_final_review.md).
Accepted inputs remain closed. The original review's clean conclusions stand
where these patches do not change them.

## 2. Findings

### 1. Type 1 - Economic isolation wording also appears to prohibit the intended effect on estimator completeness

**File and line:** synthesis v12, Section 5, lines 257-260.

**Authority:** v11 Section 5 permits declared treatment of missing history and
evaluates readiness on treated required inputs. The adopted research UX
brief's "Causal history is explicit" section and v12 Section 3, lines 135-138,
make `drop_instruments` a filter for incomplete history. The original H4
finding 2 asked to preserve membership, trading permission, valuation marks
and execution prices; it did not prohibit treatment from improving estimator
input completeness.

**Concrete ambiguity:** the new sentence says treatment never creates
"admission to the decision or estimator set". A known, otherwise admissible
instrument can have a close-history window with one eligible missing cell.
Declared carry can fill that cell, so the instrument survives
`na_action = "drop_instruments"`. Read literally, the added estimator-set
prohibition forbids that accepted outcome. Facts-based eligibility and
post-treatment completeness need to remain distinct.

**Code boundary checked:** `ledgr_strict_complete_window_mask()`
(`R/features-engine.R:571`) and the enclosing
`ledgr_availability_valuation_state()` (`R/availability-economics.R:3`).
The latter confirms why the valuation prohibition is needed. The new public
history reader is not implemented, so this is a specification ambiguity,
not a claim of a reproduced production failure.

**Smallest faithful patch:** replace the added estimator-admission wording
with a prohibition on changing facts-based membership/admissibility, trading
permission, valuation marks or execution prices. Explicitly permit declared
treatment to affect history completeness and consequently the documented
`na_action` filter. Keep the existing valuation isolation sentence.

### 2. Type 1 - Two supersession-map receiver lists miss the sections carrying their retained rules

**File and line:** synthesis v12, Section 12, table rows at lines 620 and 627.

**Authority:** the accepted governance-lifecycle synthesis Section 4 requires
the replacement section to be named, and requires the reviewer to reconcile
the map against the affected-rule inventory. This is the remaining locator
part of original H4 finding 5.

**Concrete failure:** H0 row 1.3 retains ordinary prepared-series reuse and
permission for whole-series recalculation. Its operative replacement is v12
Section 7, lines 347-360, but line 620 lists only Sections 1, 2, 10 and 11.
H0 row 5.5 retains required-field admission, readiness on treated inputs and
the absence of an engine carried-share threshold. Those rules are now in
Section 6, lines 289-294, but line 627 points only to Section 5. The prose
fixes exist; an acceptance marker using these table rows points past them.

**Code citation:** not applicable; this is source-to-receiver bookkeeping.

**Smallest faithful patch:** add Section 7 to the receiver list at line 620
and Section 6 to the receiver list at line 627, or split out H0 rows 1.3 and
5.5 with those precise receivers. No semantic change is needed.

## 3. Original findings and clean surfaces

| Original finding | Focused disposition |
| --- | --- |
| F1: cutoff-dependent numerical correctness | Restored in Section 7 and evidence group 15: cutoff-invariant reuse only, complete-series recalculation permitted, independent expected numerical/evidence answers, mask changes, output carry alone and immutable earlier results. |
| F2: required-field admission and economic isolation | Required-field admission, treated-input readiness, separate calculation/output eligibility and no carried-share threshold are restored. Economic isolation is restored subject to finding 1 above. |
| F3: H6 memory gate | Matches register E8: median of three paired repeats; both working set and private commit for each parent gate; process-tree private commit separately; summed working set disclosed as a lower bound; 1.10 limits and explicit exception route. |
| F4: detecting evidence | Now eighteen groups. Explicit reuse mismatches, backward/reordered reads, retained-result mutation, identity sensitivity, rule-3 refusal and exact same-rule sequential/current/staged transport comparisons have owners. |
| F5: supersession and obligation retention | The H0-based map and 28 resolving contract receiver anchors are present. Acceptance preserves shipped behavior and transfers unimplemented duties with sources, triggers, owners and redirect anchors. Correct the two receiver lists in finding 2. |
| F6: implementation and consumer handoffs | Test-only helper retirement, three production-precompute fixture replacements with preserved assertions, the accepted LTB-0196 reason and WS7 carried-share consumer proof are explicit. The helper census still finds exactly the three test calls named by the review. |
| F7: deferred constraints | Lifetime-correction trigger and opposing-overlap qualification, shared-bar-substrate/only-pulses_iso rebuild constraint, and exposure assessment before revision optimization are restored. |
| F8: lifecycle routing | Register, RFC index and macro plan route to focused H4 confirmation, then maintainer acceptance and H5. The synthesis remains a draft without implementation authority. |

The changes preserve availability-only scope, the single frame reader and
matrix adapter, mandatory target construction, the three-way corporate-action
clock rule, return/volatility carry exclusions, one data-start preparation and
the accepted P1/P2 ownership direction. They introduce no cache, durable
feature artifact, compatibility reader or second execution engine.

## 4. Acceptance disposition and verification limits

V12 is ready for maintainer acceptance **after the two bounded text patches
above**. No new architecture, spike or product choice is required. Acceptance
must still apply the source notices, pending contract/decision links and
pipeline consolidation specified in Section 12; implementation remains behind
the ticket cut.

Read-only verification found all 28 contract receiver anchors resolving and
`git diff --check` clean. No production change, private-data workload,
benchmark, test suite or other agent was run. The author's reported
documentation-test pass was not rerun. Only this focused review record was
written; the original H4 review and reviewed artifacts were left unchanged.

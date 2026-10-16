# H4 Final Design Review: Historical Projection Synthesis v12

Role: record; Type 1 final RFC review.
Status: complete; CHANGES_REQUIRED.
Reviewer: Codex, 2026-10-16.
Authority: verification findings only; no design or implementation authorization.

## 1. Verdict

**CHANGES_REQUIRED.** The principal H2 choices are represented faithfully, but
the consolidation loses retained requirements, weakens detecting evidence and
the memory gate, and does not yet satisfy the required supersession discipline.
All eight findings below are Type 1. None requires a new product decision.

Reviewed the working tree at
`99a3b067f323eb2b5470650f0c4422a517eed8dd`, including the uncommitted v12,
decision-register, RFC-index and macro-plan edits. V12 SHA-256:
`520AB2EAFB76E88DEA19B6ADA11114815383267F6E2AA45A3A4EE0A80E84493C`.
Line numbers refer to that working tree. Below, `v12`, `v11` and
`register` abbreviate the named synthesis files and
`rfc_history_wave_v0_2_2_decisions.md`, all in this directory.

The review read AGENTS.md and the RFC cycle first, then the specified design
inputs in order, the relevant H0-H2 closeouts, the H1 aggregate record at
`ledgr-research:e07e89d`, and current production functions. Inputs were
checked independently against the H0 dispositions, accepted register decisions
and code rather than treating the synthesis's inventory as complete. No
private workload, benchmark, test suite or other agent was run. Only this
review file was written.

## 2. Findings

### 1. Type 1 - Retained cutoff-dependent numerical correctness is not carried into the preparation rule and detecting evidence

**Location:** v12 Section 7, lines 334-352; Section 10, lines 446-482.
**Authority:** v11 Sections 6, 7(d) and 8; reviewed drift-map rows 6.1-6.2,
7.4 and 8.6; register Session C, X-F2 (line 287).

V12 requires two-clock fact resolution and immutable results, but its
once-prepared feature-panel wording omits the retained qualification that one
numerical series is reusable only where its answers are cutoff-invariant.
Its fourteen evidence groups also omit the explicit late-known change that
alters an already-historical numerical value or treatment result, including
output carry alone and the newly supported expected-session masks.
Fact-resolution correctness and agreement between entry points cannot detect
a feature panel prepared under the wrong cutoff when all readers reuse it.

This is distinct from revised vendor observations, which remain unexercised.
A late-known lifetime interval can change treatment or computation segments
over unchanged bars.

**Code checked:** `ledgr_availability_prepared_segments()`,
`R/availability-provider-prepared.R:99`, currently collapses starts with
`pmax(effective_from, knowledge_time)`; `ledgr_precompute_payload()`,
`R/precompute-features.R:681`, computes a series per definition/instrument.
Neither existing mechanism by itself supplies the retained historical
numerical oracle.

**Smallest faithful patch:** restore the invariant-reuse qualification and the
permission to prepare cutoff-correct answers by the simplest adequate method,
including whole-series recalculation where needed. Add the retained numerical
revision fixture to Section 10, owned by WS3/H6: independently expected values
and evidence before and after knowledge arrival, input/output carry separated,
mask changes exercised, and earlier returned results unchanged. This selects
no new representation or optimization.

### 2. Type 1 - Required-field admission and the economic separation of treatment are incompletely retained

**Location:** v12 Section 5, lines 218-274; Section 6, lines 283-306.
**Authority:** v11 Section 5, particularly lines 152-154 and 168-175; drift-map
rows 5.1, 5.5 and 7.7; current Contracts, Availability-Aware Strict Features
and Valuation And Terminal Outcomes.

The synthesis refers to a "required input" without retaining the rule that
each indicator declares its required fields and admission tests exactly those
fields. It also drops readiness on treated inputs without an engine-imposed
carried-share threshold, and the explicit prohibition on history treatment
creating membership, trading permission, valuation marks or execution prices.
"Treatment never ... fabricates a source observation" does not state these
other separations. They matter when a single substrate serves several readers.

**Code checked:** `ledgr_strict_complete_window_mask()`,
`R/features-engine.R:571`, currently tests every present OHLC column;
`ledgr_availability_valuation_state()`, `R/availability-economics.R:3`,
updates observed marks from finite close cells. Reusing these paths without
the retained distinctions could reject a close-only calculation for an
irrelevant missing field or refresh a mark from a history-carried close.

**Smallest faithful patch:** restore the required-field declaration/admission,
treated-input readiness and no carried-share threshold clauses, and name all
economic planes that treatment must not change. Assign their declarations to
WS4 and treatment/isolation witnesses to WS3/WS4 in Section 10. Keep hidden
internal imputation prohibited.

### 3. Type 1 - The H6 memory gate loses its statistic and per-metric pass conditions

**Location:** v12 Section 10, lines 484-490.
**Authority:** register Session E, E8, lines 455-465.

E8 binds the median of three repeats. It separately gates both working set
and private commit for each parent peak, and private commit for the
parent-plus-daemon gate, with summed working set disclosed as a lower bound.
V12 says "three repeats" but specifies no aggregation statistic. It mentions
working set and private commit only in the reporting list, leaving the two
parent gates' metrics unspecified. A parent private-commit regression above
10% could therefore be reported without necessarily failing the stated gate.

The H1 record explicitly supplies coarse scale, not limits, so it cannot fill
in these missing gate definitions.

**Smallest faithful patch:** carry E8's median and metric-specific conditions
verbatim in meaning, including the summed-working-set qualification. Retain
the paired host/workload/sampler boundary, separate preparation/fold reports
and explicit maintainer-exception route already present. No product-code
change is implicated.

### 4. Type 1 - The fourteen detecting groups omit accepted reuse/isolation checks and narrow staged-worker parity

**Location:** v12 Section 10, lines 448-450, 465-479; Sections 3 and 9,
lines 149-151 and 416-439.
**Authority:** v11 Section 8 and drift-map row 8.7; register E5, lines
432-440, and D3-F5.

Group 9 checks substrate identity and data planes. E5 additionally requires
sequential, current-dispatch and staged-dispatch agreement on final equity,
trade count, seed, snapshot, strategy and reproduction-key hashes. Group 13's
missing/altered staged-identity refusal does not replace that parity oracle.

The list also does not carry the retained detecting cases for wrong explicit
precompute reuse across policy/axis/cutoff, returned-object mutation and
query-order dependence. Those are asserted elsewhere in v12 but are absent
from the evidence list that the cut is instructed to map. Rule-4 refusal and
the feature/config identity changes likewise need an explicit detecting owner,
rather than relying on the staged-invariant hash test.

**Code checked:** `ledgr_sweep_candidate_tasks()`,
`R/sweep.R:1092`; `ledgr_sweep_eval_candidate_task()`, line 1231;
`ledgr_sweep_eval_candidate_tasks_parallel()`, line 1354;
`ledgr_validate_precomputed_features()`, `R/precompute-features.R:121`;
`config_hash_payload()`, `R/config-hash.R:5`; and
`ledgr_availability_prepared_cursor()`,
`R/availability-provider-prepared.R:135`. These expose distinct execution,
reuse, identity and cursor failure surfaces.

**Smallest faithful patch:** extend the existing evidence groups and name
their WS3/identity/H6 cut owners. Preserve the exact E5 compared fields; use
same-rule execution arms for transport parity. Add explicit precompute
mismatch, backward/reordered request, retained-result mutation, identity-input
sensitivity and pre-v12 refusal witnesses. These restore accepted obligations;
they do not require another spike.

### 5. Type 1 - The required supersession map is missing, and acceptance routing can erase unimplemented obligations

**Location:** v12 Section 12, lines 534-569; RFC index lines 67 and 74.
**Authority:** accepted governance-lifecycle synthesis Section 4,
lines 120-151; `rfc_cycle.md`, Post-synthesis horizon entry pattern;
the macro plan's designation of v12 as the first application-specific
supersession carrier.

A whole-document successor notice and a list of contract topics do not provide
the required target-artifact / addressed-group / disposition / replacement
table. Without it, the reviewer and acceptance author cannot account for every
retained or superseded v11 rule, the narrower H2 changes, and the precise
shipped contract groups.

Acceptance items 3-4 also remove the recursive-indicator and session-axis rows
because the synthesis "consumes" them, without explicitly transferring their
unimplemented obligations and preserving their inbound anchors. Consolidation
does not itself discharge implementation duties. The current index repeats
this early-removal instruction.

**Smallest faithful patch:** add the affected-rule table using the reviewed H0
census and the closed register; include exact stable contract-group addresses
and unchanged dispositions where appropriate. At acceptance, apply the required
source/heading notices and pending bridge/back-links without rewriting shipped
behavior. Consolidate the two pipeline obligations under the accepted
history-wave row, retaining source, trigger and cut owner, and leave redirect
stubs at their old anchors. Discharge them only when tickets own them or the
maintainer explicitly drops them with a reason. This does not require keeping
duplicate live obligation rows.

### 6. Type 1 - Two accepted implementation/consumer handoffs disappear

**Location:** v12 Sections 6, 10 and 12, especially lines 460-482 and 548-553.
**Authority:** register Session B, X-F5, line 205; Session D gap rules,
lines 355-361; PIT-G-013, line 212.

The accepted deletion of `ledgr_sweep_compute_feature_matrix()` and migration
of its three fixture constructions to production precompute has no v12
disposition or owner. Nor does the explicit requirement that WS7 consume
carried-share disclosure. Reporting that share and demonstrating a generic
history-to-target flow are weaker than the named consumer obligation.

**Code checked:** repository-wide caller search finds the helper definition at
`R/sweep.R:2574` and exactly three calls, all in
`tests/testthat/test-sweep.R:1022,1142,1226`. The enclosing tests protect
prebuilt-view parity and mutation isolation across pulses and candidate folds.
They are not a production history path.

**Smallest faithful patch:** restore both handoffs in the cut/acceptance map:
delete the test-only helper while moving those three fixture constructions
and preserving their assertions; have WS7 exercise the disclosed carried-share
consequence. Record the already-accepted reason for the fixture change.
Also name Session B's authorized LTB-0196 expectation change when mapping the
history-start work, so its old restart assertions are changed for that stated
semantic reason, not to hide a failure.

### 7. Type 1 - Deferred lifetime correction and shared-memory constraints are lost

**Location:** v12 Section 11, lines 504-532.
**Authority:** register Session C, D5-F2, line 283; Session E, E6, lines
442-448; v11 Section 9 and reviewed drift-map rows 9.1-9.2.

The consolidated deferral list omits lifetime corrections and their accepted
reopening trigger: acquisitions merged into bitemporal lifetime facts. It
also omits the qualification that only opposing lifetime overlaps are refused.
Trading-status correction rules do not settle lifetime corrections.

The shared-memory deferral retains the 10% trigger but drops E6's constraint
for any reopening: share the bar substrate rather than rebuilding it, and
rebuild only `pulses_iso`. The revision-optimization paragraph also drops
the retained exposure-assessment trigger for a new source with genuine
knowledge clocks or missing sessions.

**Code checked:** `ledgr_fact_validate_lifetime_conflicts()`,
`R/availability-facts.R:1925`, calls the opposing-state overlap check; it
does not refuse every restatement. The mori closeout records the separate
share-versus-rebuild result and its limited two-worker evidence boundary.

**Smallest faithful patch:** restore these deferred decisions with links to
their durable owner/source and exact triggers, preserving the lifetime
qualification and E6 constraint. Retain v11's distinction between exposure
assessment and authorization of revision optimization. Do not implement any
deferred feature in this wave.

### 8. Type 1 - Routing records still name earlier steps as current

**Location:** register lines 100-104; macro plan line 719; RFC index lines
49 and 51.
**Authority:** the same register's Resume here and stage table, lines 17-25
and 129-133; macro-plan H3/H4 status, lines 785-810.

The principal status statements correctly say H0-H2 complete, H3 drafted and
H4 current. However, the register's Next steps still starts by writing stage
3; the H2 closeout paragraph says H3 is current; the history-wave index row
still instructs writing v12; and the recursive-indicator row says the wave
may yet take the gap semantics that H2 has already settled. These are live
routing instructions, not labelled historical quotations.

**Smallest faithful patch:** update those four routing statements to point to
the drafted v12 and current H4 review, with acceptance and ticket cut still
pending. Preserve historical decision text and do not mark the draft accepted.
No code citation applies to this record-consistency finding.

## 3. Major surfaces checked and found clean

These conclusions concern fidelity and current-tree facts, not implementation
of the proposed history API.

- **Scope and authority:** v12 is explicitly unaccepted and gives no present
  implementation authority. Availability-only history, full membership on
  that path, frozen dense inspection and separate core consolidation agree
  with the accepted release-line decision. Deleted feature retention, cache,
  clear API and persistence are explicitly prohibited; the production-source
  and export census finds no resurrection.
- **Public reader:** one `ledgr_history_frame()` request selects exactly one
  bar field or feature; `ledgr_history_matrix()` adapts an existing result
  only. Wide/long orientation, alias-first feature resolution, inclusion and
  exclusion evidence, explicit-ID refusal, suffix lookbacks and separation
  of structural completeness from indicator readiness follow the closed
  direction. Neither public history function is currently exported.
- **Estimator versus targets:** Section 3 preserves mandatory target
  construction rather than making estimation exclusion an engine hold/zero
  instruction. This respects Contracts, Strategy Outputs And Helper Values,
  and target validation in `ledgr_fold_stage_decide()`
  (`R/fold-engine.R:613`).
- **Hydration premises and stage ownership:** the listed temporary seams still
  exist in `ledgr_experiment_window()`
  (`R/walk-forward-folds.R:521`), `ledgr_precompute_features()`
  (`R/precompute-features.R:49`), its window-coverage validator (line 235),
  the fold-row write and current DDL. Their retirement/replacement is routed.
  Envelope/P1/P2 ownership agrees with the accepted fold synthesis. The
  enclosing `ledgr_fold_stage_observe_settle()`,
  `ledgr_fold_stage_decide()` and `ledgr_fold_envelope()`
  (`R/fold-engine.R:272,613,1454`) were read.
- **Masks and civil time:** the common session axis, cutoff-resolved
  instrument masks, inactive-print treatment, halt gaps and venue-Date
  resolution preserve H0-Q2 and PIT-S2-011. They are correctly future changes:
  current `ledgr_fact_time()` (`R/availability-facts.R:1227`) still
  converts Date to UTC, and `ledgr_sealed_range_window()`
  (`R/precompute-features.R:356`) still uses UTC date boundaries.
- **Three-way corporate-action rule:** event-clock/no-knowledge follows
  Session C's assumption; no event or knowledge clock is audit-only;
  knowledge/no-event-clock produces the named cutoff-sensitive refusal.
  This correctly reads H0-Q3 together with Session C rather than extending
  Q3's abbreviated no-knowledge wording to every event-clock row. Current
  constructor and clock/due-index code were checked in
  `ledgr_facts_equity_corporate_actions()`
  (`R/availability-facts.R:568`) and `ledgr_corporate_action_plan()`
  (`R/corporate-action-settlement.R:190`).
- **Indicators:** bounded/history-dependent classes, segment restart,
  first-valid versus convergence, return/volatility input exclusions,
  TTR catalogue scope and tolerance identity follow H2. The custom bounded
  `fn`/`series_fn` comparison is narrowed correctly. The disclosed
  `stable_after`- to `requires_bars`-window change matches
  `ledgr_compute_feature_scalar_at()` and
  `ledgr_compute_feature_series_strict_scalar()`
  (`R/features-engine.R:365,409`); all four built-in constructors set the
  two widths equal. The H2 conformance closeout is not misused as a universal
  numerical tolerance.
- **Trading-status corrections:** monotone knowledge, coverage, no revival,
  supersession before precedence, ancestor-only exemptions, sibling
  competition and cycle/dangling refusal match Session F. The current
  constructor, supersession/source-conflict validators, runtime classifier
  and prepared resolver were inspected; the synthesis treats their repairs
  as future work and keeps the vendor-neutral matrix authoritative.
- **Continuity and inspection:** deciding-run ownership of boundary fills,
  continuous economic state, shared data-start history, the public-run
  comparison and unchanged standalone/flat terminal rule follow H2. Rolling
  and anchored constructors currently shift prior boundaries, confirming the
  need for the accepted original-anchor correction.
  `ledgr_pulse_snapshot()` and `ledgr_compute_pulse_features()`
  (`R/pulse-snapshot.R:44,263`) are currently separate SQL-based helpers;
  v12 correctly proposes shared preparation plus P1/P2 rather than claiming
  parity already exists. Run and sweep calls into the common fold and
  `ledgr_walk_forward_eval_fold()` were traced.
- **Representation and transport:** replacement of the three bar
  representations, provenance-preserving segment merge, separate family
  declarations, local cursors, the segment guard, staged daemon identity,
  one/two-worker claim and no mori adoption agree with E1-E7. The current
  runner hydration and sweep task builder substantiate the duplicate-input
  premise. The H1 and worker-spike records remain bounded evidence, not proof
  of full-scale history performance.
- **Identity and compatibility direction:** current config rule 3, schema
  120 and snapshot hash rule 3 are real constants/gates. The proposed rule-4
  advance, expanded feature fingerprints, old-artifact refusal and conditional
  retention of snapshot hash rule 3 follow D3-F5. Worker count stays outside
  identity; the specifically accepted segment-limit override stays inside.
  No migration, compatibility reader or durable feature artifact is added.

The fourteen evidence groups provide a useful core, but are not sufficient
as the exhaustive cut checklist until findings 1-4 and 6 are addressed.
Open helper/evidence-column naming is appropriately limited to naming; this
review does not select those names.

## 4. Acceptance disposition and next step

**V12 is not ready for maintainer acceptance.** Patch the synthesis and live
routing records for the findings above, with a revision note, then run a
focused Type 1 confirmation. No new architecture round or additional private
benchmark is needed to make these document corrections.

Acceptance remains a maintainer action after that confirmation. Implementation,
contract rewrites and stored-format changes remain with the subsequent ticket
cut and implementation; this review authorizes none of them.

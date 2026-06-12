# RFC: Validation Toolkit -- Selection-Integrity Diagnostics And The Business-Objective Constructor (Seed v2)

**Status:** Seed v2 - supersedes seed v1 after response-stage findings.
Standalone: read this file, not v1, as the current proposal. Nothing is
binding until a synthesis is accepted.
**Date:** 2026-06-12
**Author:** Claude (seed v1 + v2; response by Codex 2026-06-12;
synthesis falls to Codex; final review to Claude).
**Window:** v0.1.9.x, first feature packet after v0.1.9.5. The accepted
v0.1.9.5 naming synthesis (2026-06-12) is binding on every name
proposed here.
**Inputs:** `rfc_validation_toolkit_v0_1_9_x_seed.md` (v1, historical),
`rfc_validation_toolkit_v0_1_9_x_response.md` (Codex, with the D-A
framing patch from the seed-author review), plus the v1 context-file
list (unchanged) and `rfc_api_naming_consistency_v0_1_9_5_synthesis.md`
(accepted, binding).

**Revision note (v1 -> v2).** All six response-required changes
absorbed, plus one seed-author supplementary finding: (1) A-prime is
restated with the binding panel-hygiene gates (Section 5); (2)
`business_objective_hash` session identity is bound as a conditional
payload field following the in-repo metric-context precedent, with a
byte-identity regression gate (Section 6); (3) the `ledgr_pardo_*`
prefix is withdrawn -- criterion constructors move to the
`ledgr_objective_*` domain family, with Pardo's vocabulary binding
criterion semantics and documentation attribution, not the public
prefix (Section 4); (4) Pardo criterion 2's evidence source is bound
(closed-trade realized P&L concentration in v1); (5) external package
version/activity claims are converted to spec-cut re-verification
gates; (6) the clustering helper is narrowed to one deterministic v1
method (hierarchical, no RNG) with the method menu deferred; (S1, new)
the PerformanceAnalytics adapter is repositioned: PA is ALREADY a
Suggests dependency with an optionality-enforcing parity test file and
a binding contracts clause, so the adapter extends an existing
contract-bound optional-evidence boundary rather than creating one.

> This RFC uses "v1" as shorthand for the first implementation of the
> validation toolkit; ledgr's roadmap does not have a validation-toolkit
> v1 milestone. Post-v1 work lives in named follow-up RFCs at their own
> roadmap windows.

---

## 1. Problem Statement (unchanged from v1, abbreviated)

ledgr's evidence machinery is complete through selection (sealed
snapshots, identity-bearing sweeps with retained returns, target-risk
identity, walk-forward sessions with fail-closed scalar selection). It
does not yet answer the question those layers funnel toward: should
this candidate be promoted, given how it was found? Two literatures
answer it from complementary angles, and the 2026-06-07 horizon entry
binds shipping them together: Bailey / Borwein / Lopez de Prado / Zhu
selection-bias correction (DSR, PBO/CSCV, MinTRL, drawdown stop-outs)
and Pardo's nine-criterion robust-strategy checklist. The bundle is the
unit of honesty (the *Pseudo-Mathematics* warning case in one
direction; corrected-metrics-without-thresholds in the other). The
design stance is adapter-first: connect to the R ecosystem's mature
analytics; implement natively only what is missing, small, or
identity-bound.

## 2. Substrate Inventory (verified by the response stage)

The v1 table stands as verified (response Section 1.3, with file:line
citations). Key confirmations: retained-return long/wide accessors
exist over `period_return`/`equity`; saved sweeps persist and reopen
candidate identity including `risk_chain_hash`; walk-forward sessions
store identity fields and per-fold scalar scores (no per-period
candidate returns); closed trades carry timestamps, `realized_pnl`,
and `event_seq`/`ts_utc` ordering (sufficient for Pardo criteria 1, 7,
8); selection rules are scalar-only argmax/argmin with hashes over
`type_id`/schema/metric/direction.

One v2 clarification from the response: **Pardo criterion 2 ("even
distribution of trading profit") binds to closed-trade realized P&L
concentration in v1** -- the natural reading of Pardo's trade-level
criterion, computable from the trades table. A period-return profit
concentration variant is a possible later step, not v1 scope.

## 3. Proposed Scope

Two public pillars plus one shared bridge (unchanged in structure from
v1):

1. **Selection-integrity diagnostics:** DSR, PBO/CSCV (route per D1),
   minimum track-record length, with effective-trial-count input from
   candidate clustering.
2. **Business-objective constructor:** `ledgr_business_objective()`
   composing classed criterion steps into a serializable, hash-bearing
   candidate filter.
3. **The external-evidence bridge:** one-way transformation from
   canonical retained returns to PA-family return-matrix/xts shapes.

### 3.1 Adapter targets (Suggests-only; spec-cut re-verification bound)

External package version and activity claims below are AS OF the
2026-06-07 research pass and are NOT verified current. **Binding gate:
the spec packet re-verifies maintenance status, current version, and
input contracts for every adapter target at packet-open** (response
M5; the research README's reliability caveats apply).

- **PerformanceAnalytics** -- first adapter, REPOSITIONED per S1: PA is
  already in `Suggests` (DESCRIPTION:42), already has an
  optionality-enforcing parity test
  (`tests/testthat/test-metrics-performanceanalytics.R`), and already
  has a binding contracts clause ("external evidence only... must not
  redefine ledgr's owned metric formulas or become a runtime
  dependency", contracts.md ~628-631). The toolkit adapter EXTENDS
  this existing boundary (rolling diagnostics, PSR, MinTrackRecord
  over bridged retained returns); it does not create a new dependency
  posture. The v0.1.9.2 synthesis F5 obligation is satisfied by this
  extension.
- **RPESE** -- serial-dependence-aware standard errors;
  influence-function methods deterministic by construction; bootstrap
  modes opt-in and seeded through ledgr's seed contract if exposed at
  all. Not currently in Suggests; added by this packet.
- **pbo** -- optional adapter ONLY, never a foundation (stale
  maintenance, open upstream correctness issue, input-shape constraint
  per Section 5). Native CSCV fallback from the published
  specification remains the recorded alternative. **Gate: `pbo()`'s
  exact input API is re-verified at spec cut** before the adapter
  ticket is cut.
- **Conditional:** `vrtest`, `changepoint` -- only if the synthesis
  pulls regime awareness into criterion-5 scope.

### 3.2 Native implementations (unchanged from v1 except criterion 2)

DSR (from primary literature; quantstrat's GPL implementation as
behavioral cross-check in optional tests at most, never a code donor);
K-Ratio; Triple Penance PENDING paper-first verification and
load-isolated (droppable from v1 without consequence); PBO/CSCV per
D1; the seven computable Pardo criterion steps (criterion 2 now bound
to closed-trade realized P&L concentration); stable-region analysis
(criterion 4; no R package exists); candidate clustering per Section
3.4.

### 3.3 The bridge (v1 text stands, plus the Section 5 gates)

One-way export from canonical retained returns to PA-shaped
return matrices: sorted `(sweep_id, candidate_id, ts_utc)`, UTC whole
seconds, `period_return` pivoted; consumes already-computed retained
returns only -- never raw fills, never reconstructed positions; PA
outputs labeled as external evidence carrying PA's conventions.

### 3.4 Clustering: one deterministic v1 method (response M6/D-D)

`ledgr_sweep_cluster()` ships in this packet as the
effective-trial-count input, with the method surface deliberately
narrowed: **v1 binds hierarchical clustering over return-correlation
distance -- deterministic by construction, no RNG, no seed surface.**
The horizon sketch's `method = "kmeans"` menu is NOT inherited; method
selection beyond the single deterministic default is a recorded future
obligation. The helper returns candidate-to-cluster mapping plus an
effective-independent-trial-count summary consumable by DSR/PBO.

### 3.5 Licensing posture (tightened wording per response 1.7)

ledgr core is MIT. All adapters are Suggests-only optional boundaries.
Native implementations are written from the primary literature; GPL
implementations are **optional behavioral cross-checks in test code at
most -- never code donors, never translated**. AGPL routes excluded
entirely.

---

## 4. The Business-Objective Constructor

Indicative shape, renamed per the accepted naming synthesis (R7:
one prefix scheme per domain; no person-named public prefix exists in
the namespace -- step families follow their domain like `ledgr_cost_*`
and `ledgr_risk_*`):

```r
objective <- ledgr_business_objective(
  ledgr_objective_even_trades(max_concentration = 0.3),
  ledgr_objective_even_profit(max_concentration = 0.4),
  ledgr_objective_stable_region(min_neighbors = 5),
  ledgr_objective_max_drawdown(0.20),
  ledgr_objective_stable_runs(max_streak = 10),
  ledgr_objective_min_trades(n = 30),
  ledgr_objective_positive_trajectory(slope_min = 0)
)

eligible <- ledgr_sweep_filter(sweep_results, objective)
```

**Pardo's vocabulary binds criterion SEMANTICS and documentation
attribution** (help pages and the vignette cite Pardo 2008 Chapter 11
per criterion), **not the public prefix** (v2 resolution of response
M4/D-B; maintainer veto available as part of D2). `ledgr_sweep_filter()`
returns objective evidence / eligible rows -- it is not a dplyr verb
replacement, and its docs say so.

Design requirements (v1 text stands): classed serializable steps with
deterministic params; canonical plan with `business_objective_hash`
(same plan-json + sha256 recipe as cost/risk); narrowing-then-selecting
composition with walk-forward; fail-closed per-criterion evaluation
(uncomputable criterion = ineligible with classed reason, never a
silent pass).

Deferred criteria unchanged: criterion 3 (long-short balance) behind
the shorting/leverage contract RFC; criterion 5 full cross-market form
behind v0.2.x snapshot lineage (v1 proxy: performance across
walk-forward folds and/or non-overlapping slices, labeled as a proxy).

---

## 5. The PBO Substrate Decision (D1) -- A-prime With Binding Gates

Restated per the response (1.1, M1, patched D-A). The seed retains the
A-prime lean: **sweep-level PBO/CSCV uses the existing v0.1.9.2
retained-return substrate -- no new retention surface -- and the
walk-forward `fold_seq` retention extension is deferred to a
separately-decided fast-follow.** Walk-forward-level PBO is explicitly
NOT solved by this route.

The "no new retention" claim now carries binding panel-hygiene gates
(verified against `R/sweep-retention.R` by the response):

- **First-row NA gate.** Every candidate's first `period_return` is
  structurally `NA_real_`. The adapter drops the first aligned
  timestamp (or proves the downstream function's handling); external
  packages never silently decide.
- **Complete-matrix gate.** `ledgr_sweep_returns_wide()` legitimately
  produces ragged panels (missing cells filled `NA_real_`). The
  PBO/CSCV adapter FAILS CLOSED unless every selected completed
  candidate shares the same timestamp grid after first-row removal,
  with a classed error naming the offending candidates.
- **Universe reporting.** Failed candidates have no retained rows. The
  diagnostic result reports the completed-candidate universe actually
  used (and the excluded set), never implying the full grid entered
  the computation.
- **External-API gate.** `pbo()`'s T x N input contract is re-verified
  at spec cut (Section 3.1).

**D1 as now decidable:** sweep-level PBO over retained
completed-candidate panels with the gates above (A-prime), vs native
CSCV over scores with no adapter route (B). The fast-follow
walk-forward `fold_seq` retention question is logged as a future
obligation either way and is not bundled into D1.

---

## 6. Identity And Provenance -- Conditional Payload Binding (D4)

The v1 "nullable-additive" phrase is replaced with the precise binding
(response 1.2, M2, D-C):

- **Absent objective = absent key.** When no business objective
  participates in selection, the session identity payload contains NO
  `business_objective_hash` key -- not a null, not an `NA`, not an
  empty string. Existing no-objective session ids remain
  byte-identical.
- **In-repo precedent followed:** `ledgr_metric_context_payload()`
  (`R/metric-context.R:512-524`) adds `benchmark` / `market_factor` /
  `mar` to the hash payload only when non-null. The session payload
  adopts the same conditional-inclusion pattern.
- **Supplied objective = key present** with the canonical plan stored
  in a schema-compatible place (nullable DB column acceptable for
  storage; a nullable storage column does NOT imply an always-present
  canonical JSON key).
- **Regression gate:** a fixed fixture proves a no-objective
  walk-forward session id is byte-identical before and after the
  toolkit lands.

Diagnostic provenance unchanged from v1: every result table carries
input identity (`sweep_id`/`session_id`, candidate keys,
`metric_context_hash`, `business_objective_hash` when filtering);
adapter-derived numbers carry adapter package + version as a
structural field; clustering records method and params (no seed needed
for the deterministic v1 method); the toolkit is read-only over the
store. Result persistence remains session-objects for v1 (Q5 lean
unchanged).

Walk-forward integration language uses the accepted post-naming
surfaces: `ledgr_walk_forward_open()` for reopen and the
`ledgr_candidate()` generic for extraction.

---

## 7. Explicit Non-Goals (unchanged from v1)

Purged k-fold / embargo / CPCV (deferral bound by the bundling entry;
native route pre-recorded for any later promotion); HRP (portfolio
scaffolding family); benchmark-relative diagnostics (v0.2.x benchmark
context); regime adapters beyond the conditional note; automatic
promotion gating (the toolkit reports and filters; selection remains a
recorded human decision); walk-forward synthesis amendments; Python
interop beyond comparison-appendix material.

---

## 8. Pre-CRAN Framing

No external users. Internal costs: conditional session-payload change
(byte-preserving for existing sessions, per Section 6 gate); RPESE
added to Suggests; new vignette; doc-contract locks; the `ledgr_objective_*`
and diagnostics surfaces enter the export lock under the bound naming
rules.

---

## 9. Acceptance Criteria Sketch (delta from v1)

v1 criteria stand (DSR over any saved sweep with >= 2 completed
candidates and clustering-overridable trial count; fail-closed
everything; PA/RPESE Suggests-only skipping cleanly; full input
identity on every output; the teaching vignette demonstrating
sweep -> objective filter -> selection -> walk-forward -> DSR/PBO and
stating what the toolkit does NOT prove), plus:

- the Section 5 panel-hygiene gates have classed tests (ragged panel
  rejected; first-row handling explicit; universe reported);
- the Section 6 byte-identity regression fixture passes;
- `ledgr_sweep_cluster()` is deterministic across repeated calls with
  identical inputs (no RNG surface in v1);
- criterion-2 step documents its closed-trade evidence base;
- spec-cut re-verification of adapter versions/APIs is a packet-open
  checklist item, not prose.

---

## 10. Open Questions, Maintainer Decisions, Future Obligations

**Maintainer decisions -- ALL RESOLVED 2026-06-12 (in-line per the
naming-cycle precedent, since this file escalated them):**

- **D1 -- RESOLVED: A-prime with binding gates.** Sweep-level PBO over
  retained completed-candidate panels with the Section 5 panel-hygiene
  gates; walk-forward `fold_seq` retention remains a separately-decided
  fast-follow. Resolution context: the maintainer challenged whether
  sweep-only PBO serves the walk-forward-overfitting motivation; the
  resolving observations were (a) the canonical CSCV input from the
  source paper IS a trials matrix -- a retained sweep -- so sweep-level
  is the textbook form, not the compromise; (b) walk-forward guards
  itself by construction (per-fold OOS test windows + degradation
  table) while the unguarded stage is the candidate-space selection
  before it; (c) every walk-forward fold runs a sweep internally, so
  this machinery is the per-fold building block. The walk-forward
  integration the maintainer wants -- a per-fold train-sweep PBO column
  in the degradation table -- is parked as its own horizon entry
  (2026-06-12 `[evaluation]`) at maintainer request: interesting in
  its own right, enabled by fold-level retention, with A-prime as its
  prerequisite.
- **D2 -- RESOLVED: all-pass for v1, with two maintainer-added binding
  requirements.** (a) **The criterion tear-down is v1 scope, not
  optional**: `ledgr_sweep_filter()` produces a per-candidate x
  per-criterion verdict table (criterion, measured value, threshold,
  pass/fail, reason), and the result's print method leads with it --
  "why did candidate 47 fail?" is always one glance away. (b)
  **Composability and tunability are preserved by design**: criteria
  remain independent classed steps so a scored-composite constructor
  can arrive later as an additive variant (recorded future
  obligation); thresholds are ordinary hashed step params. The
  `ledgr_objective_*` naming resolution stands (no veto).
- **D3 -- RESOLVED: max_drawdown only.** Additive criterion steps can
  extend risk coverage later; nothing pre-empts the deferred VaR /
  tail-risk metric contract.
- **D4 -- RESOLVED: the objective enters session identity** via the
  Section 6 conditional-payload binding with the byte-identity
  regression gate. Maintainer rationale recorded verbatim: "the
  objective has to be part of the id. it changes the whole story" --
  two stories must never share one session id, and the
  DELETE-INSERT-by-session-id persistence design makes the alternative
  an overwrite hazard, not merely an audit gap.

**Open questions (spec-cut):**

- **Q1.** Triple Penance paper-first verification, then in/out call
  (load-isolated; droppable).
- **Q2.** Stable-region detector methodology for criterion 4
  (neighborhood-mean vs local-SD vs smoothed-surface; `.filter`-holed
  grid topology handling).
- **Q3.** Adapter maintenance re-verification results (PA/RPESE/pbo
  current versions, activity, `pbo()` input API) -- mechanical
  packet-open checklist.
- **Q4.** Exact diagnostics result-object classes and print contracts
  (per the ux_decisions print standards).

**Future obligations:**

- walk-forward `fold_seq` per-candidate return retention (the deferred
  half of the original Option A; separately decided fast-follow) AND
  the per-fold train-sweep PBO degradation-table column it enables --
  parked at maintainer request as its own horizon entry (2026-06-12
  `[evaluation]`), not just a retention footnote;
- scored-composite business-objective constructor as an additive
  variant over the same criterion steps (D2 resolution);
- clustering method menu beyond the deterministic v1 default;
- period-return profit-concentration variant of criterion 2;
- purged k-fold / embargo / CPCV promotion decision (native route);
- criterion 3 activation behind the shorting contract RFC; criterion 5
  full form behind snapshot lineage; benchmark-relative diagnostics
  behind v0.2.x benchmark context; Harvey-Liu haircut on demand.

---

## 11. Cycle State And Next Step

Stages complete: research input (2026-06-07), seed v1 (2026-06-11),
response (Codex, 2026-06-12), seed-author response review with one
in-place response patch (D-A framing), seed v2 (this file). Next:
maintainer resolves D1-D4 (in-line here per the naming-cycle
precedent, or a stage-6 artifact if any escalate); then synthesis by
Codex binding scope, the adapter/native split, the panel-hygiene and
identity gates, and acceptance criteria; final review by Claude
verifies citations, the gates' mechanical checkability, and naming
compliance against the accepted synthesis.

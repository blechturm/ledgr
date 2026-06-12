# RFC: Validation Toolkit -- Selection-Integrity Diagnostics And The Business-Objective Constructor

**Status:** Seed v1 - request for response-stage review. Nothing in this
document is binding until a synthesis is accepted.
**Date:** 2026-06-11
**Author:** Claude (seed v1; per `../rfc_cycle.md` role rotation the
response stage should be authored by a different model, synthesis by
whoever does not write seed v2).
**Window:** v0.1.9.x, first feature packet after v0.1.9.5. Note a
sequencing supersession: the 2026-06-07 bundling horizon entry's diagram
places the validation toolkit before the docs cycle; the roadmap's
v0.1.9.5 section (authoritative, later) binds "v0.1.9.5 lands before any
other v0.1.9.x planned work". This seed follows the roadmap. Consequence:
the toolkit ships with its own teaching vignette rather than relying on
the v0.1.9.5 docs cycle, and the v0.1.9.5 API-naming rules (R1-R7, if
that synthesis is accepted) apply to every name proposed here.
**Cycle trigger:** recorded in `../research/README.md` ("RFC cycle
expected to open after v0.1.9.4 walk-forward closes"); v0.1.9.4 closed
2026-06-11.

**Research input:** `../research/Validation-Toolkit.md` (2026-06-07 deep
research; non-binding; citation precision varies -- primary sources must
be verified before any claim becomes load-bearing in the synthesis).

**Context files:**
- `../horizon.md` entry `2026-06-07 [planning] Validation toolkit --
  bundling selection-integrity diagnostics with the business-objective
  constructor under an adapter-first posture` (the bundling decision,
  adapter/native split, and pre-recorded open questions)
- `../horizon.md` entry `2026-06-09 [research] Business-objective
  constructor RFC (Pardo-anchored)` (nine criteria, computability map,
  indicative shape)
- `../horizon.md` entry `2026-06-07 [planning] Walk-forward fold output
  -- preserve per-period candidate return vectors` (the PBO substrate
  decision, carried forward 2026-06-11 after v0.1.9.4 shipped
  scalar-only)
- `../horizon.md` entry `2026-06-09 [research] Post-sweep candidate
  clustering as selection-integrity input` (effective-trial-count input)
- `../methodology_references.md` (Bailey / Borwein / Lopez de Prado /
  Zhu; Pardo; Kestner; Peterson)
- `rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md` (session/candidate
  identity, fail-closed selection, Section 17 gate discipline)
- v0.1.9.2 sweep persistence synthesis (retained-return substrate,
  three-tier evidence framing, Section 11 F5 PerformanceAnalytics
  obligation)
- `R/sweep-retention.R`, `R/walk-forward.R`,
  `R/walk-forward-inspection.R`, `R/metric-context.R` (substrate)
- `rfc_api_naming_consistency_v0_1_9_5_seed.md` (naming rules this
  packet must follow)

> This RFC uses "v1" as shorthand for the first implementation of the
> validation toolkit; ledgr's roadmap does not have a validation-toolkit
> v1 milestone. Post-v1 work lives in named follow-up RFCs at their own
> roadmap windows.

---

## 1. Problem Statement

ledgr's evidence machinery is now complete through selection: sealed
snapshots, identity-bearing sweeps with retained return series
(v0.1.9.2), target-risk identity (v0.1.9.3), and walk-forward sessions
with fail-closed scalar selection (v0.1.9.4). What ledgr deliberately
does not yet answer -- and currently disavows in three documentation
surfaces -- is the question every one of those layers funnels toward:

```text
should this candidate be promoted, given how it was found?
```

Two literatures answer it from complementary angles, and the 2026-06-07
horizon entry binds the decision to ship them together:

- **Selection-bias correction (Bailey / Borwein / Lopez de Prado / Zhu
  2014-).** "Is the reported Sharpe corrected for the number of trials
  that produced it?" Deflated Sharpe Ratio (DSR), Probability of
  Backtest Overfitting (PBO) via Combinatorially Symmetric Cross
  Validation (CSCV), minimum track-record length, drawdown-based
  stop-outs (Triple Penance).
- **Robust strategy evaluation (Pardo 2008, Chapter 11).** "Even with
  corrected metrics, does the underlying structure hold up?" Nine
  criteria over trade distribution, profit concentration, parameter-
  region stability, risk, streaks, sample size, and trajectory.

Shipping the structural checklist without bias correction is the exact
warning case of the *Pseudo-Mathematics* paper; shipping bias correction
without structural checks leaves corrected metrics with no canonical way
to threshold them. The bundle is the unit of honesty.

The design stance, bound in the bundling entry and confirmed by the
research input, is **adapter-first**: connect to the R ecosystem's
mature analytics (Peterson's PerformanceAnalytics lineage) rather than
replace them, and implement natively only what is missing, small, or
identity-bound.

---

## 2. Substrate Inventory (what exists today)

| Substrate | Source | Toolkit role |
| --- | --- | --- |
| Retained net return series per sweep candidate (`ledgr_sweep_returns()`, long and wide) | v0.1.9.2 | canonical input for PA/RPESE adapters and PBO panels |
| Saved-sweep artifacts with candidate identity and `risk_chain_hash` | v0.1.9.2 / v0.1.9.3 | diagnostic provenance anchoring |
| Walk-forward sessions: `session_id`, `candidate_key`, per-fold scalar scores, degradation table | v0.1.9.4 | fold-level evidence; multi-regime proxy (Pardo criterion 5) |
| `metric_context_hash` and metric kernel | v0.1.8.2+ | every diagnostic must carry the context that produced its inputs |
| Trades / fills / equity tables on promoted runs | v0.1.x core | Pardo criteria 1, 2, 6, 7, 8, 9 inputs |
| Selection rules with `selection_rule_hash` | v0.1.9.4 | the surface the business objective composes with |

Per the 2026-06-09 Pardo entry's computability map: criteria 1, 2, 6, 7,
8, 9 are computable from promoted-run or retained evidence today;
criterion 4 (stable region) from sweep results; criterion 5
(multi-regime) has a walk-forward proxy; criterion 3 (long-short
balance) is structurally inapplicable until the shorting/leverage
contract RFC lands; criterion 5's full form needs v0.2.x snapshot
lineage.

What does NOT exist: per-period return vectors per walk-forward
candidate/fold. v0.1.9.4 shipped the scalar-score MVP; the substrate
decision was explicitly carried forward to this cycle (Section 5).

---

## 3. Proposed Scope

Two public pillars plus one shared bridge, all consuming the same
canonical retained-return and trade evidence:

1. **Selection-integrity diagnostics**: DSR, PBO/CSCV, minimum
   track-record length, with effective-trial-count input from candidate
   clustering.
2. **Business-objective constructor**: `ledgr_business_objective()`
   composing classed Pardo-criterion steps into a serializable,
   hash-bearing candidate filter.
3. **The external-evidence bridge**: a one-way transformation from
   ledgr's canonical return tibbles to the return-matrix/xts shapes the
   PA-family packages consume.

### 3.1 Adapter targets (Suggests-only, verify maintenance at spec cut)

Per the research input (verify versions at spec-cut time; stated
versions are as of the 2026-06-07 research pass):

- **PerformanceAnalytics** (2.1.0, 2026-04) -- first adapter; pulls the
  v0.1.9.2 synthesis Section 11 F5 obligation forward into this packet.
  Scope: Sharpe/Sortino/Calmar/drawdown families, PSR and
  MinTrackRecord, rolling diagnostics, over bridged return series.
- **RPESE** (1.2.7, 2026-01) -- serial-dependence-aware standard errors
  for performance estimators. Influence-function methods are
  deterministic by construction; bootstrap modes are opt-in and must be
  seeded through ledgr's seed contract if exposed at all.
- **pbo** (1.3.5, quiet since 2022) -- optional adapter ONLY, never a
  foundation: input-shape constraints in Section 5, maintenance is
  stale, and an open correctness issue exists upstream. Native fallback
  feasible from the published CSCV specification.
- **Conditional (promote only if scope demands):** `vrtest`
  (variance-ratio tests) and `changepoint` (deterministic regime
  breaks) -- both deferred unless the synthesis pulls regime awareness
  into criterion-5 scope; the regime-detection research slot remains
  unscheduled.

### 3.2 Native implementations

- **Deflated Sharpe Ratio.** Current CRAN PerformanceAnalytics stops at
  PSR/MinTrackRecord; the existing R DSR lives in quantstrat, which is
  architecturally unusable (transitive dependency FinancialInstrument
  was removed from CRAN 2025-06-12). The deflation step over observed
  SR, trial count, trial-SR variance, skewness, kurtosis, and sample
  length is small. Implement from the primary literature.
- **K-Ratio** (Kestner, via Pardo criterion 9). No central adapter
  surface exists; small native metric over cumulative equity.
- **Triple Penance** drawdown stop-out rule -- PENDING paper-first
  verification (the research explicitly did not source-verify the
  specification; see open question Q1). Scope it only after
  verification; dropping it from v1 is acceptable.
- **PBO/CSCV over ledgr evidence** -- shape depends on the Section 5
  decision.
- **Pardo criteria steps** (the seven computable ones) -- native by
  necessity: criteria 1/2/7 consume ledgr fills directly (adapting
  blotter's tradeStats would import a mutable account/portfolio state
  model that conflicts with ledgr's event-sourced invariants); criterion
  4 (stable parameter region) has no canonical R package; criteria 6/8/9
  are small metric calculations.
- **Candidate clustering** (`ledgr_sweep_cluster()` shape from the
  2026-06-09 entry) -- effective-trial-count input for DSR/PBO
  multiplicity correction. A 240-candidate sweep that clusters into 12
  return-stream groups has ~12 effective trials, not 240. Deterministic
  methods or seeded methods only.

### 3.3 The bridge

One-way export from canonical retained returns to the shapes PA-family
functions accept (xts / matrix keyed by `ts_utc`, one column per
candidate). Constraints bound here:

- sort by `(sweep_id, candidate_id, ts_utc)`; UTC whole-second
  timestamps; pivot only `period_return`;
- the bridge consumes ledgr's already-computed retained returns -- never
  raw fills, never reconstructed positions. This preserves the existing
  "no second canonical metrics path" rule: PA metrics are EXTERNAL
  evidence layered over canonical returns, clearly labeled as carrying
  PA's conventions, never silently merged with ledgr's metric kernel
  outputs (the v0.1.9.2 sweeps vignette already teaches this boundary).

### 3.4 Licensing posture (resolves the bundling entry's bind-at-seed item)

ledgr core is MIT (DESCRIPTION). Therefore:

- all adapters are `Suggests:`-only optional boundaries (the pattern PA
  itself uses for RPESE); no GPL package enters `Imports:`;
- native implementations are written from the primary literature.
  GPL-licensed implementations (quantstrat's `SharpeRatio.deflated`,
  `SharpeRatio.haircut`) are **behavioral cross-check references in
  optional test code at most, never code donors** -- no GPL code is
  copied or translated into MIT ledgr;
- AGPL dependencies (Python `pypbo`) are excluded entirely; reticulate
  comparison routes are out of scope for core.

---

## 4. The Business-Objective Constructor

Indicative shape (illustrative, not contractual; final names follow the
v0.1.9.5 naming rules):

```r
objective <- ledgr_business_objective(
  ledgr_pardo_even_trade_distribution(max_concentration = 0.3),
  ledgr_pardo_even_profit_distribution(max_concentration = 0.4),
  ledgr_pardo_stable_region(min_neighbors = 5),
  ledgr_pardo_acceptable_risk(max_drawdown = 0.20),
  ledgr_pardo_stable_runs(max_streak = 10),
  ledgr_pardo_min_trades(n = 30),
  ledgr_pardo_positive_trajectory(slope_min = 0)
)

eligible <- ledgr_sweep_filter(sweep_results, objective)
```

Design requirements carried from the horizon entries:

- each criterion is a **classed step** consuming candidate evidence
  (metrics, trades, equity, retained returns) and returning a per-
  candidate verdict; steps are serializable with deterministic params;
- the constructor produces a canonical plan with a
  `business_objective_hash` that participates in selection identity
  alongside `selection_rule_hash` -- same plan-json + sha256 recipe as
  cost/risk identity (reuse, do not redesign);
- composition with walk-forward is narrowing-then-selecting: the
  objective filters the eligible pool, the selection rule picks from
  it. Walk-forward session identity must therefore incorporate
  `business_objective_hash` when an objective is supplied (additive,
  nullable -- absent objective hashes as absent, preserving existing
  session ids);
- fail-closed inheritance: a criterion that cannot be computed for a
  candidate (missing trades, no retained returns) marks the candidate
  ineligible with a classed reason, never silently passes it;
- Pardo's vocabulary is binding ("do not coin alternatives" per the
  constraint-family precedent).

Deferred criteria (future obligations, not v1): criterion 3 long-short
balance (gated on the shorting/leverage contract RFC); criterion 5 full
cross-market form (gated on v0.2.x snapshot lineage; the v1 proxy is
performance across walk-forward folds and/or non-overlapping slices of
one snapshot, labeled as a proxy).

---

## 5. The PBO Substrate Decision (must be bound this cycle)

Carried forward from the 2026-06-07 fold-output entry after v0.1.9.4
shipped the scalar-score MVP. `pbo()` requires a T x N panel of
per-period returns and performs CSCV subdivision internally; fold-level
scalar scores cannot be coerced into it (conceptual mismatch, not type
mismatch). The two coherent options, restated with post-v0.1.9.4 state:

- **Option A -- add per-fold per-candidate return retention now.**
  Extend the v0.1.9.2 retention substrate with a `fold_seq` dimension as
  an additive walk-forward retention surface (additive schema migration;
  identity bytes untouched). Preserves the `pbo` adapter route, reduces
  native scope, and enables future signal-decay / per-fold attribution
  work. Storage is bounded (~50K doubles per metric for 10 candidates x
  20 folds x 252 pulses).
- **Option B -- stay scalar; implement PBO/CSCV natively over scores.**
  No retention extension; the CSCV combinatorics move onto ledgr's
  plate, implemented from the published specification.

**Seed recommendation: A-prime.** Take Option A for sweep-level PBO
(the retained-return substrate already exists there -- sweep-level CSCV
over retained candidate returns needs no new retention at all and covers
the primary "did my sweep overfit?" question), and defer the
walk-forward `fold_seq` retention extension to a fast-follow unless the
response stage finds walk-forward-level PBO load-bearing for v1. This
gets the adapter route and the headline diagnostic without reopening
walk-forward persistence in the same packet. The horizon entry's own
recommendation (lean A) is preserved; A-prime narrows where the new
retention lands first. Maintainer decision D1 either way.

---

## 6. Identity And Provenance

Diagnostics are evidence about evidence; they must carry provenance or
they undermine the audit posture they exist to serve:

- every diagnostic result table carries the identity of its inputs:
  `sweep_id` / `session_id`, `candidate_key`s, `metric_context_hash`,
  and (when filtering) `business_objective_hash`;
- adapter-derived numbers are labeled with the adapter package and
  version (PA conventions are not ledgr conventions; the existing
  "label any overlapping headline metric" rule from the sweeps vignette
  becomes a structural field, not prose);
- effective-trial-count inputs record the clustering method, params, and
  seed where applicable;
- no diagnostic mutates stored artifacts. The toolkit is read-only over
  the experiment store (same posture as walk-forward inspection).

Whether diagnostic results themselves persist to the store (a
`validation_results` table) or remain session-objects the user persists
via ordinary artifacts is open question Q5 -- the seed leans
session-objects for v1 (no schema growth until report shapes stabilize).

---

## 7. Explicit Non-Goals (v1)

- purged k-fold CV, embargo, and CPCV (bound deferred by the bundling
  entry: no production-grade R adapter exists, and PBO/CSCV plus native
  walk-forward cover the v0.1.9.x territory; native implementation is
  the recorded route IF a later cycle promotes them);
- HRP and any portfolio-construction functionality (routed to the
  portfolio-optimization scaffolding family);
- benchmark-relative diagnostics (v0.2.x benchmark context owns these;
  the reserved `benchmark` slot in metric_context is not consumed here);
- regime-detection adapters beyond the conditional `changepoint` note;
- automatic promotion gating -- the toolkit reports and filters; it
  never auto-promotes or auto-rejects a candidate without an explicit
  user call. Selection remains a recorded human decision;
- walk-forward synthesis amendments -- the Amendment 2 degradation
  contract stands; anything here is additive;
- Python interop (reticulate comparison harnesses, mlfinlab-successor
  survey) -- comparison appendix material at most.

---

## 8. Pre-CRAN Framing (named per rfc_cycle.md)

No external users; no compatibility cost for new surfaces. Internal
costs that still matter: walk-forward session identity gains a nullable
`business_objective_hash` (additive, existing sessions unaffected);
sweep-filter surfaces must compose with the (possibly renamed, post-
naming-RFC) candidate extraction generic; the docs gates (executing
vignettes, doc-contract locks) extend to a new vignette. If Option A /
A-prime adds retention, the schema migration is additive with the same
discipline as the v0.1.9.2 saved-sweep migration.

---

## 9. Acceptance Criteria Sketch (for the synthesis to refine)

- DSR computable over any saved sweep with >= 2 completed candidates,
  with trial count defaulting to candidate count and overridable by the
  clustering-derived effective count; result carries full input
  identity.
- PBO/CSCV computable over retained sweep returns (route per D1);
  fail-closed when retention is absent with a classed error naming the
  retention opt-in.
- `ledgr_business_objective()` with the seven v1 criteria; serializable
  plan; deterministic hash; fail-closed per-criterion evaluation;
  composes with `ledgr_sweep_filter()` and narrows walk-forward
  eligibility without altering selection-rule semantics.
- PA + RPESE adapters Suggests-only, skipping cleanly (classed
  condition) when not installed; no GPL code in ledgr sources.
- Every diagnostic output labeled with source (native vs adapter+
  version) and input identity.
- A teaching vignette that demonstrates the full loop -- sweep ->
  objective filter -> selection -> walk-forward -> DSR/PBO -- and states
  what the toolkit does NOT prove (the selection-is-not-validation
  lineage extends, it does not end).

---

## 10. Open Questions vs Maintainer Decisions vs Future Obligations

**Maintainer decisions (stage 6 candidates -- product-level choices):**

- **D1.** PBO substrate: Option A, A-prime (seed lean), or B (Section 5).
- **D2.** Business-objective composition rule: all-criteria-must-pass vs
  scored composite vs threshold majority. Seed leans all-pass for v1
  (simplest honest semantics; composites invite threshold-shopping),
  with per-criterion verdicts always visible.
- **D3.** Criterion 6 "acceptable risk" v1 metric: max_drawdown only
  (seed lean) vs drawdown+vol vs configurable metric set.
- **D4.** Does `business_objective_hash` join walk-forward session
  identity in this packet (seed lean: yes, nullable-additive) or wait
  for first integration demand?

**Open questions (spec-cut within the packet):**

- **Q1.** Triple Penance: paper-first verification of the specification
  (Bailey / Lopez de Prado drawdown stop-out literature), then in/out
  scope call. Research explicitly flagged this unverified.
- **Q2.** Stable-region detector for criterion 4: neighborhood-mean
  stability vs local SD vs smoothed-surface approach; grid-topology
  handling for filtered grids (`.filter` holes). No R package to adapt;
  the methodology choice is ledgr's.
- **Q3.** Exact public names -- bound by the naming-consistency rules
  once that synthesis lands (family-first; `pardo_` step prefix vs
  criterion-noun names is a vocabulary call the naming RFC's R7
  one-scheme-per-domain rule governs).
- **Q4.** Clustering method set for the effective-trial count (kmeans
  vs hierarchical; both seedable/deterministic) and whether
  `ledgr_sweep_cluster()` ships inside this packet (seed lean: yes,
  it is the multiplicity input and is already analysis-side-only).
- **Q5.** Diagnostic-result persistence: session objects (seed lean)
  vs a store table.
- **Q6.** Adapter maintenance re-verification at spec cut (PA, RPESE,
  pbo versions and activity; the research data is from 2026-06-07).

**Future obligations (separate cycles, recorded for the horizon entry
at synthesis time):**

- purged k-fold / embargo / CPCV promotion decision (native route
  pre-recorded);
- criterion 3 activation behind the shorting/leverage contract RFC;
- criterion 5 full cross-market form behind v0.2.x snapshot lineage;
- benchmark-relative diagnostics behind the v0.2.x benchmark context;
- regime-detection adapter family if criterion-5 scope demands it;
- Harvey-Liu haircut-Sharpe (same formula-from-paper posture as DSR) if
  user demand surfaces;
- walk-forward `fold_seq` return retention fast-follow if A-prime is
  chosen and walk-forward-level PBO demand materializes.

---

## 11. Suggested Cycle Shape

1. Response stage (different model): verify adapter maintenance claims
   (Q6) against current CRAN; pressure-test A-prime vs A vs B; verify
   the claim that sweep-level CSCV needs no new retention against
   `R/sweep-retention.R`; check the business-objective identity
   composition against `R/walk-forward-identity.R`; source-verify
   Triple Penance (Q1) if feasible at response stage.
2. Seed v2 absorbs findings; maintainer resolves D1-D4.
3. Synthesis binds scope, the adapter/native split table, identity
   semantics, and acceptance criteria; records future obligations.
4. Final review verifies code citations and the worked DSR example.
5. Horizon entry (stage 9) supersedes the 2026-06-07 bundling entry's
   open-question list; rfc/README.md pipeline row moves to the Topic
   Decision Index; the roadmap line for the v0.1.9.x slot re-scopes
   from "selection-integrity diagnostics" to "validation toolkit" at
   packet-open per the bundling entry's closure note.

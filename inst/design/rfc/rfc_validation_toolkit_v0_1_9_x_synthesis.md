# RFC Synthesis: Validation Toolkit

**Status:** Accepted 2026-06-12. Final review passed 2026-06-12
(APPROVED WITH PATCHES; see
`rfc_validation_toolkit_v0_1_9_x_final_review.md`). Binding for the
v0.1.9.6 spec packet.
**Revision note (2026-06-12, final-review patches F1-F3, in-place per
rfc_cycle.md):** (F1) Q4 broadened to cover diagnostics entry-point
naming -- the DSR/PBO/MinTRL/K-Ratio surfaces and the bridge are named
at spec-cut under the accepted naming synthesis (sweep-family lean
recorded); a matching 10.6 naming-compliance criterion added. (F2)
Section 8 binds session-object persistence for v1 outright; the
saved-diagnostics storage table moves to Section 12 future obligations.
(F3) the unretained-returns gate reuses the existing
`ledgr_sweep_returns_unretained` class (`R/sweep-retention.R:188-194`)
instead of minting a duplicate; the two genuinely new condition classes
stand.
**Date:** 2026-06-12
**Author:** Codex (synthesis author)
**Window:** v0.1.9.x, first feature packet after v0.1.9.5 (resolved in
conversation to v0.1.9.6; the roadmap pins the number at acceptance).

Cycle trail:

- Research input: `inst/design/research/Validation-Toolkit.md`
  (non-binding; citation precision varies).
- Seed v1: `rfc_validation_toolkit_v0_1_9_x_seed.md` (Claude,
  2026-06-11; historical).
- Response: `rfc_validation_toolkit_v0_1_9_x_response.md` (Codex,
  2026-06-12; D-A patched during seed-author response review).
- Seed v2: `rfc_validation_toolkit_v0_1_9_x_seed_v2.md` (Claude,
  2026-06-12; primary input).
- Maintainer decisions: D1-D4 resolved inline in seed v2 on 2026-06-12.

This RFC uses "v1" as shorthand for the first implementation of the
validation toolkit; ledgr's roadmap does not have a validation-toolkit v1
milestone. Post-v1 work lives in named follow-up RFCs at their own roadmap
windows.

The accepted API naming synthesis
(`rfc_api_naming_consistency_v0_1_9_5_synthesis.md`) is binding on every
public name in this synthesis.

---

## 1. Bound Scope

The validation toolkit ships as two public pillars plus one shared bridge:

1. **Selection-integrity diagnostics.** Deflated Sharpe Ratio (DSR),
   sweep-level PBO/CSCV over retained completed-candidate return panels,
   minimum track-record length, and effective-trial-count input from
   deterministic candidate clustering.
2. **Business-objective constructor.** `ledgr_business_objective()` composes
   independent classed criterion steps into a serializable, hash-bearing
   candidate filter.
3. **External-evidence bridge.** A one-way transformation from ledgr canonical
   retained returns to return-matrix / xts shapes used by optional analysis
   packages.

The toolkit is read-only over experiment stores. It inspects saved sweeps,
walk-forward sessions, retained return series, and promoted-run evidence. It
does not mutate fold execution, replay, target construction, target risk, cost
application, liquidity, OMS behavior, or broker reconciliation.

### Forbidden List For This Packet

The following are explicit non-scope:

- purged k-fold, embargo, and CPCV;
- HRP and portfolio optimization scaffolding;
- benchmark-relative diagnostics and benchmark-context work;
- regime adapters beyond the conditional note in Section 2;
- automatic promotion, winner-picking, or deployment gating;
- walk-forward synthesis amendments;
- walk-forward per-fold / per-candidate return retention;
- per-fold train-sweep PBO degradation-table columns;
- criterion 3 long-short balance;
- full cross-market criterion 5;
- VaR, ES, and broader tail-risk metric contracts;
- Python / reticulate integration;
- GPL or AGPL code transfer into ledgr core.

The walk-forward per-fold train-sweep PBO idea is recorded separately in
`inst/design/horizon.md` at the 2026-06-12 `[evaluation]` entry. It is a future
obligation, not part of this packet.

---

## 2. Adapter / Native Split

All external package claims are as of the 2026-06-07 research pass until the
spec packet re-verifies them. Packet-open includes a mechanical
adapter-reverification checklist for current package version, activity,
license, input API, and known correctness issues.

| Surface | Binding |
| --- | --- |
| PerformanceAnalytics | First adapter. It extends an existing optional-evidence boundary: PA is already in `Suggests` (`DESCRIPTION:42`), optionality is enforced by tests (`tests/testthat/test-metrics-performanceanalytics.R:66-89`), and contracts state PA parity tests are external evidence only and must not redefine ledgr-owned metrics or become runtime dependencies (`inst/design/contracts.md:628-631`). |
| RPESE | Added to `Suggests` in this packet if spec-cut re-verification passes. Influence-function methods are allowed; bootstrap modes are opt-in only and must use ledgr's seed discipline if exposed. |
| pbo | Optional adapter only, never a foundation. Exact `pbo()` input contract and package status are re-verified at packet-open. A native CSCV fallback from the published specification is recorded if the adapter is stale, unavailable, or API-incompatible. |
| vrtest / changepoint | Conditional only. Do not add unless spec-cut explicitly promotes a bounded regime-related diagnostic. |
| Native DSR | Implement from primary literature. GPL implementations are optional behavioral cross-checks in tests only, not code donors. |
| Native K-Ratio | Implement over ledgr equity evidence as a small metric. |
| Triple Penance | Open at spec-cut pending paper-first verification. Droppable from v1 without affecting the rest of the packet. |
| Business-objective steps | Native, because they consume ledgr evidence and participate in identity. |
| Candidate clustering | Native deterministic hierarchical clustering over return-correlation distance in v1. |

---

## 3. D1: Sweep-Level PBO/CSCV Uses A-prime

D1 is resolved as A-prime: sweep-level PBO/CSCV uses existing v0.1.9.2 retained
completed-candidate return panels. No new sweep-retention surface is required
for v1.

The route is **sweep-level only**. It does not claim to solve walk-forward
per-fold PBO. Every walk-forward fold runs a train-window sweep, so the
sweep-level machinery is the future per-fold building block, but the
`fold_seq` retention extension and degradation-table `train_pbo` column remain
parked in horizon (`inst/design/horizon.md:78-126`).

Maintainer-resolution rationale from seed v2:

- the canonical CSCV input is a trials matrix, which a retained sweep supplies;
- walk-forward already guards itself through per-fold out-of-sample test runs
  and a degradation table;
- the unguarded event is the candidate-space selection inside each sweep;
- per-fold train-sweep PBO is interesting, but depends on a later `fold_seq`
  retention surface.

### 3.1 Panel-Hygiene Gates

The PBO/CSCV adapter has a stricter contract than
`ledgr_sweep_returns_wide()`.

- **First-row NA gate.** Retained `period_return` has structural first-row
  `NA_real_` because there is no previous equity row
  (`R/sweep-retention.R:74-88`). The adapter must drop the first aligned
  timestamp or prove the downstream function's treatment. External packages
  must not decide silently.
- **Complete-matrix gate.** `ledgr_sweep_returns_wide()` can produce ragged
  panels by filling missing cells with `NA_real_`
  (`R/sweep-retention.R:159-180`). PBO/CSCV fails closed unless every selected
  completed candidate has the same timestamp grid after first-row removal.
- **Classed error.** Incomplete panels raise
  `ledgr_validation_pbo_incomplete_panel`, with offending candidate ids and
  missing timestamps represented in the condition data.
- **Completed-universe reporting.** Failed candidates have no retained return
  rows. Every PBO/CSCV result reports the completed candidate universe used and
  the excluded candidate ids.
- **Unretained evidence gate.** Missing retained returns surface the
  EXISTING classed error `ledgr_sweep_returns_unretained`
  (`R/sweep-retention.R:188-194`), which already carries the
  retention-opt-in guidance. No new class is minted for this condition
  (final-review patch F3).
- **External-API gate.** `pbo()`'s expected input API is re-verified before any
  adapter ticket is cut. API mismatch raises
  `ledgr_validation_adapter_contract_mismatch` or routes to native CSCV.

---

## 4. D2: Business Objective Is All-Pass In v1

D2 is resolved as all-pass composition for v1. A candidate is eligible only if
every criterion step passes. Scored-composite objectives are a future additive
variant over the same classed step substrate.

The constructor surface is:

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

The `ledgr_pardo_*` prefix is withdrawn. Pardo's vocabulary binds the criterion
semantics and documentation attribution, not the public prefix. Criterion help
pages cite Pardo 2008 Chapter 11 where applicable.

`ledgr_sweep_filter()` returns objective evidence and eligible rows. It is not
a dplyr replacement, and its help page must say so.

### 4.1 Criterion Steps

V1 criterion steps are independent classed, hashed, serializable objects.
Thresholds are ordinary step parameters and participate in the objective plan
hash.

| Step | Evidence | Binding |
| --- | --- | --- |
| `ledgr_objective_even_trades()` | closed-trade timestamps | Trade distribution over time. |
| `ledgr_objective_even_profit()` | closed-trade `realized_pnl` | Criterion 2 is bound to closed-trade realized-P&L concentration in v1. Period-return profit concentration is future work. |
| `ledgr_objective_stable_region()` | sweep candidate grid and metrics | Stable parameter region. Detector methodology is a spec-cut open question. |
| `ledgr_objective_max_drawdown()` | equity / metric evidence | Sole v1 acceptable-risk criterion; see D3. |
| `ledgr_objective_stable_runs()` | ordered closed-trade outcomes | Winning / losing run stability. |
| `ledgr_objective_min_trades()` | closed-trade count | Minimum statistically meaningful sample size. |
| `ledgr_objective_positive_trajectory()` | equity curve | Positive performance trajectory, K-Ratio compatible. |

Uncomputable evidence fails closed for the candidate with a classed reason; it
never silently passes.

### 4.2 Required Tear-Down Table

The per-candidate x per-criterion verdict table is v1 scope. It is not optional.
It contains, at minimum:

- candidate id / candidate row;
- criterion id;
- measured value;
- threshold / parameter summary;
- pass/fail;
- reason code;
- evidence source;
- `business_objective_hash`;
- input identity (`sweep_id` or `session_id`, metric context hash, cost hash,
  risk hash when available).

The result print method leads with this table so "why did candidate 47 fail?"
is visible without digging through nested attributes.

---

## 5. D3: V1 Risk Criterion Is Max Drawdown Only

D3 is resolved as `ledgr_objective_max_drawdown()` only. This does not pre-empt
the deferred VaR, ES, tail-risk, benchmark-relative, or broader risk-metric
contracts. Those remain separate future surfaces.

---

## 6. D4: Business Objective Enters Session Identity

D4 is resolved: when a business objective participates in walk-forward
selection, it changes walk-forward session identity.

Maintainer rationale from seed v2 is binding: "the objective has to be part of
the id. it changes the whole story." Two stories must not share one session id.
The current walk-forward persistence path deletes and inserts rows by
`session_id` (`R/walk-forward.R:765-780`), so omitting objective identity would
create an overwrite hazard, not merely an audit gap.

### 6.1 Conditional Payload Rule

The identity bytes follow the response-stage binding:

- absent objective means **no** `business_objective_hash` key in the canonical
  session payload;
- supplied objective means the key is present and validated;
- a nullable storage column does not imply an always-present JSON key;
- the no-objective session-id regression fixture must remain byte-identical.

This follows the metric-context precedent: optional metric-context fields are
added to the hash payload only when non-null (`R/metric-context.R:510-523`).
Walk-forward session identity currently hashes canonical JSON over a payload
(`R/walk-forward-identity.R:3-5`) with fixed fields
(`R/walk-forward-identity.R:193-218`), so this rule is identity-critical.

### 6.2 Storage And Reopen

The session row may add nullable storage fields for objective hash / plan JSON.
Reopen and inspection must verify stored objective identity against the
session. No-objective sessions must remain readable and must not gain a
different session id.

---

## 7. Clustering Contract

`ledgr_sweep_cluster()` ships in packet as the effective-trial-count input for
DSR/PBO. V1 binds one deterministic method:

- hierarchical clustering over return-correlation distance;
- no RNG;
- no seed argument;
- no method menu;
- result reports cluster membership and effective independent trial count;
- output carries input identity and method params.

The method menu is a future obligation, not v1 scope.

---

## 8. Diagnostics And Provenance Contracts

Every diagnostic output carries input identity:

- `sweep_id` or `session_id`;
- candidate id / candidate row or `candidate_key`, as applicable;
- `metric_context_hash`;
- `cost_model_hash` when available;
- `risk_chain_hash` when available;
- `business_objective_hash` when an objective participates;
- adapter package and adapter version for adapter-derived numbers;
- native diagnostic version / schema version for ledgr-native numbers.

Adapter-derived diagnostics are labeled as external evidence carrying adapter
conventions. They do not become ledgr's canonical metric kernel and must not
silently redefine owned ledgr metrics.

V1 persistence is session-object persistence, full stop: no new durable
table families in this packet (final-review patch F2; a
saved-diagnostics storage table is a Section 12 future obligation
requiring its own scope decision). The toolkit remains read-only
against existing ledgr execution evidence.

---

## 9. Ticket Shape And Sequencing

This packet lands after v0.1.9.5 and consumes its accepted naming rules from
day one. A spec packet should cut tickets in this order:

1. Packet-open verification: external adapter status/API/license checks,
   Triple Penance source verification, stable-region method decision, result
   print-contract decision.
2. External-evidence bridge and panel hygiene tests over
   `ledgr_sweep_returns()` / `ledgr_sweep_returns_wide()`.
3. PerformanceAnalytics adapter extension over retained returns.
4. RPESE optional adapter, if packet-open verification passes.
5. Optional pbo adapter or native-CSCV fallback, depending on packet-open
   verification.
6. Native DSR / minimum track-record / K-Ratio helpers.
7. `ledgr_sweep_cluster()` deterministic hierarchical helper.
8. `ledgr_business_objective()` and `ledgr_objective_*` criterion steps.
9. Walk-forward identity integration for objective-filtered selection.
10. Documentation, NEWS, examples, condition-class docs, and release gates.

Implementation must not add a second execution engine or mutate fold-core
semantics.

---

## 10. Mechanical Acceptance Criteria

The release gates below are mechanically checkable.

### 10.1 Adapter And Licensing Gates

- `DESCRIPTION` keeps ledgr MIT and keeps external analysis packages out of
  `Imports`.
- PerformanceAnalytics remains `Suggests` only and absent from `NAMESPACE`.
- RPESE is `Suggests` only if added.
- pbo is `Suggests` only if added.
- Tests skip cleanly when optional packages are absent.
- A packet-open checklist records current package version, license, activity,
  API shape, and known issues for PA, RPESE, and pbo.
- No native implementation copies or translates GPL/AGPL source code.

### 10.2 Panel-Hygiene Gates

- A retained completed sweep with equal timestamps produces a numeric matrix
  with one column per completed candidate after dropping `ts_utc` and the
  first structural `NA` row.
- A retained sweep with a ragged selected candidate panel fails with
  `ledgr_validation_pbo_incomplete_panel` and names offending candidates.
- A sweep without retained returns fails with the existing
  `ledgr_sweep_returns_unretained` class (reused per final-review
  patch F3).
- PBO/CSCV output reports completed candidate ids used and excluded ids.
- Adapter API mismatch fails with
  `ledgr_validation_adapter_contract_mismatch` or routes to native CSCV per
  the packet decision.

### 10.3 Business-Objective Gates

- `ledgr_business_objective()` rejects bare functions, arbitrary lists, and
  unknown criterion objects.
- All v1 `ledgr_objective_*` steps have canonical plan JSON and stable hashes.
- Changing any threshold parameter changes `business_objective_hash`.
- `ledgr_sweep_filter()` returns a per-candidate x per-criterion tear-down
  table with the fields listed in Section 4.2.
- Missing criterion evidence marks the candidate failed/ineligible with a
  classed reason; it does not silently pass.
- `ledgr_objective_even_profit()` uses closed-trade realized P&L concentration
  in v1 and documents that choice.
- `ledgr_sweep_filter()` docs state it is not a dplyr replacement.

### 10.4 Identity Gates

- A no-objective walk-forward fixture produces the exact same `session_id`
  before and after the toolkit identity extension.
- An objective-filtered walk-forward session includes
  `business_objective_hash` in identity and storage.
- Two sessions differing only by objective threshold have different
  `session_id` values.
- Reopened objective-filtered sessions verify objective identity.
- No-objective reopened sessions remain readable.
- Persistence does not overwrite objective-distinct sessions that share all
  other identity inputs.

### 10.5 Clustering Gates

- `ledgr_sweep_cluster()` is deterministic across repeated calls with identical
  inputs.
- V1 has no RNG or seed argument.
- Output includes cluster membership, effective independent trial count,
  method name, method params, and input identity.
- Method-menu requests beyond the v1 deterministic method fail loudly.

### 10.6 Documentation Gates

- The validation-toolkit article demonstrates:
  sweep -> retained returns -> objective filter -> selection -> walk-forward
  context -> DSR/PBO interpretation.
- Documentation states what the toolkit does not prove: it does not prove a
  strategy will work live, does not automate promotion, does not replace
  out-of-sample judgment, and does not provide broker/OMS validation.
- NEWS names new adapters and marks them optional.
- Condition classes introduced by this packet are listed in the condition
  reference.
- Export-lock tests cover every new public export, and every new public
  export complies with the accepted API naming synthesis (R1-R7;
  coverage by the lock alone is not compliance -- final-review patch
  F1).

---

## 11. Open Questions Promoted To Spec-Cut

These are packet-open decisions, not new RFC work:

- **Q1. Triple Penance.** Paper-first verification and in/out decision.
- **Q2. Stable-region methodology.** Choose the v1 detector for
  `ledgr_objective_stable_region()` and how it handles `.filter`-holed grids.
- **Q3. Adapter re-verification results.** Resolve PA/RPESE/pbo current status,
  API shape, and any known issues.
- **Q4. Result-object, print, and entry-point naming contracts.** Bind
  exact result classes and print methods under the existing UX
  decisions, AND bind the diagnostics entry-point names -- the
  DSR/PBO-CSCV/minimum-track-record/K-Ratio public surfaces and the
  external-evidence bridge -- under the accepted API naming synthesis
  (final-review patch F1). Lean recorded, not bound: sweep-family
  diagnostics (`ledgr_sweep_pbo()`-shaped), since their evidence
  container is the retained sweep.

---

## 12. Future Obligations Recorded

These require separate later scope decisions:

- walk-forward `fold_seq` per-candidate return retention;
- per-fold train-sweep PBO degradation-table column (`train_pbo` illustrative,
  not bound);
- scored-composite business-objective constructor over the same criterion
  steps;
- clustering method menu beyond the deterministic v1 method;
- period-return profit-concentration variant of criterion 2;
- purged k-fold / embargo / CPCV;
- criterion 3 long-short balance after the shorting/leverage contract;
- full cross-market criterion 5 after snapshot lineage;
- benchmark-relative diagnostics after benchmark context;
- VaR / ES / broader tail-risk metrics after the standard risk-metric
  contract;
- Harvey-Liu haircut if demand warrants it;
- a saved-diagnostics storage table (durable persistence of diagnostic
  summaries; moved here from Section 8 by final-review patch F2 --
  requires its own scope decision, not packet latitude).

---

## 13. Final Review Focus

Claude final review should verify:

- seed v2 and this synthesis are mutually consistent;
- D1-D4 resolutions are preserved without reopening;
- panel-hygiene gates are mechanically checkable;
- conditional-payload identity language preserves no-objective session ids;
- public names comply with the accepted API naming synthesis;
- adapter/native split respects MIT + Suggests-only boundaries;
- future obligations and spec-cut open questions are separated correctly.

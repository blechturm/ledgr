# RFC Response: Validation Toolkit

**Status:** Response-stage review. Recommends seed v2 before synthesis.
**Date:** 2026-06-12
**Author:** Codex (response-stage reviewer)
**Input:** `rfc_validation_toolkit_v0_1_9_x_seed.md`

This response pressure-tests the seed against current source, accepted RFCs,
horizon entries, and the research-input caveats. It does not redesign the
toolkit, edit the seed, or write implementation code.

---

## 1. Verification Results By Focus Question

### 1.1 A-prime: Sweep-Level PBO Substrate

The A-prime claim mostly holds for **sweep-level completed candidates**:
v0.1.9.2 retained returns already provide the candidate return panel needed by
an adapter route. It does not hold unconditionally. Seed v2 should bind the
panel-cleaning and fail-closed gates explicitly.

Evidence:

- Retention is opt-in and currently limited to `returns = "none"` or
  `"completed"` (`R/sweep-retention.R:17-37`), with invalid shapes rejected
  during normalization (`R/sweep-retention.R:39-58`).
- Sweep candidate execution uses the shared fold core, reconstructs the
  candidate summary from that fold output, and only builds retained return
  rows from `summary$equity` when retention is `"completed"`
  (`R/sweep.R:1299-1319`, `R/sweep.R:1351-1356`).
- The retained return row has `candidate_id`, `candidate_row`, `ts_utc`,
  `equity`, and `period_return`; the first `period_return` is explicitly
  `NA_real_` because there is no prior equity row (`R/sweep-retention.R:74-88`).
- The public long accessor returns only `sweep_id`, `candidate_id`, `ts_utc`,
  `equity`, and `period_return`, with UTC timestamp normalization and numeric
  casts (`R/sweep-retention.R:217-223`).
- The wide accessor returns one `ts_utc` column followed by one column per
  candidate id, using `period_return` for `value = "returns"` and filling
  missing candidate/timestamp cells with `NA_real_`
  (`R/sweep-retention.R:159-180`).
- Retained returns fail loudly when not retained
  (`R/sweep-retention.R:182-195`), and explicit candidate requests fail for
  unknown, failed, or missing-retained candidates
  (`R/sweep-retention.R:239-263`).
- Saved sweeps persist candidate rows and retained return rows when present
  (`R/sweep-persistence.R:57-66`), reopen return rows by joining
  `sweep_returns` to `sweep_candidates` (`R/sweep-persistence.R:425-449`),
  and restore reopened sweeps with `sweep_returns` attached
  (`R/sweep-persistence.R:461-523`).

Conclusion: a completed, retained sweep can produce a `ts_utc + N candidate
columns` return table. The adapter can transform that into a `T x N` numeric
matrix by dropping `ts_utc` and dropping or otherwise handling the first
all-`NA` return row.

Caveats that seed v2 should bind:

- **First-row `NA` is not optional.** The adapter must either drop the first
  timestamp or prove the downstream function accepts an all-`NA` first row.
  Do not let external packages silently decide how to treat it.
- **The panel must be complete.** `ledgr_sweep_returns_wide()` currently allows
  ragged panels by filling missing cells with `NA_real_`
  (`R/sweep-retention.R:172-177`). That is a good generic accessor behavior,
  but a PBO/CSCV adapter should fail closed unless every selected completed
  candidate has the same timestamp grid after the first row is removed.
- **Failed candidates are absent by default.** That is acceptable, but the PBO
  adapter must report the completed-candidate universe it actually used rather
  than implying that all grid rows entered the diagnostic.
- **The claim is sweep-level only.** v0.1.9.4 walk-forward shipped scalar
  train-window scores and selected-candidate test runs, not per-fold
  per-candidate return vectors (`inst/design/horizon.md:3291-3297`). The
  A-prime route should not be described as solving walk-forward-level PBO
  unless a later retention surface adds the `fold_seq` dimension.
- **External `pbo()` shape should be re-verified at spec cut.** The local
  horizon record says `pbo` expects a `T x N` panel of raw returns
  (`inst/design/horizon.md:3299-3304`). I did not network-verify the package
  API in this response.

### 1.2 Session Identity And `business_objective_hash`

The seed's "nullable-additive" premise is technically implementable, but only
if seed v2 binds a precise conditional-payload rule. As written, the phrase is
too loose for an identity surface.

Evidence:

- Walk-forward session identity hashes canonical JSON of a payload
  (`R/walk-forward-identity.R:3-5`).
- The current session payload is a fixed named list containing snapshot,
  experiment, grid, fold-list, selection-rule, metric-context, cost, risk,
  seed, opening-state, schema-version, and ledgr-version fields
  (`R/walk-forward-identity.R:193-218`).
- `ledgr_walk_forward_session_id()` hashes exactly that payload
  (`R/walk-forward-identity.R:220-244`).
- The live walk-forward identity builder passes only the current fixed fields
  into `ledgr_walk_forward_session_id()` (`R/walk-forward.R:199-238`).
- The persisted `walk_forward_sessions` table has no
  `business_objective_hash` column today (`R/experiment-store-schema.R:190-205`),
  and the session row writer stores only the current identity fields plus
  `meta_json` (`R/walk-forward.R:727-754`).

Adding `business_objective_hash = NA`, `NULL`, or `""` unconditionally to the
payload would change every future session id for runs without an objective.
That violates the seed's preservation claim.

There is a good precedent for conditional identity fields: metric-context
payloads start from fixed fields and add `benchmark`, `market_factor`, and
`mar` only when non-null (`R/metric-context.R:510-523`). The same pattern can
preserve existing walk-forward session ids: omit the business-objective field
entirely when no objective is supplied; include it only when a concrete
objective participates in selection.

Seed v2 should bind:

- absent objective means no `business_objective_hash` key in the session
  identity payload;
- supplied objective means both `business_objective_hash` and any required
  plan JSON are stored in a schema-compatible place;
- adding a nullable DB column is acceptable, but a nullable storage column does
  not imply an always-present canonical JSON key;
- tests must assert that a no-objective walk-forward session id remains
  byte-identical to the current implementation for a fixed fixture.

### 1.3 Substrate Inventory Accuracy

The Section 2 inventory is directionally accurate, with two clarifications.

| Seed row | Verification |
| --- | --- |
| Retained net return series per sweep candidate | Verified. Long and wide accessors exist over retained `period_return` and `equity` (`R/sweep-retention.R:148-180`). |
| Saved-sweep artifacts with candidate identity and `risk_chain_hash` | Verified. The `sweep_candidates` table stores `candidate_id`, `candidate_row`, metrics, cost identity, metric identity, and risk fields (`R/experiment-store-schema.R:124-155`), and reopen reconstructs `risk_chain_hash` into candidate rows and attributes (`R/sweep-persistence.R:461-523`). |
| Walk-forward sessions and per-fold scalar scores | Verified. `walk_forward_sessions` stores the session identity fields (`R/experiment-store-schema.R:190-205`) and `walk_forward_scores` stores per-fold scalar metric rows with `candidate_key`, hashes, metric name/value, status, and trade count (`R/experiment-store-schema.R:236-258`). No per-period candidate returns exist for all candidates/folds. |
| `metric_context_hash` and metric kernel | Verified. Metric contexts have JSON, hash, and version storage helpers (`R/metric-context.R:405-420`). |
| Trades / fills / equity tables on promoted runs | Verified. Fills include `event_seq`, `ts_utc`, `qty`, `price`, `fee`, `realized_pnl`, and `action` (`R/backtest.R:1115-1126`). Closed trade rows are fill rows where `action == "CLOSE"` (`R/backtest.R:1422-1430`). Equity rows are ordered by `ts_utc` (`R/backtest.R:1102-1112`). |
| Selection rules with `selection_rule_hash` | Verified, but current rules are scalar-only argmax/argmin. Composite, top-N, stability-region, and arbitrary-function selectors are explicitly deferred in the docs (`R/walk-forward-selection.R:3-9`), and the payload/hash covers only `type_id`, schema version, metric, and direction (`R/walk-forward-selection.R:54-65`). |

Pardo criteria 1, 7, and 8 have the required trade evidence: closed trades
carry timestamps, realized P&L, and ordering through `event_seq`/`ts_utc`
(`R/backtest.R:1115-1126`, `R/backtest.R:1242-1250`,
`R/backtest.R:1389-1402`, `R/backtest.R:1422-1430`). Criterion 2 needs a
seed-v2 clarification: "profit distribution" can mean trade-level realized
profit distribution, period-return profit concentration, or both. ledgr has
evidence for both, but the business-objective step must name which evidence it
uses.

### 1.4 Adapter Maintenance Claims

Local evidence verifies the dependency posture, not current external package
status.

- ledgr is MIT licensed (`DESCRIPTION:12`).
- Current `Imports` do not include PerformanceAnalytics, RPESE, or pbo
  (`DESCRIPTION:22-30`).
- Current `Suggests` include PerformanceAnalytics, xts, and zoo, but not RPESE
  or pbo (`DESCRIPTION:33-51`).
- Existing tests enforce that PerformanceAnalytics is optional, absent from
  `Imports`, absent from `NAMESPACE`, and external evidence only
  (`tests/testthat/test-metrics-performanceanalytics.R:66-89`).
- Contracts bind the same rule: optional PerformanceAnalytics parity tests are
  external evidence only and must not redefine ledgr-owned metrics or become a
  runtime dependency (`inst/design/contracts.md:628-631`).

I did not network-verify the seed's PA 2.1.0 / RPESE 1.2.7 / pbo 1.3.5
maintenance claims. Seed v2 should keep the stated-as-of date and convert all
external package version/activity statements into spec-cut re-verification
gates.

### 1.5 Triple Penance

I did not source-verify Triple Penance. The seed's pending-verification posture
is load-isolated: it explicitly says the rule is pending paper-first
verification and may be dropped from v1 (`rfc_validation_toolkit_v0_1_9_x_seed.md:171-174`).
Nothing else in the seed should depend on Triple Penance being included. Seed
v2 should preserve that isolation.

### 1.6 Naming Compliance Under Accepted v0.1.9.5 Rules

The accepted naming synthesis postdates the seed and is now binding. The seed
needs a naming pass before synthesis.

Evidence:

- Public artifact-scoped exports must be family-first
  `ledgr_<family>_<action>`, with only a closed verb-first allowlist
  (`inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md:42-50`).
- Public accessors should avoid `extract_`, `get_`, and `fetch_`
  (`inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md:51-55`).
- Each domain gets one prefix scheme
  (`inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md:60-65`).

Name checks:

- `ledgr_business_objective()` is probably acceptable as a family-root
  constructor if "business objective" is the domain family.
- `ledgr_sweep_filter()` and `ledgr_sweep_cluster()` are family-first sweep
  operations. They are naming-compatible, though the spec should be clear that
  `ledgr_sweep_filter()` returns objective evidence or eligible rows and is
  not a dplyr replacement.
- The proposed `ledgr_pardo_*()` family needs an explicit decision. Pardo's
  vocabulary can bind the criterion semantics, but a person-named public prefix
  is not automatically consistent with the one-prefix-per-domain rule. Seed v2
  should either justify `ledgr_pardo_*` as a named methodology subfamily or
  move the criterion constructors under the business-objective/validation
  family. Do not let this pass as merely illustrative if tickets will cut from
  the seed.
- Any walk-forward integration language should use the accepted
  `ledgr_walk_forward_open()` durable-evidence name and the `ledgr_candidate()`
  generic. The naming synthesis explicitly deletes
  `ledgr_walk_forward_extract_candidate` in favor of `ledgr_candidate()`
  (`inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md:107-108`).

### 1.7 Licensing Posture

The seed's licensing posture is strong enough if carried forward literally:
adapters are optional Suggests-only boundaries, native code is written from
primary literature, GPL implementations are behavioral cross-checks in optional
tests at most, and AGPL routes are excluded.

The local package metadata supports the MIT/Suggests posture
(`DESCRIPTION:12`, `DESCRIPTION:22-51`). Seed v2 should avoid language such as
"formula donor" for GPL implementations; use "primary literature source,
GPL implementation as optional behavioral cross-check only" to keep the
license boundary mechanical.

### 1.8 Scope-Cut Coherence

The seed mostly respects the bound deferrals:

- Purged k-fold, embargo, and CPCV stay deferred in the horizon entry
  (`inst/design/horizon.md:3136-3144`).
- HRP is routed away from this toolkit (`inst/design/horizon.md:3136-3144`).
- Regime detection remains conditional and unscheduled in the research index
  (`inst/design/research/README.md:47-54`).

The one scope edge is clustering. The horizon entry says clustering is
analysis-side-only and naturally informs effective-trial-count estimates
(`inst/design/horizon.md:436-453`), but it also says no public API is bound and
method selection is a future design choice (`inst/design/horizon.md:481-487`).
Seed v2 can still include clustering in the bundled packet, but it should not
silently ship a broad method menu. Either bind one deterministic v1 method and
defer method selection, or route clustering as a narrow helper whose method
surface is deliberately minimal.

### 1.9 D1-D4 Readiness

The four maintainer decisions are close, but D1 and D4 need sharper evidence.

- **D1 - PBO substrate.** Decidable after the A-prime caveats are added. The
  clean wording is: sweep-level PBO can use retained completed-candidate return
  panels with strict matrix cleanup; walk-forward-level PBO remains a future
  `fold_seq` retention decision.
- **D2 - business-objective composition.** Fairly scoped and independent. The
  current selection-rule surface is scalar-only, so all-pass filtering before
  scalar selection is the simplest v1 shape.
- **D3 - acceptable-risk criterion.** Independent. It should not pre-empt
  benchmark context, liquidity, or OMS surfaces.
- **D4 - session identity.** Technically possible but fragile. It should bind
  "conditional payload field omitted when absent" before maintainer acceptance.

---

## 2. Findings The Seed Missed

### M1. The PBO Adapter Needs A Complete-Matrix Gate

The seed says the retained-return substrate provides the panel. It does, but
the adapter must define a stricter contract than the generic wide accessor:
drop or explicitly handle the first all-`NA` row, require no interior `NA`
after selected candidates are aligned, and report the completed-candidate set.

### M2. `business_objective_hash` Must Be Omitted, Not Null, When Absent

The current session payload is fixed and canonicalized. A nullable DB column is
not enough. The identity payload must omit the key entirely when no objective is
supplied, with a regression fixture proving old no-objective session ids remain
stable.

### M3. Criterion 2 Needs An Evidence Choice

The seed says Pardo's even profit distribution is computable, which is true.
It does not specify whether the v1 step uses closed-trade realized P&L,
per-period return/profit concentration, or both. Since ledgr exposes both
closed trades and retained returns, the ambiguity is avoidable and should be
resolved in seed v2.

### M4. The `ledgr_pardo_*` Prefix Is A Naming Decision

The accepted naming synthesis makes one-prefix-per-domain binding. Pardo's
vocabulary should bind criterion meaning, but not automatically the public
function prefix. This needs an explicit seed-v2 decision or a renamed
illustrative surface.

### M5. Adapter Version Claims Need Spec-Cut Reverification Gates

The research directory explicitly warns that citation precision varies and
primary sources must be checked before binding claims
(`inst/design/research/README.md:15-27`). Seed v2 should turn PA/RPESE/pbo
version, activity, and known-issue claims into a mechanical spec-cut gate.

### M6. Clustering Scope Needs A Narrow V1 Method Binding

The seed leans toward shipping `ledgr_sweep_cluster()` inside the packet. The
horizon entry supports clustering as an effective-trial-count input but does
not bind a public API or method family. Seed v2 should choose a minimal
deterministic v1 method or explicitly defer the helper while preserving the
diagnostic input slot.

---

## 3. Disagreements With Seed Positions

### D-A. A-prime Should Not Be Presented As Unqualified

**[Patched 2026-06-12 during seed-author response review: the original
wording implied the seed failed to scope A-prime to sweep level. The
seed did scope it (Section 5 explicitly defers walk-forward `fold_seq`
retention to a fast-follow); the genuine gap is the panel-hygiene
contract.]**

I agree with A-prime for retained sweep results as the seed scopes it
(sweep-level now, walk-forward `fold_seq` retention deferred). The gap
is that "needs no new retention at all" is stated without the
panel-hygiene contract: the complete-matrix gate, first-row-NA
handling, and completed-candidate-universe reporting above. Seed v2
should attach those gates to the A-prime statement rather than leaving
them to the adapter ticket.

### D-B. `ledgr_pardo_*` Is Not Automatically Naming-Compliant

The seed's "Pardo's vocabulary is binding" sentence is correct for the
criterion taxonomy. It does not settle the public prefix. Under R7, the
question is whether "Pardo" is a public methodology family or whether the
family is "business objective" / "validation". Seed v2 should not leave this
to tickets.

### D-C. D4 Needs Identity Bytes, Not Just A Concept

"Nullable-additive" is the right intent but not enough. The implementation
choice is identity-bearing: omit the hash field when absent, include it when
present. A null-valued canonical JSON key would change no-objective sessions.

### D-D. Clustering Is Ready As An Analysis Concept, Not As A Broad API

The analysis-side clustering idea is coherent and low-risk, but a v1 packet
should not inherit the horizon's illustrative `method = "kmeans"` sketch as a
public method menu. The method surface needs a narrow binding or deferral.

---

## 4. Items Confirmed As-Is

- The bundle of selection-integrity diagnostics plus business-objective
  constructor is coherent and matches the bound horizon rationale
  (`inst/design/horizon.md:3073-3098`, `inst/design/horizon.md:3146-3156`).
- Adapter-first is the right posture, with ledgr owning deterministic evidence
  and identity, and external packages used as optional analysis surfaces.
- Purged k-fold, embargo, CPCV, HRP, benchmark context, liquidity/capacity,
  and OMS behavior should stay out of this packet.
- The current evidence substrate is sufficient for the seven "computable now"
  Pardo criteria listed in the business-objective horizon entry, subject to the
  criterion-2 clarification (`inst/design/horizon.md:735-762`).
- Triple Penance remains correctly isolated behind source verification.
- The MIT/Suggests/no-GPL-code-donor boundary is the right licensing stance.

---

## 5. Recommendation

Revise to seed v2 before synthesis.

Required seed-v2 changes:

1. Bind A-prime as sweep-level only and add complete-matrix, first-row-NA,
   completed-candidate, and external-API re-verification gates.
2. Bind `business_objective_hash` session identity as a conditional payload
   field that is omitted when absent, with a no-objective session-id regression
   gate.
3. Resolve or explicitly escalate the public prefix question for
   `ledgr_pardo_*` under the accepted v0.1.9.5 naming synthesis.
4. Clarify Pardo criterion 2's evidence source.
5. Turn PA/RPESE/pbo maintenance and version claims into spec-cut
   re-verification criteria.
6. Narrow the clustering helper surface or defer the helper while keeping the
   effective-trial-count input slot.

After those patches, the design should be ready for synthesis. I do not see a
reason to reopen the bundle, adapter-first posture, or the major deferrals.

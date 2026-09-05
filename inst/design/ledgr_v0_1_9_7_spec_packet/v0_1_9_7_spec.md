# ledgr v0.1.9.7 Spec

**Status:** Batch 9 complete after Claude review; Batch 10 pending.
**Target branch:** `v0.1.9.7`.
**Scope:** The full business-objective eligibility layer plus validation polish after
v0.1.9.6: a serializable, hashed business-objective criterion chain
(`ledgr_business_objective()`) carrying all seven Pardo criteria plus diagnostic-threshold
criteria, an evidence-only all-candidates sweep eligibility filter
(`ledgr_sweep_filter()`), a sweep closed-trade-evidence retention extension that feeds the
trade-distribution criteria, a strict-lattice `stable_region` detector resolved by an
in-packet spike, a conditional native K-Ratio diagnostic, an intraday metric-context
honesty guardrail (audit M-1), a worked-example teaching and doc-contract refit of the
already-shipped Selection Integrity article, and the v0.1.9.6 release-surface /
deferral-ledger closeout.
**Maintainer amendment:** Per the 2026-06-26 amendment to the validation-toolkit synthesis
(Section 14), v0.1.9.7 is the separate amendment the v0.1.9.6 spec section 2.6 anticipated.
It promotes the full v1 business-objective eligibility layer (all seven D2 criteria,
evidence-only) and admits diagnostic-threshold criteria. It defers only D4
objective-filtered walk-forward identity participation, the broader robustness-criterion
family beyond the strict-lattice detector, scored composition, and a public
criterion-extension contract, to a later business-objective completion arc (2026-06-26
horizon entry).
**Non-scope:** no automatic promotion or winner selection; no objective-filtered
walk-forward identity and no `business_objective_hash` participation in walk-forward session
identity; no broader (non-lattice) robustness criteria; no scored/weighted composition; no
public third-party criterion-extension contract; no Triple Penance; no walk-forward
short-window cadence rework (audit M-2); no intraday worked example yet (audit L-1); no
first-class intraday runtime; no new selection-integrity article (the surface already
shipped in v0.1.9.6); no talib indicator adapter (v0.1.9.8); no crypto-readiness spike; no
target-helper Pass 2; no purged k-fold / embargo / CPCV; no portfolio optimization; no
point-in-time data tables; no paper/live, OMS, or liquidity/capacity work.

---

## 0. Source Inputs

Binding artifacts:

- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md` (accepted 2026-06-12;
  maintainer-amended 2026-06-14 and 2026-06-26) -- the business-objective layer contract
  (D2/Section 4: all-pass composition, classed/hashed/serializable criterion steps, the
  seven criterion steps, the per-candidate x per-criterion tear-down table, fail-closed),
  the D4 session-identity rule, and the 2026-06-26 promotion/deferral amendment (Section
  14).
- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` -- the section 2.6
  business-objective contract and the conditional-diagnostic terms MinTRL/DSR/K-Ratio
  shipped under (section 2.4).
- `inst/design/research/Stable-Parameter-Region-Detection.md` -- deep-research input for
  the `stable_region` detector spike (non-binding design-space input; the spike's accepted
  design is binding).
- `inst/design/audits/v0_1_9_6_intraday_readiness_audit.md` -- finding M-1, and the audit's
  deferral of M-2 / L-1.
- `inst/design/vignette_styleguide.md` -- the Methodological Diagnostics policy the craft
  clause extends.
- `inst/design/contracts.md` -- result-table, identity-field, retained-panel, and
  evidence-only diagnostics contracts; the closed-trade retention extension updates the
  sweep retention/identity surface recorded here.
- `inst/design/ledgr_roadmap.md` -- the v0.1.9.6 row to flip Active -> Done.
- `inst/design/horizon.md` -- the 2026-06-26 deferral-ledger entry to keep in sync,
  plus the 2026-09-04 `[docs]` all-vignette review entry that feeds only the LDG-2671
  Selection Integrity rebuild in this packet.

Planning and contract inputs:

- `inst/design/rfc/README.md` validation-toolkit decision-index row;
- `inst/design/methodology_references.md` (Pardo 2008 for the criterion semantics; the
  K-Ratio canonical-variant citation is pinned here if K-Ratio ships);
- the v0.1.9.2 sweep-retention storage discipline
  (`inst/design/ledgr_v0_1_9_2_spec_packet/sweep_retention_storage_smoke.md`), which the
  closed-trade retention extension follows;
- `inst/design/release_ci_playbook.md`;
- v0.1.9.1-v0.1.9.6 packet records.

External facts about any K-Ratio reference implementation must be re-verified at
packet-open / ticket cut. Any current manual or CRAN lookup is input evidence, not
permanent authority.

---

## 1. Thesis

v0.1.9.6 shipped the validation substrate and the first evidence-only selection-integrity
diagnostics -- the canonical returns view, retained-return panels, native PBO/CSCV, MinTRL,
and DSR with deterministic effective-trial clustering -- and an audit-only
intraday-readiness review. It deliberately stopped before letting any objective compose
those diagnostics, and before integrating an objective into walk-forward identity.

v0.1.9.7 adds the layer that lets a user express and check a business objective over a
sweep, and stops one deliberate step short of selection. The objective produces eligibility
evidence over every candidate; it never selects, promotes, ranks-to-pick, or changes any
candidate, sweep, or walk-forward identity. The full seven-criterion Pardo set ships --
including the closed-trade-distribution criteria, fed by a sweep closed-trade-evidence
retention extension, and the `stable_region` criterion, fed by a strict-lattice detector
resolved by an in-packet spike -- alongside diagnostic-threshold criteria that thread the
v0.1.9.6 diagnostics into eligibility evidence.

```text
Can ledgr let a user compose proven criteria into a reproducible business-objective
eligibility check over a sweep, with full criterion coverage, without that check ever
becoming selection, promotion, or a change to walk-forward identity?
```

The packet also closes three debts behind the same release: a conditional native K-Ratio
diagnostic (a trajectory-consistency measure compatible with, but not required by,
`positive_trajectory`), the intraday metric-context honesty guardrail the 9.6 audit flagged as M-1,
and a worked-example teaching refit of the shipped Selection Integrity article.

---

## 2. Product Shape

### 2.1 Business-Objective Criterion Chain

Add a serializable objective constructor that composes proven criteria:

```r
obj <- ledgr_business_objective(
  ledgr_objective_max_drawdown(0.20),
  ledgr_objective_min_trades(30),
  ledgr_objective_positive_trajectory(slope_min = 0)
)
```

(Criterion constructor names follow the synthesis; the `ledgr_pardo_*` prefix is withdrawn
per synthesis Section 4 -- Pardo binds the semantics and documentation attribution, not the
public prefix. Final names are bound at ticket cut under the v0.1.9.5 naming synthesis.)

Binding:

- v1 composition is all-pass: a candidate is eligible only if every criterion passes
  (logical AND). No weighting, scoring, or ranking exists in v1; scored composition is a
  deferred future additive.
- every criterion is an instance of a single **internal criterion-step contract**: a
  classed object with a stable criterion id, serializable parameters, a declared evidence
  key (the named ledgr-owned evidence it consumes), and a pure `evaluate` producing one
  finite value plus pass/fail and a reason per candidate. The constructor, filter, hash,
  and tear-down table operate generically over that contract and never touch a criterion's
  internals. The contract stays internal in v1; a public third-party extension contract is
  deferred (Section 8).
- the objective is serializable, round-trips, and carries a deterministic
  `business_objective_hash` over its ordered, classed criterion steps.
- criteria do not recompute strategy evidence from raw fills or positions; they threshold
  over already-computed ledgr-owned evidence.
- each criterion has a sensible default threshold where one is meaningful, always
  overridable; nothing is forced and no objective is constructed by default.
- missing or non-finite evidence for a referenced criterion fails closed with a classed
  condition, never a silent pass or fail.

The v1 criterion set is the full synthesis Section 4.1 set, each over its named evidence:

| Criterion | Evidence | Source in v0.1.9.7 |
| --- | --- | --- |
| `max_drawdown` | retained `max_drawdown` metric | summary metrics |
| `min_trades` | retained `n_trades` metric | summary metrics |
| `positive_trajectory` | retained equity curve | deterministic slope test over retained returns (no K-Ratio dependency) |
| `stable_region` | candidate parameter grid + per-candidate metric | strict-lattice detector (2.4) |
| `even_trades` | closed-trade timestamps | closed-trade retention (2.3) |
| `even_profit` | per-trade `realized_pnl` | closed-trade retention (2.3) |
| `stable_runs` | ordered win/loss outcomes | closed-trade retention (2.3) |

`positive_trajectory` is a self-contained deterministic slope test over the retained equity
curve (regress cumulative log-equity on the zero-based retained-row index after structural
first-row handling; require the slope to meet `slope_min`, measured in log-equity units per
retained observation). Non-positive or non-finite equity fails closed. It does not depend on
the conditional K-Ratio diagnostic. K-Ratio (2.5) is a compatible refinement from the same
regression family, not a prerequisite.

In addition, v1 admits **diagnostic-threshold criteria**: a criterion that thresholds a
named v0.1.9.6 diagnostic output column (for example a DSR or MinTRL value). Such a
criterion is an evidence threshold only -- it records the source diagnostic's metadata and
hash, recomputes nothing, and carries no implication that the diagnostic proves
profitability. This extends, not narrows, the D2 surface.

### 2.2 Sweep Eligibility Filter (All-Candidates, Evidence-Only)

Evaluate an objective against one sweep's retained evidence:

```r
ledgr_sweep_filter(sweep_results, obj)
```

Binding:

- consumes completed-candidate evidence from the retained sweep surface (summary metrics,
  retained returns/equity, retained closed trades when present, and v0.1.9.6 diagnostic
  outputs). It reuses the panel-hygiene contract and fails closed on missing retained
  evidence exactly as the 9.6 diagnostics do.
- returns a classed `ledgr_sweep_filter_result` evidence table that preserves **all
  evaluated candidates and all criterion rows, including failures** -- per-candidate x
  per-criterion rows carrying the criterion id, observed value, threshold, pass/fail, and a
  reason, plus a candidate-level `eligible` (all-pass) flag. It never drops ineligible
  candidates.
- `tibble::as_tibble()` and `print()` default to the full tear-down table. Eligible-only
  extraction, if offered, is an explicit separate call and is never the default surface.
- records `business_objective_hash`, objective metadata, and `sweep_id` provenance on the
  result.
- the result is evidence only (Section 3). `ledgr_sweep_filter_result` carries a long
  per-candidate x per-criterion tear-down shape that does not satisfy the candidate-row
  contract, and defines a **rejecting** `ledgr_candidate.ledgr_sweep_filter_result()`
  method that errors with a classed condition -- a missing method alone is unsafe because
  `ledgr_candidate.default()` dispatches on any sweep-like tibble that carries the candidate
  columns. It returns no chosen candidate, reorders nothing into a pick, writes no promotion
  record, mutates no candidate or sweep identity, and is rejected by `ledgr_candidate()`,
  `ledgr_promote()`, and walk-forward selection. Tests assert each rejection explicitly.

### 2.3 Closed-Trade Retention Extension

Extend sweep retention to persist per-candidate closed-trade evidence so the
trade-distribution criteria can run over saved and reopened sweeps without re-execution.

Binding:

- add an opt-in retention level (extending `ledgr_sweep_retention()`) that persists, per
  completed candidate, a closed-trade table derived from the existing
  `ledgr_closed_trade_rows()` / `ledgr_results(bt, what = "trades")` surface. Minimal
  retained columns: `candidate_row`, `trade_seq`, `close_ts_utc`, `realized_pnl`,
  `win_loss`. `trade_seq` is an explicit deterministic order key (a per-candidate
  close-event sequence): whole-second timestamps allow multiple trades to close on the same
  pulse, so `stable_runs` orders by `trade_seq`, not by `close_ts_utc` alone. Default
  retention is unchanged; trade retention is never always-on.
- bind the saved-sweep persistence gates explicitly, not only the retention policy version:
  the parent and artifact schema versions and the per-table validators in
  `R/sweep-persistence-schema.R` gain a retained-trades table and its validator, and the
  storage smoke gate (per the v0.1.9.2 discipline) records a ratio threshold for it. The
  extension is additive; reopened pre-extension sweeps remain valid and report trade
  evidence as unretained, reusing the fail-closed path.
- this touches the sealed sweep-artifact surface: a no-trade-retention regression fixture
  must remain byte-identical, and retained trade evidence participates in the saved-sweep
  artifact exactly as retained returns do. No run, fold, or session identity changes for
  sweeps that do not opt in.
- `even_trades`, `even_profit`, and `stable_runs` consume this evidence and fail closed
  when a candidate's trade evidence was not retained.

### 2.4 `stable_region` Detector Spike

`stable_region` resolves the detector methodology the synthesis Section 4.1 left as a
spec-cut open question, via an in-packet spike (the v0.1.9.6 PBO-spike precedent), not a new
RFC.

Binding:

- the spike produces a reviewed `stable_region` design note citing
  `inst/design/research/Stable-Parameter-Region-Detection.md` and recording: the neighbor
  rule, the good-neighbor threshold, the stability statistic, the fail-closed rule, and a
  known-direction fixture (a broad plateau passes, an isolated spike fails, a non-factorial
  or unordered grid errors).
- the recommended design is a strict, deterministic lattice detector consuming only the
  candidate parameter grid plus one per-candidate metric: neighbors are Manhattan-distance-1
  in level-index space (which removes all normalization/distance choices); a good neighbor
  is one whose direction-normalized score is within a data-derived band `tau` (the median
  absolute score difference across adjacent lattice pairs); a candidate is eligible when its
  count of good neighbors meets `min_neighbors`; support ratio and local smoothness range
  are recorded as audit-only diagnostics.
- v1 is strict ordered-only. It fails closed (a classed error, not a guess) on grids whose
  neighborhood is undefined: non-factorial / sparse / duplicate / collapsed grids, and any
  axis that is not numeric, integer, date-like, logical, or an explicitly `ordered` factor.
  A plain (nominal) `factor` fails closed despite R assigning it a level order, because that
  order is not meaningful for adjacency; the caller opts in by passing an `ordered` factor.
  Hold-fixed handling of nominal axes and non-lattice topologies are deferred to the broader
  robustness family (Section 8), not v1.
- the detector is documented as ledgr's interpretive operationalization of Pardo's
  qualitative plateau idea (Pardo 2008 Ch. 10-11), not a transcription of a Pardo formula;
  the `tau` band is ledgr's choice.
- gate: if the spike passes and the maintainer accepts the design, `stable_region` ships in
  v0.1.9.7. If verification does not hold, `stable_region` defers cleanly with the spike
  note as binding input, without affecting the other six criteria.

### 2.5 K-Ratio Diagnostic (Conditional)

Add a native K-Ratio diagnostic over a retained return / equity series, on the same
conditional terms MinTRL and DSR shipped under in v0.1.9.6.

Binding:

- one named published K-Ratio variant is pinned with a citation in
  `methodology_references.md` (not merely "K-Ratio"); other variants are explicitly
  non-scope. The implementation matches it to a reference value, or to a known-direction
  fixture where no clean reference exists (smoothly trending equity scores high; noisy flat
  equity scores low).
- it ships only if that verification and the article scope stay small; otherwise it defers
  cleanly, like Triple Penance, without affecting the rest of the packet.
- it defines accepted input evidence, output shape and class, input identity fields, and
  failure classes, per the diagnostic contract.
- K-Ratio is independent of the `positive_trajectory` criterion (a self-contained slope
  test, 2.1): they share the same regression family, but K-Ratio shipping is not a
  prerequisite for `positive_trajectory` or for the objective layer.

### 2.6 Intraday Metric-Context Guardrail (Audit M-1)

Close the honesty gap the v0.1.9.6 intraday-readiness audit recorded as M-1: daily
metric-context defaults can silently annualize intraday-cadence returns, misstating headline
metrics across `metrics`, sweep metrics, and walk-forward degradation reading.

Binding:

- detect the observed bar cadence of the evidence a metric context is applied to.
- when a daily-calendar / daily-annualization default meets sub-daily observed cadence, emit
  a classed condition instead of silently proceeding.
- the guardrail is identity-neutral: it does not change metric values or recipes, does not
  change run/session identity, and implements no intraday runtime behavior.
- default disposition is a classed warning; whether any specific surface should hard-fail is
  an open ticket-cut question (Section 7). M-2 and L-1 stay deferred per the audit's own
  ordering.

### 2.7 Selection Integrity Teaching And Doc-Contract Rebuild

v0.1.9.6 shipped the Selection Integrity article. A first refit (LDG-2662) added the
worked-example craft clause and relaxed the brittle doc-contract headers, but the article
still failed the maintainer's bar: it hid a fake-sweep helper, opened sections
function-name-first, and carried plots that did not explain the method. The article is
rebuilt from scratch on the Section 2.9 return-panel entry point.

The 2026-09-04 all-vignette review of `3518b188` adds one more constraint for
this section: consume only the Selection Integrity-specific findings here
(visible return-panel input, concept-first flow, stronger references and
convention attribution, executed contrasts, anti-overclaim guards). The rest of
that review is parked in `inst/design/horizon.md` for a later documentation
freshness pass and must not widen this packet.

Binding:

- the worked-example craft clause is added to the Methodological Diagnostics styleguide rule
  (a recognizable executed scenario plus a calibrating contrast, not a fixture built to
  produce a number), and the doc-contract test drops its rigid sub-section-header assertions
  while keeping the non-vacuous content and anti-overclaim guards (no profitability claim, no
  promotion, no candidate selection or ranking). Done under LDG-2662.
- the article is rebuilt (LDG-2671): no hidden sweep-construction boilerplate; the input is a
  visible candidate-return table via the Section 2.9 entry point. Each section motivates the
  concept in plain language before any mechanism or function name, and makes explicit what
  data goes into each diagnostic and why.
- the calibrating contrasts (rotating vs stable, short vs longer sample, clustered vs
  independent) are kept, rebuilt on the clean API; a plot is added only where it genuinely
  reveals the geometry.
- no diagnostic behavior or identity change; the vignette renders deterministically and the
  doc-contract test stays non-vacuous and green.

### 2.8 Release Surfaces And Deferral-Ledger Closeout

Binding:

- bump `DESCRIPTION` to `0.1.9.7`.
- flip the v0.1.9.6 roadmap row from Active to Done with its shipped scope, and refresh the
  horizon "Current packet note".
- keep the 2026-06-26 horizon deferral entry in sync with this spec's Section 8, and record
  this packet's own deferrals with concrete reasons.
- update NEWS, the pkgdown reference index, and the design index for the new surfaces.
- the release gate runs full tests and package check before tag.

### 2.9 Public Return-Panel Entry Point

The shipped selection-integrity diagnostics accept only a `ledgr_sweep_results` object, so a
user with their own candidate returns -- or a vignette teaching the methods -- must
hand-build a sweep object. That boilerplate is a UX gap this section closes.

Binding:

- add a public return-panel constructor (working name `ledgr_return_panel()`, bound at ticket
  cut under the v0.1.9.5 naming synthesis) over a candidate-return matrix or a tidy long
  return tibble.
- the diagnostics accept the panel in addition to a sweep, over one shared internal panel
  contract; the existing sweep-input path is unchanged. Per the 2026-06-28 synthesis
  amendment (Section 15) they are renamed off the `sweep_` prefix to
  `ledgr_{pbo,dsr,min_track_record,effective_trials}` (was
  `ledgr_sweep_{pbo,dsr,min_track_record,cluster}`); `ledgr_sweep_returns_panel()` stays a
  sweep accessor.
- the surface is identity-neutral: for the same underlying panel, a diagnostic returns
  identical output whether the panel came from a sweep or the constructor.
- malformed panels fail closed reusing the existing panel-hygiene conditions.

This is the foundation the Section 2.7 vignette rebuild is written on: the teaching input
becomes a visible return table, not hidden sweep-construction boilerplate. The full
maintainer-approved design (panel object, source-neutral `panel_hash`, input contract, and
the rename) is bound in
`inst/design/ledgr_v0_1_9_7_spec_packet/return_panel_entry_point_design.md`.

---

## 3. Identity And Eligibility Boundary

This is the load-bearing gate for the packet. The business-objective layer is the first
surface that could quietly become selection. It must not.

Hard invariants:

- `ledgr_sweep_filter()` returns **all-candidate** eligibility evidence. It never returns a
  single chosen candidate, never reorders candidates into a pick, never drops ineligible
  candidates from the default surface, and is not `ledgr_candidate()` by another name.
- `ledgr_sweep_filter_result` defines a **rejecting**
  `ledgr_candidate.ledgr_sweep_filter_result()` method (a missing method alone is unsafe:
  `ledgr_candidate.default()` dispatches on any sweep-like tibble with the candidate
  columns), and its long tear-down shape does not satisfy the candidate-row contract;
  `ledgr_promote()` and walk-forward selection also reject it. Tests assert all three
  rejections.
- constructing an objective or running a filter writes no promotion record, run, or
  persisted artifact.
- `business_objective_hash` is recorded on the filter result as provenance only. It does not
  participate in run, sweep, session, or walk-forward identity in this packet. That
  participation is the deferred D4 objective-filtered walk-forward identity work.
- candidate identity, sweep identity, and walk-forward session identity are byte-for-byte
  unchanged by the presence or absence of an objective or a filter. Sweeps that do not opt
  into closed-trade retention have byte-identical artifacts to today.
- the objective composes thresholds over already-computed, ledgr-owned evidence. It
  introduces no new metric recipe and recomputes no strategy evidence.

Spec and ticket review must be able to point at each invariant and find a mechanical test.

---

## 4. Documentation And Teachability Gate

- the worked-example craft clause lands in `inst/design/vignette_styleguide.md` with, or
  before, the Selection Integrity article refit.
- after the doc-contract header relaxation, `test-documentation-contracts.R` still asserts
  non-vacuous content and the anti-overclaim guards; the relaxation removes brittleness, not
  coverage.
- the PBO/MinTRL/DSR worked examples execute and their pinned numbers match the rendered
  output.
- new public surfaces (`ledgr_business_objective()`, the `ledgr_objective_*` criteria,
  `ledgr_sweep_filter()`, the retention level, and K-Ratio if it ships) carry reference
  pages; criterion help pages cite Pardo 2008 Chapter 11 for semantics where applicable.

---

## 5. Indicative Implementation Sequence

Tickets will bind final batch shape later. The spec-level order is:

1. Packet alignment; the 2026-06-26 maintainer-amendment record; K-Ratio reference
   re-verification.
2. `stable_region` detector spike (design note + known-direction fixture + maintainer
   acceptance gate).
3. Closed-trade retention extension (opt-in level, storage gate, schema bump, reopened-sweep
   compat).
4. Methodological-diagnostics craft clause + doc-contract relaxation + Selection Integrity
   worked-example refit (independent of the feature work; can run in parallel).
5. Intraday metric-context guardrail (M-1).
6. K-Ratio diagnostic if reference verification passes; otherwise record a clean deferral.
7. Business-objective criterion chain: the internal step contract, all seven criteria over
   their evidence, and the diagnostic-threshold criteria; classed/hashed/serializable plan.
8. Sweep eligibility filter: all-candidates tear-down table, fail-closed, provenance, the
   anti-selection invariants.
9. Release surfaces, NEWS, reference index, deferral-ledger closeout, and the release gate.

The sequence puts the spike and the retention substrate before the criteria that depend on
them, the objective substrate before the filter consumer, and keeps every objective/filter
surface evidence-only -- identity integration stays out of the packet entirely.

---

## 6. Mechanical Gates

### 6.1 Business Objective

- v1 composition is all-pass; no scoring, ranking, or weighting exists.
- every criterion implements the single internal step contract (stable id, serializable
  params, declared evidence key, pure evaluate); composition/filter/hash/table touch only
  that contract.
- criteria are classed and hashed; the objective serializes and round-trips.
- `business_objective_hash` is deterministic over the ordered criterion steps.
- missing or non-finite criterion evidence fails closed with a classed condition.
- constructing an objective changes no run / sweep / session / walk-forward identity.

### 6.2 Sweep Filter

- returns a classed tear-down table covering all evaluated candidates and all criterion rows
  including failures, plus a candidate-level `eligible` flag.
- `as_tibble()` and `print()` default to the full table; eligible-only extraction is
  explicit and never the default.
- reuses retained-panel hygiene and fails closed on missing retained evidence.
- records objective hash, objective metadata, and `sweep_id`.
- a rejecting `ledgr_candidate.ledgr_sweep_filter_result()` method errors (not merely
  absent, since `ledgr_candidate.default()` dispatches on sweep-like tibbles) and the long
  tear-down shape does not satisfy the candidate-row contract; `ledgr_promote()` and
  walk-forward selection reject it; writes no promotion record; mutates no identity -- tests
  assert each rejection.

### 6.3 Closed-Trade Retention

- the opt-in level persists `candidate_row`, `trade_seq`, `close_ts_utc`, `realized_pnl`,
  `win_loss` per closed trade; `trade_seq` is the deterministic order key `stable_runs`
  uses; default retention is unchanged.
- the saved-sweep parent/artifact schema versions and per-table validators gain the
  retained-trades table; the storage smoke gate passes with a recorded ratio threshold.
- reopened pre-extension sweeps remain valid and report trade evidence as unretained.
- a no-trade-retention regression fixture remains byte-identical.

### 6.4 `stable_region`

- the spike note records neighbor rule, good-neighbor threshold, statistic, fail-closed
  rule, research citation, and a known-direction fixture.
- the detector is deterministic, consumes only grid + metric, and fails closed on
  non-factorial / sparse / unordered grids.
- ships only on maintainer acceptance; defers cleanly otherwise without affecting the other
  criteria.

### 6.5 Diagnostic-Threshold Criteria

- threshold over a named v0.1.9.6 diagnostic output column; record the source diagnostic's
  metadata and hash; recompute nothing.
- documentation states the criterion is an evidence threshold, not a profitability
  endorsement.

### 6.6 K-Ratio

- matches a pinned, named reference variant or a known-direction fixture.
- carries input identity and schema/version metadata; invalid evidence fails closed.
- defers cleanly with a recorded note if verification does not stay small.

### 6.7 Intraday Guardrail

- daily metric defaults over sub-daily observed cadence raise a classed condition.
- metric values, recipes, and identity are unchanged by the guardrail.
- no intraday runtime behavior is added.

### 6.8 Documentation And Release Surfaces

- the craft clause exists in the styleguide with or before the article refit; the
  doc-contract test keeps non-vacuous content and anti-overclaim assertions.
- PBO/MinTRL/DSR worked examples execute and their pinned numbers match.
- new public surfaces have reference pages.
- `DESCRIPTION` reads `0.1.9.7`; the v0.1.9.6 roadmap row reads Done; deferrals are carried
  forward with reasons; the release gate runs full tests and package check before tag.

---

## 7. Open Questions For Spec Review / Ticket Cut

1. Intraday guardrail disposition: warning-only everywhere, or hard-fail on the most
   dangerous surface (annualized headline metrics in a committed sweep)?
2. K-Ratio: which named published variant is canonical, and does a clean reference value
   exist or is a known-direction fixture the gate?
3. Diagnostic-threshold criteria: which v0.1.9.6 diagnostic columns are admissible
   thresholds in v1 (DSR and MinTRL at least), and how is each column's hash recorded on the
   criterion step?
4. Closed-trade retention: the new retention level's name and the storage-ratio threshold
   for its smoke gate (minimal columns are bound in 2.3).
5. `ledgr_sweep_filter_result` class and column names are bound at ticket cut under the
   v0.1.9.5 naming synthesis. `filter` reads as a subsetting verb -- reconsider whether a
   less selection-implying entry-point name is warranted given the all-candidates contract.

---

## 8. Explicit Deferrals

- D4 objective-filtered walk-forward identity and `business_objective_hash` participation in
  walk-forward session identity.
- the broader robustness-criterion family beyond the strict lattice detector: hold-fixed
  handling of nominal axes, and non-factorial / sparse / unordered grids via kNN,
  normalized-radius, Gower, or density modes, as separate criteria.
- scored / weighted objective composition (a synthesis-named future additive).
- a public third-party criterion-extension contract.

These four cluster into one candidate "business-objective completion / robustness" RFC,
recorded in the 2026-06-26 horizon entry, opened after the v0.1.9.8 talib adapter.

Also deferred:

- Triple Penance (original-paper verification unresolved).
- walk-forward short-window cadence awareness (audit M-2).
- intraday worked example and subsecond-tolerance documentation (audit L-1), pending M-1.
- first-class intraday runtime implementation.
- the talib indicator adapter (separate packet, v0.1.9.8).
- crypto-readiness spike, target-helper Pass 2, and the strategy schedule decorator.
- purged k-fold / embargo / CPCV, portfolio optimization, point-in-time data tables, and
  benchmark-relative metrics.
- paper/live trading, OMS, broker reconciliation, and liquidity/capacity.

---

## 9. Review Focus

Spec review should verify:

- the business-objective layer is genuinely eligibility-only and cannot become selection,
  promotion, or walk-forward identity through any surface in this packet -- especially that
  `ledgr_sweep_filter()` is an all-candidates evidence surface that cannot be read as a
  pick;
- the 2026-06-26 amendment faithfully promotes the full D2 set and defers only D4, the
  broader robustness family, scored composition, and the public extension contract -- and
  meets the v0.1.9.6 section 2.6 conditions;
- the seven criteria map to genuinely available evidence: summary metrics, retained returns,
  the new closed-trade retention, the candidate grid, and named diagnostic outputs;
- the closed-trade retention extension follows the v0.1.9.2 storage discipline and keeps
  non-opt-in sweep artifacts byte-identical;
- the `stable_region` spike is correctly gated, deterministic, fail-closed, and honestly
  attributed as an interpretive operationalization of Pardo;
- diagnostic-threshold criteria are bound as evidence thresholds, not profitability
  endorsements, with source hashes recorded;
- K-Ratio inclusion is conditional on small, pinned, named-variant reference verification;
- the intraday guardrail is honesty-only and isolated from any intraday runtime change;
- the teaching refit is polish of the shipped article with the craft clause and a
  non-vacuous, less brittle doc-contract;
- the internal criterion-step contract keeps the layer expandable without committing a
  public extension contract in this packet;
- the deferral ledger, the 2026-06-26 horizon entry, and the roadmap closeout are complete
  and consistent, and the non-scope list blocks the promotion / selection / identity
  footguns without blocking the intended eligibility evidence.

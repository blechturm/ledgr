# ledgr v0.1.9.6 Spec

**Status:** Batch 2 implementation complete; awaiting Claude review.
**Target branch:** `v0.1.9.6`.
**Scope:** Validation substrate and gated diagnostics after v0.1.9.5:
canonical single-run returns, retained-return panel hygiene,
adapter-shaped return projections, a PBO spike gate, reference-verified
self-contained diagnostics where retained at ticket cut, the
methodological-diagnostics documentation gate, intraday-readiness audit, and a
current-surface peer benchmark redo.
**Maintainer rescope:** The accepted validation-toolkit synthesis remains
binding, but the 2026-06-14 maintainer amendment changes PBO/CSCV from
unconditional implementation to an in-packet spike-gated candidate. Until the
PBO spike passes maintainer review, implementation tickets stop at substrate,
panel hygiene, projection, and spike artifacts. If the spike does not pass
green, PBO/CSCV and the dependent business-objective / objective-filtered
walk-forward identity work defer to v0.1.9.7 or later.
**Non-scope:** no second execution engine; no fold-core semantic change; no
unconditional PBO/CSCV implementation; no purged k-fold, embargo, CPCV, HRP,
portfolio optimization, benchmark-relative diagnostics, regime adapters,
automatic promotion, winner-picking, paper/live behavior, broker/OMS
validation, intraday runtime implementation, or compiled spot-FIFO default
flip.

---

## 0. Source Inputs

Binding artifacts:

- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md` (accepted
  2026-06-12; maintainer-amended 2026-06-14) -- validation substrate,
  optional-adapter posture, D1-D4 decisions, PBO gate, documentation gates,
  and future obligations.
- `inst/design/vignette_styleguide.md` -- Methodological Diagnostics policy
  and the execute-by-default documentation standard.
- `inst/design/ledgr_roadmap.md` v0.1.9.6 row -- substrate-first validation
  packet, PBO spike gate, methodological-diagnostics gate, and
  intraday-readiness audit.
- `inst/design/horizon.md` entries:
  - 2026-06-11 `[adapters]` canonical run return stream before reporting
    adapters;
  - 2026-06-13 `[infrastructure]` peer benchmark redo with cost and risk
    chains;
  - 2026-06-13 `[execution]` v0.1.9.6 intraday-readiness code audit;
  - 2026-06-13 `[execution]` compiled spot-FIFO default decision entry
    (visible but not in-scope unless a later maintainer amendment promotes it);
  - 2026-06-07 validation-toolkit planning entry, updated 2026-06-14 with the
    PBO spike gate and documentation-policy requirement.

Planning and contract inputs:

- `inst/design/contracts.md`;
- `inst/design/rfc/README.md` validation-toolkit decision-index row;
- `inst/design/research/Validation-Toolkit.md` (research input; non-binding);
- `inst/design/methodology_references.md`;
- `inst/design/release_ci_playbook.md`;
- v0.1.9.1-v0.1.9.5 packet records.

External package facts about `pbo`, PerformanceAnalytics, RPESE, and related
packages must be re-verified in packet-open / spike work. Any current manual
or CRAN lookup is input evidence, not permanent authority.

---

## 1. Thesis

v0.1.9.1 through v0.1.9.5 built the evidence spine needed for serious
research validation: cost identity, retained return series, risk-chain
identity, walk-forward sessions, and a cleaned public API. v0.1.9.6 starts the
validation layer without pretending the statistics are trivial. It first makes
the canonical return stream explicit, hardens the panel bridge that external
diagnostics need, and gates PBO on a spike that proves the package/API/method
path before public results ship.

The release should answer a narrower question than the original validation
toolkit ambition:

```text
Can ledgr expose canonical return evidence and the first verified
selection-integrity diagnostics without weakening the execution, identity, or
teachability contracts?
```

The answer may include PBO/CSCV only if the spike returns green. Otherwise, a
successful v0.1.9.6 still ships the substrate and the spike findings that make
v0.1.9.7 safer.

---

## 2. Product Shape

### 2.1 Canonical Single-Run Returns

Add a `ledgr_results()` result-table view:

```r
ledgr_results(bt, what = "returns")
```

Required public columns:

```text
ts_utc
equity
period_return
```

Binding:

- derive from the existing equity result table;
- first `period_return` is `NA_real_`;
- subsequent values use the same adjacent equity return formula as retained
  sweep returns and ledgr-owned metric computation;
- result is a ledgr evidence table, not a metrics table;
- `what = "metrics"` remains unsupported;
- no `sweep_id`, `candidate_id`, or `candidate_row` columns on a single-run
  result view.

This view extends the existing result-table contract, not a parallel accessor.
`tibble::as_tibble(bt, what = "returns")` must expose the same table, and
`ledgr_results(bt, what = "returns")` must delegate through the `as_tibble()`
path required by `inst/design/contracts.md`. The contracts.md closed
result-set enumeration must be updated in the same implementation batch to
include `returns` alongside `equity`, `fills`, `trades`, and `ledger`.

This view is identity-neutral. It creates no new persisted evidence, config
field, run hash, session id, or metric recipe.

### 2.2 Return-Panel Bridge

Provide the validation substrate over retained sweep returns:

- sorted, UTC-normalized long evidence from `ledgr_sweep_returns()`;
- adapter-shaped wide matrices or `xts` projections for optional packages;
- first-row `NA` handling is explicit and tested;
- complete-grid checks fail closed for diagnostics that require a common
  timestamp grid;
- completed-candidate universe and excluded candidate ids are reported;
- missing retained returns reuse `ledgr_sweep_returns_unretained`.

This bridge is the load-bearing surface for PerformanceAnalytics, RPESE, pbo,
and later validation tooling. It must not recompute strategy evidence from raw
fills or positions.

### 2.3 Optional External Adapters

Adapter posture remains:

- optional packages stay in `Suggests`, never `Imports`;
- `NAMESPACE` does not import optional adapter packages;
- tests skip cleanly when optional packages are absent;
- adapter-derived results are labeled external evidence and carry package /
  version metadata;
- adapter conventions do not redefine ledgr-owned metrics.

PerformanceAnalytics is the first reporting/evidence adapter family. RPESE and
pbo remain conditional on packet-open and spike verification.

### 2.4 Self-Contained Diagnostics

Self-contained diagnostics may ship only when the packet verifies primary
reference behavior and can teach the method under the styleguide rule.

Default inclusion order:

1. minimum track-record length;
2. DSR with effective-trial-count input, coupled to deterministic candidate
   clustering where needed;
3. K-Ratio only if source verification and article scope remain small;
4. Triple Penance remains a packet-open in/out question.

Each diagnostic must define:

- accepted input evidence;
- output shape and class;
- input identity fields;
- failure classes;
- reference-value or known-direction tests;
- documentation section satisfying the Methodological Diagnostics styleguide.

### 2.5 PBO Spike And Conditional Implementation

PBO/CSCV is not pre-committed. The packet must run a PBO spike before any
public PBO implementation ticket proceeds.

The spike must produce a reviewed synthesis covering:

- method sketch: CSCV partitions, in-sample/out-of-sample ranking, logit rank,
  PBO, and related outputs;
- assumptions and failure modes: candidate count, observation count, `s`
  divisibility, ragged panels, correlated candidates, non-stationarity, and
  interpretation limits;
- "what PBO cannot prove" teaching surface, including the distinction between
  selection-integrity evidence and proof of future profitability;
- `pbo` package audit: version, license, activity, dependencies, API,
  metric-hook shape, output shape, determinism with `allow_parallel = FALSE`,
  and known issues;
- known-answer or reference-value verification, with enough fixture detail to
  become a regression gate;
- ledgr panel contract: exact `T x N` shape, first-row `NA` handling,
  complete-grid behavior, completed-candidate universe, excluded candidates;
- adapter-vs-native verdict and fallback conditions.

Gate:

- If the spike passes green and the maintainer accepts the synthesis, the
  packet may add PBO/CSCV implementation tickets.
- If the spike returns yellow/red, lacks known-answer verification, or does not
  get maintainer acceptance, PBO/CSCV defers to v0.1.9.7 or later.

### 2.6 Business Objective Layer

`ledgr_business_objective()` and `ledgr_sweep_filter()` remain planned by the
accepted synthesis but are conditional in this packet.

Default rule:

- if the PBO gate does not pass, the business-objective layer defers with PBO;
- the v0.1.9.6 spec-cut may record a narrowed override only if it can compose
  proven non-PBO criteria without implying automatic promotion, winner
  selection, or premature objective-filtered walk-forward identity;
- no implementation may hide selection or promotion inside the objective
  surface.

If implemented, the objective layer must preserve the accepted synthesis
contracts: all-pass v1 composition, classed and hashed criterion steps,
per-candidate x per-criterion tear-down table, missing evidence fails closed,
and conditional `business_objective_hash` participation in walk-forward
session identity.

---

## 3. Method Teachability Gate

The packet-open gate is hard: before validation-method implementation tickets
open, `inst/design/vignette_styleguide.md` must contain the Methodological
Diagnostics section and `tests/testthat/test-documentation-contracts.R` must
lock that rule.

Per-method documentation gates land with the method/article they cover. Do not
add tests that pass vacuously for planned articles that do not exist yet.

Every method section must teach:

- the question answered;
- ledgr evidence consumed;
- method shape, enough to audit the intuition;
- interpretation;
- limits;
- failure modes;
- references;
- an executed worked example, except for standard styleguide exceptions.

High-risk diagnostics need at least one cautionary or disconfirming example.
Selection Integrity should be organized as one article family: MinTRL, DSR,
effective-trial clustering, and later PBO/CSCV belong together unless a later
packet records a stronger split.

---

## 4. Audits And Measurement

### 4.1 Intraday-Readiness Audit

Run a deep code and contract audit, not an implementation batch. The audit
answers whether ledgr is still EOD-first but intraday-tolerant after the
v0.1.9.x arc.

Required audit surfaces:

- snapshot sealing and timestamp precision;
- pulse calendars and fold windows;
- metric annualization;
- feature warmup and hydration;
- timing and cost contexts;
- target-risk boundaries;
- retained return panels and adapter projections;
- sweep and walk-forward identity;
- generated documentation examples.

Output artifact:

```text
finding -> affected surface -> why it matters for intraday ->
current severity -> refactor size -> recommended disposition
```

No intraday runtime implementation is authorized.

### 4.2 Peer Benchmark Redo

Redo the peer parity/performance benchmark on the v0.1.9.5+ surface so current
cost and risk chains are measured rather than inferred.

Required measurement shape:

- include `ledgr_cost_zero()` / `ledgr_risk_none()` and a representative real
  cost/risk-chain row on the same fixture and seed;
- preserve canonical ledgr parity checks;
- report the delta as measurement evidence, not optimization commitment;
- update the internal benchmark report only after the record bundle is
  accepted.

No public benchmark marketing claim is authorized.

### 4.3 Compiled Spot-FIFO Default

The compiled spot-FIFO default decision remains visible in horizon but is not
part of this spec. A future packet or amendment may promote a measurement
spike and RFC. v0.1.9.6 does not flip defaults.

---

## 5. Indicative Implementation Sequence

Tickets will bind final batch shape later. The spec-level order is:

1. Packet alignment and external/package verification.
2. Methodological-diagnostics styleguide gate and doc-contract lock.
3. `ledgr_results(bt, what = "returns")`.
4. Return-panel hygiene and adapter-shaped projections.
5. PBO spike and spike synthesis.
6. Conditional branch:
   - if PBO spike passes green: PBO/CSCV implementation may be ticketed;
   - otherwise: record deferral and continue with substrate/self-contained
     diagnostics only.
7. Reference-verified self-contained diagnostics retained at ticket cut.
8. Deterministic clustering / effective-trial-count support if required by
   retained diagnostics.
9. Optional adapter extensions that pass packet-open verification.
10. Conditional business-objective layer only if the gate conditions allow it.
11. Intraday-readiness audit.
12. Peer benchmark redo.
13. Documentation, NEWS, reference pages, and release gate.

The sequence intentionally puts substrate and spike work before any method
whose correctness depends on them.

---

## 6. Mechanical Gates

### 6.1 Return Stream

- `ledgr_results(bt, "returns")` returns `ts_utc`, `equity`,
  `period_return`.
- First `period_return` is `NA_real_`.
- Later returns match the adjacent equity formula used by retained sweep
  returns.
- The result is classed as a ledgr result table.
- `tibble::as_tibble(bt, what = "returns")` exposes the same table.
- `ledgr_results(bt, what = "returns")` delegates through the `as_tibble()`
  result-table path rather than duplicating reconstruction.
- `inst/design/contracts.md` updates the closed result-set enumeration to
  include `returns`.
- `what = "metrics"` remains unsupported.
- The view does not change run/config/session identity.

### 6.2 Panel Hygiene

- Equal-grid retained returns produce a deterministic `T x N` return matrix
  after structural first-row handling.
- Ragged panels fail closed for diagnostics that require complete panels.
- Missing retained returns reuse `ledgr_sweep_returns_unretained`.
- Completed candidate ids used and excluded candidate ids are reported.
- Timestamp ordering and UTC normalization are mechanically tested.

### 6.3 PBO Spike

- No public PBO/CSCV implementation ships without a maintainer-accepted spike
  synthesis.
- The spike records package status/API/determinism/license/dependencies.
- The spike includes known-answer or reference-value verification.
- The spike binds adapter-vs-native verdict and fallback conditions.
- The spike includes the "what PBO cannot prove" teaching surface.
- Deferral is recorded explicitly when the gate does not pass.

### 6.4 Diagnostics

- Every diagnostic has reference-value or known-direction tests.
- Every diagnostic carries input identity and schema/version metadata.
- Missing or invalid evidence fails closed with classed conditions.
- Adapter-derived diagnostics are labeled external evidence.
- Optional dependencies remain optional.

### 6.5 Documentation

- The Methodological Diagnostics styleguide section exists before
  validation-method implementation tickets open.
- Each method article/section lands with doc-contract assertions for its own
  required structure.
- Examples execute unless they satisfy standard styleguide exceptions.
- High-risk diagnostics include cautionary/disconfirming examples.
- The validation docs state what the methods do not prove.

### 6.6 Audit And Benchmark

- Intraday audit writes a versioned audit artifact and makes no runtime change.
- Peer benchmark redo writes/updates internal benchmark artifacts only after
  parity and methodology checks pass.
- Release surfaces do not present internal benchmark numbers as public ranking
  claims.

---

## 7. Open Questions For Spec Review / Ticket Cut

These are not tickets yet.

1. Which self-contained diagnostics are in v0.1.9.6 after reference
   verification: MinTRL only; MinTRL + DSR; K-Ratio; any others?
2. Is DSR allowed to ship without PBO if effective-trial clustering is
   verified, or should DSR defer with PBO when the spike is not green?
   Technical steer for ticket cut: DSR's deflation depends on the
   effective-trial clustering path, not on PBO itself, so DSR can remain
   independently eligible if clustering is reference-verified.
3. Does the business-objective layer defer by default with PBO, or does the
   ticket cut record a narrowed non-PBO objective-only override?
4. What exact public names satisfy the v0.1.9.5 naming synthesis for the
   bridge and diagnostics surfaces?
5. Does the packet add RPESE or pbo to `Suggests`, or only record spike
   findings?
6. Does the peer benchmark redo land in the main packet or a separate
   measurement-only commit after feature work?
7. Does the intraday-readiness audit run before return-panel implementation
   (to catch panel cadence footguns early) or after substrate implementation
   (to audit the final v0.1.9.6 shape)?

---

## 8. Explicit Deferrals

- Public PBO/CSCV if the spike gate does not pass.
- Business-objective implementation and objective-filtered walk-forward
  identity if PBO defers, unless a narrowed override is explicitly accepted.
- Per-fold train-sweep PBO / `fold_seq` retention.
- Purged k-fold, embargo, CPCV.
- Benchmark-relative metrics.
- Portfolio optimization / HRP.
- Intraday runtime implementation.
- Compiled spot-FIFO default flip.
- Paper/live trading, OMS, broker reconciliation, liquidity/capacity.
- Saved diagnostics storage tables.

---

## 9. Review Focus

Spec review should verify:

- the 2026-06-14 maintainer rescope is represented faithfully;
- PBO/CSCV is truly gated, not accidentally scheduled as unconditional work;
- `ledgr_results(bt, what = "returns")` is consistent with existing result
  table and retained-sweep-return contracts;
- panel-hygiene and adapter-projection gates are mechanically checkable;
- the methodological-diagnostics policy is a packet-open gate and per-article
  tests are non-vacuous;
- business-objective and walk-forward identity work are conditional in the
  right places;
- intraday audit and peer benchmark redo are isolated from runtime feature
  implementation;
- the non-scope list blocks the right footguns without preventing the intended
  substrate work.

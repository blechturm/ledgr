# RFC Seed: Asset Availability, Point-in-Time Universes, and Missing-Data Semantics

**Status:** Seed v1 - request for response-stage adversarial review. This
document is a non-binding proposal. It does not authorize implementation,
change a contract, or expand the accepted research scope.
**Date:** 2026-09-07
**Author:** Codex (Seed v1). Per `../rfc_cycle.md`, the response must be written
by a different author.
**Target window:** v0.2.x-v0.3.0, after this RFC cycle and an implementation
specification are accepted.
**Cycle placement:** staged on the `v0.1.9.8` branch as design work only. The
branch name does not authorize implementation in v0.1.9.8.
**Working file:**
`rfc_asset_availability_point_in_time_universes_v0_1_9_8_seed.md`
**Research inputs:**

- `../research/Sharadar-Empirical-Evidence.md` - reviewed, public,
  non-reconstructive empirical synthesis; architecture-non-binding.
- `../research/ledgr_ragged_universe_prior_art_review.md` - source-based
  prior-art review; non-binding and independently checked where used below.
- `../research/rfc-evidence-handoff.md` - compact empirical handoff and routing
  memo; non-binding, with the expanded empirical synthesis controlling if the
  two differ.

**Adjacent non-authoritative context:**
`../research/Cross-Asset-Accounting-Critical-Events.md` informs the coordinated
accounting boundary in Section 15. It is not part of the empirical record for
ragged-universe behavior and does not authorize accounting event types here.

**Current authorities:** `../contracts.md`, accepted RFC syntheses indexed in
`README.md`, current code and tests, `../ledgr_roadmap.md`, and
`../horizon.md`.

> In this document, "v1" means a possible first implementation of this
> capability. It does not mean ledgr v1.0.0 and does not create a roadmap
> milestone.

---

## 1. Problem Statement

ledgr's current research engine is intentionally strict. A configured
instrument universe becomes a fixed matrix axis, every instrument must have a
bar at every pulse, and every strategy must return one finite named target for
every instrument. This gives an excellent deterministic oracle for complete
rectangles. It cannot faithfully represent an instrument that lists halfway
through a window, a universe whose membership changes point in time, or a held
instrument whose valuation and execution states differ.

The architectural error would be to replace strictness with undifferentiated
`NA` values or forward filling. An absent row can mean many incompatible
things: the instrument did not yet exist, it was outside the research
universe, its market was closed, an expected source observation is unresolved,
a row failed quality checks, trading was halted, a mark is stale, a feature is
warming up, or a terminal economic event has not yet been accounted for. Those
states have different visibility, valuation, execution, and evidence
consequences.

The RFC question is therefore:

```text
How can ledgr preserve sparse point-in-time facts, classify distinct forms of
availability, and deliver matrix-friendly as-of-safe inputs through the one
fold core without revealing future membership, inventing executable prices,
or weakening deterministic replay?
```

This seed proposes an answer concrete enough to attack. It deliberately leaves
policy defaults and the final physical schema to later stages.

## 2. Evidence Basis and Evidence Limitations

### 2.1 What the empirical work established

The reviewed Sharadar synthesis establishes only the following relevant facts:

- A qualified canonical build can export bounded payloads without loading or
  row-hashing the complete history in R.
- A real complete five-instrument by twenty-session rectangle (100 cells)
  sealed, reopened, executed, and reconciled. The successful trade path
  exposed one instrument under zero costs. It did not test simultaneous
  multi-instrument holdings, non-zero costs, dividends, or terminal events.
- The complete supported 2019-2021 XNYS point-in-time reference population had
  757 sessions, 563 distinct instruments, and 382,288 member-session rows.
  A static 563-by-757 rectangle would contain 426,191 member-session cells, so
  membership changed. ledgr could seal available bars but its static
  instrument input could not preserve that membership stream without
  distortion.
- Seven adversarial cases classified 101 cells into 12 expected-and-observed,
  34 structural-nonexistence, 24 unresolved-absence, and 31
  observed-outside-expectation cells. Only two lifecycle adjudications had
  known direct lifetime evidence; five remained uncertain.
- The casebook found zero confirmed `expected_session_absence` cells. The
  exhaustive gate does not disclose whether its separate missing-bar predicate
  fired. No imputation experiment was performed.
- The only accepted research scope remains
  `dense_static_method_validation_v001`.

The private evidence repository at the commit named by the empirical
synthesis remains the exact audit authority. This seed repeats only the
non-reconstructive aggregates that the synthesis intentionally makes public.

### 2.2 What the evidence does not establish

This seed does not claim that ordinary missing daily bars are common, that the
spike found a genuine missing bar inside a known active lifetime, or that any
particular representation follows from the evidence. It does not authorize
broad-equity research, dynamic-membership performance claims,
dividend-inclusive performance, or terminal-event results. Sharadar names and
action labels are source evidence, not ledgr schema names or event types.

This seed also rejects two shortcuts proposed in the older, non-binding
2026-05-28 horizon entry. First and last observed bars are not sufficient
evidence of economic lifetime. Seal-time imputation is not a source fact and
must not erase the distinction between observation, classification, and a
derived transform. The entry's separate live-degradation direction remains
parked for its own RFC.

The prior-art review is a map of alternatives, not policy. Three external
points used here were rechecked against primary documentation on 2026-09-07:

- Zipline exposes asset lifetime, exchange-open, and known-price conditions
  separately in `can_trade()`, and distinguishes a forward-filled last price
  from current OHLC and staleness. This is evidence that availability axes can
  be separate, not a contract to copy Zipline's filling policy:
  <https://zipline.ml4trading.io/api-reference.html>.
- scikit-learn documents that fit-based preprocessing, including imputation,
  must learn from training data rather than the test set. This supports the
  fold-fitted identity requirement below:
  <https://scikit-learn.org/stable/common_pitfalls.html>.
- Nasdaq publishes explicit halt status and reason fields. This supports
  representing a known halt separately from a missing row; it does not define
  a universal cross-venue taxonomy:
  <https://www.nasdaqtrader.com/Trader.aspx?id=TradeHaltCodes>.

ALFRED's distinction between observation dates and vintage dates is a useful
primary-source precedent for preserving what was known when, without implying
that market membership has the same schema:
<https://alfred.stlouisfed.org/help/downloaddata>.

## 3. Current ledgr Substrate and Code Audit

### 3.1 Snapshot facts and sealing

`R/db-schema-create.R` stores one `snapshot_instruments` row per snapshot and
instrument and one non-null-OHLC `snapshot_bars` row per instrument and
timestamp. Neither table represents lifetime evidence, time-varying
membership, expected sessions, row quality, or availability policy.
Migrations add fields to that dense model; they do not introduce a ragged
state model.

`ledgr_snapshot_from_df()` in `R/snapshot_adapters.R` validates finite OHLC and
persists canonical bars. `ledgr_snapshot_validate_for_seal()` in
`R/snapshots-seal.R` checks referential integrity, timestamp granularity, and
OHLC consistency, but sealing itself does not require a rectangle.
`ledgr_snapshot_hash()` in `R/snapshots-hash.R` hashes canonical instrument and
bar payloads, including `snapshot_instruments.meta_json`. The snapshot ID and
the `snapshots` envelope row, including `snapshots.meta_json`, are excluded.
Therefore an external sidecar can explain lineage without changing the current
snapshot hash; that is an audit limitation when the sidecar contains
semantically necessary membership or classification facts.

`ledgr_prepare_snapshot_runtime_views()` in `R/snapshot-source.R` creates the
legacy runtime views and supplies `gap_type = 'NONE'` and
`is_synthetic = FALSE` for every stored snapshot bar. These compatibility
columns do not express the state model required here.

### 3.2 Where the fixed rectangle becomes mandatory

`ledgr_experiment_snapshot_universe()` and
`ledgr_experiment_normalize_universe()` in `R/experiment.R` turn snapshot
instruments and configured IDs into a fixed experiment universe.

`ledgr_run_fold()` and `ledgr_pulse_timestamps()` in
`R/backtest-runner.R` then:

1. construct the pulse calendar from the union of stored bar timestamps;
2. apply an early fixed-universe coverage-count gate in `ledgr_run_fold()`;
3. form the exact Cartesian product in `ledgr_pulse_timestamps()` and abort if
   any product cell lacks a bar;
4. hydrate one exactly aligned series per instrument; and
5. build fixed instrument-by-pulse matrices.

`tests/testthat/test-runner-snapshots.R` makes the rule explicit: an
instrument starting one session late raises `LEDGR_SNAPSHOT_COVERAGE_ERROR`.
`ledgr_precompute_validate_static_coverage()` in
`R/precompute-features.R` independently requires the same aligned shape for
precomputed features.

### 3.3 Indicators, feature identity, and pulse delivery

`ledgr_indicator()` and `ledgr_indicator_fingerprint()` in `R/indicator.R`
identify indicator logic, parameters, required bars, and warm-up. The
session-local cache in `R/feature-cache.R` keys a series by snapshot hash,
instrument ID, indicator fingerprint, feature-engine version, and requested
range. `ledgr_precompute_features()` additionally records the fixed universe,
scoring and hydration ranges, grid labels, and feature fingerprints.

`R/pulse-context.R` aligns price, feature, and position vectors to the fixed
universe. Current feature warm-up may produce `NA` before `stable_after`; after
warm-up, non-finite output is invalid. There is no first-class observation
mask, model-native missing-value declaration, or fitted preprocessing object.

### 3.4 Targets, risk, execution, and valuation

`ledgr_validate_strategy_targets()` in `R/strategy-contracts.R` requires names
to match `ctx$universe` exactly and finite quantities. Missing names are an
error, never an instruction to liquidate. The corresponding contract is
covered by `tests/testthat/test-strategy-contracts.R`.

`ledgr_execute_fold()` and `ledgr_fold_build_pulse_plan()` in
`R/fold-engine.R` validate targets, apply target risk, validate again, and plan
the next-open fill against the next matrix column. `ledgr_next_open_fill_proposal()`
in `R/fill-model.R` requires a finite positive next open. The current final-bar
contract emits no fill rather than inventing a later bar, as tested in
`tests/testthat/test-acceptance-v0.1.0.R`.

Portfolio values inside the fold and the reconstruction in
`R/backtest-runner.R` multiply every held quantity by the current close.
`ledgr_state_asof()` similarly queries current-timestamp closes. There is no
separate mark age, unpriced-position state, or execution eligibility object;
the dense finite-bar gate makes them unnecessary today.

### 3.5 Sweep and walk-forward parity

`ledgr_sweep_impl()` in `R/sweep.R` resolves the same fixed universe and sends
every candidate through the shared fold core. `ledgr_walk_forward()` in
`R/walk-forward.R` composes training sweeps, selection, and test runs over that
same path. `R/walk-forward-folds.R` defines calendar-time train/test windows
and then applies the static pulse-coverage gate. Saved sweeps and promotion do
not create an alternate executor.

The current walk-forward identity in `R/walk-forward-identity.R` includes the
snapshot, experiment, parameter grid, folds, selection rule, metric, cost,
risk, seed, and opening-state policy. It has no independent identity for
point-in-time universe construction, calendars, availability classification,
valuation, execution eligibility, or fold-fitted preprocessing because those
objects do not yet exist.

### 3.6 The actual current equivalence

For the production snapshot path, the code effectively equates:

```text
configured static universe
  = internal matrix axis
  = every-pulse expected-bar set
  = every-pulse accepted observed-bar set
  = public strategy universe
  = full target domain
  = valuation domain
  = execution-price domain
```

The statement needs two qualifications. Snapshot sealing can store a sparse
payload; the rectangle is imposed when a run or feature precomputation starts.
Also, a final-pulse target has no next execution bar even in dense mode. Those
qualifications do not provide point-in-time membership or general missing-data
semantics.

## 4. Adjacent Accepted Decisions That Constrain This RFC

Any later synthesis must preserve these accepted boundaries unless it names
and justifies a direct amendment:

- `ledgr_run()`, `ledgr_sweep()`, and walk-forward use one fold core.
- Only sealed, hash-verified snapshots may execute.
- Strategy context is as-of the decision pulse; next-open execution data is
  not visible to the strategy.
- Indicators carry replay-stable fingerprints and explicit warm-up contracts.
- A strategy returns a full finite named target vector; omitted names are not
  zero.
- Target risk runs after target validation and before fill planning, with its
  own identity.
- Timing proposes fills, transaction-cost resolution adjusts economic terms,
  and neither is an OMS.
- A next-open target on the final pulse produces no fill.
- Saved sweeps and promotions preserve candidate and experiment identity.
- Walk-forward fitting and selection use training windows that precede their
  test windows.
- Accounting is event-sourced.
- Persistent order lifecycle, broker reconciliation, and live degradation are
  deferred to the OMS/live arcs.

The direct pressure is on the current dual meaning of `ctx$universe`: it is
both the strategy-visible ID domain and the alignment domain for positions,
helpers, and full targets. Future-safe membership requires that domain to be
pulse dependent, while a held instrument can remain economically relevant
after leaving the member set. Section 9 proposes a narrow evolution that keeps
positions and targets aligned to one explicit pulse domain rather than adding
a second target-only domain. The missing-target rule remains unchanged. Dense
behavior remains unchanged.

## 5. Vendor-Neutral Terminology

The proposal uses orthogonal facts and classifications. A single cell may
carry several of them.

| Concept | Meaning | Required state shape |
| --- | --- | --- |
| Stable instrument identity | An internal ID that survives ticker or display-name changes | ID plus validity- and knowledge-dated alias assertions; never infer continuity from symbol equality |
| Lifetime evidence | Evidence about when the economic instrument existed | `known_active`, `known_inactive`, or `unknown`, with validity interval, knowledge time, and provenance |
| PIT universe membership | Whether the named universe included the instrument as of a decision time | `member`, `not_member`, or `unknown`, with source effective/knowledge times |
| Expected observation | Whether a source observation should exist for an instrument and session | `expected`, `not_expected`, or `unknown`, plus calendar and expectation rule |
| Observed row | A source row was present | immutable fact keyed by instrument, observation time, and source revision |
| Observation validity | ledgr's disposition of the observed row | `accepted`, `rejected`, `quarantined`, or `unresolved`, with reason and policy version |
| Valuation availability | A policy can produce a mark at this pulse | `fresh`, `stale`, or `unpriced`, with mark time, age, source, and policy |
| Execution eligibility | A timing/execution policy may use an observed price | `eligible`, `ineligible`, or `unknown`, with reason; never inferred from valuation availability alone |
| Feature validity | A feature value is available for its declared consumer | `valid`, `warmup`, `source_missing`, `transformed`, `model_native_missing`, or `invalid`, with node identity |
| Unknown | Evidence was not sufficient to classify the state | a first-class value, never silently coerced to false, absent, or valid |

Vendor records remain source facts with source-native labels. ledgr policy
produces versioned classifications from those facts. A new policy may change a
classification without rewriting the source record. A vendor corporate-action
label must not be normalized one-to-one into a ledgr accounting event merely
because the strings resemble each other.

## 6. Architectural Alternatives

| Alternative | Research validity and leakage | Performance / memory | Strategy / ML ergonomics | Replay and complexity | Seed assessment |
| --- | --- | --- | --- | --- | --- |
| Static superset plus plain `NA` | Poor: future identities are visible and meanings collapse | Dense memory; simple kernels | Familiar matrices but ambiguous missingness | Easy to build, hard to audit | Reject |
| Static superset plus orthogonal masks | Can prevent semantic collapse, but a public superset still leaks future IDs | Dense value and mask cost may be high | Strong matrix and ML compatibility | Deterministic if masks are identity-bound; many invariants | Viable runtime component, not sufficient alone |
| Dynamic active-universe matrices | Strong PIT visibility | Smaller active matrices; remapping cost | Variable shapes complicate holdings, targets, and ML | Deterministic with strict ordering; high implementation risk | Keep as comparison, not first choice |
| Sparse/event-native execution | Natural facts and state transitions | Efficient for sparse facts; event dispatch can scale | Cross-sectional indicators become awkward | Could become a second engine and conflict with parity | Reject as the initial fold architecture |
| Sparse snapshot plus dense fold-local materialization | Strong if materialization is as-of and membership-aware | Bounded matrices; avoids full history rectangle | Preserves vectorized indicators | Adds a typed materialization layer but keeps one fold core | Preferred base |
| Hybrid event/panel | Separates state transitions from numeric panels | Potentially efficient; highest tuning burden | Flexible but broad API surface | Strong provenance possible; highest complexity | Defer until the base model is measured |

Physical DuckDB storage and consumer-facing representation are independent
choices. Sparse facts do not require an event-native strategy API; dense
fold-local matrices do not require a dense canonical snapshot.

## 7. Proposed Seed v1 Architecture

The proposed direction is:

```text
sealed sparse facts and effective-dated state
                  |
                  v
versioned as-of classification + calendar rules
                  |
                  v
bounded fold-local decision frame
  values + orthogonal state planes + stable internal axis
                  |
                  v
the existing one fold core, with pulse-dependent public views
```

The architecture has six rules:

1. Introduce `dense_static` as the explicit semantic-mode name for current
   complete-panel behavior and preserve that behavior as the parity oracle.
2. Add a separate proposed `ragged_pit` semantic mode; do not infer it from
   the presence of `NA` values.
3. Store source facts sparsely where that is natural, including effective-
   dated identity and membership facts. Keep ledgr classifications separate.
4. Materialize bounded, ordered numeric matrices plus orthogonal state planes
   for a run or fold. The internal axis may be fixed over that bounded window;
   public visibility remains pulse dependent.
5. Give valuation and execution independent policy decisions. Imputed or stale
   values never become executable merely because they occupy a numeric cell.
6. Put every semantic input into the appropriate identity layer so run,
   sweep, promotion, and walk-forward parity is verifiable.

The preferred base is a hypothesis, not an architecture selection. Before a
synthesis accepts a physical schema, state-plane encoding, or public strategy
API, a bounded architecture spike must compare the current dense path,
dense-plus-orthogonal-state, sparse/event materialization, and sparse storage
with fold-local densification. It must test future-ID invisibility, carried or
imputed non-executability, stale/unpriced holdings, dense parity, cache and
parallel behavior, sample retention, time, and peak memory.

This is a proposal, not an accepted schema. Names shown below are illustrative.

## 8. Storage and Runtime Representation

### 8.1 Proposed snapshot fact families

A future specification should evaluate normalized fact families equivalent to:

```text
instrument_identity(instrument_id, aliases, effective_from, effective_to,
                    known_at, revision_id, provenance)
lifetime_evidence(instrument_id, effective_from, effective_to, known_at,
                  assertion, provenance)
universe_membership(universe_id, instrument_id, effective_from, effective_to,
                    knowledge_time, assertion, provenance)
market_calendar(calendar_id, session, status, known_at, provenance)
observations(instrument_id, observation_time, known_at, revision_time, fields,
             provenance)
source_status(instrument_id, effective_time, known_at, source_label,
              provenance)
```

Classification outputs may be persisted or reproducibly materialized, but
must name their policy identity and input fact hashes. The schema must permit
`unknown`; an absent assertion is not automatically a negative assertion.

### 8.2 Fold-local decision frame

For each bounded hydration and scoring window, the engine may construct:

- `axis_ids`: deterministic sorted union of IDs needed during the bounded
  window, including positions carried into it;
- `pulses`: an identity-bound experiment calendar, not merely observed bar
  timestamps and not a union derived from instruments that become known only
  later;
- typed numeric planes such as observed OHLC, accepted OHLC, valuation marks,
  and features;
- orthogonal state planes for membership, expectation, observation validity,
  valuation age, execution eligibility, and feature validity; and
- per-pulse public ID vectors derived from those planes.

The fixed internal axis is an implementation detail. It must not be exposed
through a helper that lets a strategy discover an instrument before its
membership or carried-position state makes it visible. Values outside the
public view remain inaccessible, even if memory has been allocated for them.

The frame is derived, bounded, and discardable. It is not the canonical source
of vendor facts. Persisted materializations require an identity described in
Section 14.

## 9. Point-in-Time Universe and Strategy Contract

### 9.1 Public visibility

The proposal separates current membership from the one aligned strategy
domain while keeping the current positions/target invariant:

```text
ctx$members = currently knowable point-in-time members
ctx$universe = ordered union(ctx$members, names(non-zero held positions))
ctx$positions = full named vector aligned exactly to ctx$universe
```

Future members are absent from `ctx$members`, `ctx$universe`, positions, helper
dimensions, and public names until they become knowable and effective. A held
former member stays in `ctx$universe` so positions, `ctx$hold()`, `ctx$vec`, and
the target validator continue to share one aligned domain. Cross-sectional
membership operations use `ctx$members`, not all held IDs. A ticker change does
not change the stable ID. `ctx$state(id)` (name illustrative) exposes
membership, observation, valuation, execution, and feature reasons for IDs in
`ctx$universe`; it is not a raw vendor-label API.

### 9.2 Full named targets under changing eligibility

The full-vector invariant evolves narrowly from "match the fixed experiment
universe" to "match this pulse's explicit `ctx$universe`". The strategy must
still return every name exactly once with a finite quantity. Missing names are
still errors and never mean zero.

For a current member, any finite target may proceed to risk and execution
eligibility. For a held-but-inactive instrument, the proposed allowed target
is either the current quantity (hold) or zero (request liquidation). Increasing
or opening an ineligible position is rejected before risk. A zero target does
not promise a fill: if no eligible execution price exists, the engine records
a classified non-order execution diagnostic and the position remains held.

An unheld non-member is outside `ctx$universe`; attempting to name it is an
extra-target error. Targets are never silently ignored or forced to zero.

The response should attack whether one pulse-dependent aligned universe plus a
member subset is the right public shape, especially for cross-sectional
strategies and state carried into a test fold. Any accepted change must update
the strategy contract explicitly; it cannot be smuggled in through a matrix
helper.

## 10. Calendar and Expected-Observation Semantics

### 10.1 Ownership

- The experiment/run plan owns the ordered global pulse calendar and its
  identity.
- A versioned calendar source owns per-market scheduled sessions and closures.
- A versioned expectation policy combines market calendar, instrument
  calendar assignment, lifetime evidence, membership, data frequency, and
  source coverage to classify whether an observation was expected.
- Observation validity policy decides whether a present row is accepted. It
  does not decide whether the row should have existed.

The first implementation may support one EOD calendar. Its schema and
identity must nevertheless allow each instrument to reference a calendar and
allow a global pulse to be the ordered union of relevant market sessions.
The relevant calendar set must be declared independently of future universe
membership, or its activation must itself be as-of knowable. Constructing
earlier pulses from every venue or instrument that will eventually appear in
the bounded window would leak future membership even if future IDs were hidden
from the strategy.

### 10.2 Required distinctions

A scheduled closure is `not_expected`, not a missing bar. An instrument may be
an active universe member at a global pulse when its market has no expected
session; it remains visible with no fresh observation and is not executable on
that market. Conversely, `expected` plus no accepted observation is an
explicit unresolved or confirmed absence, never silently converted to a
closure or fill.

Whether a source can elevate "unresolved absence" to "confirmed expected-
session absence" is an evidence question. The current empirical spike did not
demonstrate such a cell.

## 11. Indicator, Transformation, and Strategy Dependency Graph

One universal imputation hook is rejected. The proposed engine uses a typed,
acyclic transformation graph:

```text
sealed source facts
  -> as-of classifications and expected-session state
  -> causal source-domain transforms
  -> indicators / derived features
  -> optional feature-domain transforms or fitted preprocessing
  -> pulse-specific strategy view
  -> full named targets
  -> target risk
  -> timing proposal
  -> execution-eligibility check + execution price
  -> cost resolution
  -> fill events
  -> valuation policy + event-sourced accounting
```

Preprocessing can occur before an indicator (for example, a declared causal
source-domain transform) or after indicators (for example, fold-fitted
cross-sectional feature preprocessing). Therefore each node needs at least:

- input and output domain;
- deterministic or fitted execution kind;
- as-of rule and lookback;
- missing-state contract;
- fit scope, if any;
- stable implementation and parameter identity; and
- permission boundaries for valuation and execution use.

Cycles are invalid. A node cannot read a descendant, a future pulse, a test
row during training fit, or a valuation-only mark unless its declared input
domain permits it. No node fills implicitly.

Indicators receive aligned observed/transformed numeric series plus explicit
state for their declared source domain. They do not receive future IDs.
Strategies receive current features, current public IDs, positions, and
classified state; they do not receive the next execution bar. The fold-local
materializer owns alignment. Indicator functions own computation, not axis or
calendar construction.

Membership start and admissible feature-history start are independent. An
index entrant may have valid, point-in-time-knowable observations before its
membership begins, while an IPO may not. A future design may compute such
history internally under an identity-bound source-domain rule, but it must not
expose the future member ID early. The warm-up contract must name which history
is admissible rather than assume that membership and existence begin together.

## 12. Simple Versus Walk-Forward Preprocessing

The following categories must remain distinct:

| Category | May alter raw facts? | Fit scope | May price execution? |
| --- | --- | --- | --- |
| Raw missingness | No; preserved | None | No |
| Deterministic causal transform | Derived only | None; as-of rule | No, unless it is a separately accepted execution-price rule (not proposed here) |
| Valuation-only stale mark | Derived only | Policy as of pulse | No |
| Feature warm-up | No value before declared readiness | Indicator history | No |
| Cross-sectional feature imputation | Derived feature domain | Declared pulse/training scope | No |
| Statistically fitted imputer | Derived feature domain | Training window/fold only | No |
| Model-native missing | Missing state delivered unchanged | Model contract | No |
| Label / terminal outcome | Separate than feature missingness | Outcome policy | No |

For a simple backtest, an as-of-safe deterministic transform may be computed
for the hydration window and reused. A fitted transform still needs an
explicit training boundary; "the whole backtest" is not an acceptable
implicit fit set if its output is used to claim out-of-sample evidence.

For walk-forward, fit-capable nodes are fit only on the fold's training rows,
freeze a fitted-state artifact, and transform the associated test window
without refitting. A globally fitted post-snapshot imputation artifact would
leak test information and violate the accepted train/test separation. This is
a proposed rule for response-stage attack; this RFC does not select an
imputation algorithm.

Deterministic as-of-safe transforms may be materialized in DuckDB when keyed
to the source, universe, calendar, classification, transformation, and bounded
range identities. Fitted transforms additionally require training window,
fold, recipe, and fitted-state identity.

## 13. Valuation and Execution Semantics

Availability is fact; response is policy.

### 13.1 Valuation proposal

A held asset with no fresh accepted observation may use the most recent prior
accepted mark only when an explicit valuation policy permits it. The resulting
mark is `stale`, carries its source timestamp and age, and is visible as stale
to risk and reporting. It is not relabeled current.

If no permissible mark exists, the position is `unpriced`. The engine must not
coerce its value to zero. Whether an unpriced position aborts the run,
continues with restricted metrics, or uses an explicit recovery/terminal value
is left unresolved for response and the accounting sibling. Any chosen policy
must be identity-bearing and fail closed for performance claims it cannot
support.

Risk calculations that consume stale marks must declare that permission and
the maximum admitted age. A risk rule that requires fresh prices fails or
classifies the target; it cannot unknowingly consume a carried value.

### 13.2 Execution proposal

Execution requires a separate eligible observed execution price at the timing
model's execution pulse. A stale valuation mark, feature-imputed value, or
synthetic alignment value is never executable by default.

If a target is submitted and the next required execution bar is unavailable,
the pre-OMS behavior is:

1. retain the valid strategy and risk outputs as evidence;
2. create no fill;
3. record an explicit, reason-coded non-order execution diagnostic; and
4. carry no invisible order to a later pulse.

The exact persisted representation of that diagnostic remains unresolved. It
must not be a durable pending order or otherwise create OMS semantics by name
or behavior.

A known halt or non-orderable state fails execution eligibility even if a
valuation mark exists. On resumption, a new strategy target may create a new
execution attempt. Persistent orders, good-till-cancelled semantics, and
partial fills remain OMS work.

Delisting or permanent unavailability is not merely "stale forever". It must
route to the accounting-critical-event boundary in Section 15.

## 14. Identity, Provenance, and Cache Invalidation

### 14.1 Proposed identity layers

| Identity layer | Proposed contents | Invalidates |
| --- | --- | --- |
| Snapshot identity | Canonical sealed source facts: stable instrument records, observations, effective-dated source facts, and any calendar/membership facts stored in the snapshot | Every downstream artifact |
| External lineage | Provider/product/release, extraction query/code identity, source checksums, revision/as-of cutoff, and license-safe provenance; represented by a sealed manifest digest | Snapshot trust/reconstruction; included by reference in semantic snapshot identity |
| Universe construction | Universe definition, membership source, effective/knowledge-time rule, filters, and implementation identity | Decision frames, runs, sweeps, folds |
| Availability classification | Policy code/version, reason taxonomy, source inputs, and parameters | State planes and all consumers |
| Calendar | Calendar source/version, market assignments, frequency, timezone/session rules, and global-union rule | Pulses, expectation state, materializations |
| Valuation policy | Mark source hierarchy, stale-age rules, unpriced behavior | Risk inputs, accounting, metrics, run identity |
| Execution policy | Timing model plus eligibility rule/reasons; cost remains its accepted separate identity | Intents, fills, run identity |
| Indicator / feature | Existing code/parameter/warm-up fingerprint plus declared input domain and missing-state contract | Feature series |
| Deterministic materialization | All upstream hashes, node graph, implementation, bounded range, axis ordering, and engine version | Cached derived values/state planes |
| Fold-fitted preprocessing | All deterministic inputs plus train bounds, fold ID, recipe, hyperparameters, random seed, fitted-state digest, and software identity | Fold transforms and model inputs |
| Run / sweep | Snapshot and all semantic policy/materialization identities, strategy/risk/cost/timing identity, range, seed, and opening state | Run/sweep replay identity |
| Walk-forward session / fold | Session fold definitions and all run identities, including each fold's fitted artifacts | Session reopen, selection, and promotion |

External lineage can remain a separate manifest for access control and storage
practicality, but its digest must be sealed into the semantic identity used by
ragged runs. A mutable un-hashed sidecar is insufficient when it supplies PIT
membership or classification facts. This conclusion uses the Sharadar sidecar
limitation as evidence; it does not prescribe that source's schema.

### 14.2 Invalidation rules

Any changed upstream hash creates a different downstream key. Cache lookup
must compare the complete typed dependency identity, not filename, timestamp,
or row count. A fitted artifact cannot be reused across folds merely because
its recipe matches. Promotion and reopen must verify all linked identities.

Existing dense snapshots remain reproducible under their current hash rules and
are interpreted only through `dense_static`. They are not retroactively
assigned fabricated membership or lifetime facts. A migration tool may later
create a new ragged-capable snapshot with new identity; it must not rewrite the
old one.

## 15. Accounting-Critical-Event Boundary

This RFC treats the accounting-critical-event RFC as a **coordinated sibling**,
with a conditional release prerequisite.

The availability substrate may store or expose source facts concerning
dividends, distributions, delisting, bankruptcy, recovery, mergers,
acquisitions, ticker changes, and terminal settlement. It does not define
their ledger effects. Stable identity and effective-dated aliases belong here;
cashflows, position conversions, recoveries, and terminal settlement belong to
the accounting sibling.

An initial ragged implementation can support IPOs, PIT membership, calendars,
and temporary observation/execution states without solving every accounting
event. It must classify an unresolved terminal situation and prohibit claims
that require a resolved terminal payoff. Any release that permits a held
instrument to cross a known delisting, merger, bankruptcy, or distribution
event is gated on the accounting sibling's accepted semantics and fixtures.

This avoids making the full accounting RFC a prerequisite for all useful
ragged work while preventing "indefinitely stale" from becoming accidental
terminal accounting.

## 16. Dense-Mode Parity and Migration

The accepted current complete-panel behavior is the oracle for the proposed
`dense_static` semantic-mode name. It must produce bit-identical or explicitly
approved equivalent artifacts for existing complete snapshots:

- fixed configured universe and internal axis;
- pulse calendar derived exactly as today;
- complete accepted bars at every pulse;
- current indicator fingerprints and warm-up behavior;
- full targets matching the fixed universe;
- current valuation and next-open behavior; and
- current run, sweep, saved-sweep, promotion, and walk-forward parity.

The new mode is explicit. Opening an old snapshot does not infer unknown
lifetime intervals, membership streams, or missing-row classifications.
Existing tests remain the dense oracle. New ragged tests supplement rather
than weaken them.

Because ledgr is pre-CRAN and has no external consumers, this is not a public
backward-compatibility promise. The eventual specification may introduce clean
constructors and identity versions. Dense parity remains load-bearing for
internal reproducibility, semantic comparison, and old artifact verification.

## 17. Performance and Resource Implications

Performance is a design constraint, not a result established by the research
timings. Before synthesis selects the physical representation or public
strategy shape, the architecture spike in Section 7 must provide comparative
evidence. Any later implementation therefore requires:

- sparse canonical storage when absent instrument-session cells carry no fact;
- interval/effective-dated membership operations in DuckDB rather than a
  permanent complete instrument-by-session table;
- bounded set-wise materialization for one run/fold hydration window;
- vectorized matrices and compact state planes inside hot indicator, strategy,
  risk, and valuation paths;
- no per-instrument database query or R loop on every pulse;
- deterministic axis ordering and reusable causal-transform caches;
- the same materializer and fold executor for run, sweep, and walk-forward;
  and
- explicit memory budgets and spill/failure behavior.

A later implementation packet needs deterministic benchmarks covering:

1. dense parity at current fixture sizes;
2. increasing instruments, pulses, membership churn, and sparsity separately;
3. snapshot/open/seal/classification and frame-materialization time;
4. peak process memory and materialized-frame memory separately;
5. indicator, simple-run, sequential-sweep, parallel-sweep, and walk-forward
   execution on the same semantic fixture;
6. cache cold/warm behavior and invalidation cost; and
7. equality of outputs across reused and recomputed materializations.

No target latency, memory advantage, or competitor comparison is claimed by
this seed.

## 18. Mandatory Scenario Matrix

Every row is a proposed behavior unless its final column says otherwise.

| Scenario | Snapshot representation | Indicator input | Strategy visibility | Valuation behavior | Execution behavior | Identity / provenance consequence | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1. IPO halfway through a backtest | Stable ID plus unknown/inactive lifetime before listing, effective-dated membership, observations only when present | No pre-listing series; warm-up begins from admissible history | ID absent before effective membership; enters `members` and `universe` afterward | No pre-listing mark | No pre-listing target or fill | Lifetime, membership, calendar, and universe-construction hashes enter frame/run identity | Proposed |
| 2. Delisting while held | Held ID, membership/lifetime change, source terminal facts retained | State changes; no fabricated post-event bars | Leaves `members` but remains in `universe` and aligned positions while held | Stale/unpriced only under explicit interim policy; terminal value requires sibling | Zero target can request liquidation only if an eligible price exists; no invisible order | Terminal source provenance and accounting-event identity required for resolved performance | Partly proposed; payoff unresolved pending accounting sibling |
| 3. Unexpected missing daily bar during known active lifetime | `expected` with absent/invalid observation and reason/evidence | Missing state or declared causal transform; never implicit fill | Member remains visible with missing-state reason | Prior mark may be stale under policy | No execution from stale/imputed value | Availability-policy and valuation-policy hashes change artifacts | Proposed; empirical frequency not established |
| 4. Several-session trading halt | Source halt facts plus ledgr execution classification | Observed data and explicit halt state; features follow declared missing contract | Member visible; non-orderable | Named stale-mark policy may continue with increasing age | Record each failed execution attempt; a later target is evaluated anew | Halt source, classifier, valuation, and execution identities recorded | Proposed |
| 5. Two instruments using different calendars | Per-instrument market assignment and versioned calendars | Aligned global pulses with `not_expected` states on local closures | Both may remain members; state distinguishes local closure | Latest permissible mark may be stale on other-market pulses | Only instrument whose market/price is eligible may fill | Both calendar hashes and global-union rule enter identity | Proposed concept; first implementation calendar scope deferred |
| 6. Held position with only a stale prior close | Prior accepted observation plus current no-fresh-observation state | Stale valuation is not an indicator source unless declared | Held ID remains visible with mark age | Value with explicit stale flag/age or become unpriced at policy boundary | Stale mark cannot execute | Valuation-policy hash affects risk, accounting, metrics, and run | Proposed; default age/error policy unresolved |
| 7. Target before a missing next execution bar | Decision facts and next-pulse expected/absent state remain separate | Decision pulse unchanged | Valid target produced for current member | Current position valued independently | No fill; explicit reason-coded non-order diagnostic; no later carry | Execution-policy identity and diagnostic retained | Proposed |
| 8. Ticker change, identity continues | Stable ID with effective-dated aliases | Continuous history by stable ID, with adjustment/accounting rules separate | Same ID; current alias is presentation only | Continuous if accepted marks exist | Eligibility follows stable ID and venue facts, not string equality | Alias provenance included in snapshot facts; no new position identity | Proposed |
| 9. Feature warm-up after listing or membership entry | Listing/membership facts plus point-in-time-admissible observations | Explicit `warmup` until the declared history requirement is met; pre-membership history may be used only under an identity-bound source-domain rule | ID is not publicly visible before membership; feature state says unavailable until ready | Unrelated valuation can be fresh | Execution allowed only if strategy/risk can act without invalid feature | Indicator fingerprint and admissible-history rule identify readiness | Proposed |
| 10. Cross-sectional model with changing membership | PIT membership and sparse observations | Pulse-specific member rows/masks; fitted universe cannot see future IDs | `members` contains current knowable members; `universe` additionally retains held former members | Per-held-position policy | Only currently eligible IDs | Universe construction, per-pulse membership query, feature/model identity | Proposed; public modeling API deferred to ML RFC |
| 11. Fold-fitted imputation in walk-forward | Raw observations/missing states unchanged | Fit on train only; frozen fitted state transforms test | Test strategy sees transformed features and provenance, not test-informed fit | No effect on execution/valuation prices | Imputed features never executable | Fold/train bounds, recipe, seed, software, and fitted-state digest enter identities | Proposed; algorithms deferred |
| 12. Dense complete snapshot | Existing instrument/bar payload unchanged | Existing aligned matrices and warm-up | Existing fixed `ctx$universe`; proposed `ctx$members` is identical | Current fresh-close behavior | Current next-open/final-pulse behavior | Existing snapshot/run identities remain verifiable under the proposed `dense_static` name | Proposed parity requirement |

## 19. Failure Modes and Forbidden Behavior

An implementation derived from this RFC must fail review if it:

- reveals a future instrument ID to a strategy or fitted transform;
- collapses lifetime, membership, expectation, observation, valuation,
  execution, and feature state into `NA` or one `gap_type`;
- treats unknown evidence as known absence or known activity;
- treats a scheduled closure as a missing expected observation;
- turns a stale, imputed, or synthetic value into an execution price without a
  separately accepted explicit execution rule;
- values an unpriced holding at zero without an accounting event;
- silently carries an unfilled target as a persistent order;
- treats omitted targets as zero or ignores extra targets;
- lets test-window values fit preprocessing used in that test window;
- permits cache reuse after any semantic dependency changes;
- creates a second ragged execution engine for sweep or walk-forward;
- mutates or bypasses a sealed snapshot;
- rewrites existing snapshot identity during migration;
- maps vendor action labels directly to ledger event types;
- reports unresolved terminal assets as valid complete performance; or
- claims broad-equity, dividend, terminal-event, or ragged-runtime validity
  from the bounded Sharadar evidence.

## 20. Acceptance-Criteria Sketch

This is not an implementation ticket list. A later accepted synthesis and
specification should make at least these criteria mechanical:

1. A vendor-neutral schema expresses every state in Section 5, including
   unknown and source/classification separation.
2. A current dense fixture reproduces the accepted dense oracle across run,
   sweep, saved-sweep promotion, and walk-forward.
3. Future membership cannot be observed through public context, feature
   access, dimensions, names, diagnostics, or timing.
4. A pulse-specific `ctx$universe` preserves exact full-name target validation,
   stays aligned with positions and helpers, distinguishes `ctx$members`, and
   exposes held former members without permitting new ineligible exposure.
5. Calendar fixtures distinguish scheduled closure, no expected session,
   expected-but-absent, present-but-rejected, and present-outside-expectation.
6. The twelve scenarios in Section 18 have deterministic fixtures, with
   unresolved terminal economics asserted as blocked rather than fabricated.
7. Valuation age and execution eligibility are independent, inspectable, and
   identity-bearing.
8. Missing next execution data produces no fill and no persistent hidden
   order, but preserves a reason-coded diagnostic.
9. A fold-fitted preprocessing fixture proves that changing test data cannot
   change fitted state and changing training data invalidates it.
10. Cache mutation tests cover snapshot, lineage, universe, calendar,
    classifier, transform graph, fold, fitted state, valuation, and execution
    policy changes.
11. The one fold core produces parity across simple runs, sequential and
    parallel sweeps, and walk-forward.
12. Benchmarks report time, peak memory, frame size, sparsity, and cold/warm
    cache behavior without performance claims beyond measured fixtures.
13. Held terminal-event scenarios cannot pass final performance validation
    until the accounting sibling supplies accepted event semantics.
14. Documentation states the evidence limits and does not teach forward-filled
    values as executable prices.
15. Before synthesis selects a physical schema, state encoding, or public
    strategy API, the comparative architecture spike in Section 7 records its
    fixtures, parity results, failure evidence, runtime, and peak memory.

## 21. Decisions, Deferrals, and Unresolved Questions

| Question | Proposed | Rejected | Deferred | Unresolved |
| --- | --- | --- | --- | --- |
| Storage representation | Sparse canonical facts and effective-dated state | Complete superset panel as sole canonical form | Exact DuckDB schema | Interval versus event encoding details |
| Runtime representation | Bounded dense numeric planes plus orthogonal state planes | Plain `NA` matrix; second engine | Optional later hybrid/event optimization | Exact mask encoding |
| Public universe shape | Pulse-dependent `ctx$members`; aligned `ctx$universe` is members union held IDs and remains the position/target domain | Public future superset; a separate target-only alignment domain | Final API names | Exact member/state accessor ergonomics |
| Availability taxonomy | Orthogonal vendor-neutral classifications with unknown | One overloaded `gap_type` | Final enums | Minimum extensibility mechanism |
| Valuation policy | Explicit fresh/stale/unpriced result with age | Zero value or silent carry | Built-in policy catalog | Default stale-age and unpriced-run behavior |
| Execution policy | Eligible observed price only; unavailable next price records no fill and no carried order | Execution from stale/imputed values; invisible GTC | OMS persistence and partial fills | Exact diagnostic/event representation |
| Deterministic materialization | As-of-safe typed DAG, fully identity-keyed | Implicit/global filling | Physical persistence strategy | Which transforms ship built in |
| Fold-fitted preprocessing | Fit per training window/fold; hash fitted state | Global post-snapshot fitted artifact | Algorithms and ML API | Artifact serialization contract |
| Dense-mode parity and migration | Introduce `dense_static` as the explicit name for the current complete-panel parity oracle | Automatic reinterpretation/migration | Sunset, if ever | Bit-identical versus approved semantic equivalence for newly versioned metadata |
| Accounting-event boundary | Coordinated sibling; required before held terminal events claim resolved performance | Treat terminal event as missing bar | Full accounting event semantics | Minimum blocker representation before sibling lands |
| Multi-calendar scope | Conceptual support and identity now | Calendar inferred solely from observed bars | First supported market/frequency set | Global pulse union details around simultaneous/overnight sessions |
| Live/streaming degradation | Keep separate from offline ragged research | Reuse this seed as live late/duplicate/revision policy | Dedicated live RFC | None in this cycle |

Open spec-cut questions are the unresolved cells that the response and Seed v2
can narrow without new external research. Future obligations are the deferred
OMS, live-stream, ML API, full accounting-event, and broader multi-calendar
surfaces; they belong to named later RFCs, not hidden promises in this seed.

## 22. Recommended Response-Stage Attacks

The independent response author should try to falsify the proposal at these
seams:

1. **Pulse-domain evolution:** Can `ctx$universe = members union holdings`
   preserve one-domain alignment for positions, helpers, exact targets, risk,
   and walk-forward opening positions while giving cross-sectional code a
   clean member-only view?
2. **Future-ID leakage:** Can internal axis dimensions, cache keys, diagnostics,
   or cross-sectional transforms reveal future membership even when names are
   hidden?
3. **State independence:** Are lifetime, membership, expectation, observation
   quality, valuation, execution, and feature validity truly independent, or
   are necessary states/illegal combinations missing?
4. **Calendar construction:** Does a global union calendar remain deterministic
   and causally knowable for different venues, unscheduled closures, and EOD
   timestamps?
5. **Materialization DAG:** Can before-indicator and after-indicator transforms
   share one typed graph without cycles, accidental price filling, or
   unbounded cache identity?
6. **Walk-forward fit isolation:** Is the proposed fitted-state identity enough
   to prevent train/test contamination across candidates, folds, resumes, and
   parallel workers?
7. **Valuation/accounting hole:** What exact fail-closed behavior is required
   when a held instrument is unpriced, and can metrics remain internally
   consistent before terminal-event semantics exist?
8. **Pre-OMS diagnostic semantics:** What is the smallest honest non-order
   record for unavailable execution, and how does it avoid accidentally
   creating an order model?
9. **Snapshot lineage:** Should the lineage-manifest digest be inside a new
   snapshot hash, a separate required semantic identity, or both?
10. **Performance:** Does fold-local densification remain bounded under a broad
    sparse universe, and which operations risk per-pulse R work?
11. **Dense parity:** Can the new materializer be introduced without changing
    current dense results, warnings, hashes, saved sweeps, and promotion?
12. **Evidence discipline:** Does any proposed default outrun the empirical
    record, especially ordinary gaps, imputation, terminal events, or
    multi-asset execution?
13. **Architecture-spike sufficiency:** Are the four comparative prototypes and
    their fixtures enough to select storage, state-plane, and public-context
    shapes, or would the spike merely benchmark accidental implementations?

## 23. Suggested Remainder of the RFC Cycle

Follow `../rfc_cycle.md` without collapsing roles:

```text
Seed v1 (this document)
  -> adversarial response by a different author
  -> review of that response
  -> bounded comparative architecture spike on storage, state encoding, and
     public-context choices
  -> Seed v2 resolving or preserving each attack
  -> maintainer decisions only for irreducible product choices
  -> synthesis by an eligible different author
  -> final review
  -> horizon update
```

No implementation specification or tickets should be cut from Seed v1. The
response should cite current code/tests and primary sources, distinguish a
design defect from a product choice, and preserve all empirical limitations.

## 24. Revision History

| Date | Stage | Author | Change |
| --- | --- | --- | --- |
| 2026-09-07 | Seed v1 | Codex | Opened the non-binding RFC cycle; integrated the three staged research inputs, current code/test audit, preferred sparse-storage/fold-local-materialization direction, scenario matrix, and response attack surface. |
| 2026-09-07 | Seed v1 refinement | Codex | Corrected snapshot-hash and coverage-gate details; preserved one aligned strategy/position/target domain; added future-calendar and pre-membership-history guards; made the preferred architecture conditional on a comparative spike; and clarified dense parity, pre-OMS diagnostics, evidence limits, and sibling accounting scope. |

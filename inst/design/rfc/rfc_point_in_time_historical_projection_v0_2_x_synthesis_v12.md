# RFC Synthesis v12: Causal Historical Research Surface

Role: record; accepted RFC-cycle synthesis and implementation authority.
Status: accepted by the maintainer on 2026-10-16; H5 ticket cut is current.
Authority: accepted synthesis. This document supersedes v11 within its stated
scope; v11 remains the derivation record.

**Mode:** Decision synthesis. **Author:** Codex, at maintainer request.
**Date:** 2026-10-16.
**Inputs:** accepted v11, the reviewed current-tree drift map, the completed
history-wave decision register, its H0-H2 evidence, and the post-Cut-15 tree.
The register's two focused peer-review passes found no remaining evidence gap.

This RFC uses "v1" as shorthand for the first implementation of the causal
history surface. ledgr's roadmap does not have a history-v1 milestone.
Post-v1 work lives in the named follow-up routes in Section 11.

## 1. Decision and scope

Ship one point-in-time historical research surface on the availability path.
It gives a strategy causal bar or feature history, explicit missingness and
estimation exclusions, and an identity-preserving matrix bridge for ordinary R
estimators. The intended flow is:

```text
causal history -> ordinary R estimator -> identified weights
               -> target intent -> execution and accounting
```

History is availability-only. A fixed basket or all-snapshot-instruments
request is the full-membership availability shape. Dense mode is frozen: this
RFC adds no dense history branch and does not alter its current inspection
path. Dense leaves through the separately accepted execution-core
consolidation before the first CRAN release.

The first implementation includes:

- one history start at the beginning of the available data;
- one public frame helper and one adapter over its result;
- one common venue-session axis plus per-instrument expected-session masks;
- point-in-time facts under effective and knowledge clocks;
- declared price-input and indicator-output treatment;
- bounded and history-dependent indicator semantics on ragged data;
- parity across runs, sweeps, walk-forward and availability-aware inspection;
  and
- one immutable prepared substrate shared inside each owning execution.

It does not add portfolio replay, fitted-model lifecycle, a feature artifact
store, a process cache, a multi-feature tensor, scheduling, an optimizer
catalogue, durable prediction evidence or a generic executor abstraction.

## 2. Information and execution ownership

For a decision cutoff `t`, every returned historical value at column `s`
satisfies `s <= t`. Facts must be both applicable at `s` and knowable at `t`.
Seal time, wall-clock time and final snapshot truth never substitute for either
clock. Later-known evidence cannot affect an earlier returned object, its
error, treatment decision or exclusion reason.

The existing family authority remains the only resolver. Precedence,
completeness, supersession and family declaration are not reimplemented in the
history helper. Facts without a knowledge clock use the accepted
known-when-effective assumption and disclose it. Interval membership remains
single-clock; complete membership snapshot sets remain the two-clock path.

History and every indicator start at the data start for runs, sweeps,
walk-forward windows and inspection. Decisions still occur only on scoring
pulses. The implementation retires or replaces the temporary scoring-start
hydration seams, including `hydration_start_utc`, its stored fold column,
`ledgr_unsupported_hydration_start`,
`ledgr_precomputed_hydration_mismatch` and the precomputed payload's separate
warm-up start. No replacement may create a second history start.

Ownership follows the accepted fold envelope:

- envelope preparation builds immutable history inputs and services;
- P1 observe-and-settle is the sole fold-stage reader of history-derived
  typed values;
- P2 constructs the requested public history value as a local boundary
  object; and
- P3 through P5 receive no history frame and no mutable substrate reference.

No callback issues history SQL, rebuilds fact segments or recomputes a whole
panel. No data frame becomes a stage argument or carrier slot. Run, sweep and
walk-forward retain one execution path.

## 3. Public history surface

The public reader is `ledgr_history_frame()`, used as an exported helper over
the current strategy context. Exactly one of `feature` and `bar` is supplied:

```r
returns <- ctx |>
  ledgr_history_frame(
    feature = "daily_return",
    lookback = 252L,
    instruments = "admissible",
    na_action = "drop_instruments",
    layout = "wide"
  )

x <- ledgr_history_matrix(returns)
```

Feature names use the accepted active-alias-first, then concrete-ID rule. Bar
names use the sealed closed bar-field vocabulary. One call reads one numeric
series; multi-feature joins and tensors are outside this surface.

The result is a classed `ledgr_history` value. It retains:

- the ordered time axis and instrument identities;
- the data start, returned-window start and causal cutoff;
- requested and available lookback;
- the source feature or bar identity and treatment policy;
- requested, included and excluded instruments, with every exclusion reason;
- aligned missingness and carry evidence; and
- whether any returned value used observations or state before the returned
  window.

The ordinary defaults are `lookback = Inf`,
`instruments = "admissible"`, `na_action = "keep"` and `layout = "wide"`.
Finite lookback counts expected venue sessions on the common axis, oldest to
the cutoff. `Inf` requests all permitted history from the data start. A shorter
lookback is a suffix of that one causal preparation; it is not independently
seeded. The before-window-state flag applies to bounded and
history-dependent values alike.

`instruments` accepts:

- `"admissible"`, the default estimator set at the cutoff;
- `"decision_axis"`, including held nonmembers; or
- an explicit character vector of known instrument IDs.

Unknown explicit IDs refuse. Explicit known IDs are not silently dropped for
current inadmissibility. `na_action = "drop_instruments"` may exclude an
included request from the estimator sample for incomplete values; it records
the reason. Estimation exclusion never creates a zero target or liquidation.
An instrument excluded from the estimator sample still receives a target from
the strategy like every universe member; exclusion itself produces no target
and is not a liquidation.

Wide layout is pulses by instruments with explicit `ts_utc`. Long layout has
at least `ts_utc`, `instrument_id`, source identity and value. The exact
evidence-column names are a spec-cut naming question; their meanings are
bound here. `ledgr_history_matrix()` accepts only an already-constructed
history result, excludes the time key, preserves included-instrument identity
and owns no cutoff, axis, treatment or missingness logic. It is not a reader.

Returned objects are fresh immutable values. Equal cutoff, policy, source and
selection give equal scalar, frame and matrix values. Query order cannot
change them, and a later cutoff cannot mutate an earlier result.

Structural completeness is separate from indicator readiness. The surface
must answer whether a finite requested lookback and minimum included-instrument
count are present. The exact helper name is promoted to the spec cut; it may
not be named or taught as indicator warm-up or convergence.

## 4. Axis, civil time and point-in-time facts

The public time axis is the declared venue's ordered expected sessions through
the cutoff. Each instrument has a cutoff-resolved expected-session mask aligned
to that common axis. Windows never count each instrument's last `N`
non-missing observations.

Lifetime-inactive absence is structural, not a missing observation. A
trading-status halt remains a gap. A real print stored inside a knowable
lifetime-inactive interval remains readable through bar history with an
explicit structural flag and inclusion/exclusion evidence, but enters no
indicator computation segment and supplies no valuation mark. Membership at a
past column does not by itself erase an otherwise admissible observation.

On availability-aware inputs a `Date` is a venue civil-session label:

- `effective_from` resolves to that session's open;
- exclusive `effective_to` resolves to that date's session open;
- a knowledge Date resolves to that session's open, making the fact knowable
  by its close;
- a window start Date selects session open; and
- a window end Date selects session close.

`POSIXct` remains an exact instant. A Date that does not resolve to exactly one
declared session refuses. Stored facts retain the original value, resolved
instant, venue zone and calendar identity. Dense UTC-midnight behavior is
unchanged.

Trading-status correction chains obey one rule in construction, validation,
ingest classification and runtime:

1. A successor's knowledge time is not earlier than its direct predecessor's.
2. It starts no later than the predecessor's end and covers the predecessor
   from the successor start through the predecessor end; it may start earlier
   or extend later.
3. Before successor start the predecessor remains valid; afterwards it never
   revives. A successor ending before the predecessor refuses.
4. Supersession is applied before ordinary precedence.
5. Only direct and transitive ancestor/descendant pairs receive the
   supersession exemption. Siblings and unrelated descendants compete
   normally; a tied contradiction refuses.
6. Cycles and dangling predecessor references refuse.

The existing constructor's same-source lookup remains the source boundary.
These rules land as a small facts prerequisite before the history substrate,
with the reviewed ten-shape vendor-neutral matrix as the semantic oracle.
Sharadar has no trading-status facts and is regression evidence only.

A corporate-action row with no clock at all is audit-only and never due. A row
with an event clock but no knowledge clock follows the known-when-effective
assumption. A row with knowledge time but neither entitlement nor effective
clock refuses preparation at every cutoff on or after knowledge with
`ledgr_corporate_action_clock_missing`, parent
`ledgr_invalid_corporate_action_event`. It carries `fact_id`,
`parent_instrument_id`, `knowledge_time`, `entitlement_time` and
`effective_time`; its message directs the caller to supply a clock or
quarantine the row.

## 5. Missing data, carry and disclosure

One experiment-level history policy owns treatment. Its first implementation
has these defaults:

- price-input carry is enabled with `max_sessions = 5L`;
- indicator-output carry is disabled and, when enabled, requires its own
  finite maximum age; and
- `segment_limit = NULL` selects the default preparation guard in Section 7.

The public constructor name is a spec-cut naming question; the policy is
canonical config input and is not callback state.

Price-input carry treats each OHLC field independently, from the latest
admissible earlier observation of the same stable instrument. It never carries
volume, never fills backward, never invents a leading value, never refreshes
source age and never inserts closed-day columns. Age counts expected venue
sessions from original source to delivered column. Expiry returns missing.

Indicator-output carry occurs after input treatment and calculation. Turning
one carry stage off never turns the other on. Only a later gap caused by an
unavailable required input, after readiness, calculation and an admissible
earlier output, is eligible. Warm-up, failed readiness, errors and unsupported
calculation never become fillable merely because their result is `NA`.

Carry observes facts knowable at the request cutoff and the whole
source-to-destination path:

- a `known_inactive` lifetime interval blocks carry across it;
- declared or assumed-default `split_adjusted` bars add no corporate-action
  carry barrier; omitted basis remains `NULL` in identity but is economically
  and visibly the assumed `split_adjusted` model;
- `distribution_adjusted` remains unsupported for execution; and
- a knowable terminal assertion permanently blocks carry from its boundary,
  even if later real observations exist.

After a nonterminal barrier, a new real observation may seed later carry when
no later barrier is crossed. Treatment never quarantines or fabricates a
source observation.

History treatment changes only the returned history values and their aligned
evidence. It never changes facts-based membership or admissibility, trading
permission, a valuation mark or an execution price. Declared treatment may
change history completeness and therefore whether the documented `na_action`
filter retains an otherwise admissible instrument in the estimator sample.
That filtering is not facts-based admission. In particular, a history-carried
close cannot refresh the valuation plane.

Return- and volatility-family features never consume carried prices. Their
output is missing whenever required inputs are missing or carried. V0.2.2
ships no silent multi-session bridge labelled as a one-session return. A
single missing session can therefore remove an instrument from a complete
252-session estimator sample for 252 sessions. That consequence is disclosed,
not hidden. A span-labelled bridged-return feature is deferred under the
reopening rule in Section 11.

Aligned evidence distinguishes at least:

- original and remaining missingness;
- direct observations, carried inputs, calculated values and carried outputs;
- source time and carry age;
- warm-up, structural absence and later gaps;
- applicable barrier or exclusion reason; and
- count and share of required inputs carried for finite windows.

No universal usable flag replaces these distinctions. Fitted imputation and
consumer-specific filtering remain outside this RFC.

## 6. Indicator history classes

Every supported feature is either `bounded` or `history_dependent`.
`gap_contract = "strict_window"` implies bounded; contradictory declarations
refuse. A custom definition without a history-class declaration defaults to
disclosed `history_dependent`. Bounded is declared, never inferred.

Every definition declares the input fields it requires. Admission tests
exactly those fields after input treatment; an irrelevant missing OHLC field
cannot reject a close-only calculation. Readiness is evaluated on the treated
required inputs, and the engine imposes no maximum carried-share threshold.
Input admission, readiness, calculation validity and output-carry eligibility
remain separate states with separate evidence.

For bounded definitions:

- existing `requires_bars` is the dependency width and the window handed to
  `fn`;
- `stable_after` is the first-valid boundary and is at least
  `requires_bars`;
- the window counts expected sessions on the instrument's Section 4 mask; and
- an incomplete required window produces missing output.

No third width field is added. `stable_after` means first valid, not converged.
The teaching surface must say so and use the measured recovery ranges as
evidence rather than promising convergence.

This deliberately changes custom definitions where `stable_after` exceeds
`requires_bars`: the current scalar path hands `fn` `stable_after` rows, while
v12 hands it exactly `requires_bars`. Bundled built-ins set the two values
equal and therefore do not change on this boundary.

A history-dependent feature runs once per contiguous segment of treated input.
Treated input includes observations plus policy-carried inputs, except for the
return and volatility families excluded in Section 5. A lifetime-inactive
interval splits a segment structurally. Halts and missing observations beyond
the carry horizon create gaps. The feature restarts and becomes first-valid
again after each gap. Restart rather than skip is the declared v0.2.2 policy.

Registered TTR support is catalogued per function, selected output and
algorithm-changing argument. Each catalogue row records its TTR version and
is certified bounded or history-dependent by registered package tests on the
fixed hostile fixtures. An unregistered TTR form follows the custom-definition
rules rather than inheriting a family-wide class.

Causality and declaration are failure-sensitive:

- exact prefix invariance is checked once per concrete definition at fixed,
  deterministic positions before any artifact write;
- experiment-data window-versus-prefix refutation applies to custom bounded
  definitions that supply `series_fn`, comparing `fn(window_i)` with
  `series_fn(full_causal_prefix)[i]`; a definition with `fn` alone is bounded
  by the handed window and receives the prefix-invariance check;
- built-ins are exact;
- catalogue rows have no runtime product tolerance; their measured fixture
  drift is evidence, not a promoted threshold; and
- a custom definition is exact by default, while an explicitly declared
  nonzero tolerance enters its fingerprint.

A refusal is classed and names the definition, instrument, sampled position
and gap or mismatch. Causality checks may not turn into quadratic all-prefix
validation.

## 7. Prepared substrate and resource policy

Build one immutable substrate once per snapshot identity and history policy in
the owning run, sweep or walk-forward session, before any fold. Share its raw
evidence and every cutoff-invariant numerical series across that run, all
sweep candidates or all windows of that session. A numerical answer is reused
only when its admitted observations, axis, treatment and value are invariant
for the requested cutoff. It replaces, rather than accompanies,
`bars_by_id`, `bars_mat` and `static_bars_views`.

Where a supported late-known fact changes a historical mask, treated input or
output, preparation produces the cutoff-correct answer by the simplest
adequate method. Recalculating a complete affected series is permitted; fact
arrival alone does not require a second numerical copy. An earlier returned
history value and its evidence remain immutable. This rule selects neither
segmented numerical storage nor incremental invalidation as the implementation.

The substrate contains:

- bar and feature panels once, as observation-time columns on the common axis,
  with a knowledge-clock slot where supplied;
- flat bitemporal segment vectors per instrument and fact-state family;
- active, inactive, unknown and conflicting membership states; and
- family declaration and completeness apart from individual fact rows.

Adjacent fact-state segments merge only when state, winning fact and reason
all match. Equal visible states never erase selecting evidence. Candidate and
window cursors stay outside the immutable object. Reads are vectorised across
instruments; frame and matrix results are transient views, not retained copies
or independent readers.

Preparation counts segments by instrument and family and refuses above
`max(4 * facts, 16)`. The condition names instrument, family, fact count,
segment count and ratio; it never truncates. The canonical experiment history
policy field is `segment_limit`: `NULL` uses the formula and a declared finite
value replaces its numeric ceiling. An override enters config identity.
Preparation records aggregate and maximum counts per family. The full Sharadar
build must pass the default; refusal there is a defect in the default, not a
reason to weaken facts.

For local parallel sweeps, prepare candidate-invariant inputs once in the
parent and stage them once on each persistent daemon. Tasks carry only
candidate-varying fields and the expected staged-invariant identity. A daemon
refuses a missing or different invariant. Per-sweep daemons stop after success,
interruption or failure, preserving discard-all behavior. This is private
executor machinery and adds no public executor or dependency.

The supported availability-history claim covers one and two local workers.
Larger counts continue to run but are recorded as unmeasured. Worker count and
resource settings are evidence, never experiment, candidate or run identity.
V0.2.2 adds no `mori` dependency. H6 may reopen shared memory only if the
post-substrate trigger in Section 10 reaches 10%.

Preserve the full logical decision trace. It is streamed in bounded typed
chunks and is neither substrate nor worker payload. Sweep workers return
compact summaries. Physical trace compression waits until omitted rows can be
reconstructed exactly without changing `ledgr_run_explain()`.

## 8. Windows, continuity and inspection

`carry_test_state` represents one economically continuous test chain with
parameter changes at fold boundaries. The last decision of a window is
executed by that same run at the following venue open, preserving the
decision-to-fill join. The next window opens from the post-fill state.

Only economic state crosses the boundary: cash, positions, lot state, pending
corporate-action entitlements and frozen or stale mark status. Feature, mark
and entitlement history are read from the shared data-start substrate and are
never window-local. A corporate-action row is not rejected merely because its
posting pulse is in the next contiguous carried window. Standalone runs and
`flat_test_state` windows retain their existing terminal rule.

For a fold list and its selected parameters, concatenated carried test runs
must equal one public `ledgr_run()` whose strategy changes those parameters on
the same decision pulses, on events, equity and diagnostics.

Monthly rolling and anchored fold boundaries are derived from the original
anchor plus `k * step`, then clamped to the last valid civil day of the result
month. A boundary is never derived from the preceding clamped boundary.

Availability-aware `ledgr_pulse_snapshot()` uses the shared preparation and
runs P1 observe-and-settle plus P2 context construction at one cutoff. It runs
no P3-P5, creates no run row and performs no store write. With the same
snapshot, definitions, policies and opening state, its data-dependent planes
equal the first pulse of a run started at that cutoff. The frozen dense branch
remains until execution-core consolidation; no new dense-only code is added.

History remains an estimation surface, not historical portfolio replay.
Historical holdings, priced state and mark ages are not added to the public
frame. Durable run evidence remains owned by results and explain.

## 9. Identity, persistence and compatibility

Advance config identity from rule 3 to rule 4. Identity includes:

- history class, `requires_bars`, gap/restart behavior and readiness;
- custom tolerance, TTR version and algorithm-changing arguments;
- history treatment order and parameters, implementation version, cutoff and
  axis semantics;
- the assumed-versus-declared price-basis identity already bound by the
  current contract; and
- any declared segment-limit override.

Feature fingerprints carry the feature-specific subset. Strict and treated
requests cannot share identity. Worker count and resource controls do not
enter identity.

There is no compatibility layer. Pre-v12 rule-3 run, sweep and walk-forward
artifacts are not resumable or reusable under rule 4, and stores whose current
format fingerprint changes are rebuilt. No migration, legacy reader, marker
fallback or inference is added. H6 builds both timing/memory arms fresh.

Snapshot content hash rule 3 remains the content rule unless implementation
changes the sealed snapshot representation. The history substrate, history
results and feature values are runtime values, not snapshot rows or durable
feature artifacts. Do not recreate the deleted feature table, cache, clear API,
cache telemetry or `persist_features` path.

## 10. Detecting evidence and release gates

The implementation cut maps each item below to one owner and a
failure-sensitive oracle.

1. A two-clock fixture detects seal/wall-clock substitution, future-known
   leakage and omission of a fact effective at `s` and knowable at `t`.
2. Frame, matrix and scalar reads agree at equal cutoff and policy; future,
   unknown-ID, empty-axis, empty-long and outside-axis cases fail or return the
   bound empty shape rather than a plausible value.
3. Per-instrument masks distinguish lifetime-inactive structure from halts and
   retain inactive-interval prints only as flagged bar evidence.
4. Sydney, Honolulu and New York Date fixtures detect UTC-midnight leakage and
   wrong open/close resolution.
5. Carry fixtures detect backward fill, refreshed age, cross-field or volume
   carry, leading invention, barrier crossing, lost later boundaries,
   terminal restart and wrong assumed-basis behavior.
6. Admission over exactly the declared required fields, readiness on treated
   inputs, calculation validity, input carry and output carry are independently
   detected with aligned reason evidence. No engine carried-share threshold is
   introduced, and a carried history value changes no membership, trading,
   valuation or execution plane. **Owners:** WS3 treatment and WS4
   declarations/calculation.
7. Registered indicator rows cover bounded and history-dependent families,
   multi-output TTR, algorithm variants, interior gaps, carry-horizon expiry,
   first-valid restart and custom exact/tolerant refusal.
8. Removing or moving the sampled prefix and custom-window checks fails before
   artifact creation; both avoid all-prefix quadratic work.
9. Run, sweep, walk-forward and availability-aware pulse inspection agree on
   substrate identity and data planes. The continuous-carry public-run oracle
   detects lost boundary fills, marks or entitlements. Its history-start
   update changes LTB-0196's restart expectations for this named semantic
   reason, not to conceal a failing old oracle. **Owner:** WS3 integration.
10. The correction-chain matrix detects non-monotone knowledge, early-ending
    successors, revival, whole-component exemptions, cycles, dangling links
    and classifier/runtime disagreement.
11. The rolling-month oracle anchored at 2019-12-31 has no day drift or pulse
    gap across twelve folds.
12. Corporate actions with an event clock but no knowledge clock follow the
    known-when-effective assumption; rows with no clocks remain audit-only;
    rows with knowledge but no event clock fail only from their knowledge
    cutoff.
13. A structural check proves no parallel `bars_by_id`, `bars_mat` and
    `static_bars_views` remain. A daemon rejects missing or altered staged
    identity. **Owner:** shared substrate and transport.
14. The full 1998-2026 Sharadar changing-membership and full-membership paths
    finish without history-related stops, and the default segment guard passes
    with aggregate and maximum counts reported.
15. A late-known lifetime change independently pins numerical values and
    evidence before and after knowledge arrival, including an expected-session
    mask change, input carry disabled and output carry tested alone. Earlier
    returned results remain unchanged. The oracle is independent of agreement
    among ledgr entry points. **Owners:** WS3 correctness and H6 integration.
16. Explicit precompute refuses reuse under a changed policy, axis or cutoff;
    backward and reordered requests retain the right values; mutation of a
    returned result cannot alter storage or a later result; every rule-4
    identity input changes the applicable feature or config identity; and a
    pre-v12 rule-3 artifact refuses rather than being inferred or upgraded.
    **Owners:** WS3 reuse and the identity ticket.
17. Sequential, current-dispatch and staged-dispatch arms under the same
    identity rule agree on final equity, trade count, seed, snapshot, strategy
    and reproduction-key hashes. This transport oracle is separate from the
    staged-invariant refusal. **Owner:** H6 transport evidence.
18. Delete the test-only `ledgr_sweep_compute_feature_matrix()` and construct
    its three fixtures through production precompute while retaining their
    prebuilt-view and cross-pulse/candidate mutation-isolation assertions.
    WS7 consumes the carried-share disclosure on its registered history
    workload rather than merely observing that the field exists. **Owners:**
    WS4 test migration and WS7 consumer proof.

Resource acceptance uses paired current-tree and history-enabled runs on the
same H1 workload and host, with the same approximately 0.2-second sampler and
the median of three repeats. The single-run parent and two-worker parent each
pass separately for both working set and private commit at no more than 1.10
times their paired baseline. The summed parent-plus-daemon process tree passes
separately on private commit at no more than 1.10 times baseline; summed
working set is disclosed as a lower bound rather than used as that gate.
Preparation and fold peaks, working set, private commit, live substrate bytes,
workers, instruments, pulses, bars, facts and segments are reported. Any miss
is corrected or receives an explicit maintainer exception, user-visible limit
and routed follow-up.

After the single-copy substrate lands, report:

```text
(workers - 1) * staged_invariant_bytes / total_private_commit
```

Reopen `mori` only at or above 10%. Measure read-side peak for the full logical
trace through `ledgr_results(bt, "diagnostics")` and `ledgr_run_explain()`;
route a material problem to WS8. The release teaching gate demonstrates the
history-to-estimator-to-weights-to-target flow without manual timestamp or
instrument-name reconstruction.

## 11. Deferred work and reopening

These items keep their existing owners:

- **Span-labelled bridged returns.** Reopen from the Sharadar gap census when
  the missing-output consequence blocks an intended method. It must carry its
  elapsed-session span and cannot silently replace daily return.
- **Convergence readiness.** `stable_after` remains first-valid. A later
  convergence contract needs a method-specific use case and evidence; it may
  not redefine this release's readiness silently.
- **More than two local workers and shared memory.** Larger counts are
  unmeasured. Shared memory reopens only under Section 10's post-substrate 10%
  trigger. If reopened, it shares the prepared bar substrate rather than
  rebuilding it and rebuilds only `pulses_iso`.
- **Lifetime corrections.** Reopen when acquisitions are merged into
  bitemporal lifetime facts. Same-assertion restatements remain admissible;
  only opposing lifetime overlaps refuse. This trigger and qualification come
  from the register's Session C and v11 Section 9, not the trading-status
  correction-chain implementation in this wave.
- **Revision optimization.** Reopen segmentation, trigger tables or partial
  invalidation only when a supported knowledge-timed change affects an
  intended request and simple correct preparation has material measured cost.
  A new source with genuine knowledge clocks or missing sessions first
  triggers an exposure assessment, not automatic optimization or causal
  approximation. Record affected instruments, cells and requests, the
  consequence of the named shortcut and the correction cost before reopening
  representation work.
- **Fitted transforms and ML lifecycle.** Training cutoffs, labels, embargo,
  refitting and artifact identity remain with the ML RFC.
- **Durable factor/prediction evidence.** V12 preserves the join identity;
  capture, retention, reopening and paper/live feedback remain a separate RFC.
- **Portfolio construction and scheduling.** Omitted-target policy, current
  weights, allocation diagnostics, generic optimizers and schedule decorators
  keep their existing routes.
- **Dense execution.** No history feature lands there; consolidation retains
  its accepted owner.

Dividend-fact adapter work, broad RAM restructuring, liquidity/capacity and
compiled execution do not become history prerequisites merely because they
may later consume the surface.

## 12. Contract, ticket-cut and acceptance routing

The implementation cut must amend the stable contract groups for:

- snapshot point-in-time facts and civil-time resolution;
- availability provider/timing, expected-session masks and inactive prints;
- context pulse data, feature naming and the public history result;
- indicator computation, history class, readiness, gaps and causality;
- execution/scoring start, carried walk-forward continuity and pulse
  inspection;
- config/feature identity, current-store refusal and explicit precompute;
- result immutability, exclusions and explain continuity; and
- release gates and full-history resource evidence.

### Supersession and receiver map

The reviewed H0 census is the affected-rule inventory. These rows account for
every load-bearing v11 clause; the ID lists are H0 row IDs, not a new semantic
classification.

| Target | Addressed H0 groups | Disposition | Receiver |
| --- | --- | --- | --- |
| v11 Sections 1-2 | 1.1, 1.3-1.5, 2.1, 2.4-2.6 | unchanged | Retained meanings, restated in v12 Sections 1, 2, 7, 10 and 11 |
| v11 header and Sections 1-2 | H-1, 1.2, 2.2-2.3 | amended | v12 header and Sections 2, 7, 10 and 12 |
| v11 Section 3 | 3.1, 3.3a, 3.4a, 3.7-3.8 | unchanged | v12 Sections 2 and 3 |
| v11 Section 3 | 3.4b-3.6 | amended | v12 Sections 3 and 8 |
| v11 Section 3 | 3.2 and 3.3b | superseded | v12 Sections 2 and 3, from Sessions 0, A and B |
| v11 Section 4 | 4.3 | unchanged | v12 Section 4 |
| v11 Section 4 | 4.1-4.2 | amended | v12 Sections 4 and 10, from H0-Q2 |
| v11 Section 5 | 5.2-5.6, 5.8, 5.10, 5.12-5.13, 5.16 | unchanged | v12 Sections 5 and 6 |
| v11 Section 5 | 5.1, 5.7, 5.9, 5.11 and 5.14 | amended | v12 Sections 4, 5, 9 and 10 |
| v11 Section 5 | 5.15 | superseded | v12 Section 9 keeps the deleted cache and feature store retired and prohibits recreation |
| v11 Section 6 | 6.1-6.2 and 6.5 | unchanged | v12 Sections 7 and 11 |
| v11 Section 6 | 6.3-6.4 and 6.6 | amended | v12 Sections 2, 7, 8 and 10 |
| v11 Section 7 | 7.1-7.5 | unchanged | v12 Sections 4, 5, 7 and 10 |
| v11 Section 7 | 7.6-7.7 | amended | v12 Sections 10 and 12 |
| v11 Section 8 | 8.2, 8.5 and 8.6 | unchanged | v12 Section 10 |
| v11 Section 8 | 8.1, 8.3a, 8.4 and 8.7-8.8 | amended | v12 Sections 3-10 |
| v11 Section 8 | 8.3b | superseded | v12 Sections 2, 3 and 10, from Sessions 0, A and B |
| v11 Section 9 | 9.1-9.2 | unchanged | v12 Section 11 |
| v11 Section 9 | 9.3 | amended | v12 Section 11 and its named downstream owners |
| v11 Section 10 | 10.1 and 10.3 | amended | v12 Sections 2, 10 and 12 |
| v11 Section 10 | 10.2 | superseded | v12 Section 1 availability-only scope |

Acceptance adds pending links, but does not rewrite shipped behavior. The H5
ticket cut assigns each receiver below exactly once; the implementing commit
rewrites it and removes its pending link.

| Stable receiver in `contracts.md` | Disposition at acceptance | V12 owner |
| --- | --- | --- |
| [Snapshot Point-In-Time Facts](../contracts.md#contract-snapshot-point-in-time-facts) and [Config Policies](../contracts.md#contract-config-policies) | amended, change pending | Sections 2 and 4; facts prerequisite and WS3 |
| [Availability Activation And Calendar](../contracts.md#contract-availability-activation-and-calendar), [Units, Price Basis And Universe](../contracts.md#contract-availability-units-and-universe), and [Provider, Knowledge And Timing](../contracts.md#contract-availability-provider-and-timing) | amended, change pending | Sections 4, 5 and 7; shared substrate |
| [Context Pulse Data](../contracts.md#contract-context-pulse-data) and [Inspection And Signal Views](../contracts.md#contract-context-inspection) | amended, change pending | Sections 2, 3 and 8; WS3 public surface |
| [Indicator Computation And Identity](../contracts.md#contract-context-indicator-computation), [Availability-Aware Strict Features](../contracts.md#contract-context-strict-features), [TTR Adapter](../contracts.md#contract-context-ttr-adapter), and [Feature Path](../contracts.md#contract-context-feature-path) | amended, change pending | Sections 5-7; WS4 |
| [Fold Core](../contracts.md#contract-execution-fold-core), [Scoring And Feature Start](../contracts.md#contract-execution-window-start), [Walk-Forward Fold Lifecycle](../contracts.md#contract-execution-walk-forward-folds), and [Event Staging](../contracts.md#contract-execution-event-staging) | amended, change pending | Sections 2, 7 and 8; WS3 integration |
| [Execution And Feature Identity](../contracts.md#contract-execution-identity), [Config Construction](../contracts.md#contract-config-construction), [Snapshot Identity And Verification](../contracts.md#contract-snapshot-identity-and-verification), and [Current Store Format](../contracts.md#contract-persistence-current-format) | amended, change pending | Section 9; shared identity owner |
| [Strategy Outputs](../contracts.md#contract-strategy-outputs) and [Decision Axis](../contracts.md#contract-strategy-decision-axis) | unchanged target obligation; history evidence added | Section 3; WS3 teaching and oracles |
| [Result Reads And Explanations](../contracts.md#contract-result-read-surfaces), [Return Panels](../contracts.md#contract-result-return-panels), and [Fills And Sweep Restoration](../contracts.md#contract-result-fills-and-sweep-restoration) | amended, change pending | Sections 3, 8 and 10; integration evidence |
| [Release Gates](../contracts.md#contract-verification-release-gates) and [Store And Codebase Gates](../contracts.md#contract-verification-store-and-codebase-gates) | amended, change pending | Section 10; H6 |
| [Indicator Teaching](../contracts.md#contract-documentation-indicators) and [Strategy Context Teaching](../contracts.md#contract-documentation-strategy-context) | amended, change pending | Sections 3, 6 and 10; release teaching |

The cut begins with the correction-chain facts prerequisite and one shared
substrate/identity owner. Public history and indicator work may then proceed in
parallel without inventing another reader or start rule. Integrated evidence
closes the wave. Exact private helper names, evidence-column names and the
structural-completeness helper name are spec-cut questions; they may not alter
the semantics above.

The cut also owns three accepted handoffs. It deletes the test-only
`ledgr_sweep_compute_feature_matrix()` and moves its three fixture builders to
production precompute without weakening their prebuilt-view or mutation
isolation assertions. It changes LTB-0196's restart expectations only for the
accepted single data-start rule. It assigns WS7 a consumer proof for the
carried-input share and its estimator consequence; field existence alone does
not discharge that obligation.

Before ticket cut, run one Type 1 final review against v11, the drift map, the
completed register, current contracts and current code. The review verifies
fidelity and ownership; a new product choice returns to the maintainer as Type
2 rather than being designed by the reviewer.

At maintainer acceptance:

1. this document becomes operative and v11 becomes derivation history;
2. v11 receives a dated header notice and each affected heading receives a
   marker pointing to the applicable row of this supersession map; unchanged
   H0 rows receive no fictitious change notice;
3. the stable contract receivers above gain `Accepted change pending`
   back-links and `decisions.md` records the same source/receiver mapping;
4. the history-wave pipeline row points to the accepted synthesis and keeps
   the recursive-indicator and instrument-specific-axis obligations, their
   sources, triggers and H5 cut owner consolidated beneath it until tickets
   own them or the maintainer drops them with a recorded reason;
5. the old recursive-indicator and instrument-specific-axis anchors remain as
   redirect stubs to that consolidated row so inbound links still resolve;
   and
6. the research UX brief marks its history/frame/matrix directions resolved.

Acceptance itself changes no product code or stored format. Cut 16 owns those
implementation changes and the present-tense contract consolidation.

## Revision history

- **2026-10-16:** initial draft from the completed H0-H2 history-wave record;
  awaiting Type 1 final review and maintainer acceptance.
- **2026-10-16:** pre-H4 fidelity corrections restored the three-way
  corporate-action clock rule, narrowed bounded refutation to definitions
  with `series_fn`, separated estimator exclusion from target construction
  and disclosed the custom scalar-window behavior change.
- **2026-10-16:** H4 Type 1 corrections restored cutoff-dependent numerical
  correctness, required-field and economic-plane separation, exact resource
  gates, reuse and transport oracles, supersession receivers, implementation
  handoffs, deferred triggers and live routing.
- **2026-10-16:** focused H4 confirmation returned `PASS_AFTER_PATCHES`; the
  estimator-completeness boundary and two supersession receivers were
  corrected in place.
- **2026-10-16:** accepted by the maintainer. The source/bridge/receiver
  routing in Section 12 is operative; implementation remains pending H5.

## As implemented (appended 2026-10-22 at the Cut 16 close)

This appendix is a pointer, not an amendment: the accepted text above is
unchanged. Cut 16 (H5) implemented this synthesis, and some of its
maintainer decisions changed what a section says. Each row names the
section, the decisions that changed it and the `contracts.md` group that now
states the shipped rule. The decisions are in the v0.2.2 packet's
`tickets.yml` (Cut 16 `decisions`); the per-decision code owners and
registered blocks are in
[`cut16_decision_reconciliation.md`](../ledgr_v0_2_2_spec_packet/cut16_decision_reconciliation.md).
Decisions (1) to (9) bound this synthesis at the cut and are not listed
except where they named a spec-cut helper or exercised a stated condition.

| Section | What changed | Cut 16 decisions | Shipped rule |
| --- | --- | --- | --- |
| Section 1 (dense mode frozen) | Four accepted corrections change dense results without adding dense history: known-when-effective corporate actions, the TTR `aroon` width, custom indicators that share a built-in id, and the effective-only corporate-action refusals. | (11), (14), (19), (35) | `contracts.md#contract-snapshot-point-in-time-facts`, `#contract-context-strict-features` |
| Section 2 (history start, knowledge clocks) | The single data start applies to availability experiments only. A membership, trading-status or lifetime fact without a knowledge time refuses at preparation; the known-when-effective assumption stays for corporate actions. | (16), (23) | `#contract-execution-window-start`, `#contract-availability-provider-and-timing` |
| Section 3 (public surface) | The reader and adapter are `ledgr_history_frame()` and `ledgr_history_matrix()`. Feature cells are a vintage view: each earlier cell keeps the value and evidence of its own pulse, while bar history is restated at the cutoff. | (3), (29) | `#contract-context-pulse-data` |
| Section 4 (civil time, facts) | A Date corporate-action entitlement, effective or payment time names the session close and a Date knowledge time the session open; an assumed Date knowledge time is the session open; a supplied knowledge time is kept; effective-only disposition, quantity-effect and cash-dividend rows refuse; membership-snapshot headers are ordered by resolved knowledge time. | (12), (27), (28), (31), (33), (34) | `#contract-snapshot-point-in-time-facts` |
| Section 5 (missing data, carry) | The policy constructor is `ledgr_history_policy()`. A custom definition may declare `input_carry = "excluded"`. Bounded windows, readiness and output carry are stated against lifetime-inactive and terminal intervals, and `calculation_non_finite` joins the evidence reasons. | (4), (13), (15), (20), (21) | `#contract-config-policies`, `#contract-context-strict-features`, `#contract-context-pulse-data` |
| Section 6 (indicator classes) | The custom input-carry declaration and the `aroon` `n + 1` width are catalogue rules; a terminal interval ends bounded windows; a refused feature in a durable run leaves one `FAILED` run row, the only record written before the refusal. | (13), (14), (15), (18), (20) | `#contract-context-indicator-computation`, `#contract-context-strict-features`, `#contract-context-feature-path` |
| Section 7 (substrate) | Only lifetime and terminal segments are stored; membership and trading-status segments are counted for the guard with one canonical count. For features, the cutoff-correct answer to a late-known fact is the vintage view. | (22), (24), (29) | `#contract-availability-provider-and-timing`, `#contract-execution-fold-core`, `#contract-context-pulse-data` |
| Section 8 (windows, inspection) | Availability-aware inspection is derived from an experiment, its parameters and a cutoff. The carried walk-forward chain applies to availability experiments only. | (10), (16) | `#contract-context-inspection`, `#contract-execution-walk-forward-folds` |
| Section 9 (identity, persistence) | Civil-time facts changed the sealed representation, so snapshot hash rule 4 replaced rule 3; the store format advanced to 121 and, with the stored hydration column removed, to 122. | (6) | `#contract-snapshot-identity-and-verification`, `#contract-persistence-current-format`, `#contract-execution-identity` |

Sections 10, 11 and 12 are unchanged. The Section 10 shared-memory trigger
measured 0.1218 on the H1 workload and is a maintainer question in the v0.2.2
macro plan (`#deferred-history-simplification`); nothing was implemented.

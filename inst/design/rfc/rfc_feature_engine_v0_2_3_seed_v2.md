# Feature Engine: Seed v2

- Author: Claude, 2026-11-16, at the maintainer's request (macro plan, order
  after Cut 20, items b and c).
- Status: seed v2. Applies every finding of the Type 2 review of v1. Binds
  nothing. The maintainer's Section 7 answers (2026-11-16) stand; they are
  restated in Section 7.
- Changes from v1: corrects every finding of the Type 2 review
  ([review](rfc_feature_engine_v0_2_3_seed_review.md), on v1 at `7eae4ac0`:
  REVISE_SEED, F1-F13, all accepted; its probe is kept in
  `dev/spikes/feature_engine/seed_review_probe/`).
  - F1: the profiler charged compute residual to the sweep's split and
    rebuild. Fixed and re-measured; the split and rebuild cost 0.00-0.05 s,
    not 0.13-0.20 s.
  - F2: the table gives sampled estimates, not removable costs; savings are
    hypotheses until a paired measurement.
  - F3: narrowing input treatment to required fields is not neutral for
    custom callbacks. Narrowed to proven-unobservable cases.
  - F4: stage 1's oracle and proof obligations are stated.
  - F5: the "dead" accessors are registered test seams. They stay.
  - F6: the engine-version gap is wider than four helpers. A dependency
    census replaces the list.
  - F7: simple instruments still have segment records and possible
    missing-input reasons.
  - F8: the simple gate is per definition and calculation context, not per
    instrument.
  - F9: unchanged TTR fingerprints need the emitted functions kept
    byte-identical.
  - F10: the adapter description must carry raw-call identity, output
    selection and derivation, raw-result sharing and certification.
  - F11: the identity section now covers each layer and what an engine
    change does and does not invalidate.
  - F12: the sweep-reuse claim is narrowed.
  - F13: three more small removals are added as candidates.
- Evidence: release/v0.2.3, pin `d5b3a151`.
  `dev/bench/v0_2_3_lean_tuning_profile/`: `feature_steps.R` (precedence
  fixed) and `results/feature_steps.csv` (re-measured),
  `results/feature_split.csv`, `results/features_h1.csv` (private H1,
  aggregates only), `results/e2e_cut18_groups.csv`.
- Not decided here: the cuts themselves, compiled code (it needs the
  maintainer's named decision), a TA-Lib adapter, new indicators, the
  separately accepted post-warmup-NA chore (macro plan WS12).

## 1. The question

Features are the largest cost of a wide run after the store write. In the
lean end-to-end profile after Cut 18 (`e2e_cut18_groups.csv`), they take:
- 21 percent of a 500 x 1,260 run;
- 40 percent of a 1,166 x 252 run;
- 20 percent of an 8-candidate sweep on 500 x 1,260.

The macro plan asks for a seed that:
- finds where that time goes;
- keeps adapters pluggable (TTR now, TA-Lib later);
- settles how sweeps prepare and reuse features.

The seed separates removals that keep every value and contract (a cut, no
RFC) from interface changes (RFC-sized).

## 2. Where the time goes

`feature_split.csv` times the compute step alone, without the projection,
for SMA 5 and 10 on the published crossover:

| shape | ledgr compute | bare TTR | difference |
| --- | ---: | ---: | ---: |
| 10 x 7,200 | 0.08 s | 0.00 s | 0.08 s |
| 500 x 1,260 | 0.83 s | 0.08 s | 0.75 s |
| 1,166 x 252 | 1.10 s | 0.17 s | 0.93 s |

On private H1 (1,166 instruments, 7,213 sessions), 582 instruments have
the shape that `features_h1.R` calls simple: one feature range, one close
run, no terminal, no carried input. On those, the pin's per-instrument path
takes 7.8 ms per instrument for the SMA pair, and bare TTR takes 0.29 ms,
with the same SMA values and NA placement. That cohort is evidence of an
opportunity. It is not the gate stage 3 would use (Section 5).

`feature_steps.R` splits the pin's paths by Rprof sampling:
- **run path:** compute, then projection (`R/backtest-runner.R:664-680`),
  with SMA 5 and 10;
- **sweep path:** compute, the per-instrument payload split, then the
  rebuild (`R/sweep.R:276-291`), with the union SMA 3, 5, 8, 12, 20 and 40.

Each sample goes to the first matching step. Children come before their
residuals, and residuals come before the wrappers that contain them (F1).
The cells below are pooled sample shares over five profiled repetitions,
scaled to the median profiled time. They are estimates, not removable
costs. A zero cell means the cost is too small to resolve at this sample
count, not that it is absent. Another job shared the machine, so the
seconds are descriptive.

| step | 10x7200 run | 10x7200 sweep | 500x1260 run | 500x1260 sweep | 1166x252 run | 1166x252 sweep |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| axis formatting (D + 2 `format()` calls) | 0.19 | 0.43 | 0.04 | 0.07 | 0.01 | 0.01 |
| TTR raw call (includes TTR itself) | 0.00 | 0.03 | 0.14 | 0.49 | 0.37 | 1.11 |
| input treatment | 0.04 | 0.03 | 0.34 | 0.35 | 0.35 | 0.34 |
| calculate: admission, readiness, runs, carry, buffers | 0.02 | 0.07 | 0.16 | 0.52 | 0.22 | 0.67 |
| segment frame and segment rest | 0.00 | 0.03 | 0.10 | 0.24 | 0.11 | 0.32 |
| plane exceptions and records | 0.00 | 0.02 | 0.06 | 0.11 | 0.08 | 0.21 |
| compute residual (output matrices, counts, plane collection) | 0.03 | 0.13 | 0.06 | 0.21 | 0.06 | 0.23 |
| causality probe, certification | 0.02 | 0.05 | 0.00 | 0.02 | 0.00 | 0.01 |
| payload split and rebuild (sweep) | - | 0.00 | - | 0.05 | - | 0.05 |
| other (ranges, projection indexing and rest) | 0.00 | 0.00 | 0.01 | 0.01 | 0.03 | 0.03 |
| **whole path** | **0.30** | **0.80** | **0.90** | **2.08** | **1.24** | **2.98** |
| samples | 96 | 250 | 296 | 673 | 399 | 964 |

Bare TTR for the sweep's six definitions takes about 0.28 s on 500 x 1,260
and 0.57 s on 1,166 x 252. It ran on the same busy machine, as a mean over
repetitions.

Reading:

- **Narrow long runs:** formatting the POSIXct pulse axis is about two
  thirds of the feature time. The projection formats it D + 2 times for D
  features (`R/runtime-projection.R:35, 40, 48`): D times for dimnames,
  once for the pulse index and once for the ISO pulses. One format must
  stay.
- **Wide runs:** the cost is spread over the per-instrument machinery.
  - The TTR raw-call bucket includes TTR itself. Its difference from the
    separate bare-TTR clock is a hypothesis about per-call overhead (input
    mapping, function lookup, `do.call()`; `R/indicator-ttr.R:852-863`),
    not a measured split.
  - Input treatment, the calculate bookkeeping, segment framing and the
    evidence planes together cost more than the raw call.
- **Sweeps:** the split and rebuild are small (0.00-0.05 s). The sweep's
  cost is the same calculation over more definitions.
- Certification is unresolved at this sample count, and the causality probe
  is small.

## 3. What the code does today

One per-instrument engine serves every definition (`R/history-features.R`):

1. **Certification.** Each definition is certified once per compute call
   against catalogue candidates built fresh, including a synthetic TTR call
   (`:19-151`). A matching claim is replaced by the canonical constructor
   definition (`:30-81`).
2. **Ranges.** Knowledge ranges are found per instrument (`:412-428`).
3. **Inputs.** Inputs are treated per instrument and knowledge range, and
   shared by every definition in that range (`:169-218`, `:475-487`). Each
   range recomputes its full prefix at its own cutoff, and the causality
   probe builds its own inputs (`:655-663`).
4. **Calculation.** Per instrument x range x definition x segment
   (`:329-407`). Admission, readiness and segment records are kept even when
   there is no gap (`:342-379`). There are four segment branches
   (`:282-324`):
   - the built-in SMA, a `vapply()` over every window;
   - TTR, through a segment frame and a raw call, with raw results shared
     across the outputs of one call (`:62-77`, `:294-306`);
   - custom `series_fn`, one call per segment, given the full OHLCV frame
     (`:230-242`, `:308-320`);
   - custom `fn` only, one call per ready bar.
5. **Evidence.** The evidence planes are built per instrument (`:540-611`).
6. **Causality probe.** A prefix-invariance check runs for every
   definition with calculated cells; the fn-against-series refutation is
   for custom bounded definitions only (`:688-709`). The comment at
   `:624-625` says otherwise and is wrong.
7. **Projection.** The projection indexes the planes and formats the axis
   (`R/runtime-projection.R`).

TTR is hard-wired outside its adapter file:
- certification and catalogue candidates (`R/history-features.R:120-149`);
- the kind dispatch and the raw-call key (`:70-80`, `:294-307`);
- the catalogue matching helpers (`R/indicator-ttr.R:328-409`) and rows
  (`R/indicator-history.R:203-268`);
- the `source` values (`R/indicator.R:137-138`);
- the parameter registry (`R/feature-parameters.R:290-299`);
- the provenance list (`R/strategy-provenance.R:104-116`). This one is
  diagnostic metadata, not calculation identity.

**Engine-version gap.** `ledgr_feature_engine_version()` hashes named helper
bodies, but not the helpers they call (`R/features-engine.R:1-93`). Several
semantic helpers are outside it, among them:
- `ledgr_ttr_raw_call`, `ledgr_ttr_build_input` and
  `ledgr_ttr_select_output`;
- `ledgr_feature_plane_exceptions` and `ledgr_feature_plane_records`;
- `ledgr_history_feature_bounds`;
- `ledgr_history_feature_check_definition`;
- `ledgr_projection_index_planes`;
- the TTR catalogue matching helpers.

The review's probe changed each of these in a private copy, and the hash
stayed the same. The contract binds every helper of the calculation
(Availability-Aware Strict Features).

## 4. Constraints

- **Same values.** Values, NA placement, types, dimensions and names,
  every feature plane and history-read reason, and calculation refusals stay
  identical to the pin. The pin is the oracle, as in Cut 17. The contracts
  (Indicator Computation And Identity, Availability-Aware Strict Features,
  TTR Adapter, Feature Path) stay as they are unless an RFC changes them.
  The one intended new refusal is an old precompute object meeting a new
  engine version (Section 6).
- **Constructor functions.** Catalogue rows are computed with the
  constructor's own functions. A faster path may call TTR differently, but
  may not substitute another implementation.
- **The custom callback boundary.** Custom callbacks today receive the full
  treated OHLCV frame, whatever their `required_fields` say. Narrowing
  that needs a contract decision (F3).
- **Remove before adding** (maintainer, standing).
- **No compiled code** without the maintainer's named decision.
- **No backward compatibility** before CRAN: an in-memory precompute object
  or engine version gets no reader for the old one.

## 5. Proposal

### Stage 1: remove work (same values, no contract change; a cut, no RFC)

Candidates, each kept only if the pin oracle and a paired measurement show
it is identical and faster:

1. **Format the pulse axis once** per projection: one format instead of
   D + 2.
2. **Narrow treatment only where it is unobservable** (F3). Compute the
   field union from the certified canonical definitions, not from source
   labels or claimed metadata. Keep the full treated frame whenever a
   custom definition or an unregistered TTR form is present. Keep sharing
   treatment across definitions within each instrument and knowledge
   cutoff, and keep the probe's behaviour.
3. **Cut the TTR per-call overhead.** Resolve the TTR function once per
   definition. For `input = "close"`, pass the treated close vector
   directly: the current mapping already hands TTR `as.numeric(bars$close)`
   (`R/indicator-ttr.R:806-844`), and the review's probe shows identical
   output. Build a segment frame only on a raw-cache miss (F13). Output
   selection, derived outputs, the short-sample guard, canonical
   certification and raw-result sharing stay as they are.
4. **Slice only the required fields for admission** (F13). The callback
   frame stays complete.
5. **Keep matrices** on the sweep path and in explicit precompute, which
   today holds both split vectors and matrices
   (`R/precompute-features.R:91-132`). This is small in time but removes
   duplicate memory. Registered precompute tests that assert the old
   physical shape change only with a stated representation-change reason;
   their semantic comparisons stay.
6. **Repair the engine version** (F6). Take a census of the ledgr-owned
   semantic helpers:
   - certification and declarations;
   - input mapping and treatment;
   - bounds and ranges;
   - calculation and output selection;
   - planes;
   - causality and refusals;
   - the prepared representation that sweeps reuse.

   Bind each helper, or document the separate identity that already binds
   it. Add mutation tests showing that a representative value, evidence,
   refusal or representation change moves the engine version. Do not solve
   this with a recursive hash of environments, session state or every
   package function.
7. **Fix the probe comment** to say what the code does.

**Not deleted:** the four "dead" accessors in
`R/runtime-projection.R:357-559` (F5). Two of them are registered test
seams (LTB-0183, `test-feature-accessor-scaling.R`), and the third serves
them.

**Oracle and proofs (F4).** A diff-based checker compares the installed pin
with the candidate on:
- exact values and NA placement;
- types, dimensions and names;
- every feature plane and history-read reason;
- refusal condition classes and their identifying fields.

It also preserves the caller's RNG and the causality probe's selection and
order. The intended differences are the engine version, the old-precompute
refusal and the in-memory representation; nothing else is normalised away.

Cases:
- built-in SMA separately from TTR SMA;
- every supported warmup rule and documented or derived output;
- bounded and history-dependent rows; `stable_after` greater than
  `requires_bars`;
- empty, short and never-calculated histories;
- custom `series_fn` and fn-only callbacks, including one that reads a
  non-required field;
- unregistered TTR arguments and forged catalogue claims;
- required-field gaps, carry admission and exclusion, output carry and
  expiry;
- inactive sessions, terminals and relistings, late-known facts;
- both clocks, a scoring start after data start;
- runs, implicit sweeps and explicit precompute with reuse.

Refusals must still come before any candidate or fold runs, and a
preparation failure still leaves a FAILED durable run with no strategy,
events or equity. Registered tests stay. Timing uses the shared harness
(`dev/bench/timing/`), as paired measurements after correctness.

### Stage 2: an internal adapter description (RFC-sized)

One immutable internal description per adapter, which TTR fills now and a
later adapter fills the same way (F10):

- **identity:** a deterministic adapter and backend identity; the package
  and, where it applies, the underlying library version and the
  algorithm-setting identity;
- **inputs:** the exact input mapping (`close`, `hl`, `hlc`, `ohlc`,
  `hlcv`, and TTR's separate volume argument for MFI and CMF), and forwarded
  arguments kept separate from metadata;
- **widths:** deterministic dependency-width and `stable_after` rules,
  kept distinct from each other and from the history class;
- **catalogue matching:** keyed by input, function, output and the
  algorithm variants, with neutral and allowed arguments. Unregistered
  combinations still route to custom, with their classed refusals;
- **raw calls and outputs:** raw-call identity separate from the identity
  of a selected or derived output (MACD `histogram` is derived, not a TTR
  column). Raw invocation, output discovery, selection and derivation,
  aligned numeric normalisation, and preparation-local raw sharing over
  compatible inputs and segments. A call that returns only one selected
  vector is not enough;
- **certification:** candidates rebuild the canonical ledgr-owned
  definitions and compare complete identity. An adapter or source name
  never authorises caller-supplied code under a catalogue identity;
- **proof:** registered hostile-fixture tests for every catalogue row,
  warmup rule and documented output; direct-backend parity including
  derived outputs; the runtime causality probe unchanged.

Certification, the kind dispatch, the `source` values, the parameter
registry and provenance read the registered adapters instead of naming TTR.
Registry contents are deterministic and bound by the engine version. A
later adapter has its own backend identity even for similarly named
indicators; no cross-backend equivalence or catalogue membership is
presumed. This RFC creates no TA-Lib implementation and no matrix-call
obligation.

**TTR fingerprints (F9).** Keep the emitted `fn` and `series_fn` bodies,
their formals, direct captures, params (including `ttr_version`), IDs and
declarations exactly as they are. Their existing helper may route through
the adapter, with the adapter's semantics bound in the engine version.
Before refactoring, pin the ordinary and declared-session fingerprints for
concrete, parameterised and bundled TTR forms, and verify that canonical
certification still recognises them. Do not hard-code an old hash or add a
compatibility reader. If this cannot be done, bring the concrete identity
diff to the maintainer before changing it.

### Stage 3: a plain-R direct-call path for proven simple cases (RFC-sized)

The maintainer chose plain R: one direct adapter call per instrument
without the segment machinery. A matrix entry point is considered only if a
measured gap remains.

**The gate (F8)** is one predicate over (certified definition or compatible
raw-call group, instrument, bounds, knowledge cutoff, history policy). It
is not an instrument property.
- Initially it admits only supported certified adapter rows. Custom and
  unregistered forms keep the general path.
- It requires one unchanged knowledge range over the relevant calculation
  history.
- It proves expected-session selection and finite admission for every
  required field under the row's input-carry family.
- It accounts for terminal assertions and the sticky barrier over the
  prefix, and establishes the actual run's start, end and scatter mapping.
- It handles `stable_after` and empty or short histories without an early
  adapter call.

A conservative first gate may require full expected, finite, uncarried
coverage of the whole calculation slice and no terminal history. That
narrower gate must be re-counted: the 582 H1 instruments are not its
coverage, and the count needs a run by the authorised private-data
executor.

**Same records (F7).** Admitted cells use the same canonical adapter
calculation, normalisation and refusals. They build the same segment start,
ready and end records, bounds and calculated counts as the general path,
including segments that never become ready. A single run that covers less
than the calculation range keeps its leading or trailing missing or
inactive evidence, and its values are scattered to the same axis positions.
Only carry and reason exception sets proven absent may be empty.
Output-carry semantics are kept, or shown to be a no-op on the admitted
slice. The global sampled causality check runs for every concrete
definition, with the same instrument tie-breaking and sampled positions
across the fast and general partitions. It is not made debug-only.

**Oracle.** The stage-1-cleaned general path stays the normative
executable oracle. With debug on, fast and general values, all planes and
refusal outcomes are compared, and any divergence fails closed. The fast
answer is never chosen silently, and a mismatch is never hidden by
fallback. Admitted cases and near misses on every gate clause are tested in
both clocks and both debug settings. Differential checks against the pin do
not depend on any adapter helper both arms share.

### Sweeps (F12)

Within one sweep, preparation computes the union of concrete fingerprints
once and shares the immutable projection (`R/precompute-features.R:685-696`;
`R/sweep.R:276-317`). Fingerprints include the ID, so equal definitions
under different IDs are computed separately. Candidates still resolve and
validate their identity and prepare their own aliases and read surface.
Explicit precompute avoids recomputing series only when its ownership and
causal-axis validation passes. This RFC changes the representation and the
calculator's cost, not this reuse boundary.

## 6. Identity (F11)

- **Logical identity is kept in every stage.** Stages 1-3 keep the
  calculation semantics and the existing TTR function, capture and
  parameter identity. Each stage proves these unchanged on fixed inputs:
  - base fingerprints, declared-session active fingerprints and stored
    declarations;
  - the candidate `feature_set_hash` and the sweep `feature_union_hash`;
  - `config_hash`, `alias_map_hash` and `feature_params_hash`;
  - the matching walk-forward candidate, experiment and session identities.
- **The engine version changes in every stage** that changes the
  calculation, certification, evidence or prepared-representation
  implementation. Stage 2 is included even with fixed TTR fingerprints.
  Debug selection is not an identity input.
- **What an engine change invalidates.** An old explicit precompute object
  refuses with `ledgr_precomputed_engine_mismatch` before candidates; it is
  regenerated. Every other precompute validation and refusal stays:
  ownership, axis, grid, fingerprint and alias. A durable sweep keeps its
  recorded engine version. An engine-only change does not change
  `config_hash` or walk-forward keys. It does not change the store schema,
  and it does not make older stored results unreadable.
- **Later fingerprint changes.** Any later change to a fingerprint or
  declaration names its effects on config, feature set and union, and
  walk-forward identity.

## 7. Maintainer answers (2026-11-16)

1. **Stage 1 first,** as its own cut with the pin as oracle, after Cut 21
   (slice 4). The RFC on stages 2-3 measures on the cleaned path.
2. **Internal registry.** Only ledgr ships adapters for now. The interface
   is written so it could later be opened to sister packages, but no public
   adapter contract is promised before CRAN.
3. **Plain R.** The simple path makes one direct adapter call per
   instrument without the segment machinery. A matrix entry point is
   considered only if a measured gap remains. Compiled code is out of
   scope.
4. **The engine-version repair goes into stage 1.**

The review found no new maintainer question.

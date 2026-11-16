# Feature Engine: Seed v1

- Author: Claude, 2026-11-16, at the maintainer's request (macro plan, order
  after Cut 20, item b: drafted while Cut 21 is reviewed).
- Status: seed, for the maintainer's reading and then a Type 2 review. Binds
  nothing.
- Required by: macro plan WS16 point 6 ("a feature-engine RFC seed follows
  the map's feature numbers") and the order after Cut 20, items b and c (a
  feature cut with its own oracle against the pin, before slice 5).
- Evidence: release/v0.2.3 at `dcc2fa9d`, pin `d5b3a151`.
  `dev/bench/v0_2_3_lean_tuning_profile/`: `results/feature_split.csv`,
  `results/features_h1.csv` (private H1, aggregates only),
  `results/e2e_cut18_groups.csv` and the new `feature_steps.R` with
  `results/feature_steps.csv`.
- Not decided here: the feature cut itself, any compiled code (it needs the
  maintainer's named decision), a TA-Lib adapter, new indicators.

## 1. The question

Features are the largest cost of a wide run after the store write: 21 percent
of a 500 x 1,260 run and 40 percent of a 1,166 x 252 run, and 20 percent of
an 8-candidate sweep on 500 x 1,260 (`e2e_cut18_groups.csv`). Bare TTR on
the same closes takes a fifth to a tenth of that time. The macro plan asks
for a seed that:

- finds where the feature time goes;
- keeps adapters pluggable (TTR now, TA-Lib later);
- settles how sweeps prepare and reuse features across candidates.

The seed separates what can be removed with the same values and no
contract change (no RFC needed) from what changes an interface (RFC-sized).

## 2. Where the time goes

`feature_split.csv` (SMA 5 and 10, the published crossover):

| shape | ledgr features | bare TTR | the rest |
| --- | ---: | ---: | ---: |
| 10 x 7,200 | 0.08 s | 0.00 s | 0.08 s |
| 500 x 1,260 | 0.83 s | 0.08 s | 0.75 s |
| 1,166 x 252 | 1.10 s | 0.17 s | 0.93 s |

On private H1 (1,166 instruments, 7,213 sessions), 582 instruments (50
percent) have the simple shape: one feature range, one input run, no
terminal, no carried input. On those, the pin takes 7.8 ms per instrument
and bare TTR 0.29 ms, with identical values (`features_h1.csv`).

Until now "the rest" was one number. `feature_steps.R` splits it by Rprof
sampling of the pin's run path (compute, then projection;
`R/backtest-runner.R:664-680`) and sweep path (compute, the per-instrument
payload split, then the rebuild; `R/sweep.R:276-291`). A run computes SMA 5
and 10; a sweep computes the union of `sweep_map.R`'s grid, SMA 3, 5, 8, 12,
20 and 40. Seconds per step, three repetitions (descriptive: another job
shared the machine):

| step | 10x7200 run | 10x7200 sweep | 500x1260 run | 500x1260 sweep | 1166x252 run | 1166x252 sweep |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| pulse names (`format()` of the axis) | 0.12 | 0.31 | 0.01 | 0.05 | 0.00 | 0.02 |
| TTR raw call | 0.01 | 0.01 | 0.14 | 0.37 | 0.33 | 0.90 |
| input treatment | 0.02 | 0.03 | 0.26 | 0.27 | 0.26 | 0.33 |
| calculate: runs, carry | 0.01 | 0.03 | 0.15 | 0.42 | 0.17 | 0.63 |
| segment frame and rest | 0.00 | 0.03 | 0.06 | 0.30 | 0.09 | 0.31 |
| plane exceptions and records | 0.00 | 0.01 | 0.02 | 0.12 | 0.09 | 0.17 |
| payload split and rebuild (sweep) | - | 0.13 | - | 0.20 | - | 0.18 |
| certification, causality probe | 0.01 | 0.03 | 0.01 | 0.01 | 0.00 | 0.00 |
| other (ranges, projection indexing, the rest) | 0.07 | 0.00 | 0.08 | 0.03 | 0.08 | 0.02 |
| **whole path** | **0.25** | **0.59** | **0.74** | **1.78** | **1.04** | **2.56** |

Bare TTR for the sweep's six definitions takes 0.24 s on 500 x 1,260 and
0.48 s on 1,166 x 252.

Reading:

- **Narrow long runs:** half the feature time is `format()` of the
  POSIXct pulse axis, done once per feature
  (`ledgr_projection_pulse_names()`, `R/runtime-projection.R:35, 40, 48,
  105`). It does not depend on the data.
- **Wide runs:** the cost is spread over the per-instrument machinery.
  - The TTR raw call takes about twice bare TTR (0.33 against 0.17 s on
    1,166 x 252). Per call it builds the TTR input from the segment's data
    frame, looks up the function and goes through `do.call()`
    (`R/indicator-ttr.R:852-863`): about 70 us over 2,332 calls. The
    segment frame it reads is built separately (`segment frame`).
  - Input treatment covers all five bar fields whatever a definition
    requires (`R/history-features.R:186-207`).
  - Runs and carry, framing and the evidence planes together cost more
    than TTR itself.
- **Sweeps:** each distinct definition is computed once for all candidates
  (the union by fingerprint, `R/precompute-features.R:685-696`). The
  per-candidate cost is the fold, not the features. The split into one
  vector per instrument and the rebuild into matrices
  (`R/history-substrate.R:396-399`, `R/runtime-projection.R:150-177`) exist
  only on the sweep path.
- Certification and the causality probe are negligible on these shapes.

## 3. What the code does today

One per-instrument engine serves every definition (`R/history-features.R`):

1. **Certification.** Each definition is certified once per compute call,
   against catalogue candidates built fresh, including a synthetic TTR call
   (`:19-151`).
2. **Ranges.** The knowledge ranges per instrument are found (`:412-428`).
3. **Inputs.** The inputs are treated per instrument and range (`:169-218`).
4. **Calculation.** Per instrument x range x definition x segment
   (`:329-407`), with four segment branches (`:282-324`):
   - the built-in SMA, a `vapply` over every window;
   - TTR, a data frame and a raw call;
   - custom `series_fn`, one call per segment;
   - custom `fn` only, one call per ready bar.
5. **Evidence.** The evidence planes are built per instrument (`:540-611`).
6. **Causality probe.** One probe per definition (`:627-742`).
7. **Projection.** The projection indexes the planes and formats the axis
   per feature (`R/runtime-projection.R`).

The adapter contract is `ledgr_indicator` (`R/indicator.R:86-172`): `fn`,
an optional `series_fn`, `requires_bars`, `stable_after`, `params`, and a
`source` of `ledgr`, `TTR` or `custom`. TTR is hard-wired outside its
adapter file:
- catalogue candidates (`R/history-features.R:120-149`);
- the kind dispatch and call key (`:70-80`, `:294-307`);
- the `source` enum (`R/indicator.R:137`);
- the parameter registry (`R/feature-parameters.R:290-299`);
- the provenance list (`R/strategy-provenance.R:105`);
- the catalogue rows (`R/indicator-history.R:203-268`).

A second adapter today can only be `custom`: its own `series_fn` per
segment, no catalogue treatment.

Two defects found while mapping:

- `ledgr_feature_engine_version()` hashes helper bodies but omits
  `ledgr_ttr_raw_call`, `ledgr_ttr_select_output`,
  `ledgr_feature_plane_exceptions` and the causality functions
  (`R/features-engine.R:1-92`). The contract says the identity "binds
  every helper of this calculation" (Availability-Aware Strict Features).
- The comment at `R/history-features.R:624-625` says built-in and catalogue
  rows are not refuted at runtime, but the prefix-invariance probe runs for
  them (`:688-704`). It costs little; the comment or the code is wrong.

Dead code: four accessor functions in `R/runtime-projection.R:357-559` are
called only from `dev/`.

## 4. Constraints

- **Same values.** Every value, plane, reason and refusal stays identical
  to the pin; the pin is the oracle, as in Cut 17. The contracts
  (Indicator Computation And Identity, Availability-Aware Strict Features,
  TTR Adapter) stay as they are unless an RFC changes them.
- **Constructor functions.** Catalogue rows are computed with the
  constructor's own functions. A faster path may call TTR differently, but
  it may not substitute another implementation of SMA.
- **Remove before adding** (maintainer, standing): removed work comes
  before new paths, caches or kernels.
- **No compiled code** without the maintainer's named decision.
- **No backward compatibility** before CRAN: a changed in-memory precompute
  object or engine version needs no reader for the old one.

## 5. Proposal

### Stage 1: remove work (same values, no contract change; a cut, no RFC)

1. **Format the pulse axis once** per projection, not once per feature.
   Expected about half the feature time on narrow long runs (0.12 of 0.25 s
   on 10 x 7,200).
2. **Treat only the fields the run's definitions require.** Today all five
   are treated. Treatment stays "once per preparation" as the contract says.
3. **Cut the per-call TTR overhead.** Resolve the TTR function once per
   definition, not once per segment. For single-field inputs (`close`),
   pass the treated vector directly instead of a segment data frame.
   Multi-field inputs (`hl`, `hlc`, `ohlc`, `hlcv`) keep the frame until
   measured. TTR's own function still computes every value. Expected: most
   of the 0.16 s the raw call adds over bare TTR on 1,166 x 252.
4. **Keep matrices on the sweep path.** Drop the per-instrument split and
   rebuild, as the run path already does. Expected 0.1-0.2 s per sweep on
   wide shapes.
5. **Fix the engine-version gap** (Section 3): hash every helper the
   calculation uses, so the version moves when they change.
6. **Delete the dead accessors**, and make the probe comment match the code.

These change no value and no contract, so under the family method they need
a cut note, not an RFC. The pin is the oracle on every plane, with a
paired timing.

### Stage 2: an adapter interface (RFC-sized)

Replace the TTR hard-wiring with one registered adapter description that
both TTR and a later TA-Lib adapter fill:

- **name**, plus the package and version that enter identity, as
  `params$ttr_version` does today;
- **catalogue rows**: function, output, algorithm-changing arguments,
  history class, required fields, input-carry family;
- **warmup rules** per function;
- **a vector call**: one instrument's treated input vectors and the
  arguments in, an aligned numeric vector out;
- **an optional matrix call**: instruments x sessions in, the same shape
  out;
- **a certification candidate** builder.

Certification, the kind dispatch, the `source` values, the parameter
registry and provenance read the registered adapters instead of naming TTR.
`ledgr_ind_ttr()` becomes the TTR adapter's constructor, with an unchanged
fingerprint. If the fingerprint has to change, that is an identity change
and needs the maintainer's decision.

### Stage 3: a matrix path for simple instruments (RFC-sized)

An instrument is simple when it has one knowledge range, one input run, no
terminal and no carried input. These are half of H1, and every instrument of
the simulated published shapes.

- For each definition, all simple instruments are computed in one matrix
  call, or one vector call per instrument with no segment machinery. Their
  evidence planes are empty by construction and are checked by vector
  operations.
- Every other instrument keeps today's per-instrument path. That path
  stays the fallback and, with debug on, the differential oracle, as Cut 18
  did for the loop's fast paths.
- The gate predicate is stated once and tested on both sides (Cut 15's rule
  for fast paths).
- Expected on simple instruments: from 7.8 ms to near TTR's 0.3 ms each.

### Sweeps

Sweeps already compute each distinct definition once. Stage 1 removes the
split and rebuild. Stage 3 brings a swept parameter's cost close to bare
TTR per value. No per-candidate feature work remains. The precompute object
(`ledgr_precompute_features()`) is public but held only in memory; its
shape may change with the engine version.

## 6. Identity

- **Stage 1:** no value, fingerprint or config hash changes.
  `feature_engine_version` changes, since helper bodies change and item 5
  adds helpers. It is stored in the `sweeps` table and checked by
  precomputed reuse, so precomputed objects from before the change refuse
  as mismatched, which is correct.
- **Stage 2:** none if `ledgr_ind_ttr()`'s fingerprint is kept. Otherwise
  every config hash with a TTR feature changes.
- **Stage 3:** no value or fingerprint change; the engine version changes.

## 7. Questions for the maintainer

1. **Order.** Stage 1 as its own cut now, before the RFC on stages 2-3,
   or everything after the RFC?
   - Stage 1 first: about half of narrow-run feature time and part of
     wide-run time is gone before any interface change, and the RFC
     measures on the cleaned path.
   - All at once: one oracle and one review, but the quick removals wait
     for the RFC.
2. **Adapter registry.** Internal only (TTR now, TA-Lib later by ledgr), or
   public so users and sister packages can register adapters? Public means
   a documented contract and certification rules for third-party rows.
3. **Matrix path.** Plain R only, by vector calls per instrument without
   segment machinery, or also a matrix call where the adapter offers one?
   A compiled kernel is out of scope unless you name it.
4. **Engine-version gap.** Fix it in stage 1, as proposed, or treat it as a
   separate contract correction?

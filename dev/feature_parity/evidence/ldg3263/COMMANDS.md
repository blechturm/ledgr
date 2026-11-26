# LDG-3263 evidence: the gated direct path (stage 3)

Code at dc70fc0d (branch ws44). `S = C:/Users/maxth/ledgr-wt/cut24-scratch`;
the library `$S/libs/ldg3263-dc70fc0d` installed with install_arm.R. Feature
engine version 743b9e7f... (was 88b4237e... at the workstream-43 close).

## What changed (R/)

`R/history-features.R`, inside `ledgr_history_compute_feature_series()` only:

- `ledgr_history_feature_masks()`: the expected mask and terminal planes of
  one instrument and knowledge range, computed once and used by both the
  gate and the treatment (`ledgr_history_feature_inputs()` takes them as an
  argument; its default computes them as before for its other callers).
- `ledgr_history_feature_gate()`: synthesis rule 6's conservative gate, one
  flag per definition: a built-in or catalogue certification, exactly one
  knowledge range (checked by the caller), every calculation column expected
  at the range-end cutoff, every required raw field finite there (one flag
  per field of the preparation's certified field union), no terminal
  asserted anywhere in the prefix. Cheap rejection: the expected and
  terminal masks first. A custom-only preparation builds no gate.
- `ledgr_history_feature_direct_inputs()`: the raw fields of an instrument
  whose every cell is admitted; treatment runs only where a cell needs the
  general path (or debug compares with it).
- `ledgr_history_feature_direct()`: one admitted cell, the adapter's segment
  calculation over the whole slice, values from stable_after on, a slice
  shorter than stable_after making no call; the calculated count
  (ready and finite); one segment record. Output carry has no eligible gap
  on an admitted cell and only clears non-finite values, which the direct
  path does too.
- `ledgr_history_feature_direct_checked()`: debug only; the general path with
  its own raw cache, exact comparison of values, count and plane records or
  of refusal class, message and identifying fields;
  `ledgr_feature_debug_mismatch` on disagreement; an agreed refusal
  re-raises the product condition.
- The loop keeps instrument, range and definition order, direct and general
  cells interleaved; the raw-call cache keeps today's key and lifetime.

`R/features-engine.R` binds the four production helpers; the debug
comparison and the flag are excluded (census rows say so).

## Contract and map

- `inst/design/contracts.md`, Feature Path And Intent Constructors: the bullet
  "Feature computation follows one uncached production path..." replaced by
  the synthesis's exact text (decision 8); no other bullet changed.
- `inst/design/ledgr_v0_2_2_spec_packet/history_representation_map.md`: row
  R36 (oracle, predicate, registered differential, exit).

## Tests

- New: `tests/testthat/test-feature-direct-path.R` (9 blocks): gate choices
  per clause, each clause isolated on its own instrument (custom, a second
  knowledge range with every column expected, unexpected columns, a missing
  close, an NA volume for the definitions that require volume only, a
  terminal in the prefix before a later calculation start); every catalogue
  row, the built-ins, stable_after above requires_bars, an unregistered form,
  an ohlc mapping and a custom definition, under three history policies,
  production with debug off and on equal to the general path (values, planes,
  attributes); later, short (no adapter call) and never-ready slices; empty
  bounds and zero definitions return before any mask or gate; a custom-only
  preparation builds no gate; MACD and BBands raw sharing (one call per
  family, carry family and instrument, as on the general path; the debug
  shadow its own); the causality probe receives the same calculated counts;
  refusals (the admitted runSD(n = 1), competing refusals in both definition
  orders, across instruments and across knowledge ranges) equal the general
  path with debug off and on; the debug comparison fails closed on one
  value, one count, one segment-ready record, one extra record, one
  condition field, one class, and success against refusal; the admitted
  refusal end to end: precompute and sweep write nothing, the run is FAILED
  with no strategy call, ledger event or equity row.
- `tests/testthat/helper-cut24-phases.R`: counts a function's calls by phase
  (certification, production, debug shadow, causality).
- Decision 9 test changes, each with its reason:
  - the engine literals in `test-fingerprint-stability.R:34`,
    `test-strict-feature-acceleration.R:208` and
    `test-strict-ttr-cleanup.R:196` (88b4237e -> 743b9e7f, and 71177b19 ->
    4042761f under that test's own raw-call mock): the engine
    implementation changed;
  - LTB-0143 and LTB-0276: the debug shadow adds calls (the suite runs with
    debug on: 46 segment calls against 42, 8 TTR calls against 7). The
    counts are now observed by phase, with debug off and on: production and
    causality counts exactly the former ones (7 and 35 segment calls; 1 + 1
    and 1 + 2 TTR calls plus 5 causality), the shadow asserted separately
    (4 admitted built-in cells; 1 admitted TTR cell; 0 on the gapped
    series). The values, canonical-dispatch, raw-sharing, source and refusal
    assertions are unchanged; the MACD count block is unchanged (the gapped
    series is never admitted).

`targeted_tests.txt`: 5 files, 20 tests, 0 failed. The 38-file feature
subset (filter feature|indicator|history|ttr|precompute|strict|fingerprint|
debug, debug on) failed only the five decision-9 expectations before these
changes.

## Oracle against the pin (both debug settings)

    Rscript dev/feature_parity/runner.R --arm=ldg3263_debug<d> --lib=$S/libs/ldg3263-dc70fc0d --out=$S/ldg3263/oracle/debug<d> --debug=<d>
    Rscript dev/feature_parity/check.R --pin=$S/oracle/pin --candidate=$S/ldg3263/oracle/debug<d>

`check_debug0.txt`, `check_debug1.txt` (the checker as it stood at the
workstream-43 close): every semantic component equals the pin on all 631
cases with debug off and on: values and NA placement, planes, projections,
history reads, certification, field union, callback frames, causality,
refusal classes and digests, RNG, and the production route with debug off.
What differs is exactly the mechanism stage 3 changes: debug off, the
hand-offs and treated fields of 216 cases (admitted instruments are not
treated); debug on, the route of 238 cases (the shadow's calls). LDG-3264
replaces those observations.

## Calculated counts

    Rscript dev/feature_parity/counts.R --lib=$S/libs/ldg3263-dc70fc0d --out=$S/ldg3263/counts
    Rscript dev/feature_parity/counts.R --lib=... --out=$S/ldg3263/counts-fault --fault=count

`counts_check.txt`: COUNTS CHECK PASS, 385 cells (296 positive) equal to the
base general-path matrices frozen in LDG-3258 (counts_expected.csv), with the
dense preparations now admitted. `counts_fault.txt`: COUNTS CHECK FAIL (the
count-only fault is caught).

## Gut

    Rscript dev/feature_parity/evidence/ldg3263/gut.R --lib=$S/libs/ldg3263-dc70fc0d > gut_output.txt

The gate's full-coverage clause removed in that process; every corpus
substrate and certified definition set prepared with debug on and off.
`gut_output.txt`, complete: in the 30 cases where the gutted gate admits
more cells (both panels and the empty-history substrate), debug on refuses
every one with `ledgr_feature_debug_mismatch`, and debug off returns a
different outcome from the real gate (the real gate's values against a
refusal from the uncovered cells). The three hostile substrates admit no
cell even gutted: their instruments fail the range and terminal clauses as
well, so the gut cannot act there; recorded as found. GUT PASS.

## Census

    Rscript dev/feature_parity/census.R --lib=$S/libs/ldg3263-dc70fc0d --out=$S/ldg3263/census-lib --census=dev/feature_parity/census.csv

`census_check.txt`: CENSUS CHECK PASS; 315 reachable, 163 bound (159 plus
the four direct-path helpers), 152 excluded (150 plus the debug comparison
and the flag), each proved by replacement.

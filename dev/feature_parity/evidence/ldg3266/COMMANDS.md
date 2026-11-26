# LDG-3266 commands and results (dropped branch)

Stage 3 was dropped by LDG-3265. The final commit add30fed returns R/, tests,
NAMESPACE, DESCRIPTION, the contract bullet and map row R36 to the
workstream-43 close 2dee0f98:

    git diff --stat 2dee0f98 add30fed -- R tests NAMESPACE DESCRIPTION inst/design/contracts.md inst/design/ledgr_v0_2_2_spec_packet/history_representation_map.md

prints nothing. The engine version is therefore the stage-2 one (88b4237e),
and no second engine change is required (LDG-3266's dropped-branch item).
`S = C:/Users/maxth/ledgr-wt/cut24-scratch`.

## Removed and retained

- Removed from the product: the gate, the finiteness pass, the direct
  calculator and inputs, the debug comparison (R/history-features.R,
  R/features-engine.R back to 2dee0f98); the debug flag (R/debug.R): nothing
  in R/ reads it once the comparison is gone, so it is not retained as
  scaffolding and has no identity treatment. Restoring it is one commit
  (015546c3).
- Removed from the tests: test-feature-direct-path.R,
  helper-cut24-phases.R, setup-debug.R, test-debug-flag.R; the three engine
  literals and the LTB-0143 and LTB-0276 count changes are back to their
  2dee0f98 text. No registered test differs from the workstream-43 close.
- Removed from the design records: the contract bullet replacement and map
  row R36 (back to 2dee0f98); the census rows of the stage-3 helpers
  (dev/feature_parity/census.csv back to 2dee0f98).
- Retained, inert without the direct path: the checker's stage-3
  components (gate_expected, gate, shadow, calculated_count, prep_direct),
  the five stage-3 faults (not run: "the library has no direct path"), the
  63 pin-derived corpus cases and gate_expected.csv; dev/feature_parity/
  README.md says so. The rejected implementations stay in history: dc70fc0d,
  ffe19415, b56eaee9.

## Proofs (run_proofs.R, outputs in this folder)

    Rscript dev/feature_parity/evidence/ldg3266/run_proofs.R --final=add30fed

In order: install the final arm ($S/libs/final-add30fed); the permanent
oracle on the final arm with --debug=0; check.R pin (LDG-3264's
$S/ldg3264/pin) against the pin repeat and against the final arm; faults.R
on the final library; identity.R on the workstream-43 close library
(final-8f7c6977) with its store, then on the final library reading it, and
identity_check.R in unchanged-engine mode (prefix 88b4237e); emitted_pin.R;
counts.R; census.R; lines.R against 2dee0f98. A first run used the
workstream-43 identity record without a store and stopped at identity.R
(gzfile: no precompute.rds); the identity_ws43 step was added and the whole
sequence rerun, these outputs are that rerun.

- `check_pin_repeat.txt`, `check_final.txt`: CHECK PASS; 694 cases (99
  refusing on the pin), 11,791 observations in each arm; every component
  equal to the pin, routes and hand-offs included; gate and shadow empty.
- `faults.txt`, `faults/`: FAULTS PASS; the eight existing faults and the
  structural controls as before, signal sets pairwise distinct; the five
  stage-3 faults not run (the library has no direct path, checked before
  running).
- `identity_check.txt`: IDENTITY CHECK PASS; 156 of 156 expected
  identities equal, the engine version included (88b4237e on both); the
  workstream-43 explicit precompute is reused with the same result table as
  fresh preparation; its stored run (30 equity rows) and sweep stay readable.
- `emitted_pin_final.txt`: EMITTED PIN PASS, 134 of 134.
- `counts_final.txt`: COUNTS CHECK PASS, 385 calculated-count cells equal to
  the base matrices.
- `census_check.txt`, `census/`: CENSUS CHECK PASS; 159 bound, 150 excluded
  (as at the workstream-43 close).
- `lines.csv`: R/ production lines 54,966 -> 54,966 (0).
- `shapes.md`: no preparation code changed; nothing to walk.

Direct-backend TTR parity with derived outputs: the registered tests in
tests/testthat/test-indicator-ttr.R pass in the full suite below.

## Full suite and check (verification library, as workstream 43's close)

    Rscript dev/feature_parity/evidence/ldg3266/verify/full_tests_verify.R
    Rscript dev/feature_parity/evidence/ldg3266/verify/buildcheck_verify.R

`verify/full_tests_summary.txt`: duckdb 2.0.0, nanonext 1.10.4, mirai 2.7.4
from $S/verify-lib; 233 files, 1,364 tests, 0 failed, 0 errors, 1 skipped
(the quantmod missing-package path). With no debug flag there is no
debug-on suite. `verify/r_cmd_check.log`: Status OK. A first build attempt
failed while the proof rerun held an evidence file open (file.copy:
Permission denied); the build was rerun after the proofs finished.

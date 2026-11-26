# LDG-3264 evidence: stage-3 mechanism observations in the permanent checker

Harness at 931c2499; candidate library `$S/libs/ldg3263-dc70fc0d` (R/ is
unchanged after dc70fc0d); pin library
`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`; `S = C:/Users/maxth/ledgr-wt/cut24-scratch`.

## Test-change reason (synthesis rule 11)

The direct path removes the treatment hand-off of every instrument whose
cells are all admitted, and debug adds shadow work. On the checker as it
stood at the workstream-43 close the candidate differed from the pin only
there (LDG-3263 `check_debug0.txt`: handoffs and treated_fields of 216
cases; `check_debug1.txt`: route of 238 cases); every semantic component
was equal. Those mechanism observations are replaced as below; nothing else.

## What changed

- `runner.R`: per preparation, the direct cells and untreated instruments
  observed at the seams `ledgr_history_feature_direct()` and
  `ledgr_history_feature_direct_inputs()` (component `gate`); the harness's
  own conservative predicate on the arm's substrate primitives, taken before
  any fault or recorder, on each preparation's own arguments
  (`gate_expected`); the debug shadow's cells and calls, counted at
  `ledgr_history_feature_calculate()` inside the debug comparison and kept
  out of the production `route` (`shadow`); the calculated-count matrices at
  the causality seam, recorded innermost (`calculated_count`); `handoffs`
  gains `prep_direct`; provenance gains `direct_path`. No product counter:
  every observation is a wrapper the harness installs in its own process.
- `check.R`: `gate_expected` equal to the committed `gate_expected.csv` on
  every arm (and, like every other component, between the arms); `gate`
  equal to the expectation on an arm with the direct path (untreated
  instruments only with debug off; a prefix on refusing cases), empty on
  an arm without it; `shadow` none with debug off and one shadow cell per
  direct cell with debug on; `handoffs` reach and causality fields equal to
  the pin's and inputs observed plus untreated ranges equal to the pin's
  inputs observed; the treated-fields rule counts untreated ranges as
  observed hand-offs. route, callback, causality, treated fields, the read
  entry, TTR route agreement, refusals and every data component are still
  compared with the pin and the corpus as before; `calculated_count` is
  compared with the pin.
- `faults.R`: five stage-3 faults, run only on a library with the direct
  path: wrong_admission, missing_treatment, missing_raw_sharing,
  wrong_payload_refusal, count_only.
- `corpus.R`: runsd_one (an admitted refusing cell, TTR runSD n = 1),
  competing_first and competing_second (with a custom refusal, both
  orders): 63 cases (694 in all).
- Expectations written from the pin only, never from the candidate:
  `corpus_expected.csv` regenerated from the pin run, diff reviewed: 315
  rows added (the 63 cases), none removed or changed (`git diff`: 315
  insertions, 0 deletions); `gate_expected.csv` written from the pin's
  `gate_expected` (`check.R --write-gate-expected=`), 288 cases with
  admitted cells. A first pin run exposed a harness bug (an instrument
  passing the masks with no admitted cell wrote a stray `@<id>` entry); the
  predicate was fixed and the pin rerun before anything was committed.

## Commands

    Rscript dev/feature_parity/runner.R --arm=pin --lib=<pin lib> --out=$S/ldg3264/pin --debug=0
    Rscript dev/feature_parity/runner.R --arm=pin_repeat --lib=<pin lib> --out=$S/ldg3264/pin_repeat --debug=0
    Rscript dev/feature_parity/check.R --pin=$S/ldg3264/pin --write-expected=<csv>
    Rscript dev/feature_parity/check.R --pin=$S/ldg3264/pin --write-gate-expected=<csv>
    Rscript dev/feature_parity/runner.R --arm=ldg3264_debug<d> --lib=$S/libs/ldg3263-dc70fc0d --out=$S/ldg3264/cand_debug<d> --debug=<d>
    Rscript dev/feature_parity/check.R --pin=$S/ldg3264/pin --candidate=<pin_repeat | cand_debug0 | cand_debug1>
    Rscript dev/feature_parity/faults.R --lib=$S/libs/ldg3263-dc70fc0d --pin=$S/ldg3264/pin --scratch=$S/ldg3264/faults --evidence=dev/feature_parity/evidence/ldg3264/faults

## Results

- `check_pin_repeat.txt`, `check_debug0.txt`, `check_debug1.txt`: CHECK
  PASS; 694 cases (99 refusing on the pin), 11,791 observations per arm.
- Candidate observations: 3,786 direct cells in 272 cases, the same with
  debug off and on; 554 untreated ranges with debug off, none with debug on;
  the run, implicit sweep, explicit precompute and pulse-inspection cases of
  both clocks take direct cells; the pin records none.
- `faults.txt`, `faults/`: FAULTS PASS, every control as expected and the
  signal sets pairwise distinct (`faults/faults.csv`). New controls:
  wrong_admission `gate` only (values unchanged); missing_treatment `gate`
  with the values, hand-offs and refusals it breaks; missing_raw_sharing
  `route`; wrong_payload_refusal `refusal` only (same class, changed
  identifying field); count_only `calculated_count` only. Kept: the eight
  existing faults (all_fields run, the library has the selector), missing
  arm, case and component (exit 2), cleared treated fields, dropped
  causality phase and the shared observer loss on refusing cases (exit 1,
  treated_fields), pin against pin (exit 0). No certification-refusal case
  was added to the corpus.

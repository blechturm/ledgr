# LDG-3270: Cut 25 final-code proofs

Host: Windows 11 Pro x64, R 4.6.1, the maintainer's default library
(duckdb 2.0.1, mirai 2.7.4, nanonext 1.10.4, TTR 0.24.4); no verification
library. Run 2026-11-26. Nothing here is a timing record.

Candidate library: `C:/Users/maxth/ledgr-wt/cut25-scratch/libs/cand-4abdb348`
(`dev/feature_parity/install_arm.R --commit=4abdb348`). `R/` is unchanged
from 4abdb348 to the final commit (`r_tree.txt` checks it at 5a30bd3f; the
later commits 26e7e380 and 74e6f822 change only `inst/design/` and three test
literals). Pin observations: LDG-3264's
`C:/Users/maxth/ledgr-wt/cut24-scratch/ldg3264/pin` and `pin_repeat`.
Identity base: LDG-3266's record of the workstream-43 close library
(`cut24-scratch/ldg3266/identity_ws43`, engine 88b4237e).

## Commands and results

    Rscript dev/feature_parity/runner.R --arm=cand_4abdb348 --lib=<candidate library> --out=C:/Users/maxth/ledgr-wt/cut25-scratch/oracle/cand --debug=0
    Rscript dev/feature_parity/check.R --pin=<pin> --candidate=<oracle/cand> --write-declared=dev/feature_parity/declared_expected.csv
        (after declared_semantics.R passed on the same library)
    Rscript dev/feature_parity/evidence/ldg3270/run_proofs.R --final=5a30bd3f

`run_proofs.R` writes one transcript per step here:

| step | result |
| --- | --- |
| `check_final` | CHECK PASS (declared: 52 cases compared with declared_expected.csv) |
| `check_final_declared_none` | CHECK FAIL, 14 signals, as required without the declared file |
| `check_pin_repeat` | CHECK PASS with `--declared=none` |
| `check_pin_as_candidate` | CHECK FAIL, 12 signals: the declared difference is absent on the pin |
| `oracle_flips_final` | 52 non-treated-fields differences, exactly the declared cases; 270 treated_fields-only |
| `semantics_pin`, `semantics_candidate`, `semantics_compare` | SEMANTICS PASS: 52 of 52 identical to the pin's fn-path twins; declared values digests 52 of 52 |
| `declared_controls` | DECLARED CONTROLS PASS (ten controls, `declared_controls/declared_controls.csv`) |
| `identity_final`, `identity_check` | IDENTITY CHECK PASS, changed-engine mode: 155 of 155 equal, engine 88b4237e to 100eff97, old precompute refused with ledgr_precomputed_engine_mismatch and 0 strategy calls, old run and sweep readable |
| `emitted_pin_final` | EMITTED PIN PASS, 134 of 134 |
| `counts_final` | COUNTS CHECK PASS, 385 of 385 |
| `census_check` | CENSUS CHECK PASS |
| `lines` | `lines.csv`: R/ production lines 54,966 to 54,986 (features-engine.R -3, timestamp.R +23); the bind list unchanged at 59 |

Run on their own:

    Rscript dev/feature_parity/faults.R --lib=<candidate library> --pin=<pin> --declared=dev/feature_parity/declared_expected.csv --scratch=C:/Users/maxth/ledgr-wt/cut25-scratch/faults --evidence=dev/feature_parity/evidence/ldg3270/faults

`faults.txt`, `faults/faults.csv`: FAULTS PASS. The unfaulted library passes
with the declared file; the eight product faults each exit 1 with their own
signal, the signal sets pairwise distinct; the five stage-3 faults are not
run (no direct path, checked before running); the seven controls made from
pin observations use `--declared=none` and behave as before.

    Rscript dev/feature_parity/evidence/ldg3270/full_tests.R --lib=<candidate library> --tree=C:/Users/maxth/ledgr-wt/cut25

`full_tests_run1_4abdb348.log`: 1,366 tests, 3 failed, all three the
registered engine-version literals (cut amendment_engine_literals).
`full_tests_final.log` at 74e6f822: 233 files, 1,366 tests, 0 failed, 0
errors, 1 skipped (quantmod's missing-package path).

    Rscript dev/feature_parity/evidence/ldg3270/buildcheck.R

`buildcheck.txt`, `r_cmd_check.log`: R CMD build of the worktree and R CMD
check --no-manual --no-build-vignettes of the tarball.

    Rscript tools/governance-report.R

The finding set equals the cut base ca635540's (no finding added).

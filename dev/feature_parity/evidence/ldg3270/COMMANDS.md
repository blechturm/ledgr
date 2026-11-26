# LDG-3270: Cut 25 final-code proofs

Host: Windows 11 Pro x64, R 4.6.1, the maintainer's default library
(duckdb 2.0.1, mirai 2.7.4, nanonext 1.10.4, TTR 0.24.4); no verification
library. Run 2026-11-26. Nothing here is a timing record.

Round 2 (after close review round 1): every proof below was rerun on the
corrected candidate library `C:/Users/maxth/ledgr-wt/cut25-scratch/libs/cand-812ed1e2`
(`dev/feature_parity/install_arm.R --commit=812ed1e2`). Between round 1's
library (4abdb348) and this one only `R/timestamp.R` changed (F1); the
oracle observations of the two libraries are byte-identical (12,051 rows,
`cut25-scratch/oracle/cand` and `oracle/cand2`). `r_tree.txt` checks that the
library's R/ equals the proof commit's. Pin observations: LDG-3264's
`C:/Users/maxth/ledgr-wt/cut24-scratch/ldg3264/pin` and `pin_repeat`.
Identity base: LDG-3266's record of the workstream-43 close library
(`cut24-scratch/ldg3266/identity_ws43`, engine 88b4237e).

## Commands and results

    Rscript dev/feature_parity/runner.R --arm=cand_812ed1e2 --lib=<candidate library> --out=C:/Users/maxth/ledgr-wt/cut25-scratch/oracle/cand2 --debug=0
    Rscript dev/feature_parity/evidence/ldg3270/run_proofs.R --final=e99afc33

The declared file was written once in round 1 from the 4abdb348 run
(`check.R --write-declared=`), after `declared_semantics.R` passed on that
library; it was not regenerated.

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
| `governance_compare` | `governance/`: GOVERNANCE COMPARE PASS, the final commit's finding set equals the cut base ca635540's with line numbers removed (no finding added) |

Run on their own:

    Rscript dev/feature_parity/faults.R --lib=<candidate library> --pin=<pin> --declared=dev/feature_parity/declared_expected.csv --scratch=C:/Users/maxth/ledgr-wt/cut25-scratch/faults2 --evidence=dev/feature_parity/evidence/ldg3270/faults

`faults.txt`, `faults/faults.csv`: FAULTS PASS on cand-812ed1e2. The
unfaulted library passes with the declared file; the eight product faults
each exit 1 with their own signal, the signal sets pairwise distinct; the
five stage-3 faults are not run (no direct path, checked before running);
the seven controls made from pin observations use `--declared=none` and
behave as before. Every row records its library and declared option.

    Rscript dev/feature_parity/evidence/ldg3270/full_tests.R --lib=<candidate library> --tree=C:/Users/maxth/ledgr-wt/cut25

`full_tests_run1_4abdb348.log`: 1,366 tests, 3 failed, all three the
registered engine-version literals (the cut's amendment_engine_literals).
`full_tests_final.log` at 812ed1e2 with cand-812ed1e2: 233 files, 1,366
tests, 0 failed, 0 errors, 1 skipped (quantmod's missing-package path).

    Rscript dev/feature_parity/evidence/ldg3270/buildcheck.R

`buildcheck.txt`, `r_cmd_check.log`: R CMD build of the worktree and R CMD
check --no-manual --no-build-vignettes of the tarball.

Close review round 1 controls (dev/bench/v0_2_3_cut25_chores/):
`sweep_witness.R` (results/sweep_witness_none.txt passes;
_recovery_value.txt and _na_evidence.txt fail at pulses 5 and 4) and
transcripts/test-timestamp_prefix_4abdb348.txt (the uncorrected parser fails
LTB-0566's AsIs assertion).

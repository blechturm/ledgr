# LDG-3255 commands

`S = C:/Users/maxth/ledgr-wt/ws41-scratch`; `<pin>` the read-only library
`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`; `<ws41>` this worktree. Every
`Rscript` is `"C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"`, one call per
shell command.

Final arm and oracle:

    Rscript dev/feature_parity/install_arm.R --repo=<ws41> --commit=45df6928 --lib=$S/libs/final-45df6928
    Rscript dev/feature_parity/runner.R --arm=final_45df6928 --lib=$S/libs/final-45df6928 --out=$S/oracle/final
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v2/pin --candidate=$S/oracle/final > check_final.txt
    Rscript dev/feature_parity/faults.R --lib=$S/libs/final-45df6928 --pin=$S/oracle/v2/pin
      --scratch=$S/oracle/final_faults --evidence=dev/feature_parity/evidence/ldg3255/faults

Full tests (a script file run with the worktree and the final library; it
prepends the library to `.libPaths()`, sets `R_LIBS` to it so sweep workers
load the same code, then):

    pkgload::load_all('<ws41>', quiet = TRUE); testthat::test_local('<ws41>', reporter = 'summary', load_package = 'none')

Build and check (a script file: Quarto and Pandoc from
`C:/Program Files/RStudio/resources/app/bin/quarto/bin`, as dev/build-site.R
sets them; working directory `$S/buildcheck`):

    R CMD build <ws41>
    R CMD check --no-manual --no-build-vignettes ledgr_0.2.2.tar.gz

Lean gate (the lean core loads only the pin; the wrapper overlays this cut's
changed R/ files on the pinned namespace after load and runs loop_parity.R
unchanged):

    Rscript dev/feature_parity/lean_gate.R --tree=<ws41> --base=b33e01d7 --overlay-log=lean/overlay_debug<0/1>.txt
      --lib=<pin> --debug=<0/1> --freeze=dev/lean_core/parity/loop_freeze.csv --out=lean/gate_debug<0/1>.csv

Identities:

    Rscript dev/feature_parity/identity.R --lib=$S/libs/base-b33e01d7 --out=$S/identity/base --save-store=1
    Rscript dev/feature_parity/identity.R --lib=$S/libs/final-45df6928 --out=$S/identity/final --old=$S/identity/base
    Rscript dev/feature_parity/identity_check.R --base=$S/identity/base --candidate=$S/identity/final > identity_check.txt

Lines:

    Rscript dev/feature_parity/lines.R --repo=<ws41> --base=b33e01d7 --final=45df6928 --out=lines.csv

Engine-version calls per public entry point: the final library's
`ledgr_feature_engine_version()` wrapped with a counter around one
`ledgr_run()`, `ledgr_sweep()` with 2 and 4 candidates, with and without an
explicit precompute, `ledgr_precompute_features()` and
`ledgr_pulse_snapshot()` (one call each).

Timing: record `final-vs-cut-base` in
`dev/bench/timing/records/cut22-feature-1/` (its COMMANDS.md).

## Close review round 1 (evidence in round1/)

Final code R/ at 39ac4ba4, oracle harness at 574770ff; the same commands with:

    Rscript dev/feature_parity/install_arm.R --repo=<ws41> --commit=39ac4ba4 --lib=$S/libs/final-39ac4ba4
    Rscript dev/feature_parity/runner.R --arm=final_39ac4ba4 --lib=$S/libs/final-39ac4ba4 --out=$S/oracle/v4/final
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v4/pin --candidate=$S/oracle/v4/final > round1/oracle/check_final.txt
    Rscript dev/feature_parity/faults.R --lib=$S/libs/final-39ac4ba4 --pin=$S/oracle/v4/pin
      --scratch=$S/oracle/v4/final_faults --evidence=$S/evidence_round1/faults   (copied to round1/faults)
    Rscript dev/feature_parity/identity.R --lib=$S/libs/final-39ac4ba4 --out=$S/identity/final_r1 --old=$S/identity/base
    Rscript dev/feature_parity/identity_check.R --base=$S/identity/base --candidate=$S/identity/final_r1 > round1/identity_check.txt
    Rscript dev/feature_parity/lines.R --repo=<ws41> --base=b33e01d7 --final=39ac4ba4 --out=round1/lines.csv
    Rscript dev/feature_parity/lean_gate.R --tree=<ws41> --base=b33e01d7 --overlay-log=$S/lean_r1/overlay_debug<0/1>.txt
      --lib=<pin> --debug=<0/1> --freeze=dev/lean_core/parity/loop_freeze.csv --out=$S/lean_r1/gate_debug<0/1>.csv
      (copied to round1/lean)

`$S/oracle/v4/pin` is the pin d5b3a151 run by the round-1 runner (574770ff).
Full tests and build/check as above, the build into `$S/buildcheck_r1`
(round1/full_tests_summary.txt, round1/r_cmd_check.log). The census on the
corrected source is in ../ldg3253/round1/. Timing: record
`final-vs-cut-base-r1` (dev/bench/timing/records/cut22-feature-1/COMMANDS.md).

## Close re-review 1 (evidence in round2/; G1 and G2, harness only)

R/ unchanged at 39ac4ba4 (library `$S/libs/final-39ac4ba4`); harness at the
round-2 commit:

    Rscript dev/feature_parity/runner.R --arm=pin --lib=<pin> --out=$S/oracle/v5/pin
    Rscript dev/feature_parity/runner.R --arm=final_39ac4ba4 --lib=$S/libs/final-39ac4ba4 --out=$S/oracle/v5/final
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v5/pin --candidate=$S/oracle/v5/pin > round2/oracle/check_pin_self.txt
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v5/pin --candidate=$S/oracle/v5/final > round2/oracle/check_final.txt
    Rscript round2/oracle/handoff_summary.R $S/oracle/v5/final > round2/oracle/handoffs_final.txt
    Rscript dev/feature_parity/faults.R --lib=$S/libs/final-39ac4ba4 --pin=$S/oracle/v5/pin
      --scratch=$S/oracle/v5/final_faults --evidence=dev/feature_parity/evidence/ldg3255/round2/faults

The reviewer's negative controls, adapted to this tree, are in
../ldg3249/round2/ (run each script with Rscript; make_driver_probe.R before
fault_driver_control.R).

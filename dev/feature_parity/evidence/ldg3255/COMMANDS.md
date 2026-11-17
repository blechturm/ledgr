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

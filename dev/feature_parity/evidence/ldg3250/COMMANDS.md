# LDG-3250 commands

As LDG-3249's (harness at 1f33fe2c, `S = C:/Users/maxth/ledgr-wt/ws41-scratch`).

    Rscript dev/feature_parity/install_arm.R --repo=<ws41> --commit=74d3e886 --lib=$S/libs/ldg3250-74d3e886
    Rscript dev/feature_parity/runner.R --arm=ldg3250_74d3e886 --lib=$S/libs/ldg3250-74d3e886 --out=$S/oracle/v2/ldg3250
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v2/pin --candidate=$S/oracle/v2/ldg3250 > check.txt

`$S/oracle/v2/pin` is LDG-3249's pin run (its observations are
`evidence/ldg3249/pin_observations.csv`). The legacy inventory
(`legacy_inventory.csv`) is from `git grep` at the cut base b33e01d7 and on
74d3e886 for the three function names, outside inst/design.

Targeted suites (load_all on the working tree, one Rscript call):

    pkgload::load_all('<ws41>'); testthat::test_local('<ws41>', filter = '^(features|fingerprint-stability|strict-feature-acceleration|strict-ttr-cleanup|availability-features|indicator-ttr|indicators|indicator-history|indicator-causality|codebase-contracts|precompute-features|history-integration)$', load_package = 'none')

Timing: `dev/bench/timing/records/cut22-feature-1/COMMANDS.md` (records
aa-cut-base, unit1-axis, unit4-admission).

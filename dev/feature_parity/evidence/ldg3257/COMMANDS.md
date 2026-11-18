# LDG-3257 commands

`S = C:/Users/maxth/ledgr-wt/cut23-scratch`; `<pin>` the read-only library
`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`; `<ws42>` this worktree. Every
`Rscript` is `"C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"`, one call per
shell command. Final R/ is at 68b505b9 (LDG-3256); later commits change only
dev tooling, evidence and the packet.

Arms:

    Rscript dev/feature_parity/install_arm.R --repo=<main checkout> --commit=6d12ef79 --lib=$S/libs/base-6d12ef79
    Rscript dev/feature_parity/install_arm.R --repo=<ws42> --commit=68b505b9 --lib=$S/libs/final-68b505b9

Rebuild coverage (decision 5a):

    Rscript dev/feature_parity/rebuild_coverage.R --lib=$S/libs/final-68b505b9 --out=$S/coverage/final > rebuild_coverage_final.txt
    Rscript dev/feature_parity/rebuild_coverage.R --lib=<pin> --out=$S/coverage/pin > rebuild_coverage_pin.txt

Oracle (corpus.R fx_e2e_features() with ledgr_ind_returns(1) added):

    Rscript dev/feature_parity/runner.R --arm=pin --lib=<pin> --out=$S/oracle/pin
    Rscript dev/feature_parity/runner.R --arm=pin_repeat --lib=<pin> --out=$S/oracle/pin_repeat
    Rscript dev/feature_parity/runner.R --arm=final_68b505b9 --lib=$S/libs/final-68b505b9 --out=$S/oracle/final
    Rscript dev/feature_parity/check.R --pin=$S/oracle/pin --write-expected=dev/feature_parity/corpus_expected.csv
    git diff -U0 dev/feature_parity/corpus_expected.csv > corpus_expected_diff.txt
    Rscript dev/feature_parity/check.R --pin=$S/oracle/pin --candidate=$S/oracle/pin_repeat > check_pin_repeat.txt
    Rscript dev/feature_parity/check.R --pin=$S/oracle/pin --candidate=$S/oracle/final > check_final.txt
    Rscript dev/feature_parity/faults.R --lib=$S/libs/final-68b505b9 --pin=$S/oracle/pin
      --scratch=$S/oracle/final_faults --evidence=dev/feature_parity/evidence/ldg3257/faults

Identities (decision 5b, unchanged-engine mode):

    Rscript dev/feature_parity/identity.R --lib=$S/libs/base-6d12ef79 --out=$S/identity/base_v2 --save-store=1
    Rscript dev/feature_parity/identity.R --lib=$S/libs/final-68b505b9 --out=$S/identity/final --old=$S/identity/base_v2
    Rscript dev/feature_parity/identity_check.R --base=$S/identity/base_v2 --candidate=$S/identity/final
      --mode=unchanged-engine --engine-prefix=bc6a3ea2 > identity_check.txt
    Rscript dev/feature_parity/identity_controls.R --base=$S/identity/base_v2 --candidate=$S/identity/final
      --scratch=$S/identity/controls --engine-prefix=bc6a3ea2 > identity_controls.txt

Census (decision 5c):

    Rscript dev/feature_parity/census.R --source=<ws42> --out=dev/feature_parity/evidence/ldg3257/census
      --census=<ws42>/dev/feature_parity/census.csv > census/census_check.txt
    Rscript dev/feature_parity/census.R --source=<main checkout at bb86c10e, R/ as 6d12ef79> --out=$S/census_base

Probe rerun (decision 5d):

    Rscript dev/spikes/f6_legacy_defs_probe/run_certification.R <ws42> > run_certification_final.txt

Lines:

    Rscript dev/feature_parity/lines.R --repo=<ws42> --base=6d12ef79 --final=68b505b9 --out=lines.csv

Full tests ($S/full_tests.R: the final library first on `.libPaths()` and on
`R_LIBS` for sweep workers, then `pkgload::load_all('<ws42>')` and
`testthat::test_local('<ws42>', reporter = 'summary', load_package = 'none')`),
and build and check ($S/buildcheck.R: Quarto and Pandoc from
`C:/Program Files/RStudio/resources/app/bin/quarto/bin`, then
`R CMD build <ws42>` and `R CMD check --no-manual --no-build-vignettes` in
$S/buildcheck).

Close review round 1, F1 (round2/): the unchanged-engine mode checks each
arm's record names against the committed
dev/feature_parity/identity_names_unchanged_engine.csv (156 names in both
arms, 2 base-only saved-store records, 8 candidate-only reuse and store-read
records), so a record lost from both arms alike fails:

    Rscript dev/feature_parity/identity_check.R --base=$S/identity/base_v2 --candidate=$S/identity/final
      --mode=unchanged-engine --engine-prefix=bc6a3ea2 > round2/identity_check.txt
    Rscript dev/feature_parity/identity_controls.R --base=$S/identity/base_v2 --candidate=$S/identity/final
      --scratch=$S/identity/controls_r2 --engine-prefix=bc6a3ea2 > round2/identity_controls.txt
    # the reviewer's negative records (ws42-close-review-out/identity_negative/<case>/{base,candidate}):
    Rscript dev/feature_parity/identity_check.R --base=<case>/base --candidate=<case>/candidate
      --mode=unchanged-engine --engine-prefix=bc6a3ea2      (round2/reviewer_identity_negatives.txt)

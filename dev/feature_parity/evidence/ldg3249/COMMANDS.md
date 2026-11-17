# LDG-3249 commands

Harness at 1f33fe2c (dev/feature_parity), R 4.6.1, TTR 0.24.4. Scratch
outside the repository: `S = C:/Users/maxth/ledgr-wt/ws41-scratch`. Each
`Rscript` is `"C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"`.

Arms:

    Rscript dev/feature_parity/install_arm.R --repo=<ws41> --commit=b33e01d7 --lib=$S/libs/base-b33e01d7

The pin is the read-only library `C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`
(marker `LEDGR_INSTALLED_FROM_COMMIT` = d5b3a151).

Runs (each a fresh process; provenance.csv in each output directory):

    Rscript dev/feature_parity/runner.R --arm=pin --lib=C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151 --out=$S/oracle/v2/pin
    Rscript dev/feature_parity/runner.R --arm=pin_repeat --lib=C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151 --out=$S/oracle/v2/pin_repeat
    Rscript dev/feature_parity/runner.R --arm=cut_base_b33e01d7 --lib=$S/libs/base-b33e01d7 --out=$S/oracle/v2/cut_base

Corpus (identical to the committed corpus_expected.csv):

    Rscript dev/feature_parity/check.R --pin=$S/oracle/v2/pin --write-expected=<scratch csv>

Checks (transcripts in this folder):

    Rscript dev/feature_parity/check.R --pin=$S/oracle/v2/pin --candidate=$S/oracle/v2/pin_repeat   > check_pin_repeat.txt
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v2/pin --candidate=$S/oracle/v2/cut_base     > check_cut_base.txt

Fault controls (run from an export of the harness at 1f33fe2c; transcripts
and faults.csv in faults/):

    Rscript <export>/dev/feature_parity/faults.R --lib=C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151
      --pin=$S/oracle/v2/pin --scratch=$S/oracle/v2/faults --evidence=dev/feature_parity/evidence/ldg3249/faults

`pin_observations.csv` (this folder) is `$S/oracle/v2/pin/observations.csv`; `pin_provenance.csv` its provenance.

# LDG-3251 commands

As LDG-3249's (harness at 1f33fe2c, `S = C:/Users/maxth/ledgr-wt/ws41-scratch`).

    Rscript dev/feature_parity/install_arm.R --repo=<ws41> --commit=9f4c1a24 --lib=$S/libs/ldg3251-9f4c1a24
    Rscript dev/feature_parity/runner.R --arm=ldg3251_9f4c1a24 --lib=$S/libs/ldg3251-9f4c1a24 --out=$S/oracle/v2/ldg3251
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v2/pin --candidate=$S/oracle/v2/ldg3251 > check.txt

The narrowed-callback fault on the candidate (exit 1, the callback signal):

    Rscript dev/feature_parity/runner.R --arm=ldg3251_narrowed_callback --lib=$S/libs/ldg3251-9f4c1a24 --fault=narrowed_callback --out=$S/oracle/v2/ldg3251_narrowed
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v2/pin --candidate=$S/oracle/v2/ldg3251_narrowed > fault_narrowed_callback.txt

Targeted suites as in LDG-3250, with history-frame and feature-inspection
added. Timing: record unit23-inputs-ttr
(`dev/bench/timing/records/cut22-feature-1/COMMANDS.md`).

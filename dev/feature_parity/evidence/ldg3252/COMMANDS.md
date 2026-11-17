# LDG-3252 commands

`S = C:/Users/maxth/ledgr-wt/ws41-scratch`. The harness ran at 0fbdffe5,
whose runner compared the precompute object without its payload; the pin
reference was rerun under it (`pin_provenance.csv`).

    Rscript dev/feature_parity/install_arm.R --repo=<ws41> --commit=0fbdffe5 --lib=$S/libs/ldg3252-0fbdffe5
    Rscript dev/feature_parity/runner.R --arm=pin --lib=C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151 --out=$S/oracle/v3/pin
    Rscript dev/feature_parity/runner.R --arm=ldg3252_0fbdffe5 --lib=$S/libs/ldg3252-0fbdffe5 --out=$S/oracle/v3/ldg3252
    Rscript dev/feature_parity/check.R --pin=$S/oracle/v3/pin --candidate=$S/oracle/v3/ldg3252 > check.txt

Memory (declared in dev/bench/timing/protocols/cut22-feature-1/protocol.md;
memory.R at 0fbdffe5; memory.log, memory_raw.csv, memory_summary.csv,
memory_spread.csv):

    Rscript dev/feature_parity/memory.R --base=$S/libs/ldg3251-9f4c1a24 --candidate=$S/libs/ldg3252-0fbdffe5
      --work=$S/memory_work --out=$S/memory_out

The diagnosis runs in memory_diagnosis.txt used scratch copies of memory.R's
child mode (with the source frame dropped before the reset, and with
`R_GC_MEM_GROW=0`); they are not records.

Timing: record c5-matrices (dev/bench/timing/records/cut22-feature-1/COMMANDS.md).
The revert restored R/, the registered tests, the dev/bench producers and
the oracle's payload comparison from 9f4c1a24 (9806e927).

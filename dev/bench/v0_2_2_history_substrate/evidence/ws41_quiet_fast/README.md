# WS41 quiet-host fast profile

Tree: `16825307` (product correction `1db8b675`).

The maintainer closed the DAW session that dominated Microsoft Defender's
real-time scanning during the earlier second-correction records, then the
three ordinary fast-profile runs were made one at a time on the otherwise idle
host. All 565 registered blocks pass in each run, with no failure, skip or
warning: 107.02, 105.61 and 106.53 seconds. `gate-record.csv` records the
106.53-second median against the unchanged 112-second bound, and the
registered checker returns `LEDGR_TEST_GATE_OK`.

The LTB-0154 and LTB-0182 warnings recorded in `../ws41_second_correction_fast/`
did not recur with full reporter output captured, which, with the clean
diagnostic pass, indicates a transient condition of the loaded host or
working tree rather than a product or test defect.

Commands:

```text
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_history_substrate/evidence/ws41_quiet_fast --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_history_substrate/evidence/ws41_quiet_fast
```

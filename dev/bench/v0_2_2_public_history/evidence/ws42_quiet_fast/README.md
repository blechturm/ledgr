# WS42 quiet-host fast profile

Tree: `eac3808a` (`ws42/public-history`, including close-review correction
`1ac64ecf`).

The three ordinary fast-profile runs were made one at a time on a host the
maintainer reported as quiet. All 565 registered blocks pass in each run,
with no failure, skip or warning: 106.50, 105.81 and 105.21 seconds.
`gate-record.csv` records the 105.81-second median against the unchanged
112-second bound, and the registered checker returns `LEDGR_TEST_GATE_OK`.

Commands:

```text
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_public_history/evidence/ws42_quiet_fast --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_public_history/evidence/ws42_quiet_fast
```

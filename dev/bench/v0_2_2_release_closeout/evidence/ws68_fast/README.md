# Workstream 68 ordinary fast-profile record

Candidate: `97c42adb` plus the Workstream 68 review record.

Commands, run sequentially on Windows 11 with R 4.6.1:

```text
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_release_closeout/evidence/ws68_fast --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_release_closeout/evidence/ws68_fast
```

All three runs executed 577 of 577 blocks without a failure. Elapsed times
were 112.07, 112.67 and 112.25 seconds. The 112.25-second median exceeds the
unchanged 112-second bound by 0.25 seconds. This is a recorded gate miss, not a
pass. No threshold or profile membership changed.

# Workstream 68 ordinary fast-profile retry

Candidate: `97c42adb` plus the Workstream 65 documentation tree. The
documentation changes do not alter fast-profile membership.

The three runs used the same sequential command and unchanged 112-second
bound as `../ws68_fast`:

```text
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_release_closeout/evidence/ws68_fast_retry --run-index=<1|2|3>
```

All three runs executed 577 of 577 blocks without a failure. Elapsed times
were 112.40, 112.94 and 113.47 seconds. The 112.94-second median exceeds the
unchanged bound. The retry therefore confirms the gate miss; it is not a pass.
No further retry was taken, and no threshold or profile membership changed.

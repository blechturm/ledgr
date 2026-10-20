# WS46 quiet-host fast profile

Tree: `9610dfa9` (`ws46/history-simplification`, after close-review
corrections 1-3).

Three ordinary fast-profile runs on a quiet host under the High performance
power plan, pinned to the performance cores (affinity `0xFFFF`), each
alternating with a run of the integration tree `90c66d11` (accepted Workstream
43) under the same conditions.

| Run | Integration `90c66d11` | WS46 `9610dfa9` |
| --- | ---: | ---: |
| 1 | 109.85 | 104.39 |
| 2 | 109.19 | 108.15 |
| 3 | 110.35 | 104.72 |
| Median | 109.85 | 104.72 |

All registered fast blocks pass in each run (568 on WS46, 565 on the
integration tree) with no failure or skip. `gate-record.csv` records the
104.72-second median against the unchanged 112-second bound, and the
registered checker returns `LEDGR_TEST_GATE_OK`. WS46 is about 5 seconds
faster than the integration tree, mostly from LDG-3077 building the indicator
catalogue once.

Commands (PowerShell, affinity set on the current process before Rscript
starts, so children inherit it):

```text
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_history_simplification/evidence/ws46_quiet_fast --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_history_simplification/evidence/ws46_quiet_fast
```

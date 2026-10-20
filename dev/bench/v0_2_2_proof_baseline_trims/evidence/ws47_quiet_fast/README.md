# WS47 quiet-host fast profile

Tree: `14ad7e44` (`ws47/proof-baseline-trims`, after close-review correction
1, verified by the coordinator). Three ordinary fast-profile runs on a quiet
host under the High performance plan, pinned to the performance cores
(affinity `0xFFFF`), each alternating with a run of the integration tree
`92b5015b` (accepted Workstream 46) under the same conditions.

| Run | Integration `92b5015b` | WS47 `14ad7e44` |
| --- | ---: | ---: |
| 1 | 110.18 | 110.43 |
| 2 | 109.24 | 105.42 |
| 3 | 110.50 | 106.10 |
| Median | 110.18 | 106.10 |

All registered fast blocks pass in each run (570 on WS47, 568 on the
integration tree) with no failure or skip. `gate-record.csv` records the
106.10-second median against the unchanged 112-second bound, and the
registered checker returns `LEDGR_TEST_GATE_OK`. The full suite on a source
copy of `14ad7e44` passed 1,150 blocks with one optional skip.

Commands (PowerShell, affinity set on the current process before Rscript
starts, so children inherit it):

```text
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_proof_baseline_trims/evidence/ws47_quiet_fast --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_proof_baseline_trims/evidence/ws47_quiet_fast
```

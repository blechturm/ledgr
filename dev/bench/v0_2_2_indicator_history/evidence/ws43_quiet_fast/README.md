# WS43 quiet-host fast profile

Tree: `93ce0ecf` (`ws43/indicator-history`, after close-review corrections 1-3
and the re-review 3 record patch).

The three ordinary fast-profile runs were made on a quiet host under the
High performance power plan, with the runner pinned to the performance cores
(affinity mask `0xFFFF`; logical processors 0-15 on the i9-12900K, where a
single-threaded R loop runs in 2.15 s against 5.2 s on the efficiency cores).
Each WS43 run alternated with a run of the accepted integration tree
`42df9de9` under the same conditions.

| Run | Integration `42df9de9` | WS43 `93ce0ecf` |
| --- | ---: | ---: |
| 1 | 103.17 | 108.81 |
| 2 | 100.19 | 107.90 |
| 3 | 99.59 | 107.98 |
| Median | 100.19 | 107.98 |

All 565 registered blocks pass in each run with no failure or skip.
`gate-record.csv` records the 107.98-second median against the unchanged
112-second bound, and the registered checker returns `LEDGR_TEST_GATE_OK`.

WS43 costs about 7.8 s (7.8 percent) over the integration tree. A profile of
`test-strict-feature-acceleration.R` attributes most of the per-block increase
to every built-in indicator constructor rebuilding the 48-row indicator
history catalogue (`ledgr_indicator_history_catalogue()`, about 68 percent of
that file's time); LTB-0142 (+2.2 s) and LTB-0143 (+0.8 s) carry most of it.
Building the catalogue once and indexing it is routed to Workstream 46.

Earlier attempts on the same day are excluded: under the Balanced power plan
both trees ran about 40 percent slower (integration 148.88 s), and an
unpinned High performance series gave WS43 112.38/115.65/108.78 s against an
integration run of 103.39 s.

Commands (from PowerShell, with the process affinity set first so the Rscript
children inherit it):

```text
[System.Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]0xFFFF
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_indicator_history/evidence/ws43_quiet_fast --run-index=<1|2|3>
Rscript --vanilla tools/check-test-gate.R --profile=fast --mode=ordinary --records=dev/bench/v0_2_2_indicator_history/evidence/ws43_quiet_fast
```

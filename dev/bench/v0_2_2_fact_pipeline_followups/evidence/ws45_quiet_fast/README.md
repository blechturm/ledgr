# WS45 quiet-host fast profile

Tree: `ea8f9349` (`ws45/fact-pipeline`, after correction 1 and the
coordinator's re-review fixes). Three ordinary fast-profile runs on a quiet
host under the High performance plan, pinned to the performance cores
(affinity `0xFFFF`), each alternating with a run of the integration tree
`4b33f377`.

| Run | Integration `4b33f377` | WS45 `ea8f9349` |
| --- | ---: | ---: |
| 1 | 104.22 | 103.98 |
| 2 | 104.60 | 104.98 |
| 3 | 104.64 | 105.60 |
| Median | 104.60 | 104.98 |

All 570 fast blocks pass in each run with no failure or skip;
`gate-record.csv` records the 104.98-second median against the 112-second
bound and the checker returns `LEDGR_TEST_GATE_OK`.

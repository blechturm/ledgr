# WS44 phase B quiet-host fast profile

Tree: `e4d23bc5` (`ws44/history-proof`, phase B after correction 1, verified by
the coordinator). Three ordinary fast-profile runs on a quiet host under the
High performance plan, pinned to the performance cores (affinity `0xFFFF`),
each alternating with a run of the integration tree `67f98d6b`.

| Run | Integration `67f98d6b` | WS44 `e4d23bc5` |
| --- | ---: | ---: |
| 1 | 105.57 | 109.17 |
| 2 | 106.30 | 105.81 |
| 3 | 105.67 | 105.69 |
| Median | 105.67 | 105.81 |

All 570 fast blocks pass in each run with no failure or skip;
`gate-record.csv` records the 105.81-second median against the 112-second
bound and the checker returns `LEDGR_TEST_GATE_OK`.

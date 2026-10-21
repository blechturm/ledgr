# WS44 phase A quiet-host fast and review profiles

Tree: `25b4dce9` (`ws44/history-proof`, after correction 3 and the
coordinator's LTB-0371 test addition). Recorded by the coordinator for
LDG-3068 acceptance item 5.

Fast profile, three ordinary runs on a quiet host under the High performance
plan, pinned to the performance cores (affinity `0xFFFF`), each alternating
with a run of the integration tree `630cb7c9`:

| Run | Integration `630cb7c9` | WS44 `25b4dce9` |
| --- | ---: | ---: |
| 1 | 103.19 | 103.89 |
| 2 | 102.75 | 103.37 |
| 3 | 102.92 | 103.56 |
| Median | 102.92 | 103.56 |

All 570 fast blocks pass in each run with no failure or skip;
`gate-record.csv` records the 103.56-second median against the 112-second
bound and the checker returns `LEDGR_TEST_GATE_OK`. The review profile
(`../ws44a_review/`) ran once under the same conditions: 397 blocks, no
failure, 371.0 seconds. The full suite on a source copy of `25b4dce9` passed
1,159 blocks with one optional skip.

Fixture lane disposition (recorded with LDG-3068): 48 of 50 families are
identical to BASE; the other two differ only by the `history_policy` rows that
LDG-3081 adds to the valuation summary, an intended difference.

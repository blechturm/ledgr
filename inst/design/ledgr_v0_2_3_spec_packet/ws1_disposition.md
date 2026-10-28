# WS1 disposition: one output handler

**Role:** record; workstream 1 disposition for v0.2.3 cut 1 (LDG-3132).
**Status:** draft, awaiting the workstream close review.
**Authority:** `tickets.yml` cut 1 and LDG-3126 to LDG-3132; the design note
[ws1_output_handler_design.md](ws1_output_handler_design.md).

## Outcome

ledgr has one output handler, `ledgr_output_handler(sink)`, with a DuckDB
sink (audit_log and db_live) and a memory sink. The handler alone owns the
event column buffer, capacity growth, pulse fill staging, status and
completion bookkeeping and diagnostic numbering. Each handler exposes exactly
its storage kind's former method set, so the compiled spot-FIFO dispatch
guard admits the same handlers as before. Fill-row publication deltas come
from one computation, `ledgr_fill_publication_deltas()` (R3). The two former
constructors are deleted with no alias.

Final candidate: `697f32ee42c395aa6dc282e8a3f05fa8e4ae8d05`.

## Evidence

| Gate | Result | Where |
| --- | --- | --- |
| A0 byte identity | `check.R` exit 0 on the final candidate; `gut.R` exit 0, control passes and all 17 corruptions fail naming their table | LDG-3132 evidence |
| Full tests, build, check | `test_local` exit 0 (1228 blocks, 0 failed, 1 unrelated quantmod skip); `R CMD build` exit 0; `R CMD check --no-manual --no-build-vignettes` exit 0 with 1 NOTE (see below) | LDG-3132 evidence |
| Parity retirement | All 26 blocks inventoried; none retired; worker native-buffer witness LTB-0519 and cross-sink events LTB-0520 added | [ws1_parity_coverage_map.md](ws1_parity_coverage_map.md) |
| Timing | Gate record CHECK PASS: all 18 cells at most 1.03 | [gate_final record](../../../dev/bench/v0_2_3_ws1_timing/records/gate_final/raw.csv) |

## Identity and release impact (cut decision (3))

- Snapshot content identity: none. No snapshot, fact or hash code changed.
- Run configuration identity: none. No config or identity code changed; A0
  records, which embed `config_json`, strategy and run identities, are
  byte-identical.
- Store format fingerprint: none. `ledgr_store_format_bindings()` is
  identical to `07dbbc87` (27 bindings).
- Release impact: product tests and performance records, and one NEWS line.
  No taught behavior, user documentation or dependency changed.

## Timing (protocol ws1-timing-1)

Both records ran on the registered host (High performance, affinity 0xFFFF),
eight alternating pairs, 288 fresh processes each.

- **Base A/A record** (`records/base_aa`, base = candidate = `07dbbc87`):
  CHECK PASS, A/A ratios 0.925 to 1.021.
- **Gate record** (`records/gate_final`, base `07dbbc87`, candidate
  `697f32ee`): CHECK PASS, ratios 0.918 (dense_cost sweep) to 1.021
  (walk_forward run). The 50x1260 cells came out at 1.011 (run) and 1.017
  (sweep), against 0.995 and 1.007 in the A/A record, so the large workload
  may carry a small cost of about 1%, within the bound. Base medians ran about
  5 to 7% higher than in the A/A record in both arms; host snapshot and a 30 s
  CPU trace (mean 16%, max 19%) are kept beside the record.

H6, committed-run median over sweep median, base and candidate:

| Workload | Base | Candidate |
| --- | ---: | ---: |
| dense_cost | 3.09 | 3.31 |
| dense_risk_features | 2.74 | 2.74 |
| dense_dividend_state | 2.96 | 2.92 |
| avail_terminal_resume | 1.66 | 1.62 |
| avail_acquisition | 2.79 | 2.82 |
| avail_incomplete | 2.68 | 2.66 |
| walk_forward | 2.41 | 2.51 |
| timing_scale | 1.46 | 1.44 |
| dense_scale_50x1260 | 1.28 | 1.27 |

WS1 does not change the committed-run versus sweep gap. The roadmap's hope
that one handler would close most of H6 is not borne out: the gap lies
outside the handler code WS1 consolidated.

## Open points

- **Macro WS4 (execution-core consolidation):** the handler composes its
  methods from sink flags at construction and adds no mode branch; WS4 can
  remove dense mode without touching it. The H6 gap remains WS4/WS8 territory.
- **Macro WS7 (one result reader):** the INCOMPLETE `annualized_return`
  difference (sweep row 0, run metrics NA) is unchanged and routed there by
  cut decision (2); Claude recommends NA.
- **Peer benchmark smoke** (`peer_benchmark.R --preset smoke`, ledgr-cost):
  fails at the public-sweep versus internal-oracle trade-summary comparison on
  `07dbbc87` and on the candidate alike. Pre-existing; it needs an owner,
  suggested macro WS3 (peer benchmark suite).
- **R CMD check NOTE:** `ledgr_history_bar_mask_view` in `R/history-frame.R`
  calls `head` without an `utils` import. Pre-existing (file unchanged since
  `07dbbc87`).
- **Governance debt:** 83 pre-existing header and link findings in v0.2.3
  packet documents (spike, brief and review files) entered the scan
  population when the packet became current (LDG-3126).
- **Outside R3:** `R/accounting-replay.R:95`, a reader-side replay fallback,
  computes a cash delta of its own. It is reconstruction, not fill-row
  publication, and stays outside the accepted R3 scope.
- **Recorded debt in moved code:** per-row `meta_json` parsing in memory
  `append_event_rows()` and per-event serialization in `events()` (design
  note Section 12).

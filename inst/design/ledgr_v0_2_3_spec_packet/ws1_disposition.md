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
| Timing | Gate record CHECK PASS: all 18 cells at most 1.03 (numerical pass; the protocol's background-application instruction was not met, see Timing) | [gate_final record](../../../dev/bench/v0_2_3_ws1_timing/records/gate_final/raw.csv) |

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
  5 to 7% higher than in the A/A record in both arms; a host snapshot and 45
  valid CPU samples at 30-second intervals over about 22 minutes (total CPU
  mean 16.1%, max 18.7%) are kept beside the record.

**Host conditions and maintainer disposition.** Both records pass `check.R`
numerically, but neither met the protocol's instruction to close background
applications first (close review
[F1](ws1_close_review.md#f1---p2-numeric-timing-pass-is-presented-as-a-completed-protocol-gate-despite-the-recorded-host-departure)). Maintainer decision,
2026-10-29 (option A): "The maintainer accepts the timing records base_aa and gate_final under their recorded host conditions (Positron and TotalMixFX open in both, Steam additionally at the gate, Codex processes present but idle, High performance plan and P-core affinity 0xFFFF verified per row). Rationale: alternating base/candidate pairs expose both arms to the same background state; both records pass check.R within the 1.03 bound; the records cannot prove that background load caused any ratio. The protocol's background-application instruction is not amended; future gates follow it." Both records are unchanged.

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

The measured H6 gap remains, with no material closure under the declared
warm-call boundary; this comparison does not locate the remaining cost. The
roadmap's hope that one handler would close most of H6 is not borne out.

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
- **Governance debt:** activating the v0.2.3 packet (LDG-3126) brought its
  documents into the scan. At `656ee7a5` the packet's structural findings
  were 83: 80 inherited (78 header and link findings plus 2 invalid verdicts,
  in `macro_plan_review.md` and `strategy_grammar_closeout.md`, all present
  at `07dbbc87`) and 3 missing headers in WS1's own `ws1_phase_a_review.md`.
  By `d8906f77` WS1's review records carried 7 header findings (three in
  `ws1_phase_a_review.md`, one invalid Status in `ws1_phase_a_review_2.md`,
  three in `ws1_phase_b_review.md`); they are this cut's record debt and were
  repaired with the close-review F2 correction, leaving 0 findings in WS1
  files (packet header and link findings 85 before, 78 after; 2 verdict
  findings unchanged). The 80 inherited findings stay outside WS1.
- **Outside R3:** `R/accounting-replay.R:95`, a reader-side replay fallback,
  computes a cash delta of its own. It is reconstruction, not fill-row
  publication, and stays outside the accepted R3 scope.
- **Recorded debt in moved code:** per-row `meta_json` parsing in memory
  `append_event_rows()` and per-event serialization in `events()` (design
  note Section 12).

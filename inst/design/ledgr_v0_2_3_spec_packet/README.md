# ledgr v0.2.3 Spec Packet

Role: living; current packet front door.
Status: working; macro plan revision 7 records the accepted within-release
order. Cuts 1, 2, 4, 5 and 7 are closed. Cut 6 (WS4b, one execution path) is
implemented and accepted through `14252ffb`: its final independent Type 1
confirmation is `PASS`, and workstream 14/LDG-3178 are complete. Cut 7 is the
accepted WS5 strategy-authoring implementation cut (workstreams 15-18,
LDG-3179-LDG-3190); it resolves the accepted synthesis's bounded spec-cut
questions. Its independent [cut review](cut_review_7.md) returned
`NEEDS_TYPE_2`: all independent corrections are applied, and the maintainer
accepted its recommended durable cursor/checkpoint option on 2026-11-01. The
bounded pre-acceptance probes are recorded in
`dev/bench/v0_2_3_strategy_authoring_preflight/`; its focused
[re-review](cut_review_7_rereview_1.md) is `PASS_AFTER_PATCHES` with patches
applied. Its [final confirmation](cut_review_7_confirmation_1.md) required four
exact textual patches and stated that no further review was needed once they
landed; all are applied. The maintainer accepted the cut on 2026-11-01.
Cut 2 (WS3 dense oracle and current-tree timing) is closed and accepted at revision 3.2. The 2026-10-30 amendment aligns its descriptive baseline with Cut 4's shared paired-gate harness boundary; its focused [review](cut_review_2_amendment.md) is `PASS`. Workstream 2's accepted [Type 1 close review](ws2_close_review.md) freezes the dense oracle at `cbf25359`. Workstream 3's accepted [Type 1 close review](ws3_close_review.md) freezes the descriptive [current-tree record](../../../dev/bench/peer_benchmark/records/20261030-current-tree/). Together they discharge C1's oracle/baseline prerequisite. A0 remains independent, the record is not a future ratio arm or public speed claim, and the old peer driver retires only after replacement coverage is accepted.

Workstream 15 (LDG-3179--LDG-3181) received `CHANGES_REQUIRED` independent
Type 1 reviews in [close_review_15.md](close_review_15.md) and
[close_review_15_rereview_1.md](close_review_15_rereview_1.md). Its final
focused [re-review 2](close_review_15_rereview_2.md) also returned
`CHANGES_REQUIRED`; the maintainer authorized one third and final bounded
correction on 2026-11-02. Commit `7e3f477a` completes that correction: exact
UTC carry parsing and the public 21:00 three-window witness pass, all 12
registered mutations are detected, and the maintainer accepted the workstream
on the bounded evidence without another review round. The record is
[ws15_implementation_matrix.md](ws15_implementation_matrix.md) with runnable
inventories under `dev/bench/v0_2_3_ws5/` and timing preregistration under
`dev/bench/timing/protocols/ws5-timing-1/`. Workstream 15 and LDG-3179 through
LDG-3181 are complete; integrated Cut 7 timing is
descriptive milestone evidence, not a WS15 correctness gate.

Workstream 16 (LDG-3182--LDG-3184) is complete through `4fcb4bbf`. Its
independent [close review](close_review_16.md) and two focused confirmations
([one](close_review_16_rereview_1.md),
[two](close_review_16_rereview_2.md)) found and closed the declared-session
parity, cache, detector, explicit-policy, teaching and scheduled-recovery
issues. The final public surface uses plain selections and weights, two
ctx-first target verbs, explicit investor inputs and explicit schedules.
Focused tests and registered mutations pass; the source build and package
check pass. The ordinary-fast lane executed 636/636 blocks in 211.540 seconds;
that functional result exceeded the advisory 112-second timing hint and is not
recorded as a timing pass.

Workstream 17 (LDG-3185--LDG-3186) is complete through `4a6430ac`. Its
independent [close review](close_review_17.md) found correctness, detector and
hot-path issues in typed state; its focused
[re-review](close_review_17_rereview_1.md) closed those findings and exposed
one final reordered-ID oracle gap. The bounded correction registered the
eighth state mutation, and the final independent confirmation returned
`PASS`. Typed asset and portfolio state now has explicit declarations,
type/missing/axis-preserving checkpoints, exact resume and candidate
isolation. Unchanged pulses encode no payload. The 500-ID, four-field record
uses 0 payloads in 0.64 seconds when unchanged and 100 payloads in 0.67
seconds when changed; these clocks are descriptive. Exact-source build and
package check pass with only the two expected no-build-vignettes warnings.

Workstream 18 (LDG-3187--LDG-3190) and Cut 7 are complete through
`34a06c6d`. The independent [close review](close_review_18.md) and focused
re-review found and closed stale helper-evidence, boundary-witness,
classification, teaching and record defects. A final clean-context Claude
Opus confirmation returned `PASS`: ordinary post-helper edits discard stale
evidence to one raw notice, malformed evidence still refuses, both D8
mutations are detected, and the executed article and records agree. The fast
profile is functionally green but its 214.22-second result remains an explicit
maintainer-accepted miss against the historical 112-second backstop; no test
was retiered. Cut 7 closes WS5 implementation. Macro join J remains open for
WS7's merged result reader.
Authority: routing only. The roadmap binds release scope, accepted RFCs bind
design, contracts bind shipped behavior, and `tickets.yml` is the sole
implementation and sequencing authority for accepted cuts.

Cut 9 is the accepted WS6 context-frame-retirement implementation cut
(workstreams 20-21, LDG-3194-LDG-3197). It implements the accepted synthesis
after Cut 7's flat-context handoff. The findings in `cut_review_9.md` and
`cut_review_9_rereview_1.md` are patched, final focused confirmation returned
PASS. Workstream 20 is accepted; Workstream 21 implementation is complete and
awaits its independent Type 1 close review.
Cut 8, workstream 19 and LDG-3191-LDG-3193 belong to the withdrawn, unmerged
hot-path ban-list branch; their numbers are not reused.

v0.2.3 is the cleanup, performance and research-authoring release that follows
the published v0.2.2 point-in-time foundation. The macro plan and cut 1 were
accepted on 2026-10-28; later cuts are added to `tickets.yml` as the
maintainer accepts them. The packet does not copy the large carried inventory
from the roadmap or manufacture ticket status.

## Start here

| Need | Source |
| --- | --- |
| Release goal and carried scope | [Roadmap current-release section](../ledgr_roadmap.md#next-release) |
| Within-release order (accepted 2026-10-28) | [Macro plan](macro_plan.md) |
| Cut, workstream and ticket state | [tickets.yml](tickets.yml) |
| Due, active and parked design work | [RFC pipeline](../rfc/README.md#rfc-pipeline) |
| Current package behavior | [Contracts](../contracts.md) |
| Accepted choices awaiting consolidation | [Decisions bridge](../decisions.md) |
| Non-binding future ideas | [Horizon](../horizon.md) |
| What v0.2.2 shipped | [Released v0.2.2 packet](../ledgr_v0_2_2_spec_packet/README.md) |

## First planning duties

Before the first implementation cut:

1. reconcile the roadmap's carried commitments and maintenance inventory
   against the released v0.2.2 tree;
2. run the due design work needed by that cut rather than reopening settled
   v0.2.2 choices;
3. complete the focused release-candidate, CI-gate and evidence-reuse RFC
   before designing the next publication cut; and
4. create the macro plan and `tickets.yml` only when their concrete order and
   implementation ownership are ready to be reviewed.

The packet must stay human-readable. Historical evidence remains at its
versioned source; link to it instead of copying it here.

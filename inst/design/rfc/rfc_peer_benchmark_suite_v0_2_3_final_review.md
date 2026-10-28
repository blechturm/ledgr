# Peer benchmark suite: Type 1 final review

**Latest verdict: PASS (focused re-review, round 2).** Codex, 2026-10-28.
FR1-FR3 are closed. The maintainer accepted the corrected synthesis on
2026-10-28 after this PASS.

**Initial verdict: CHANGES_REQUIRED (round 1).** Codex, 2026-10-28.
Reviewed Claude's proposed synthesis, D1-D11 and Sections 4-8, against seed
v2, the response review and accepted macro plan WS3/WS4. The inputs are
appropriate: the roadmap fixes scope; the macro plan fixes dependencies;
current contracts and execution evidence constrain claims. No Type 2
reopening is needed for the corrections below.

**Execution and verification.** Re-ran
`dev/spikes/peer_suite_response/check.R`: recorded CSVs reproduced, gut
detected, tracked package/design scope unchanged. Checked public run/results
and recording-pulse surfaces in `R/backtest.R:392`,
`R/backtest-results.R:1356` and `R/backtest-fills.R:3-20`.
Geometry arithmetic is correct: 390 minute ends, 23,400 pulses, 468,000 bars.
No new peer parity, timing or memory was measured.

1. **FR1: the synthesis adds work to C1's prerequisite cut.**
   Synthesis Section 5, lines 384-390, assigns qualification/provisioning for
   all six peers to the dense cut; lines 406-408 require its first report
   render there. Seed v2 Sections 3/10 and macro plan WS3
   (`macro_plan.md:127-143`) require dense parity/current-tree timing before
   C1, with remaining lanes alongside release work; they do not put all six
   environments and the report on that critical path.
   **Correction:** restrict the early cut to its assigned dense comparisons
   and oracle/timing obligations. Keep all-six provisioning and report work
   owned by the relevant suite cuts, without making them new C1 prerequisites.

2. **FR2: comparator reuse conflicts with exact deletion.**
   D6, lines 247-249, says `peer_equity_parity()` serves ledgr-versus-ledgr
   surfaces. Its default is `tolerance = 1e-8` and it calls `all.equal()`
   (`peer_benchmark.R:1159-1194`); this is not D4's exact economic oracle.
   Seed v2 Section 6 requires inspecting a comparator's actual coverage.
   **Correction:** explicitly exclude this tolerant helper from unchanged-
   meaning deletion checks. Use exact comparison there; keep the old helper
   only for labelled diagnostics, and require field-specific peer checks.

3. **FR3: the first required portfolio pair is not bound explicitly.**
   D1 and Section 5's portfolio bullet name the lane and PyBroker tie work,
   but omit seed v2 Section 3's required first new ledgr/PyBroker top-N
   rotation pair.
   **Correction:** bind that pair explicitly, including common ranking,
   ties, cadence, next-bar quantities and holdings; additional peers remain
   optional after qualification.

**Handoff and provenance.** Claude drafted the complete synthesis in a tool
call, but Bash quoting prevented the file write; its CLI then hit the session
limit (reset reported as 17:50 Europe/Vienna). Codex recovered the draft
verbatim from that call, without executing the shell text or editing its
substance. The synthesis remains proposed. A correction handoff is prepared;
author correction and focused re-review remain pending. No commit, acceptance,
contract amendment or implementation cut has occurred.

**Focused re-review, 2026-10-28.** Claude's correction round 1 closes FR1
(D1/D5/D11 and Section 5: oracle/current-tree timing prerequisite separated
from suite provisioning/report work), FR2 (D4/D6: tolerant helper excluded
from exact deletion) and FR3 (D1/Section 5: required ledgr/PyBroker pair).
Confirmed the prerequisite reading against roadmap lines 238-240 and macro
plan WS3/WS4; WS9a's existing memory-baseline obligation remains unchanged.
Compared the correction with the recovered draft; changes stay within the
findings and revision record. UTF-8, local links and whitespace checks pass.
No product/probe changes or new measurements; prior rerun/gut evidence stands.
The quota blockage is resolved. No findings remain; acceptance is next.

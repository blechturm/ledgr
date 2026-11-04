# RFC: Lean Core Skeleton (v0.2.3), Final Review

- Mode: **Type 1 final review**, 2026-11-04, under the maintainer-approved
  brief (drafted by Claude). Verification, not design (`rfc_cycle.md`,
  "Final review scope").
- Reviewer: a Claude session that wrote neither the synthesis (Codex) nor
  any earlier artifact in this cycle. Disclosure: Claude co-authored the
  seeds, drafted both review prompts and drafted the D1-D2 record, so this
  review is independent of the synthesis, not of the seed side.
- Verified: `rfc_lean_core_skeleton_v0_2_3_synthesis.md` against seed v2,
  the response, the seed v2 review, the response review, maintainer
  decisions D1-D2, the parent synthesis (Sections 2, 4, 5 and A1-A4), macro
  plan WS16 (Macro:640-700), `contracts.md`, and every R/, dev/ and manual
  file:line the synthesis cites.
- Commit: worktree detached at `6ef58138`. `git diff 61f37613 6ef58138
  --stat` touches only `R/output-handler.R` (two `utils::tail` qualifications
  at :501-505 and :580-587, not cited by the synthesis), the RFC README, the
  synthesis and the extension seed. Every R/ citation therefore resolves as
  at the synthesis baseline. Release head `8e8ab1b7` adds only `tickets.yml`
  and a closeout note on top.
- Ran: read-only git, grep and line reads. No R probes, no tests, no check,
  no private data.

## Verdict: PASS_AFTER_PATCHES

The synthesis is consistent with its inputs, D1-D2 and the three
2026-11-04 WS16 bullets; every cited source line and contract anchor holds.
Three low-severity text patches below. None opens design.

## Findings

### P1 - Low: the target-axis correction of seed v2 is not recorded

**Evidence:** Seed v2 principle 6 (seed_v2:80) and Section 3.3
(seed_v2:227) put targets among the run-axis vectors. The synthesis
(synthesis:83) instead puts decision targets on the decision axis, mapped
by `context_pos`. The source supports the synthesis: the decision group is
built on the context axis with `context_pos` as "its only bridge to the run
axis" (`R/fold-engine.R:1058-1068`), and P3 reads `context_pos[k]`
(`R/availability-economics.R:379`). No response or review finding asked for
this change, and Section 6's rejection table does not list it, so a builder
reading v2 beside the synthesis meets two answers.

**Patch:** in the Section 2 table, Fold state row, replace
"run-axis storage must not invent missing targets." with
"run-axis storage must not invent missing targets. This corrects seed v2
principle 6 and Section 3.3, which listed targets among the run-axis
vectors (`R/fold-engine.R:1058-1068`)."

### P2 - Low: one OMS authority D1 names is dropped

**Evidence:** D1's order-types row cites "OMS synthesis Sections 5 and 6.3"
(maintainer_decisions:23); its OMS row cites Sections 3 and 6
(maintainer_decisions:22). Synthesis:165 retains only "OMS Sections 3 and
6", which covers 6.3 but omits Section 5 (lifecycle state model,
`rfc_ledgr_oms_seed_synthesis.md:253`). Section 2.1 says it retains "the
authorities named by D1".

**Patch:** in Section 2.1, replace
"[OMS Sections 3 and 6](rfc_ledgr_oms_seed_synthesis.md#3-accepted-architecture)"
with
"[OMS Sections 3, 5 and 6](rfc_ledgr_oms_seed_synthesis.md#3-accepted-architecture)".

### P3 - Low: the shorting row names only P3's affordability policy

**Evidence:** The short-exposure refusal (`R/availability-economics.R:311`)
runs in P2 after risk (`R/fold-engine.R:1016`) and again per candidate row
in P3's plan (`R/availability-economics.R:430-436`, inside
`ledgr_fold_build_availability_pulse_plan()` called from
`ledgr_fold_stage_plan()` at `R/fold-engine.R:1117`). Synthesis:141 names
"P2's target/risk validation services and P3's affordability policy". The
locality claim still holds (P3 is a named owner), but D1's check asks which
structure changes, and P3's short-exposure check is one of them.

**Patch:** in the Section 2.1 table, Short selling and leverage row,
replace "and P3's affordability policy change only under the shorting
contract." with "and P3's short-exposure and affordability checks change
only under the shorting contract."

## Checks that passed

- **Inputs.** Independently of the synthesis's own list: the RFC README
  lean-core-skeleton row (README:110) and the response review's "Next"
  (response_review:32-35) name the same five inputs plus seed v1, which is
  historical and reaches the synthesis through the response. `git log` on
  the macro plan and decisions file shows no later decision than
  `61f37613`/`a6caacc3`. The extension seed added in `6ef58138` is correctly
  not an input (D2: the synthesis must not pre-accept it).
- **v2, reviews and synthesis.** Response P1-P7 and N1 dispositions
  (response_review:15-24) match seed v2 and the synthesis Section 6 table;
  N1's input-access patch is in v2 (seed_v2:70-75, :251-254, :344-346) and
  the synthesis (:207-214, :398). Authorship and deviation statements match
  the response review.
- **D1.** The order-shaped handoff (synthesis:86-92) matches D1's OMS row.
  The four-row table answers D1's check per row and states the
  second-engine/mode-branch/P2/lot-kernel failure rule (synthesis:144-150);
  the per-family-close recurrence is stated (:134-135). The synthesis routes
  D1's "fill resolution reads the same tiles" through P1's execution packet
  (:140, :156-157), consistent with seed v2's "P1 alone reads the substrate"
  (seed_v2:276-277) and the parent (parent:74-76); this is explicit, not
  silent.
- **D2.** Coding gate, recorder included, and amend-before-coding route
  (synthesis:54-60, :402, :416-419) match D2 and WS16 "Extension
  architecture first" (Macro:674-680).
- **WS16 bullets.** Cited ranges are exact: "Stage parity" Macro:666-673,
  "Extension architecture first" Macro:674-680, "One family per cut"
  Macro:681-684. Section 5.3 incorporates the recorder by reference and
  claims no end-to-end parity before P3, consistent with Macro:672-673.
- **Source anchors hold:** `R/backtest-runner.R:939` and `R/sweep.R:1827`
  call `ledgr_execute_fold()`; `R/fold-engine.R:1878`/`:1911` separate
  execution data and drop decision data; `:1010` post-risk validation;
  `:1065` threshold against position; `:617` packet with open/high/low and
  `exec_ts`; `:1238` passes pos/side/qty/price/fee to `ledgr_lot_fill`;
  `:1337`, `:1359`, `:1386` (P4 `ledgr_fold_stage_apply`) and `:1425` (P5
  `ledgr_fold_stage_commit`) order as stated. `R/lot-accounting.R:278`,
  `:286`, `:323`, `:524`, `:549`, `:731`; `R/history-frame.R:207`, `:257`,
  `:770`, `:801`, `:1043` (explicit IDs checked against the substrate at
  :1055-1066), `:1114`, `:1198`, `:1402`, `:1659`;
  `R/history-features.R:187`, `:329`, `:409`, `:447`, `:458`, `:474`;
  `R/history-substrate.R:376` (per-instrument split at :399), `:1306`;
  `R/pulse-context.R:100`, `:166`, `:196`; `R/strategy-state.R:178`, `:285`;
  `R/availability-provider-prepared.R:139`; `R/backtest-runner.R:119`;
  `R/accounting-replay.R:8`; `dev/spikes/lean_fifo/kernel.R:18`, `:103`;
  manual:77 (seven shapes) and manual:253-255 (sequential loops allowed for
  ordered affordability). Nothing in `R/` references `lean_core`;
  `dev/` is build-ignored.
- **Contracts.** All eight cited anchors exist with the cited headings.
  C:325-336 is the accepted validation-limits rule; C:550-563 is the typed
  accounting table with no JSON envelope; C:3360-3382 is the paired 1.10
  resource protocol (the parent's C:3351 has moved, the synthesis's range is
  current). C:1349-1351 supports the short-refusal-as-policy reading;
  C:284 the signed opening lot input.
- **Links.** README anchors (`lean-core-skeleton`,
  `core-extension-architecture`, `shorting-leverage-contract`,
  `cross-asset-accounting-events`, `asset-precision-tradability`), the
  macro WS16 slug, the D1 slug and the OMS Section 3 slug resolve.
- **Numbers and worked example.** 14 vs 10 us (layout README:70), 191 us
  (:69, fixed basket 500, history 252), 12,580 us (:91), unmeasured
  preparation/spilling/sharing (:95). `21, 22, NA, NA, 25` has three finite
  values, so it meets `min_observations = 3`; admission is
  `rowSums(is.finite(value)) >= min_observations`
  (`R/history-frame.R:760`, `:771`). LR-07 is the complete-window shorthand
  (rules ledger:26).

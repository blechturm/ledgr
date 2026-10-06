# Terminal-Outcomes Reconciliation

**Status:** LDG-2961 acceptance evidence for Cut 6. Index only.
**Authority:** The rules bind through the cited `contracts.md` sections. The
[synthesis](../rfc/rfc_terminal_outcomes_v0_2_2_synthesis.md) records why;
`tickets.yml` records status. This file restates no rule.

Every rule in synthesis Sections 3 to 7 has exactly one owning ticket, one
failure-sensitive block and one standing contract section. Blocks are
registered in `tests/claims.yml`. "Supporting" names further blocks that also
detect the rule; they do not share ownership.

## Synthesis rules

| Rule | Synthesis | Contract section | Ticket | Block | Supporting |
| --- | --- | --- | --- | --- | --- |
| R01 A modeled terminal needs a held `known_inactive` row with a nonempty label, no supported settlement and no refusal | 3.1 | Availability | LDG-2955 | LTB-0162 | LTB-0170 |
| R02 An empty label stops `terminal_settlement_unsupported` and is never normalized | 3.1 | Availability | LDG-2955 | LTB-0164 | |
| R03 Horizon exhaustion creates no fill, disposition, cash or quantity change | 3.1, 3.3 | Availability | LDG-2956 | LTB-0165 | |
| R04 `held_terminal_position` is one choice or an exact-label map with a required `default`; five choices; haircut fraction rules | 3.2 | Config | LDG-2953 | LTB-0158 | LTB-0170 |
| R05 Labels match byte for byte; no vendor synonyms | 3.2 | Availability | LDG-2955 | LTB-0170 | |
| R06 Map order, labels, choices, haircut and fallback enter identity; `v002` identities; `v001` unchanged | 3.2 | Config | LDG-2953 | LTB-0158 | |
| R07 Policy schema 2; schema-1 records readable, execution, resume, rerun and promotion refused | 3.2, 3.3 | Config | LDG-2953 | LTB-0160 | |
| R08 Settlement evidence runs first and pre-empts every modeled choice | 3.2 | Availability | LDG-2955 | LTB-0163 | LTB-0168 |
| R09 A modeled outcome posts one `DISPOSITION` before the strategy decision; not a fill; atomic; event equals its meta | 3.2 | Execution | LDG-2955 | LTB-0162 | LTB-0171 |
| R10 A choice without a qualifying mark stops `terminal_mark_unavailable`; never aborts | 3.2 | Availability | LDG-2955 | LTB-0164 | |
| R11 A scheduled row disposes at the evidenced or frozen mark; only `last_mark` or `refuse` change it; it is a precedence barrier | 3.2 amendment | Availability | LDG-2955 | LTB-0163 | |
| R12 `exhausted = c("freeze", "refuse")`, default freeze; valuation schema 2; no default `max_sessions` | 3.3 | Config | LDG-2954 | LTB-0159 | |
| R13 Freeze keeps quantity and cash, keeps the risk mark, marks `frozen_close`, ages, restricts, and resumes at the next bar | 3.3 | Availability | LDG-2956 | LTB-0165 | LTB-0166 |
| R14 Explicit zero may attempt an exit; no order is queued | 3.3, 3.5 | Strategy | LDG-2956 | LTB-0165 | |
| R15 An effective `known_inactive` holding never freezes | 3.3 | Availability | LDG-2956 | LTB-0164 | LTB-0168, LTB-0169 |
| R16 `exhausted = "refuse"` stops typed with no frozen state | 3.3 | Availability | LDG-2956 | LTB-0165 | LTB-0174 |
| R17 Freeze entry and exit are diagnostics; resume and replay rebuild them | 3.3 | Persistence | LDG-2958 | LTB-0169 | LTB-0166 |
| R18 `frozen_terminal_position` defaults: write_off research, refuse strict; enters identity | 3.4 | Config | LDG-2953 | LTB-0158 | |
| R19 The frozen fallback applies only when the choice needs a permissible mark; an explicit label choice wins; haircut is never a fallback | 3.4 | Availability | LDG-2958 | LTB-0168 | LTB-0158 |
| R20 A defaulted frozen write-off reads `default: assumed worthless` | 3.4 | Result | LDG-2959 | LTB-0172 | |
| R21 Frozen holdings stay visible, target-restricted and excluded from `ctx$tradable()` | 3.5 | Context | LDG-2957 | LTB-0167 | |
| R22 Rebalance helpers preserve frozen quantity and reserve its exposure once; no second equity basis | 3.5 | Strategy | LDG-2957 | LTB-0167 | |
| R23 Terminal outcomes extend the corporate-action summary and fidelity; no second headline | 4 | Result | LDG-2959 | LTB-0172 | |
| R24 One valuation headline; one warning before metrics; no materiality threshold | 4 | Result | LDG-2959 | LTB-0174 | LTB-0172 |
| R25 Structured valuation fields and the frozen-worthless bound; metrics unchanged | 4 | Result | LDG-2959 | LTB-0173 | |
| R26 Frozen equity is an estimate; accounting is exact; documentation never calls frozen equity exact | 2, 4 | Result | LDG-2961 | LTB-0181 | |
| R27 Run lists, comparison, sweeps, review, walk-forward and plans expose compact flags | 4 | Sweep Promotion | LDG-2960 | LTB-0176 | LTB-0178, LTB-0179, LTB-0180 |
| R28 Every selection surface reports attempted, done, incomplete and failed counts with reasons and IDs | 5 | Sweep Promotion | LDG-2960 | LTB-0176 | LTB-0178, LTB-0179 |
| R29 A named incomplete run stays non-comparable | 5 | Result | LDG-2960 | LTB-0178 | |
| R30 Frozen `DONE` runs stay eligible with their flags beside ranking output | 5 | Sweep Promotion | LDG-2960 | LTB-0176 | |
| R31 Effective-trial and DSR maths stay on completed panels; counts are disclosure only | 5 | Verification | LDG-2960 | LTB-0177 | |
| R32 No Sharadar halt or carried-price claim without LFB-027 evidence and an end-to-end record | 6 | Documentation | LDG-2961 | LTB-0181 | |
| R33 One gate registry; each case has a mutation-sensitive block; a vendor-neutral release fixture | 7 | Verification | LDG-2961 | LTB-0182 | LTB-0154 |

## Gate cases (synthesis Section 7)

Cut review C1 assigned cases 1 to 6 and the case 7 economics to LDG-2958,
the case 7 summary fields to LDG-2959 and case 8 to LDG-2960. LDG-2958 owns
the gate for its cases; the blocks below were written under the ticket named
in their claim and are the detecting evidence for that gate.

| Case | Owning ticket | Block | Mutation that the block detects |
| --- | --- | --- | --- |
| 1 Supported settlement pre-empts every modeled choice | LDG-2958 | LTB-0163 | let the lifetime path dispose a holding its settlement fact resolved |
| 2 Default, exact-label override, haircut, write-off and strict refusal change outcome and identity | LDG-2958 | LTB-0162 | swap two choices' prices or drop one choice from identity (LTB-0158 detects the identity half) |
| 3 No qualifying mark stops typed; an unlabeled terminal stops and never freezes | LDG-2958 | LTB-0164 | abort instead of stopping, or keep freezing an unlabeled terminal |
| 4 Freeze entry, continuation, resumption and one-shot non-queueing | LDG-2958 | LTB-0165 | queue a one-shot zero or create a transaction at freeze entry |
| 5 A frozen holding is visible, restricted, preserved and reserved | LDG-2958 | LTB-0167 | let the rebalance helper spend frozen exposure |
| 6 A terminal while frozen uses the declared fallback; evidence first | LDG-2958 | LTB-0168 | apply the fallback to an evidenced row or to an explicit label choice |
| 7a Memory, reopen and resume agree on events, equity and diagnostics | LDG-2958 | LTB-0169 | derive freeze state from in-memory fold state only |
| 7b Memory, reopen and resume agree on summary fields | LDG-2959 | LTB-0175 | derive a reported field from state a reopen does not rebuild |
| 8 Selection surfaces keep counts while DSR inputs stay completed panels | LDG-2960 | LTB-0177 | add an incomplete prefix to a validation panel (LTB-0176 detects a dropped count) |

## Out of scope here

The Sharadar integration record named at the end of synthesis Section 7
belongs to ledgr-research LFB-027 and is not a v0.2.2 package deliverable.
Until it lands, R32 holds the release-claim boundary.

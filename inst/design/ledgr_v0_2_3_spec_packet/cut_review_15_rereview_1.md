CHANGES_REQUIRED
Mode: focused Type 2 re-review of Cut 15 / workstream 32; fresh session, no implementation authorship.

Compared `bd767d20..258d3861`; HEAD is `258d38611c025e1eb6ed162af8c343ff6454cb7d`. All `tickets.yml:line` references below resolve to `C:/Users/maxth/ledgr-wt/cut15-review/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml`.

| Finding | Application of requested replacement text | Location |
| --- | --- | --- |
| R1 | Applied; stale workstream wording remains (N2) | tickets.yml:1745, tickets.yml:4875; shared items at tickets.yml:4851, tickets.yml:4874, tickets.yml:4895 |
| R2 | Applied | tickets.yml:4853 |
| R3 | Applied, including rerun after LDG-3224 | tickets.yml:4852, tickets.yml:4897 |
| R4 | Applied; existing regression rule retained explicitly | tickets.yml:1770, tickets.yml:4854, tickets.yml:4876, tickets.yml:4898 |
| R5 | Applied | tickets.yml:1721 |
| R6 | Applied, including the additional scope sentence | tickets.yml:4912, tickets.yml:4918 |

Comparison normalized YAML folding and terminal punctuation. The findings below reconcile remaining text with those replacements; they do not reopen their substance.

**N1 — required: reconcile the cut's location restriction with its measurement scope.** Claim: decision 1 still allows changes only in `dev/lean_core`, while R6 requires edits elsewhere. Evidence: `tickets.yml:1740` versus `tickets.yml:4912` and `tickets.yml:4918`; the close also creates a timing protocol under `dev/bench/timing` (`tickets.yml:4909`). Consequence: the required runner/checker changes and timing deliverables violate the cut's blanket scope restriction, leaving implementation and close review with incompatible instructions. Exact replacement for decision 1's opening `No behaviour change, and changes only in dev/lean_core:`:

> No behaviour change. Execution-code changes stay in dev/lean_core; the explicitly scoped benchmark tools, protocols, records and summaries under dev/bench/, and Section 19's tuning paragraph, are also in scope:

**N2 — required: carry the FIFO exception into workstream 32's close review.** Claim: the workstream still requires every replacement to fall back to the pin. Evidence: `tickets.yml:2131` versus decision 2's strategy-facing pin fallback and shared-FIFO general-lean fallback at `tickets.yml:1755`. The repeated tuning-ticket acceptance items already reference decision 2 correctly. Consequence: a conforming FIFO specialization can fail the prescribed close review, or an implementer can add the production pin dependency that R1 expressly excludes. Exact replacement within workstream 32's review reason for `each replacement falls back to the pin outside its common case and is compared with it in debug`:

> each new or materially changed fast path meets decision 2, including its named dispatch predicate, canonical debug comparison and runtime fallback (the general lean kernel for a shared FIFO specialization)

No further build/proof issue found against macro_plan.md WS16, lean_core_interface.md Section 19 or AGENTS.md. The new acceptance items are falsifiable through differential observations, refusal checks, reached faults and source/signature checks. Existing parity runners support the witness work; required extensions are scoped by LDG-3222–3224, decision 5 and LDG-3225. LDG-3225's unchanged `dev/lean_core` is compatible with its tools being in `dev/bench`. Neither finding needs a maintainer design decision.

No R, timing windows, full tests or long parity runs were executed. No tracked file was edited; no commit was made.

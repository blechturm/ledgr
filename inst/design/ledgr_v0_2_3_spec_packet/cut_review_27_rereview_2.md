PASS
Mode: Type 2 focused re-review 2 of Cut 27; independent fresh session; text review of revision 3 at abfdc491 against revision 2 at 0725ca51.

**Role:** record
**Status:** accepted
**Authority:** Non-binding review record. Its disposition is recorded in Cut 27 cut_review in tickets.yml.

S1, S2 and S3 are applied faithfully. Revision 3 introduces no new gap or contradiction that changes what gets built or proven. This verdict concerns the preparation brief; it does not claim that its implementation or proof tickets have run.

Citations use revision-3 line numbers. tickets.yml means C:/Users/maxth/ledgr-wt/cut27-review/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml.

S1 - required correction applied faithfully.

LDG-3282's dependency list (tickets.yml:9638) exactly matches the replacement: LDG-3276, LDG-3277, LDG-3279, LDG-3280 and LDG-3281. The sequencing text (:4898-4905) requires the final audit, affected witness population, surviving checkers and feature routes before oracle acceptance, while permitting earlier immutable pin collection. The added acceptance item (:9646) identifies those final inputs, requires updates to the matrix and affected records and reruns of the checker and controls after subsequent input changes before cut closure, and expressly requires LDG-3283 to verify the match. All three replacements match the prior review's text, allowing for YAML line wrapping.

The dependency graph remains acyclic. LDG-3283 depends on LDG-3282 (:9654); the new requirement for close-time verification does not make LDG-3282 depend on LDG-3283. Named Cut 28 obligations retain their completion and live-pin-retention gates (:9643-9646). The former stale-corpus completion order is closed without requiring deferred switch proofs to finish in Cut 27.

S2 - required correction applied faithfully.

Workstream 47's test clause (:5353) exactly matches the replacement. It requires an inventoried handling and execution status for every affected test, helper and detector; passing replacements and rejection of original registered witnesses for remaps demonstrable now; individually named switch gates for proofs requiring actual API or format removal; mapping approval and independent Type 1 verification before the switch; and accepted authority for semantic changes.

This agrees with decision 8 (:4833-4855), LDG-3280's acceptance (:9611-9614), and the Cut 28 exclusions (:4908-4917). It removes the unconditional all-rows proof claim without dropping affected rows or claiming their deferred execution.

S3 - advisory correction applied faithfully.

LDG-3278's second acceptance item (:9580) exactly matches the replacement. A green prerequisite leads to an attempted mechanical extension. Terminal green retains exact equality on all three named shapes and the specified paired timing protocol. A later red or inconclusive stop under decision 6 also completes the spike, with the failure or stop signal, completed and unrun shapes, and remaining questions recorded. Available ratios and the line/readability effect remain reportable. The runner, diff checker and gut demonstration remain required (:9576-9579); adoption remains the maintainer's decision (:9577). This agrees with decision 6 (:4793-4807).

No new findings. No T finding or replacement text is needed.

Checked: I read C:/Users/maxth/ledgr-wt/cut27-review/inst/design/ledgr_v0_2_3_spec_packet/cut_review_27.md and C:/Users/maxth/ledgr-wt/cut27-review/inst/design/ledgr_v0_2_3_spec_packet/cut_review_27_rereview_1.md; read Cut 27, workstream 47 and LDG-3275 through LDG-3283; and inspected the full 0725ca51..abfdc491 tickets.yml diff. I checked the dependency closure, sequencing, close verification, deferred obligations, identity statement and exclusions. A text comparison confirmed the dependency replacement and all four replacement paragraphs, normalizing whitespace for YAML wrapping. I also read the repository agent notes and the RFC cycle's record and escalation rules.

HEAD is abfdc49190cabeae1ca59282e6ecd40f07f51ad0, detached. Git status was clean and diff --check for the reviewed range passed. The range adds the prior re-review record and changes tickets.yml only. Read-only Git commands used the existing C:/Users/maxth/ledgr-wt/cut27-review-out/review_gitconfig through a process-local setting; no Git configuration was edited. No R or long job ran, no tracked file was edited, and no commit was made. This report is the sole file written by this review: C:/Users/maxth/ledgr-wt/cut27-review-out/rereview2/cut_review_27_rereview_2.md.

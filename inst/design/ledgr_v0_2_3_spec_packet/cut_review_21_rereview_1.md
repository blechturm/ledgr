CHANGES_REQUIRED

Mode: Type 1 focused re-review 1 of Cut 21's Type 2 cut review; independent session, tree a04e0df9, compared with dcc2fa9d. Scope: faithful application of R1-R9 and defects introduced by that application.

| Finding | Applied? | Evidence (file:line) |
| --- | --- | --- |
| R1 | Yes. Transition absence is precise; frozen decision evidence, FIFO lots, entry anchor and unequal entitlement are retained. | [tickets.yml:6891](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:6891)-6893 (LDG-3243). |
| R2 | Yes. Exact staged book nets, disposition/hold witnesses and the diagnostic mutation are bound. | [tickets.yml:2986](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2986), :3028, :6978, :6984 (LDG-3247); [lean_core_interface.md:1540](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/lean_core_interface.md:1540). |
| R3 | Yes. Production append acceptance precedes installation; overflow refusal and its mutation are checked. | [tickets.yml:2969](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2969), :6917 (LDG-3244); [lean_core_interface.md:1511](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/lean_core_interface.md:1511). |
| R4 | Yes. Opening/P1/fill prefixes, timing, digest observations and late-commit mutation are covered, including dispositions. | [tickets.yml:2978](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2978), :3116, :6918 (LDG-3244), :6985 (LDG-3247). |
| R5 | Yes. Empty axis and empty membership are distinct; state, records, strict-subset mapping and all six context variants are required. | [tickets.yml:3029](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:3029), :6959-6962 (LDG-3246); [lean_core_interface.md:1529](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/lean_core_interface.md:1529). |
| R6 | Yes. Independent call/install witnesses and separate publication faults replace the old check; measured input is corrected. | [tickets.yml:2900](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2900), :3043, :3161, :6920 (LDG-3244). |
| R7 | Yes. Policy routes, corrected condition reason, collision witnesses and precedence faults are assigned across the named tickets. | [tickets.yml:2936](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2936), :3088-3109, :6915-6916 (LDG-3244), :6958 (LDG-3246), :6981-6986 (LDG-3247). |
| R8 | Not completely. Growth, bounds, re-anchors and close gates are present; the specific duplicated-tail fault is missing. See F1. | [tickets.yml:3129](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:3129), :3164-3185, :6936-6937 (LDG-3245), :7002-7003 (LDG-3248). |
| R9 | Yes. All six path moves include exact fold counts in both debug settings; intermediate workstream paths and both closes reference them. | [tickets.yml:3142](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:3142), :6936 (LDG-3245), :7002 (LDG-3248). |

New findings:

F1. Required; R8 incomplete. [The original R8:125](C:/Users/maxth/ledgr-wt/cut21-rereview/inst/design/ledgr_v0_2_3_spec_packet/cut_review_21.md:125) explicitly requires a duplicated captured tail to fail event parity. Decisions 10-11 require a trailing non-fill block and a generic `captured_row_duplicated` event-table difference, respectively, but never require that fault to reach the tail. LDG-3244:6920-6921 has the same gap; the closing tickets inherit it. Duplicating an earlier captured row can satisfy this acceptance without testing tail duplication.

Add to decision 11 and bind through the close acceptance: "The captured_row_duplicated variant must reach and duplicate a captured tail after the last fill in the batch-one mixed workload, and fail event parity." This completes R8's existing obligation; no additional design scope is needed.

What I checked:

- The requested commit diff, every R1-R9 replacement/addition, Cut 21's surrounding decisions and sequencing, LDG-3243 through LDG-3248, Section 19.13 and the cut_review record. Ticket references to cut-wide decisions retain their detailed requirements. No other application defect, contradiction or unfalsifiable new acceptance item found.
- Read-only prior evidence in C:/Users/maxth/ledgr-wt/cut21-review-out: input_audit_21.txt, final_details_21.txt and capture_acceptance.csv, including the corrected R6 account and R9 path counts. Existing variant definitions were inspected for the re-anchor obligations.
- No implementation or runtime validation claimed. No R runs, tracked-file edits or commits. The worktree remains clean; this report is the only file written. Unrelated feature-engine changes in the commit range were excluded from this focused review.

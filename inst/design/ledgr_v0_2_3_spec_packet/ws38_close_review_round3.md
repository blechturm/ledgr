CHANGES_REQUIRED
Mode: Type 1 close review of workstream 38 (Cut 20), round 3; independent fresh session.

Reviewed e7627f34e90aa020b127e71427ab6eabdecb0094 against e83cf032, limited to F2 and regressions from its second correction. The reported parenthesized forms are fixed, but F2 remains incomplete. No regression was found in the existing witness checks, and every compared invariant number reproduces. No production result defect is claimed.

Repository paths below are relative to the review worktree. Probe and rerun paths were in the review output directory (not committed).

1. F2 remains incomplete - required. The nested-function exclusion also skips an evaluated call head containing a direct forbidden call.

   Claim: ``({ sys.call(); `function` })(NULL, 1)`` executes `sys.call()` at the body's top level while obtaining the function constructor. That call is outside the function being defined, but the scan returns zero hits. This uses neither a lookup by string nor caller inspection through a helper. It falls within decision 3's prohibition and decision 5's scan obligation (inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2705 and :2731).

   Evidence: dev/lean_core/parity/hashed_frame_witness.R:65 unwraps parentheses and :66 takes the last expression of a braced head. For this expression, head_name() therefore returns "function". At :76, scan_body() returns immediately, before the descent at :78 can visit the evaluated head. Excluding the new function's body is correct; excluding the preceding `sys.call()` is not.

   head_scope_probe.R extracts the actual scanner definitions. head_scope_probe.csv records zero hits for each of the six forbidden names in ``({ F(); `function` })(NULL, 1)`` and ``({ F(); base::`function` })(NULL, 1)``. head_scope_probe.log reports `Direct calls in evaluated heads missed: 12 of 12`. These cases are also missed by e83cf032, so this is an unresolved F2 hole rather than a newly introduced regression.

   frame_probe.R uses the actual frame_run() and production edit loader to insert ``({ cat("r3 head executed: ", deparse(sys.call()), "\n"); `function` })(NULL, 1)`` immediately after execution validation. frame_probe.log prints the executed call as `eval(lean_envelope_code, new.env(hash = TRUE, parent = environment()))` with debug off and `lean_fold_envelope_plain(execution, output_handler)` with debug on. frame_probe.csv records lean_fold, plain_entries, frame_hashed, bytecode and scan all TRUE in both modes. The log concludes `All normal frame checks passed with direct sys.call() in the call head: TRUE`.

   Consequence: the witness can still certify a body containing an executed direct forbidden call. The 114-row table proves its enumerated cases, but does not establish the claimed coverage of direct calls in call heads.

   Fix: when excluding a function definition's arguments/body, still scan its evaluated call head. A probe-only change from the return at :76 to `return(scan_body(x[[1L]]))` detects all 12 cases while preserving all 114 committed cases, including nested-function and string-lookup controls (head_scope_probe.log). Add a retained case for this evaluated-head boundary and a frame fault demonstrating it. No tracked implementation was changed during review.

Checked:

- Read both prior reviews and LDG-3242's two close-review evidence items first. Inspected the supplied correction diff; it changes the witness and its evidence, with no execution-source change.
- Reran hashed_frame_witness.R with the supplied pinned library into witness/. It printed PASS. scan_cases.csv reproduces 114/114: 84 direct-spelling cases found once and 30 controls with no hits. The no-fault envelope and nested-function control stay clean in both modes. All 70 predicates across 14 fault/debug settings match their expectations. The new `(base::sys.call)()` fault fails only scan in both modes; the flag, unhashed-frame, unqualified and qualified faults retain their previous discrimination.
- Reran review/scan_gut.R against the scanner extracted from e83cf032. scan_gut.log reproduces 78/114 and the same six failing spellings: parens, parens_qualified, double_parens, braces, braces_last and in_head.
- Adapter rerun: 48 identical tables and 3/3 frozen paths; each of the three hashed-only .safety_state faults fails the context comparison, with 13 of 16 tables different. Semantics rerun: 10 cases, 60 fields, 55 equal and five expected differences.
- evidence_audit.R reports 16/16 invariant comparisons identical: all eight rerun CSVs against witness_round2/, seven previous witness comparisons preserving the original 60 frame predicates, and an independently regenerated scan table. Adapter elapsed-time columns were excluded; all other columns reproduce. No newly recorded invariant number failed to reproduce.

Not checked: F1, the rest of the workstream, timing windows, the full gate, the variant driver, the full test suite, package build/check, vendor data or the research workspace. The accepted cut, wrapper form, keep disposition and stated string-lookup/helper limits were not reopened. No tracked file was edited and no commit was made. Probes and outputs are confined to the designated round-3 output directory.

CHANGES_REQUIRED
Mode: Type 1 close review of workstream 38 (Cut 20), round 4; independent fresh session.

Reviewed e39201fb5df393b673236c747b2cb11d32852fbc against e7627f34, limited to F2 and regressions from the round-3 correction. The reported function-constructor-head defect is fixed. F2 remains incomplete for other direct call-head spellings. No regression or non-reproducing invariant number was found. No production result defect is claimed.

Repository paths below are relative to the review worktree. Probe files and outputs were in the review output directory (not committed).

1. F2 remains incomplete - required. Wrapping the parenthesis operator itself still defeats the scan.

   Claim: ``(base::`(`)(sys.call)()`` directly executes sys.call() at the body's top level, but the scan returns no hits. This names the function directly and uses the built-in parenthesis operator, without an alias, string lookup or caller-inspection helper. It falls within the supplied intended rule and decision 3/5's direct-call obligation (inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2705 and :2731).

   Evidence: dev/lean_core/parity/hashed_frame_witness.R:64 recognizes a wrapping operator only when its own head is a bare symbol. At :67 and :68, head_name() therefore cannot unwrap a parenthesis or brace operator whose head is parenthesized or namespace-qualified. Descending through the AST at :82 finds only the symbol sys.call, which :76 ignores because it is not a call.

   scan_probe.R extracts the actual scanner definitions. scan_probe.csv records zero hits for each of the six forbidden names in ``(base::`(`)(F)()``, ``(`(`)(F)()`` and ``(base::`{`)(1, F)()``, among its additional cases. scan_probe.txt confirms execution of all three sys.call forms: the plain result is `plain()`, while the hashed result is `eval(bytecode, new.env(hash = TRUE, parent = environment()))`. It also demonstrates the missed literal selection `(if (TRUE) sys.call else identity)()`, with the same execution results. These are direct names in the evaluated head, without a stored alias or string lookup.

   frame_probe.R inserts the qualified-parenthesis call using the witness's production edit loader and actual frame_run(). frame_probe.txt prints the executed call as `eval(lean_envelope_code, new.env(hash = TRUE, parent = environment()))` with debug off and `lean_fold_envelope_plain(execution, output_handler)` with debug on. frame_probe.csv records all five normal predicates TRUE in both modes, including scan. Its conclusion is `All normal frame predicates pass despite the direct top-level call: TRUE`.

   Consequence: the witness can still certify a body containing a forbidden direct top-level call. head_boundary_check.txt shows these misses also occur in the preceding scanner; they are unresolved F2 coverage, not regressions introduced by the round-3 fix. The 126-case table establishes its enumerated cases, not the stated coverage of every direct spelling.

   Fix: recognize the direct targets through these evaluated heads, including wrapped/qualified parenthesis and brace operators and literal conditional selection. Preserve the function-formals/body exclusion and the settled alias/string/helper limits. Add retained scan cases and an installed-loop fault. A probe-only normalization of the wrapping operator's own head detects the three operator forms while retaining all 126 existing cases (head_boundary_check.R and .txt); conditional selection needs additional head analysis. No tracked implementation was changed.

Checked:

- Read all three prior reviews and LDG-3242's three close-review evidence items first. Inspected the correction's source diff and evidence. No execution source changed.
- Reran hashed_frame_witness.R with the supplied pinned library: PASS. The scan table reproduces 126/126: 96 direct-spelling cases found once and 30 controls with no hits. All 80 predicates across 16 fault/debug settings match their expectations. The new ``({ sys.call(); `function` })(NULL, 1)`` fault fails only scan in both modes. The real envelope and nested-function control stay clean; the flag, unhashed-frame and earlier direct-call faults retain their discrimination.
- Additional scope probes leave all 36 function-definition controls clean, including default formals, nested bodies, qualified/parenthesized constructors and definitions in evaluated heads. A forbidden call in the evaluated constructor head is found while the defined body is excluded.
- Reran scan_gut.R against the scanners extracted from e83cf032 and e7627f34: 78/126 and 114/126, respectively, with the committed failing-spelling lists.
- Adapter: 48 identical tables and 3/3 frozen paths. Each of the three hashed-only .safety_state faults fails the context comparison, with 13 of 16 tables different. Semantics: 10 cases, 60 fields, 55 equal and five expected differences.
- evidence_audit.R reports 24/24 invariant comparisons identical: all eight rerun CSVs against witness_round3/, the previous 60 and 70 frame predicates and adapter/semantics evidence, and both gut outputs. Adapter elapsed-time columns were excluded; every other column reproduces.

Not checked: F1, the rest of the workstream, timing windows, the full gate, variant driver, full test suite, package build/check, vendor data or the research workspace. The accepted cut, wrapper form, keep disposition and stated string-lookup/helper limits were not reopened. No tracked file was edited and no commit was made.

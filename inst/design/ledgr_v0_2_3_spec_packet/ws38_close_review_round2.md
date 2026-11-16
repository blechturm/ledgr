CHANGES_REQUIRED
Mode: Type 1 close review of workstream 38 (Cut 20), round 2; independent fresh session.

Reviewed e83cf0320a42a58592ee3a10aba00fec512c9c8f against d9e2b6b0, limited to round 1's F1/F2 corrections and their regressions. F1 is resolved. F2's namespace forms are corrected, but another direct-call spelling still defeats the guard. No regression introduced by the corrections was found in the checks below. No production result defect is claimed.

Repository paths below are relative to the review worktree. Probe and rerun paths were in the review output directory (not committed).

1. F2 remains incomplete - required. Parenthesized direct forbidden calls pass the scan.

   Claim: `(sys.call)()` and `(base::sys.call)()` directly invoke the forbidden function at the body's top level, but the witness reports a clean scan. This remains within decision 3's prohibition in inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:2705 and decision 5's scan obligation at :2731. It requires no helper, alias or indirect caller inspection.

   Evidence: dev/lean_core/parity/hashed_frame_witness.R:57 recognizes a symbol or a namespace head, but does not unwrap a parenthesized head. Its visitor at :68 excludes the call head from recursion. `scan_probe.R` evaluates the actual scan definitions parsed from that file. `scan_probe.csv` records one hit for each of the six functions as `name()`, `base::name()` and `base:::name()` (18/18), but zero for each as `(name)()` and `(base::name)()` (12/12 missed). All nested-function controls have zero hits. The toy execution in `scan_probe.log` confirms the parenthesized call executes: the plain result is `plain_parens(1)`, while the hashed result is `eval(code_parens, new.env(hash = TRUE, parent = environment()))`.

   `frame_scan_probe.R` uses the witness's actual frame_run() and edit loader to insert `(sys.call)()` or `(base::sys.call)()` immediately after execution validation in lean_fold_envelope_plain. `frame_scan_probe.csv` and .log show every normal predicate TRUE for both faults at debug 0 and 1: lean_fold, plain_entries, frame_hashed, bytecode and scan. Thus this is also a false clean answer through the installed loop. A parenthesized nested-function control passes in both modes as intended.

   Consequence: the direct-call guard can still certify a body containing a forbidden top-level frame-sensitive call. The namespace defect itself is fixed; this is a remaining hole in F2's proof obligation, not a new production behavior or a reopening of the accepted wrapper.

   Fix: unwrap parentheses in call heads before recognizing the symbol or base namespace form. Add a parenthesized top-level fault and retain the nested-function exclusion control. Verify all six names with parenthesized unqualified and namespace forms, while retaining the existing faults and comparisons.

Checked:

- Read the round 1 review and LDG-3242's "Close review round 1" evidence first, then inspected the correction diff. No execution source changed in this correction.
- F1: cut20_keep.R:51 validates numeric, present, finite, integral round keys; :57 requires exactly 1..rounds per shape and arm; :65 and :66 pair using match() on that key. cut20_keep_refusals.R reproduced 11/11. The same refusal harness against the previous analyzer, with only its analyzer and input locations redirected into the permitted paths, reproduced 9/11; only the two fractional cases failed, returning open and keep (`old_refusals_clean/keep_refusals.csv`).
- `keep_probe.R` refused 72/72 malformed sets: fractional, replaced, NA, non-numeric, infinite, negative and zero round values, missing rows and duplicate rows, separately in every shape and arm. The committed raw rows and independently reordered rows produced byte-identical keep_paired.csv, keep_outside.csv and keep_verdict.txt against evidence/cut20/timing/ (`keep_probe.log`). The settled open verdict and residue were preserved.
- Reran hashed_frame_witness.R: PASS. All 60 predicates across 12 fault/debug settings matched their expectations. The new qualified fault fails only scan in both modes; the new nested-function control fails no predicate. The previous flag, unhashed-frame and unqualified-call faults still discriminate exactly as before.
- Adapter: 48 identical tables and 3/3 frozen paths; each of the three .safety_state faults has 16 tables, 13 different, and the expected context failure. Semantics: 10 cases, 60 fields, 55 equal and five expected differences. `evidence_audit.R` reports 26/26 invariant comparisons identical, including the new committed CSV evidence, previous frame predicates, adapter results and semantics. Adapter wall-clock measurements naturally vary and were excluded from invariant table comparisons; all other columns reproduce. No newly recorded invariant number failed to reproduce.

Not checked: the rest of the workstream, timing windows, full gate, variant driver, full test suite, package build/check, vendor data or research workspace. The accepted cut, wrapper, keep disposition and known residue were not reconsidered. No tracked file was edited and no commit was made. All probes and review outputs are in the designated round 2 output directory.

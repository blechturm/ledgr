CHANGES_REQUIRED

Mode: focused re-review 1 of Cut 22, Type 2; independent fresh session, 2026-11-17.

Reviewed detached e32742b4acc7564a4ad0f3899702250e314765ea and the tickets.yml diff from e458f38f. R1-R3 and R5-R8 are applied faithfully in the decisions and matching acceptance. R4's measurement design is applied, but its rewrite loses an explicit candidate-5 keep predicate. No settled maintainer choice needs reopening. No new scope or neutrality defect found.

Repository paths below are relative to C:/Users/maxth/ledgr-wt/cut22-review. `tickets.yml` means inst/design/ledgr_v0_2_3_spec_packet/tickets.yml. Probe files are under C:/Users/maxth/ledgr-wt/cut22-review-out/rereview1/.

R1: Applied. Decision 7 and LDG-3253 name all three engine-version literals; grep for the complete current hash returns exactly tests/testthat/test-strict-feature-acceleration.R:205, test-fingerprint-stability.R:34 and test-strict-ttr-cleanup.R:182. Decision 4 and LDG-3250 separately itemise the scalar-helper mock. Fingerprint literals, raw-call counts and source predicates stay (tickets.yml:3427, :3472, :7440, :7454, :7486).

R2: Applied. Decision 5 and LDG-3253 start discovery at preparation, include substrate/bounds and dynamic dependencies, require complete bindings and final-code reconciliation, and require the lifetime-producer mutation plus replacement of every newly bound helper (tickets.yml:3430, :7483-7485). The small read_boundary_probe.R traversal discovers ledgr_history_lifetime_segments when substrate construction is included.

R3: Applied. Decision 5 explicitly excludes the four named decoders and the recomputing read entry because they produce no reusable prepared state; LDG-3253 repeats the exclusion and negative case (tickets.yml:3445-3460, :7484-7485). Shared encoding rules remain bound. The expanded discovery roots do not require binding every reached function: classification and the explicit exclusions still govern. read_boundary_probe.txt confirms changed read evidence, identical prepared state, identical fresh/existing reads under the changed decoder, and an unchanged engine marker; its preparation traversal reaches none of the five excluded entries.

R4: Not fully applied. Matched arms per unit, common prerequisites, the separate final/base comparison, A/A, batch length, complete preparation clock, logical work signatures and bounded heap measurement are present in decision 3a and LDG-3250/3251/3252/3255 (tickets.yml:3382-3412, :7441, :7456, :7471, :7518). The memory keep predicate is missing: F1 below.

R5: Applied. Decision 4 and LDG-3250 distinguish maintained current-package consumers from inventoried historical pin consumers and delete the hash references with the functions. Decision 8 and LDG-3254 permit FIFO tooling/population work while preserving value oracles and historical captured records; decision 9 and out_of_scope now make the same bounded exception (tickets.yml:3413-3429, :3488-3515, :3537-3545, :7440, :7499-7501).

R6: Applied. Decisions 2/3 and LDG-3250 require the complete formatted-axis surfaces, attributes and encodings, including named/empty axes, non-UTC input and fractional seconds; the formatted vector is reused unchanged (tickets.yml:3347-3357, :7437).

R7: Applied. The measured-input count and LDG-3249 now say 15 sets plus 14 read cases; decision 2 and that ticket require certification, route and field-union recording and the additional constructor/input cases, including wrong-route failure despite equal refusals (tickets.yml:3289-3292, :3341-3347, :7421). The original probe findings remain historical evidence rather than being silently rewritten.

R8: Applied. Decision 8 and LDG-3254 require both captures' call-time keys, ordered populations and multiplicities, rejection despite equal totals, preserved mocked/refusal/value accounting, and exclusion of the RNG file only from capture/census (tickets.yml:3493-3505, :7499-7501).

F1. Required: restore candidate 5's explicit memory reduction requirement.

Claim: decision 3a delegates candidate 5's keep decision to a memory rule, but the following text specifies observations and method without saying what numerical result passes. LDG-3252 repeats that omission.

Evidence: tickets.yml:3387 says candidate 5 needs the memory rule instead of a speedup; :3403-3411 names object bytes, peak R heap, lifecycle and sensitivity, but supplies no reduction predicate. LDG-3252's acceptance at :7471 requires before/after numbers and a keep verdict, with only timing's 1.02 bound explicit. The e458f38f version of decision 3 expressly required a smaller precompute object and sweep peak memory. Saying that smaller retained size alone is insufficient does not specify the missing peak comparison. A run reporting smaller object bytes and unchanged or increased peak heap has no explicit memory inequality to fail.

Consequence: the method is executable, but the acceptance no longer determines whether a memory-only candidate is kept. This is a lost gate in the rewrite, not a request for a new performance target.

Replacement text for decision 3a's candidate-5 clause and the corresponding LDG-3252 acceptance:

> Candidate 5 is kept only if the oracle is identical, the whole explicit-precompute object has fewer bytes, and the median peak R heap of sequential sweep feature preparation is lower in the candidate on every memory target cell named before comparison. Compare matched arms differing only by candidate 5, with prerequisites identical. Declare the object-byte measure, memory cells, repetitions, worker count and lifecycle before running. Use the stated fresh-child gc(reset = TRUE)/max-used method, prepare fixtures outside the phase, retain the projection at its end, and validate sensitivity with an extra live allocation. Label the metric peak R heap. Both memory reductions must pass; unchanged or increased memory fails, and unresolved noise is inconclusive. No minimum percentage reduction is required. Every measured timing cell must also remain within 1.02. Revert and record a candidate that fails its keep rule.

Checked: the predecessor's brief and R1-R8 replacements; the amended cut, workstream 41 and LDG-3249 to LDG-3255; the accepted feature-engine RFC and its review/confirmation; the relevant contract groups (#contract-context-indicator-computation, #contract-context-strict-features, #contract-context-ttr-adapter and #contract-context-feature-path); macro-plan item c, Cut 17's oracle/protocol precedent and LDG-3248's final FIFO evidence; AGENTS.md and the relevant process/style/benchmark rules. Traced the preparation/read boundary and checked the complete engine-version literal list.

The timing design is executable without modifying the shared harness: its protocol accepts named clocks, frozen repetitions and alternating pairs; runner.R:81 supports same-commit A/A, and check.R:104 and :288-289 support its validity/noise record. Use no candidate overlay for A/A: Cut 17's overlay invocation would classify even equal commits as a gate. Keep common fixture construction in the committed protocol workloads.R. Normalized logical work strings can satisfy the unchanged invariant-work check without suppressing value/plane faults. A/A VALID alone does not establish a resolved 2-percent margin; the recorded noise must still be assessed as decision 3a requires.

Executed host_probe.R twice in fresh R 4.6.1 processes, with and without an 8,388,608-byte live allocation. The existing four-file protocol validated and alternated correctly; peak R heap rose from 26,597,624 to 34,986,304 bytes. This establishes basic host sensitivity, not candidate-5 savings or workload stability. read_boundary_probe.R loaded only the supplied pin and passed its assertions. Locale startup warnings occurred.

Did not run timing windows, an A/A window, workload memory benchmarks, the deterministic corpus rerun, full tests, package check, the lean gate, FIFO captures or private-data work. No candidate implementation exists to validate. No library under AppData/Local/Temp was used; no prohibited data location was accessed. Git required its explicit worktree gitdir with the installed Git 2.36 ownership check; no Git configuration was changed. The tracked worktree remains clean. No tracked file was edited and no commit was made.

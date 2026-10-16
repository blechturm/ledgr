# Cut 16 focused cut re-review

**Mode:** Type 1 focused re-review with input check.
**Reviewer:** Claude Opus 5.5, high effort, independent CLI session.
**Baseline:** `99a3b067`; corrected draft uncommitted.
**Date:** 2026-10-16.
**Verdict:** `PASS_AFTER_PATCHES`.

All twelve findings from [`cut_review_16.md`](cut_review_16.md) and its one
Type 2 item are closed. The accepted architecture still has one reader, one
immutable result and no cache or second feature engine. Nine bounded
ownership and wording patches were required; none changes product design.

## Original findings

- **R1 resolved.** LDG-3064 retires the public and stored hydration seams,
  the precompute warmup start and both conditions, advances the current
  format and owns LTB/LCL-0197.
- **R2 resolved.** LDG-3057 advances snapshot hash rule 3 to 4 and format 120
  to 121 and owns Date resolution at every named entry point.
- **R3 resolved.** LDG-3058 binds the public experiment-level policy and its
  exact defaults; LDG-3066 owns the accepted LCL-0142/LCL-0274 change.
- **R4 resolved.** LDG-3062 owns result metadata, explicit IDs, suffixes,
  outside-axis refusal and `ledgr_history_sufficient()`; LDG-3060 owns the
  evidence vocabulary.
- **R5 resolved.** Prefix invariance covers every concrete definition, while
  window-versus-prefix comparison is limited to custom bounded fn/series_fn
  pairs and catalogue rows stay package-tested.
- **R6 resolved.** P1 is the sole reader, P2 adapts, P3-P5 receive no history,
  and substrate state, precedence and service ownership are explicit.
- **R7 resolved.** Rule-4 identity pins land with the tickets that introduce
  segment, treatment and feature declarations; final fixtures land in WS43.
- **R8 resolved.** The correction-chain matrix is complete without importing
  the deferred lifetime-fact design.
- **R9 resolved.** All eighteen Section 10 groups have one primary owner;
  contributors and routed work are distinguished.
- **R10 resolved.** Cut 16 proves carried-input-share reachability and LDG-3071
  durably hands the consumer proof to WS7.
- **R11 resolved.** All 28 receivers are assigned once, each has one pending
  link and no nonexistent pipeline advance is claimed.
- **R12 resolved.** Frame, matrix, scalar, entry-point and continuity fixtures
  include independent literal values, timestamps and IDs.

## Type 2 disposition

Resolved by the maintainer on 2026-10-16. `ledgr_pulse_snapshot()` is external
development and inspection, not a strategy callback dependency.
Availability-aware inspection derives from an experiment, concrete parameters
and cutoff; the experiment supplies snapshot, universe, features, history
policy, data start and opening state. A strategy reads history only through
`ctx |> ledgr_history_frame()`. The low-level snapshot-and-universe form stays
the dense inspection branch until execution-core consolidation.

## Patches applied after this review

1. LDG-3057 now owns every rule-3 contract reference affected by civil-time
   storage, re-derives the golden roots on Windows and Ubuntu and records the
   sole reason for their change. LDG-3071 detects stale rule/schema text.
2. Every ambiguous `declared data start` reference now means the first session
   of the experiment snapshot. No second configurable history start is added.
3. LDG-3066 owns run/sweep parity; experiment-derived pulse parity waits for
   LDG-3068, after LDG-3063 creates that surface.
4. LDG-3060 owns treatment and exclusion evidence. LDG-3062 owns the strategy
   witness proving estimation exclusion creates no execution intent, and
   LDG-3063 extends the substrate detector to experiment-derived inspection.
5. LDG-3057 pins the exact corporate-action child and parent classes, cutoff
   boundary and structured fields.
6. Evidence group 6 records LDG-3066 as the readiness/calculation-validity
   contributor.
7. The stale macro-plan sentence saying H4 is current is removed.
8. Every workstream close now verifies its receiver groups in present tense
   and removes their pending links instead of deferring all detection to H6.
9. The empty-wide result retains typed instrument columns even with zero rows,
   making its matrix dimensions unambiguous.

## Clean checks

- `tickets.yml` parses with 149 unique ticket IDs and resolved dependencies.
- All 28 receiver anchors carry exactly one pending link.
- `git diff --check 99a3b067` is clean apart from checkout line-ending
  warnings.
- `test-documentation-contracts.R` passes.
- No private data, full suite or long-running workload was used.

This is the second independent Type 1 verdict in the Cut 16 sequence. Under
the governance lifecycle, the exact patches above are verified directly; a
third correction-review round is neither required nor opened.

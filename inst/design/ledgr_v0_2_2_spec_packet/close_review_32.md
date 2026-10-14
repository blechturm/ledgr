# Workstream 32 close review

**Mode:** Type 1 close review
**Range:** `31ad6d39..7419ad5f`
**Candidate:** `7419ad5f`
**Reviewer:** Claude Opus, high effort, independent of the implementing agent
**Verdict:** `CHANGES_REQUIRED`
**Date:** 2026-10-14

The accepted lifecycle is applied and the guard remains report-only, but the
implementation and evidence are not yet sufficient for acceptance. Nine
bounded findings concern failure sensitivity, two omitted lifecycle rules and
several report identities or parsing boundaries. They fit the accepted design
and require correction round 1, not Type 2 reconsideration.

## Findings

1. **F1 (medium): the fixture claim overstates failure-class coverage.**
   Reviewer branch-deletion mutations showed that 17 of 18 claimed classes
   survived. Missing witnesses include declared-remainder loss;
   receiver/amendment provenance; stale consolidated backlinks; invalid
   `Status`; missing `Role`, `Authority`, rejection reason or remainder
   provenance; invalid disposition; malformed change rows; invalid bridge
   state; Type 2 verdicts; repository-escaping targets; malformed
   `claims.yml`; malformed tracked manifests; and the claims-warning branch.
   The explicit-anchor-kind and baseline-occurrence-key positive controls did
   fail. Add small failure-sensitive witnesses for every synthesis Section 6
   class and both malformed inputs, or narrow each claim to exactly what its
   witness proves. Because LDG-3042 requires all Section 6 classes, real
   witnesses are preferred.

2. **F2 (medium): reverse notice-to-change-row mapping is absent.** A notice
   or marker that points into a change-map source without a matching change
   row must be reported. Restore the synthesis's "or vice versa" behavior and
   add a fixture witness.

3. **F3 (medium): adopted packet-closeout text was removed with the obsolete
   ratio gate.** Restore the requirements to record what shipped, supported
   claims, remaining open items and one line per rejected approach or record.
   Retain counters for reruns, rejected records and disputed classifications;
   remove only obsolete gate wording.

4. **F4 (medium): the header rule rejects a valid Section 2 form.** Authority
   may be embedded in the Section-2 `Role` line. The current report therefore
   incorrectly flags the accepted governance synthesis as
   `missing_authority`. Treat `Receiver`, `Replacement`, `Operative
   remainder` and `Reason` labels as provisional spellings in the report
   documentation because Workstream 35 owns their final normalization.

5. **F5 (medium): the baseline is not self-contained.** `baseline.yml`
   depends at runtime on the historical exploratory census. Store all 51 exact
   entries in the baseline itself, print resolved-entry identities, and
   include finding kind in matching or visibly report a kind change. Preserve
   the 313-source identity without rewriting the old census.

6. **F6 (low): verdict parsing reaches body prose.** Check only the designated
   header block and strip Markdown backticks and emphasis before token
   comparison. Add a backticked-verdict fixture.

7. **F7 (low): repository-root local paths are misclassified as external.**
   Only URI schemes and `//` are external. A leading `/` resolves from the
   repository root and participates normally in reporting and baselining. Add
   a fixture witness.

8. **F8 (low): claims identity is checkout-dependent and incomplete.** Emit
   the claims input as a root-relative path plus its file SHA-256, document
   the capture method, and make complete report bytes independent of checkout
   location.

9. **F9 (low): a deleted fixture is absence-skipped inside a source
   checkout.** Skip only when the tool/source context itself is absent. Once
   inside a source checkout, a missing required fixture must fail.

## Correction boundary

Correction round 1 must add failure-sensitive mutations for each correction,
rerun the registered fixture block and documentation/control-plane suites, and
compare two full reports. A second checkout should confirm portable bytes when
practical. The correction may not broaden into Workstreams 33 through 35,
activate check mode, change product behavior, or claim maintainer acceptance.

## Review accounting

This is the first independent close-review verdict for Workstream 32 and starts
correction round 1. Under M1 no ratio is computed or used as a gate. Under M2
this file is the one packet home for the findings; `tickets.yml` carries only
the verdict, link and one-line impact.

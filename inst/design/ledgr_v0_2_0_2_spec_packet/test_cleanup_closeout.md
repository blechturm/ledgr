# v0.2.0.2 Test-Cleanup Packet Closeout

**Status:** Complete after focused Type 1 re-review and explicit maintainer
acceptance.

**Date:** 2026-09-22

**Authority:** `tickets.yml`, the accepted testing-architecture synthesis,
and D4/D8 of the accepted governance synthesis.

## What shipped

The five workstreams implemented the accepted test-suite cleanup:

1. Oracle repair replaced weak or circular evidence, contained side effects,
   and documented the bounded mock and frozen-fixture inventory.
2. The control plane added fail-closed `fast`, `review`, CRAN, and named-heavy
   routing; an independent two-sided census; a claims registry; clocks; and
   mutation-sensitive gates.
3. Fixture shrink reduced 132 fixtures. Two proposed reductions were rejected
   because their boundary probes stopped exercising the original condition.
4. Merge consolidated overlapping blocks by claim family while retaining
   independent negative, canonical-R, installed-path, and public-journey
   witnesses.
5. Delete replaced the remaining structural documentation checks with one
   current-state review-lane block, then removed 17 mixed historical pins
   while retaining their logo and optional-dependency guarantees.

The audited suite moved from 930 blocks to 850: 445 fast, 215 review, and 190
heavy. The registry still contains 17 stable block IDs and 14 claims.

## Supported claims

- Every ordinary profile invocation reconciles independently parsed expected
  selection with reporter-observed execution.
- The fast lane includes the canonical-R differential core and remains under
  its 90-second registered bound on the recorded host.
- CRAN mode runs the same fast membership from a recorded isolated library,
  with no registered claim depending only on skipped evidence.
- Review remains unconditional at release and owns extended parity plus the
  current documentation-artifact check.
- Heavy protocols remain named, separately invoked, owner-bound work; this
  packet did not disguise them as ordinary membership.
- The 17 final blocks are gone, but their executable current-state guarantees
  remain: artifact and logo existence, the logo size cap, installed article
  links, rendered image targets, the DuckDB notice, and optional `qlcal`
  containment have one executable review-lane replacement. Only their
  version-stamped or sentence-level material is left to Git history.

These are claims about routing and detecting evidence, not proof that every
test is minimal or that the claims registry is exhaustive.

## Workstream 5 deletion map

`LDG-2771` replaces structural current-state checks, including the logo and
`qlcal` assertions recovered during Type 1 review. Completed release prose
has no replacement because Git is its history.

| Deleted block | Replacement or reason |
| --- | --- |
| README and package docs use package-visible logo | LDG-2771 checks both logo assets and the package-logo size cap. |
| indicator docs include compact multi-output ID references | No replacement: sentence-level completed documentation state. |
| availability runtime and strict feature windows are documented | No replacement: sentence-level completed packet state. |
| README exposes documentation discovery | LDG-2771 checks current documentation roots and installed article links. |
| NEWS records v0.1.7.4 package adoption | No replacement: version-stamped release history. |
| NEWS records v0.1.7.5 TTR indicators | No replacement: version-stamped release history. |
| NEWS records v0.1.7.6 durable persistence | No replacement: version-stamped release history. |
| evidence-only business objectives and contracts are documented | No replacement: completed evidence-packet prose. |
| strategy preflight is positioned at the research boundary | No replacement: sentence-level completed documentation state. |
| auditr integration is documented as an external downstream concern | No replacement: sentence-level completed documentation state. |
| sweep docs state discipline and non-goals | No replacement: sentence-level completed documentation state. |
| research workflow documents the canonical workflow and caveats | No replacement: sentence-level completed documentation state. |
| facts docs cover inspection and preparation | LDG-2771 retains `qlcal` in Suggests, out of NAMESPACE imports, and confined to `availability-facts.R`; its prose is history. |
| availability economics docs state the controlled stop | No replacement: sentence-level completed packet state. |
| walk-forward docs cover the public workflow | No replacement: sentence-level completed documentation state. |
| new teaching surfaces are linked from current docs | LDG-2771 checks installed article links and source/rendered targets. |
| v0.2.0.0 packet preserves the pre-edit wide-projection inventory | No replacement: completed packet history. |

The final commit message must preserve this replacement-versus-history split.

## Recorded clocks

All clocks used R 4.6.1 on Windows, testthat 3.3.2, duckdb 1.5.2,
collapse 2.1.8, yaml 2.3.12, and pkgload 1.5.2. The source baseline is
`7ae5892`. The fast and CRAN clocks used implementation-only binary diff
`e3a298cef5d8c276f1313a6f9b37b1c80a748de6`. The corrected review clock used
binary diff `5ad9d89ad54962804c0e2b74d778980769796f3a`; its final test file has
SHA-256 `154165AFA57C39E5A1CD6BFDF5666BCD8E766E4E1C15C06A84B444632D62ABC4`.
These are explicitly worktree clocks, not falsely attributed to a later
closeout commit. The correction changes only the selected review block.

| Clock | Result |
| --- | --- |
| ordinary fast | 445 expected, 445 executed, 0 skipped/failed, 88.220 s; bound 90 s |
| isolated CRAN fast | 445 expected, 445 executed, 0 skipped/failed, 87.220 s; bound 105 s |
| ordinary review | 215 expected, 215 executed, 27 disclosed optional skips, 0 failed, 328.670 s after review correction |

Reproduction, from the repository root:

```powershell
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --library=C:/Users/maxth/Documents/R/win-library/4.6 --records=<out>/fast --run-index=1
Rscript --vanilla tools/prepare-cran-test-library.R --library=<empty-lib>
$env:LEDGR_CRAN_LIBRARY_MANIFEST='<empty-lib>/_ledgr_cran_library_manifest.csv'
$env:LEDGR_CRAN_WORKDIR='C:/Program Files/R/R-4.6.1/library'
Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=cran --library=<empty-lib> --records=<out>/cran --run-index=1
Rscript --vanilla tools/run-test-profile.R --profile=review --mode=ordinary --library=C:/Users/maxth/Documents/R/win-library/4.6 --census=<out>/review-census.csv --summary=<out>/review-summary.csv
```

The isolated manifest held 36 packages and had SHA-256
`638B52895AC3D2C6555A2CDA1856826085FF26270AD410869AAD4D354A8D727A`.
The first Workstream 5 CRAN invocation was rejected before selection in 2.2 s
because the prepared manifest path was not exported. No test result was
accepted from it; the corrected command above produced the recorded clock.

## Pilot counters

### Reviews and turns

Review invocation means one independent verdict, including the ticket-cut
review. Eleven reviews are complete: cut 1, Workstream 1 two, Workstream 2
two, Workstream 3 one, Workstream 4 three, and Workstream 5 two. All 31
tickets are complete: 11 / 31 = 0.355, below the 0.5 gate.

Counting only governance decision or handoff messages, not status updates,
the pilot used eight maintainer open/accept, review-handoff, or decision turns;
twelve implementation-agent handoffs; and eleven independent-review turns.

### Findings and outcome changes

| Review | Mode and result | Consequence |
| --- | --- | --- |
| ticket cut | Type 1 plus Type 2; 4 blocking findings | restored 49 heterogeneous documentation rows to Merge; added rule and closeout owners; encoded workstream gates |
| Workstream 1 round 1 | Type 1; 4 findings and 3 routed notes | made cleanup fail-safe, added its detector, restored an error-class assertion, narrowed mutation claims, and routed control-plane gaps |
| Workstream 1 round 2 | Type 1; pass | opened Workstream 2 |
| Workstream 2 round 1 | Type 1; 3 findings and 2 notes | fixed shared-fold claim fidelity, made mutation proof end-to-end, and made the optional-package boundary self-maintaining |
| Workstream 2 round 2 | Type 1; pass | opened Workstream 3 |
| Workstream 3 | Type 1; pass with one low observation | no outcome change; opened Workstream 4 |
| Workstream 4 round 1 | Type 1; 2 required findings | corrected the 17-row W5 boundary and stopped merged prerequisites suppressing siblings |
| Workstream 4 round 2 | Type 1; 1 residual | fixed four further sibling-suppression cases missed by the reviewer's first truncated scan |
| Workstream 4 round 3 | Type 1; pass | opened Workstream 5 |
| Workstream 5 round 1 | Type 1; 2 moderate findings and 1 note | restored logo existence and size plus `qlcal` containment; recorded overlap with the installed-article block |
| Workstream 5 round 2 | Type 1; pass | accepted Workstream 5 for maintainer decision and commit |

### Runtime, reruns, and rejected records

Fifteen retained profile or heavy-protocol commands over 60 seconds consumed
3,867.280 seconds (64 minutes 27.280 seconds): three in Workstream 2, three in
Workstream 3, five in Workstream 4, and four in Workstream 5. This is a
lower bound: focused tests, independent reviewer runs, and Workstream 1 runs
without retained clocks are excluded.

Workstreams 1, 2, and 5 each required one correction review; Workstream 4
required two. Workstream 4 also repeated one passing profile after its first
evidence destination proved unwritable; that first invocation was not kept as
a record. The 2.2-second Workstream 5 CRAN invocation above was rejected
before tests. No failed or superseded empirical result was silently promoted.

### Retained governance surface

The packet retains README (90 lines), tickets (388), and cut review (132):
610 lines before this closeout. Linked decision and audit authority adds four
files and 1,789 lines. Including this closeout, the retained governance and
decision surface is eight files and 2,604 lines. `tests/README.md` is a
separate 47-line operational manual; including it yields nine related files
and 2,651 lines.

Disputed classifications resolved during the pilot:

- The cut tried to reroute 49 heterogeneous documentation merges to one
  render check; Type 2 review returned them to claim-family adjudication.
- One `delete_after_replacement` public-site block was retained in Merge
  because its executable ordering and path witnesses were useful, leaving 17
  rather than 18 rows for Delete.
- Workstream 3 implemented 132 reductions and retained two after boundary
  probes showed that the proposed smaller fixtures lost their condition.
- Workstream 4's first skip scan named six merged blocks; a full parse found
  ten. The review record attributes the correction to reviewer error.
- Workstream 5 initially classified two mixed blocks as prose-only. Type 1
  review restored the logo asset/size and `qlcal` containment guarantees.

## Rejected approaches and records

- Per-ticket independent review: rejected because workstream-close review
  preserved the material boundaries with far fewer invocations.
- A directory split and mass test move: rejected because routing metadata and
  the census supplied the needed control without churn.
- Mandatory inline oracle prose: rejected because it can drift and does not
  make an oracle independent.
- A single render-freshness replacement for 49 documentation claims: rejected
  because runnable examples, installed paths, and public journeys differ.
- Silent skips for missing review-lane sources: rejected because one missing
  prerequisite must fail without suppressing a runnable sibling.
- The two unrecorded invocations named above: rejected for missing evidence
  destination or manifest authority, not reinterpreted as passing records.

## Open work

- The promoted loop must be reassessed after v0.2.0.2 and before the next
  version inherits it; promotion here is deliberately not permanent.
- The broader v0.2.0.2 accounting-core work has not opened. This packet does
  not authorize it.
- The heavy profile remains at 190 blocks and was not rerun for Workstream 5;
  no heavy block or production code changed here.

MAINTAINER PILOT DECISION: PROMOTE FOR V0.2.0.2; REASSESS BEFORE NEXT VERSION

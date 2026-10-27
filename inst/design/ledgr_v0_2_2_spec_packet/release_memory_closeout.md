# v0.2.2 Release-Memory Closeout

**Role:** durable release-closeout evidence.
**Status:** Workstream 66 accepted; publication handoff completed 2026-10-27.
**Authority:** `tickets.yml` LDG-3117. This record reports reconciliation; it
does not replace contracts, accepted RFCs or the release playbook.
**Date:** 2026-10-26.

## Outcome

The v0.2.2 candidate now has one package version, one user-facing upgrade
story and one current design-memory route. `DESCRIPTION` and the first NEWS
heading identify 0.2.2. NEWS describes the final shipped formats and public
surface rather than the intermediate schemas used while the release was being
built. The macro plan is frozen as a completed planning record; `tickets.yml`
alone owns the remaining release gate and publication sequence.

## Version-consistency inventory

| Surface | Candidate value or disposition |
| --- | --- |
| Package metadata | `DESCRIPTION` version `0.2.2` |
| Release notes | first heading `ledgr 0.2.2` |
| Implementation worktree | `codex/cut23-release-closeout`; not represented as the release branch |
| Local release branch | `refs/heads/v0.2.2`; Workstream 67 merges the accepted candidate before its first gate |
| Remote release branch | `refs/remotes/origin/v0.2.2` is behind the local candidate at this freeze; Workstream 67 rechecks the remote immediately before explicit release-branch CI |
| Intended tag | `refs/tags/v0.2.2`; deliberately absent until the separately authorized publication step |
| GitHub Release target | `v0.2.2`; deliberately absent until the tag workflow is green |
| Active packet | `inst/design/ledgr_v0_2_2_spec_packet/` |
| Active design front door | `inst/design/README.md`, still pointing to v0.2.2 until publication |
| Next-release handoff | Maintainer-supplied `v0.2.3`; packet path `inst/design/ledgr_v0_2_3_spec_packet/`. LDG-3118 performs the switch only after publication. |

Older version strings remain only where their age is meaningful: historical
NEWS sections, versioned packet and RFC filenames, migration/refusal fixtures,
tests of version parsing, and release-history prose. Intermediate v0.2.2
identities in the current NEWS section were corrected to the final formats;
they are not retained as a development diary.

## User-facing release memory

The first NEWS section now stands alone as the upgrade guide from v0.2.1.0.
It names the public outcomes, rebuild requirement, removed or changed public
names, final persistent-format versions and the supported research boundary.
It repeats the accepted Sharadar carried-bar sentence verbatim and discloses
terminal assumptions, one pulse per session, the long-only estimator scope and
the workload-specific one- and two-worker memory observations. It contains no
ticket, workstream, test-block or private-helper vocabulary.

The current-only format inventory is:

- experiment-store schema 124 and snapshot hash rule 4;
- run identity rule 4;
- valuation-policy and corporate-action-policy schema 2;
- saved-sweep format 6 and retention format 2;
- provenance and candidate-reproduction-key format 2;
- walk-forward candidate and inspection format 2; and
- promotion-context format 3.

Older stored artifacts refuse. The release supplies no migrations, tolerant
readers or missing-marker fallbacks.

## Decision-bridge reconciliation

Three accepted rows now have exact present-tense receivers and therefore move
to `decisions.md` Removed locators:

| Removed bridge row | Exact current receivers |
| --- | --- |
| Point-in-time historical projection | Snapshot facts; availability provider and timing; context inspection; execution window start; strategy decision axis; result reads; documentation strategy context |
| Recursive-indicator history boundary | Indicator computation; strict features; TTR adapter; feature path; indicator teaching |
| Strategy scheduler and common calendar rules | Execution entry points; fold core; execution identity; strategy decision axis; result reads; strategy-context teaching |

Objective-filtered walk-forward identity and the OMS order lifecycle remain in
the live bridge because no complete current contract receiver and no
implementation owner exists. Removing either would lose an accepted
obligation.

## RFC-pipeline reconciliation

- Ordinary causal-history manifestation leaves the pipeline: LDG-3105 is
  complete and its behavior is consolidated in contracts.
- Snapshot-verification WS5-B is complete through LDG-3056; the redirect now
  points to the current Snapshot Contract and accepted history.
- Historical projection and recursive-indicator redirects now describe
  completed implementation rather than open ownership.
- Fold-phase implementation ownership is complete. The row retains only its
  genuine future triggers for output-handler or compiled-envelope work.
- The governance-lifecycle M1 reassessment deliberately remains open. LDG-3118
  owns it because the final Cut 23 review count does not yet exist.

Every other pipeline row names a future trigger without a current ticket and
therefore remains. No accepted obligation was moved back into `horizon.md`.

## Horizon, roadmap and concurrent inputs

The active packet refers to `horizon.md` only as non-binding parking, as an
explicit release definition check, or as historical evidence inside closed
ticket records. The packet front door, macro plan and design front door all
say that horizon is not authority. Historical review artifacts and closed
ticket evidence were not rewritten merely to erase links.

The accepted next-release routing commit `f46de1f1` was merged before this
freeze. It carries the export-shape audit plus roadmap and horizon routes. The
accepted spot-crypto readiness spike is upstream of that route. Both are
future inputs, not v0.2.2 release claims. No uncommitted audit, roadmap or
horizon file is cited as release evidence.

The main v0.2.2 worktree currently has line-ending-only generated changes in
`R/cpp11.R` and `src/cpp11.cpp`. They are excluded from the candidate and from
all release evidence; Workstream 67 requires a clean release worktree before
the first gate.

## Navigation and publication handoff

Until publication, `AGENTS.md`, `inst/design/README.md`, the roadmap and this
packet continue to identify v0.2.2 as active. Workstream 67 may switch them
only in its post-publication, untagged main commit and only to the exact
maintainer-supplied next-release identifier and packet path recorded above.
The macro plan no longer schedules work: it is a frozen explanation of how the
release reached the candidate boundary.

## Verification

The candidate must pass the focused project-metadata,
release-claim-boundary and documentation-contract suites, both YAML parses,
local-link checks for every touched document and `git diff --check`. The
independent Workstream 66 Type 1 review records those results and challenges
the receiver and version inventories before maintainer acceptance.

The first close review found three bounded record defects. The version bump
left the executable Sweeps render at engine 0.2.1.0, the current-layer article
still named v0.2.1.0, and the upgrade guide named two history surfaces that
never shipped in v0.2.1.0 while leaving `ledgr_feature_cache_clear()` unnamed.
The correction rerenders Sweeps under 0.2.2, updates the article and its
documentation-contract pin, and narrows the upgrade list. The pin changes only
because its exact prior version literal became the stale claim being fixed; it
still requires the current-layer sentence in both source and rendered article.
The complete `render-vignettes-gfm.R --check --all` gate then exposed and
confirmed the one other version-derived render change: the walk-forward
session ID. All 28 tracked article renders are fresh after that correction.

## Post-publication completion

Tag and GitHub Release `v0.2.2` were published from `7539be45` after mandatory
tag workflow 40542364504 passed. The untagged post-publication commit activates
the maintainer-supplied v0.2.3 packet and turns this document's pre-publication
inventory into historical evidence. Exact remote and M1 records are in
[release_gate_closeout.md](release_gate_closeout.md).

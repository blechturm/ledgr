# Workstream 34 Type 1 close review

**Verdict:** CHANGES_REQUIRED

The mechanics hold up. All 19 hashes recompute, the 73-entry population
reconciles, the moved bodies are verbatim, and nothing was moved or reopened
for shipping. The rewrite nevertheless dropped live routing, demoted one
accepted decision, misclassified at least one Horizon entry, and recorded no
ticket evidence.

The review brief named `planning_front_door_reconciliation.md` and
`horizon_current_reconciliation.md`; the implementation instead created
`horizon_open_classification.md` and `macro_plan_history.md`.

## Blocking findings

### F1. Accepted execution-mode decision was demoted

`ledgr_roadmap.md` and H009 say to reconsider one execution mode and retain the
older two-mode route. The later accepted release-line commit `4397f58f` binds
availability-only history, freezes dense mode, and makes execution-core
consolidation a committed pre-CRAN goal. Current planning must state that later
decision, classify H009 as promoted or mixed, and route the older Cut 15 and
RFC-pipeline wording without erasing its historical record.

### F2. Post-history routing lost a live owner

Moving the dated macro amendments left only hashes for the dividend-facts lake
rebuild, WS7 checks, WS8 G-025 and the dividends-excluded headline,
growth-shape routes for custom-function slicing and result/print replay,
phase-timing evidence, availability-core placement at the WS3/WS4 cut, and
per-gap TTR in WS4. Add a concise live owner list after the joint gate or in
the existing WS sections. H006 must either remain genuine or point to that
real owner; LFB-013 is not the mapping owner.

### F3. A shipped Horizon entry was classified genuine

H022 shipped in v0.2.1.0 through LDG-2826 to LDG-2830 and the exported
surfaces. Archive it behind a redirect. Recheck every row whose body already
names a ticket or route, especially H005-H008, H011, H018-H020, H040-H044,
H055-H058, H062 and H065-H066, and replace boilerplate evidence with specific
evidence. The recorded 69 genuine / 1 shipped counts cannot stand.

### F4. Ticket evidence is empty

Both LDG-3045 and LDG-3046 have empty evidence arrays. Cut 15 requires one
pointer and one-line result for every acceptance item. Add five evidence items
for each ticket.

## Should-fix findings

### F5. Live documents cite removed roadmap rows

Current macro-plan, Horizon, RFC-pipeline and research-finding routes still
name deleted roadmap rows. Keep a concise Next release theme list and point
live documents to current owners. Do not restore a duplicate ticket ledger.

### F6. Two older redirect anchors remain broken

The failures predate WS34, but the stubs fall under its redirect claim. Point
the terminal-outcome stub at the terminal synthesis and the feature-map stub
at `decisions.md#feature-map-read-surface`. Leave older seed and migration
artifacts baselined for WS35.

### F7. Detector fails open at two boundaries

Renaming the `Open` section while adding an unclassified entry produces no
finding. Deleting an archive body while retaining its heading also passes.
The missing-archive-body and duplicate-classification findings lack explicit
test witnesses. Report a missing section/table structurally, validate body
presence rather than heading only, add both witnesses, and document the
current-packet pin in LCL-0273. The guard remains report-only.

### F8. Remaining-order numbering implies false dependencies

The numbered list presents WS34 before WS33/WS37 and puts multiple owners in
steps described as single-owner steps. Present separate governance and product
tracks or state the concurrency explicitly.

### F9. Some genuine entries lack their claimed trigger and route

At least the entries around the reviewed H040 group lack a trigger or route.
Add one concise route where it is known or narrow the claim accurately.

## Nits

- Add the missing blank line before the Remaining order heading.
- Move WS34 archive stubs below the archive section explanation.
- Reconcile release dates and small-scale live trading with the accepted
  2026-10-13 brief rather than dropping them silently.
- Add the omitted hash row for the base change-control paragraph.
- State in H066 that schema 120 deleted the current feature store.

## Per-ticket assessment

### LDG-3045

1. The roadmap table has 41 release rows, one v0.2.2 row and no generic
   release-family row, but the Next release text is wrong: partial.
2. One Remaining order exists and amendments no longer compete with it, but
   live post-history routing was lost: partial.
3. All 19 moved narratives reproduce from `1cbc5166`: pass.
4. Workstreams 32-39, two tracks and the joint gate are named, subject to F8:
   partial.
5. `inst/design` stayed in place with no shim: pass.
6. Evidence is missing: fail.

### LDG-3046

1. All 73 pre-change Open entries occur once and in order, but classifications
   are wrong for H022 and need rechecking for H006/H009 and routed rows:
   partial.
2. Four bodies survive verbatim once and redirects exist, but H006 dead-ends:
   partial.
3. Trigger/route preservation and no-demotion are not met: fail.
4. The three report kinds fire on fixtures, with the gaps in F7: partial.
5. Manual sampling found real misclassifications: fail.

## Verification performed

- `test-governance-report.R`, `test-test-control-plane.R` and
  `test-build-boundary.R` passed without failures, warnings or skips.
- `tests/claims.yml` and `tickets.yml` parsed; `git diff --check` was clean.
- Full report: 320 sources and 1,104 findings. The direct real-tree Horizon
  scan reported zero findings.
- Independent mutations caught archive-heading removal and duplicate table
  rows, but missed a renamed Open section and a deleted body with its heading
  retained.
- No design-tree move, copy or alias; `.Rbuildignore`, package code, CI and
  check mode were unchanged.

## Maintainer disposition

The review asked whether `4397f58f` supersedes the earlier two-mode language.
The accepted release-line commit is the binding later decision: history is
availability-only, dense is frozen, and execution-core consolidation is a
committed pre-CRAN goal. No new design round is needed; correction round one
records and routes that supersession.

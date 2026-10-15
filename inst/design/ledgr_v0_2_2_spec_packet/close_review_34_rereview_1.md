# Workstream 34 focused Type 1 re-review

**Verdict: CHANGES_REQUIRED.** This would be correction round 2, not the third round, so it does not go to the maintainer yet. Nothing in it needs a new design decision.

## Findings F1–F9

- **F1: resolved, with one surface missed.** The later rule from `4397f58f` appears consistently in five places: the roadmap's `#next-release`, macro plan `#execution-core-consolidation` (`:653-660`), the Cut 15 `current_state` in `tickets.yml:232`, RFC pipeline `#history-wave`, and the decision register. H009 is promoted. `4397f58f` is an ancestor of HEAD. Decision 9's historical text is unchanged.
  - **New, low:** packet `README.md:664-666` still says, in its current-state paragraph, that the RED probe "requires the later history implementation to support both dense and availability modes". Fix: one sentence pointing to `macro_plan.md#execution-core-consolidation`.
- **F2: resolved, with one stale pointer.** `#post-gate-live-routes` (macro plan `:662-674`) names owners for dividend facts (lake rebuild, WS7 G-013/G-016, build time, peak RSS, WS8 G-025, dividends-excluded headline), growth shape (custom-function slicing, result/trade/print replay, phase timing) and the availability core (cut placement, per-gap TTR in WS4). The H006 stub and table row point there.
  - **New, low:** the H006 archive disposition at `horizon_archive.md:3042-3043` still says "Current owner: research findings index, LFB-013". That contradicts the stub and F2. It sits outside the byte-identical body, so it is safe to repoint.
- **F3: partial.**
  - Counts reconcile exactly. 73 base Open headings, unique and in order, match the table: 67 genuine, 3 promoted (H006/H009/H015), 2 shipped (H022/H044), 1 superseded (H049). The genuine set equals the current Open list in order.
  - H022 is shipped, citing the Cut 9 closeout `#what-shipped`. H066 states the schema-120 deletion. All 21 rows the review named now have specific evidence.
  - **But** 46 rows still carry the boilerplate "No binding receiver or shipped disposition…", and several of those bodies name routes:
    - H061 (`classification:79`, `horizon.md:2818-2823`) cites a "Target Construction Helper Extensions" roadmap hook. The base roadmap recorded that row as done in v0.2.1.0 (Cut 16 WS23). This is a mixed entry, so "no shipped disposition" is false.
    - H063 (`:81`, `horizon.md:2889`) says "Promoted roadmap hook: `v0.2.x Benchmark Context And Active Metrics`". WS34 deleted that row, so the route now goes nowhere.
- **F4: resolved.** LDG-3045 and LDG-3046 each have 5 acceptance items and 5 pointer+result evidence items, and they match. One exception: the guard claim in LDG-3046 evidence item 4 overstates what the guard does (see F7).
- **F5: partial.**
  - Fixed: the RFC pipeline rows (persisted-data, spot-crypto), the macro-plan Section 5 note, and several Horizon entries (H058, H055, H069 prose, the memory theme at `:554`). The roadmap anchors used by the evidence resolve: `#release-sequence`, `#next-release`, `#boundary`.
  - Still naming deleted or non-existent roadmap rows or commitments in genuine entries:
    - H007 `horizon.md:332`: the "one store connection per composite call" row; its live owner is now macro plan `:556`.
    - H039 `:1838-1841`
    - H061, H063 (above)
    - H069 `:3226` and H070 `:3386`: "Promoted roadmap hooks"
    - H071 `:3483`, `:3489`, `:3717`
    - H073 `:3885-3886`: "Committed for v0.2.x" via a roadmap entry that does not exist
  - Fix: point each to its current owner, or state plainly that it is parked. No ticket ledger is needed.
- **F6: resolved.** The terminal-outcome stub points to `rfc/rfc_terminal_outcomes_v0_2_2_synthesis.md` and the feature-map stub to `decisions.md#feature-map-read-surface`. Both resolve. The older `horizon_migration_reconciliation.md` anchors stay baselined for WS35.
- **F7: not resolved (should-fix, report-only guard).** At `tools/governance-report.R:1009-1013`, a body runs from its heading to the next heading. The WS34 archive puts each entry's anchor and `**Disposition:**` paragraph above the heading, so the next entry's disposition continuation line (e.g. `horizon_archive.md:3098`, `:3284`) counts as the previous entry's body.
  - Mutation on a scratch copy of the real tree: deleting the body of H006, H009, H015, H022 or H044 (heading kept, with or without the back-link) produced **no finding**. Only H049, the last entry, is caught.
  - The fixture witness passes only because it has a single archived entry.
  - Fix: also end the region at `^<a[[:space:]]` or `^\[Back to classification\]`. Add a fixture witness with two archived entries in disposition-before-heading layout.
  - The other new boundaries hold: missing or duplicate `## Open`, altered table header, missing delimiter, duplicate classification (2 findings), unclassified entry, missing redirect, archived heading back under Open, deleted archive heading, and a misspelled class (reported as unclassified). The packet pin is explicit (default `inst/design/ledgr_v0_2_2_spec_packet`, recorded in LCL-0273). `--check` and `--mode=` abort, and output says `MODE report-only`.
- **F8: resolved.** Section 7 now shows two concurrent tracks. The only cross-track dependencies stated are WS33 after WS36 and WS39 after WS34. One joint gate (WS35 + WS39) precedes history. This matches the `tickets.yml` sequencing.
- **F9: resolved for the reviewed group.** H005, H018 and H040–H043, H055–H058, H062, H065, H066 now carry route lines. The F5 rows above remain open.

## Nits

- Blank line before Remaining order: resolved.
- Stubs below the section explanation: resolved (`horizon.md:3945-3973`).
- H066: resolved.
- Base change-control hash row: resolved.
- **Release dates: not resolved.** The base roadmap had "Released 2026-10-01" and "Latest release: … published 2026-10-01". The accepted 2026-10-13 brief says "Shipped releases keep date". The current roadmap has no release dates. Small-scale live trading is reconciled through the OMS synthesis (`v1.0.0`, line 60 there).

## Checks and counts

- **Archive integrity:** all 6 redirects resolve, and the redirect set covers every non-genuine row. All 6 archive bodies match base exactly once trailing blank lines are trimmed. H009 and H022 are raw byte-identical (87 and 42 lines).
- **History:** 20/20 SHA-256 hashes recompute from `1cbc5166`. The ranges are contiguous from line 633 to 1158, the end of the file.
- **Tests:**

| Test file | Tests | Expectations | Failures / skips / warnings |
| --- | --- | --- | --- |
| `test-governance-report` | 2 | 160 | 0 |
| `test-build-boundary` | 1 | 3 | 0 |
| `test-test-control-plane` | 8 | 66 | 0 |
| `test-documentation-contracts` | 24 | 1031 | 0 |

- **Other checks:**
  - Both YAML files parse: 134 tickets, 267 claims.
  - The full report gives 1,105 findings with 0 Horizon-guard kinds; the direct real-tree Horizon scan reports 0.
  - Link and anchor scan over 11 changed or related docs: 460 links, 0 broken.
  - `git diff --check` on the range is clean.
- **Scope:** the range touches only the 13 expected files. The working tree has `R/cpp11.R` and `src/cpp11.cpp` modified, but these were already modified when the session started and the diff is line-ending-only. I made no edits; all mutations ran in `tempdir()`.

## Maintainer decision

None needed. The fixes are mechanical: the F7 boundary plus its witness, the stale routes and evidence for H007/H039/H061/H063/H069–H071/H073, the H006 archive disposition, the packet README sentence, and shipped release dates.

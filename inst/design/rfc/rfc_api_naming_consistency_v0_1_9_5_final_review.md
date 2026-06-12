# RFC Final Review: API Naming Consistency And Surface Tightening

**Status:** Final review complete. **Verdict: APPROVED WITH PATCHES** --
four small in-place synthesis patches, none reopening design. Applied
2026-06-12 with a revision note on the synthesis per the rfc_cycle.md
in-place rule for final-review findings. With the patches applied, the
synthesis is binding.
**Date:** 2026-06-12
**Reviewer:** Claude (final reviewer; wrote seeds v1/v2; Codex wrote
response, v2 review, and synthesis).
**Scope:** verification only -- D1-D5 not reopened, no new names
proposed except where the synthesis contradicted its own bound rules.

---

## Findings (severity order)

### F1 (medium): the closed verb-first allowlist omits `ledgr_promote`

Synthesis Section 1 binds: "Verb-first exports are forbidden except for
this closed allowlist: `ledgr_compute_metrics`,
`ledgr_precompute_features`, `ledgr_validate_schema`, and
`ledgr_backtest_bench`" (synthesis lines 29-33). Section 2.2 then keeps
`ledgr_promote` unchanged with the rationale "Cross-container promotion
verb retained by existing workflow" (line 151). `ledgr_promote` is in
the export lock (`tests/testthat/test-api-exports.R:66`), is verb-first
(there is no artifact-noun reading of "promote", unlike `ledgr_run` /
`ledgr_sweep` which read as family roots), and is not on the list. As
written, the closed allowlist and the disposition table contradict each
other, and the contracts.md rework would inherit the contradiction.

**Patch:** add `ledgr_promote` to the R1 allowlist in Section 1. No
rename; the seed never put promotion in scope, the list was simply
incomplete. Execution entry points (`ledgr_run`, `ledgr_sweep`,
`ledgr_walk_forward`) are correctly NOT on the list -- they read as
artifact-family roots; one clarifying sentence added.

### F2 (low): NEWS.md dropped from cost surfaces and acceptance criteria

Seed v1 bound "NEWS.md carries the consolidated rename table"; seed v2
Section 8 inherited it ("v1 criteria stand, plus..."). The synthesis
omits NEWS.md from the Section 6 cost-surface list and has no NEWS
criterion in Section 7. The Section 7.2 sweep correctly EXCLUDES
NEWS.md from the old-name ban (old names must appear there, in the
rename table), which makes the missing positive criterion easy to lose.

**Patch:** add NEWS.md to the Section 6 cost surfaces and a 7.7
criterion: NEWS.md carries the consolidated rename/unexport table for
the batch.

### F3 (low): the missing/moved-db fail-closed path has no bound class

Synthesis 3.2 requires a fail-closed path for "missing or moved db
file" but Section 3.3's class list does not cover it. The v2-review
already identified the reusable class: `LEDGR_SNAPSHOT_DB_NOT_FOUND`,
verified present at `R/snapshots-list.R:183` (raised by
`ledgr_snapshot_load()` when the file does not exist -- exactly the
resolve-at-call failure mode).

**Patch:** bind reuse of `LEDGR_SNAPSHOT_DB_NOT_FOUND` for the
missing/moved-db path in Section 3.3.

### F4 (low): Recovery docs landing surface may be renamed in the same release

Section 4 binds the Recovery section to `vignettes/experiment-store.qmd`.
The v0.1.9.4 vignette screening audit (Split D, routed to the same
v0.1.9.5 release) proposes splitting experiment-store into "Data Input
And Snapshots" plus a refocused "Experiment Store" article. If Split D
ships first, the bound filename is ambiguous at gate time.

**Patch:** bind "the experiment-store vignette or, if the screening
audit's Split D has landed, its refocused Experiment Store successor
article" in Sections 4 and 7.7.

---

## Verified clean (no action)

- **Export-lock reconciliation is complete and exact.** Every name in
  `tests/testthat/test-api-exports.R` (127 entries including the six
  unprefixed) appears exactly once across Sections 2.1/2.2; Section 2.2
  contains no names absent from the lock. The 2.2 row ordering mirrors
  the lock's own `ledgr_run`/`ledgr_sweep` placement quirk (cosmetic).
- **Bucket A is exactly the four** resolved at D3: `ledgr_backtest_run`,
  `ledgr_create_schema`, `ledgr_metric_context_resolve`,
  `ledgr_compute_equity_curve`, with the duplicate-door rationale
  correctly stated (not a replay helper).
- **Recovery pair** (`ledgr_db_init`, `ledgr_state_reconstruct`) stays
  public per D4 with the docs requirement carried, including the
  what-it-does-not-do list (broker reconciliation, live restart safety,
  schema migration, sealed-snapshot repair) -- faithful to the D4
  resolution and its rationale.
- **D2 rule bound correctly**: `ledgr_ind_*` constructors +
  constructor-family metadata (incl. `ledgr_ind_ttr_warmup_rules`);
  `ledgr_indicator_*` infrastructure; registry renames consistent.
- **Candidate generic contract is faithful to patched seed v2**:
  durable-string locator attributes with the no-live-handles clause;
  resolve-at-call with re-verification; override requires `snapshot_id`
  AND `snapshot_hash` match with `db_path` free;
  `ledgr_walk_forward_snapshot_override_mismatch` named; Amendment 2
  discipline carried in full; v0.1.9.4 Section 4 supersession stated
  without weakening identity/rationale/fail-closed rules.
- **Q1 resolution** (`ledgr_indicator_remove`) is within the synthesis
  author's granted latitude and reasonably argued; Section 9 correctly
  reports zero surviving open questions.
- **Gates are mechanically checkable**: export-lock test, anchored
  rg sweeps with a well-defined exclusion set, internal-definition
  collision gate (the `ledgr_snapshot_connection` same-commit binding
  carried), M-8 regression gate (testable through the internal impl
  seam with a small threshold; does not require 100k-row fixtures),
  candidate-generic test matrix, streaming-contract preservation gate.
- **No overbinding found**: ticket granularity latitude is preserved
  (Section 9 closing), future obligations match v2, amendment
  discipline satisfied (substantive defaults and named gates
  throughout, no procedural-only routings).
- **M-8 prerequisite** correctly sequenced (before or with the rename
  batch) with the borrowed-connections-never-return-cursors contract
  matching the audit addendum's preferred fix.

---

## Disposition

The four patches were applied in place on the synthesis with a revision
note (per rfc_cycle.md: post-synthesis bug fixes caught during final
review). With those applied, the synthesis is internally consistent,
faithful to seed v2 and the D1-D5 resolutions, exhaustively reconciled
against the export lock, and ticket-cuttable. The cycle closes pending
maintainer acceptance; the rfc/README.md pipeline row should move to
the Topic Decision Index on acceptance.

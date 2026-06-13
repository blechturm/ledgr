# RFC Review: API Naming Consistency Seed v2

**Status:** Seed-v2 verification review. Recommends small in-place v2 patches
before maintainer decisions and synthesis; no v3 required.
**Date:** 2026-06-12
**Author:** Codex
**Input:** `rfc_api_naming_consistency_v0_1_9_5_seed_v2.md`

This is a verification pass, not a second response-stage redesign. I checked
that seed v2 absorbed the response findings, then pressure-tested only the new
Section 5 locator contract and the new v2 rename/collision claims.

---

## 1. Absorption Verdict

### Response finding 1: `ledgr_snapshot_open` collision

Absorbed faithfully. Seed v2 names the existing collision with the internal
lazy connection helper (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:101-111`)
and binds an internal rename to `ledgr_snapshot_connection()` before the public
`ledgr_snapshot_open` rename. The source confirms the collision: current
`ledgr_snapshot_open(snapshot)` is an internal helper (`R/snapshot.R:61-78`)
and `get_connection()` calls it for snapshot handles (`R/snapshot.R:80-83`).

Definition-only grep found no existing definition for
`ledgr_snapshot_connection` or `ledgr_equity_reconstruct`, so the new v2 names
do not currently collide with code definitions.

### Response finding 2: Q3 fills disposition

Absorbed faithfully. Seed v2 binds `ledgr_extract_fills` ->
`ledgr_run_fills()` and explicitly keeps the public `lazy` /
`stream_threshold` contract (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:87`).
That matches the response: the streaming surface is not a pure
`ledgr_results()` rename. Current source still exposes `lazy` and
`stream_threshold` on `ledgr_extract_fills()` (`R/backtest.R:1168-1172`) and
can return a `ledgr_fills_cursor` (`R/backtest.R:1410-1412`).

### Response finding 3: walk-forward locator contract

Mostly absorbed, with two patch requests below. Seed v2 correctly withdraws
the overstated sweep precedent and states that current sweep results carry
identity attributes, not a durable locator
(`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:154-163`). Current source
confirms that sweep results carry `snapshot_id` and `snapshot_hash` attributes
but no `db_path` or snapshot handle (`R/sweep.R:294-332`), while current live
and reopened walk-forward result objects carry tables and run ids but no
locator attributes (`R/walk-forward.R:151-168`,
`R/walk-forward-inspection.R:15-40`).

Patch needed: Section 5 should explicitly require override snapshots to match
both `snapshot_id` and `snapshot_hash`; `db_path` may differ because moved
stores are the reason the override exists. It should also name whether new
condition classes are required for missing/moved locator and override mismatch
paths.

### Response finding 4: unexport split and `ledgr_backtest_bench`

Absorbed faithfully. Seed v2 splits unexports into bucket A confirmed removals,
bucket B recovery-surface decision, and bucket C telemetry decision
(`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:126-150`). It correctly
elevates `ledgr_backtest_bench` to D5 because contracts bind detailed
session-scoped telemetry through it (`inst/design/contracts.md:259-262`).

### Response finding 5: blast-radius corrections

Partially absorbed. Seed v2 correctly keeps contracts.md as a first-class
rework item and carries the doc-contract/pkgdown/README/UX cost surfaces
(`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:222-236`). The count still
needs a small correction; see Section 2.

---

## 2. Verification Results

### Count dispute

Seed v2 is half right. The current physical file length is 714 lines: the file
ends at `inst/design/contracts.md:714`. However, current grep counts are still
99 `ledgr_*` tokens across 84 matching lines, not 100 tokens across 85 lines.
The last matching lines include `inst/design/contracts.md:648`,
`inst/design/contracts.md:675-676`, `inst/design/contracts.md:680`, and
`inst/design/contracts.md:688`.

Patch needed: change seed v2's count claim at
`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:28-29` and
`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:224-227` to "714 physical
lines with 99 `ledgr_*` tokens across 84 matching lines." My response's
691-line figure came from the wrong PowerShell line-count method; the token and
matching-line counts were correct.

### M-8 verification

M-8 is confirmed. The actual path is:

- `as_tibble.ledgr_backtest()` opens a read connection, stores it as `con`, and
  schedules `opened$close()` on exit (`R/backtest.R:2306-2308`).
- For `what = "fills"`, it calls `ledgr_extract_fills_impl(x, con = con)`
  (`R/backtest.R:2310-2316`).
- A supplied `con` means `owns_connection` remains `FALSE`; only the
  `is.null(con)` branch sets `owns_connection <- TRUE`
  (`R/backtest.R:1172-1184`).
- If `total_rows > stream_threshold`, the implementation sets `lazy <- TRUE`;
  the safe re-entry path is gated on `owns_connection`, so it does not fire for
  the borrowed connection (`R/backtest.R:1204-1209`).
- The function later returns `new_ledgr_fills_cursor(..., con)` when `lazy` is
  true (`R/backtest.R:1410-1412`), but the caller's `on.exit` closes that same
  borrowed connection (`R/backtest.R:2306-2308`).

The audit addendum's preferred fix is sound: borrowed-connection callers should
materialize eagerly and never return a cursor over a connection they do not own
(`inst/design/audits/v0_1_9_4_deep_code_review_audit.md:358-364`). Side
effects are acceptable because `ledgr_results()` is documented as eager and
has no cursor lifecycle. It also fixes any other borrowed-connection caller
that expects a materialized fill table.

One nuance: the audit's alternative option, passing `stream_threshold = Inf`,
is not sufficient as the code stands. The implementation coerces
`stream_threshold` with `as.integer(stream_threshold)` (`R/backtest.R:1199-1202`),
so an `Inf` sentinel would need its own validation/coercion change. This does
not affect v2's Q3 disposition.

### New name collisions

Definition-only grep found no existing code definitions for the two new v2
names:

- `ledgr_snapshot_connection`
- `ledgr_equity_reconstruct`

The only grep hit for `ledgr_snapshot_connection` was the seed-v2 proposal
itself (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:107`).

### Replay-pair claim

Patch needed. Seed v2 says `ledgr_compute_equity_curve` and
`ledgr_state_reconstruct` are "both replay-from-events"
(`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:92`). That is not true of the
current public equity helper.

Current `ledgr_compute_equity_curve()` delegates to
`ledgr_compute_equity_curve_impl()` (`R/backtest.R:1707-1711`), and the impl
reads the persisted `equity_curve` table through `ledgr_backtest_equity()`
(`R/backtest.R:1717-1725`). By contrast, `ledgr_state_reconstruct()` is
documented as rebuilding derived state from the event-sourced ledger
(`R/public-api.R:73-85`) and actually calls `ledgr_rebuild_derived_state()`
(`R/public-api.R:150`).

The synthesis cannot bind `ledgr_equity_reconstruct` on the claim that it is a
replay-from-events helper unless implementation semantics change. Better v2
wording: treat `ledgr_compute_equity_curve()` as a public equity result
accessor whose final name is an open question, and keep D4 focused on the true
low-level recovery pair (`ledgr_db_init` + `ledgr_state_reconstruct`). If the
maintainer wants an equity "reconstruct" name, that should imply replay
semantics or be rejected.

---

## 3. Section 5 Locator Contract Findings

The durable-string locator direction is implementable and is the right shape.
Live walk-forward has access to the source snapshot through `exp$snapshot`:
`ledgr_experiment()` validates a `ledgr_snapshot` and stores it on the
experiment object (`R/experiment.R:221-235`, `R/experiment.R:276-279`).
`ledgr_walk_forward()` receives that experiment object (`R/walk-forward.R:37-58`)
and already computes session identity from `exp$snapshot`
(`R/walk-forward.R:199-229`). Reopened walk-forward also receives a snapshot
argument (`R/walk-forward-inspection.R:15-17`).

Resolve-at-call composes with current helpers. The current session reader opens
the run store from a snapshot object (`R/walk-forward-inspection.R:209-216`),
checks the persisted session snapshot hash (`R/walk-forward-inspection.R:226-227`),
and reads linked run config through the snapshot object
(`R/walk-forward-inspection.R:250-254`). A method can reconstruct a snapshot
from locator strings with `ledgr_snapshot_load(db_path, snapshot_id,
verify = TRUE)`, which already fails if the file is missing
(`R/snapshots-list.R:175-184`) and verifies the stored snapshot hash when
asked (`R/snapshots-list.R:220-228`).

Two patches are needed before synthesis:

1. **Override matching must include `snapshot_id`.** Seed v2 says an explicit
   override snapshot "must hash-match the locator attributes"
   (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:178-183`). The override
   should explicitly require matching `snapshot_id` and `snapshot_hash`;
   `db_path` may differ for moved stores. This matters because linked run
   config lookup is scoped by snapshot id (`R/walk-forward-inspection.R:289-296`).
2. **Condition classes need names.** Existing classes cover some paths:
   missing db files can reuse `LEDGR_SNAPSHOT_DB_NOT_FOUND`
   (`R/snapshots-list.R:182-184`), session hash mismatch can reuse
   `ledgr_walk_forward_snapshot_hash_mismatch`
   (`R/walk-forward-inspection.R:263-270`), and invalid linked session data can
   reuse `ledgr_walk_forward_invalid_session`
   (`R/walk-forward-inspection.R:349-360`). The override mismatch path is new,
   and the acceptance criteria require classed tests
   (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:250-253`). Seed v2 should
   either name a new class, such as
   `ledgr_walk_forward_snapshot_override_mismatch`, or explicitly bind reuse of
   an existing class.

No v3 is required for these; they are contract-tightening patches to new
Section 5 text.

---

## 4. D1-D5 Readiness

- **D1 is ready.** Seed v2 fairly presents namespace hygiene versus shop-window
  strategy fluency (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:197-218`).
  This is maintainer territory.
- **D2 is ready.** It bundles the `ind_` contraction and
  `ledgr_ttr_warmup_rules` placement explicitly
  (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:113-120`,
  `rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:269-270`).
- **D3 is ready.** Bucket A is coherent: `ledgr_backtest_run`,
  `ledgr_create_schema`, and `ledgr_metric_context_resolve`
  (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:126-132`).
- **D4 needs patching.** The recovery-surface decision correctly bundles
  `ledgr_db_init` and `ledgr_state_reconstruct`
  (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:134-142`), but it should not
  include `ledgr_compute_equity_curve` as an "equity-replay" helper unless v2
  stops claiming current replay semantics or deliberately scopes a semantic
  change. The exact equity helper spelling can remain an open question, but it
  should not be justified as replay-from-events today.
- **D5 is ready.** It is correctly scoped as a telemetry product decision with
  a contracts.md dependency (`rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:144-150`,
  `rfc_api_naming_consistency_v0_1_9_5_seed_v2.md:275-277`).

---

## 5. Recommendation

Do not proceed directly to maintainer decisions and synthesis yet. Patch seed
v2 in place with a revision note; no seed v3 is needed.

Required small patches:

1. Correct the contracts count to 714 physical lines, 99 `ledgr_*` tokens, and
   84 matching lines.
2. Remove or rewrite the claim that `ledgr_compute_equity_curve` is currently
   replay-from-events. Keep D4 focused on the true recovery pair, and leave the
   equity helper's exact name as a spec-cut open question unless a semantic
   change is deliberately scoped.
3. Tighten Section 5 override semantics: explicit override snapshots must match
   locator `snapshot_id` and `snapshot_hash`; `db_path` may differ.
4. Name the classed failure path for override mismatch, or explicitly bind reuse
   of an existing condition class.

After those patches, the cycle is ready for maintainer decisions D1-D5 and then
synthesis.

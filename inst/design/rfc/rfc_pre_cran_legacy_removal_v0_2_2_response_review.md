# RFC Response Review: Pre-CRAN Legacy Removal for v0.2.2

- Status: Response review by the seed author; seed v2 follows
- Author: Claude, seed v1 author
- Date: 2026-10-12
- Reviewed: `rfc_pre_cran_legacy_removal_v0_2_2_response.md` (REVISE_SEED)
- Baseline checked: `a2464434`

## Verdict

I accept the response except for one point. Its code claims hold where I
checked them. I reject its sequencing remedy, because moving the cut does not
avoid a second rebuild. The maintainer has decided that point.

## Checked Claims

- **G1, confirmed.** `ledgr_snapshot_connection()` opens through
  `ledgr_open_duckdb_with_retry()` with no schema check (`R/snapshot.R:82`).
  The split-store source attaches the snapshot file read-only and creates views
  without reading its `ledgr_schema_metadata` (`R/snapshot-source.R:48-71`).
  The gate needs one chokepoint. Accepted.
- **G2, confirmed.** There are 18 `*_schema_version` and `*_rule_version`
  constants in `R/`, plus the execution-timing version and the snapshot hash
  rule, and none is tied to the store marker. Accepted with one addition: the
  test that guards the fingerprint finds constants by name in the package
  namespace, so a new constant cannot be left out.
- **G3.** Accepted.
- **G4.** Partly accepted. The gate reads the marker anyway, but the
  refusal condition carries the recorded version, fingerprint and cause as
  fields. A new exported `ledgr_store_version()` would add a documented public
  surface for one message, so I rejected it.
- **R1, R2.** Accepted. Row absence (an interrupted run has no telemetry row)
  and construction-time `risk_chain` normalisation are current behaviour.
- **R3, confirmed.** `R/config-validate.R:360-363` requires
  `data.snapshot_hash` under rule 2, so "set the field" cannot work. Rule 2
  becomes required, and hand-built configs carry both fields. Ten test files
  call `ledgr_run_config()`.
- **S1, S2, V1, V2.** Accepted. V1's argument holds: both sides of the
  comparison are rendered by the running DuckDB. A close-and-reopen witness
  covers the storage-format case.
- **Section 6.** Accepted as the inventory correction. Trigger probing is
  refiled as dead current code, not legacy.
- **F6.** Accepted. LDG-3019 implements the accepted synthesis, and the
  removal cut deletes the legacy-snapshot branch.

## Rejected: the F1 Remedy

The response offers two orders: put the removal cut after the lake rebuild,
or do an interim rebuild. The first does not avoid a second rebuild. The
removal cut raises the store version, so a lake built before it is locked out
by it. Under the no-compatibility policy, any later store-format change locks
the lake out again, and WS3/WS4 is likely to add formats. So "rebuilt once"
cannot hold whatever the order.

Maintainer decision, 2026-10-12: rebuild the lake after every store-format
change. The first rebuild comes right after the removal cut, under rule 3 and
without dividends. The rebuild is a scripted, timed step, and the macro plan's
"rebuilt once" wording is amended.

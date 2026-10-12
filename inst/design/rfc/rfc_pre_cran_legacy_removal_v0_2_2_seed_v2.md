# RFC Seed v2: Pre-CRAN Legacy Removal for v0.2.2

- Status: Revised seed; synthesis is next
- Author: Claude, seed v1 author
- Date: 2026-10-12
- Target window: v0.2.2, the cut after Cut 13
- Baseline reviewed: `a2464434`
- Inputs: seed v1, the Type 2 response (REVISE_SEED) and its review
- Skipped stage: research input, as in seed v1

Revision: the response found that the gate had no chokepoint, that one
integer cannot mark a content epoch, and that three current behaviours had
been filed as legacy. It also added missing inventory items and raised a
sequencing conflict with the Sharadar lake. This revision makes these changes:

- it routes the gate through one opener;
- it adds a format fingerprint to the store marker;
- it keeps the three current behaviours;
- it completes the inventory;
- it records the maintainer's rebuild decision.

The direction and the deletion-not-refusal stance are unchanged.

This RFC uses "v1" only for ledgr's own v0.1.x releases.

## 1. Decision Taken and Question

The direction is decided: no backward compatibility before the first CRAN
release. Sources are the README ("stored artifacts, database schemas, and APIs
may change without a deprecation cycle"), `rfc_cycle.md` ("Pre-CRAN
Compatibility Policy") and the macro plan amendment of 2026-10-12.

The question is what replaces the compatibility code:

1. **A gate** that recognises and refuses anything not current.
2. **One schema authority** for creation, validation and tests.
3. **The contract text** that changes.

Out of scope:

- redesigning the schema;
- removing current surfaces (`ledgr_backtest()`, `function(params)`
  factories);
- changing any output of a current store.

## 2. What Is Removed

Citations are checked at `a2464434`.

| Area | Where | Kept working today |
| --- | --- | --- |
| Legacy schema path | `R/db-schema-create.R:40-492` | Stores from v0.1.0: column adds, rebuilds (`COMPLETED`, `FEE`, nullable `volume`) |
| Migrate pass | `R/experiment-store-schema.R:606-794` | Run column adds, provenance backfill |
| Table rebuilds | same file `:161`, `:225`, `:397` | Stores up to 112 and v0.2.1.0's 117 |
| Lazy `ensure_*` | `ledgr_experiment_store_check_schema()` `:581-604` | Tables created or patched on every write |
| Table and column probes | `R/run-store.R:74-80` and readers in about 15 files | Unmigrated stores read without migrating |
| Saved sweeps 1 to 3 | `R/sweep-persistence.R:410-422` and branches `:332-340`, `:476-478`, `:528-532`, `:602-610`, `:654-687` | Old risk, trade and completion fields |
| Identity rule 1 | `R/config-hash.R:43-66`, `R/config-validate.R:355-363`, `R/run-registration.R:95-109` | Hashing the store-local snapshot ID |
| Policy schema 1 | `R/corporate-action-policy.R:107-130`, `:388-401`; `R/availability-policy.R:97-118`, `:217-226`; `R/config-validate.R:392-440` | v0.2.1.0 policy records |
| Stored-config inference | `ledgr_config_normalize_risk_identity()` at reopen (`R/run-store.R:1148`); timing inference `R/execution-timing.R:42-48` | Configs without `risk_chain` or a timing version |
| Provenance markers | `R/strategy-provenance.R:130-138`, `:160-166` and readers | Runs before provenance |
| Old call forms | `fill_model` refusal arguments; `as_tibble(type =)` (`R/backtest-results.R:1169`); retention v1 (`R/sweep-retention.R:63-65`) | Refusals and aliases |
| Dead code | metric-kernel fallback `R/metric-context.R:353-378` | No caller passes a NULL context |

Some current behaviour sits next to these lines and **stays**:

- **Row absence.** An interrupted or `RUNNING` run has no telemetry row, and
  readers return `NA` for it.
- **Construction-time `risk_chain` normalisation.** `ledgr_experiment()` turns
  an omitted `risk_chain` into the no-op plan.
- **Version-2 timing validation.**

Trigger probing (`R/db-schema-create.R:544-569`) is removed under its own
reason: it is dead on the DuckDB in use (both statements fail on 1.5.6.9000),
not compatibility code.

## 3. The Gate

1. **One opener.** `ledgr_store_open(path, mode)` becomes the only way package
   code obtains a connection to a store file. It replaces direct calls to
   `ledgr_open_duckdb_with_retry()` (`R/public-api.R:10`) and the raw
   `dbConnect()` in `R/snapshot_adapters.R:275`. The two modes:
   - `"open"` refuses any store whose marker is not current;
   - `"create"` also accepts an empty file and writes the current schema.

   Creation sites use `"create"`: `ledgr_db_init()`, snapshot creation, and
   the split-mode run store on first use (`R/backtest-config.R:107-115`).
   Sites that open without a check today use `"open"`: the snapshot
   connection (`R/snapshot.R:82`), the backtest handle
   (`R/backtest-handle.R:107`, `:157`, `:225`) and the result readers
   (`R/backtest-results.R:1073`, `R/availability-results.R:295`). The 19
   per-call-site schema checks in 10 files outside the schema code are
   deleted.
2. **ATTACH reads the marker.** The split-store source checks
   `ledgr_snapshot_src.ledgr_schema_metadata` before any view is created
   (`R/snapshot-source.R:48-71`).
3. **The marker is a pair.** It holds the store version (raised to 119 by the
   removal cut) and a format fingerprint. The fingerprint is the canonical
   JSON of every persisted format constant: the 18 `*_schema_version` and
   `*_rule_version` constants, the execution-timing version and the snapshot
   hash rule. Both are written at creation and compared at open.
4. **One condition.** `ledgr_store_rebuild_required` has a `cause` field:
   older, newer, missing marker with ledgr tables, invalid marker, or
   fingerprint mismatch. Its fields carry the recorded version and the
   differing constants, and its message names the rebuild route.
   `ledgr_future_schema_version` folds into it. No new export: the condition
   holds everything a user needs to see why a file refuses.

The gate turns the epoch into a mechanism. A format bump cannot land without
a store bump, because a test enumerates the constants by name in the package
namespace and fails when one is missing from the fingerprint. Once the gate
holds, every record in an open store was written under current rules. That
makes the record-level branches in section 2 unreachable, so they are
deleted. Where a record carries a version field, one equality assertion
stays as a corruption check.

## 4. One Schema Definition

Today there are four descriptions of the schema:

- DDL literals spread over `R/db-schema-create.R`,
  `R/experiment-store-schema.R` and `R/availability-schema.R`;
- the hand validator (`R/db-schema-validate.R:14-779`);
- the LDG-3016 template, which replays the legacy path
  (`R/db-schema-create.R:498-514`);
- `ledgr_sweep_assert_schema_compatible()` (`R/sweep-persistence.R:311-330`).

All four are replaced by:

- **`R/db-schema-current.R`.** It holds the DDL for every table and index.
  `ledgr_schema_create_fresh()` (`R/db-schema-create.R:531-543`) already runs
  statements in one transaction and writes the marker last; only its
  statement source changes. Every table exists from creation.
- **Catalogue comparison.** `ledgr_validate_schema()` compares the store's
  catalogue with a reference catalogue built from the current DDL on
  `:memory:`, using the LDG-3018 normaliser
  (`R/db-schema-validate.R:785-825`). It is strict: an extra column is a
  difference. It reports differences by table, column and constraint. The
  semantic checks the hand validator made (status enums, event types) are
  CHECK constraints in the DDL, so the comparison covers them.
  - **Rendering.** The running DuckDB renders both sides, so a DuckDB upgrade
    moves them together. A create, close, reopen and compare witness covers a
    storage-format upgrade.
  - **Cost.** `ledgr_validate_schema_once()` stays in front as cost control.

## 5. Rule 2 Becomes Required

Rule 2 needs `data.snapshot_hash` (`R/config-validate.R:360-363`). So
`config_hash_payload()` refuses a config without `identity_rule_version`, and
validation requires both fields. `ledgr_config()` sets them
(`R/backtest-config.R:180`).

Hand-built configs passed to `ledgr_run_config()` must carry both fields:
- tests in 10 files;
- any `dev/bench` harness.

That census is the one place the fixture ladder cannot see.

## 6. Contract and Documentation Changes

`contracts.md`, by heading:

- **Execution Contract:**
  - the legacy `fill_model` refusal sentence;
  - the saved-sweep v2 migration and v0.1.9.2 reopen sentences;
  - the identity rule 1 sentences.

  These become the gate and required rule 2. The construction-time
  `risk_chain` sentence stays.
- **Config Contract:** the legacy `ledgr_validate_config()` reference.
- **Snapshot Contract:** the legacy-marker sentence. Unrecognised markers
  keep their refusal.
- **Availability Contract:** the `availability_close_v1` inference and
  "Legacy or unknown active configs".
- **Persistence Contract:**
  - the schema 113, 114 and 115 sentences become history, not rules;
  - remove "except for deliberate schema migration or DDL";
  - split the `ledgr_run_list()` / `ledgr_run_info()` sentence. Missing
    telemetry rows stay `NA`; "tolerate legacy/pre-provenance stores" goes.
- **Strategy Contract:** the two legacy-signature and legacy-metadata
  sentences.
- **New Persistence Contract clause:** one opener, one gate, one schema
  definition, no migration before the first CRAN release.

Elsewhere:

- **WS5-A synthesis section 3.5 and gate 8.** The legacy-snapshot metadata
  open and legacy-run readability become unreachable and are amended.
- **`vignettes/sweeps.qmd:521-522`.** This executed article promises a
  saved-sweep migration; the passage goes.
- **`R/condition-reference.R`.** The man page and `@aliases` drop the retired
  classes (`ledgr_legacy_fill_model_shape`, `ledgr_legacy_config_shape`,
  `ledgr_execution_timing_version_mismatch`) and add
  `ledgr_store_rebuild_required`. Otherwise `R CMD check` fails on orphaned
  aliases.
- **NEWS.**

## 7. Removal Cut Shape and Evidence

Each step has an oracle:

1. Write `R/db-schema-current.R` and prove its catalogue equals the
   legacy-built one. This is the legacy path's last use.
2. Add `ledgr_store_open()`, the marker pair and the gate. Route every opener
   and the ATTACH path through it. Raise the store version to 119.
3. Delete:
   - the legacy path, migrate pass and rebuilds;
   - `ensure_*` and the template;
   - trigger probing;
   - the per-site checks.
4. Delete the record-level branches and the table and column probes. Keep
   row absence. Make rule 2 required and fix the hand-built configs.
5. Replace the hand validator and the sweep column check with the catalogue
   comparison.
6. Remove the old call forms and update the contracts, the WS5-A synthesis,
   the article, the condition reference and NEWS.

Gates:

- **Byte identity.** The fixture ladder must be 51/51 at each code step.
  Stores are built per tree, so the ladder spans the version bump.
- **Opener census.** Every `dbConnect`, `ledgr_open_duckdb_with_retry`,
  `ledgr_db_init`, `ledgr_run_store_open` and `ATTACH` site in `R/` routes
  through `ledgr_store_open()`. A remaining raw open fails the review.
- **Gate tests.** Each cause refuses with its `cause` field:
  - a 118 store;
  - ledgr tables with no marker;
  - a newer marker;
  - an invalid marker;
  - a changed constant;
  - a 118 snapshot file attached under a 119 run store.

  An empty file gets the current schema. An interrupted creation leaves no
  table and no marker.
- **Fingerprint test.** A constant missing from the fingerprint fails.
- **Catalogue tests.** Each is reported by name: a dropped column, a weakened
  CHECK, an extra column, a missing table. The close-and-reopen witness
  compares equal.
- **Claims.**
  - Retire the claims that are now unreachable: LCL-0028 (LTB-0033) and
    LCL-0158 to LCL-0160.
  - Rewrite LCL-0026, LCL-0039, LCL-0200, LCL-0242 and LCL-0034 / LCL-0237
    without their migration or trigger arms. Their current halves stay: seal,
    replay, the no-selection record and rule-2 identity.
  - LCL-0234 drops rule 1.
  - LCL-0128's expected count changes with the article text.
  - The nine unregistered blocks in `test-experiment-store-schema.R` go with
    the code.
- **Cost.** Paired clocks on store open, `ledgr_db_init()` and
  `ledgr_snapshot_from_df()`. The fast and review profiles and the full suite
  must pass.

## 8. Sharadar Lake

Maintainer decision, 2026-10-12: the lake is rebuilt after every store-format
change. The first rebuild follows the removal cut, under rule 3 and without
dividends, so the WS3/WS4 reviews keep their real-data lane. Later format
changes, including the dividend-facts adapter change, rebuild again. The
rebuild is a scripted, timed step in ledgr-research, with the time recorded
in the evidence of the cut that forces it. The macro plan's "rebuilt once"
wording is amended.

## 9. Risks

- **A missed opener.** The census in section 7 is the guard.
- **Hand-built configs outside tests.** Any private harness that builds
  configs by hand fails loudly at `config_hash_payload()`, which is the
  intended failure.
- **Fingerprint churn.** Any format constant bump refuses every store. This
  is the policy, and its cost is the rebuild time recorded per cut.

## 10. Sequence

1. Synthesis, by an author other than this seed's.
2. A Type 1 final review.
3. Maintainer acceptance.
4. The removal cut after Cut 13, followed by the first lake rebuild.
5. The WS3/WS4 history wave.

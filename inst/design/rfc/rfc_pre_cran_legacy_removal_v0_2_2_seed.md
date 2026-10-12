# RFC Seed: Pre-CRAN Legacy Removal for v0.2.2

- Status: Seed v1; Type 2 response is next
- Author: Claude, seed v1 author, at the maintainer's request
- Date: 2026-10-12
- Target window: v0.2.2, the cut after Cut 13
- Baseline reviewed: `64d6d49d`
- Skipped stage: research input. The direction is a maintainer decision and
  the policy is already written down; no prior art is needed.

This RFC uses "v1" only for ledgr's own v0.1.x releases. It does not mean
ledgr 1.0.

## 1. Decision Taken and Question

The direction is decided and is not reopened here. The README says: "Until the
first CRAN release, stored artifacts, database schemas, and APIs may change
without a deprecation cycle, so expect to rerun experiments after upgrading."
`rfc_cycle.md` ("Pre-CRAN Compatibility Policy") says the same. The macro plan
amendment of 2026-10-12 records the decision: v0.2.2 deletes the code that
keeps older stores, records and call forms working.

The question is what replaces that code. Three parts:

1. **Gate.** How does ledgr recognise and refuse anything that is not current?
2. **Schema authority.** What single definition of the current schema do store
   creation, validation and tests use?
3. **Contract text.** Which `contracts.md` passages and accepted-synthesis
   clauses change?

Out of scope: redesigning the schema, removing current public surfaces that
merely carry the word "compatibility" (`ledgr_backtest()`, `function(params)`
feature factories), and changing any output of a current store.

## 2. What Exists Today

An agent inventory at `0c753e86` found about 950 lines of R and 1,700 lines of
tests that exist only for older data or call forms. I checked the citations
below against `64d6d49d`.

| Area | Where | What it keeps working |
| --- | --- | --- |
| Legacy schema path | `R/db-schema-create.R:40-492` | Stores from v0.1.0 on: column adds, table rebuilds (`COMPLETED` to `DONE`, `FEE` rows, nullable `volume`) |
| Store migrate pass | `R/experiment-store-schema.R:606-794` | Run column adds and backfills, `'legacy_pre_provenance'` provenance rows |
| Table rebuilds | same file, `:161`, `:225`, `:397` | `sweep_candidates` and `walk_forward_scores` without `completion_json` (stores up to 112); `walk_forward_folds` without `selection_source` (117, v0.2.1.0) |
| Lazy `ensure_*` | `ledgr_experiment_store_check_schema()`, `:581-604` | Sweep, walk-forward, availability and run-telemetry tables created or patched on every write |
| Tolerant readers | `R/run-store.R:74-280`, `R/metric-context.R:688-702`, `R/walk-forward-inspection.R:148`, `:394` and about 15 other files | Read-only opens never migrate, so readers check whether tables and columns exist |
| Saved sweeps 1 to 3 | `R/sweep-persistence.R:410-422` accepts 1..4; branches at `:332-340`, `:476-478`, `:528-532`, `:602-610`, `:654-687` | Missing risk fields, trades and `completion_json` |
| Identity rule 1 | `R/config-hash.R:43-66`, `R/config-validate.R:355-363`, `R/run-registration.R:95-109` | A config without `identity_rule_version` hashes the store-local snapshot ID |
| Policy schema 1 | `R/corporate-action-policy.R:107-130`, `:388-401`; `R/availability-policy.R:97-118`, `:217-226`; `R/config-validate.R:392-440` | v0.2.1.0 policy records readable, refused for execution |
| Config inference | `R/execution-timing.R:42-48`; `R/config-validate.R:445-459` | Availability configs without a timing version; configs without `risk_chain` |
| Provenance markers | `R/strategy-provenance.R:130-138`, `:160-166`; readers in run-store and strategy-extract | Runs recorded before provenance |
| Old call forms | `fill_model` refusal args and condition classes; `as_tibble(type =)`; retention v1 objects (`R/sweep-retention.R:63-65`) | Classed refusals and aliases |
| Dead code | `R/metric-context.R:353-378` (no caller passes a NULL context); trigger probing in `R/db-schema-create.R:544-569` | Both trigger statements fail on the DuckDB in use (1.5.6.9000); write paths already enforce sealed-snapshot immutability |

**There is no single definition of the current schema.** The DDL for the 10 core tables
exists only as literals inside the legacy path. Five more tables are defined only
in the migrate pass, and the rest in the `ensure_*` helpers.
`ledgr_validate_schema()` (`R/db-schema-validate.R:14-779`) is a third,
hand-written description. The LDG-3016 fresh-store template is built by
running the legacy path on `:memory:` (`R/db-schema-create.R:498-514`).

Published store schemas: v0.1.5 105, v0.1.6 to v0.1.7 106, v0.1.8 107 to 108,
v0.1.9.x 109 to 112, v0.2.0.x 115, v0.2.1.0 117; this branch is at 118.

## 3. Proposal in One View

1. **The store version marks a content epoch.** The removal cut raises the
   experiment-store schema version to 119. A store opens only when its marker
   equals the current version. An empty file receives the current schema. Any
   other store refuses with one classed condition naming its recorded version
   and the rebuild route: an older marker, a missing marker with ledgr tables,
   an invalid marker or a newer marker. Read and write paths share the gate,
   and read-only opens get no tolerance.
2. **Record-level legacy branches are deleted, not converted to refusals.** A
   pre-119 store never opens, so every record inside an open store was written
   under current rules. That makes these branches unreachable:
   - identity rule 1;
   - schema-1 policies;
   - saved sweeps 1 to 3;
   - provenance markers;
   - timing and risk inference;
   - missing, rule-1 and rule-2 snapshot markers.

   Where a record carries a version field, one equality assertion stays and
   refuses an unknown value as corruption. No version branches remain.
3. **One current-schema definition.** A new `R/db-schema-current.R` holds the
   DDL for every table and index, including those `ensure_*` creates today.
   A fresh store runs it in one transaction with the marker written last.
   Every table exists from creation, and `ensure_*`, the migrate pass, the
   legacy path and the template are deleted.
4. **Validation compares catalogues.** `ledgr_validate_schema()` compares the
   store's catalogue with a reference catalogue built from that definition, and
   reports differences by table, column and constraint. It reuses the columns
   and constraints fingerprint from LDG-3018, and replaces the hand description.
   It is strict: an extra column is a difference, because only ledgr writes
   ledgr stores.
5. **Old call forms go.** Delete:
   - the `fill_model`, `spread_bps` and `commission_fixed` refusal arguments
     and their condition classes;
   - `as_tibble(type =)`;
   - retention v1 normalisation;
   - the metric-kernel fallback;
   - trigger probing.
6. **Rule 2 becomes unconditional.** `config_hash_payload()` no longer treats
   a missing `identity_rule_version` as rule 1. Internal builders that omit
   the field get it set (`R/run-registration.R:102-103` says such configs
   exist).

## 4. Alternatives Considered

- **Refuse at each artifact,** as the WS5-A synthesis does for snapshots
  (section 3.5): every reader checks its record's version and refuses old
  ones. Rejected: it keeps one version check per artifact type alive. That is
  the weight this RFC removes.
- **A v0.2.1.0 floor.** This keeps the 117 to 118 rebuild, rule 1 and the
  schema-1 policies. Rejected by the maintainer decision. Also, v0.2.2 already
  refuses to execute those records, so reading them is half a promise.
- **Read-only tolerance for diagnosis,** so an old store can still list its
  snapshots and runs. Rejected for v1 of the gate: it is exactly what keeps the
  tolerant readers alive. The refusal message carries the recorded version and
  the route. Section 8 asks the response to challenge this.
- **Keep the hand-written validator** and consolidate only the DDL. This
  option stays open. It is cheaper to land and has no DuckDB rendering risk
  (section 7), but it keeps two descriptions of one schema in step by hand.

## 5. Contract Changes an Accepted Synthesis Would Authorize

`contracts.md`, by heading:

- **Execution Contract:**
  - the `fill_model` / `spread_bps` / `commission_fixed` "classed migration
    errors" sentence;
  - the saved-sweep v2 "additive schema migration" and "v0.1.9.2 saved sweep
    reopens" sentences;
  - the identity rule 1 sentences ("Stored runs and sessions are not migrated
    and stay readable under their recorded rule"). These become the
    store-version gate.
- **Config Contract:** the "legacy `ledgr_validate_config()`" reference.
- **Snapshot Contract:** "A missing marker, rule 1 or rule 2 is legacy:
  metadata-only reads may open it". Unrecognised markers keep their refusal.
- **Availability Contract:** the read-only `availability_close_v1` inference
  and "Legacy or unknown active configs".
- **Persistence Contract:**
  - the schema 113 and 115 migration sentences;
  - "except for deliberate schema migration or DDL";
  - "`ledgr_run_list()` and `ledgr_run_info()` ... must tolerate
    legacy/pre-provenance stores".
- **Strategy Contract:** "Legacy lower-level paths may retain older
  signatures" and "Legacy strategy metadata may be tolerated for historical
  run inspection".
- **A new Persistence Contract clause:** one current schema, one gate, no
  migration before the first CRAN release.

The WS5-A synthesis section 3.5 and its detecting gate 8 bind two clauses:

- legacy snapshots open for metadata;
- legacy run records stay readable through durable-result-only surfaces.

Under this RFC both become unreachable, and the synthesis is amended to say so.

## 6. Removal Cut Shape and Evidence

The order is chosen so that each step has an oracle:

1. Write `R/db-schema-current.R` and prove its catalogue equals the
   legacy-built catalogue. This is the legacy path's last use, as an oracle.
2. Add the gate, raise the version to 119 and turn creation into
   current-definition-only.
3. Delete the legacy path, migrate pass, rebuilds, `ensure_*`, template and
   triggers.
4. Delete the record-level branches and tolerant readers. Make rule 2
   unconditional.
5. Replace the validator with the catalogue comparison, unless the response
   keeps the hand validator.
6. Remove the old call forms. Edit `contracts.md`, the WS5-A synthesis and
   NEWS.

Gates:

- **Byte identity.** The fixture ladder is 51/51 against the predecessor commit
  for each code step. Fresh stores are built per tree, so the ladder is valid
  across the version bump.
- **Refusal tests.** Each of these refuses with the one condition and the
  recorded version: a 118 store, a store with ledgr tables and no marker, a
  newer marker and an invalid marker. An empty file gets the current schema,
  and an interrupted creation leaves no table and no marker.
- **Catalogue tests.** For each of these the validator reports the difference
  by name: a dropped column, a weakened CHECK, an extra column and a missing
  table.
- **A census.** Every persisted version field is listed with its single
  equality assertion. A remaining version branch fails the review.
- **Claims.** Rewrite or retire the registered claims that cover legacy
  behaviour:
  - LCL-0026, LCL-0034, LCL-0039 and LCL-0158 to LCL-0160 (schema-1 policies);
  - LCL-0234, LCL-0237 and LCL-0242 (identity rule 1).

  The nine blocks in `test-experiment-store-schema.R` are unregistered and are
  deleted with the code.
- **Cost.** Paired clocks on store open, `ledgr_db_init()` and
  `ledgr_snapshot_from_df()`. The fast and review profiles must pass, and the
  full suite must have no failures.
- **Maintainer-owned stores.** The ledgr-research lake and local experiment
  stores are rebuilt. The rule-3 rebuild is already scheduled after WS3/WS4.
  The bench fixtures build fresh stores, and no `.duckdb` file is tracked.

## 7. Risks

- **DuckDB rendering.** A strict catalogue comparison depends on how DuckDB
  renders constraint text and defaults. A store created under one DuckDB
  version and opened under another could compare as damaged when it is not.
  The reference is rebuilt each session on the running DuckDB, so this only
  bites across DuckDB upgrades. Today's hand validator is immune.
- **Low-level configs.** Making rule 2 unconditional changes the hash of any
  internal config built without the field. The fixture ladder catches this on
  the public path; internal builders need their own census.
- **WS27 overlap.** Cut 13 implements the WS5-A legacy-snapshot refusal now,
  and the removal cut deletes it shortly after. The cost is small, but it is
  real.

## 8. Questions for the Response (Type 2)

1. Is the store version the right epoch for every persisted artifact, or does
   anything live outside the store?
2. Strict catalogue comparison or the hand validator: is DuckDB's rendering
   stable enough across versions, and how would we know?
3. Should any diagnostic read of an old store survive the gate, and what
   would it cost in code?
4. Should WS27 shrink its legacy-snapshot handling now, or implement the
   accepted synthesis and let the removal cut delete it?
5. Is anything in section 2 current behaviour misfiled as legacy, and what
   legacy code is missing from it?

## 9. Sequence

1. This seed.
2. A Type 2 response by Codex.
3. Response review.
4. Synthesis by an author other than the seed's.
5. A Type 1 final review.

The cycle runs alongside Cut 13. The removal cut follows Cut 13 and comes
before the WS3/WS4 history wave.

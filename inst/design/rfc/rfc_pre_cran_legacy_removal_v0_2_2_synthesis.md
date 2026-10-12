# Synthesis: Pre-CRAN Legacy Removal For v0.2.2

**Status:** Accepted by the maintainer on 2026-10-12 after the Type 1 final
review (`rfc_pre_cran_legacy_removal_v0_2_2_final_review.md`) returned
PASS_AFTER_PATCHES and its three patches were applied in place (revision
history). Binding for the legacy-removal cut; implements as direct tickets;
no further RFC.
**Author/date:** Claude (Fable 5.1), 2026-10-12. Author of the Type 2
response; not author of either seed (a separate Claude session wrote both).
**Inputs:** seed v2, the response, the response review, seed v1, the macro
plan's 2026-10-12 legacy-removal amendment (with the maintainer's rebuild
decision), `contracts.md`, `rfc_cycle.md` ("Pre-CRAN Compatibility Policy"),
`tests/claims.yml`, and the cited code at `164e15ba`.
**Settled before this synthesis and not reopened:** the direction (no
backward compatibility before the first CRAN release) and the lake-rebuild
decision (rebuilt after every store-format change; first rebuild right after
the removal cut, under rule 3, without dividends).

This RFC uses "v1" only for ledgr's own v0.1.x releases, never ledgr 1.0.

## 1. Decision

- **D1. One opener, one gate.** `ledgr_store_open(path, mode)` is the only
  way package code obtains a connection to a store file. `mode = "open"`
  refuses any store whose marker is not current; `mode = "create"` also
  accepts an empty file and writes the current schema in one transaction
  with the marker last. The split-store `ATTACH` reads the attached file's
  marker before any view exists. Every per-call-site schema check is
  deleted.
- **D2. The marker is a pair.** Store version 119 plus a format
  fingerprint: the canonical JSON of every persisted format constant,
  written at creation and compared at open. The fingerprint turns the
  "every record in an open store is current" premise into a mechanism, and
  a namespace-enumerating test keeps it complete.
- **D3. Record-level legacy branches are deleted, not converted.** Identity
  rule 1, policy schema 1, saved sweeps 1 to 3, provenance markers,
  stored-config timing and risk inference, legacy snapshot markers. Where a
  record carries a version field, one equality assertion stays as a
  corruption check against the current constant.
- **D4. One schema definition.** `R/db-schema-current.R` holds every table
  and index. The legacy path, the migrate pass, the lazy `ensure_*`
  helpers, the LDG-3016 template, the hand validator and the saved-sweep
  column list are deleted.
- **D5. Validation compares catalogues**, strictly, against a reference
  built from the current DDL on the running DuckDB, using the LDG-3018
  normalizer. An extra column is a difference.
- **D6. Rule 2 is required.** A config without `identity_rule_version` and
  `data.snapshot_hash` is refused by hashing and validation; hand-built
  configs carry both.
- **D7. Three current behaviours stay:** row absence in run readers,
  construction-time `risk_chain` normalisation, version-2 timing
  validation. Trigger probing is deleted as dead current code, under its
  own sentence, not as compatibility.
- **D8. One condition**, `ledgr_store_rebuild_required`, parent
  `ledgr_invalid_store`, with a `cause` field. No new export for diagnosis.
- **D9. Old call forms go:** the `fill_model`, `spread_bps` and
  `commission_fixed` refusal arguments and classes, `as_tibble(type =)`,
  retention v1 normalisation, the metric-kernel fallback.
- **D10. Scope boundary:** no schema redesign, no removal of
  `ledgr_backtest()` or `function(params)` factories, no change to any
  output of a current store.

## 2. Bound Architecture

### 2.1 The opener

Today four opener primitives exist: `ledgr_open_duckdb_with_retry()`
(`R/public-api.R:10`), `ledgr_db_init()` (`:96-109`, creates or migrates),
`ledgr_run_store_open()` (`R/run-store.R:16`) and a raw `dbConnect()`
(`R/snapshot_adapters.R:275`). About twenty `check_schema` or
`create_schema` calls in nine files guard some sites, and four sites read
ledgr tables with no check: the snapshot locator (`R/snapshot.R:82`), the
backtest handle (`R/backtest-handle.R:107`, `:157`, `:225`), and two result
readers (`R/backtest-results.R:1073`, `R/availability-results.R:295`).

Bound: `ledgr_store_open(path, mode)` wraps the retry open and runs the
gate. `"open"` reads `ledgr_schema_metadata` and refuses unless the version
and fingerprint both match the running package. `"create"` additionally
accepts a file whose `main` schema holds no table (`ledgr_schema_catalogue()`,
as `R/db-schema-create.R:26-33` decides today) and runs
`ledgr_schema_create_fresh()` (`:531-543`, one transaction, marker last).
`ledgr_db_init()` keeps its name and becomes `"create"`; the run store in
split mode is created on first use through it (`R/backtest-config.R:107-115`).
`ledgr_create_schema()` called on an opened store (`R/backtest-runner.R:734`,
`R/promotion-context.R:67`) becomes a gate call. `ledgr_run_store_open()`
becomes `"open"`. The snapshot locator and the handle call `"open"`. The
split-store source (`R/snapshot-source.R:48-71`) reads
`ledgr_snapshot_src.ledgr_schema_metadata` and applies the same gate before
creating views.

### 2.2 The marker

`ledgr_schema_metadata` holds two keys: `experiment_store_schema_version`
(raised to 119) and `format_fingerprint`. The fingerprint is
`canonical_json()` of a named list of every binding in the package
namespace that matches `^ledgr_[a-z_]+_(schema|rule)_version$` and is a
length-one atomic value. At `164e15ba` that is exactly these 18:
`ledgr_business_objective_schema_version`,
`ledgr_corporate_action_policy_schema_version`,
`ledgr_cost_schema_version`, `ledgr_experiment_store_schema_version`,
`ledgr_fact_schema_version`, `ledgr_fold_list_schema_version`,
`ledgr_fold_schema_version`, `ledgr_identity_rule_version`,
`ledgr_objective_criterion_schema_version`, `ledgr_risk_schema_version`,
`ledgr_saved_sweep_schema_version`, `ledgr_selection_rule_schema_version`,
`ledgr_sweep_filter_schema_version`, `ledgr_sweep_retention_schema_version`,
`ledgr_timing_schema_version`, `ledgr_valuation_policy_schema_version`,
`ledgr_walk_forward_candidate_schema_version` and
`ledgr_walk_forward_schema_version`. The two functions the pattern also
matches (`ledgr_snapshot_hash_rule_version()`,
`ledgr_sweep_assert_parent_schema_version()`) are excluded by the atomic
test. The store version is in the list and also the marker's own key; the
redundancy is harmless and keeps the rule free of exceptions. Plus two
named entries the cut
introduces as constants: the execution-timing version (today the literal 2
at `R/execution-timing.R:51-52`) and the current snapshot hash rule that
Cut 13 LDG-3019 defines. Provenance versions that readers already compare
per row (`ledgr_feature_engine_version()`,
`ledgr_availability_provider_version()`, `ledgr_promotion_context_version`)
are not formats and stay out.

Guard: one test enumerates the namespace by that pattern and fails if a
matching atomic binding is absent from the fingerprint list or the list
names a binding that no longer exists. A format bump therefore cannot land
without changing the fingerprint, and a changed fingerprint refuses every
existing store. That is the policy, made mechanical.

### 2.3 The condition

`ledgr_store_rebuild_required`, classes
`c("ledgr_store_rebuild_required", "ledgr_invalid_store")` (the parent
already exists, `R/sweep-persistence.R:345`). Fields: `cause` in
`older`, `newer`, `missing_marker`, `invalid_marker`,
`fingerprint_mismatch`; `recorded_version`; `recorded_fingerprint` and the
names of differing constants when applicable; `path`. The message names
the rebuild route. `ledgr_future_schema_version`
(`R/experiment-store-schema.R:566-579`) folds into it. Rejected: an
exported `ledgr_store_version()` probe (response G4); the condition
carries everything it would print, and one message does not earn a public
surface.

### 2.4 Record-level branches

After D1 and D2, every record in an open store was written by the running
package's formats. Deleted as unreachable, with the equality assertion that
remains:

| Branch | Code | Remaining assertion |
| --- | --- | --- |
| Identity rule 1 | `R/config-hash.R:48-52`, `:55-66`; `R/config-validate.R:355-363`; `R/run-registration.R:95-109` | `identity_rule_version == 2L` or `ledgr_invalid_config` |
| Policy schema 1 | `R/corporate-action-policy.R:107-130`, `:388-401`; `R/availability-policy.R:97-118`, `:217-226`; `R/config-validate.R:392-440` | policy schema equals the current constant |
| Saved sweeps 1 to 3 | `R/sweep-persistence.R:410-422` and branches `:332-340`, `:476-478`, `:528-532`, `:602-610`, `:654-687` | `sweep_schema_version == 4L` or `ledgr_sweep_schema_incompatible` |
| Provenance markers | `R/strategy-provenance.R:130-138`, `:160-166` and readers | none; provenance is always present |
| Stored-config inference | `ledgr_config_normalize_risk_identity()` at `R/run-store.R:1148`; `R/execution-timing.R:42-48` | timing version equals 2 |
| Legacy snapshot markers | the LDG-3019 metadata-open branch and `ledgr_snapshot_rebuild_required` | `hash_rule_version == 3L` or `ledgr_snapshot_hash_rule_unsupported` |
| Table and column probes | `R/run-store.R:74-80` and readers in about fifteen files | none; every table exists from creation |

Kept, because they are current behaviour next to legacy lines (D7): a
`RUNNING` or interrupted run has no telemetry row and readers return `NA`;
`ledgr_experiment()` turns an omitted `risk_chain` into the no-op plan;
version-2 timing validation.

### 2.5 Schema definition and validation

`R/db-schema-current.R` holds the DDL for the 11 core tables
(`R/db-schema-create.R`), the 14 tables and indexes now created in the
migrate and ensure paths (`R/experiment-store-schema.R`) and the 8
availability tables with their indexes (`R/availability-schema.R`). Every
table exists from creation; no path creates a table later.

`ledgr_validate_schema()` builds a reference catalogue from that DDL on
`:memory:` once per session, reads the store's catalogue through
`information_schema` and `duckdb_constraints()`, normalizes both with the
LDG-3018 code (`R/db-schema-validate.R:785-825`), and reports differences by
table, column, constraint and index. Both sides are rendered by the running
DuckDB, so an engine upgrade moves them together; a create, close, reopen,
compare witness covers the storage-format case. The hand validator
(`R/db-schema-validate.R:14-779`) and `ledgr_sweep_assert_schema_compatible()`
(`R/sweep-persistence.R:311-330`) are deleted; their semantic checks are CHECK
constraints in the DDL. `ledgr_validate_schema_once()` (`:794-806`) stays in
front as cost control.

### 2.6 Rule 2 required

Rule 2 needs `data.snapshot_hash` (`R/config-validate.R:360-363`), so a
config cannot be "given" the field. `config_hash_payload()` refuses a
config without `identity_rule_version`, validation requires both fields,
`ledgr_config()` already sets them (`R/backtest-config.R:180`), and the ten
test files that call `ledgr_run_config()` with hand-built lists, plus any
`dev/bench` harness, carry both. This is the one change the fixture ladder
cannot see, so its census is a gate.

## 3. Where v2 And The Response Differed

| Point | v2 | Response | Bound | Reason |
| --- | --- | --- | --- | --- |
| Diagnostic probe of an old store | condition fields only | exported `ledgr_store_version()` | v2 | one message does not earn a public surface |
| Sequencing against the lake | rebuild after every format change, first rebuild right after the cut | move the cut after the rebuild, or one interim rebuild | maintainer decision | moving the cut cannot avoid a second rebuild once no format is compatible |
| Fingerprint membership | 18 constants plus timing and hash rule | fingerprint of "every persisted format constant" | v2, with the pattern-and-atomic rule and the provenance exclusions of 2.2 | the response named no enumeration rule |
| Trigger probing | deleted under its own reason | misfiled as legacy | both agree | dead on DuckDB 1.5.6.9000 (`R/db-schema-create.R:544-569`), not compatibility |

## 4. Rejected, One Line Each

- Refuse at each artifact (seed v1 Section 4): keeps one version check per
  type alive, which is the weight being removed.
- A v0.2.1.0 floor: keeps the 117 to 118 rebuild, rule 1 and schema-1
  policies; contradicts the decision.
- Read-only tolerance for diagnosis: the tolerant readers reborn; the
  condition carries the diagnosis instead.
- Keep the hand validator and consolidate only the DDL: two descriptions of
  one schema kept in step by hand.
- A single-integer epoch without a fingerprint: a policy the code cannot
  enforce (response G2).
- `ledgr_store_version()` export: see 2.3.
- Migrating old roots or stores in place: blurs two content contracts.
- Any change to `ledgr_backtest()`, the factories, or a current store's
  output: out of scope by the maintainer's decision.

## 5. Contract Changes Authorized By Acceptance

Applied at ticket cut, in `contracts.md`:

- Execution Contract: delete the `fill_model` / `spread_bps` /
  `commission_fixed` refusal sentence (line 260); replace the saved-sweep
  "additive schema migration" and "v0.1.9.2 saved sweep reopens" sentences
  (`:288-291`) with "saved sweeps carry schema 4; any other value refuses";
  replace the identity-rule-1 sentences (`:316-321`) with "every config and
  session carries identity rule 2; a config without it is refused"; keep
  the construction-time `risk_chain` sentence.
- Config Contract: delete the legacy `ledgr_validate_config()` reference
  (`:411`).
- Snapshot Contract: replace the Cut 13 legacy-marker sentence (`:451-456`,
  "metadata-only reads may open it") with "a snapshot row whose
  `hash_rule_version` is not 3 is corruption, not legacy"; keep the
  unrecognized-marker refusal.
- Availability Contract: delete the `availability_close_v1` inference and
  "Legacy or unknown active configs" (`:670-672`); timing version 2 is the
  only accepted value.
- Persistence Contract: the schema 113, 114 and 115 sentences (`:834-839`,
  `:886`) become release history, not rules; delete "except for deliberate
  schema migration or DDL" (`:829`); split line 939 so missing telemetry
  rows stay `NA` and "tolerate legacy/pre-provenance stores" goes; add one
  clause: one opener, one gate (version and fingerprint), one schema
  definition, catalogue-comparison validation, no migration before the
  first CRAN release.
- Strategy Contract: delete the legacy-signature sentence (`:1250`) and the
  legacy-metadata tolerance (`:1314`).
- Verification Contract: add the fingerprint-enumeration test and the
  opener census as standing requirements.

Elsewhere, in the same cut: the WS5-A synthesis Section 3.5 and gate 8
(legacy snapshots metadata-readable; legacy runs readable through
durable-result-only surfaces) are amended to "unreachable after the store
gate"; `vignettes/sweeps.qmd:521-522` loses its migration sentence;
`R/condition-reference.R` drops `ledgr_legacy_fill_model_shape`,
`ledgr_legacy_config_shape` and `ledgr_execution_timing_version_mismatch`
and adds `ledgr_store_rebuild_required`, with the `@aliases` updated so
`R CMD check` passes; NEWS records the reset and the rebuild instruction.

## 6. Removal Cut Shape And Gates

Two workstreams, each with one claim and one Type 1 close review, in this
order:

**Workstream A, one schema and one gate.** (1) Write
`R/db-schema-current.R` and prove its catalogue equals the legacy-built
catalogue; this is the legacy path's last use and the first commit's oracle.
(2) Add `ledgr_store_open()`, the marker pair, the condition and the
`ATTACH` check; raise the version to 119; route every opener. (3) Delete the
legacy path, migrate pass, rebuilds, `ensure_*`, the template, trigger
probing and the per-site checks. (4) Replace the hand validator and the
sweep column list with the catalogue comparison.

**Workstream B, no version branch remains.** (5) Delete the record-level
branches and probes of 2.4, keep the three behaviours of D7, make rule 2
required and fix the hand-built configs. (6) Remove the old call forms;
apply Section 5 to the contracts, the WS5-A synthesis, the article, the
condition reference and NEWS. (7) Run the scripted lake rebuild in
ledgr-research under rule 3 without dividends and record its time.

Gates the ticket cut retains:

1. **Byte identity.** The registered fixture ladder
   (`dev/bench/v0_2_2_real_data_scale/ladder.sh`) reports every row
   identical to its predecessor commit at each code step; stores are built
   per tree, so the ladder spans the version bump.
2. **Opener census.** Every `dbConnect`, `ledgr_open_duckdb_with_retry`,
   `ledgr_db_init`, `ledgr_run_store_open` and `ATTACH` site in `R/` routes
   through `ledgr_store_open()`; a remaining raw open fails the review.
3. **Gate witnesses.** Each cause refuses with its `cause` field: a 118
   store; ledgr tables with no marker; a newer marker; an invalid marker; a
   changed constant; a 118 snapshot file attached under a 119 run store. An
   empty file receives the current schema; an interrupted creation leaves no
   table and no marker.
4. **Fingerprint enumeration.** A matching atomic namespace binding missing
   from the list, or a listed name that no longer exists, fails.
5. **Catalogue witnesses.** A dropped column, a weakened CHECK, an extra
   column, a missing table and a missing index are each reported by name;
   create, close, reopen compares equal.
6. **Branch census.** Every persisted version field is listed with its
   single equality assertion; a remaining version branch fails the review.
7. **Config census.** Every `ledgr_run_config()` caller in `tests/` and
   `dev/bench` carries `identity_rule_version` and `data.snapshot_hash`.
8. **Claims.** Retire LCL-0028 (LTB-0033) and LCL-0160 (LTB-0160), whose
   whole scope is schema-1 readability. Rewrite, dropping only the schema-1
   clause and keeping the current-behaviour coverage: LCL-0158 (LTB-0158,
   schema-2 policy identity) and LCL-0159 (LTB-0159, the valuation
   `freeze`/`refuse` choice in identity). Rewrite without their migration
   or trigger arms, keeping seal, replay, the no-selection record and
   rule-2 identity: LCL-0026 (LTB-0028), LCL-0039 (LTB-0050), LCL-0200
   (LTB-0200), LCL-0242 (LTB-0244), LCL-0034 (LTB-0039 to LTB-0041, the
   catalogue-once claim) and LCL-0237 (LTB-0239, which carries the trigger
   and legacy-migration arms). LCL-0234 drops rule 1; LCL-0128's expected
   hit count follows the article text; the nine unregistered blocks in
   `test-experiment-store-schema.R` go with the code.
9. **Cost.** Paired clocks on store open, `ledgr_db_init()` and
   `ledgr_snapshot_from_df()` show no regression; the fast and review
   profiles and the full suite pass; the lake rebuild time is recorded.
10. **Docs.** `R CMD check` passes with the condition-reference aliases
    updated; the documentation-contract tests pass.

## 7. Failure Scenarios

| Scenario | Bound behaviour | Failure of this design |
| --- | --- | --- |
| A 118 store opened read-only for listing | refuses, cause `older` | a tolerant reader survives |
| A 118 snapshot attached under a 119 run store | refuses at `ATTACH` | views are created over an ungated file |
| A later format bump without a store bump | fingerprint test fails before merge | a record branch becomes necessary again |
| A newer ledgr's store under this build | refuses, cause `newer` or `fingerprint_mismatch` | misreported as corruption |
| Interrupted creation | no table, no marker; next open creates | a half store opens |
| A hand-built config without rule 2 | refused by `config_hash_payload()` | a rule-1 hash is silently produced |
| A `RUNNING` run with no telemetry row | `NA` as today | row absence treated as legacy and refused |
| DuckDB upgrade | both catalogues re-rendered by the new engine; round-trip witness | a current store compares as damaged |
| Private lake after the cut | locked out until the scripted rebuild, by decision | a tolerant path is added for it |

## 8. Open Questions Promoted To Spec-Cut

- Exact field names and message text of `ledgr_store_rebuild_required`.
- The canonical form of the fingerprint (key order is canonical JSON; the
  value type of `"v1"` strings versus integers is as stored).
- Whether `ledgr_db_init()` is documented as create-or-open-current or
  split into two exported names; this synthesis keeps the name.
- The two named constants for timing and the current hash rule, which Cut
  13 may define first; and Workstream A's grain if it outgrows one review.

## 9. Future Obligations Recorded

- **CRAN compatibility policy.** Before the first CRAN release, define the
  compatibility and deprecation policy that `rfc_cycle.md` promises; the
  gate and fingerprint are its enforcement point.
- **Execution-core consolidation** (roadmap row, parked): inherits one
  opener and one gate; it must not add a second.

## 10. Acceptance Routing

On maintainer acceptance: set the pipeline row `pre-cran-legacy-removal` to
`Obligations open`, latest artifact this synthesis, next action the removal
cut after Cut 13; add a decisions-bridge row pointing at Sections 1, 2, 5
and 6; at ticket cut, remove the obligation from the pipeline, apply
Section 5 and amend the WS5-A synthesis. The macro plan amendment already
carries the rebuild decision and order. No horizon entry.

## 11. Final Review Boundary

Final review is Type 1: every line number in Sections 2 and 5 resolves at
`164e15ba`; the fingerprint rule in 2.2 enumerates exactly the 18 constants
plus the two named entries; D7's kept behaviours are current code; no gate
passes without a witness that fails on the pre-cut tree. A design finding
routes to `NEEDS_TYPE_2`.

## Revision History

- 2026-10-12 - Initial synthesis after seed v2 and the response review.
- 2026-10-12 - Final-review patches (PASS_AFTER_PATCHES): LCL-0158 and
  LCL-0159 are rewritten, not retired, because their scope is current
  schema-2 identity; LCL-0034 is attached to its own blocks LTB-0039 to
  LTB-0041 and the trigger arm to LCL-0237; the 18 fingerprint constants
  are listed by name; one missing blank line restored.

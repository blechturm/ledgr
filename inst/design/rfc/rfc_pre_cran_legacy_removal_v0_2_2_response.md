# RFC Response: Pre-CRAN Legacy Removal for v0.2.2

- Status: Type 2 response to seed v1, non-binding
- Author: Claude (Fable 5.1); not the seed's author session
- Date: 2026-10-12
- Mode: Type 2 on the replacement mechanisms only. The direction (no backward
  compatibility before CRAN) is decided and is not argued here.
- Baseline read: `a2464434`; code citations checked at that commit
- Brief: maintainer-supplied

## 1. Answer

The removal is sound and the inventory is close to complete. Four of the
seed's mechanisms need revision before synthesis, one of them a sequencing
conflict with an amendment accepted the same day:

1. The gate has no chokepoint. Four opener sites run no schema check today
   and the split-store `ATTACH` never reads the attached store's marker, so
   "read and write paths share the gate" is a sentence, not a place (G1).
2. The epoch premise is a policy the code does not enforce. The store marker
   is one integer; record formats carry eight independent constants. Deleting
   every version branch is safe only if the gate compares all of them (G2).
3. The removal cut lands before the Sharadar lake rebuild, which makes the
   only real-data lane unopenable through the WS3/WS4 implementation cut,
   or forces the lake to be rebuilt twice against the "rebuilt once" routing
   accepted for Cut 13 (F1).
4. Three items are misfiled; five registered claims, one vignette passage
   and one hand-written column check are missing from the inventory
   (Section 6).

The single schema definition and the strict catalogue comparison survive;
the DuckDB rendering risk is smaller than the seed states (V1).

## 2. The Gate

**G1. Name the chokepoint, or the gate becomes the tolerant-reader pattern
it deletes.** Store opens happen through `ledgr_open_duckdb_with_retry()`
(`R/public-api.R:10`), `ledgr_db_init()` (`:96-109`, which creates or
migrates), `ledgr_run_store_open()` (`R/run-store.R:16`) and raw
`dbConnect()` in the adapter (`R/snapshot_adapters.R:275`). The schema check
is then applied per call site: 21 `ledgr_experiment_store_check_schema()` or
`ledgr_create_schema()` calls across nine files. Sites that open and read
ledgr tables with no check at all: the snapshot locator
(`R/snapshot.R:82`, behind every `ledgr_snapshot_info()`, `ledgr_experiment()`
and inspection read), the backtest handle (`R/backtest-handle.R:107`, `:157`,
`:225`), result readers (`R/backtest-results.R:1073`,
`R/availability-results.R:295`) and the split-store source, which attaches a
second file read-only and creates views over it without reading its
`ledgr_schema_metadata` (`R/snapshot-source.R:48-71`). A 118 snapshot store
attached under a 119 run store would pass the seed's gate.

Smallest correction: one function, `ledgr_store_open(path, mode)`, is the
only way package code obtains a connection to a store file. `mode = "create"`
accepts an empty file and runs the current definition; `mode = "open"`
refuses anything whose marker is not current. `ledgr_create_schema()` on an
opened store (`R/backtest-runner.R:734`, `R/promotion-context.R:67`) becomes
a gate call, with the empty-file case retained because a split-mode run
store is created on first use (`R/backtest-config.R:107-115`). The `ATTACH`
path reads `ledgr_snapshot_src.ledgr_schema_metadata` before any view exists.
Every other `check_schema` call is then deleted, which is the point.

**G2. One integer does not mark a content epoch.** The seed's unreachability
argument (Section 3.2) is: a pre-119 store never opens, so every record in
an open store was written under current rules. That holds only while every
change to a persisted record format bumps the store version. The formats
have their own constants: saved sweep 4 (`R/experiment-store-schema.R:2`),
identity rule 2 (`R/config-hash.R:46`), corporate-action and valuation
policy 2 (`R/corporate-action-policy.R:60`, `R/availability-policy.R:88`),
fact schema 1, retention 2, walk-forward, fold, candidate and selection-rule
`"v1"`, cost, timing, risk and filter 1. Nothing ties them to the marker.
The seed itself keeps "one equality assertion" per field and classes a
mismatch as corruption; a record written by a later ledgr with saved-sweep
schema 5 under an unbumped store 119 is not corruption, it is the skew the
gate exists to catch, and it would be misreported.

Smallest correction: the marker is the pair (store version, format
fingerprint), where the fingerprint is the canonical JSON of every persisted
format constant, written to `ledgr_schema_metadata` at creation and compared
at open. A mismatch refuses with the same gate condition and names the
differing constant. A test asserts the fingerprint changes whenever any
constant changes, so a format bump cannot land without a store bump. The
per-record equality assertions then stay as cheap corruption checks and the
"epoch" claim becomes mechanical.

**G3. One condition, four causes.** `ledgr_future_schema_version`
(`R/experiment-store-schema.R:566-579`) already exists for a newer marker.
Retire it into the one gate class with a `cause` field (older, missing with
tables, invalid, newer, fingerprint) so tests assert the cause, not the
message.

**G4. Diagnostic reads (seed Q3).** Rejecting tolerant content reads is
right. A metadata probe is not a tolerant reader: the gate must read the
marker to name it in the refusal, so exposing that one read as
`ledgr_store_version(path)` costs nothing and lets a user see why a file
refuses without a second code path. No table other than
`ledgr_schema_metadata` is touched.

## 3. Deleting Record-Level Branches

**R1. Table tolerance and row tolerance are two different things.**
`R/run-store.R:74-80` (`ledgr_run_store_has_col`, table and column existence
probes) is legacy and goes. "Treat missing telemetry as `NA`" is not: a
`RUNNING` or interrupted run has no telemetry row today, and the Persistence
Contract line 939 bundles both. The cut must delete the existence probes and
keep the row-absence handling, and the contract sentence must be split.

**R2. Read-side inference and construction-time normalization share a
name.** `ledgr_config_normalize_risk_identity()`
(`R/config-validate.R:452-459`) fills a missing `risk_chain` on a stored
config at reopen (`R/run-store.R:1148`); unreachable after the gate, delete.
The Execution Contract's "omitted `risk_chain` normalizes to the no-op plan
for new configs" is construction-time behavior in `ledgr_experiment()` and
stays. The seed's "configs without `risk_chain`" item should name the reader
function only. The same split applies to timing inference
(`R/execution-timing.R:42-48`, `legacy_config_inference`): delete the
inference branch, keep version-2 validation.

**R3. Unconditional rule 2 is a validation change, not a default.** Rule 2
requires `data.snapshot_hash` (`R/config-validate.R:360-363`). `ledgr_config()`
sets both (`R/backtest-config.R:180`); only hand-built lists passed to
`ledgr_run_config()` omit them, which is what `R/run-registration.R:102-103`
means by low-level configs. "Internal builders that omit the field get it
set" cannot work, because setting the field without the hash fails
validation. The honest rule: `config_hash_payload()` refuses a config without
`identity_rule_version`, and every hand-built config in tests and bench
harnesses carries both fields. That is a census of `ledgr_run_config()`
callers, and it is the one place the fixture ladder cannot see.

## 4. Single Schema Definition

**S1. Count the descriptions correctly: there are four, not three.** DDL
literals (11 in `R/db-schema-create.R`, 14 in the migrate and ensure paths
of `R/experiment-store-schema.R`, 8 in `R/availability-schema.R`); the
hand validator (`R/db-schema-validate.R:14-779`); the LDG-3016 template built
by replaying the legacy path (`R/db-schema-create.R:498-514`); and
`ledgr_sweep_assert_schema_compatible()` (`R/sweep-persistence.R:311-330`), a
required-columns list the seed does not mention. All four go, or the
"single definition" is three.

**S2. The fresh-store transaction already exists.**
`ledgr_schema_create_fresh()` (`R/db-schema-create.R:531-543`) runs the
statements and writes the marker
last in one transaction. The new `R/db-schema-current.R` replaces its
statement source; nothing else about creation changes. The seed's step 1
oracle (new definition's catalogue equals the legacy-built catalogue) is the
right first commit and should be the last use of the legacy path, as the
seed says.

## 5. Catalogue-Comparison Validation

**V1. The rendering risk is smaller than the seed states.** Both sides of
the comparison are rendered by the running DuckDB: the reference is built
in `:memory:` from the current DDL each session, and the store's catalogue
is read through `duckdb_constraints()` and `information_schema` by the same
engine. A DuckDB upgrade changes both renderings together. The residual risk
is a storage-format upgrade that rewrites stored constraint text, and the
existing code already fails closed when constraint text is uninterpretable
(`R/db-schema-create.R:124-125`, "fail review rather than adding write
probes"). Go strict, reuse the LDG-3018 normalizer and fingerprint
(`R/db-schema-validate.R:785-825`), and add one witness: create, close,
reopen, compare equal. Delete the hand validator; its semantic checks (status
enums, event types) are CHECK constraints in the DDL and the comparison
covers them.

**V2. Keep `ledgr_validate_schema_once()`.** The per-session key
(`R/db-schema-validate.R:794-806`) is cost control, not tolerance; it stays
in front of the comparison.

## 6. Inventory: Missed and Misfiled

| Item | Seed status | Finding |
| --- | --- | --- |
| Trigger probing (`R/db-schema-create.R:544-569`) | dead code, listed under legacy | Misfiled: shipped by Cut 12 LDG-3016 on 2026-10-12 as best-effort immutability; it is dead on the current DuckDB, not compatibility. Delete it under its own sentence and rewrite the LDG-3016 claim (LCL-0034, block LTB-0239) |
| `ledgr_sweep_assert_schema_compatible()` | absent | A fourth hand description of the schema (S1) |
| Row-absence tolerance in `ledgr_run_list()` / `ledgr_run_info()` | bundled with table tolerance | Current behavior; keep (R1) |
| Construction-time `risk_chain` normalization | bundled with read inference | Current behavior; keep (R2) |
| LCL-0028 / LTB-0033 "legacy runs do not acquire a policy on reopen" (`tests/testthat/test-corporate-action-policy.R:243`) | absent from the claims list | Unreachable after the gate; retire with LCL-0158 to LCL-0160 |
| LTB-0028 "corporate-action rows migrate, seal, and move identity", LTB-0050 "DISPOSITION is prepared, migrated and replays", LTB-0200 "the schema 118 migration", LTB-0244 "fork from a rule-1 session" | only their claims LCL-0026 and LCL-0039 are listed | Each block embeds a migration witness; the rewrite must keep the non-migration half (seal, replay, no-selection record, rule-2 identity) and drop the migration arm |
| LCL-0128 documentation scan | absent | Its recorded hit count names "legacy and pre-provenance in Reproducibility"; the article text and the expected count change |
| `vignettes/sweeps.qmd:521-522` ("Opening an older store may perform an additive saved-sweep schema migration") | absent (seed lists contracts and NEWS) | Executed article prose; it promises the migration being removed |
| `R/condition-reference.R:8-14`, `:82` and its aliases | implied by "condition classes" | The documented classes `ledgr_legacy_fill_model_shape`, `ledgr_legacy_config_shape` and `ledgr_execution_timing_version_mismatch` need the man page and aliases edited, or `R CMD check` fails on the orphaned `@aliases` |
| `ledgr_future_schema_version` | absent | Folds into the one gate class (G3) |
| Persistence Contract version-history sentences (schema 113, 114, 115) | 113 and 115 listed | 114 ("adds `run_completion` and `run_diagnostics`") is the same kind of sentence; all three become history, not rules |
| `ledgr_backtest()`, `function(params)` factories, `as_tibble(type =)` | out of scope / listed | Correctly filed: the first two are current surfaces; `type` is documented "Deprecated alias" (`R/backtest-results.R:1169`) and goes |
| Metric-kernel fallback, retention v1 | listed | Confirmed dead: all three callers pass a resolved context (`R/backtest-results.R:249`, `R/run-store.R:744`, `R/sweep.R:313`); retention v1 is reachable only from a serialized old object |

Nothing persisted lives outside the store except user-serialized R objects
and CSV exports (seed Q1). The in-memory equality assertions on versioned
objects (policy, retention) are the gate for those, and the pre-CRAN policy
covers them. No change needed.

## 7. What Would Make the Removal Cut Fail

**F1. Sequencing against the Sharadar lane.** The accepted order is Cut 13,
the removal cut, the WS3/WS4 history wave and implementation cut, the lake
rebuild under rule 3 with dividend facts, WS7 (macro plan, 2026-10-12
amendment). After the removal cut, the private Sharadar store at schema 118
cannot be opened by any ledgr path. The WS3/WS4 implementation reviews use
that store as the second lane ("byte-identical on the fixture and Sharadar
lanes", Cut 12 closeout), and `dev/bench/v0_2_2_sharadar_run/stage.R` opens
it directly. Either the lake is rebuilt immediately after the removal cut,
which contradicts the Cut 13 amendment's "rebuilt once ... together with the
dividend-facts adapter change", or the removal cut moves after the rebuild.
The seed's Section 6 ("the rule-3 rebuild is already scheduled after
WS3/WS4") treats this as solved; it is the opposite. Recommendation: either
place the removal cut after the lake rebuild, which also means the history
cut meets legacy shapes once more, or accept a cheap interim rebuild of the
lake under rule 3 without dividends right after the removal cut, and say so
in the amendment.

**F2. Over-deletion of current behavior.** R1, R2 and R3 are the three
places where a legacy label covers a current rule.

**F3. A missed opener.** G1's list is from one grep; the cut's census must
be the `dbConnect`, `ledgr_open_duckdb_with_retry`, `ledgr_db_init` and
`ledgr_run_store_open` call sites, plus `ATTACH`, with each shown routed
through the chokepoint. A site left on a raw open is the tolerant-reader
pattern reborn.

**F4. Hand-built configs.** Every `ledgr_run_config()` caller in tests and
`dev/bench` that builds a config list by hand fails the moment rule 2 is
unconditional (R3). The fixture ladder runs public paths and cannot see it.

**F5. Claims and docs.** The retired and rewritten claims in Section 6, the
orphaned condition aliases, the sweeps article passage and the LCL-0128
expected count. Any one of these fails the review or `R CMD check`.

**F6. Cut 13 overlap (seed Q4).** Let LDG-3019 implement the accepted
synthesis, including the metadata-readable legacy snapshot and its
`ledgr_snapshot_rebuild_required` refusal. After the gate, a 119 store can
hold only rule-3 snapshots, so that branch and its tests are deleted by the
removal cut's census, and the synthesis clause is amended as the seed says.
Shrinking LDG-3019 now would reopen an accepted cut for a few test blocks.

## 8. Answers to the Seed's Section 8

1. The store is the right epoch for every persisted artifact, once the
   marker carries the format fingerprint (G2). Nothing durable lives outside
   it except user-serialized objects, already covered.
2. Strict catalogue comparison, with the LDG-3018 normalizer and one
   round-trip witness; the rendering risk is renderer-consistent (V1).
3. No diagnostic content read. One metadata probe that the gate uses
   anyway (G4).
4. Implement the accepted synthesis in Cut 13; delete in the removal cut
   (F6).
5. Misfiled: trigger probing, row-absence tolerance, construction-time risk
   normalization. Missing: the sweep-persistence column check, LCL-0028,
   four migration-witness blocks, LCL-0128, the sweeps article passage, the
   condition-reference aliases, the schema-114 sentence (Section 6).

## 9. What Survives, What Changes, Disposition

Survives: refusal at the store rather than per artifact; deletion rather
than refusal conversion for record branches; one DDL file; strict catalogue
comparison; deletion of old call forms; rule 2 unconditional; the cut order
in Section 6 with the legacy path as the first commit's oracle.

Revise: the gate's chokepoint and the `ATTACH` path (G1); the format
fingerprint in the marker (G2); the one gate class with causes (G3); the
metadata probe (G4); the three keep-lines (R1 to R3); the fourth schema
description (S1); the inventory additions (Section 6); and the sequencing
against the lake rebuild (F1), which needs a maintainer line in the macro
plan amendment either way.

No spike is needed; every claim here is a code citation.

TYPE_2_DISPOSITION: REVISE_SEED

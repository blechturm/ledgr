# Workstream 36: feature-retention removal and capture identity

## Outcome and necessity

Workstream 36 is complete for implementation and ready for its required Type 1
close review. The smallest valid change was deletion, not repair. The accepted
feature-keeping probe observed that the process-local cache could return stale
values after a captured dependency changed, retained about 67.7 MB at the
1,166-by-7,213 shape, and did not help the measured repeated walk-forward. The
durable path wrote 40,000 rows, had no named public consumer, and did not improve
the measured fixture. A manifest, replacement cache, migration, compatibility
parser, or generic retention layer would preserve machinery without making the
next research result more valid.

The implementation therefore deletes both retention mechanisms, computes each
run's features once through the existing production engine, and binds direct
deterministic captures in the surviving feature identities. ledgr continues to
own run/configuration identity, snapshot integrity, execution, accounting,
result persistence, and reopening; no research-side duplicate of those
guarantees was added.

## Implementation record

### LDG-3049

- Deleted `R/feature-cache.R`, the process registry, cache key/get/set/clear
  functions, the `ledgr_feature_cache_clear()` export and help, cache branches,
  cache telemetry, and cache-only teaching and tests. There is no alias,
  deprecation wrapper, environment registry, or replacement cache.
- Moved `ledgr_feature_engine_version()`,
  `ledgr_active_feature_fingerprint()`, and
  `ledgr_feature_def_fingerprint()` to `R/features-engine.R`. Their engine
  inputs and the dense engine digest remain unchanged; LTB-0105 still proves
  that the two scalar helpers enter engine provenance.
- The captured-value witness in `test-feature-retention-removal.R` produces the
  changed value on the second run and reproduces exact config, fills, and
  equity when the same capture is repeated.

### LDG-3050

- Removed `persist_features` from public formals, experiment/config objects,
  identity, telemetry, internal carriers, examples, and result printing. An
  old call is now an ordinary unused-argument error.
- Removed feature-row buffering, writes, resume/finalize handling, and the
  `features` table. Durable stores contain no feature rows because schema 120
  has no feature relation at all.
- Made experiment-store schema 120 and identity rule 3 the only current
  representations. Schema 119 refuses with
  `ledgr_store_rebuild_required(cause = "older")`; a rule-2 config refuses with
  `ledgr_invalid_config`. No migration, fallback, legacy reader, or ignored
  argument exists.

The exact current format fingerprint is:

```text
{"ledgr_availability_execution_timing_rule_version":2,"ledgr_business_objective_schema_version":1,"ledgr_canonical_json_rule_version":1,"ledgr_corporate_action_policy_schema_version":2,"ledgr_cost_schema_version":1,"ledgr_experiment_store_schema_version":120,"ledgr_fact_schema_version":1,"ledgr_fold_list_schema_version":"v1","ledgr_fold_schema_version":"v1","ledgr_identity_rule_version":3,"ledgr_objective_criterion_schema_version":1,"ledgr_risk_schema_version":1,"ledgr_saved_sweep_schema_version":4,"ledgr_selection_rule_schema_version":"v1","ledgr_snapshot_content_hash_rule_version":3,"ledgr_sweep_filter_schema_version":1,"ledgr_sweep_retention_schema_version":2,"ledgr_timing_schema_version":1,"ledgr_universe_rule_schema_version":1,"ledgr_valuation_policy_schema_version":2,"ledgr_walk_forward_candidate_schema_version":"v1","ledgr_walk_forward_schema_version":"v1"}
```

### LDG-3056

- Indicator `fn` and `series_fn` fingerprints now include deterministic direct
  captures through the existing strategy-capture rules. Feature-definition,
  active-feature, feature-set, config, experiment, sweep-candidate, and
  walk-forward-session identities therefore change when a capture changes.
- Unsupported direct captures, including environments and connections, refuse
  with `ledgr_config_non_deterministic`. A captured function's own captures are
  deliberately not traversed recursively, and `ledgr_stable_payload()` is
  unchanged.
- The CSV adapter's constructor-owned private identity override represents its
  captured input with the existing `params$data_hash` and literal missing-value
  behavior. Public source or adapter labels cannot select that route, and row
  values are not serialized into the fingerprint.
- A stale precomputed sweep refuses with
  `ledgr_precomputed_feature_mismatch` before candidate execution, fills, or
  store writes. A rebuilt payload matches a fresh non-precomputed sweep.

The one-time built-in pins include SMA(20)
`722be865c97f7cc5d2aa85b95d7ceef74959da6c754d643cde2063ed5d0366a0`
and returns(5)
`d3feff6aeb660729888928583c4cf36150a66dba0053ab944783e064f090d9cb`.
The dense feature-engine digest remains
`6bd61d705a94f2cd955b5eab2a526f65e36419393de0baef4d95c64718658a76`.

## Identity and entry-point reconciliation

The intended one-time identity changes are every indicator and feature
definition fingerprint under rule 3, `features.active`, `feature_set_hash`,
`config_hash` after removal of `features.persist`, experiment identity, sweep
candidate keys, and walk-forward `session_id`. Snapshot ID/hash, snapshot
content-hash rule, strategy fingerprint, parameter identity, cost/risk/policy
identity, fill/ledger/equity bytes, and dense engine provenance remain exact
when their inputs do not change.

Focused witnesses cover run, backtest, sweep, promotion, walk-forward, resume,
reopen, and pulse snapshot in both dense and availability modes. The economic
oracles compare fills, ledger, positions, equity, metrics, strategy state, and
diagnostics after removing only the retired telemetry/config fields.

## Acceptance evidence

### LDG-3049

1. **PASS:** `test-feature-retention-removal.R` derives its deleted-name census
   from `R/`, `NAMESPACE`, public formals, and help; the moved engine functions
   and LTB-0105 preserve feature-engine provenance.
2. **PASS:** the same file's runtime capture witness changes the second run's
   feature value and repeats exact outputs; walk-forward suites pass.
3. **PASS:** the focused entry-point suites named under Verification preserve
   economic/result outputs outside the deleted telemetry fields.
4. **PASS:** the final source scan finds no cache promise or compatibility
   alias in current `NAMESPACE`, help, contracts, vignettes, examples, claims,
   or result code; NEWS records the intentional removal.
5. **PASS:** focused suites and the ordinary profile pass; the test ledger and
   verbatim seven-shape walk are below. No replacement retention or repeated
   parsing path was introduced.

### LDG-3050

1. **PASS:** `test-feature-retention-removal.R`, API/formal tests, result tests,
   and the current documentation census prove that `persist_features` is
   absent and an old call is unused.
2. **PASS:** `test-schema-current.R`, `test-schema.R`, and the schema-120 golden
   catalogue prove that neither the table nor any retired telemetry column
   exists; the source detector fails if one returns.
3. **PASS:** current-only and store-gate tests prove schema 120/fingerprint
   creation, schema-119 older refusal, exact integer identity rule 3, and
   rule-2 invalid-config refusal before use.
4. **PASS:** dense/availability and all entry-point witnesses preserve economic
   bytes; only the enumerated config/experiment/candidate/session identities
   change, while snapshot, policy, strategy, parameter, and engine identities
   stay exact.
5. **PASS:** absence of the table makes durable feature-row count structurally
   zero while the feature-keeping economic witness is exact. Package tests,
   documentation contracts, the unchanged-bound fast profile, and R CMD check
   pass as recorded below; the test ledger and seven-shape walk follow.

### LDG-3056

1. **PASS:** `test-feature-capture-identity.R` proves scalar/list change and
   repeat stability at indicator, feature-definition, active, and feature-set
   levels; intended downstream identities are enumerated above.
2. **PASS:** constructor/adapter coverage includes SMA, EMA, RSI, returns, TTR,
   TTR outputs, R, and CSV with and without missing values; CSV binds
   `data_hash`, not row values or public labels.
3. **PASS:** `test-precompute-features.R` proves stale captured precompute
   refusal before candidate execution and exact rebuilt-versus-fresh economics.
4. **PASS:** run, sweep, and walk-forward focused suites exercise capture-
   distinct current identities and repeat exactness.
5. **PASS:** atomic/list captures are accepted; environment and connection
   captures refuse with `ledgr_config_non_deterministic` before side effects.
6. **PASS:** contracts and custom-indicator teaching state direct, nonrecursive
   capture binding; failure-sensitive capture-blind and CSV-authority cases are
   in `test-feature-capture-identity.R`.
7. **PASS:** indicator, adapter, precompute, sweep, walk-forward, identity, and
   promotion suites pass; final source/catalogue scans find no cache, feature
   table, compatibility fingerprint, or stale fallback.

## Test-change ledger

The control-plane census is 1,090 blocks before and after: fast 564 to 565,
review 337 to 336, heavy 189 to 189. The immutable load-bearing block count is
267 before and after. LTB-0105 moved from the deleted cache file to the
fingerprint suite; LTB-0213 retired only its now-deleted persisted-row half.

| Changed test file or fixture | Reason |
|---|---|
| `fixtures/schema-current-golden.csv`, `fixtures/schema-current-golden-rows.csv` | Regenerate the strict schema-120 catalogue and supported DuckDB 1.5.6.9000 metadata. |
| `helper-fixtures.R` | Remove the persisted-feature fixture argument/telemetry and make schema/rule fixtures current. |
| `test-feature-cache.R` (deleted) | Delete cache-only API, key, registry, hit/miss, and reuse tests; move LTB-0105 to fingerprint coverage. |
| `test-feature-retention-removal.R` (new) | Source detector, old-call refusal, zero-durable-surface, capture-change, and repeat-exact witnesses. |
| `test-feature-capture-identity.R` (new) | Direct-capture, unsupported-capture, constructor, CSV/data-hash, and nonrecursive-function witnesses. |
| `test-fingerprint-stability.R`, `test-strict-feature-acceleration.R` | Pin the intentional rule-3 fingerprints and retain the engine-helper mutation detector. |
| `test-precompute-features.R` | Add stale-capture precompute refusal and remove retired persistence setup. |
| `test-schema-current.R`, `test-schema.R`, `test-schema-validator-side-effects.R`, `test-store-gate-contracts.R`, `test-current-only-records.R` | Pin schema 120/rule 3, deleted catalogue objects, older-store refusal, and remove the deleted table from side-effect counts. |
| `test-config.R`, `test-experiment.R`, `test-api-exports.R`, `test-backtest-wrapper.R`, `test-result-output.R`, `test-run-telemetry.R` | Remove public/config/result/telemetry persistence assumptions and assert ordinary old-call failure. |
| `test-indicators.R`, `test-indicator-adapters.R`, `test-indicator-ttr.R` | Update capture-aware pins and prove all supported constructors/adapters remain deterministic. |
| `test-acceptance-v0.1.0.R`, `test-acceptance-v0.1.1.R`, `test-active-alias-runtime.R`, `test-feature-map.R` | Remove retired persistence/cache setup while preserving feature-access and acceptance economics. |
| `test-availability-economics.R`, `test-availability-features.R`, `test-availability-fold-witnesses.R`, `test-availability-parity.R`, `test-pit-consistency.R` | Remove retention fields, bind rule-3 expected configs, and preserve availability/PIT economics. |
| `test-backtest-audit-log-equivalence.R`, `test-fifo-opening-positions.R`, `test-ledger-writer.R`, `test-metric-context-storage.R` | Remove feature-table/write expectations while retaining accounting, audit, and storage oracles. |
| `test-durable-run-preparation-memory.R`, `test-run-store.R`, `test-runner.R`, `test-runner-snapshots.R`, `test-run-continuity-ii.R` | Remove feature buffers/writes/resume fields and preserve durable preparation and continuation behavior. |
| `test-research-cycle-scale.R` | Retire the persisted-feature-row half of LTB-0213; retain exact pair-key behavior. |
| `test-risk-config.R`, `test-corporate-action-policy.R`, `test-terminal-policy-identity.R` | Update current config identity without changing policy/risk/terminal semantics. |
| `test-run-compare.R`, `test-sweep.R`, `test-sweep-parity.R`, `test-sweep-parallel.R`, `test-strict-dispatch-hoist.R` | Remove persistence/cache controls and retain run/sweep/parallel/dispatch equality. |
| `tests/claims.yml` | Reconcile LCL-0105, LCL-0213, schema 120, and identity rule 3 without adding or dropping a load-bearing ID. |

## Seven-shape walk

1. **One-row frame per element, bound at the end:** none added. Deleted feature-
   row construction and buffering remove this shape from finalization.
2. **Full-table subset inside a loop over ids:** none added. Existing feature
   engine indexing remains the single production route.
3. **Per-element parsing or formatting where a vectorised call exists:** none
   added. Capture identity uses the existing deterministic serializer once per
   definition.
4. **Per-row JSON on repetitive strings:** none added. Durable feature-row JSON
   or row serialization does not exist.
5. **Work computed and discarded, or recomputed on every call:** no work is
   duplicated within a run. One current computation per run is the intended
   semantics after deleting cross-run retention; precompute remains the explicit
   reusable object and now refuses stale capture identity.
6. **Quadratic validators:** none added. Current store/config validation is
   reused unchanged apart from literal current versions.
7. **Scalar writes into an environment-held vector:** none added. The cache
   environment and its retained vectors were deleted.

## Verification and empirical record

Input identity: accepted product commit
`31ad6d39237709a0661b1e763e9c26d73981ab77`; implementation branch
`codex/ws36-v0.2.2`; Cut 15 tickets LDG-3049, LDG-3050, and LDG-3056; accepted
feature-keeping probe and Cut 15 decisions. Source commit means the immutable
implementation input; the resulting repository commit is the output record and
is not embedded in itself.

Environment: Windows 11 x64 build 26200, R 4.6.1, testthat 3.3.2, DuckDB
1.5.6.9000, DBI 1.3.0, pkgload 1.5.3. The supported-toolchain record was run on
2026-10-14 from approximately 19:11 through 19:40 UTC. Quarto used RStudio's
bundled executable with its cache redirected into the writable workspace; no
network input was used.

| Check | Reproduction command | Result |
|---|---|---|
| Focused feature/identity/schema/entry-point suites | `pkgload::load_all(compile = FALSE); testthat::test_file(...)` over the named files | PASS; all focused files green. |
| Documentation, codebase, and control-plane contracts | `testthat::test_file()` for the three contract files | PASS. |
| Ordinary fast profile | `Rscript --vanilla tools/run-test-profile.R --profile=fast --mode=ordinary --records=.test-evidence/ws36-fast-profile --run-index=1` | PASS, 565/565, zero skipped/failed, 106.110 s against unchanged 112 s bound. |
| Supported full suite | `pkgload::load_all(compile = FALSE); testthat::test_dir('tests/testthat', reporter='summary', stop_on_failure=FALSE)` | PASS in 651.2 s, zero failures and one expected optional-path skip after schema-golden regeneration. |
| Source build | `R CMD build .` with workspace-local Quarto cache | PASS; all vignettes built. |
| Package check | `R CMD check --no-manual --no-build-vignettes ledgr_0.2.1.0.tar.gz` | PASS, Status: OK in 274.1 s; code, examples, tests, installed vignettes, and vignette execution all OK. Offline repository-index messages occurred after Status: OK. |

The first diagnostic full pass under unsupported R 4.5.2 exposed stale test
assumptions and two interruption assertions plus the PIT serialized-byte pin.
The latter failures reproduced unchanged at the input commit. Under the
supported R 4.6.1/DuckDB 1.5.6.9000 toolchain both continuity tests and the PIT
fixture pass; only DuckDB-version metadata in the freshly generated schema
goldens needed correction before the final green record.

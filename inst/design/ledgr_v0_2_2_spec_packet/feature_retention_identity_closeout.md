# Workstream 36: feature-retention removal and capture identity

## Outcome and necessity

Workstream 36 is complete for implementation. Its independent Type 1 close
review returned CHANGES_REQUIRED; `close_review_36.md` preserves that review,
and this correction record is ready for the required focused re-review of
F1-F4. The smallest valid product change was deletion, not repair. The accepted
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
  equity when the same capture is repeated. This is a deterministic atomic-
  capture substitute for the original RED spike: the spike captured an
  environment, which rule 3 correctly refuses with
  `ledgr_config_non_deterministic`, so that script no longer directly witnesses
  recomputation without modification.

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
  values are not serialized into the fingerprint. The detector uses
  non-integer values plus `NA_real_`, proves that changing the private captured
  values with `params$data_hash` fixed leaves identity unchanged, and fails
  when row values are substituted for the data-hash identity.
- A stale precomputed sweep refuses with
  `ledgr_precomputed_feature_mismatch` before candidate execution, fills, or
  store writes. Validation binds the exact ordered feature-fingerprint vector
  and alias-map hash for every candidate, not merely the union. The exact
  `fast = 5, slow = 20` to `fast = 20, slow = 5` permutation is refused even
  though its union is unchanged; a rebuilt payload matches a fresh
  non-precomputed sweep.

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
candidate keys, and walk-forward `session_id`. For every feature-bearing
walk-forward candidate, the rule-3 candidate key also changes its derived
`execution_seed` and candidate label. Snapshot ID/hash, snapshot content-hash
rule, strategy fingerprint, parameter identity, cost/risk/policy identity, and
dense engine provenance remain exact when their inputs do not change.

The cross-rule economic exactness claim is limited to deterministic strategies
and to the recorded non-stochastic oracles. A strategy that consumes its
derived RNG seed may intentionally produce different fills, ledger, equity, or
metrics after rule 3 because its candidate key and therefore `execution_seed`
changed. Repeated execution under the same current rule and inputs remains
exact.

Focused witnesses cover run, backtest, sweep, promotion, walk-forward, resume,
reopen, and pulse snapshot in both dense and availability modes. The economic
oracles compare fills, ledger, positions, equity, metrics, strategy state, and
diagnostics after removing only the retired telemetry/config fields.

## Acceptance evidence

### LDG-3049

1. **PASS:** `test-feature-retention-removal.R` derives its deleted-name census
   from `R/`, `NAMESPACE`, `_pkgdown.yml`, public formals, and help; the moved
   engine functions and LTB-0105 preserve feature-engine provenance.
2. **PASS:** the same file's runtime capture witness changes the second run's
   feature value and repeats exact outputs; walk-forward suites pass. The
   atomic witness replaces, and is explicitly distinct from, the original
   environment-capturing RED spike.
3. **PASS:** the focused entry-point suites named under Verification preserve
   economic/result outputs outside the deleted telemetry fields.
4. **PASS:** the final current-surface scan finds no cache promise or
   compatibility alias in `NAMESPACE`, `_pkgdown.yml`, help, contracts,
   vignettes, examples, claims, or result code, and the pkgdown reference index
   builds. NEWS records the current removal while preserving truthful cache
   history in released 0.1.5, 0.1.8.6, and 0.1.8.7 sections; those historical
   release notes are intentionally outside the current-promise census.
5. **IMPLEMENTATION PASS; CORRECTION TIMING MISS:** focused suites pass; the
   implementation fast profile passed, while the correction's three-run median
   is 112.490 s against 112 s with every block green. The test ledger and
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
4. **PASS:** deterministic dense/availability and all entry-point witnesses
   preserve economic bytes; the enumerated config, experiment, candidate,
   session, walk-forward label, and derived-seed identities change. A strategy
   that consumes the changed seed may change economics; snapshot, policy,
   strategy, parameter, and engine identities stay exact.
5. **IMPLEMENTATION PASS; CORRECTION TIMING MISS:** absence of the table makes
   durable feature-row count structurally zero while the feature-keeping
   economic witness is exact. A real run asserts that both its in-memory and
   stored config `features` object has no `persist` field; restoring
   `persist = TRUE` produces six focused failures. Focused tests and
   documentation contracts pass. The implementation package/check record
   remains green; the correction fast timing is an explicit 0.490 s median miss
   with zero failed blocks, as recorded below. The test ledger and seven-shape
   walk follow.

### LDG-3056

1. **PASS:** `test-feature-capture-identity.R` proves scalar/list change and
   repeat stability at indicator, feature-definition, active, and feature-set
   levels; intended downstream identities are enumerated above.
2. **PASS:** constructor/adapter coverage includes SMA, EMA, RSI, returns, TTR,
   TTR outputs, R, and CSV with non-integer values and missing values; CSV binds
   `data_hash`, not row values or public labels, even when its private captured
   values are mutated with the data hash unchanged.
3. **PASS:** `test-precompute-features.R` proves exact per-candidate fingerprint
   and alias-map binding: the unchanged-union fast/slow capture permutation
   refuses before candidate execution or run/fill writes, and rebuilding is
   exact against a fresh sweep.
4. **PASS:** run, sweep, and walk-forward focused suites exercise capture-
   distinct current identities and repeat exactness.
5. **PASS:** atomic/list captures are accepted; environment and connection
   captures refuse with `ledgr_config_non_deterministic` before side effects.
6. **PASS:** contracts and custom-indicator teaching state direct, nonrecursive
   capture binding; failure-sensitive capture-blind and CSV-authority cases are
   in `test-feature-capture-identity.R`. Replacing the CSV data-hash override
   with captured row serialization fails on the non-finite value before the
   fingerprint assertion can pass.
7. **PASS:** indicator, adapter, precompute, sweep, walk-forward, identity, and
   promotion suites pass; final source/catalogue scans find no cache, feature
   table, compatibility fingerprint, or stale fallback.

## Test-change ledger

The implementation control-plane census was 1,090 blocks before and after:
fast 564 to 565, review 337 to 336, heavy 189 to 189. The close-review
correction adds one heavy-protocol candidate-permutation block, so the corrected
tree has 1,091 blocks: fast 565, review 336, and heavy 190. The immutable
load-bearing block count is 267 before and after. LTB-0105 moved from the
deleted cache file to the fingerprint suite; LTB-0213 retired only its now-
deleted persisted-row half.

| Changed test file or fixture | Reason |
|---|---|
| `fixtures/schema-current-golden.csv`, `fixtures/schema-current-golden-rows.csv` | Regenerate the strict schema-120 catalogue and supported DuckDB 1.5.6.9000 metadata. |
| `helper-fixtures.R` | Remove the persisted-feature fixture argument/telemetry and make schema/rule fixtures current. |
| `test-feature-cache.R` (deleted) | Delete cache-only API, key, registry, hit/miss, and reuse tests; move LTB-0105 to fingerprint coverage. |
| `test-feature-retention-removal.R` (new) | Source and pkgdown-index detector, old-call refusal, real-run in-memory/stored config-shape check, zero-durable-surface, capture-change, and repeat-exact witnesses. |
| `test-feature-capture-identity.R` (new) | Direct-capture, unsupported-capture, constructor, non-integer/missing CSV data-hash and capture-mutation, and nonrecursive-function witnesses. |
| `test-fingerprint-stability.R`, `test-strict-feature-acceleration.R` | Pin the intentional rule-3 fingerprints and retain the engine-helper mutation detector. |
| `test-precompute-features.R` | Add stale-capture refusal plus the unchanged-union per-candidate permutation witness; remove retired persistence setup. |
| `test-schema-current.R`, `test-schema.R`, `test-schema-validator-side-effects.R`, `test-store-gate-contracts.R`, `test-current-only-records.R` | Pin schema 120/rule 3, deleted catalogue objects, older-store refusal, and remove the deleted table from side-effect counts. |
| `test-config.R`, `test-experiment.R`, `test-api-exports.R`, `test-backtest-wrapper.R`, `test-result-output.R`, `test-run-telemetry.R` | Remove public/config/result/telemetry persistence assumptions and assert ordinary old-call failure. |
| `test-indicators.R`, `test-indicator-adapters.R`, `test-indicator-ttr.R` | Update capture-aware pins and prove all supported constructors/adapters remain deterministic. |
| `test-acceptance-v0.1.0.R`, `test-acceptance-v0.1.1.R`, `test-active-alias-runtime.R`, `test-feature-map.R` | Remove retired persistence/cache setup while preserving feature-access and acceptance economics. |
| `test-availability-economics.R`, `test-availability-features.R`, `test-availability-fold-witnesses.R`, `test-availability-parity.R`, `test-pit-consistency.R` | Remove retention fields, bind rule-3 expected configs, and preserve availability/PIT economics. |
| `test-backtest-audit-log-equivalence.R`, `test-fifo-opening-positions.R`, `test-ledger-writer.R`, `test-metric-context-storage.R` | Remove feature-table/write expectations while retaining accounting, audit, and storage oracles. |
| `test-durable-run-preparation-memory.R`, `test-run-store.R`, `test-runner.R`, `test-runner-snapshots.R`, `test-run-continuity-ii.R` | Remove feature buffers/writes/resume fields and preserve durable preparation and continuation behavior. |
| `test-research-cycle-scale.R` | Retire the persisted-feature-row half of LTB-0213; retain exact pair-key behavior. |
| `test-risk-config.R`, `test-corporate-action-policy.R`, `test-terminal-policy-identity.R` | Update current config identity without changing policy/risk/terminal semantics. |
| `test-run-compare.R`, `test-sweep-parity.R`, `test-sweep-parallel.R`, `test-strict-dispatch-hoist.R` | Remove persistence/cache controls and retain run/sweep/parallel/dispatch equality. |
| `test-sweep.R` | Remove persistence/cache controls and change the precomputed-sweep factory-call oracle from 0 to 2: validation must resolve both candidates again to compare their current fingerprints and alias maps with the stored per-candidate identities. |
| `tests/claims.yml` | Reconcile LCL-0105, LCL-0213, schema 120, and identity rule 3 without adding or dropping a load-bearing ID. |

## Seven-shape walk

1. **One-row frame per element, bound at the end:** none added. Deleted feature-
   row construction and buffering remove this shape from finalization.
2. **Full-table subset inside a loop over ids:** none added. Existing feature
   engine indexing remains the single production route.
3. **Per-element parsing or formatting where a vectorised call exists:** none
   added in a pulse loop. Capture identity uses the existing deterministic
   serializer per candidate and per feature definition. The review measured
   indicator fingerprinting at 0.21 to 1.61 ms per indicator (7.6 times); this
   is a bounded identity-boundary cost, not once-per-definition global work.
4. **Per-row JSON on repetitive strings:** none added. Durable feature-row JSON
   or row serialization does not exist.
5. **Work computed and discarded, or recomputed on every call:** no feature
   values are duplicated within a run. One current computation per run is the
   intended semantics after deleting cross-run retention. A sweep using a
   precomputed payload deliberately re-resolves each candidate's definitions
   for identity validation; the review measured 1.83 s for 500 candidates,
   about 2 percent of its 90 s sweep. That bounded recomputation is necessary
   to refuse stale or permuted candidate mappings and is acceptable here.
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

Close-review correction verification used the same R 4.6.1 toolchain on
2026-10-14:

| Correction check | Result |
|---|---|
| F1 candidate permutation | PASS. Swapping `c(fast = 5, slow = 20)` to `c(fast = 20, slow = 5)` with the same union raises `ledgr_precomputed_feature_mismatch`; the mocked fold is not called, run/fill row counts remain unchanged, and rebuilt versus fresh status, final equity, and trade counts are exact. Disabling the per-candidate fingerprint/alias-hash condition produces three focused failures. |
| F2 pkgdown reference index | PASS. With the bundled Quarto path configured, `pkgdown:::data_reference_index(pkgdown::as_pkgdown('.'))` exits successfully after removal of the deleted topic. Restoring the topic produces two current-surface detector failures. |
| F3 CSV row-value mutation | PASS. The normal non-integer/missing fixture is green; replacing the constructor override with captured row values fails with `ledgr_config_non_deterministic` on the non-finite capture. Changing the private `values` vector while retaining `params$data_hash` leaves the normal fingerprint identical. |
| F4 config-shape mutation | PASS. Restoring `persist = TRUE` in the real config produces six focused failures, covering both the returned run config and stored `config_json`. |
| Focused correction and affected suites | PASS in 110.6 s. Twenty-five feature, indicator, precompute, sweep, walk-forward, current-format, documentation, codebase, control-plane, telemetry, result, backtest, and API files completed with zero failures. |
| Corrected control-plane census | PASS: 1,091 total blocks = 565 fast, 336 review, 190 heavy protocol; 267 registered load-bearing blocks. |
| Corrected ordinary fast timing protocol | **MISS**, with all 565 blocks passing and zero skips/failures in every run: 117.530, 112.490, and 107.480 s; median 112.490 s, 0.490 s above the unchanged 112 s bound. The heavy permutation block does not enter this lane. The miss remains evidence and is not relabelled as a pass. |

The focused correction did not rerun the full package suite, source build, or
R CMD check; the table above retains the implementation commit's supported-
toolchain results and the correction batch covers every changed runtime and
documentation surface. Focused re-review remains the acceptance gate.

The first diagnostic full pass under unsupported R 4.5.2 exposed stale test
assumptions and two interruption assertions plus the PIT serialized-byte pin.
The latter failures reproduced unchanged at the input commit. Under the
supported R 4.6.1/DuckDB 1.5.6.9000 toolchain both continuity tests and the PIT
fixture pass; only DuckDB-version metadata in the freshly generated schema
goldens needed correction before the final green record.

# WS36 Type 1 close review (31ad6d39..8ca55c73)

## Context

Independent read-only close review of Cut 15 / Workstream 36 (LDG-3049,
LDG-3050, LDG-3056). Probes ran from `%TEMP%/ws36probe` against the worktree
and a `git archive` copy of 31ad6d39 (same compiled DLL; no `src/` change in
range). This file preserves the independent review under M2; the implementing
agent did not alter the findings or verdict.

## 1. Verdict: CHANGES_REQUIRED

The accepted direction holds and the core work is sound: both retention
mechanisms are gone, schema 120 / rule 3 are exact, economics are
byte-identical. Two defects block acceptance: the stale-precompute detector
(F1) and the pkgdown site build (F2). F3-F6 are small detector and evidence
corrections. A focused re-review should cover F1-F4.

## 2. Findings

**F1 — Medium-High, correctness. `R/precompute-features.R:185-199` (enabled by
`R/sweep.R:225`).** Stale-payload validation only checks that the set of
required fingerprints is covered. Execution does not use that set: it uses the
payload's per-candidate mapping (`ledgr_sweep_resolved_from_precomputed`,
`R/sweep.R:2592`). So a capture change that permutes candidates onto already-
precomputed fingerprints passes validation and runs stale features.

- Scenario: the factory captures `windows <- c(fast=5, slow=20)`, with
  `ledgr_ind_sma(windows[[params$speed]])` behind alias `trend`. Precompute,
  then set `windows <- c(fast=20, slow=5)`.
- Result: `ledgr_sweep(exp, grid, precomputed_features = pre)` does not refuse.
  Candidate `fast` reports SMA(5) equity 100483.50; a fresh sweep gives
  99883.09. The two candidates' fingerprints come back swapped.
- This also reproduces on 31ad6d39, where there was no check at all. WS36
  narrowed the gap but did not close it.
- It falsifies the new contract line in `contracts.md` ("validated against
  current feature identity before reuse; a mismatch refuses") and LDG-3056
  acceptance 3. It also falsifies the existing precompute help text
  ("validated … against … resolved feature fingerprints").
- Minimal fix: compare `resolved$candidate_features$feature_fingerprints` (and
  alias-map hash) per candidate with `precomputed$candidate_features`, and
  refuse with `ledgr_precomputed_feature_mismatch`. Register the swap witness.

**F2 — Medium, packaging/docs. `_pkgdown.yml:217`.** The file still lists
`ledgr_feature_cache_clear`. On a temp copy,
`pkgdown:::data_reference_index()` fails with: "reference[10].contents[16]
(ledgr_feature_cache_clear) must be a known topic name or alias". The `pkgdown`
workflow on push to `main` would fail. LDG-3049 acceptance 4's census claim
("only NEWS … and detector name the retired cache") is therefore false. The
documentation-contract tests pass, so nothing detects this. Fix: delete the
line, and optionally add an unknown-topic check.

**F3 — Low-Medium, detector.
`tests/testthat/test-feature-capture-identity.R` (CSV block).** LDG-3056
acceptance 6 says a mutation that serializes CSV row values fails the registered
detector. It does not:

- The mutation `ledgr_indicator_capture_overrides <- function(...) list()`
  passes all of: capture-identity, retention-removal, precompute, fingerprint-
  stability, indicators, indicator-adapters and current-only (0 failures).
- Cause: `read.csv` reads `c(1, 2)` and `c(1, NA)` as integer. `NA_integer_`
  passes `ledgr_stable_payload`, so hashing the row values still gives two
  distinct, valid fingerprints.
- Fix: use non-integer values (for example `c(1.5, NA)`). Also assert that
  replacing `values` in `environment(csv$fn)` with `params$data_hash` unchanged
  leaves the fingerprint unchanged.

**F4 — Low, detector. `R/backtest-config.R:238-248`.** Putting `persist = TRUE`
back into `ledgr_config()`'s `features` list changes `config_hash`/`config_json`.
No test I ran catches it:

- Files run: retention-removal, config, experiment, backtest-wrapper,
  fingerprint-stability, run-telemetry, api-exports, terminal-policy,
  risk-config, sweep-parity, walk-forward-identity, identity-locale,
  current-only, schema.
- The source patterns (`persist_features`, `features\$persist`) only catch a
  reader, not the identity field.
- Fix: assert `!"persist" %in% names(bt$config$features)` on a real run, or pin
  one end-to-end `config_hash`.

**F5 — Low, stale or rewritten docs.**

- `contracts.md:869` still describes "Persisted feature rows" in the resume
  agreement.
- `man/ledgr_indicator_remove.Rd` was not regenerated: it still says "runs,
  features, or ledger artifacts", while `R/indicator.R` no longer says
  "features".
- `claims.yml` LCL-0105 overlapping_evidence still says "invalidate caches".
- NEWS rewrites shipped release history to pass the census: the 0.1.5 cache
  bullet and the rename-table row are deleted, and 0.1.8.6/0.1.8.7 "cache key"
  became "lookup key". Released sections should stay truthful; exempt them from
  the census instead.
- Optional: `dev/bench/v0_2_2_durable_run_memory/run_case.R` and
  `dev/spikes/feature_keeping/*` call deleted APIs. This is fine as frozen
  evidence, but it means the brief's "rerun the RED spike" cannot be done
  unmodified.

**F6 — Low, evidence accuracy (closeout).**

- (a) Walk-forward `execution_seed` derives from `candidate_key`
  (`walk-forward-identity.R:78-99`). It changed for every feature-bearing
  candidate (observed old vs new with `seed = 7`), and WF candidate labels
  changed with it. So a seeded stochastic walk-forward does not keep its
  economics under rule 3. Enumerate this as a derived intended change and
  qualify the claim that "fill/ledger/equity bytes remain exact".
- (b) `test-sweep.R` inverts a registered oracle: the factory call count goes
  from 0 to 2 on a precomputed sweep. The ledger's stated reason ("remove
  persistence/cache controls") omits this.
- (c) The seven-shape walk says capture identity is serialized "once per
  definition". In fact it runs per candidate and per feature, and the
  precomputed path now resolves the grid twice. Measured: fingerprint cost
  0.21 → 1.61 ms per indicator (7.6×). Precompute validation adds 1.83 s on a
  500-candidate grid against a 90 s sweep (~2% end-to-end). That is acceptable
  but should be recorded.
- (d) The RED spike's own witness captures an environment, so it now refuses
  with `ledgr_config_non_deterministic` rather than recomputing. The closeout
  substituted an atomic-capture witness without saying so.

## 3. Acceptance table

| Ticket | Item | Result |
|---|---|---|
| 3049 | 1 API/registry/telemetry absent; helpers identical | PASS. Engine digests dense and availability identical old/new; `engine_version` and `active_fingerprint` bodies identical; `def_fingerprint` differs only by the intended 3056 capture flag |
| 3049 | 2 captured value fresh; repeat exact | PASS (atomic witness; see F6d) |
| 3049 | 3 entry points exact outside telemetry | PASS (oracle below) |
| 3049 | 4 no cache promise in NAMESPACE/help/docs | FAIL: F2, F5 |
| 3049 | 5 suites, ledger, seven shapes | PASS_AFTER_PATCH: F6b, F6c |
| 3050 | 1 persist_features absent; unused-arg | PASS (only `ledgr_walk_forward` has `...`, and it refuses) |
| 3050 | 2 DDL and catalogue detectors | PASS. Golden diff = features table + 3 telemetry columns + `updated_at_utc` ordinal only |
| 3050 | 3 schema 120 / fingerprint / 119 older / rule 2 | PASS. A real 31ad6d39 store refuses `cause = "older"` (recorded 119), md5 unchanged |
| 3050 | 4 economics exact, identities enumerated | PASS_AFTER_PATCH: F6a enumeration |
| 3050 | 5 zero durable rows, ledger, checks | PASS (structural); F4 detector gap |
| 3056 | 1 scalar/list capture binding | PASS |
| 3056 | 2 constructors and CSV via data_hash | PASS. CSV with NA runs through run, feature map, sweep, precompute and register |
| 3056 | 3 stale precompute refuses | FAIL: F1 |
| 3056 | 4 run/sweep/WF distinct captures | PASS |
| 3056 | 5 env/connection refuse before side effects | PASS. run/backtest/precompute refuse, store row counts 0/0/0 unchanged |
| 3056 | 6 teaching + failure-sensitive detectors | FAIL: F3 (capture-blind mutation is detected; CSV mutation is not) |
| 3056 | 7 focused suites; no fallback | PASS |

## 4. Clean checks, commands, seven shapes, inputs

**Cross-commit oracle** (`oracle.R` on the worktree and on 31ad6d39, dense
2-instrument plus availability fixture):

- Byte-identical: run fills/ledger/equity/trades, sweep economics (fresh and
  precomputed), promotion, pulse snapshot, walk-forward test-run economics,
  availability run and strategy state.
- Snapshot hashes, dense and availability engine digests: identical.
- Differences are confined to `config_hash`, `feature_set_hash`, the retired
  telemetry fields, `schema_version`, `feature_fingerprints`/provenance
  `feature_set_hash`, WF `session_id`/`candidate_key`/label/`execution_seed`,
  and per-run noise (snapshot_id, timestamps, paths).

**Mutations** (in-memory `assignInNamespace`, no file edits):

- Caught: capture-blind `fn`+`series_fn` (12 failures), capture-blind `fn` only,
  capture-blind definition, `resolve_features = FALSE` (LTB stale witness),
  rule 2, schema 119 (store gate).
- Not caught: CSV row serialization (F3), `features$persist` re-add (F4).

**Focused baseline:** 0 failures across about 20 files. Covered capture-
identity, retention-removal, precompute, fingerprint-stability, indicators,
adapters, current-only, schema-current, schema, store-gate,
codebase/documentation/control-plane contracts, run-telemetry, result-output,
WF identity, sweep-parity, backtest-wrapper, api-exports.

**Other checks:**

- Roxygen regenerated in a temp copy: NAMESPACE identical; Rd differences are
  only roxygen 8.1.0 ordering, except F5's `ledgr_indicator_remove.Rd`.
- Blobs are LF/ASCII. No `cpp11`/build artifacts in range. Test-block count is
  net zero (−7 cache, −2 schema, +9).
- Not rerun: full suite, R CMD check, fast profile. I accepted the recorded
  565/565 at 106.110 s; it says nothing about shape safety, so shapes were
  walked separately.

**Seven shapes, on changed functions** (`ledgr_function_fingerprint`,
`ledgr_indicator_fingerprint`, capture overrides, `ledgr_sweep_impl`
validation, runner feature loop, telemetry writer, run-store fetch, finalize):

1. One-row frame bound at end: none.
2. Full-table subset in an id loop: none.
3. Per-element parsing where a vectorized call exists: none in pulse loops.
   `findGlobals` runs per indicator per candidate (bounded by candidates ×
   features).
4. Per-row JSON: removed.
5. Recompute: yes — the precomputed sweep re-resolves the grid. This is
   necessary for the detector and ~2% end-to-end (F6c).
6. Quadratic validators: none.
7. Environment-vector scalar writes: removed.

No replacement cache and no unbounded retained payload.

**Inputs:** adequate for deletion and schema. Inadequate for stale-precompute:
the witness only varies one candidate's capture, so it cannot see permutations
(F1). The CSV fixture is integer-typed (F3). LTB-0202/0205 and the PIT digest
were not charged; I saw no differential.

## 5. Ready for maintainer acceptance?

No. Patch F1 (per-candidate comparison plus a swap witness) and F2 (one-line
`_pkgdown.yml` fix). Then fix F3-F6. A focused re-review of F1-F4 should follow.

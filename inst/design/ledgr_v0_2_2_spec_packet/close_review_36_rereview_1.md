# WS36 focused Type 1 re-review (8ca55c73..4a417c75)

## Verdict: CHANGES_REQUIRED

F2–F6 are resolved, and the fingerprint half of F1 is resolved and independently guarded. The alias half of F1 is not. The new validator compares `alias_map_hash`, and that hash does not record which concrete feature each alias points to. A permuted alias map therefore passes validation and runs with stale results (N1). The patch is small; a re-review limited to N1 is enough.

## The suspected fingerprint-detector gap is not real

In the registered swap (fast 5 / slow 20 → fast 20 / slow 5), `alias_map_hash` is identical before and after, and identical across both candidates. Alias identity uses capture-free function bodies (`R/feature-alias-map.R:42-60`), so SMA(5) and SMA(20) produce the same hash. Only the fingerprint comparison fires.

I mutated the validator in memory and ran `test-precompute-features.R` (14 blocks):

| Mutation | Result |
|---|---|
| No change | 0 failures |
| Fingerprint check removed | 2 failures (permutation witness) |
| Alias check removed | 1 failure (alias-only witness) |
| Both removed | 3 failures, matching the recorded "three" |

Additional probes:

- **Plain-list features (alias hash NA):** with the full validator, the swap refuses with `ledgr_precomputed_feature_mismatch`. With the fingerprint check removed, it passes, so the fingerprint check is the only guard here, and it works.
- **Parameterized map `sma(ledgr_param("n"))`:**
  - A valid payload passes.
  - Swapping the stored fingerprint vectors between candidates refuses; it passes only when the fingerprint check is removed.
  - A stale alias hash on its own refuses.
- **Duplicate sets and ordering:**
  - A three-candidate grid where two candidates share a feature set gives no false refusal.
  - A reordered grid with the old payload refuses (`grid_mismatch`).
  - A reordered grid with a rebuilt payload passes, and the rebuilt sweep equals a fresh one.

## N1 — Medium, correctness: alias-map permutation reuses stale features

- **Where:** `R/precompute-features.R:193-197` compares `alias_map_hash`.
  - That hash is built only from alias → declaration-identity pairs (`R/feature-alias-map.R:128-131`).
  - The declaration identity omits feature ID, params and captures.
  - Execution, however, uses the stored alias → feature-ID map (`R/sweep.R:2608`).
- **Scenario:** the feature factory captures `nm <- c("fast","slow")` and builds `ledgr_feature_map` from `list(sma(5), sma(20))` with `names <- nm`. After precompute, set `nm <- c("slow","fast")`.
  - Fingerprints: identical. Alias hash: identical. `alias_map_json`: differs.
  - Validation passes, and `ledgr_sweep(..., precomputed_features = pre)` runs.
  - Stale result: equity 99980.08, 5 trades. Fresh: 99987.98, 3 trades. A rebuilt payload equals fresh.
- **Scope:** this is pre-existing (alias identity has excluded captures since 31ad6d39) and confined to the validator. Run `config_hash` does distinguish the two maps: I checked with two real runs.
- **What it falsifies:**
  - the validation line at `contracts.md:1504`;
  - LDG-3056 acceptance 3;
  - the closeout's claim to bind the alias map per candidate (`feature_retention_identity_closeout.md:83-88, 180-183`);
  - the current NEWS line "stale precomputed features refuse before execution".
- **Why the tests miss it:** the alias-only witness (`test-precompute-features.R:469`) only overwrites the stored hash string, so it can't see that the hash ignores where an alias points.
- **Fix:** also compare the stored `alias_map` (or `alias_map_json`) per candidate. Register this permutation as a witness and confirm that dropping the new comparison fails it.

## F1–F6 status

| Finding | Status | Evidence |
|---|---|---|
| F1 | **Partly resolved** | Fingerprint half: resolved and independently guarded (above). The registered swap refuses before execution and before any fill or write; rebuilt equals fresh. Alias half: N1. |
| F2 | Resolved | The pkgdown reference index builds on the worktree (with the RStudio Quarto/Pandoc paths set). Restoring the topic in a temp copy fails the index with "must be a known topic", and the detector reports 2 failures. |
| F3 | Resolved | The CSV fixture is now `c(1.5, 2.25)` and `c(1.5, NA)`. Changing the captured values with `data_hash` fixed leaves the fingerprint identical. Both mutants (no override, and an override that hashes the row values) fail the detector. An indicator with only a label or params gets no private route. |
| F4 | Resolved | Restoring `persist = TRUE` in both `ledgr_config` branches produces exactly 6 failures, covering the returned and stored config. |
| F5 | Resolved | Released NEWS sections are unchanged from 31ad6d39; only the current section changed. Three detector mutations each produce 1 failure: rewriting history, deleting the rename-table row, and restoring the stale contract line. `contracts.md:869` and `ledgr_indicator_remove.Rd` are clean, and `claims.yml` LCL-0105 is reworded. |
| F6 | Resolved | The closeout records: the walk-forward seed/label change and the qualified exactness claim; factory calls 0→2 in the test ledger (`test-sweep.R` oracle confirmed at 2); 0.21→1.61 ms; +1.83 s per 500 candidates (~2%); the atomic-witness substitution; and work that is per candidate rather than once per definition. |

## Other checks

- **Focused suites:** 25 files, 216 blocks, 0 failures. They cover capture identity, retention removal, precompute, sweep, sweep parity, three walk-forward files, indicators, adapters, TTR, fingerprint stability, config, experiment, current-only, schema, store gate, telemetry, result output, backtest, API, feature map, documentation and codebase contracts, and the control plane.
- **No new compatibility, cache, persistence or fallback code** in `R/` across 31ad6d39..4a417c75.
- **No identity drift:** the correction changes only validator logic, and the fingerprint pins pass.
- **Seven shapes:**
  - Shape 5 (re-resolving each candidate) is disclosed and accepted.
  - Nit, not blocking: the new candidate loop at `R/precompute-features.R:188` does two `identical()` calls per candidate on top of the resolve loop. That is bounded, but the style manual expects a stated reason for a new per-candidate loop, and none is given. One whole-column `identical()` plus `which()` for the error message would remove it.

## Fast profile

The recorded figures stand as written: 565/565 in 117.530 / 112.490 / 107.480 s, median 112.490 s. That is a **MISS by 0.490 s** against the 112 s bound. The original candidate ran in 106.110 s. My one independent run was 565/565 in 115.760 s, also over the bound.

The correction adds no fast-lane blocks (its new block is heavy-protocol), so the miss looks like machine variance. It does not block correctness acceptance. However, LDG-3050 acceptance 5 is literally unmet: accepting the miss or getting a passing median is your decision.

## Side effect to clean up

My fast-profile run left `R/cpp11.R` and `src/cpp11.cpp` showing as modified. `tools/run-test-profile.R:57` calls `load_all` with compilation enabled, which re-registers cpp11 and rewrites those files. `git diff` shows no content change, only line endings. I did not restore them, as instructed; `git checkout -- R/cpp11.R src/cpp11.cpp` will clear it. All temp copies and records were removed.

## Commands and mutations

- **Single-line `Rscript -e` probes:** `load_all(compile = FALSE)` on the worktree. Multi-line commands were permission-denied, so every probe ran as one line.
- **In-namespace mutations** (no files edited): three validator conditions (fingerprint off, alias off, both off), two capture-override mutants, and a `persist = TRUE` config-body patch.
- **Temp-copy mutations** under R's session tempdir: pkgdown topic restore, two NEWS history rewrites, and the stale contract line. Each copy was deleted afterwards.
- **pkgdown:** `pkgdown:::data_reference_index(as_pkgdown(...))` on the worktree and on a restored copy.
- **Fast profile:** `tools/run-test-profile.R --profile=fast`, with records written to a temp directory that was then deleted.

## Ready for maintainer acceptance?

No. Patch N1: compare the per-candidate alias map, register the alias-permutation witness, and mutation-check it. Then run a re-review limited to N1. Separately, decide on the fast-profile miss without relabelling it.

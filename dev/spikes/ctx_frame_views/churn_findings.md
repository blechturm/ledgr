# Preparation and fold churn: where the peak comes from

**2026-10-04 / Claude, for the maintainer.** Recharter probe that follows
`probe_findings.md`. Binds no design.

**Question:** At a durable availability `ledgr_run()`, which allocations make
up the gap between peak R heap and live state (about 255 MiB of 634 MiB)?

**Tree and shape:** the same as `probe_findings.md`: `ff04a32`, 757 pulses,
600 instruments, 500 members, three returns features, monthly top-10 momentum,
feature persistence off.

**Script:** `probe_churn.R`, three fresh-process runs over fresh fixture copies:
- **Run A:** phase markers at top-level steps of `ledgr_run_fold()`, recording
  live heap and the peak inside each phase. Markers force full collections, so
  these are attribution numbers, not production peaks.
- **Run B:** `Rprofmem()`, allocations of at least 64 KiB, with call stacks.
- **Run C:** `Rprof(memory.profiling = TRUE)`, allocation volume by function,
  sample-attributed.

## Phase peaks (Run A)

| Phase | Live at start | Peak in phase | Above start live |
| --- | ---: | ---: | ---: |
| Run start to hydration (snapshot guard, provider, calendar) | 112 MiB | 427 MiB | 314 MiB |
| Bar hydration | 199 MiB | 452 MiB | 253 MiB |
| Feature series | 340 MiB | 529 MiB | 189 MiB |
| Strategy, risk and spec setup | 362 MiB | 437 MiB | 75 MiB |
| **Fold** | 362 MiB | **593 MiB** | **231 MiB** |
| Finalize | 366 MiB | 383 MiB | 17 MiB |

Peak is the highest phase. Here that's the fold: live state at fold entry plus
fold churn. The feature phase is second. Lowering only one of them moves the
peak to the next, so a material reduction needs live fold-entry state and both
churn sources.

## Allocation attribution

**Large allocations (Run B, at least 64 KiB):** 394 MiB in 2,089 allocations.
- `ledgr_snapshot_hash`: 259 MiB (`sprintf` 60, `paste0` 50, `serialize` 43,
  token formatting 41). That's the run-start full re-hash.
- `ledgr_run_fold` hydration: 75 MiB (`bars_mat` 33, DuckDB result 30).
- Prebuilt bar views: 42 MiB (including the split).

**All allocation sizes (Run C), allocation volume per function:**

| Function | Allocated (MiB, nested) | Phase |
| --- | ---: | --- |
| `ledgr_execute_fold` | 6,390 | fold |
| `ledgr_fold_asset_state_normalize` | 1,631 (all self) | fold, per pulse |
| `ledgr_compute_feature_series_strict` | 1,551 | features |
| of which `ledgr_strict_builtin_kind` | 1,263 | features |
| `canonical_json` / `canonicalize` | 1,526 / 1,063 | fold diagnostics and identity |
| `diagnostic_writer$append_block` | 961 | fold |
| `ledgr_snapshot_hash` | 693 | run start |
| `ledgr_update_pulse_context_helpers` + `ledgr_pulse_context_vec` | 648 | fold, per pulse |

These are allocation volumes, not resident bytes. They show what feeds the
churn between collections.

## What was learned

1. **The feature phase recomputes dispatch for every instrument.**
   `ledgr_strict_builtin_kind()` (`R/features-engine.R:351`) builds
   `ledgr_ind_sma(width)` and `ledgr_ind_returns(width)` and deparse-fingerprints
   them on every call. It is called once per instrument per feature: 1,800
   times here for a result that depends only on the feature definition. That's
   1.26 GiB of allocation and about 12% of sampled run time. Optimization
   shape 5. Hoisting it to once per definition is exact; LCL-0143 already pins
   the dispatch semantics. The cost scales with instruments × features, not
   history.
2. **Fold churn is per-pulse rebuilding.** The leaders are
   `ledgr_fold_asset_state_normalize()` (already noted at about 1% time share in
   `dev/bench/notes/long_window_scaling_findings.md`), diagnostic JSON
   canonicalization and per-pulse context helpers.
3. **Run start churn is the snapshot re-hash.** It stays below the fold peak at
   this shape and belongs to the WS5 snapshot verification session.
4. **Hydration churn and live dead intermediates** are Cut 5 (LDG-2951)
   territory. Staged release at each object's last read lowers the hydration
   phase peak.

## What the spec may consume

- Peak is a maximum over phases, so memory gates should report peak-so-far per
  phase, not one process peak.
- History-panel preparation (WS3) adds a phase. It should prepare once into
  typed matrices, avoid per-instrument data-frame construction, and report its
  own phase peak.

## Open

- Run C attribution is sample-based and approximate. Run A markers perturb
  collection timing.
- The other fold allocators were not examined at code level.
- One shape only; R heap only, no DuckDB.

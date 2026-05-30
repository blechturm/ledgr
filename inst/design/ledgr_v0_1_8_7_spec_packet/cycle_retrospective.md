# ledgr v0.1.8.7 Cycle Retrospective

**Status:** Release gate complete.  
**Date:** 2026-05-30  
**Branch:** `v0.1.8.7`

## Summary

v0.1.8.7 was Optimization Round 2 plus explicit legacy cleanup. It removed
pre-snapshot and R6-era execution gunk from modern execution, narrowed the
strategy contract to plain functions, added `collapse` behind a deterministic
wrapper, removed the largest measured event-buffer bottleneck, cleaned up
timestamp/setup representation waste, improved fills read-back materialization,
formalized sweep as the fast/evaluation path, and recorded post-lane benchmark
attribution.

The release did not ship parallel dispatch, a compiled fold core,
matrix-canonical public strategy surfaces, target risk, walk-forward,
cost/liquidity APIs, OMS semantics, durable identity byte redesign, or a public
benchmark dashboard.

## Ticket Outcomes

| Ticket | Outcome |
| --- | --- |
| LDG-2458 | Completed: packet alignment and v0.1.8.7 planning state. |
| LDG-2459 | Completed: legacy raw `bars`, R6, and run-time `data_hash` execution cleanup. |
| LDG-2460 | Completed: ADR 0004 dependency and function-strategy cleanup. |
| LDG-2461 | Completed: deterministic `collapse` wrapper. |
| LDG-2462 | Completed: B0 event-buffer and emission rewrite. |
| LDG-2463 | Completed: representation and setup cleanup. |
| LDG-2464 | Completed: reconstruction and read-back cleanup. |
| LDG-2465 | Completed: run-artifact materialization policy. |
| LDG-2466 | Completed: post-lane benchmark and attribution closeout. |
| LDG-2467 | Completed: release gate and closeout. |

## Shipped Work

- Modern execution now requires sealed snapshot-backed configs before the fold.
  Raw mutable `bars` execution no longer reaches runtime views or fold state.
- R6 strategy execution and R6-specific replay/mutation behavior were removed.
  Built-in/reference strategies now use the function strategy contract.
- Run-time data-subset hashing is no longer modern sealed-run identity. Resume
  relies on config identity, snapshot identity/hash, ordered instruments, and
  inclusive selector bounds.
- `cli` and `R6` were removed from imports; `collapse` was added for scoped
  deterministic hot-path use.
- Durable and sweep event buffers now use realistic initial capacity plus
  grow-by-doubling under a hard worst-case cap.
- Snapshot ingest/seal rejects sub-second timestamps; trusted whole-second
  POSIXct values are carried through hot fill paths without repeated
  format/parse round trips.
- Session-local feature-cache keys now use deterministic length-prefixed lookup
  strings instead of canonical JSON plus SHA.
- Fills reconstruction/read-back now uses primitive column buffers rather than
  per-row data.frames plus `do.call(rbind, ...)`.
- Sweep/evaluation paths are documented and tested as compact-result paths;
  promotion is the explicit slow/materialized path. The new
  `ledgr_candidate_reproduction_key()` exposes the compact candidate
  reproduction key.

## Measurements

The post-lane benchmark closeout is recorded in
`benchmark_attribution_closeout.md` with machine-readable rows in
`benchmark_attribution_table.csv`.

Current local benchmark evidence:

- Durable TTR-backed `peer_sma_crossover` (`500 x 1260 x 2`): 25.91s,
  24,315 security-bars/sec, 13,355 events/fills, with phases `pre=1.22s`,
  `loop=15.70s`, `residual=8.99s`.
- Same-host canonical peer row: ledgr quick/TTR path 31.21s / 20,186 bars/sec;
  Backtrader 64.40s / 9,782 bars/sec; quantstrat 114.59s / 5,498 bars/sec.
  This is one workload, one host, and different timing boundaries. It is not a
  public peer-superiority claim.
- B0 event-buffer evidence: profiled durable buffer self-time fell from 72.43%
  to 3.49% of sampled R time. Old-power wall ratios are not used as direct
  speedup claims.
- R/A representation/setup evidence: same-power turnover shape moved from
  32.91s to 31.25s; setup time moved from 1.50s to 1.11s.
- C read-back evidence: synthetic memory fill reconstruction for 13,355 events
  improved from 8.27s to 4.92s. This is materialization/read-back timing, not
  primary run-wall timing.

## Verification

- Stale-surface grep checks: no production R6 strategy execution surface,
  modern `data_hash` execution guard, or raw `bars` execution path remains
  load-bearing. Remaining hits are expected design/history references or a
  fail-loud raw-config comment.
- Full `testthat::test_local()` via `pkgload::load_all()`: passed in about
  5.8 minutes with one expected skip.
- `R CMD build --no-build-vignettes .`: passed and built
  `ledgr_0.1.8.7.tar.gz`.
- `R CMD check --no-manual --no-build-vignettes ledgr_0.1.8.7.tar.gz`: passed
  with the two known no-build-vignettes warnings about vignette outputs missing
  from `inst/doc`.
- `tools/check-coverage.R`: passed at 84.69%.
- `pkgdown::build_site(new_process = FALSE, install = FALSE)`: passed after
  setting explicit local RStudio Quarto/Pandoc paths. The first pkgdown rerun
  exposed a real release-gate metadata issue: the new
  `ledgr_candidate_reproduction_key()` export was missing from `_pkgdown.yml`.
  `_pkgdown.yml` was updated and the site then built successfully.
- Local WSL/Ubuntu gate: not run because WSL is installed without any Linux
  distributions on this host. Branch, main, and tag CI remain the Linux release
  evidence per `release_ci_playbook.md`.

## Carry-Forward

- v0.1.8.8 remains the planned parallel dispatch window, but no packet has been
  cut at v0.1.8.7 close.
- The post-v0.1.8.7 remaining fold-loop bucket is parked in `horizon.md`:
  future work should first profile context access, target/order conversion,
  fill resolution, state update, and event emission before attempting another
  collapse pass.
- Peer-benchmark expansion is parked in the roadmap/horizon: same-host
  zipline-reloaded, LEAN-Python, NautilusTrader, and a contextual VectorBT row
  remain future evidence work.
- Built-in pure-R indicator speed remains a future UX/performance decision.
  The canonical peer benchmark row uses quick TTR-backed features.
- A compiled/native fold core remains the decisive future lever for LEAN-class
  single-run performance; it is out of scope for v0.1.8.7.


# Spike Log: Line-Level Empty-Fold Profile

**Date:** 2026-05-29 · **Host:** Intel Core i9-12900K, Windows 11 · R 4.5.2 ·
**Status:** v0.1.8.7 input. Resolves Codex review point #2 (split the empty-fold
machinery bucket). **Overturns the "ctx-build is the dominant part" hypothesis.**

**Script:** `dev/spikes/spike-empty-fold-profile.R`. CSV (gitignored):
`dev/bench/results/spike_empty_fold_profile.csv`.

## Question

Spike 4 attributed the modest-turnover loop loosely to "ctx-build." Codex: the
"empty" fold also includes bars/pulse plumbing, bookkeeping, target handling, and
the output wrapper — split it with a real profile. So: Rprof a real empty ledgr
fold (no features, no trades, flat strategy) and report function self-time.

## Method

`ledgr_sim_bars` + flat strategy (`ctx$flat()`) + `ledgr_run`, reusing the bench
setup. 500 inst x 1260 pulses, 3 reps under `Rprof(interval = 0.002)`.

## Results (self-time, 5.70s/run)

```
  format.POSIXlt  26.6%   timestamp formatting
  formatC         14.7%   number formatting
  sprintf         12.5%   string formatting (event-ids etc.)
  paste            4.3%
  paste0           3.6%
  ----------------------  ~61.7% BOUNDARY REPRESENTATION (formatting)
  fn (ctx$flat)   12.8%   the strategy/ctx callback
  %||%            10.5%   null-coalesce, called an enormous number of times
  rapi_* (DuckDB)  ~3%    persistence binding
  digest::digest   1.3%   hashing
```

## Findings

1. **The empty-fold bucket is NOT ctx-build — it is boundary representation.**
   ~62% of the empty fold is timestamp/number/string **formatting**
   (`format.POSIXlt` + `formatC` + `sprintf` + `paste`/`paste0`). The
   "ctx-build is the dominant part" hypothesis is refuted; the strategy/ctx
   callback (`fn` = `ctx$flat`) is only ~13%.
2. **`format.POSIXlt` is the #1 self-time function with ZERO trades (26.6%).**
   The per-pulse equity/positions path formats timestamps per row, so the
   timestamp anti-pattern (audit finding #2) is far bigger and more pervasive
   than the per-fill estimate — it dominates the low-turnover wall on its own.
3. **`%||%` is 10.5%** — a cheap null-coalesce operator called so often (hot
   per-pulse / per-cell path) that it is a tenth of the empty fold. Worth
   reducing call count or replacing with explicit checks on the hot path.
4. **This unifies two lanes I had separated.** The "ctx-build rock" (spike 4 L2)
   and the "per-fill timestamp lane" (synthesis L8 #3) are really **one
   representation/formatting lane**, and it is shared with the emission lane
   (fills carry the same `format.POSIXlt`/`sprintf` payload work). Fixing the
   representation — carry trusted `POSIXct` end to end, format once at validated
   boundaries, avoid per-row `sprintf`/`formatC` — attacks the low-turnover rock
   AND part of the high-turnover emission rock at once.

## Caveats

- Self-time is sampled (interval 0.002s, 3 reps); the *ranking* is robust, exact
  percentages are approximate.
- This is the durable path (persists equity to DuckDB). Some `format`/`rapi_*`
  is the persistence boundary; an ephemeral/in-memory run would shift the mix,
  but the formatting dominance is intrinsic to the per-pulse row construction.
- `format.POSIXlt`/`formatC`/`sprintf` are also the per-fill payload functions,
  so the high-turnover emission profile shares this villain.

## Implication for the RFC

**The low-turnover rock is the timestamp/representation lane, not ctx-build.**
Promote the representation cleanup (POSIXct end-to-end, format-once-at-boundary,
de-`sprintf`/`formatC` the per-row path, audit the hot `%||%`) to a top lane
alongside the buffer — it is cross-cutting (low-turnover equity path + part of
high-turnover emission). ctx-build proper (~13%) drops down the priority list.
Production re-profile after the change remains the verdict.

# ledgr v0.1.8.6 Cycle Retrospective

**Status:** Release gate complete.
**Date:** 2026-05-29
**Branch:** `v0.1.8.6`

## Summary

v0.1.8.6 was a measured setup-performance and storage-boundary release. It
implemented the accepted feature-projection materialization work, added a
structured benchmark suite, recorded width and peer-comparison evidence, and
closed with the remaining large speed gaps named and owned for v0.1.8.7.

The release did not ship DuckDB-backed projection storage, typed persistent
event columns, snapshot administration helpers, research-loop helper APIs,
auditr-report bugfix intake, target risk, parallel dispatch, walk-forward,
public cost/liquidity APIs, OMS work, or public benchmark dashboards.

## Ticket Outcomes

| Ticket | Outcome |
| --- | --- |
| LDG-2445 | Completed: packet alignment and active-scope cleanup. |
| LDG-2446 | Completed: feature cache-key fingerprint and engine-version inputs hoisted. |
| LDG-2447 | Completed: full-panel long `feature_table` no longer built by default. |
| LDG-2448 | Completed: structured benchmark suite with source guards and metadata. |
| LDG-2449 | Completed: two-mode instrument x feature width sweep. |
| LDG-2450 | Completed: storage/schema decision recorded as deferred. |
| LDG-2451 | Deferred: snapshot administration and research-loop helpers moved to the horizon/v0.2.x track. |
| LDG-2452 | Completed: release gate and closeout. |
| LDG-2453 | Completed: fast data.frame stamping for wide-view manifestation. |
| LDG-2454 | Completed: cold setup/residual profiling. |
| LDG-2455 | Completed: removed the intermediate all-pulse wide matrix allocation. |
| LDG-2456 | Completed: performance attribution closeout. |
| LDG-2457 | Completed: same-host matched peer benchmark and v0.1.8.7 handoff evidence. |

## Shipped Work

- Feature cache-key setup work now deduplicates repeated per-definition
  fingerprint and engine-version inputs.
- `ctx$feature_table` remains a plain data.frame field, but defaults to a
  schema-only zero-row frame instead of an eager full-panel long table.
- `ctx$features_wide` remains contract-compatible while using cheaper
  base-R data.frame stamping and direct per-pulse projection slices.
- The benchmark suite records raw and summarized outputs, environment metadata,
  LEAN side-by-side caveats, width sweeps, and peer-comparison provenance.
- Remaining performance gaps were attributed to owned lanes rather than left as
  unexplained residuals.

## Measurements

- LDG-2446 reduced the representative flat setup phase from 6.27s to 2.02s on
  the recorded current-source probe, about a 3.1x improvement.
- LDG-2447 made the default feature-table path schema-only and preserved full
  long construction only behind explicit opt-in; isolated view timings recorded
  schema-mode savings and retained inspection parity.
- LDG-2453/LDG-2455 improved wide-view manifestation without changing the public
  `ctx$features_wide` shape. The largest isolated view timing improved from
  0.33s to 0.19s in schema mode and from 2.44s to 1.15s in full-long mode.
- LDG-2456 named the remaining large read/score buckets: persistent writes,
  cache-key/setup, default view construction, fold loop, and accepted
  interpreter/DBI overhead.
- LDG-2457 recorded same-host SMA-crossover peer evidence. The durable ledgr row
  ran 313.42s (2,010 security-bars/sec); the sweep row ran 381.46s
  (1,652 security-bars/sec); Backtrader ran 114.46s (5,504 security-bars/sec).
  The comparison is local and matched by data/shape, but not event-accounting
  parity. Profiling named event buffering/emission as the dominant hot lane.

## Verification

- Targeted documentation-contract test: passed.
- Full `testthat::test_local()` via `pkgload::load_all()`: passed with one
  expected missing-package skip and existing warnings.
- `R CMD build --no-build-vignettes .`: passed.
- `R CMD check --no-manual --no-build-vignettes ledgr_0.1.8.6.tar.gz`: passed
  with two expected no-build-vignettes warnings about missing built vignette
  HTML/PDF artifacts.
- `tools/check-coverage.R`: passed at 84.70%.
- `pkgdown::build_site(new_process = FALSE, install = FALSE)`: passed after
  setting the local Quarto/Pandoc environment and using a local cache.

`R CMD build .` with vignette building enabled was attempted and failed on the
known Quarto/R build boundary where `.qmd` inputs rendered to `.md` but R's
build step expected `.html`. The release gate therefore used the documented
`--no-build-vignettes` package-check path plus pkgdown site build.

## Carry-Forward

v0.1.8.7 is the Optimization Round 2 handoff and remains RFC-first until a new
packet is cut. Its planned design lanes are:

- fold-core primitive R object/function contract;
- run-artifact materialization policy separating fast ephemeral sweep output
  from explicit durable promotion;
- event-buffering and emission lane, including collapse adoption behind the
  deterministic wrapper;
- cache-key/setup lane, including sealed-data trust-boundary implications;
- reconstruction lane;
- ADR 0004 dependency decisions: collapse in scope, cli/R6 dropped, tibble
  retained.

Parallel dispatch remains deferred to v0.1.8.8.

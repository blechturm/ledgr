# collapse Optimization Map (v0.1.8.7 input)

**Status:** Scope input for the v0.1.8.7 optimization round. Relates to ADR 0004
(adopt `collapse`, drop `cli`/`R6`, keep `tibble`) and
`inst/design/audits/fold_path_hotpath_audit.md`. Not a v0.1.8.6 deliverable.

**Premise:** `collapse` (2.1.x, pure C, zero transitive deps) is being adopted
for the hot-path lanes. This maps what it buys *beyond* the event-buffer fix —
checked against the full 382-export surface — ranked by impact on ledgr's actual
code, with the determinism gate attached.

## 2026-09-26/27 re-measurement against the release line

This map predates the v0.1.9 primitive-internals work. It was re-measured at `b14579f`, at release
shape; see `inst/design/spikes/fold_writer_accessor_levers_spike/summary_report.md`.

- ledgr now calls collapse only through `setv()`. The profiled fold, runner and sweep lanes no
  longer contain the grouped base reductions that Tier 1 targeted.
- A few grouped base reductions remain, all off the profiled hot paths. They are unmeasured
  GRP/`fsum` candidates:
  - `R/snapshot_adapters.R:135` (`tapply`);
  - `R/availability-facts.R:1728` (`ave`);
  - `rowsum` in corporate-action settlement and results;
  - `R/derived-state.R:199` (`tapply`);
  - `R/sweep-retention.R:769` (`ave`).
- `collapse::rsplit()` for bars by instrument was rejected: about 60 ms per call.
- A per-pulse block write of fill events with one `setv()` per column is green:
  - `ledgr_run` −10%;
  - one-candidate sweep −21%;
  - byte-identical results.
- The largest non-collapse lever is plain R: prepared fast-context feature accessors.
- The v0.1.9 gate still applies: more than 5% wall clock on the reference workload, pinned options
  and parity.

## Tier 1 — vectorize the loop-heavy, value-bearing lanes

### Reconstruction (Lane C) — `R/fold-core.R:445-901`

`ledgr_equity_from_events` / `ledgr_fills_from_events` /
`ledgr_sweep_summary_from_ordered_events` loop *per instrument* and *per event*.
collapse collapses those loops:

| collapse | replaces | site |
| --- | --- | --- |
| `fcumsum(x, g)` | per-instrument `cumsum(cash_delta)` / `cumsum(position_delta)` loops | fold-core.R ~503-516, 843-856 |
| `GRP` / `groupv` / `fsum` / `ffirst`/`flast` | grouped equity/position assembly | reconstruction |
| `rowbind` | `do.call(rbind, rows)` | fold-core.R:688 |
| `ss` / `get_vars` / `.subset2` | `events[i, , drop=FALSE]` + `$` per event | fold-core.R:575+ |
| `fmatch` / `funique` / `any_duplicated` | `match()` / `unique(events$instrument_id)` | reconstruction |
| `na_locf` / `na_focb` | findInterval carry-forward of positions/prices | positions matrix |

### Projection / features_wide — `R/runtime-projection.R` (spiked: NOT a perf lane)

Measured in `dev/spikes/spike-projection-collapse.md`: the full features_wide
build + df->matrix round-trip is ~0.74s/run (500x1260x50) — negligible vs the
buffer (~137s) or the wall. Corrected findings:

- **`mctl` dropped** — *slower* than the base-R `ledgr_fast_data_frame` stamp
  (0.41 vs 0.25s). Do not use it for the build.
- **`qM`** is 2x faster than `as.matrix` for the df->matrix conversion, but on a
  sub-second component — immaterial.
- **matrix-canonical surface** (strategy reads a matrix, skips `as.matrix(fw[...])`)
  saves only ~0.4s/run — justified by API/contract cleanliness + primitives-in-core,
  **not speed**. Belongs in the v0.1.8.7 *contract* RFC, not the perf lanes.
- `rsplit` remains the separate ~3x v0.1.9 "Phase B" win for the
  `feature_table="full"` path (not measured here). The 2026-09-26 spike measured
  `rsplit` at the two bars-by-instrument sites instead and rejected it there;
  this `feature_table="full"` site is still unmeasured.

## Tier 2 — clean, modest wins

- **Metrics** (`ledgr_metrics_from_equity_fills`, fold-core.R:911+): `fdiff`/`fgrowth`
  (returns), `fmean`/`fsd`/`fvar` (vol/Sharpe), `fcumsum`+`frange` (drawdown),
  `fmean(pnl>0)` (win rate). One-shot per run.
- **Result tables**: `qDF` / **`qTBL`** for boundary stamping — `qTBL` preserves
  the tidyverse signal (ADR 0004 keeps `tibble`), faster than `tibble::as_tibble`.
- **Event buffer**: finding #1 / the spike
  (`dev/spikes/spike-event-buffer-rewrite.R`; results
  `dev/bench/results/spike_event_buffer_rewrite.csv`). Two stacking levers, both
  tracemem-confirmed:
  - **(1) sizing (base R, no dep):** stop over-allocating to `n_inst*n_pulses`,
    grow by doubling -> **27-101x** (grows with scale). Still copies fills-sized
    columns, so O(fills^2).
  - **(2) write-op (`collapse::setv(col, i, v, vind1=TRUE)`):** in-place by
    reference (tracemem: no copy), true O(fills) -> **65-1300x** vs current, and
    its edge over base R *grows with turnover* (2.4x -> 12.9x from 2k -> 13k
    fills).
  Recommendation: ship the base-R sizing fix regardless (bulk of the win, no
  dep); use `setv` for the buffer since collapse is adopted anyway (completes it,
  pulls away on high turnover). Caveat: the isolated sim overestimates absolute
  cost ~3x vs the real ~137s buffer profile; trust the ratios + mechanism, the
  real-run re-profile is the verdict.

## Tier 3 — hot-path micro-ops (collapse doctrine)

`whichv`/`whichNA`/`anyv`/`allv`/`allNA` (index not logical subsetting); `%iin%`
(index match vs `%in%`); `roworderv` (radix sort for `order(event_seq)`);
`setop`/`%+=%` (in-place accumulation); `alloc` (fill-allocate vs `rep`);
`setattrib`/`copyMostAttrib`/`setColnames` (zero-copy attribute stamping).

## Out of scope (engine) — checked, not applicable

Analyst/research surfaces, not hot paths: `qsu`, `descr`, `pwcor`/`pwcov`,
`flm`, `fFtest`, `fdist`, `varying`, panel/HD operators (`fhdwithin`,
`fbetween`, `psmat`, `psacf`), `pivot`/`join` (no hot ledgr join), `recode_*`.
Some (`qsu`, `flm`) are candidate *research helpers* later, not optimization.

## Determinism gate — escalates with adoption

The event-buffer `setv` is **value-neutral** (an in-place write; needs only
event-stream parity, not the floating-point gate). Tier 1/2 are
**value-bearing**: `fcumsum`/`fmean`/`fdiff`/`fsd` results depend on collapse's
global options (`na.rm`, `sort`, `nthreads`). So the moment collapse touches
reconstruction, metrics, or projection, the **`ledgr_with_collapse_deterministic()`
wrapper is mandatory, not optional** — a hostile caller `set_collapse(na.rm=...)`
must not change a backtest's numbers. The wrapper **must pin `nthreads = 1L`**
(not just `na.rm`/`sort`): threaded reductions like `fsum`/`fmean` can reorder
floating-point accumulation and break byte-identity even with `na.rm` pinned
(Codex review, confirmed). Each value-bearing adoption needs a byte-identical
event/equity parity fixture, and calls should pass important args explicitly.
The wider the adoption, the more the wrapper + parity gates carry the
reproducibility USP.

## Discipline

Each lane is an *opportunity to measure*, not an assumed win (per the v0.1.8.6
measurement experience). Sequence: spike -> real-run re-profile -> parity gate
(byte-identical for value-bearing) -> ship. The buffer `setv` is the first; the
reconstruction (`fcumsum`/`GRP`) is the highest-value next.

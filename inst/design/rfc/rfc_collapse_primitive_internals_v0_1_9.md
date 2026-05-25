# RFC Seed: Collapse-Backed Primitive Internals And Accounting Acceleration

**Status:** Design seed - response required before synthesis or ticket cut.
**Date:** 2026-05-25
**Author:** Claude
**Inputs:**

- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`
  - accepted LDG-2413 pulse view consolidation
- `inst/design/spikes/ledgr_v0_1_8_3_pulse_view_construction/`
  - pulse view construction spike comparing base/data.table/tidyr/collapse
- LDG-2402 baseline measurement, LDG-2409 projection checkpoint,
  LDG-2411 fast-context B1 checkpoint, LDG-2413 prebuilt-views checkpoint.
- `https://fastverse.org/collapse/articles/developing_with_collapse.html`
  - collapse package design philosophy and primitive-objects recommendation.
- Maintainer discussion on dependency audit, primitive internals, and
  accounting/metrics acceleration.

---

## 1. Problem Statement

LDG-2413 has now landed with the nest/split refinement. Committed measurement
on the reference workload:

```text
                                  baseline    now      speedup
reference sweep_plain             45.585s     32.235s  1.41x
reference sweep_precomputed       45.490s     32.610s  1.40x
persistent sweep_plain             4.415s      2.675s  1.65x
persistent run_loop                9.420s      9.920s  0.95x
```

The big win landed in v0.1.8.3. `ledgr_projection_pulse_views()` is no longer
in the top profile frames after the split patch. The remaining hot frames
shifted to fill event construction and post-fold reconstruction, with
data.frame allocation in those paths as the residual cost.

The pulse view construction spike that triggered the split patch also surfaced
a deeper architectural lesson that this RFC carries forward. Reference-shaped
fixture, 50 candidate feature views, pre-split helper baseline:

```text
current helper           8.03s
base split               1.96s   (4.1x)
data.table (as df)       6.27s   (1.3x)
data.table (native)      5.06s   (1.6x)
tidyr::nest              3.64s   (2.2x)
collapse::rsplit         0.68s   (11.8x)
```

LDG-2413 shipped with base split, recovering the 4x of the 11x. The 3x gap
between base split and collapse remains available as a future optimization
target.

The collapse measurement combined with reading the collapse "developing with
collapse" article surfaces an architectural lesson that LDG-2413 only
partially addressed:

> Stop using `data.frame` as the internal canonical shape. Use vectors,
> matrices, and lists internally. Attach the `data.frame` class only at the
> public API boundary.

This is the same discipline collapse itself uses internally, and it is what
gives collapse its measured speed advantage. LDG-2413 applied this discipline
to pulse view construction. The lesson generalizes to other surfaces where
ledgr still constructs and tears down data.frame objects: fill event
boundaries, post-fold reconstruction, sweep result assembly, and metric
computation.

This RFC asks whether ledgr should commit to a primitive-internals design
discipline across the remaining surfaces, with collapse as a possible
acceleration layer where measured wins justify the dependency. collapse is no
longer the immediate trigger for this RFC; the architectural direction is.

---

## 2. Where data.frame Lives Internally Today

A non-exhaustive inventory of internal data.frame uses in the hot path or
adjacent code:

```text
pulse views (LDG-2413 surface):
  bars_views[[i]]                   data.frame per pulse
  feature_table_views[[i]]          data.frame per pulse
  features_wide_views[[i]]          data.frame per pulse

ctx public fields (LDG-2413 surface):
  ctx$bars                          data.frame per pulse (plucked from view)
  ctx$feature_table                 data.frame per pulse (plucked from view)
  ctx$features_wide                 data.frame per pulse (plucked from view)

fill event construction (largest residual hot frame):
  ledgr_fill_event_row()            primitive list write result
  ledgr_event_row_df()              list-to-data.frame boundary
  output_handler$append_event_rows  data.frame buffer / row append
  meta_json round-trips             jsonlite serialization of list

post-fold reconstruction:
  ledgr_fills_from_events()         data.frame manipulation
  ledgr_equity_from_events()        data.frame plus matrix mix
  realized_pnl / unrealized_pnl     data.frame columns

sweep result assembly:
  ledgr_sweep_failure_row()         data.frame per failed candidate
  ledgr_sweep_run_candidate()       row binding via do.call(rbind, rows)
  result list columns               nested data.frames

metric paths:
  ledgr_compute_metrics()           data.frame intermediate views
  ledgr_compare_runs()              comparison tibbles
  metric tables                     tibble-shaped outputs

precompute and feature payload:
  ledgr_precompute_features()       payload as named list of values
  feature library tables            mixed list/data.frame
```

Most of these data.frames exist because:

1. ledgr's public API contract returns data.frames at user-visible surfaces;
2. internal helpers were written to operate on data.frames because the
   construction shape was assumed to be authoritative;
3. accretion across v0.1.0 through v0.1.8 added more data.frame intermediates
   without revisiting whether the shape was load-bearing.

The article's insight: most of these data.frame intermediates should be lists
or matrices internally. The data.frame class should be attached only at the
public boundary, with `qDF()` or `structure(..., class = "data.frame", ...)`.

---

## 3. Proposed Direction

Adopt two related but separable disciplines:

### 3.1 Primitive Internals Design Discipline

Internally, ledgr uses:

- numeric matrices for per-instrument-per-pulse data;
- named lists for keyed collections;
- atomic vectors for per-pulse or per-instrument scalar series;
- plain lists for heterogeneous per-pulse views.

`data.frame` class is attached only at public API boundaries. Internal helpers
operate on the underlying primitive structures.

This discipline is independent of whether collapse is imported. It can be
adopted using base R primitives alone. The architectural benefit (cheaper
internal data passing, cleaner future Rust FFI, cleaner DuckDB column mapping)
is intrinsic to the discipline, not to collapse.

### 3.2 collapse As Acceleration Layer

Where the primitive-internals discipline produces measurable wall-clock wins
through collapse helpers, import collapse as an Imports dependency and use
collapse helpers internally.

Concrete candidate uses:

- `collapse::rsplit()` for pulse view splitting (12x measured)
- `collapse::rowbind()` for fill/sweep result row binding
- `collapse::fcumsum()` for cumulative reconstruction (cash, positions, equity)
- `collapse::GRP()` and `collapse::fgroup_by()` for grouped aggregates
- `collapse::qDF()` for cheap data.frame construction from lists
- `collapse::fmatch()` and `collapse::whichv()` for index-based filtering

Every collapse-backed ledgr entry point must execute inside the deterministic
`collapse::set_collapse()` wrapper described in Section 5. Where individual
collapse functions accept relevant arguments (`na.rm`, grouping order, stable
algorithms), pass them explicitly as well. Functions such as `rsplit()`,
`rowbind()`, and `qDF()` do not expose every option per call, so ledgr must not
pretend per-call arguments are a complete determinism policy.

---

## 4. Scope By Phase

The conversion is multi-phase. Each phase is its own ticket with parity tests.

### Phase A: Pulse Views (shipped in LDG-2413)

LDG-2413 already shipped pulse view construction with base R nest/split. The
1.41x measured speedup landed inside the predicted band. collapse::rsplit
would offer an incremental ~3x additional on the construction path alone
(from spike measurement), which translates to roughly 5-10% additional
wall-clock on the reference workload if collapse is imported.

This phase is **not v0.1.9 work**. It is recorded here for completeness and as
a future revisit target if the collapse dependency is taken on for Phases
B-D and a second collapse pass through the pulse view path becomes
incidentally available.

### Phase B: Fill Event Boundary And Buffer Assembly

The profile frame `ledgr_fill_event_row` at 13.8% does not represent a single
data.frame() call per fill. Current code constructs lists at the fill site;
the data.frame boundary is `ledgr_event_row_df()` and the output handler's
buffered append path. The 13.8% share is a mix of:

- list construction at the fill site
- list-to-data.frame conversion at the output handler boundary
- buffered event append data.frame operations
- meta_json round-trip serialization

Phase B targets the data.frame boundary specifically, not the list
construction. Primitive-internals discipline applies:

- Keep fill event construction as primitive lists at the call site.
- Defer data.frame attachment to the output handler buffer flush, not per-fill.
- Replace per-fill data.frame append patterns with bulk row binding at flush
  time.

**Required before claiming wall-clock savings:** a micro-profile of which
sub-paths inside the 13.8% are actually data.frame construction versus list
work versus meta_json serialization. The current RFC cannot honestly claim
"3-4s savings" without that decomposition. Treat the 13.8% frame as evidence
that this area is worth investigation, not as a guaranteed savings pool.

```text
current profile share: 13.8% (mixed: list + data.frame + meta_json)
target: data.frame boundary path specifically
expected savings: requires micro-profile before quantifying
```

### Phase C: Safe Cumulative Reconstruction (FIFO Replay Out Of Scope)

Two distinct reconstruction concerns must be separated:

**Phase C.1 (in scope): Safe vectorizable reconstruction.**

`cash_delta` and `position_delta` reconstruction via `findInterval + cumsum`
in the persistent path is already vectorized. Grouped per-instrument
cumulative operations using `collapse::fcumsum` with `GRP()` may improve this
where the algorithm is genuinely cumulative-over-a-grouping. Equity = cash +
positions_value reconstruction falls in this category.

```text
target: equity reconstruction, position curve, cash curve
expected reduction: requires per-phase measurement
```

**Phase C.2 (out of scope for this RFC): FIFO lot replay.**

`ledgr_lot_apply_event` and the realized/unrealized PnL derivation depend on
sequential mutable FIFO lot state. Long/short flips, opening positions, and
partial closes are path-dependent and not naturally vectorizable. LDG-2403
parity tests gate any change here.

A vectorized FIFO alternative may be possible in principle (interval
matching, cumulative quantity intersections), but it is **not in scope for
the primitive-internals + collapse RFC**. It requires its own design RFC
with explicit parity proof, algorithmic equivalence demonstration, and
floating-point determinism analysis.

This RFC's Phase C is explicitly the safe-vectorizable subset only. FIFO
redesign is parked.

### Phase D: Sweep Result Assembly

`ledgr_sweep_run_candidate()` and the sweep result row collection use
`do.call(rbind, rows)` for assembly. Replace with `collapse::rowbind()` or
base R `data.table::rbindlist()`-style bulk assembly equivalent.

```text
current cost: small but measurable
target: row binding step at sweep result aggregation
expected reduction: requires per-phase measurement
```

### Phase E: Metric Computation And Comparison

`ledgr_compute_metrics()` and `ledgr_compare_runs()` build comparison tibbles
through standard R idioms. Replace with primitive-internals construction
where measured wins justify the change.

```text
current cost: <5% of fold
target: metric table construction and comparison view assembly
expected savings: small; do opportunistically not as a focused ticket
```

### Hypothesized Cumulative Impact (Not A Prediction)

The phases above are independent hypotheses requiring per-phase measurement.
Adding profile shares as if they were independent savings overstates the
expected aggregate because Rprof by-total frames overlap (a single call site
contributes to multiple parent frames in the by-total view).

A grounded estimate requires per-phase before/after measurement on the LDG-2402
reference workload. The cycle should not commit to a numeric speedup target;
it should commit to the architectural discipline and report per-phase results.

If pressed for a rough hypothesis: Phases B + C.1 combined plausibly deliver
10-20% additional wall-clock improvement on the reference workload, taking
the post-v0.1.8.3 32.2s down to ~26-29s. Phase D is incidental (<2%). Phase E
is negligible at the workload sizes ledgr targets. Parallel dispatch
(v0.1.8.7) is a separate compounding question and out of scope for this RFC's
numbers.

Treat these as hypotheses to test, not commitments to deliver.

---

## 5. Dependency Considerations

### Why collapse Specifically

The pulse view spike compared base, data.table, tidyr, and collapse. collapse
won by a wide margin on the patterns ledgr uses (split by many small groups,
row binding, grouped cumulative operations). data.table was slower than base
split for these patterns because data.table has higher per-call overhead and
is optimized for fewer larger groups.

collapse's design philosophy (primitive internals, explicit options, minimal
side effects) matches ledgr's determinism requirements better than
tidyverse-style alternatives.

### Dependency Profile

collapse imports:

- `Rcpp` (usually already present in R installations)
- no recursive tidyverse dependencies

Install footprint: small. CRAN provides binaries for major platforms.

### Bus Factor

collapse is primarily maintained by Sebastian Krantz. Single-maintainer
projects carry risk. Mitigation:

- collapse is mature (~5 years of CRAN releases);
- API has been stable across recent versions;
- the patterns ledgr would use (`rsplit`, `rowbind`, `fcumsum`, `GRP`) are
  long-stable core helpers;
- ledgr pins collapse to a tested version range in DESCRIPTION.

### Determinism Contract

ledgr's pitch is deterministic execution across machines and sessions.
collapse has user-tunable options that affect output:

```text
collapse.nthreads      - parallelism in some operations
collapse.na.rm          - default NA handling
collapse.sort           - default ordering behavior
collapse.stable.algo    - stable vs unstable algorithms
```

A naive "always pass options explicitly at every call site" policy is
**impossible as stated**: collapse functions like `rsplit()`, `rowbind()`,
`qDF()`, `fmatch()`, and `whichv()` do not accept `nthreads` or `na.rm` as
arguments. Those defaults come from `set_collapse()` global configuration,
not per-call arguments.

The correct discipline is a scoped wrapper that sets and restores the
collapse global configuration around any ledgr code that uses collapse
helpers:

```r
ledgr_with_collapse_deterministic <- function(expr) {
  changed_options <- c("nthreads", "na.rm", "sort", "stable.algo")
  previous <- collapse::get_collapse(changed_options)
  collapse::set_collapse(
    nthreads    = 1L,
    na.rm       = FALSE,
    sort        = TRUE,
    stable.algo = TRUE
  )
  on.exit(do.call(collapse::set_collapse, previous), add = TRUE)
  force(expr)
}

# Usage at every entry point that triggers collapse-backed work:
ledgr_with_collapse_deterministic({
  pulse_views <- collapse::rsplit(big_table, by = pulse_idx)
  ...
})
```

This pattern:

- Sets known-deterministic defaults for all collapse calls inside the
  expression.
- Captures and restores only the settings ledgr changes
  (`nthreads`, `na.rm`, `sort`, `stable.algo`) so namespace/export settings
  such as `mask` or `remove` are left alone.
- Works uniformly for functions that take per-call options
  (`fcumsum(..., na.rm = ...)`) and functions that don't (`rsplit()`).
- Documents the determinism intent at the call site.

Where individual functions accept relevant arguments (`fcumsum`, `fmean`,
`fsd`), pass them explicitly anyway as belt-and-braces and to make intent
visible in code review.

The scoped wrapper is mandatory for every collapse-backed ledgr entry point,
including non-accounting paths. Determinism-critical paths still require the
extra floating-point and parity checks below.

### Floating-Point Determinism

collapse uses C++ implementations of cumulative operations. These may produce
different floating-point results than base R's vectorized operations due to
accumulation order and SIMD usage. For LDG-2403 parity-tested paths
(realized/unrealized PnL, equity reconstruction), this needs verification:

```text
collapse::fcumsum(deltas) == cumsum(deltas)?
collapse::fmean(x) == mean(x)?
```

Likely yes within 1e-12 for non-pathological inputs, but the parity test
tolerance (1e-10) must hold.

**Required spike before any collapse adoption in determinism-critical code:**

- Run LDG-2403 accounting parity fixtures with collapse-backed
  reconstruction. Assert max-abs-diff < 1e-12 vs base R reference.
- Vary `set_collapse()` settings (especially `nthreads = 1L` vs
  `nthreads = 4L`) and verify outputs are identical when ledgr uses the
  deterministic wrapper.
- Verify behavior is independent of caller-side `collapse::set_collapse()`
  configuration (start with deliberately-wrong defaults, confirm wrapper
  overrides them).

If the floating-point parity spike fails, collapse cannot be used in
accounting paths and Phase C.1 falls back to base R cumulative operations.

---

## 6. Relationship To Other v0.1.x Work

### LDG-2413 (v0.1.8.3, shipped)

LDG-2413 has landed with the base R nest/split implementation. The dependency
decision was deferred per maintainer direction: collapse stays optional, base
split delivers the cycle's predicted win (1.41x measured on reference). The
~3x gap between base split and `collapse::rsplit` remains available if a
future cycle pulls collapse in for other reasons (Phases B-D).

Phase A is therefore **not v0.1.9 work**. If collapse is imported during
v0.1.9 to support Phases B-D, revisiting the pulse view path with
`collapse::rsplit` becomes an incidental incremental optimization. If
collapse is not imported, pulse views stay on base split indefinitely.

### v0.1.8.4 Active Aliases

Active aliases land per-candidate alias maps that resolve aliases to concrete
feature IDs. Primitive-internals discipline applies cleanly: alias maps are
named integer vectors, not data.frames. No conflict.

### v0.1.8.6 DuckDB-Backed Feature Storage

Primitive-internals makes the DuckDB-backed projection storage path simpler
because matrices map to DuckDB columns directly without intermediate
data.frame conversion.

### v0.1.8.7 Parallel Dispatch

Worker processes inherit the primitive-internals discipline. Per-worker
memory footprint is smaller (no data.frame overhead) which helps with
parallel scaling memory pressure.

### v0.2.x Rust Fold Harness

The biggest downstream benefit. Rust handles vectors, matrices, and lists
natively via extendr. R data.frames are awkward to marshal across FFI
because of their attribute-heavy nature. Primitive-internals reduces FFI
marshalling cost by 2-3x compared to data.frame-internals.

This RFC indirectly makes the Rust port substantially easier when it lands.

---

## 7. Architecture For Public API Boundary

The public API contract continues to return data.frames at user-visible
surfaces. The conversion happens at the boundary. Note that in the current
code, timestamp is not a matrix field in `bars_mat`; it comes from the
pulses_posix / pulses_iso vectors built once per fold setup. The internal
helper takes those as arguments alongside the bars matrix:

```r
# Internal: primitive list with named numeric/character vectors
ledgr_internal_make_pulse_view <- function(bars_mat, pulse_idx, instrument_ids,
                                            pulses_posix) {
  list(
    instrument_id = instrument_ids,
    ts_utc        = rep(pulses_posix[[pulse_idx]], length(instrument_ids)),
    open          = bars_mat$open[, pulse_idx],
    high          = bars_mat$high[, pulse_idx],
    low           = bars_mat$low[, pulse_idx],
    close         = bars_mat$close[, pulse_idx],
    volume        = bars_mat$volume[, pulse_idx],
    gap_type      = bars_mat$gap_type[, pulse_idx],
    is_synthetic  = bars_mat$is_synthetic[, pulse_idx]
  )
}

# Boundary: attach data.frame class for public ctx field.
# Centralize in one place (e.g. R/internal-views.R) so column order,
# row.names format, and class chain are pinned by one helper, not
# scattered across boundary call sites.
ledgr_public_bars_view <- function(internal_view) {
  expected <- c("instrument_id", "ts_utc", "open", "high", "low",
                "close", "volume", "gap_type", "is_synthetic")
  internal_view <- internal_view[expected]

  # Without collapse:
  structure(
    internal_view,
    class = "data.frame",
    row.names = c(NA, -length(internal_view$instrument_id)),
    names = expected
  )
  # With collapse (optional):
  # collapse::qDF(internal_view[expected])
}
```

The boundary helper should live in a single internal file (suggested
`R/internal-views.R`) so the column order, row.names format, and class
chain are pinned in one place. Scattering this across the call sites for
each ctx field would mean three places to update when the boundary policy
changes.

Internal helpers (`ledgr_make_ctx`, accounting, reconstruction) operate on the
internal list shape. The public boundary attaches `data.frame` class once.

Strategy code reads `ctx$bars$close` exactly as today. The data is identical;
only the internal construction path changed.

---

## 8. Verification Requirements

Any accepted phase must require tests for:

- bit-exact fold parity between current implementation and primitive-internals
  implementation on the LDG-2402 reference workload;
- LDG-2403 accounting parity tests continue to pass on the new path;
- metric-context parity continues to pass;
- fingerprint stability pins remain unchanged;
- floating-point determinism for collapse-replaced operations within the
  existing 1e-10 tolerance;
- public ctx field shapes (column types, ordering, ts_utc behavior) preserved;
- determinism when caller-side `collapse::set_collapse()` state is changed
  before ledgr entry points run; ledgr wrappers must override and restore the
  relevant collapse settings;
- determinism across collapse versions in DESCRIPTION pin range;
- post-change measurement against LDG-2402 baseline, reported in cycle
  residual report.

The state-leak fixtures from LDG-2413 Section 7 carry forward unchanged. The
primitive-internals refactor must not break those invariants.

---

## 9. Non-Goals

This RFC does not propose:

- a second execution engine;
- vectorized strategy execution (strategy callback contract preserved);
- public ctx API field type changes (still data.frame-shaped at the boundary);
- removing tibble from DESCRIPTION (separate decision);
- removing R6 from DESCRIPTION (separate decision);
- FIFO lot apply redesign (separate, larger architectural concern);
- compiled C / Rust fold kernels (different cycle, v0.2.x);
- DuckDB-backed projection storage (v0.1.8.6 horizon);
- active aliases or alias-map identity (v0.1.8.4);
- public ML training-frame APIs;
- reliance on user `collapse::set_collapse()` state or startup
  `options(collapse.*)` for behavior;
- collapse as Suggests-only with conditional loading;
- weakening snapshot, no-lookahead, FIFO accounting, metric-context, or
  execution-seed contracts.

---

## 10. Open Questions For Response

1. Should collapse be added as an Imports dependency in v0.1.9 packet, or
   evaluated phase-by-phase with each non-Phase-A phase having to prove its
   own measured value before the dependency is taken?
2. Is Phase B's data.frame boundary inside the output handler the right
   target, or should the conversion live somewhere else (e.g., per-fill list
   stays primitive all the way through to the post-fold summary helper)?
3. What floating-point determinism evidence is required before committing to
   collapse in any accounting-adjacent path (Phase C.1)? Spike running
   LDG-2403 fixtures against a collapse-backed equity reconstruction with
   max-abs-diff < 1e-12 assertion?
4. Are Phases B + C.1 + D in scope for v0.1.9, with E deferred? Or is C.1
   alone enough to test the discipline and the rest deferred to v0.1.9.x?
5. How should the collapse version pin work in DESCRIPTION? Conservative
   upper bound at a tested version, or open-ended trust collapse's
   compatibility guarantees?
6. Should the primitive-internals discipline be documented in a developer
   guide (`inst/design/architecture/primitive_internals.md`) or only
   communicated through code review?
7. The `ledgr_with_collapse_deterministic()` wrapper sets and restores
   `set_collapse()` global state. Is per-call wrapping (every helper that
   uses collapse wraps its own call) sufficient, or do we want a
   package-level lifecycle hook (load-time `set_collapse()` reset, with
   per-call wrappers as the inner discipline)?
8. For Phases B and C.1, are LDG-2403 parity tests sufficient, or do we
   need additional fixtures specifically for collapse-backed
   reconstruction paths?
9. Does the primitive-internals discipline have implications for the public
   `as.data.frame.ledgr_*` methods, or do those continue to operate on
   whatever the field currently is?
10. The cumulative speedup section is now framed as hypotheses, not
    predictions. Should the response require per-phase measurement gates
    (each phase ships only if its measured win meets a per-phase threshold)
    or trust the discipline and let the cumulative result land?

---

## 11. Suggested Next Step

Write a response that takes positions on:

- collapse Imports decision (yes/no/conditional);
- phase ordering and v0.1.9 scope;
- whether to revisit Phase A only if collapse is imported for Phases B-D;
- determinism evidence requirements;
- collapse version pin policy;
- primitive-internals documentation surface.

If the response accepts the recommended direction, draft a synthesis that
binds:

- phase prioritization and cycle scope;
- dependency adoption details;
- determinism contract for collapse usage;
- parity test requirements per phase;
- measurement gates per phase;
- documentation surface decisions.

If the response rejects the dependency, the primitive-internals discipline
can still be adopted using base R helpers alone, with smaller measured wins.
The synthesis would then drop collapse but preserve the architectural
direction.

# RFC Synthesis: Pulse Context Data Model Consolidation

**Status:** Accepted synthesis - binding amendment for LDG-2413 and the
v0.1.8.3 spec packet.
**Date:** 2026-05-25
**Author:** Claude
**Thread:**

- `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3.md`
- `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md`
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md`
- `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_tickets.md`
- `inst/design/ledgr_v0_1_8_3_spec_packet/tickets.yml`
- LDG-2402 baseline measurement, LDG-2409 projection checkpoint, LDG-2411
  fast-context B1 checkpoint.

**Response step skipped intentionally.** RFC seed v2 absorbed reviewer
positions directly (quantified memory, audit prerequisite, state-leak invariant
tightening, candidate-share options, active-alias interaction, remeasurement
verification, `run_feature_matrix` cleanup). The seed-to-synthesis flow without
a separate response document reflects that the review iteration happened inside
the seed, not as a separate position document. Future readers tracing the RFC
chain should treat seed v2 as the position-bearing document.

---

## 1. Decision Summary

The pulse-context data model has accreted multiple representations of the same
static per-pulse data. LDG-2409 introduced the runtime projection as the
indexed truth for feature values, and LDG-2411 fast-context B1 reused helper
closures across pulses. But the fold still rebuilds public data-frame views
(`ctx$bars`, `ctx$feature_table`, `ctx$features_wide`) on every pulse, which
the LDG-2411 checkpoint profile shows as the dominant remaining R-level cost.

This synthesis accepts the seed's Option B direction:

- LDG-2413 is rescoped from "Fast Context B2 Index-Backed Context Proxies"
  to "Pulse Context Data Model Consolidation."
- Static per-pulse views (`ctx$bars`, `ctx$feature_table`, `ctx$features_wide`)
  are built once at fold setup and plucked by index in the hot loop.
- Helper closures, projection-backed scalar accessors, and dynamic state
  (cash, equity, positions, state_prev) keep their current LDG-2411 lifecycle.
- `run_feature_matrix` is removed from the fold execution contract. Its
  setup-only role in `ledgr_run_fold()` may remain as an intermediate or be
  replaced by direct projection construction.
- `ctx$feature_table` disposition is gated on a usage audit and resolved before
  LDG-2413 implementation starts.

Option A (narrow proxy patch), Option C (lazy view objects), and Option D
(literal pmap fold) are all explicitly rejected for v0.1.8.3.

---

## 2. Accepted Architecture

The pulse context is the merge of two layers:

```text
static pulse data                       dynamic fold state
  ts_utc                                  cash
  universe                                equity
  bars view (per pulse)                   positions
  feature_table view (per pulse)          state_prev
  features_wide view (per pulse)          safety_state
  projection-backed feature accessors     current targets / hold targets
  reused helper closures                  ledger events accumulated so far
```

The static layer is built once at fold setup and indexed by `pulse_idx` in the
hot loop. The dynamic layer evolves as a state transition driven by strategy
results and fill processing.

The fold remains imperative:

```r
state <- initial_state
for (pulse_idx in seq_along(pulses)) {
  ctx <- ledgr_make_ctx(
    static_pulse_views[[pulse_idx]],
    state,
    fast_context_helpers,
    pulse_idx
  )
  result <- strategy(ctx, params)
  state <- ledgr_apply_strategy_result(result, state, ...)
}
```

This is not vectorization. It is the same imperative fold ledgr already has,
with the per-pulse data-frame construction work moved out of the loop into
setup.

---

## 3. Prebuilt View Construction

### Bars Views

Bars views have two distinct construction lifetimes depending on entry point.

**`ledgr_run()` (single candidate):** built once at run setup, before the fold
loop:

```r
# Inside ledgr_run_fold, after bars_mat is built:
bars_views <- vector("list", n_pulses)
for (i in seq_len(n_pulses)) {
  bars_views[[i]] <- ledgr_build_bars_view(bars_mat, i, instrument_ids)
}
# Pass bars_views into the fold execution list.
```

**`ledgr_sweep()` (grid of candidates):** built once at sweep setup, before
the candidate loop, and threaded through every candidate's fold:

```r
# Inside ledgr_sweep, after bars_mat is built (same snapshot + universe +
# pulses for all candidates):
bars_views <- vector("list", n_pulses)
for (i in seq_len(n_pulses)) {
  bars_views[[i]] <- ledgr_build_bars_view(bars_mat, i, instrument_ids)
}
# Pass bars_views into each candidate's ledgr_sweep_run_candidate call.
```

This is the "sweep-shared" lifetime: one allocation paid for the entire sweep,
plucked by every candidate. Memory pays once, not 50 times. The shared object
identity also enables the cross-candidate state-leak test in Section 7.

Each `bars_views[[i]]` is a data.frame with the existing `ctx$bars` schema:
`instrument_id`, `ts_utc`, `open`, `high`, `low`, `close`, `volume`,
`gap_type`, `is_synthetic`. Column order, types, and missing-value semantics
must match the current `bars_df` mutation path bit-exact.

The single-candidate case (`ledgr_run`) is **not** the degenerate sweep case
for construction purposes - it's its own simpler path that builds views inside
`ledgr_run_fold`. The shared concept is "bars views are pulse-indexed and
built once before any fold iteration starts," which holds for both entry
points; the actual code paths differ.

### Feature Views

Feature views are candidate-specific in the first pass. Each candidate's
`feature_table` and `features_wide` are built from the runtime projection
restricted to that candidate's declared `feature_ids`:

```r
candidate_feature_views <- function(projection, feature_ids, n_pulses,
                                    instrument_ids) {
  feature_table_views <- vector("list", n_pulses)
  features_wide_views <- vector("list", n_pulses)
  for (i in seq_len(n_pulses)) {
    feature_table_views[[i]] <- ledgr_projection_feature_table(
      projection, i, feature_ids = feature_ids
    )
    features_wide_views[[i]] <- ledgr_projection_features_wide(
      projection, i, feature_ids = feature_ids
    )
  }
  list(
    feature_table = feature_table_views,
    features_wide = features_wide_views
  )
}
```

Candidate-specific construction is the safest first-pass policy. Grid-union
shared views with per-candidate column selection is recorded as a future memory
optimization and named in Section 10.

### Fast Context Integration

The B1 fast context (reused helper closures, projection-backed scalar
accessors) is preserved. The pulse-context constructor merges prebuilt views
with B1 helpers and dynamic state per pulse:

```r
ledgr_make_ctx <- function(static_views, dynamic_state, fast_context,
                           pulse_idx) {
  fast_context$feature_state$pulse_idx <- pulse_idx
  ledgr_refresh_pulse_context_lookup(
    fast_context$lookup,
    bars = static_views$bars,
    positions = dynamic_state$positions,
    universe = static_views$universe
  )
  list(
    run_id        = dynamic_state$run_id,
    ts_utc        = static_views$ts_utc,
    universe      = static_views$universe,
    bars          = static_views$bars,
    feature_table = static_views$feature_table,
    features_wide = static_views$features_wide,
    cash          = dynamic_state$cash,
    equity        = dynamic_state$cash + dynamic_state$positions_value,
    positions     = dynamic_state$positions,
    state_prev    = dynamic_state$state_prev,
    safety_state  = "GREEN",
    seed          = dynamic_state$execution_seed,
    feature       = fast_context$feature,
    features      = fast_context$features,
    bar           = fast_context$helpers$bar,
    open          = fast_context$helpers$open,
    high          = fast_context$helpers$high,
    low           = fast_context$helpers$low,
    close         = fast_context$helpers$close,
    volume        = fast_context$helpers$volume,
    position      = fast_context$helpers$position,
    flat          = fast_context$helpers$flat,
    hold          = fast_context$helpers$hold,
    targets       = fast_context$helpers$targets,
    current_targets = fast_context$helpers$current_targets,
    .pulse_lookup = fast_context$lookup
  )
}
```

The hot loop allocates one outer list per pulse plus the integer
`pulse_idx` assignment plus the lookup-env refresh. No per-pulse data.frame
construction. No per-pulse closure construction.

---

## 4. ctx$feature_table Disposition

The seed leaves this as an open question. This synthesis binds the resolution
as **audit-first, decide before implementation starts.**

### Required Audit

Before LDG-2413 implementation begins, run a usage audit:

```bash
grep -rn "ctx\$feature_table\|feature_table" \
  vignettes/ tests/ inst/examples/ R/
```

Classify each hit as:

- **Strategy usage** - a documented or example strategy reads
  `ctx$feature_table` as part of its decision logic.
- **Validator/error-helper** - internal ledgr code reads
  `ctx$feature_table` for schema validation or error message construction.
- **Test scaffold** - tests verify `ctx$feature_table` shape but no strategy
  pattern under test relies on the field.

### Decision Rule

| audit outcome | binding decision for v0.1.8.3 |
| --- | --- |
| Any documented strategy usage | Prebuild `ctx$feature_table` per pulse with current schema |
| Validator-only and test-scaffold usage | Prebuild `ctx$feature_table` per pulse with current schema; record a future-deprecation note in `inst/design/horizon.md` for a later cycle to address through a proper deprecation contract |

There is no in-v0.1.8.3 deprecation path. A "deprecation warning on access"
would require active bindings or a function-valued field, both of which the
non-goals list rejects (Section 15). A bare data.frame field cannot warn on access
without those mechanisms. The audit therefore either confirms strategy usage
(prebuild and ship as-is) or confirms no strategy usage (prebuild for
contract preservation, and park the deprecation conversation for a later
cycle where the active-binding question can be revisited on its own merits).

The audit is required because the future-deprecation note depends on audit
findings, but the v0.1.8.3 outcome is the same either way: prebuild
`ctx$feature_table` per pulse with the current schema.

The audit and the prebuild work are LDG-2413 implementation prerequisites.
They block ticket-cut completion, not the rescope itself.

---

## 5. run_feature_matrix Cleanup

`run_feature_matrix` has two distinct roles in the current code:

1. **Setup-only matrix construction in `ledgr_run_fold`** at
   `R/backtest-runner.R:1241` and used at `R/backtest-runner.R:1259` to build
   `runtime_projection` via `ledgr_projection_from_feature_matrix`. This
   construction is still load-bearing: the projection has to be built from
   something, and the matrix is the current intermediate.
2. **Legacy fallback input in `ledgr_execute_fold`** via the
   `if (is.null(runtime_projection))` conditional. This branch never fires in
   production because LDG-2409 made the projection mandatory. It is dead.

LDG-2413 scope:

- **Remove from fold execution contract.** Drop `run_feature_matrix` from the
  fold execution list. Remove the `is.null(runtime_projection)` conditional in
  `ledgr_execute_fold`. The fold consumes only the projection.
- **Setup-only role may stay or be replaced.** The implementing agent may
  either keep `run_feature_matrix` as a local setup-only intermediate in
  `ledgr_run_fold` (released after `runtime_projection` is built) or replace
  it by building the projection directly from feature defs and bars. The
  choice is left to the implementer based on which path is simpler; the only
  binding constraint is that the matrix cannot survive into the fold execution
  contract.
- **Sweep path** in `ledgr_sweep_run_candidate` already does not need
  `run_feature_matrix` post-LDG-2409. Verify by inspection that the parameter
  is removed cleanly.

Default position: remove the fallback branch in `ledgr_execute_fold`, decide
between setup-matrix-as-intermediate vs direct-projection-build inside
`ledgr_run_fold` based on simpler implementation. Either is acceptable.

If the legacy `is.null(runtime_projection)` branch is retained for parity
testing, document why and how in the LDG-2413 completion notes.

---

## 6. Memory And Performance

### Memory Cost

Quantified for two workloads:

| workload | bars (shared) | features per-candidate | total |
| --- | --- | --- | --- |
| reference (4 inst, 5 feat, 252 pulses, 50 candidates) | ~250 KB | ~125 KB x 50 = ~6.3 MB | **~6.5 MB** |
| parallelism-spike scale (250 inst, 50 feat, 2520 pulses, 50 candidates) | ~80 MB | ~50 MB x 50 = ~2.5 GB | **~2.6 GB** |

The reference workload is trivial. The parallelism-spike scale exceeds typical
R session memory and is the limiting factor for the candidate-specific policy.

If wider-workload memory becomes load-bearing, the grid-union view with
per-candidate column selection (named Section 10) is the future fallback. v0.1.8.3
does not implement that fallback.

### Performance Forecast

Estimated reference workload impact based on LDG-2411 checkpoint
(43.245s, ~40% data.frame share):

| state | reference workload | speedup vs LDG-2402 |
| --- | --- | --- |
| LDG-2411 (current) | 43.245s | 1.05x |
| + Option A narrow proxy | ~40s | 1.14x |
| **+ Option B prebuilt views (this synthesis)** | **~30s** | **1.5x** |
| + Option B with `ctx$feature_table` deprecated | ~26-28s | 1.6-1.75x |

Option B is the difference between "ledgr is 5-15% faster" and "ledgr is 50%+
faster" on the target workload.

LDG-2414 reference measurement is the empirical gate. There is no fixed
numeric target. The release gate remains the existing evidence-based
formulation: measured improvement, no correctness drift, no `ledgr_run()`
regression, residual report.

---

## 7. State-Leak Contract

Prebuilt views are referenced from the hot loop, not constructed fresh per
pulse. Each pulse_idx has a distinct view object identity, but the SAME object
is plucked every time that pulse_idx is iterated.

Strategy mutation of a captured view must not:

- propagate to that pulse's next iteration in any sweep candidate;
- propagate to any other pulse's view;
- corrupt the bars or feature data underlying the prebuilt views.

### Required Test Fixtures

The naive "capture, mutate after the run, compare" pattern is **insufficient**
because R copy-on-modify can mask shared mutable storage by allocating a fresh
object on the post-run mutation, making the test pass even when the
implementation does share storage during the run. The real invariant is "a
view captured at pulse t is unchanged by what happens at pulse t+1 *during* the
fold," and the test must observe that during execution.

**Fixture 1: in-run capture survives later pulses.**

```r
testthat::test_that("captured pulse view is unchanged by later pulse fold work", {
  observed <- new.env(parent = emptyenv())
  observed$pulse_n <- 0L
  observed$pulse1_view <- NULL
  observed$pulse1_snapshot <- NULL
  observed$pulse3_check <- NULL

  strategy <- function(ctx, params) {
    observed$pulse_n <- observed$pulse_n + 1L
    if (identical(observed$pulse_n, 1L)) {
      # Pulse 1: capture the view and a deep copy of its current state.
      observed$pulse1_view <- ctx$features_wide
      observed$pulse1_snapshot <- as.list(ctx$features_wide)
    } else if (identical(observed$pulse_n, 3L)) {
      # Pulse 3 (after pulse 2 fold work has run): verify pulse 1's
      # captured view has not been mutated by pulse 2's iteration.
      observed$pulse3_check <- as.list(observed$pulse1_view)
    }
    ctx$flat()
  }

  # Run with at least 3 pulses so pulse 2 fold work executes
  # between capture at pulse 1 and check at pulse 3.
  ledgr_run(experiment, params = list(), run_id = "leak-test")

  testthat::expect_equal(observed$pulse3_check, observed$pulse1_snapshot)
})
```

This pins the invariant: pulse 1's captured view at pulse 3 must equal pulse 1's
captured view at pulse 1. If the implementation shared mutable storage that
pulse 2 updated, this test catches it.

**Fixture 2: in-strategy mutation does not propagate to other pulses.**

```r
testthat::test_that("strategy mutation of one pulse view does not corrupt others", {
  observed <- new.env(parent = emptyenv())
  observed$pulse1_features <- NULL
  observed$pulse2_features <- NULL

  strategy <- function(ctx, params) {
    if (is.null(observed$pulse1_features)) {
      # Pulse 1: record original values, then attempt to mutate.
      observed$pulse1_features <- as.list(ctx$features_wide)
      tryCatch(
        ctx$features_wide[1, ncol(ctx$features_wide)] <- -999,
        error = function(e) NULL  # acceptable if view is read-only
      )
    } else if (is.null(observed$pulse2_features)) {
      # Pulse 2: read features and ensure pulse 1's mutation did not
      # leak through shared storage.
      observed$pulse2_features <- as.list(ctx$features_wide)
    }
    ctx$flat()
  }

  ledgr_run(experiment, params = list(), run_id = "mutation-test")

  # Pulse 2's feature values must not contain the -999 sentinel.
  testthat::expect_false(any(unlist(observed$pulse2_features) == -999))
})
```

This pins the harder invariant: even an active in-strategy write to the view
must not corrupt other pulses. Either the view is functionally immutable
(write is a no-op or errors) or the write produces a fresh copy that doesn't
touch the underlying source. Either is acceptable; what's not acceptable is
shared mutable storage that lets a strategy poison later pulses.

**Fixture 3: cross-candidate isolation in sweep mode.**

```r
testthat::test_that("strategy mutation in candidate A does not corrupt candidate B", {
  observed <- new.env(parent = emptyenv())
  observed$candidate_A_pulse1 <- NULL
  observed$candidate_B_pulse1 <- NULL
  current_candidate <- "A"

  strategy <- function(ctx, params) {
    if (identical(current_candidate, "A") && is.null(observed$candidate_A_pulse1)) {
      observed$candidate_A_pulse1 <- as.list(ctx$bars)
      tryCatch(
        ctx$bars[1, "close"] <- -999,
        error = function(e) NULL
      )
    } else if (identical(current_candidate, "B") && is.null(observed$candidate_B_pulse1)) {
      observed$candidate_B_pulse1 <- as.list(ctx$bars)
    }
    ctx$flat()
  }

  # Sweep with two candidates; mode toggle between them via current_candidate.
  # (Implementation may use a helper that sets current_candidate per candidate
  # before each candidate fold begins.)
  ledgr_sweep(...)

  # Candidate B's bars at pulse 1 must not contain the -999 sentinel
  # from candidate A's mutation.
  testthat::expect_false(any(unlist(observed$candidate_B_pulse1) == -999))
})
```

All three fixtures must be exercised for:

- `ctx$features_wide`
- `ctx$bars`
- `ctx$feature_table`

Fixtures 1 and 2 cover `ledgr_run()` and `ledgr_sweep()` (single candidate).
Fixture 3 is sweep-mode-only and is required because sweep-shared bars views
are the highest-risk case.

---

## 8. Verification Requirements

The LDG-2413 ticket cut must require tests for:

- Bit-exact fold parity between LDG-2411 (current projection+B1) and prebuilt
  views on the reference workload event stream.
- `ctx$bars` schema (columns, types, ordering, `ts_utc` behavior) byte-identical
  to the current `bars_df` mutation path.
- `ctx$features_wide` schema byte-identical to LDG-2411's projection wide-view
  output.
- `ctx$feature_table` schema is prebuilt and preserved in v0.1.8.3; if the
  audit finds no strategy usage, a future-deprecation note is recorded in
  `inst/design/horizon.md`.
- State-leak fixtures from Section 7 pass for all three views and both execution
  paths.
- Candidate-specific feature view restriction verified for sweep mode (candidate
  A sees only its declared `feature_ids`, not the grid union).
- Cross-candidate state-leak fixture passes.
- Existing `tests/testthat/test-fingerprint-stability.R` pins remain unchanged.
- Existing LDG-2403 accounting parity tests remain green.
- Metric-context parity tests remain green.
- `ledgr_run()` single-candidate wall-clock measurement, recorded relative to
  LDG-2411 checkpoint, must not regress materially.
- Peak memory measurement during a reference-workload sweep, recorded for the
  residual report.
- LDG-2402 reference workload remeasurement, recorded with profile delta versus
  LDG-2411 checkpoint, reported in LDG-2414 residual hot-path report.

---

## 9. LDG-2410 And LDG-2412 Maintainer Decision Recommendation

Per the seed's expected follow-up Section 12 step 5, this synthesis flags
LDG-2410 (typed memory events) and LDG-2412 (single-pass summary) for an
explicit maintainer decision after LDG-2413 measurement, but does not bind a
hard rule. Release-sequencing decisions live outside the data-model synthesis's
scope.

The LDG-2414 residual report should include the data needed to make the
decision:

- Post-fold reconstruction sampled-time share
  (`ledgr_equity_from_events`, `ledgr_fills_from_events`,
  `ledgr_metrics_from_equity_fills`, or successor frames).
- Wall-clock contribution of post-fold reconstruction on the reference and
  wider workloads.
- Memory pressure or GC cost specific to the reconstruction path.

The recommendation for the maintainer is:

- If post-fold reconstruction is a small share of total time AND v0.1.9
  risk-chain work is expected to touch the same reconstruction code path:
  bundling LDG-2410 + LDG-2412 with v0.1.9 reduces churn and may be the
  cleaner sequencing.
- If post-fold reconstruction is a meaningful share OR if LDG-2410's typed
  event representation has value beyond performance (provenance, debugging,
  test surface): keep them in v0.1.8.3.

This is a recommendation, not a binding rule. The maintainer evaluates the
LDG-2414 evidence and decides. If deferred, the v0.1.9 packet picks up the
tickets; if retained, v0.1.8.3 closes them as originally planned.

If deferred, update `inst/design/horizon.md` and
`inst/design/ledgr_roadmap.md` to record the v0.1.9 bundling intent and the
measurement evidence justifying it.

---

## 10. Active-Alias Interaction (v0.1.8.4)

The active-parameterized-feature-aliases synthesis introduces per-candidate
alias maps that resolve aliases like `fast` to concrete feature IDs like
`sma_10`. Under that future model, `ctx$features_wide` columns would be named
by alias, not by concrete feature ID, and the schema would differ across
candidates with different alias maps.

The prebuilt-view construction in this synthesis must be designed to absorb
alias resolution at setup time without architectural rework. Specifically:

- The per-candidate view construction loop must accept an optional alias map
  parameter (NULL in v0.1.8.3; populated in v0.1.8.4).
- When alias map is non-NULL, column names in `features_wide` are alias names;
  concrete feature IDs are stored as a column-name -> feature-ID lookup attribute
  on the view object for provenance.
- The view construction code path must not require restructuring when v0.1.8.4
  lands; only the column-naming logic must change.

This is a v0.1.8.4 concern, not a v0.1.8.3 implementation concern, but the
v0.1.8.3 prebuilt-view design must not paint v0.1.8.4 into a corner.

---

## 11. Grid-Union Shared View Future Optimization

Recorded as future work, not v0.1.8.3 scope:

For sweeps where many candidates share concrete features (typical of
parameterized indicator sweeps), candidate-specific view construction
duplicates memory. A grid-union view with per-candidate column selection
provides the same restricted strategy-facing schema with shared underlying
data:

```r
grid_union_view <- ledgr_projection_features_wide(
  projection, pulse_idx, feature_ids = grid_union_feature_ids
)
candidate_view <- grid_union_view[, c("instrument_id", "ts_utc",
                                       candidate_feature_ids), drop = FALSE]
```

The column-selection step is zero-copy in R if no further mutation occurs
(R copy-on-write semantics).

v0.1.8.3 does not implement grid-union sharing. If LDG-2414 reference
measurement shows memory is a concern for wider workloads, grid-union sharing
becomes a candidate for a follow-up ticket (provisionally v0.1.8.5 or
v0.1.8.6 alongside DuckDB-backed projection).

---

## 12. DuckDB Boundary

DuckDB remains a static preparation, persistence, and cache layer. It is not
the per-pulse runtime engine for v0.1.8.3.

The prebuilt-view setup is pure R: views are built from `bars_mat` and
`runtime_projection$feature_values` matrices that already exist in R memory.
No DuckDB query is issued during view construction or during fold execution.

A future DuckDB-backed projection (provisionally v0.1.8.6) can implement the
same view interface by loading pulse blocks into memory:

```text
DuckDB feature storage
  -> load pulse block [i:j]
  -> expose prebuilt views inside the block
  -> no DBI per pulse, no DBI per view access
```

The block boundary fires DuckDB queries, not the pulse boundary. The
prebuilt-view interface is the natural boundary for this future swap.

---

## 13. Sequencing

Within the v0.1.8.3 cycle:

```text
1. Run ctx$feature_table usage audit (Section 4); record outcome and any
   future-deprecation note for horizon.md.
2. Remove run_feature_matrix from the fold execution contract per Section 5.
3. Implement bars view prebuild and parity test (per-entry-path lifetimes
   per Section 3).
4. Implement features_wide view prebuild and parity test.
5. Implement feature_table view prebuild and parity test.
6. State-leak fixtures (Section 7) for all three views: in-run capture, in-strategy
   mutation, cross-candidate isolation.
7. Remeasure LDG-2402 reference workload; record vs LDG-2411 checkpoint.
8. Maintainer reviews Section 9 evidence and decides LDG-2410 / LDG-2412
   disposition (defer to v0.1.9 or keep in v0.1.8.3).
9. Update LDG-2414 residual report with memory, timing, and disposition
   decision.
```

Steps 1 and 2 are prerequisites for step 3. Steps 3-5 can land as a single
commit or three separate commits. Step 8 is a maintainer decision point, not
an implementation step.

---

## 14. Required Document Updates

Before LDG-2413 ticket cut:

1. Amend `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md`:
   - Section 3 In Scope: rename "Fast context B2" subsection to "Pulse context data
     model consolidation" and update the bullet list to reflect prebuilt
     view scope.
   - Section 3 Out Of Scope: confirm "no field-to-function context API changes" still
     holds - prebuilt views are still fields, just constructed elsewhere.
   - Section 4 Experimental Protocol: add peak memory measurement to the workload
     requirements.

2. Amend `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_tickets.md` and
   `tickets.yml`:
   - Rename LDG-2413 from "Fast Context B2 Index-Backed Context Proxies" to
     "Pulse Context Data Model Consolidation."
   - Update LDG-2413 description, tasks, acceptance criteria, and verification
     to reflect this synthesis.
   - Update LDG-2414 dependencies so it can run after LDG-2413 and provide the
     maintainer decision evidence for LDG-2410 / LDG-2412 disposition.

3. Amend
   `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`:
   - Add a one-paragraph note that this synthesis supersedes the
     fast-context-B2-proxy framing for v0.1.8.3 implementation.

4. Index this synthesis in `inst/design/README.md`.

5. Add an entry to `inst/design/horizon.md` recording grid-union view sharing
   as a future memory optimization.

Do not cut LDG-2413 implementation until items 1-3 are written and reviewed.

---

## 15. Non-Goals

This synthesis does not propose:

- a second execution engine;
- a sweep-only fast path separate from `ledgr_run()`;
- literal `pmap()` or vectorized strategy execution;
- DuckDB calls inside the per-pulse hot loop;
- active aliases or alias-map identity in v0.1.8.3;
- public ML training-frame export APIs;
- lazy view objects via active bindings or function-valued ctx fields;
- changing `ctx$bars`, `ctx$features_wide`, or `ctx$feature_table` from
  data.frame to a custom S3 class;
- public parallel sweep dispatch;
- compiled C / Rust fold kernels;
- weakening snapshot, no-lookahead, FIFO accounting, metric-context, or
  execution-seed contracts;
- grid-union view sharing (recorded as future work in Section 11);
- deletion of `ctx$feature_table` without the Section 4 audit;
- preserving the `run_feature_matrix` legacy fallback without explicit
  justification;
- backward-compatibility shims for pre-CRAN development artifacts.

---

## 16. Bound Synthesis Positions

This synthesis accepts:

1. LDG-2413 is rescoped to "Pulse Context Data Model Consolidation."
2. Prebuilt static pulse views are the v0.1.8.3 B2 implementation target.
3. Bars views are built at the appropriate setup point per entry path
   (`ledgr_run()`: at run setup; `ledgr_sweep()`: at sweep setup, shared
   across candidates). Feature views are candidate-specific in the first
   pass.
4. Fast context B1 closures, projection-backed accessors, and dynamic state
   keep their current LDG-2411 lifecycle.
5. `run_feature_matrix` is removed from the fold execution contract and the
   legacy `is.null(runtime_projection)` branch in `ledgr_execute_fold` per
   Section 5. Setup-only role in `ledgr_run_fold` may remain as an intermediate or
   be replaced by direct projection construction; implementer's choice.
6. `ctx$feature_table` audit is completed before implementation begins. Both
   audit outcomes result in prebuilding `ctx$feature_table` per pulse with
   the current schema in v0.1.8.3; the audit outcome determines only whether
   a future-deprecation note is recorded in `inst/design/horizon.md`.
7. State-leak fixtures from Section 7 (in-run capture survives, in-strategy mutation
   does not propagate, cross-candidate isolation) are required for all three
   views (`ctx$bars`, `ctx$feature_table`, `ctx$features_wide`).
8. LDG-2402 reference workload remeasurement is required at LDG-2414.
9. Peak memory measurement is required at LDG-2414.
10. LDG-2410 and LDG-2412 disposition is recommended for maintainer decision
    after LDG-2414 measurement per Section 9; this synthesis does not bind a
    deferral rule.
11. v0.1.8.4 active-alias interaction is preserved via per-candidate
    construction loop accepting optional alias map parameter.
12. Grid-union view sharing is recorded as future work in `horizon.md`.
13. No fallback path is pre-designed for memory pressure; measure first, add
    fallback later if evidence shows it is needed.

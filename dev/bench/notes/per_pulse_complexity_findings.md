# Per-Pulse Complexity Findings

Created: 2026-05-31
Scope: Post-LDG-2479 diagnosis of why per-fill engine cost grows with universe
size, derived from the workload grid baseline record and the
`R/fold-engine.R` per-pulse code path.

This is a v0.1.9 spec input. It is not a fix, not a benchmark, and not a
public performance claim. It identifies the specific R-idiom patterns in the
fold engine that cause per-fill cost to scale with universe size when it
architecturally should not.

## Headline

An event-driven backtester's per-fill cost should be O(1) - touch one
position, write one event, update one cash field. The LDG-2479 workload grid
shows ledgr's per-fill engine cost growing with universe size on the same
strategy and density:

| Cell | n_inst | Fills | Fills/inst | us/fill (engine) |
| --- | ---: | ---: | ---: | ---: |
| density_high_medium_durable | 100 | ~13,750 | 137 | 931 |
| density_high_large_durable | 500 | ~68,070 | 136 | 2,040 |
| density_high_xlarge_durable | 1000 | ~133,070 | 133 | 3,107 |

Fills-per-instrument is constant at ~135, so total fills scale linearly with
`n_inst`. If per-fill work were truly O(1) the us/fill column would be flat.
It grows 3.3x as universe grows 10x.

**Cause: ledgr's fold engine does O(n_inst) work per pulse in several places,
unrelated to fill emission. The "per-fill" metric divides total loop time by
total fills, so per-pulse work shows up as inflated per-fill cost.**

The architecture is correct. The implementation has R-idiom debt. The fixes
are mechanical.

## Suspect 1 - Per-Pulse Position Valuation Loop

Location: `R/fold-engine.R:164-170`

```r
positions_value <- 0
for (j in seq_along(instrument_ids)) {
  inst <- instrument_ids[[j]]
  qty <- as.numeric(state$positions[[inst]] %||% 0)
  if (qty == 0) next
  positions_value <- positions_value + qty * bars_mat$close[j, i]
}
```

Runs every pulse to compute `equity = cash + positions_value` for the pulse
context. The loop is O(n_inst) per pulse regardless of fill activity. At
1000 instruments x 1260 pulses this is 1.26M R-interpreted iterations.

Suggested fix (mechanical):

```r
positions_value <- sum(as.numeric(state$positions) * bars_mat$close[, i])
```

`bars_mat$close[, i]` is already a column vector aligned to `instrument_ids`.
`as.numeric(state$positions)` extracts position values in instrument order.
Single vector multiply plus single `sum()`. O(n_inst) in compiled C instead
of interpreted R.

Estimated savings on `density_high_xlarge_durable`: ~9s out of 413s loop time.

Risk: position-order alignment. `as.numeric(state$positions)` returns values
in the order the names are stored. Must verify that order is identical to
`instrument_ids` order. If not, index with `state$positions[instrument_ids]`
before `as.numeric()`.

## Suspect 2 - Per-Target Early-Skip Loop

Location: `R/fold-engine.R:277-359`

```r
for (instrument_id in names(targets)) {
  desired <- as.numeric(targets[[instrument_id]])
  cur_qty <- as.numeric(state$positions[[instrument_id]] %||% 0)
  delta <- desired - cur_qty
  if (abs(delta) <= sqrt(.Machine$double.eps)) {
    next
  }
  ...
}
```

The strategy returns `targets` as a length-`n_inst` named numeric vector
(because `ctx$flat()` returns a zero-vector of length `n_inst`). This loop
iterates n_inst times per pulse and does the early-skip check on each
iteration even when no fill is going to happen.

At 1000 inst x 1260 pulses the loop body runs 1.26M times to do ~133k real
fills (~10:1 skip-to-fill ratio). Each cheap iteration costs an
`[[id]]` lookup against both `targets` and `state$positions`, a subtraction,
and an absolute-value comparison. Even at a few microseconds per iteration
the cheap-skip overhead is several seconds.

Suggested fix:

```r
desired_vec <- as.numeric(targets)
positions_vec <- as.numeric(state$positions[names(targets)])
delta_vec <- desired_vec - positions_vec
fill_idx <- which(abs(delta_vec) > sqrt(.Machine$double.eps))
for (j in fill_idx) {
  instrument_id <- names(targets)[[j]]
  delta <- delta_vec[[j]]
  cur_qty <- positions_vec[[j]]
  ...
}
```

The vector subtraction is one C op. `which()` produces only the indices
where work is needed. The R loop now iterates ~133k times total across the
run, not 1.26M.

Estimated savings on `density_high_xlarge_durable`: ~12s out of 413s loop time.

Risk: target ordering. `names(targets)` may differ from `instrument_ids`
ordering. Use `state$positions[names(targets)]` (with subset) instead of
positional access to keep alignment safe.

## Suspect 3 - Named-Vector Copy-on-Write on `state$positions`

Location: `R/fold-engine.R:354-355`

```r
state$positions[[instrument_id]] <- cur_qty + qty
state$cash <- state$cash + cash_delta
```

`state$positions` is a named numeric vector of length `n_inst`. R's
copy-on-write semantics may copy the whole vector when one element is
mutated, depending on reference count. The pulse-context constructor a few
lines earlier (around line 186) does `positions = state$positions` inside
the `ctx` list, which holds a reference. That reference may force a copy on
mutation.

At 1000 inst x 133k fills that is potentially 133M element copies per run.
At a few nanoseconds per element the total is 1-2 seconds. Smaller than the
other two suspects but real.

Suggested fix options:

- Make `state` an environment instead of a list. Environment slot mutation
  is O(1) hash mutation with no copy semantics.
- Switch `state$positions` from a named numeric vector to an integer-indexed
  numeric vector with a one-time `id -> idx` map built at fold start. Index
  mutation in R is O(1) when the vector is not shared.

Estimated savings on `density_high_xlarge_durable`: ~1.5s out of 413s loop time.

Risk: surface area. `state$positions` is referenced from multiple places
(pulse context construction, reconstruction, telemetry). Changing the
representation requires touching every read site too. This is a larger
change than Suspects 1 and 2 and should be sequenced after them.

## What Lands After the Three Fixes

Combined expected recovery on `density_high_xlarge_durable`: ~22.5s of 413s
loop time (~5% direct). Modest in absolute terms but the per-fill scaling
curve flattens substantially. The remaining ~390s is split between true
per-fill work (event writes, lot-map updates, cash bookkeeping) and the
per-pulse strategy callback (user code, out of scope).

Once these land, the next-largest bottleneck is per-fill
`output_handler$write_fill_events()` - DuckDB row insertion at 133k fills.
The current loop calls `write_fill_events` once per fill. Batching to chunks
of 100-1000 fills should give the next big win.

The lane sequencing for v0.1.9 single-core perf:

1. Suspect 1: vectorize per-pulse position valuation. Smallest blast radius,
   biggest single win, easiest verification.
2. Suspect 2: vectorize per-target delta computation. Larger code change,
   second-biggest win, similar verification.
3. Output handler batching: per-fill writes -> chunked writes. Architecturally
   bigger change because it touches the output-handler contract, but the
   per-fill cost reduction should be substantial at high density.
4. Suspect 3: state representation. Largest blast radius. Defer until 1, 2,
   and 3 are measured.

## Verification Discipline

Each fix is a candidate for the workload grid as the before/after gate:

- Before: run `density_high_xlarge_durable` and `density_high_large_durable`
  at the current source. Record `t_loop_sec`, `mus_per_fill_engine`,
  `fills` count.
- After: apply the fix, re-run the same cells, confirm:
  - `t_loop_sec` decreases on both cells;
  - `mus_per_fill_engine` decreases more on xlarge than on large (the
    scaling curve is flattening, not just shifting);
  - all parity tests in `tests/testthat/` still pass byte-identically;
  - the peer benchmark Tier 1 parity check still passes within tolerance.

Do not promote a fix unless both `density_high_large_durable` and
`density_high_xlarge_durable` improve and the per-fill cost curve gets
flatter. A fix that improves xlarge but not large is suspicious because it
suggests a constant-cost saving rather than a scaling fix.

## What This Note Is Not

- Not authorization to change `R/fold-engine.R`. Cuts a v0.1.9 ticket first.
- Not a peer benchmark claim. The numbers are local-host, current-source,
  ledgr-only.
- Not a contract change. Public APIs (`ledgr_run`, `ledgr_sweep`,
  function-strategy contract) remain unchanged through these fixes.
- Not a parallel-dispatch story. This is single-core hot-path work that must
  land before parallelism becomes the answer.

## Source Evidence

- `dev/bench/results/ledgr_bench_record_20260531T132910Z_summary.csv`
- `dev/bench/notes/workload_grid_baseline_closeout.md`
- `dev/bench/peer_benchmark/notes/ledgr_regression_source_analysis.md`
- `inst/design/horizon.md`, `2026-05-31 [optimization] LDG-2476
  peer-benchmark turnover cost decomposition` entry
- `R/fold-engine.R` (per-pulse loop body)

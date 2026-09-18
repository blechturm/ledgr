# Results-Path And Benchmark-Boundary Note

Status: Observations, plus maintainer decisions recorded on 2026-09-18. Not a
ticket and not a gate. Nothing here may be implemented inside v0.2.0.1.

Read before Batch 11. The leading finding is a benchmark-methodology defect
that bears directly on which release claims are permitted, so it must be
settled before the release gate rather than after it.

This note covers the results phase and the peer-benchmark measurement
boundary. Its companion is `dev/bench/notes/durable_path_observations.md`,
indexed from the 2026-09-17 infrastructure entry in `inst/design/horizon.md`,
which covers durable ingestion, snapshot hashing, and the durable engine. Read
this note first of the two: it changes which rows of the peer record may be
quoted at all.

Source: initial read and measurement of the tree based at
`400a3e56ae49cc61256d0e7aaca66281626d4fe3`, followed by the declared
benchmark-boundary correction described below.

## Finding 1: the peer benchmark measures a workflow users cannot invoke

This is a measurement-boundary defect, not a performance problem, and it is
the reason the rest of this note is ordered the way it is.

The two ledgr lanes in the peer harness are not the same kind of measurement:

| Lane | `ledgr:::` internals | Public API calls |
| --- | ---: | ---: |
| `peer_run_ledgr`, durable | 0 | 4 |
| `peer_run_ledgr_ephemeral`, memory | 9 | 0 |

The durable lane calls `ledgr_experiment()`, `ledgr_run()` and
`ledgr_results()`. It measures the product.

The memory lane at `dev/bench/peer_benchmark/peer_benchmark.R:461` hand-builds
an execution spec and drives `ledgr_execute_fold()` directly, then reconstructs
equity and fills from the event stream at
`dev/bench/peer_benchmark/peer_benchmark.R:513`. Every entry point it uses is
unexported: `ledgr_execute_fold`, `ledgr_execution_spec` and
`ledgr_memory_output_handler` are absent from `NAMESPACE`. No user can reach
that workflow.

Worse, production does not take that path either. `ledgr_sweep()` at
`R/sweep.R:1429` prefers `output_handler$inline_summary()` and falls back to
event-stream reconstruction only when the handler has none. The memory handler
defines `inline_summary()` at `R/sweep.R:1854`, reading equity facts and inline
fills accumulated per pulse during the fold by `record_equity_fact()` at
`R/sweep.R:1843`. Those facts are recorded unconditionally, so the fold pays
for them whether or not anything reads them.

Measured at the registered 500 by 1,260 shape, 68,201 events:

| Path | Time |
| --- | ---: |
| `inline_summary()`, what `ledgr_sweep()` calls | 0.00 s, below clock |
| `typed_events()` plus both reconstructions, the harness | 9.99 s |

The harness therefore charges ledgr four times over: the fold computes the
accounting facts, the harness discards them, reconstructs equity with a full
FIFO replay, and reconstructs fills with a second full FIFO replay.

The two paths agree. Fills match exactly across all ten shared columns and all
68,201 rows. Equity matches exactly on `positions_value`, `realized_pnl` and
`unrealized_pnl`. `cash` and `equity` differ by 3.092e-07, discussed under
finding 6.

### Row classification

- durable `ledgr_ttr_canonical` and `ledgr_builtin_sma`: valid product
  benchmarks. They use the public workflow.
- memory `ledgr_ttr_canonical_ephemeral` and compiled
  `ledgr_ttr_compiled_spot_fifo_ephemeral`: valid internal kernel diagnostics.
  They are not valid product comparisons and must not be quoted as peer
  performance.

The private fold harness stays useful as an internal kernel benchmark. It
cannot honestly answer "how fast is ledgr" while users cannot invoke it and the
public workflow avoids ten seconds of redundant work.

### What is not a result

Subtracting the measured results phase from the recorded rows gives about 39.7
seconds for memory and about 25.7 seconds for compiled. Those are arithmetic,
not measurements. They must not be recorded, quoted, or carried into any
closeout. The corrected numbers can only come from running the corrected
workflow.

## Maintainer decisions

Recorded 2026-09-18. They set direction for the correction and do not authorize
work inside v0.2.0.1 beyond what Batch 11 sequencing requires.

Decision 1. Correct the peer harness to measure the public workflow for the
memory-backed rows, and rerun those two rows before entering the release gate:

- `ledgr_sweep()` with exactly one candidate for canonical R;
- the same public sweep with `compiled_accounting_model = "spot_fifo"`;
- the complete public-call wall clock as the peer-comparable result;
- the private fold phases retained only as diagnostic decomposition; and
- reconstruction parity checked outside the timed region, using the existing
  numerical equity tolerance and exact fills and trades checks.

Decision 2. The one-candidate sweep machinery belongs inside the reported
result. `warm_research_iteration` is defined as the workflow researchers
actually use. Stripping public orchestration overhead to make the row look
leaner would make the comparison less honest, not more comparable.

Decision 3. Do not overwrite Batch 10. Preserve its two private rows as
historical internal fold diagnostic records, add the corrected public-sweep
rows under a new method version, and prohibit quoting the private rows as peer
performance.

Before the corrected run existed, the only defensible comparative statement
was:

> The public durable ledgr workflow completed in 78.21 seconds versus
> Backtrader's 83.54 seconds on the registered workload.

### Correction record

The corrected harness now measures a public one-candidate `ledgr_sweep()` for
both memory rows. Public retained returns and trades are part of the timed
workflow. A private internal oracle supplies the richer fills and cash and
position surfaces needed by the existing parity checks, but runs outside the
reported clock. The canonical and compiled public sweep surfaces are identical
after excluding sweep identifiers.

The registered full-shape correction run is
`peer_benchmark_record_20260917T231851Z`, method
`public_one_candidate_ledgr_sweep_v002`:

| Public workflow | Cold wall | Warm wall |
| --- | ---: | ---: |
| canonical R sweep | 64.87 s | 44.84 s |
| compiled spot-FIFO sweep | 49.71 s | 30.38 s |

Backtrader recorded 83.69 seconds cold and 83.11 seconds warm in the same
record. The public and oracle equity series differed by at most 4.12e-07 and
passed the existing relative parity predicate; retained public returns and
trades passed exact cross-arm checks.

This is a working-tree correction measurement based at `400a3e5`, with exact
harness SHA-256
`3ef4a31831a16bc8cb06cc2647bd68e1f3e9f5d13268806523ec62edb22b579e`.
It establishes that the corrected method works and supplies review evidence.
It is not the immutable release record. After the harness correction is
accepted and committed, the same method must be rerun at that commit before
Batch 11 may authorize comparative release claims.

### Note on direction

The correction makes ledgr look better, not worse: it removes a self-inflicted
penalty rather than adding an advantage. That is exactly why it needs declaring
loudly in the record and reviewing carefully. It is distinct from the declined
proposal to speed up the harness's own `read.csv()`, which was rejected because
it would improve a published number without improving ledgr. Here nothing is
optimized; a path that does not exist stops being measured.

### Bearing on Batch 10

This does not retroactively invalidate the original Batch 10 record. That
record accurately measured and disclosed its private boundary and remains
historical diagnostic evidence. The corrected report now uses the public
sweep boundary and preserves the original record by identifier. Its memory and
compiled figures remain provisional until the accepted harness is rerun from
its committed source for immutable closeout.

## Finding 2: there is no durable sweep path

The first draft of this note incorrectly inferred a durable `ledgr_sweep()`
from the persistent output handler. The call graph does not support that claim.
`ledgr_sweep()` always constructs `ledgr_memory_output_handler()` at
`R/sweep.R:1353`, and that handler always defines `inline_summary()`. Promotion
reruns a candidate through the separate public `ledgr_run()` workflow; it does
not replace the sweep's handler. The persistent handler is used by
`ledgr_run()`, not by a durable sweep.

The combined fallback at `R/sweep.R:1440` performs one replay, not the two
independent replays used by the benchmark. No current public sweep construction
reaches that fallback. The standalone equity and fill reconstruction helpers
remain useful as reference, test and result-reconstruction code, but the
benchmark is the identified caller that invokes both over one event stream.

This narrows rather than erases the later findings. The repeated per-instrument
scan is reconstruction debt. The lot-state primitives are shared more broadly:
fold accounting, derived state, finalization and run-store readers also call
them. Their complexity must therefore be assessed by call site rather than
attributed to a nonexistent durable-sweep path.

## Finding 3: the fold's own accounting results are written and never read

`materialize_events()` attaches `ledgr_event_realized` and
`ledgr_event_cost_basis` at `R/sweep.R:1664`, computed by the fold.
`ledgr_typed_event_metadata()` reads only `cash_delta`, `position_delta` and
`meta`, and nothing in `R/fold-reconstruction.R` reads the other two.

Verified: replaying the FIFO from scratch reproduces both attributes with a
maximum absolute difference of 0. The recomputation is pure waste where the
attributes are present.

They are present only for memory-origin events. Durable events arrive from
DuckDB without R attributes, so any consumption of them needs a fallback, which
is where finding 5 and the compiled kernel become relevant.

Separately, `ledgr_equity_from_events()` at `R/fold-reconstruction.R:36` and
`ledgr_fills_from_events()` at `R/fold-reconstruction.R:288` each independently
sort the events, rebuild typed metadata, and replay the full FIFO. One shared
replay would remove a duplicate O(E log E) sort, a duplicate O(E) metadata
build, and one of the two replays.

## Finding 4: three nonlinear shapes in the reconstruction path

None is the dominant cost at the registered shape. All three scale badly.
Timings are 500 then 2,000 instruments, except the last row which is 125
then 1,000 instruments.

| Shape | Complexity | Measured |
| --- | --- | ---: |
| full-vector scan per instrument | O(instruments x events) | 0.14 / 0.41 s |
| named lot-state lookups per event | O(instruments)/event | ~1 us each |
| basis re-summed over all lots | O(lot depth) per event | 147 vs 62 us |

The scan is `ev_idx <- which(events$instrument_id == id)` inside a loop over
instruments. It appears in the standalone reconstruction helper and in the
combined internal fallback. Neither occurrence is reached by the ordinary
public memory sweep today.

The lookups are `ledgr_lot_get()` at `R/lot-accounting.R:28` and
`ledgr_lot_set()` at `R/lot-accounting.R:54`, which together perform roughly
five named-list searches per event over a list sized by the universe.

The basis re-sum is `ledgr_lot_basis()` at `R/lot-accounting.R:21`, called from
`ledgr_lot_set()` on every event, summing an instrument's entire open lot list.
This is the dangerous latent cost. It measures as only 3.3 percent of self time
on the registered SMA crossover workload because that strategy alternates buys
and sells and keeps lot lists shallow. A strategy that accumulates lots without
closing them makes reconstruction progressively more expensive. `lot_set()`
already holds `old_basis`, so the delta is available and the re-sum is
avoidable.

Profiling shows no single hot spot: `ledgr_lot_set` 13.9 percent self,
`$` 9.0, `ledgr_lot_add_realized` 8.2, `ledgr_lot_apply_fill` 7.8, `%in%` 6.5.
That is per-event interpreter overhead on a state machine, not one defect.

## Finding 5: what collapse can and cannot do here

Measured replacement of the per-instrument scan:

| Universe | `which()` loop | `fmatch` plus `gsplit` | Gain |
| --- | ---: | ---: | ---: |
| 500 instruments | 0.090 s | 0.010 s | 9.0x |
| 2,000 instruments | 0.410 s | 0.050 s | 8.2x |

One `collapse::fmatch()` pass maps every event to an integer instrument index,
which also replaces the repeated named-list searches, so a single change
addresses two of the three shapes in finding 4. `collapse::gsplit()` groups
event positions once. Grouped `fcumsum()` can replace the per-instrument
`cumsum()`.

collapse cannot vectorise the FIFO replay. State after event N depends on
events 1 through N-1. The options there are to skip the replay when the fold
already retained the answer, to perform one shared replay rather than two, to
use the existing compiled kernel, or to maintain basis incrementally.

`ledgr_cpp_spot_fifo_batch()` already ships and takes batched fills with
integer instrument indices and flat lot arrays, which is the shape
reconstruction needs. It is called only from the fold opt-in path. Using it to
underpin canonical fallback reconstruction is a deliberate contract decision
about whether compiled code may sit beneath a reference path, and should not be
taken as an optimization.

## Finding 6: the equity tolerance question

Inline and reconstructed equity differ by 3.092e-07 on `cash` and `equity`,
and agree exactly elsewhere. The inline path accumulates with Kahan
compensation through `realized_comp`; the reconstruction re-sums.

This is not a detail to resolve in passing. The existing peer parity CSVs were
computed against the reconstruction, so adopting the public workflow shifts the
reference and moves peer parity figures in the seventh decimal. The earlier
record's 2.011657e-07 figure is an observed durable/memory residual, not a
tolerance. The registered parity predicate uses relative `all.equal()`
tolerance 1e-8, which both residuals satisfy at this equity scale.

The corrected record uses the public inline result as the ledgr memory
reference, reports the residual, and does not change the tolerance merely to
preserve historical bytes. The compensated production result is the relevant
product behavior.

## Scope and authorization

None of the reconstruction or shared lot-accounting optimizations is a
v0.2.0.1 implementation item. Result readers and broad hot-path cleanup are
explicit non-goals of the accepted hot-path complexity amendment.

Finding 1 is different in kind. It is a benchmark-methodology defect, not an
optimization, and it determines which comparative statements Batch 11 may
authorize. It must be settled before the release gate.

## Reproduction

Drive the ephemeral lane by sourcing the harness inside a function so that its
`sys.nframe()` guard does not fire `peer_main()`, then time
`output_handler$inline_summary()` against `ledgr_equity_from_events()` and
`ledgr_fills_from_events()` over the same handler. Compare column by column
rather than with `identical()` on the whole frame, because the only divergence
is a float accumulation difference confined to two equity columns.

Profile the results phase alone. Profiling the full ephemeral call mixes fold
execution into the attribution and hides that the reconstruction is the cost.

# ledgr v0.1.8.9 Optimization-Round Spike

**Status:** Pre-RFC investigation. Results feed the v0.1.8.9 single-core
optimization round. Not a v0.1.8.8 deliverable.
**Scope:** Decompose ledgr's per-fill cost growth with universe size,
locate the responsible mechanisms in `R/fold-engine.R`,
`R/fold-reconstruction.R`, `R/fold-event-buffer.R`, and the output handlers,
and measure candidate fixes (per-pulse vectorization, fill-write batching,
results-materialization rewrite, memory output handler scaling) in
isolation before committing them to a v0.1.8.9 spec.
**Non-scope:** ledgr implementation work, fold-core refactor, the v0.1.8.9
spec packet itself, peer benchmark work, parallelism, indicator engine
rewrites.

Each spike is a short, self-contained, *runnable* investigation. The
runnable scripts and raw logs live in `dev/spikes/`. CSV artifacts under
`dev/bench/results/` are gitignored scratch. This directory holds the
design-level writeup: the per-spike logs are linked below, and the
cross-cutting conclusions will be synthesized in `architecture_synthesis.md`
once the spikes complete.

Host for all spikes: same local development host running R 4.5.2 at
`C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe`.

## Why this round exists

The LDG-2476 three-phase peer benchmark and the LDG-2479 self-profiling
workload grid surfaced one architectural-feeling problem and several
mechanism-level candidates. The headline:

- Per-fill engine cost in ledgr grows with universe size: 931 us/fill at
  100 instruments, 2,040 at 500, 3,107 at 1000 (all on 1260-pulse SMA 5/10
  crossover).
- Fills per instrument is constant at ~135 across these rows, so total
  fills scale linearly with `n_inst`. A correctly implemented event-driven
  engine should have flat per-fill cost.
- Architecture is correct; implementation has R-idiom debt.

The full diagnosis lives in
`dev/bench/notes/per_pulse_complexity_findings.md` and the full optimization
inventory lives in `dev/bench/notes/single_core_optimization_inventory.md`.

This spike round mirrors the v0.1.8.7 cycle's pre-RFC investigation
(`inst/design/spikes/ledgr_optimization_round_spike/`): each suspected
mechanism gets an isolated reproducer that either confirms or rejects the
hypothesis, then the production re-profile is the wall-time verdict. The
discipline is captured in
`inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd`.

## Spikes

Reference workload for the production re-profile gate is
`density_high_xlarge_durable` from the LDG-2479 grid (1000 inst x 1260
pulses, SMA 5/10 crossover, durable). Secondary cell is
`density_high_large_durable` (500 x 1260, same strategy). Both must improve
for a scaling fix; xlarge alone improving is suspicious because it suggests
a constant-cost win rather than a scaling win.

| # | Spike | Runnable + log | Mechanism hypothesis | Headline |
|---|---|---|---|---|
| 1 | Per-pulse position valuation vectorize | `dev/spikes/spike-position-valuation-vectorize.{R,md}` | The `for (j in seq_along(instrument_ids))` loop at `R/fold-engine.R:164-170` is O(n_inst) per pulse, R-interpreted, with no fill dependency. Replacing with a single `sum(positions * close_col)` should be 10x-100x faster on the isolated loop and recover ~9s of 413s loop on the xlarge cell. | **Confirmed.** Vec is effectively free vs 3.29s current at 1000x1260. Density (0.1/0.5/0.9) does not change current cost — per-iteration overhead dominates. Use `vec_ord` variant for alignment safety. Proceed to v0.1.8.9 ticket. |
| 2 | Per-target delta vectorize | `dev/spikes/spike-target-delta-vectorize.{R,md}` | The `for (instrument_id in names(targets))` loop at `R/fold-engine.R:277-359` iterates n_inst times per pulse, doing per-instrument `[[id]]` lookups even when no fill will fire. Computing a delta vector once per pulse and iterating only over `which(abs(delta_vec) > tol)` should drop loop iterations from 1.26M to ~133k on the xlarge cell and recover ~12s. | **Confirmed, scales with universe.** 14x at 100 inst, 35x at 500 inst, **102.7x at 1000 inst** — the architectural-flattening signature. 6.16s isolated cost at 1000x1260. Proceed to v0.1.8.9 ticket. |
| 3 | state$positions representation | `dev/spikes/spike-state-positions-representation.{R,md}` | `state$positions[[id]] <- value` at `R/fold-engine.R:354-355` may force whole-vector copy because the pulse-context constructor holds a reference (`positions = state$positions` in ctx). Switching `state` to an environment, or `state$positions` to integer-indexed numeric with a one-time id-to-idx map, should remove copy-on-write cost and recover ~1.5s. tracemem confirms the copy if the mechanism is real. Also tested: `collapse::setv` (v0.1.8.7 buffer-spike alternative). | **Mechanism confirmed by tracemem.** Copy fires on every mutation. **env_state does NOT fix it** (state-as-env still leaves positions as a refcounted vector). env_positions gives 4.6x but **changes semantics** (ctx$positions becomes live, not snapshot). intvec_id_map gives 1.9x and preserves snapshot semantics. **collapse::setv is tracemem-clean (zero copy) but only 1.9x at this scale** — function-call overhead washes out the no-copy win at 1000-inst vectors. The v0.1.8.7 buffer-spike's 65-1300x for setv was scale-dependent (630k-slot buffers). Defer to after Spikes 1+2 land; recommend intvec_id_map as default (semantic-preserving), env_positions only after ctx audit. |
| 4 | Batch fill writes (DuckDB) | `dev/spikes/spike-batch-fill-writes.{R,md}` | The durable output handler calls `write_fill_events` once per fill, each insert paying per-call DuckDB overhead. Batching N fills into one insert should amortize that overhead by N. Expected sharp drop in per-fill cost between batches of 1 and batches of 100, with diminishing returns past 1000. Wall recovery estimate: 30-80s on the xlarge cell. | **RECLASSIFIED per Codex Round 1 review.** Spike 4 measured live-mode-only per-row INSERT (24x speedup at batches of 100). Codex confirmed default durable uses BUFFERED mode (`R/backtest-runner.R:425-435`) which already batches via `pending_cols` + `DBI::dbAppendTable`. So Spike 4's 75s recovery claim does NOT apply to the LDG-2479 grid xlarge cell. The actual durable handler buffer write anti-pattern is covered by Spike 11 (LDG-2490). Spike 4 stays useful as a measurement of the live-mode lane only. |
| 5 | Per-fill next-bar extraction | `dev/spikes/spike-next-bar-extraction.{R,md}` | `b[i+1L, , drop = FALSE]` at `R/fold-engine.R:290` allocates a new data.frame row per fill with class-dispatch overhead. Replacing with `bars_mat$open[next_inst_idx, i+1L]` (matrix scalar lookup) should be 10x-100x faster on the isolated lookup. Magnitude depends on whether this is profile-visible — if it is, recoverable; if not, park. | **Mechanism confirmed, small lane.** df_row_subset 4.98s vs matrix_scalar 0.03s at 133k fills = **166x speedup**, ~5s wall recovery. Tibble and data.frame indistinguishable (35-37 us/fill). Fix is mechanical but touches the fill-proposal contract surface (next_bar -> next_open_price). **De-prioritize:** Amdahl ~1%, lower priority than B1/D1/C1. v0.1.8.10 cleanup lane or fold into the matrix-canonical RFC. |
| 6 | Memory output handler scaling | `dev/spikes/spike-memory-output-handler-growth.{R,md}` | The ephemeral fold engine spends +16.4s on engine and +40.9s on results vs durable at 68k fills. The memory output handler uses the same B0 grow-by-doubling buffer as durable but accumulates ALL events for the run before reconstruction. At 133k fills the buffer's final size is large; per-event append cost may have a hidden O(n_events) component from name-vector or metadata-list growth. | **O(N^2) confirmed.** handler_baser: 128 us/event at 5k -> 3120 us/event at 130k (**24.4x growth**). Step-wise pattern matches capacity-doubling boundaries (32k, 65k, 131k). Per the v0.1.8.7 optimization map prediction, sizing fix alone leaves O(fills^2). **collapse::setv variant: 6.45x faster at 130k (484 vs 3120 us/event).** Expected wall recovery on ephemeral xlarge: 50-100s. Validates Spike 3's scale-dependence finding: setv wins at 130k-column scale where it doesn't at 1000-element scale. |
| 7 | Fills reconstruction scaling | `dev/spikes/spike-fills-reconstruction-scaling.{R,md}` | `ledgr_results(bt, "fills")` took 6.75s at 13k fills and 82.28s at 68k fills (super-linear). v0.1.8.7 Batch 6 already rewrote this path; the super-linearity suggests either a regression to the old list-of-data.frames + rbind anti-pattern in some sub-path, or a second O(N^2) site the v0.1.8.7 rewrite did not catch. The primitive-column rewrite mechanism is already established and known to work. | **O(N^2) confirmed + culprit located + Round 2 refined.** Per-fill cost: 407 -> 4759 us/fill from 13k to 130k. Rprof points at `ledgr_fill_row_buffer_add` (`R/fold-reconstruction.R:219-227`) consuming 88% of self-time. Codex Round 1 noted: buffer is an env with vector slots (not list-of-vectors as originally stated); production durable uses a CHUNKED reader (`R/backtest.R:1021`), not monolithic `ledgr_fills_from_events`. **Spike 12 (LDG-2491) re-measured against the real chunked extractor: ~150s production recovery on xlarge** (vs the originally extrapolated ~170s). Fix: collapse::setv on the 9 column writes. **Lead v0.1.8.9 lane for durable.** |
| 8 | Event-stream reconstruction scaling | `dev/spikes/spike-event-stream-reconstruction.{R,md}` | `ledgr_equity_from_events()` and `ledgr_fills_from_events()` are the in-memory reconstruction path used by the ephemeral row. The ephemeral results phase is +40.9s vs durable on the same fills count. Same hypothesis as Spike 7 but for the in-memory path: list-of-data.frames anti-pattern, primitive-column rewrite candidate. | **Negative result: equity_from_events is already O(N) per-fill flat** (57-62 us/fill across all scales). Top Rprof self-time is lot accounting + JSON parsing, both linear. The +40.9s ephemeral results delta is NOT in equity_from_events; it is mostly absorbed by Spike 7's fix (since `ledgr_fills_from_events` is called by both durable and ephemeral) and Spike 6's memory handler fix. **D3 lane parked.** No v0.1.8.9 ticket for equity_from_events. |
| 9 | Fills extraction xlarge breakdown | `dev/spikes/spike-fills-extract-xlarge-breakdown.{R,md}` | At 1000 x 1260 high-density (~133k fills), `ledgr_results(bt, "fills")` returns no row count, forcing the LDG-2479 harness to fall back to the ledger row count. Possible causes: query returns a lazy-evaluated DuckDB cursor that errors on materialization; chunked reader silently drops rows; memory pressure kills conversion to data.frame. This is a robustness diagnostic, not a perf simulation — the spike instruments intermediate stages to find which boundary fails. | **DuckDB layer exonerated, investigation narrowed.** COUNT(*) and full SELECT both return correct row counts at all scales (13.5k, 30k, 68.5k, 133k) in under 0.1s. The xlarge fallback was NOT in the DuckDB query stage. **Prime suspect: `stream_threshold = 100000L` in `R/backtest.R:1017` chunked-reader path.** At 133k fills the streaming path activates. Requires a real xlarge bt object for the diagnostic — can't be reproduced in isolation. v0.1.8.9 robustness ticket. |
| 10 | DuckDB equity round-trip noise | `dev/spikes/spike-duckdb-equity-roundtrip.{R,md}` | Durable vs ephemeral ledgr equity differ by ~8e-9 per bar. DuckDB stores DOUBLE which should be byte-identical to R numeric IEEE 754. Possible causes: (a) DuckDB internally promotes through DECIMAL/NUMERIC; (b) accumulation order differs between durable read-back and in-memory walk; (c) cast through different precision in chunked reader path. A byte-compare of write/read cycle on a 100-element double vector identifies the responsible boundary. | **DuckDB rejected as source — all three round-trips byte-identical.** Direct, cumsum accumulation, and DuckDB SUM() OVER all return identical doubles. **Real mechanism: Kahan compensated summation in `ledgr_lot_add_realized` (R/lot-accounting.R:49-55) vs naive `cumsum()` in `ledgr_equity_from_events` (R/fold-reconstruction.R:87).** Both valid; the 8e-9 noise matches the Kahan residual exactly. The 1e-8 tolerance gate is correct. **Documentation-only fix:** rename the gate's attribution from "DuckDB round-trip noise" to "Kahan vs cumsum accumulation". |

## Cross-Cutting Coding Rule (post-Batches A, B, C)

Three of the confirmed O(N^2) sites in this round share the SAME mechanism:
the v0.1.8.7 B0 event buffer, Spike 6 memory output handler, and Spike 7
fills reconstruction buffer. All three exhibit:

> **Per-row writes via base-R `[[<-` into a preallocated column buffer where
> the buffer is a refcount-elevated function argument trigger O(N)
> copy-on-modify per write, totaling O(N^2) per run.**

The fix is consistently `collapse::setv(buffer$<col>, i, value, vind1 = TRUE)`
which writes by C reference, bypassing R's copy-on-modify and restoring
true O(N) total work. `setv` is value-neutral per the optimization map and
does NOT require the `ledgr_with_collapse_deterministic()` wrapper.

**Coding rule for v0.1.8.9 and beyond:** any per-row column-buffer write goes
through `collapse::setv`, not base-R `[[<-`. The `inst/design/collapse_optimization_map.md`
listed this as Tier 3 doctrine; v0.1.8.9 promotes it to a coding rule.

The rule applies wherever the pattern `buffer$<col>[[i]] <- value` appears
inside a per-row append loop and `buffer` is reachable from outside the
loop (function argument, closure capture, environment slot). Scale matters
though: at small vector sizes (~1000 elements per Spike 3), setv does not
materially beat base-R because copies are cheap. At large vector sizes
(~100k+ per Spike 6/7), copies become bandwidth-bound and setv dominates.
Apply the rule to write paths that grow with fill count, history length,
or event count; leave fixed-small vectors alone.

The round's architecture synthesis (written after all spikes complete)
elaborates this rule with full evidence references.

## Spikes that are deferred (conditional or not now)

These items from the optimization inventory are not in this round because
they need profile evidence first, are conditional on specific strategy
features, or are architectural decisions not amenable to isolated
simulation.

- A4 (pulse_seed cheap mixer), A5-A9 (ctx reuse, helpers, alias map,
  telemetry init): require Rprof on `density_high_xlarge_durable` to
  confirm they appear in the top-10 self-time. If they do, follow-up
  spikes.
- B3, B4, B6, B7 (per-fill function-call dispatch, lot-map update,
  event_seq bookkeeping): same — Rprof first, spike if confirmed.
- E1 (snapshot creation 12s) — profile pass first, spike if a single
  function dominates.
- G1-G4 (strategy callback path overhead): Rprof first, spike if any
  appear top-10.
- H1 (state_update canonical_json): conditional on strategies that use
  `state_update`; spike on demand when a user reports cost.
- F1, F2 (series_fn dual-API, feature cache): parked until a non-SMA
  custom-R indicator workload exposes them.
- K1-K5 (compiled fold core, phased pulse, batch cost model, matrix
  strategy surface, replay kernel unification): architectural decisions
  not amenable to isolated simulation. Decided after the cheap fixes land
  and the engine gap is re-measured.

## Method

Lifted verbatim from the v0.1.8.7 cycle (see
`inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd`, section
"Lessons learned"). Three load-bearing principles:

### 1. Spike to confirm mechanism, real-run to confirm magnitude

For every candidate in this round:

1. **Isolated simulation** (this spike): a small R script that reproduces
   the suspected mechanism in isolation. Output is per-call cost and a
   scaling signature.
2. **Mechanism confirmation**: the spike either confirms or rejects the
   hypothesis. If rejected, the candidate is parked and recorded as a
   negative result.
3. **Production prototype**: implement the fix in the relevant source
   file, preserving public APIs and byte-identical event stream.
4. **Real-run re-profile**: re-run `density_high_large_durable` and
   `density_high_xlarge_durable` on the workload grid. The wall delta on
   both cells is the production verdict.
5. **Parity gate**: all `tests/testthat/` byte-identical. Peer benchmark
   Tier 1 within tolerance. Workload grid scenario definitions unchanged.

Steps 1-2 are the spike round. Steps 3-5 are the v0.1.8.9 implementation
tickets that follow.

### 2. Within-run share is more honest than wall-to-wall comparison

Local CPU power-profile drift can silently inflate or deflate apparent
speedup. Each spike log reports:

- The isolated component's before/after speedup ratio (the mechanism
  evidence).
- A wall-translation paragraph that applies Amdahl using the workload
  grid record numbers, capping the expected wall improvement.

### 3. Amdahl is non-negotiable

Each spike log includes a "Wall translation" section computing the maximum
possible wall improvement using:

```text
max_wall_speedup = 1 / ((1 - p) + p / s)
```

where `p` is the fraction of total wall the candidate addresses on the
reference cell and `s` is the spike's isolated speedup.

If the wall translation caps at < 5% improvement, the spike log explicitly
states whether to proceed (e.g., the architectural scaling win is the real
value) or park.

## Spike log template

Each spike log under `dev/spikes/spike-<name>.md` follows the structure
established in `dev/spikes/spike-event-buffer-rewrite.md` from the v0.1.8.7
round:

```markdown
# Spike Log: <Title>

**Date:** YYYY-MM-DD - **Host:** <host info> - R 4.5.2 - **Status:** v0.1.8.9
optimization-round input.

**Script:** dev/spikes/spike-<name>.R. Raw CSV (gitignored):
dev/bench/results/spike_<name>.csv.

**Relates to:** dev/bench/notes/single_core_optimization_inventory.md
(candidate <ID>); dev/bench/notes/per_pulse_complexity_findings.md.

## Question

The hypothesis being tested.

## Method

Faithfulness statement: how the spike replicates the real production code
path. Variants compared.

## Results

A small table of before/after numbers across at least two scales (to
expose super-linearity if present).

## Findings

Mechanism confirmed or rejected. Which variant wins. Whether the
super-linearity hypothesis matches the observed scaling.

## Wall translation

Amdahl-bounded wall improvement on the reference cell. Reference numbers
from the LDG-2479 grid baseline:
- density_high_xlarge_durable: 445.02s wall, 413.47s loop.
- density_high_large_durable: 153.76s wall, 138.86s loop.

## Caveats

The isolated overestimate factor (the v0.1.8.7 buffer spike overestimated
by ~3x). What the real-run re-profile must confirm.

## Recommendation

Proceed to v0.1.8.9 implementation ticket, or park as negative result.
```

## What this round is not

- Not authorization to change `R/fold-engine.R`, `R/fold-reconstruction.R`,
  or any other production source. Cut v0.1.8.9 implementation tickets first,
  with the spike log as the load-bearing source reference.
- Not a public performance claim. Numbers are local-host, current-source,
  ledgr-only.
- Not a benchmark. Spikes are isolated mechanism reproducers, not
  workload-level measurements. The workload grid is the
  workload-level measurement surface.
- Not a parity gate. Spikes use synthetic data and may not preserve
  byte-identical output of the real code path. The byte-identity gate
  applies to v0.1.8.9 implementation tickets, not to spike scripts.

## Cross-cutting conclusions

After all spikes complete, the cross-cutting conclusions live in
`architecture_synthesis.md` in this directory. That synthesis is the input
to the v0.1.8.9 spec packet. Until the synthesis exists, this README is the
plan-of-record.

**Status as of 2026-05-31:** Spikes 1-10 complete. Synthesis written
(`architecture_synthesis.md`). Codex peer review identified three
blocking findings on the synthesis:

1. Spike 4 (LDG-2483) is not faithful to the default durable path - the
   persistent output handler at `R/backtest-runner.R:415-437` already
   batches via `pending_cols` and flushes with `DBI::dbAppendTable`.
2. Spike 7 (LDG-2486) describes the buffer as a list of vectors; it is
   actually an environment with vector slots
   (`R/fold-reconstruction.R:155-170`). The copy-on-modify mechanism
   (via transient binding) and setv fix are unchanged.
3. Spike 7's wall translation is too direct - production durable goes
   through `ledgr_extract_fills_impl()` (`R/backtest.R:1021`) with a
   chunked reader that bounds per-chunk buffer size. The ~170s
   recovery estimate is likely over-projected.

Round 2 closes these gaps. Four follow-up tickets:

- **LDG-2490** (Spike 11): measure the persistent durable handler's
  `pending_cols` buffer at production scale. Confirm same O(N^2)
  mechanism as Spikes 6/7 and quantify setv recovery for the durable
  path. **Done — 50-80s production recovery measured.**
- **LDG-2491** (Spike 12): measure the chunked extractor's actual wall
  recovery from a setv prototype against the real production durable
  fills-extraction path. **Done — ~150s production recovery measured.**
- **LDG-2493** (Spike 13): assess yyjsonr as a drop-in replacement for
  `jsonlite::fromJSON` in hot READ paths. **Done — 100% parity, but
  recovery only ~1s on xlarge (Spike 12 Rprof over-attributed by ~40x).
  PARKED.**
- **LDG-2494** (Spike 14): assess yyjsonr byte-identity vs jsonlite for
  the canonical_json WRITE path. **Done — 72% byte-identical (numeric
  formatting differs in 3 predictable ways); 6.65x speedup; ~13-15s
  production recovery on xlarge. PROCEED-WITH-BUMP recommended — pre-CRAN
  blast radius is hours, not weeks.**
- **LDG-2492** (synthesis revision): apply the corrections, replace
  estimates with measured numbers, re-submit to Codex for sign-off.

See `spike_tickets.md` Round 2 section for the full ticket details.
The v0.1.8.9 spec packet cannot be cut until LDG-2492 completes.

## Source evidence

- `dev/bench/notes/per_pulse_complexity_findings.md` - diagnosis of the
  per-pulse R-idiom mechanisms.
- `dev/bench/notes/single_core_optimization_inventory.md` - complete
  inventory with simulation/profile classification per item.
- `dev/bench/notes/workload_grid_baseline_closeout.md` - reference workload
  grid record.
- `dev/bench/peer_benchmark/notes/three_phase_decomposition_results.md` -
  three-phase decomposition that surfaced the ephemeral asymmetry.
- `inst/design/horizon.md` - 2026-05-31 LDG-2476 optimization entry.
- `inst/design/maintainer_review/v0_1_8_7_optimization_round.qmd` - prior
  cycle methodology reference.
- `inst/design/spikes/ledgr_optimization_round_spike/` - prior cycle's
  spike round, the precedent this round follows.

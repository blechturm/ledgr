# Spike Log: Ephemeral Sweep Subphase Telemetry

**Date:** 2026-06-01 - **Host:** local development host (Windows, R 4.5.2,
collapse 2.1.7, yyjsonr 0.1.22) - **Status:** v0.1.8.10 spike-round
Batch A input (LDG-2515, Spike 11). Infrastructure spike paired with
Spike 1 (LDG-2505).

**Script:** `dev/spikes/spike-ephemeral-subphase-telemetry.R`. Raw CSV:
`dev/bench/results/spike_ephemeral_subphase_telemetry.csv`.

**Relates to:**
- `R/sweep.R:1364-1384` (`ledgr_sweep_telemetry_env()` — the existing
  telemetry struct, extended with three new fields)
- `R/sweep.R:919-934` (`ledgr_sweep_candidate_execute` — the production
  call site needing the proc.time wrap)
- `dev/bench/peer_benchmark/peer_benchmark.R:323-376`
  (`peer_run_ledgr_ephemeral` — the existing pattern for manual phase
  timing that this spike formalises into the sweep telemetry env)
- LDG-2505 / Spike 1 (paired: the recovery measurement Spike 11 enables
  on the production workload grid)

## Question

Prove that proc.time() snapshots around (engine + handler buffer writes)
and (reconstruction + fills extraction) can be wired into the existing
`ledgr_sweep_telemetry_env()` pattern so the workload-grid harness
reports ephemeral subphase costs (engine_sec, results_sec,
fills_extract_sec) without bespoke harness code per cell.

## Method

Wrap the production sweep candidate body shape (R/sweep.R:919-934) with
proc.time snapshots that write three new telemetry env fields:

- `t_engine` — wall around `ledgr_execute_fold(execution, output_handler)`
- `t_results` — wall around `ledgr_sweep_summary_from_ordered_events()`
- `t_fills_extract` — wall around the fills sub-extraction (placeholder
  on the ephemeral path; non-zero on the durable path's chunked extractor)

The fold engine, memory output handler, and reconstruction call are all
unchanged. Only the telemetry env constructor gains three field slots
and the candidate executor gains six proc.time calls.

Run a synthetic ephemeral candidate at two scales with a trivial
toggle strategy that fires real fills every 7 days (~180 rebalance
events on a 1260-pulse run; cycles target across {0, 50, 100, 25} so the
engine produces fills and reconstruction has lot-state work).

## Results

```
scale  n_inst n_pulses n_events engine_sec results_sec fills_extract_sec total_sec
small      50     1260     8250       3.36        0.68            0.0000      4.04
medium    200     1260    33000      16.90        2.56            0.0000     19.46
```

**Non-NA across all scales: PASS.** All three new telemetry fields
populate cleanly and round-trip through the synthetic workload-grid CSV
shape.

### Engine vs results ratio at this strategy

- 50 inst / 8.25k events: results = 20% of engine wall.
- 200 inst / 33k events: results = 15% of engine wall.

Production Spike 1 results-cost grows linearly with event count; engine
cost grows roughly with `n_inst x n_pulses`. The ratio shrinks as
universe size grows because engine work outpaces reconstruction work
above a few hundred instruments. On a production xlarge cell
(1000 inst x 1260 pulses x ~130k events) results_sec/engine_sec would be
around 10-15% on this strategy shape — useful framing for Spike 1's
recovery proposal but not a hard production projection.

### Fills extraction on the ephemeral path

`fills_extract_sec = 0` at every scale because on the ephemeral path
`summary$fills` is a pre-built tibble produced inside
`ledgr_sweep_summary_from_ordered_events()`; there is no separate
extraction phase to time. This field exists in the spec because the
durable path's chunked extractor (`R/backtest.R:1021-1276`) is the
non-trivial fills-extract phase — for the durable workload grid it
captures the v0.1.8.9 setv-rewrite win. On ephemeral rows the field
stays at 0 by design and serves as a schema-aligned column rather than
a hot measurement.

## Findings

**Mechanism confirmed; infrastructure is small.** The whole prototype
is six proc.time calls and three telemetry env field slots. No fold
engine, output handler, or reconstruction changes. Workload-grid
harness reads the env after candidate execution and writes the values
to its existing CSV row, the same way it already does for
`t_pre` / `t_post` / `t_loop`.

**Ship as infrastructure alongside the Spike 1 / 10 implementation
ticket, not as a separate optimization lane.** The decision rule in
the spike spec confirms this disposition: "Log states this is
infrastructure to ship alongside the Spike 1 implementation ticket,
not a separate optimization lane."

The cost attribution that Spike 11 enables is the v0.1.8.10
spec's headline measurement: at the production xlarge_ephemeral cell,
how much of total wall is reconstruction-eligible? Spike 11 makes that
number readable directly from the workload-grid CSV instead of
requiring bespoke peer-benchmark harnessing.

## Implementation notes for the v0.1.8.10 ticket

1. In `R/sweep.R:1364-1384`, add three field slots to
   `ledgr_sweep_telemetry_env()`:

   ```r
   telemetry$t_engine <- NA_real_
   telemetry$t_results <- NA_real_
   telemetry$t_fills_extract <- NA_real_
   ```

2. In `R/sweep.R:919-934` (`ledgr_sweep_candidate_execute` body):
   surround `ledgr_execute_fold()` with proc.time snapshots writing
   `telemetry$t_engine`; surround
   `ledgr_sweep_summary_from_ordered_events()` with proc.time snapshots
   writing `telemetry$t_results`. Fills-extract phase stays 0 on the
   ephemeral path until Spike 1's inline-equity ticket reshapes the
   fills emission path.

3. Workload-grid harness (`dev/bench/workload_grid/...`) adds three CSV
   columns: `engine_sec`, `results_sec`, `fills_extract_sec`. The
   existing `phase_sec` aggregation can sum engine + results into a new
   `engine_plus_results_sec` if needed for ranking.

4. Backward compatibility: existing telemetry consumers see three new
   fields that default to NA. No existing field is renamed, removed,
   or changed in meaning.

Source references for the ticket:

- `R/sweep.R:1364-1384` (telemetry env constructor)
- `R/sweep.R:919-934` (production candidate executor body)
- `dev/bench/peer_benchmark/peer_benchmark.R:323-376` (the manual
  phase-timing pattern this formalises)
- `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
  residual 2 (ephemeral phase visibility)

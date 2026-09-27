# Fold writer and strategy accessor levers: summary report

**Status:** measured 2026-09-26 to 2026-09-27; input for a future workstream or ticket cut. Findings
bind no design. The maintainer writes the brief and decides the tickets.
**Baseline:** detached worktree at `b14579f`, R 4.6.1 on Windows, collapse 2.1.8, duckdb 1.5.5.
Release shape: 500 instruments × 1,260 sessions, SMA 5/10 alias strategy, 68,201 fills.
**Drift to `v0.2.0.2` (f96b495):** the measured paths are unchanged. That covers the per-fill loop,
both output handlers, the accessor factories, the feature-map lookup, the strict feature engine
and the demo strategy. `R/fold-engine.R` and `R/pulse-context.R` changed only in context field
names and a new `feature_table_current` helper. The checkers therefore report a blob mismatch for
those two files on the release branch; that reflects the baseline, not a defect.
**Evidence:** `dev/spikes/{collapse-preparation, fill-event-block-write, feature-accessor-lookup,
combined-writer-accessor}/`. Each has a runner, recorded CSVs, a diff checker, a gut and
`findings.md`.

## Answer

Two changes are worth taking forward. Together they cut warm wall time with byte-identical results:

| Workload (release shape) | base | both changes | saving |
|---|---|---|---|
| `ledgr_run` | 67.6 s | 52.0 s | 22% |
| `ledgr_sweep`, one candidate (the peer-benchmark shape) | 44.2 s | 27.7 s | 38% |
| `ledgr_sweep`, compiled `spot_fifo` | 27.8 s | 20.8 s | 25% |
| `ledgr_sweep`, 8 candidates | 242.5 s | 146.2 s | 38% (91 s) |
| monthly-rebalance `ledgr_run` / `ledgr_sweep` | 18.6 / 6.1 s | 17.3 / 4.5 s | 7% / 26% |

A third lever matters more for strategies that pass an explicit feature map, the form the indicators
vignette teaches. Remembering the last validated map cuts such a run from 155.7 s to 58.8 s (−62%), with
identical results.

`collapse::rsplit()` for bar preparation was measured and rejected.

## The levers

### 1. Per-pulse block write of fill events

**What.** Today each fill event is written into the pending buffer value by value: 11 scalar writes
per event in the run writer and 16 in the sweep writer, plus 9 per accounting leg. The change stages
a pulse's rows and flushes them once, after the fill loop, with one `collapse::setv()` per column.
It touches:
- `ledgr_execute_fold()` (`R/fold-engine.R`): one `flush_pulse_events()` call after
  `for (entry in accounting_events$fills)`;
- `ledgr_persistent_output_handler()` (`R/backtest-runner.R`);
- `ledgr_memory_output_handler()` (`R/sweep.R`).

`db_live` and the compiled `spot_fifo` accountant already write differently and are untouched.

**Worth.** Alone: `ledgr_run` −6.5 s (10%), one-candidate sweep −8.7 s (21%). The saving is
per-call dispatch overhead removed, and it follows fills per pulse:
- about nothing at 10 instruments (about 1 fill per pulse);
- the full share from about 150 instruments trading together.

**Safety.** All parity surfaces are byte-identical in every case, including availability, `db_live`,
`checkpoint_every = 2` and reversals with fees. The checker's gut, which writes staged columns out of
order, is caught.

The failure path needs no new semantics. An error on the 9th of 20 fills in a pulse leaves every
durable workflow FAILED with 0 persisted events, in both arms. The whole fold runs inside one
`DBI::dbWithTransaction()`, so staged rows can never reach the store. In a sweep, only the failing
candidate fails.

### 2. Prepared fast-context feature accessors

**What.** `ctx$feature()` and `ctx$features()` currently do three things on every call:
- an `%in% universe` scan;
- named-vector subsetting;
- re-normalization of the active alias map, allocating about 4 KB at 500 instruments.

The change builds hashed instrument, universe and feature-id lookups once per run and normalizes
the alias map once. Validation, error classes and messages are unchanged. It touches
`ledgr_projection_feature_accessor_state()` and `ledgr_projection_feature_bundle_accessor_state()`
in `R/runtime-projection.R`.

**Worth.** About 7 s per 630,000 strategy calls, whatever the workflow: `ledgr_run` −10%,
one-candidate sweep −19%, compiled sweep −25%. Per call, 17.6 µs becomes 7.4 µs, and allocation
per call falls from 4 KB to 0, which is about 2.5 GB less short-lived allocation per run. The
saving scales with the number of `ctx$features()` calls, so it is small below about 50 instruments.
The demo strategy (`ledgr_demo_sma_crossover_strategy()`) and the indicators vignette use this
per-instrument form. The strategy-authoring vignette, rewritten on `v0.2.0.2` after these
measurements, teaches the vectorized `ctx$vec$feature()`. Neither change touches that path, and
its cost was not measured.

**Safety.** 48 parity rows and 33 conformance rows are identical. The conformance rows cover the
value, or the error class and message, for 11 call shapes, including unknown instruments and
features. The gut, which shifts instrument rows, is caught.

### 3. Explicit feature maps: validated twice on every call

**What.** `ctx$features(id, feature_map)` is the form the indicators vignette teaches. On every call, `ledgr_feature_lookup_map()` validates the map object,
then calls `ledgr_feature_id(feature_map)`, which validates it again. Each validation re-derives the
ids by flattening the indicator list, though the object already holds `feature_ids`. The call costs
about 155–165 µs, against 19 µs for the alias form (`uncovered_paths_probe.R`,
`explicit_map_probe.R`).

Two alternatives were measured, both on top of the prepared accessors:
- **validate once:** drop the second validation and read `feature_map$feature_ids`, with the same
  unresolved-declaration check;
- **memo:** validate once, and remember the last map whose lookup succeeded, reusing its lookup
  when the next map is `identical()`. Production would hold the memo per accessor, that is per run.

| Lookup (explicit concrete map, 500 instruments) | per call | explicit-map `ledgr_run` at release shape |
|---|---|---|
| production (prepared accessors off) | 165 µs | 155.7 s |
| today's lookup, run on prepared accessors | 145 µs | 152.8 s |
| validate once | 71 µs | 124.7 s (−20%) |
| memo | 11 µs | 58.8 s (−62%) |

Fills and equity were identical in every run. A 15-call conformance sequence gave identical values,
or identical error classes and messages, for all three arms. It covered repeated maps, a rebuilt
equal map, a reordered map, a parameterized map, tampered `feature_ids`, swapped aliases, an unknown
feature, a character map and a non-map.

Validation is a pure function of the map's content, and `identical()` compares content. So the memo
is exact: a modified map is not identical, and it is revalidated. With the memo, the explicit-map
form runs as fast as the prepared alias form (59.5 s).

### Together

The savings add up:

| Workflow | block alone | prepared alone | sum | measured together |
|---|---|---|---|---|
| `ledgr_run` | 6.5 s | 6.9 s | 13.4 s | 14.8 s |
| one-candidate sweep | 8.7 s | 8.2 s | 17.0 s | 16.5 s |

In a same-session four-arm phase, combined minus block alone is 7.3 s (run) and 7.2 s (sweep),
matching the accessor spike.

Where the time went, from a profile of each arm at release shape (`ledgr_run`):
- fill-event writing: 11.8 → 6.2 s;
- `ctx$features`: 9.3 → 4.6 s;
- sampled total: 45.8 → 35.7 s.

## Peer benchmark

The peer benchmark (`dev/bench/peer_benchmark/peer_benchmark.R`) times three lanes:
- `ledgr_run`;
- a one-candidate canonical sweep;
- a one-candidate compiled `spot_fifo` sweep.

Its strategy reads `ctx$features_wide`, which the dense path builds once per run. So:
- the accessor changes move no peer lane;
- the block write reaches the run and canonical sweep lanes, by an amount set by the peer
  strategy's fills per pulse, which was not measured here;
- the compiled lane is unaffected.

## Proposed cut

The two main levers touch disjoint code and add up, so they can be separate tickets in either
order.

| Ticket | Scope | Acceptance (from the spike checkers) |
|---|---|---|
| Block write | `flush_pulse_events()` in the output-handler interface; both R handlers stage and flush; the fold calls it once after the fill loop | byte-identical events, fills, equity and trades (run) and columns, returns and trades (sweep) on: alias SMA, reversal with fees, availability uneven, `db_live`, `checkpoint_every = 2`, multi-candidate; a regression test that detects misordered staged columns; failure-path test (FAILED, 0 events); release-shape gain ≥ 5% on run and sweep |
| Prepared accessors | the two factories in `R/runtime-projection.R` | identical values and errors on the conformance call shapes; parity on alias, explicit map, scalar and availability cases; gain ≥ 5% |
| Explicit-map lookup | `ledgr_feature_lookup_map()` (validate once), plus a per-accessor memo in the bundle accessor | identical values and errors on the 15-call conformance sequence; explicit-map parity (run and sweep); gain ≥ 5% on an explicit-map strategy |

Each ticket also carries the standing review obligations: the seven-antipattern walk and a perf
measurement before acceptance.

**Decisions for the maintainer:**
1. Make `flush_pulse_events()` part of the output-handler contract. The invariant: nothing reads a
   staged row before the flush, except the handler's own `record_accounting_fact()`.
2. State in the contract or code that the active alias map is fixed for a run. The prepared
   accessors rely on it.
3. Explicit maps: validate once only (−20%, a pure refactor), or also the per-accessor memo (−62%).
4. Whether durable-run atomicity should be written into the contracts. It holds today through the
   transaction scope. No block-write failure semantics are needed.

## Found on the way, not spiked

- **Availability-path runs are about 4× dense, and most of it is feature computation.** In a
  cold-cache availability run at release shape (sessions, stale(2)), 283 s of wall time under the
  profiler, the time splits as follows:
  - `ledgr_compute_feature_series_strict()` took 58% of sampled time;
  - the fold took 25%;
  - `ledgr_results()` took 12%, mostly `ledgr_fill_recording_pulses_from_evidence()`.

  The dense run took 68 s. The strict path (`R/features-engine.R:286`) does all of this for every
  bar of every instrument and feature:
  - slices a window from a data frame;
  - checks it for completeness;
  - calls `fn` and `series_fn` on it;
  - compares the two with `all.equal()`.

  That is R-level iteration over bars. The in-session feature cache hides it after the first run.
  A concurrent `segmented-feature-views` spike was running on this machine and may address this
  path (`availability_attribution_probe.R`).
- Per-pulse availability accessor rebuilds cost about 63 ms per run. They are not worth a ticket.
- The next writer-side costs are:
  - per-fill row and JSON construction (`ledgr_fill_event_payload()`, about 6 s of a run);
  - lot accounting (about 7 s of a run; the compiled accountant is sweep-only);
  - the run-start snapshot hash guard (about 7%).
- `ledgr_fill_row_buffer_add_many()` copies whole columns on every call (style shape 7). It is
  about 3% of a compiled sweep.
- From the rejected rsplit spike:
  - base `split()` orders groups by `LC_COLLATE`, so the precompute object's order is
    machine-dependent for mixed-case ids;
  - indicator callbacks see universe-dependent `row.names`;
  - availability hydration cannot detect a misgrouped split;
  - `ledgr_with_collapse_deterministic()` has no call sites.
- The 2026-09-18 horizon statement that `features_wide` is rebuilt every pulse is wrong for the dense
  path, which builds it once. Availability runs subset it per pulse with `%in%`.

## Declined

- `collapse::rsplit()` for bars by instrument: about 60 ms per preparation call, under 1% of a run.
  Exact output would also need per-group conversions.
- No other collapse primitive showed up in the release-shape profiles above the 5% gate.

## Measurement notes

- The machine is shared with other sessions, whose R processes and background load added up to 20%
  noise. Timed observations record the other processes' CPU and any other R processes, and loaded
  pairs were re-measured under a rule declared in advance. One kept sweep pair in the combined
  recording still overlapped another session. Without it, the median saving moves from 16.5 s to
  16.4 s.
- R 4.6.1's JIT byte-compiles a closure made in a local environment only for the first copy of its
  code in a session. A second seam copy ran interpreted, at about 17 µs instead of 8 µs per call,
  and faked an "interaction" in the four-arm phase. Only that arm was affected. The runners now
  compile seams with `compiler::cmpfun()`. Installed packages are byte-compiled at install, so this
  affects harnesses, not ledgr.
- All timings use `pkgload::load_all()` code on one Windows machine. The width clocks have 3
  repetitions. Walk-forward and the peer lanes were not timed.

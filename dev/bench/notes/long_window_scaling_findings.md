# Long-Window Scaling Findings

Created: 2026-10-02
Status: research findings for maintainer review; not a fix and not a public
performance claim.
Brief: "ledgr run cost grows faster than run length", from EXP-0003 (ledgr
usability on Sharadar data), received 2026-10-02.
Code measured: `v0.2.1.0` (`5f19dbc`) and the `v0.2.2` head (`63dcaaa`). Their
`R/`, `src/`, `tests/`, `DESCRIPTION` and `NAMESPACE` are byte-identical.
Reproducer: `dev/bench/long_window/` (synthetic, vendor-neutral; see the end).

## Headline

**No cost in the pulse loop is badly superlinear. EXP-0003's 30-minute
timeout is one dominant constant: the availability-aware feature path
evaluates every indicator window from scratch, and it is paid in full on every
cold run, every sweep call and every walk-forward fold.**

1. **Strict feature computation** (`ledgr_compute_feature_series_strict()`,
   `R/features-engine.R:291`) is 88-91 % of a cold availability-aware run. It
   costs about 108-117 us per window per instrument, so cold setup is
   O(I · Σ_f (P − w_f + 1) · (c0 + c1·w_f)) with c0 ≈ 100 us dominant and c1
   small: linear in pulses for a fixed width, fitted exponent 1.09 from 1,514
   to 6,056 pulses. At EXP-0003's shape (about 1,150 instruments, 7,470
   sessions, `ledgr_ind_returns(63/126/252)`) that is about 25.3 million
   windows, **about 45-50 minutes**. A masked vectorised `series_fn` produces
   identical values and NA masks **393-543 times faster**, which would make the
   same work a few seconds.
2. **The full snapshot re-hash** runs on every `ledgr_run()` and every
   snapshot-backed facts reader call, at 8.4-9.8 us per bar with exponent 1.2.
   At about 8.6 million bars that is roughly 70-100 s. It is most of
   EXP-0003's ~80 s warm per-run setup and its ~70 s per
   `ledgr_facts_resolve()` call.
3. **Per-run durable writes** grow with pulses × instruments: every run
   rewrites all feature values (about 25.8 million rows at EXP-0003's shape),
   which nothing ever reads, plus one diagnostic row per member and pulse.
4. **There is no feature reuse** across processes, sweep calls or
   walk-forward folds: a second identical sweep costs exactly as much as the
   first.

EXP-0003's pattern (first run timed out at 30 min, second about 25 min, later
runs about 80 s) is reproduced: later runs in the same R process hit an
in-memory feature cache; a fresh process recomputes everything.

**Measurement conditions.** Windows 11, R 4.6.1, duckdb 1.5.6.9000, 64 GB RAM.
EXP-0003, a CPU-bound single-core R process of up to about 7 GB, ran on the
same machine throughout. Measurements ran one process at a time. Treat
absolute seconds as approximate; exponents and ratios are what matter.

## 1. Scaling Tables

Unless stated, the snapshot is availability-aware with complete membership
snapshots, 500 members, 2 % churn per set, `ledgr_valuation_stale(2)`, zero
cost, and the monthly top-10 momentum strategy of EXP-0003 with
`ledgr_ind_returns(63/126/252)`. Run 1 is cold; run 2 repeats the experiment
in the same process. Setup is `ledgr_run()` entry to the first strategy call;
the loop is first to last strategy call; finalise is the rest.

### Pulses (600 instruments, 12 membership sets)

| pulses | bars | cold setup | strict windows / instr. | warm run | loop | ms/pulse | finalise | peak memory | feature rows / run |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 252 | 0.15 M | 21.3 s | 315 | 8.7 s | 2.1 s | 8.5 | 3.5 s | 555 MiB | 0.45 M |
| 757 | 0.45 M | 124.4 s | 1,830 | 16.9 s | 6.8 s | 8.9 | 5.2 s | 837 MiB | 1.4 M |
| 1,514 | 0.91 M | 276.1 s | 4,101 | 29.0 s | 13.2 s | 8.7 | 6.7 s | 1,323 MiB | 2.7 M |
| 3,028 | 1.8 M | 568.7 s | 8,643 | 56.8 s | 27.1 s | 9.0 | 10.6 s | 2,145 MiB | 5.5 M |
| 6,056 | 3.6 M | 1,243.3 s | 17,727 | 111.9 s | 58.7 s | 9.7 | 17.9 s | 3,866 MiB | 10.9 M |

Fitted exponents from 1,514 to 6,056 pulses: cold setup 1.09, warm setup 1.06,
loop 1.08, finalise 0.70, peak memory 0.77. Below the 253-bar warmup the cold
setup looks superlinear (5.8 times for 3 times the pulses from 252 to 757);
that is warmup arithmetic, because cold setup tracks the strict-window count,
not the pulse count.

### Membership churn and lifetime terminals (1,514 pulses, 1,150 instruments, no features, flat strategy)

| sets | membership rows | terminals | warm setup | loop | peak memory |
|---:|---:|---:|---:|---:|---:|
| 12 | 6,000 | 0 | 16.8 s | 11.0 s | 1,419 MiB |
| 60 | 30,000 | 0 | 17.7 s | 11.1 s | 1,377 MiB |
| 300 | 150,000 | 0 | 19.1 s | 11.6 s | 1,405 MiB |
| 600 | 300,000 | 0 | 21.3 s | 12.1 s | 1,466 MiB |
| 12 | 6,000 | 500 | 14.4 s | 11.7 s | 1,270 MiB |

Fifty times more membership rows add about 4 s of setup and 1 s of loop.
Terminals add nothing measurable (the terminal case has fewer bars, hence its
lower setup). **Runs do not scale with fact volume**; they use the prepared
availability provider.

### Physical-axis width (1,514 pulses, 500 members, 12 sets, no features)

| instruments | bars | setup | ms/pulse | peak memory |
|---:|---:|---:|---:|---:|
| 600 | 0.91 M | 9.3 s | 7.3 | 952 MiB |
| 1,150 | 1.74 M | 17.0 s | 7.5 | 1,419 MiB |
| 2,300 | 3.48 M | 32.1 s | 7.9 | 2,299 MiB |

Setup follows bars (exponent 0.92, the snapshot re-hash and bar hydration);
the loop is independent of the axis width at fixed members; memory exponent
0.66.

### Sweeps, sweep results and walk-forward (757 pulses, 600 instruments, 4 candidates)

| Step | Time |
|---|---:|
| `ledgr_sweep()`, first call | 156.3 s |
| `ledgr_sweep()`, second identical call, same process | 156.1 s |
| `ledgr_sweep_save()` | 0.19 s |
| `ledgr_sweep_open()` | 0.08 s |
| `ledgr_walk_forward()`, 3 folds | 313.3 s (about 104 s per fold) |

About 124 s of each sweep call is cold strict-feature computation. Saving and
reopening sweep results is negligible.

## 2. Ranked Causes

| # | Cause | Where | Measured contribution | Complexity, observed → should be | Shape | Fix direction and expected recovery | Parity obligation | Routed to |
|---|---|---|---|---|---|---|---|---|
| 1 | Strict feature path recomputes every window from a data-frame slice and certifies scalar against series per window | `R/features-engine.R:291`; called from `R/backtest-runner.R:975` (run hydration) and `R/precompute-features.R:570` (sweep, walk-forward) | 88 % of a cold run at 757 pulses, 91 % at 3,028; ≈45-50 min at EXP-0003's shape | O(I·Σ_f(P−w_f+1)·(c0+c1·w_f)), c0 ≈ 100 us → O(I·F·P) vectorised | 2 (subset per element) and 5 (re-certifying), plus a new shape: a sliding window recomputed from scratch | One `series_fn` call per instrument over the aligned history, masked where the trailing window contains an incomplete row (rolling count of incomplete rows). Measured 393-543 times faster per instrument and feature | Template eligible only for ledgr's own built-in strict indicators whose scalar and series agree by construction, with exact semantic identity (`identical()`) of feature matrices and NA masks over gaps, mid-history entrants and warmup (measured identical for `ledgr_ind_returns()`). For user, custom and TTR indicators, removing the per-window check changes when `ledgr_indicator_gap_parity` can fire: a specification decision, not an internal optimization | v0.2.2 leakage boundary and indicator warmup session (fn/series_fn diagnostics) |
| 2 | Full snapshot re-hash on every run and every facts reader call | `R/run-snapshot.R:55`; `R/backtest.R:153` (`ledgr_backtest()` hashes twice); `R/availability-inspection.R:292`; `R/derived-state.R:58` | Warm setup ≈ hash: 17 s of 17 s at 1.74 M bars; 17 s of a 17-29 s reader call; ≈70-100 s at 8.6 M bars | O(all snapshot bars) per call, exponent 1.2 → O(data read) with part-wise verification | 5 (re-certifying); the R hash also copies its buffer per 10,000-row block and grows `block_hashes` with `c()` (shape 7) | DuckDB hashing: 6-8 times faster on one thread, 35 times on eight; part-wise verification of one fact family ≈10 ms and of a 500 × 252 window ≈0.2 s regardless of snapshot size | Not template-eligible: changes hash bytes or verification policy. The current hash is sha256 of R-serialised strings (`digest()` default `serialize = TRUE`), so no tool but R can recompute it, and DuckDB's `round`/`printf` differ from R's `round`/`sprintf` at rounding ties and large magnitudes | v0.2.2 snapshot verification session |
| 3 | Every run rewrites all feature values into `features`, which nothing reads | `R/run-finalize.R:535`; no `SELECT ... FROM features` anywhere in `R/` | Persist off at 1,514 pulses: finalise 7.2 → 0.7 s, warm run 29.0 → 22.3 s, peak memory 1,323 → 1,142 MiB; ≈25.8 M rows per run at EXP-0003's shape | O(I·P·F) rows per run, written in one transaction, one append per instrument | new shape: write-only persistence | Persist on request only, or once per snapshot and feature definition | Not template-eligible: changes persisted rows | v0.2.2 long-window performance workstream |
| 4 | No feature reuse across processes, sweep calls and walk-forward folds | `R/feature-cache.R` (per-process registry, never evicted); availability-aware sweeps bypass it and refuse precomputed features (`R/sweep.R:168`); `ledgr_sweep_window()` per fold | Second identical sweep 156.1 s against 156.3 s; walk-forward ≈104 s per fold | Each call pays #1 again | 5 (recomputing) | After #1 this matters far less; then share one computation per snapshot and definition across a sweep's folds | Not template-eligible: changes the cache lifecycle | Indicator session (after #1), else the long-window workstream |
| 5 | One diagnostic row per member and pulse, and a `MAX(diagnostic_seq)` query per flushed 4,096-row chunk | `R/backtest-runner.R:428-440` | 758,514 diagnostic rows per run at 500 × 1,514; ≈3.7 M at EXP-0003's shape. The quadratic term is not yet visible in loop time (8.5 → 9.7 ms/pulse from 252 to 6,056 pulses) | MAX scan O(rows so far) per chunk → O(R²/4096) overall; should be O(1) per chunk | 5 (re-deriving a sequence from the table) | Hold the next sequence in the handler; read it once on resume | Template-eligible: byte identity of `diagnostic_seq` and all diagnostic rows, including resume | Long-window workstream |
| 6 | Membership resolution for `ledgr_facts_resolve()` subsets the whole membership table per set and scans per instrument | `R/availability-provider.R:59` (only caller: `R/availability-inspection.R:107`) | Without the re-hash: 0.20 s (6k rows), 0.75 s, 4.64 s, 11.33 s (300k rows); local exponent 1.29 | ≈ O(sets · rows + sets · members²) → O(rows) | 2 (full-table subset per ID) and replaying every set although a complete set resets state | Group rows by set once; start from the last complete set at or before the cutoff | Template-eligible: exact semantic identity of resolution rows and evidence | Long-window workstream |
| 7 | Session facts built one civil date at a time (LFB-016, already registered) | `ledgr_facts_sessions()` | 42.8 s for 10,473 civil dates in `America/New_York` (4.1 ms per date); 17.3 s in UTC | O(dates) with a large constant → vectorised | 3 (per-element format or parse) | Resolve local open and close times per timezone in one vectorised call | Template-eligible: exact identity of session facts and the snapshot hash | Long-window workstream |

`ledgr_fold_asset_state_normalize()` grows slightly faster than pulses (5.2
times for 4 times the pulses) at about 1 % of a cold run: noted, not analysed.
`ledgr_features_at_pulse()` and `ledgr_features_at_pulse_cached()`
(`R/backtest-runner.R:1287`, `:1402`) carry per-pulse DELETE and append with
per-element formatting, but nothing in `R/` calls them: dead code.

### The strict window in detail

Per-window cost at 3,028 pulses, from `dev/bench/long_window/lw_strict_breakdown.R`
(one instrument whose first 20 % of sessions are missing, with isolated gaps):

| feature | width | windows | data-frame slice | completeness check | scalar fn | `series_fn` on window | `all.equal()` | strict total | vectorised | speedup |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `return_63` | 64 | 2,965 | 41.6 us | 16.9 us | 10.1 us | 6.8 us | 10.1 us | 250 ms | 0.46 ms | 543× |
| `return_126` | 127 | 2,902 | 41.4 us | 17.2 us | 10.3 us | 10.3 us | 6.9 us | 220 ms | 0.56 ms | 393× |
| `return_252` | 253 | 2,776 | 49.2 us | 14.4 us | 10.8 us | 7.2 us | 10.8 us | 203 ms | 0.44 ms | 455× |

Values and NA masks of the vectorised candidate are identical to the strict
path in all three. Slicing barely grows with width (41.6 → 49.2 us from 64 to
253 rows), so the cost is per-call overhead, not the copy. In the profile of a
cold run, `[.data.frame` is 45-47 %, `vapply` 19-20 %,
`ledgr_normalize_feature_scalar_output()` 14 % and `all.equal()` 10 % of the
total; `ledgr_execute_fold()` is 4-5 %, `ledgr_snapshot_hash()` 2.5 %.

## 3. Memory

Peak working set grows with exponent 0.77 in pulses and 0.66 in axis width.
Scaling the 6,056 × 600 point (3.9 GB) by cells to EXP-0003's 7,470 × 1,150
predicts several GB, consistent with the observed 7.0 GB. The only term
attributed so far is feature persistence (14 % of peak at 1,514 × 600, from
the persist-off run); the rest is unattributed. Candidates from the code:
the per-instrument aligned bar frames and the bar and feature matrices built
at hydration, the in-memory feature cache, and the transaction that rewrites
the `features` table. A memory profile per phase is an open item.

## 4. Reader Paths

On 1.74 M bars and 300k membership rows (`lw_readers.R`):

| Call | Total | Without the re-hash |
|---|---:|---:|
| `ledgr_facts_resolve()`, membership, one instant | 28.9 s | 10.8 s |
| `ledgr_facts_history()`, membership | 21.5 s | 4.5 s |
| `ledgr_facts_history()`, sessions | 17.2 s | 0.25 s |
| loading all fact data (`ledgr_availability_provider_data()`) | 0.18 s | |

Each call re-hashes the whole snapshot (17 s here), as `contracts.md:327`
requires, then loads every fact family. `ledgr_facts_resolve()` adds the
quadratic membership resolution of cause 6. EXP-0003's ≈70 s per resolve call
at 8.6 M bars is the re-hash plus that resolution.

Verification is not consistent across entry points today:

| Entry point | Full snapshot re-hash |
|---|---|
| `ledgr_run()` | once, at fold entry |
| `ledgr_backtest()` | twice: `ledgr_snapshot_validate()`, then the run's guard |
| `ledgr_sweep()`, and walk-forward folds through it | never: trusts the stored hash |
| `ledgr_promote()` | once, through `ledgr_run()` |
| `ledgr_facts_history()`, `ledgr_facts_resolve()` | once per call |
| `ledgr_state_reconstruct()` | once |
| `ledgr_snapshot_open(verify = TRUE)`, `ledgr_snapshot_list(verify = TRUE)` | on request |

## 5. Snapshot Hashing Spike

`dev/bench/long_window/hash_spike.R`, on the sealed snapshots of the pulse
sweep (600 instruments, 7,552-15,678 fact rows), DuckDB pinned to one thread
unless stated:

| bars | R full hash | of which facts JSON | DuckDB bars hash | R ÷ DuckDB | one fact family (DuckDB) | 500 × 252 window (DuckDB) |
|---:|---:|---:|---:|---:|---:|---:|
| 0.15 M | 1.14 s | 0.10 s | 0.17 s | 6.1 | 0.01 s | 0.14 s |
| 0.45 M | 3.31 s | 0.11 s | 0.50 s | 6.4 | < 0.01 s | 0.14 s |
| 0.91 M | 6.80 s | 0.14 s | 1.03 s | 6.5 | 0.01 s | 0.16 s |
| 1.8 M | 15.2 s | 0.20 s | 2.11 s | 7.1 | 0.02 s | 0.17 s |
| 3.6 M | 35.8 s | 0.28 s | 4.29 s | 8.3 | 0.01 s | 0.22 s |
| 3.6 M, DuckDB 8 threads | | | 0.995 s | 34.7 | 0.02 s | 0.07 s |

Correctness: DuckDB's row text matched R's byte for byte on all 151,200 rows
of the smallest snapshot, but not on constructed edge values (rounding ties
such as 0.123456785, 123456789.123456789, and values above about 1e15). Block
hashes differed even with identical row text, because ledgr hashes R's
serialised form of each string. A DuckDB-computed hash therefore requires a
new hash rule (version 3), with a number encoding that does not depend on
`sprintf` rounding. The facts JSON was cheap at these fact volumes; it has not
been timed at EXP-0003's 303k membership rows with a provenance blob on each
(LFB-015).

## 6. `v0.2.1.0` Against `v0.2.2`

The product code is byte-identical between the two (`git diff` over `R/`,
`src/`, `tests/`, `DESCRIPTION`, `NAMESPACE` is empty). The confirming run at
757 pulses: `v0.2.1.0` 136.4 s cold / 16.9 s warm, `v0.2.2` 139.4 s / 17.0 s,
identical row counts. The `v0.2.2` head adds only design records, among them
the schedule decorator's held-pulse levers, which do not touch these paths.

## 7. Open Questions

- Memory is attributed only for feature persistence (section 3).
- `ledgr_fold_asset_state_normalize()` grows faster than pulses at 1 % share.
- The facts JSON part of the snapshot hash at EXP-0003's fact volume.
- The diagnostic `MAX()` query's contribution, which needs a run long enough
  for the quadratic term to show, or a direct micro-measurement.
- Whether the in-memory feature cache, never evicted, matters for long
  sessions with many distinct windows.
- Real data differs from the synthetic reproducer in price paths, gaps,
  entrants and session calendars. The ranking and exponents should carry over;
  absolute seconds should be confirmed against EXP-0003's own timings, such as
  its 2019-2021 comparison run.
- An interrupted run leaves a run row in status CREATED (reported by
  EXP-0003, not investigated here).

## Reproducer

Scripts in `dev/bench/long_window/`; raw results in its `results/` folder
(`results.csv` holds every run row). The work folder defaults to
`C:/tmp/ledgr-lw-work`; set `LW_WORK` to change it. Load ledgr from a source
checkout passed as `<repo>`.

```sh
# one configuration: sessions instruments members sets churn terminals, then
# strategy (momentum | flat), wall ceiling in seconds, profile (0|1), runs
Rscript dev/bench/long_window/lw_drive.R <repo> pulses_3028 3028 600 500 12 0.02 0 momentum 1800 0 2
LW_NOFEAT=1 Rscript dev/bench/long_window/lw_drive.R <repo> facts_s600 1514 1150 500 600 0.02 0 flat 1800 0 2
LW_PERSIST=FALSE Rscript dev/bench/long_window/lw_drive.R <repo> persist_off 1514 600 500 12 0.02 0 momentum 1800 0 2
Rscript dev/bench/long_window/lw_strict_breakdown.R <repo> 3028 3
Rscript dev/bench/long_window/hash_spike.R <repo> <snapshot.duckdb> check
LW_DUCK_THREADS=1 Rscript dev/bench/long_window/hash_spike.R <repo> <snapshot.duckdb> time 2
Rscript dev/bench/long_window/lw_readers.R <repo> <snapshot.duckdb>
Rscript dev/bench/long_window/lw_resolve_scaling.R <repo>
Rscript dev/bench/long_window/lw_sweepwf.R <repo> <snapshot copy> <out.json>
```

`lw_drive.R` builds and caches one sealed snapshot per configuration
(`lw_build.R`), copies it, and runs `lw_run.R` in a fresh process under an
external working-set sampler (the availability-closeout sampler, with a
quoting fix). Environment switches: `LW_NOFEAT=1` (no features),
`LW_PERSIST=FALSE` (`persist_features = FALSE`), `LW_DUCK_THREADS`.

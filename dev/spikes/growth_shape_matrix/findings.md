# Growth-shape matrix: findings

Spike under `spike_protocol.md`; binds nothing, changes no product code. Base
`4b729300` (codex/cut14-v0.2.2), DuckDB 1.5.6.9000, collapse 2.1.8, TTR 0.24.4,
R 4.6.1, Windows, shared machine. Runner `matrix.R`, checker `check.R`,
evidence `evidence/` (raw timings, exponents, three Rprof summaries). Copied
to v0.2.2 from branch `spike/growth-shape-matrix` at `3a539ca4`; this file was
written from the spike agent's report.

**Question.** Which cells of feature kind x execution mode x entry point grow
superlinearly in bars per instrument (T), instruments (N) or sweep candidates
(C); in which phase and at which file:line?

**Prerequisite: yes.** Every cell builds from `ledgr_sim_bars()` (dense
snapshot, or the same bars plus implied sessions in `Etc/GMT+1` copied from the
one-execution-mode probe, fixed full universe, `ledgr_valuation_stale(0,
"refuse")`) and runs in seconds at T=250, N=20, C=2. One exception is refused
by contract, not by time: BBands through `ledgr_ind_ttr()` has no
`strict_window` contract, so availability refuses it at `ledgr_experiment()`
(`ledgr_indicator_gap_unsupported`). Only TTR `SMA` on close is strict-certified
(`R/indicator-ttr.R:255-272`).

**Method.** Features: none (closes), built-in `sma_5`/`sma_10`/`returns_5`,
TTR SMA 5/10, TTR SMA + BBands `mavg` (dense only), custom scalar-window
`ledgr_indicator(fn = ...)` 5/10. Entries: `ledgr_run()` (telemetry `t_pre`,
`t_loop`, `t_post`, derived `other`), `ledgr_results()` equity/fills/trades/ledger,
`ledgr_sweep()`, `ledgr_walk_forward()` with 3 contiguous rolling folds (totals
only). Sizes: T 250/1,000/4,000 (N=20); N 20/80/320 (T=250); C 2/8/32 (sweep).
The third sizes ran only `ledgr_run()`, readers and sweep. One fresh process
per (feature, mode, size), JIT warm-up on a tiny fixture, 2 repetitions in
alternating size order, 60 s cap per entry. Exponent = log(t2/t1)/log(s2/s1)
on medians; superlinear means > 1.15 with the larger median >= 0.30 s.

**Matrix** (exponents for the phase that dominates each entry; full table in
`evidence/exponents_wide.csv`, 406 rows):

| Cell | T 250-1k | T 1k-4k | N 20-80 | N 80-320 | C 2-8 | C 8-32 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| run `t_loop`, all kinds, dense | 0.96-1.02 | 0.97-1.02 | 0.49-0.80 | 0.69-0.94 | | | linear |
| run `t_loop`, all kinds, availability | 0.90-1.01 | 1.00-1.03 | 0.31-0.68 | 0.69-0.95 | | | linear |
| run `t_pre`, TTR SMA, availability | 1.00 | CAP | 0.99 | 0.98 (59 s) | | | linear, hits cap |
| run `t_pre`, custom, dense / availability | 0.99 / 0.93 | 1.00 / 0.98 | 1.00 / 0.92 | 0.96 / 0.98 | | | linear |
| run `t_pre`, built-in / TTR, dense | below floor | 0.92-0.93 | below floor | below floor | | | linear |
| run `t_post` | 0.28-0.61 | 0.72-0.89 | 0.32-0.62 | 0.57-0.94 | | | sublinear |
| readers fills / trades | 0.17-0.85 | 0.59-1.00 | 0.18-0.85 | 0.34-1.04 | | | linear at most |
| readers equity / ledger | below floor (<= 0.07 s) | | | | | | flat |
| sweep total | 0.70-0.97 | | 0.31-0.82 | | 0.47-0.97 | 0.66-0.88 | linear at most |
| walk-forward total | 0.54-0.89 | | 0.25-0.74 | | | | sublinear |
| seal | 0.09-0.28 | 0.22-0.56 | -0.05-0.12 | 0.16-0.27 | | | sublinear |

**Superlinear cells: none.** All 284 above-floor rows are linear (66) or
sublinear (218); the largest exponent is 1.04 and the widest per-repetition
spread 0.25. No product cell needed Rprof for a superlinear phase.

**Cells that hit the cap:** TTR SMA x availability x `ledgr_run()` at T=4,000
(60 s, both repetitions) and at N=320 (64 s, not interrupted because the cap
fires only at R interrupt checks; `t_pre` 59 s). Linear growth on a large
constant: `t_pre` 15.4 s against 0.12 s dense at T=1,000 (130x). Rprof (base
size): 59% in `ledgr_compute_feature_series_strict_scalar`, TTR reached through
`try.xts` per window. The site is the per-window loop
`R/features-engine.R:313-345`, which calls `fn` and then `series_fn` on every
window for a parity check. It is taken because `ledgr_strict_builtin_kind()`
(`:351`) returns NULL for TTR; the callers are `R/backtest-runner.R:1120` and
`R/precompute-features.R:661`. Manual shape 3 (per-element calls where a
vectorised call exists) and shape 5 (the series recomputed per window for the
parity check).

**Linear constant-factor outliers** (not growth; listed because they are the
same family the matrix is meant to find):

- Custom scalar-window indicator, the documented `fn` form: dense `t_pre`
  2.2 s at T=1,000 vs 0.13 s built-in (17x), 8.8 s at T=4,000. Per-bar loop
  `R/features-engine.R:285-286` subsets a data-frame window per bar
  (`:253`). Availability takes `:313-314`. Shape 2/3.
- Fills and trades readers: 2.1 s for about 40k fills vs 0.06 s for the
  ledger reader on the same events. Rprof: `ledgr_extract_fills_impl`
  (`R/backtest-fills.R:63`) replays every event through R lot accounting,
  `R/accounting-replay.R:294-322` (`ledgr_lot_apply_event` per event, 70%),
  with per-row JSON in `ledgr_prepare_accounting_events`. Shape 5 (the fold
  already computed these values) with shape 4.
- Availability fold loop 1.9-2.2x dense at T=4,000 (none 22.5 vs 12.1 s,
  built-in 12.7 vs 5.7 s), linear; the probe's fast-context site
  `R/backtest-runner.R:988`, `R/fold-engine.R:409`.

**Gut.** Feature kind `custom_quad` puts a deliberately quadratic
`outer(x, x)` step into a custom indicator's `series_fn`. The checker flags
dense `run`/`t_pre` on T 250-1,000 as SUPERLINEAR: 1.26, repetitions
1.25-1.27 (`evidence/exponents_gut.csv`); the same-shaped linear `custom` cell
reads 0.99. The run total (0.63), sweep (0.93) and walk-forward totals did not
flag it. Whole-entry clocks dilute a superlinear step, and only the phase
split exposes it.

**Verdict: green.** No cell grows superlinearly in T, N or C up to
4,000 x 20, 250 x 320 and 32 candidates. The antipattern family survives here
as linear per-bar and per-event R loops with large constants, and TTR on the
availability path reaches the cap.

**Not covered.** Phase split inside sweep and walk-forward (totals only, which
the gut shows can hide a quadratic sub-phase); walk-forward fold count,
anchored folds and C; membership-fact universes, stale marks, gaps, corporate
actions; the diagnostics/availability readers, reopened handles, `print(bt)`,
`ledgr_compute_metrics()`, sweep return readers; `workers > 1`, the compiled
accounting model, `persist_features = FALSE`; `ledgr_backtest()`; intraday
bars; Ubuntu; sizes beyond the third points, where a superlinear term with a
small constant could still appear; fill count independent of T and N.

**Rerun.** Matrix: `Rscript dev/spikes/growth_shape_matrix/matrix.R . <out>
run reps=2`, then `points=T2,N2,C2` for the third sizes. Gut: `... run reps=2
features=custom_quad modes=dense points=base,T`. Checker: `Rscript
dev/spikes/growth_shape_matrix/check.R . evidence/timings_main.csv
evidence/timings_third_size.csv out=<exponents.csv>`. Profiles: `matrix.R .
<out> profile <feature> <mode> <point>`.

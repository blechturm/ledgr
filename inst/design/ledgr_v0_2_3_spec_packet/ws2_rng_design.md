# WS2 design note: RNG reproducibility and the v2 pulse-seed rule

Role: record; the LDG-3157 design note for v0.2.3 cut 4, workstream 11.
Status: draft for review, correction round 1 (applies the design review
`ws2_rng_design_review.md` and maintainer decisions (14), (15) and (16));
written before any
product change; it directs LDG-3158 to LDG-3161 once its design review
accepts it.
Authority: `tickets.yml` cut 4: decisions (1) to (13) and the maintainer
decisions of 2026-10-29, which are (14) (caller-isolation boundary, Type 2
on review F1, option B), (15) (argument evaluation) and (16) (callables
ledgr builds and itself runs); and the LDG-3157 scope;
`contracts.md` rule groups `contract-strategy-reproducibility` and
`contract-execution-fold-core`; `cut_review_3.md` and
`cut_review_3_rereview_1.md`; the RNG probe in
`dev/bench/v0_2_3_rng_baseline/`. Source lines cite `release/v0.2.3` at
`aa2931e9`. Timing refers to the LDG-3156 protocol on the shared timing
harness of LDG-3155.

## 1. The frozen choices in one paragraph

Pulse seeds come from rule v2: `fmix32(fmix32(u32(s)) xor u32(p)) mod
(2^31 - 1) + 1`, computed once per fold as an integer vector over the run's
own pulse calendar and read by index. One constant,
`ledgr_pulse_seed_rule_version <- 2L`, names the rule everywhere. Every
seeding call, in the fold envelope and the two simulators, goes through one
helper that sets the seed and pins Mersenne-Twister/Inversion/Rejection.
Workers pin the same kind at start. Every DuckDB append goes through one
helper, `ledgr_store_append()`, which keeps `.Random.seed` (or its absence)
as it was. Under decision (14), ledgr restores the caller's kind and
`.Random.seed` (or their absence) around its own work and around the user
code it evaluates as part of its service. Fifteen exported functions (and
one S3 method, through its generic) are wrapped at their outermost frame by
`ledgr_rng_preserve_caller()`, which restores after all cleanup. The two
callables that `ledgr_indicator_dev()` returns restore on their own calls.
Every other export is RNG-neutral because the store helper covers its only
possible draw. A wrapped export forces its caller-supplied ordinary
arguments before it saves the caller's state, so draws in arguments advance
the caller's stream (decision (15)). Captured service expressions are not
forced early, and user S3 methods dispatched after entry are restored. The
strategy built by `ledgr_signal_strategy()` and the indicator built by
`ledgr_adapter_r()` are ledgr machinery and do not restore (decision (16)).
Section 5.1 states the full boundary. Old or missing
seed-rule markers on candidates, including unseeded walk-forward ones, are
refused before a snapshot hold or run is created.

## 2. (a) Pulse-seed rule v2

### 2.1 Arithmetic

All values are unsigned 32-bit integers held in R doubles.

- `u32(x) = x mod 2^32`. A negative R integer seed maps to its two's
  complement image (`-1 -> 4294967295`).
- `fmix32(h)` is the MurmurHash3 finalizer: `h ^= h >> 16`;
  `h *= 0x85EBCA6B`; `h ^= h >> 13`; `h *= 0xC2B2AE35`; `h ^= h >> 16`.
  Every product is taken mod 2^32.
- `pulse_seed(s, p) = fmix32(fmix32(u32(s)) xor u32(p)) mod 2147483647 + 1`.
  The result lies in `[1, 2147483647]`, so it is always a valid,
  non-missing R integer seed.

This is the probe's measured mixer (`probe.R:112-130`), unchanged. I found
no reason to freeze another rule. It passes every bound in Section 2.4, and
the probe has already shown that the add and stride rules fail.

### 2.2 Implementation form and platform independence

The rule has one owner, `ledgr_pulse_seeds(execution_seed, pulse_idx)` in
`R/rng.R`. It is vectorised over `pulse_idx`, and the scalar `fmix32(u32(s))`
is computed once per call. The fold calls it once per fold:
`ledgr_pulse_seeds(seed, seq_len(length(pulses_posix)))`. A NULL seed returns
NULL. The arithmetic is the probe's 16-bit split:

- `xor32` applies `bitwXor` to the high and low 16-bit halves separately;
- `mul32` splits both operands into 16-bit halves.

The platform-independence argument:

- Every operand is a non-negative integer-valued double below 2^32. The
  largest intermediate is in `mul32`: `al*bl + ((ah*bl + al*bh) mod 2^16) *
  2^16`. It stays below 2^33, far below 2^53, so IEEE-754 double arithmetic
  is exact on every conforming platform.
- `%/%` by 65536 or 8192 and `%%` by 2^16, 2^32 or 2147483647 act on exact
  integers below 2^53, so they are exact.
- `bitwXor` receives `as.integer()` of values below 65536. These are
  non-negative 32-bit ints, so there is no sign bit and no overflow.
- No signed 32-bit arithmetic is used, no step depends on platform word
  size, and the result passes through `as.integer()` only after the final
  reduction, which is already in range.

No step relies on the C compiler, the BLAS or the locale.

`ledgr_derive_pulse_seed` (`R/rng.R:33-57`) and its per-pulse call
(`R/fold-engine.R:766`) are deleted with no alias. No per-pulse
`canonical_json` or SHA-256 remains. `ledgr_derive_seed` (`R/rng.R:21-31`) is
unchanged.

### 2.3 The pulse axis and its origin

The axis is the fold's pulse calendar, `execution$pulses_posix`.

- Index 1 is the first pulse of the run's configured range
  `[backtest$start_ts_utc, backtest$end_ts_utc]`. That start is the clamped
  scoring start for ordinary runs, sweeps and promotion (`R/backtest.R:458-466`)
  and the window's scoring start for windows (`R/backtest.R:465`). This is
  today's axis: `ledgr_fold_stage_decide` receives the calendar position `i`
  of the pulse loop (`R/fold-engine.R:1903`).
- The vector always covers `1..length(pulses_posix)`.
  - **Resume** recomputes the same calendar from the stored configuration
    and reads from `start_idx > 1` (`R/run-resume.R:53`). Indices never
    restart at the resume point.
  - **Scheduled skips** keep their index. Their seed is computed but never
    read.
  - **Windows and walk-forward test windows** have their own calendar.
    Equality is claimed against a straight run with the same execution seed
    on the same calendar, not against a longer run that contains the window.
    Walk-forward windows also derive distinct seeds
    (`R/walk-forward-identity.R:97`).
  - **Sweeps** (one and two workers) and **promotion** use the same calendar
    as `ledgr_run()` on the same experiment.
- An unseeded fold builds no vector, and `ctx$pulse_seed` stays NULL. The
  context reads the vector through one accessor,
  `ledgr_pulse_seed_at(services, pulse_idx)`, which returns NULL when the
  vector is NULL and element `pulse_idx` otherwise. The census observes
  that accessor (Section 8.2).

**What is claimed, and what is not (review reading (i)).** The claim is
equality on the same calendar: a sweep candidate and a committed run or
promotion on the same experiment, execution seed and scoring calendar get
the same pulse seeds, and a run window and the corresponding walk-forward
or sweep window agree when their calendar and execution seed agree. The
same timestamp in a longer calendar need not agree. With execution seed 7,
v2 gives 373418371 at local index 1 and 530954868 at index 3 (today's rule
also differs by index). Promotion of a walk-forward candidate calls ordinary
`ledgr_run()` on the full experiment calendar (`R/sweep.R:849-855`), not the
shorter test window, so it does not promise same-bar equality with that
window. LDG-3159's witnesses must not assert overlapping-bar equality
between calendars of different length.

### 2.4 Frozen acceptance bounds and failing controls

These bounds were written before any v2 value was computed beyond the
probe's recorded seed-7 numbers. LDG-3159 implements them as tests on the
production routine. `S = {7, 2591, -1, 2147483647}`. The edge set is
`E = {-2147483647, -1, 0, 1, 2, 7, 2591, 2147483646, 2147483647}`.

| Bound | Statistic | Limit |
| --- | --- | --- |
| B1 adjacent pulses | lag-1 correlation of the first `runif()` after `set.seed(v, kind)`, pulses 1..5000, each seed in S, kinds MT and L'Ecuyer-CMRG (Inversion, Rejection) | max abs <= 0.045 (about 3.2 SE at n = 5000) |
| B2 seed uniformity | KS D of `(v - 1) / 2147483646` against U(0,1), pulses 1..5000, each seed in S | <= 0.0276 (alpha about 0.001) |
| B3 first-draw uniformity | KS D of the first MT `runif()`, same seeds and pulses | <= 0.0276 |
| B4 cross-seed overlap | seeds 1..20 x pulses 1..500: distinct values; values shared by two or more seeds | >= 9999; <= 1 |
| B5 shifted streams | seed pairs `(s, s+1)` for s = 1..19, shifts k = 1..5, pulses p = 1..(500-k), both directions: count of `V(s+1, p) == V(s, p+k)` plus count of `V(s, p) == V(s+1, p+k)`, summed over s, k and p (p + k never exceeds 500) | <= 1 |
| B6 seed sensitivity | every pair of distinct seeds in E, pulses 1..1000: positions that differ | >= 999 |

Each control must fail at least one bound. Measured on 2026-10-29 with
`Rscript` 4.6.1 (scratch probe, base tree):

| Rule | B1 | B2 | B3 | B4 distinct / shared | B5 | B6 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| v2 | 0.0257 | 0.0174 | 0.0169 | 10000 / 0 | 0 | 1000 | pass |
| add `((s-1+p-1) mod M) + 1` | 0.379 | 1.000 | 0.0141 | 519 / 517 | 9481 | 0 | fails B1, B2, B4, B5, B6 |
| stride `(((s-1)*1000003 + p-1) mod M) + 1` | 0.375 | 0.9995 | 0.0143 | 10000 / 0 | 0 | 0 | fails B1, B2, B6 |
| seed-ignoring (v2 with s fixed at 7) | 0.0186 | 0.0174 | 0.0127 | 500 / 500 | 0 | 0 | fails B4, B6 |

`M = 2147483647`. These bounds are bounded empirical checks. They are not a
claim of independent streams or of collision freedom. Reducing to a positive
31-bit seed permits collisions.

### 2.5 Golden values, derived independently

The golden table comes from exact Python integers with 32-bit masks
(Python 3.13.2, `python -I`). It is written straight from the fmix32
definition, with no 16-bit splitting and no R:

```python
M32 = 0xFFFFFFFF
def fmix32(h):
    h &= M32; h ^= h >> 16; h = (h * 0x85EBCA6B) & M32
    h ^= h >> 13; h = (h * 0xC2B2AE35) & M32; h ^= h >> 16
    return h
def v2(seed, pulse):
    return fmix32(fmix32(seed & M32) ^ (pulse & M32)) % 2147483647 + 1
```

The R double-split routine reproduced all 63 values exactly. It also
reproduced the probe's recorded mixer matrix digest
(`rule_overlap.csv`, `0394b14a...`), so v2 is exactly the probe's mixer.

| execution_seed | p=1 | p=2 | p=3 | p=65535 | p=65536 | p=65537 | p=2147483647 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| -2147483647 | 1329652449 | 296350653 | 1020107659 | 762256976 | 1000840576 | 938002083 | 1830298223 |
| -1 | 1645275634 | 2049858838 | 1841555007 | 231637156 | 1778090837 | 1605668209 | 310231063 |
| 0 | 1364076728 | 821347079 | 99660841 | 574336617 | 245581155 | 1517865794 | 2043416234 |
| 1 | 1032769584 | 779996177 | 822924216 | 32364187 | 1150499547 | 1051651479 | 1987655487 |
| 2 | 924828732 | 1186167475 | 581926497 | 2133241161 | 953032051 | 1497089111 | 838131903 |
| 7 | 373418371 | 879019655 | 530954868 | 1568417501 | 856334211 | 1089673948 | 437387945 |
| 2591 | 1411389157 | 90853150 | 570397166 | 1632251389 | 1199731600 | 1228247822 | 203069199 |
| 2147483646 | 1557236958 | 1248947313 | 581187014 | 1382106984 | 642208404 | 653509169 | 687568460 |
| 2147483647 | 513865860 | 60330939 | 914812600 | 1178777718 | 349344874 | 1254035666 | 1019020745 |

LDG-3159 commits this table as a fixed test fixture. It executes
`ledgr_pulse_seeds()` against the table on Windows and on Linux and records
the platform identities. A skipped platform is missing evidence. Seed
`-2147483648` is `NA_integer_` and is refused by `ledgr_seed_normalize`, as
today. Pulse index 0 is not on the axis.

## 3. (b) Seeding sites and the worker-start pin

There is one seeding helper, `ledgr_rng_seed_pinned(seed)`. It calls
`set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion",
sample.kind = "Rejection")` and nothing else, so the kind is set by the same
call that seeds. There is one state helper pair:

- `ledgr_rng_caller_state()` captures `RNGkind()` and `.Random.seed`, or its
  absence. Querying the kind does not create `.Random.seed`.
- `ledgr_rng_restore(state)` restores it. When the seed was present, it
  assigns `.Random.seed`, whose first element carries the kind. When the
  seed was absent, it calls `suppressWarnings(RNGkind(kind[1], kind[2],
  kind[3]))` and then removes `.Random.seed`. A non-default active kind with
  no seed therefore comes back as it was.

| Site | Today | After |
| --- | --- | --- |
| `R/fold-engine.R:1615-1629` `ledgr_fold_envelope` | local save/restore of `.Random.seed` only; `set.seed(as.integer(seed))` | `state <- ledgr_rng_caller_state()`; `on.exit(ledgr_rng_restore(state))`; `ledgr_rng_seed_pinned(seed)`, whenever seeded. This is the enforcing point. |
| `R/sim-bars.R:33-42` `ledgr_sim_bars` | local save/restore; `set.seed(seed)` | the same three lines |
| `R/sim-pit-inputs.R:401-417` `ledgr_sim_pit_bars` (called by `ledgr_sim_pit_inputs`) | local save/restore; `set.seed(seed)` | the same three lines |
| worker start, `ledgr_parallel_worker_setup` (`R/parallel-workers.R:202`) | daemons run L'Ecuyer-CMRG | after `ledgr_parallel_mirai_start()`, a new owner `ledgr_parallel_worker_rng_pin(workers)` runs `everywhere(RNGkind("Mersenne-Twister", "Inversion", "Rejection"))` on every daemon. This is supplementary; the envelope still enforces the kind for each seeded fold. |

An unseeded fold sets neither seed nor kind (decision (1)). A strategy that
pins its own kind inside `withr::with_seed(..., .rng_kind = )` keeps that
choice. Agreement then needs the same override on every worker.

## 4. (c) RNG-consuming store writes

DuckDB 2.0.0's `dbAppendTable` names a temporary view with
`sample(letters, 10, replace = TRUE)` when the frame is nonempty. The
re-review confirmed 27 operational sites and no `dbWriteTable`. Every site
is routed through one helper:

```r
ledgr_store_append <- function(con, name, value) {
  had <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit(if (had) assign(".Random.seed", old, envir = .GlobalEnv)
          else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
            rm(".Random.seed", envir = .GlobalEnv), add = TRUE)
  DBI::dbAppendTable(con, name, value)
}
```

The helper keeps the value or absence of `.Random.seed` on normal and error
exits. It need not restore the kind, because an append never changes it.
The fold, the strategy and other store work are not wrapped (decision (3)).

| File (function) | Lines | Tables |
| --- | --- | --- |
| `R/availability-persistence.R` (`ledgr_snapshot_write_availability`, `ledgr_snapshot_write_fact_family`) | 20, 36, 60, 74, 95, 104, 113, 121, 134, 141 | fact families, quarantine, membership sets and rows, trading status, lifetime, corporate actions, sessions |
| `R/backtest-fills.R` (`ledgr_extract_fills_impl`) | 160 | the fill reader's temporary table |
| `R/backtest-runner.R` (`ledgr_write_opening_position_events`) | 289 | `ledger_events` |
| `R/derived-state.R` (`ledgr_rebuild_derived_state`) | 215, 219 | `equity_curve` |
| `R/output-handler.R` (`ledgr_output_sink_duckdb`) | 63, 70, 74, 152 | `run_completion`, `run_diagnostics`, `ledger_events` (the checkpoint and end-of-fold flushes at `R/fold-engine.R:1558, 2034`), `strategy_state` |
| `R/run-finalize.R` (`ledgr_run_equity_prefix_commit`, `ledgr_run_finalize`) | 413, 563 | `equity_curve` |
| `R/sweep-persistence.R` (`ledgr_sweep_save`) | 63, 64, 66, 69 | `sweeps`, `sweep_candidates`, `sweep_returns`, `sweep_trades` |
| `R/walk-forward.R` (`ledgr_walk_forward_write_session`) | 1097, 1099, 1102 | walk-forward sessions, folds, scores |

The local guard in `ledgr_extract_fills_impl` (`R/backtest-fills.R:64-76`)
is deleted, because the helper now owns it. The roxygen examples in
`R/snapshots-seal.R:45, 55` are documentation, not sites. The following
draw nothing from R's RNG and are not sites:

- `duckdb::duckdb_register` (`R/snapshot_adapters.R:309`), which takes its
  name from `tempfile()`;
- `dbExecute` writes;
- `ledgr_generate_sweep_id` (`R/sweep.R:1238`), which hashes the pid, a
  counter and the time.

**Source inventory (LDG-3158 test).** The test parses every file in `R/`
(parsed expressions, so roxygen is ignored) and fails if it finds:

1. a call to `dbAppendTable`, `DBI::dbAppendTable` or `dbWriteTable` outside
   `ledgr_store_append`;
2. a call to `set.seed` outside `ledgr_rng_seed_pinned`;
3. an `RNGkind` call that breaks the two `RNGkind` rules (review F4):
   - **Query:** a zero-argument `RNGkind()` is allowed only inside
     `ledgr_rng_caller_state`.
   - **Mutation:** an argument-bearing `RNGkind(...)` is allowed only inside
     `ledgr_rng_restore` and `ledgr_parallel_worker_rng_pin`, including the
     quoted expression it sends to the workers.
   Any other `RNGkind` call, query or mutation, is a finding.
4. a call to mirai `daemons()` outside `ledgr_parallel_mirai_start` and
   `ledgr_parallel_mirai_stop`.

The inventory is a function over parsed source. Its tests feed it:

- the unmodified package source, which must pass, including the zero-argument
  query in `ledgr_rng_caller_state`;
- an injected `DBI::dbAppendTable(con, "x", df)`, which must be reported;
- an injected `RNGkind("L'Ecuyer-CMRG")` inside `ledgr_rng_caller_state`,
  which must be reported;
- an injected zero-argument `RNGkind()` in another function, which must be
  reported as an unowned query;
- an injected argument-bearing `RNGkind(...)` in another function, which must
  be reported as an unowned mutation.

Separately, the helper is tested directly: present state, absent state, and
an error raised by the append.

## 5. (d) Caller restore at exported entry points

`ledgr_rng_preserve_caller(expr)` captures `ledgr_rng_caller_state()`,
registers `on.exit(ledgr_rng_restore(state))` and then forces `expr`.

- Each wrapped export's body has two steps. First it calls
  `ledgr_rng_force_args()` (Section 5.4, decision (15)). Then it calls
  `ledgr_rng_preserve_caller(<existing implementation call>)`. Every inner
  `on.exit` therefore finishes before the restore: worker stop
  (`R/sweep.R:225`), store closing and snapshot release. The restore runs
  last on success, error and interrupt, for every seed value.
- The seeded-only restores at `R/backtest-runner.R:386-399`,
  `R/sweep.R:157-174` and `R/walk-forward.R:99-114` are deleted, because the
  wrapper owns them.
- Nested wrappers are harmless: `ledgr_promote` calls `ledgr_run`, and
  `ledgr_backtest` reaches the run path.

### 5.1 The boundary (maintainer decision (14), 2026-10-29)

ledgr restores the caller's RNG kind and state around two things.

- **Its own work:** store writes (Section 4), seeding (Section 3), and
  worker start and stop.
- **User code it evaluates as part of its service:**
  - strategies;
  - indicator and feature callbacks;
  - ranking or selection expressions such as `ledgr_sweep_review()`'s
    `rank_by` (captured unevaluated and run by ledgr);
  - helpers ledgr builds for the user to call later, which restore on their
    own calls. Under decision (16), these are only `ledgr_indicator_dev()`'s
    `test` and `test_dates`. The constructor's wrapper is never claimed to
    protect later calls.

Outside the promise, as the caller's own code whose draws advance the
caller's stream as if run directly:

- **Ordinary arguments.** Under decision (15), a wrapped export forces its
  caller-supplied ordinary arguments as its first step, before saving the
  caller's state (Section 5.4). So
  `ledgr_run(exp, seed = sample.int(1e6, 1))` called twice gets two
  different seeds. An unwrapped export forces its arguments whenever R
  needs them, also outside any restore (for example
  `ledgr_utc({ sample.int(100, 1); "2020-01-01T00:00:00Z" })`, or `bt` in
  `ledgr_backtest_bench`).
- **User S3 methods reached from an unwrapped export.** For example, a
  user's `ledgr_metric_context.myclass` called through the N export
  `ledgr_metric_context()`.
- **Callables ledgr builds and itself runs (decision (16)).** These are the
  strategy returned by `ledgr_signal_strategy()` and the indicator function
  built by `ledgr_adapter_r()`. They are parts of ledgr's machinery and do
  not restore. Inside a run they draw from the fold's stream like any
  strategy or indicator code. Called directly, they are the caller's code.

Inside the restore, by contrast:

- user S3 methods that a wrapped export dispatches to after entry (decision
  (15)), for example an `as_tibble()` method on a user subclass of a sweep
  result passed to `ledgr_sweep_review()`;
- captured service expressions (`rank_by`, `.filter`), which are not forced
  early.

These rules are a documented boundary, not a claim of RNG neutrality for
caller code. The Box-Muller limitation of decisions (5) and (12) is
unchanged.

LDG-3160 puts this text, or a closer one, in the contract and the owning
article:

> ledgr restores your RNG kind and `.Random.seed` (or their absence) around
> its own work (store writes, seeding, worker start and stop) and around
> the user code it runs for you: strategies, indicator and feature
> callbacks, ranking and selection expressions such as `rank_by`, and the
> `test` and `test_dates` helpers of `ledgr_indicator_dev()`, which restore
> on each call. The arguments you pass are evaluated first, before ledgr
> saves your random state, so random draws in them advance your stream as
> if you had made them yourself: two calls of
> `ledgr_run(exp, seed = sample.int(1e6, 1))` get different seeds.
> Expressions that ledgr captures and runs later, such as `rank_by` and
> `.filter`, are restored. An S3 method you define is restored when a
> restoring ledgr function calls it after entry, and is your own code when
> another ledgr function calls it. The strategy from
> `ledgr_signal_strategy()` and the indicator function from
> `ledgr_adapter_r()` do not restore: inside a run they draw like any
> strategy or indicator, and when you call them yourself they are your own
> code. A pending Box-Muller normal variate is not preserved.

### 5.2 Disposition rule

Every export and every callable ledgr returns gets exactly one class. Classes
are assigned in priority order: W, then R, then H, then N.

- **W, own work (wrapped at the outermost frame).** The export's static reach
  includes `ledgr_fold_envelope`, a seeding site, or worker start or stop.
  Static reach is computed on a call graph over the ledgr namespace: symbol
  references, plus edges from every called S3 generic to all registered ledgr
  methods of that generic.
- **W, service-level user code (wrapped at the outermost frame).** The
  export either reaches the feature-callback invokers statically
  (`ledgr_call_feature_fn`, `ledgr_call_feature_series_fn`), or it is one of
  the explicit evaluators found by the source search in Section 5.3.
- **R, returned helper (restores on its own calls).** A helper ledgr builds
  for the user to call later that evaluates user code when called. Under
  decision (16), only `ledgr_indicator_dev()`'s `test` and `test_dates`. The
  callables ledgr builds and itself runs (`ledgr_signal_strategy()`'s
  strategy, `ledgr_adapter_r()`'s indicator function) are machinery, not R.
  They do not restore.
- **H, not wrapped.** The only possible ledgr-owned RNG consumption is a
  nonempty append, which the store helper neutralises. H means the static
  reach includes an append site; H exports get caller-state witnesses.
- **N, not wrapped.** Everything else.

For every class, Section 5.1 governs arguments and S3 methods. Section 5.4
specifies the entry step of decision (15), and records decision (16).

**W (15 exports).**

- Own work: `ledgr_backtest`, `ledgr_promote`, `ledgr_pulse_snapshot`
  (an unseeded memory fold with an internal capture callback,
  `R/pulse-snapshot.R:483-518`), `ledgr_run`, `ledgr_sim_bars`,
  `ledgr_sim_pit_inputs`, `ledgr_sweep`, `ledgr_walk_forward`.
- Service-level user code, by static callback reach:
  `ledgr_precompute_features`, `ledgr_candidate` (and the method
  `ledgr_candidate.ledgr_walk_forward_results` through it), and
  `ledgr_candidate_reproduction_key`. The last two are wrapped
  conservatively: a static edge cannot be ruled out.
- Service-level user code, explicit evaluators: `ledgr_sweep_review`
  (`rank_by`), `ledgr_pbo` (`metric` function), and `ledgr_feature_grid` and
  `ledgr_strategy_grid` (`.filter`).

The private windows `ledgr_run_window` and the sweep window run inside
`ledgr_walk_forward`'s wrapper.

**R (2 returned callables).** `ledgr_indicator_dev()` returns `e$test` and
`e$test_dates` (`R/indicator-dev.R:83-121`). Each body becomes
`ledgr_rng_preserve_caller(...)`, so each call restores after its own
snapshot release. The constructor evaluates no user code. It is H through
static append reach, and it is never claimed to protect later calls. `e$plot`
evaluates no user code.

### 5.3 Source search for service-level evaluators

I searched `R/` for `eval`, `evalq`, `eval_tidy`, `eval_bare`, `exec`,
`do.call`, `match.fun`, `substitute`/`enquo`-style capture, user-function
parameters (`is.function()` checks) and returned closures. Each operational
hit has one disposition:

| Site | What it evaluates | Disposition |
| --- | --- | --- |
| `R/sweep-review.R:51,111` | `rank_by`, captured and evaluated with the caller frame as parent | W, `ledgr_sweep_review` (review F1) |
| `R/validation-pbo.R:44,215-232` | user `metric` function over returns | W, `ledgr_pbo` (new) |
| `R/param-grid.R:32,45,182` | `.filter` expression over the expanded grid | W, `ledgr_feature_grid`, `ledgr_strategy_grid` (new). The allowlist at `:202-215` admits no RNG function and grid values must be atomic (`:165`), so the filter cannot draw today. It is wrapped anyway because decision (14) names selection expressions. |
| `R/indicator-dev.R:87,118` | `fn` passed to the returned `test` and `test_dates` | R (review F1) |
| `R/experiment.R:542` | feature factory `features(params)` | inside W only: reached from `ledgr_run`/`ledgr_backtest` (`R/backtest.R:452`), `ledgr_precompute_features` (`R/precompute-features.R:646`), `ledgr_pulse_snapshot` (`R/pulse-snapshot.R:432`) and the sweep path. `ledgr_experiment()` checks only the signature (`:495`). |
| `R/features-engine.R:336,340`, `R/history-features.R:309,318,721` | indicator `fn`/`series_fn` | inside W only, through the callback invokers |
| `R/indicator-adapters.R:67`, `R/indicator-ttr.R:609,859,861` | closures that ledgr builds around a package function (`ledgr_adapter_r`) or TTR (`ledgr_ind_ttr`) | ledgr machinery with no own restore. `ledgr_adapter_r` is named by decision (16); the TTR wrappers run no user code. They run inside W when ledgr evaluates them; a direct call is the caller's own code. |
| `R/signal-strategy.R:61` | strategy closure returned by `ledgr_signal_strategy` that calls the user's signal `fn` | ledgr machinery (decision (16)): no own restore; inside W when the fold evaluates it; a direct call is the caller's own code |
| `R/strategy-schedule.R:44-55` | none: returns the user's own strategy function with an attribute | caller's own code when called directly |
| `R/indicator.R:86-111` | none: stores the user's `fn` unchanged | caller's own code when called directly |
| `R/strategy-extract.R:272` | evaluates the stored strategy source of a function literal in a `baseenv()` child, which creates a closure and runs no body; reached by `ledgr_run_strategy` | H (no user code runs); the returned reconstruction is the user's own strategy |
| `R/business-objective.R:353,818` | criterion `evaluate` functions | not user code: only ledgr objective constructors make criteria, validated by id and hash (`:346-360`) |
| `R/parallel-workers.R:322,344`, `R/collapse-determinism.R:19` | internal expressions | not user code |
| other `do.call`/`Map`/`Reduce`/`Filter` hits | ledgr constructors (`cost-model.R:347`, `risk-model.R:515`, `feature-map.R:218`, `feature-parameters.R:244,277`, `business-objective.R:438`), `duckdb::duckdb` (`public-api.R:7`), print and data reshaping | not user code |

The LDG-3158 tracer extends the static rule at run time. During the targeted
tests it traces the following, and fails if the outermost ledgr frame on the
stack is neither a W export nor an R callable:

- `ledgr_fold_envelope`, `ledgr_rng_seed_pinned` and
  `ledgr_parallel_mirai_start`;
- `ledgr_call_feature_fn` and `ledgr_call_feature_series_fn`;
- `ledgr_sweep_review_rank`, `ledgr_pbo_metric`'s evaluation site and
  `ledgr_eval_grid_filter`.

### 5.4 Argument evaluation and built callables (decisions (15) and (16))

The two cases the first revision left open are ruled. Decision (15) settles
case A-1, option b; decision (16) settles case A-2, option 1.

**Entry step of a wrapped export (decision (15)).** A wrapped export's body
has a thin prologue, then the wrapper, then a separate implementation
function:

```r
ledgr_run <- function(exp, params = list(), ..., seed = NULL) {
  ledgr_rng_force_args()                      # step 1, before the save
  ledgr_rng_preserve_caller(                  # step 2, save and restore
    ledgr_run_impl(exp = exp, params = params, ..., seed = seed)
  )
}
```

`ledgr_rng_force_args(lazy = character(), env = parent.frame())` does the
following, in the formals order of the calling export:

- **Supplied ordinary arguments are forced.** For each formal not named in
  `lazy` and not `...`, it evaluates `missing(<name>)` in `env`. If the
  caller supplied the argument, it forces the promise (`get(<name>, envir =
  env)`), so the caller's expression runs in the caller's frame, before
  `ledgr_rng_caller_state()`.
- **Missing arguments are not forced.** Their defaults are ledgr code and
  evaluate lazily inside the restore when the implementation first uses
  them. A default may therefore reference other arguments, which are already
  forced or are themselves defaults. Defaults cannot draw: the Section 4
  source guard forbids every RNG call in `R/` outside its owners.
- **Dots are forced** with `eval(quote(list(...)), env)` when `...` is a
  formal and is non-empty.
- **Captured service expressions are never forced.** Every formal that the
  export captures unevaluated and later runs as service code must be named
  in `lazy`. The `lazy` set is exactly:
  - `rank_by` for `ledgr_sweep_review`;
  - `.filter` for `ledgr_feature_grid` and `ledgr_strategy_grid`;
  - nothing for every other wrapped export.
- **A formal captured only as a label is forced.** `ledgr_pbo`'s
  `substitute(metric)` (`R/validation-pbo.R:44`) only names the metric.
  `substitute()` still returns the original expression after the promise is
  forced, so `metric` is forced.
- **An error while forcing** surfaces before any state is saved or any
  ledgr work starts, so there is nothing to restore. This moves argument
  errors to entry; no ledgr behaviour depends on later forcing.

**What stays in the prologue.** Uses of `missing()` must stay in the
export's own frame, because the implementation receives explicit arguments.
That covers `ledgr_backtest`'s `missing(cost_model)` (`R/backtest.R:203`)
and `ledgr_pulse_snapshot`'s supplied-argument flags
(`R/pulse-snapshot.R:80-84`). So does `match.arg()` normalisation (for
example `ledgr_walk_forward`'s `no_selection`). The prologue computes these
before step 2 and passes the results to the implementation. They are ledgr
code and draw nothing.

**Why a separate implementation function.** Every `on.exit` cleanup
(worker stop, store close, snapshot release) must live in the implementation
function. An `on.exit` written in the export's own frame would run after the
wrapper's restore, which would break "restoration outside all cleanup".

**S3 generics in W.** `ledgr_candidate` dispatches with `UseMethod()`,
which must run in the generic's own frame. So the two steps sit in each
registered method that can run user or store code
(`ledgr_candidate.default`, `ledgr_candidate.ledgr_walk_forward_results`).
Dispatch has already forced `results`.

**User S3 methods after entry.** A user method that a wrapped export
dispatches to after step 1 runs inside the restore. One example is an
`as_tibble()` method on a user subclass of the sweep passed to
`ledgr_sweep_review` (`R/sweep-review.R:41`, `tibble::as_tibble(sweep)`).

**Source check (LDG-3158).** The test fails if any of these does not hold:

- every W export body, and every W method body for the generic, begins with
  `ledgr_rng_force_args()` followed by a single
  `ledgr_rng_preserve_caller()` call;
- the `lazy` argument matches the frozen set above;
- no `on.exit()` appears in a W export's own body.

**Built callables (decision (16)).** The strategy closure returned by
`ledgr_signal_strategy()` (`R/signal-strategy.R:61`) and the indicator `fn`
built by `ledgr_adapter_r()` (`R/indicator-adapters.R:64-68`) are ledgr
machinery. They get no wrapper and no restore. Inside a fold or a feature
pass they draw from the fold's stream or the caller's stream exactly like a
hand-written strategy or indicator, and the enclosing W export restores the
caller. Called directly by the user, they are the caller's own code.
Decision (14)'s returned callables are only the helpers built for the user to
call: `ledgr_indicator_dev()`'s `test` and `test_dates` (class R).

**Open point B-1 (listed, not decided).** Decision (15) names "a wrapped
export". It does not say whether the two R helpers also force their
ordinary arguments before saving: `fn` and `dates` for `test_dates`, `fn`
for `test`.
- Without forcing, a draw inside an argument expression (for example
  `dates = sample(x, 3)`) is undone by the helper's restore.
- With forcing, it advances the caller's stream, as in a wrapped export.

`fn` is normally a function value, which draws nothing when forced. The
consistent choice would apply the same entry step. LDG-3158 needs a ruling
before it implements these two helpers; the rest of the design does not
depend on it.

### 5.5 Witnesses (LDG-3158)

**Caller-state witness.** After the call, the caller's next `runif(1)` and
next `sample(10)` must equal those of an untouched session, and the kind must
be unchanged.

It runs for every W export, both R callables, and the H representatives that
append nonempty frames:

- `ledgr_snapshot_from_df`, `ledgr_results(bt, "fills")`, `print(bt)`;
- `ledgr_sweep_save`, `ledgr_state_reconstruct`,
  `ledgr_snapshot_quarantine`;
- the `ledgr_indicator_dev` constructor.

Caller states:

- MT/Inversion/Rejection;
- L'Ecuyer-CMRG;
- a non-default sample kind (Rounding);
- an absent `.Random.seed` under a non-default active kind. For this one the
  test asserts that the seed is still absent and that the kind is unchanged.

Exits:

- success;
- a setup failure after RNG state was touched;
- an interrupt from a strategy that calls `rlang::interrupt()`, caught with
  `tryCatch(interrupt = )`;
- a two-worker sweep, whose daemon start and stop consume caller RNG.

**Dynamic routes (review F1).** Each case must leave the caller state
unchanged.

- `ledgr_sweep_review(sw, rank_by = desc(sharpe_ratio) + 0 *
  runif(length(sharpe_ratio)))`, a `rank_by` that actually draws.
- `rank_by = { runif(1); stop("boom") }`: error after a draw. Class
  `ledgr_invalid_sweep_review_rank`.
- `rank_by = { runif(1); rlang::interrupt() }`: interrupt after a draw,
  caught by the test.
- A `rank_by` that calls a user helper. The helper draws, runs
  `ledgr_sweep(..., workers = 2L)` on a small fixture and
  `ledgr_sweep_save()` into a temporary store (a real worker operation and a
  real store write), then draws again.
- `dev$test(function(w) sample.int(100, 1))` and
  `dev$test_dates(function(w) sample.int(100, 1), dates)`, each checked
  after its own call. Then each again with an `fn` that draws and then errors,
  and one that draws and then interrupts.
- `ledgr_pbo(x, metric = function(m) colMeans(m) + 0 * runif(ncol(m)))`.
- `ledgr_strategy_grid(qty = 1:3, .filter = qty > 1)` leaves the state
  unchanged. `.filter = runif(1) > 0` is refused with
  `ledgr_grid_filter_invalid`.
- **Optional R3 witness.** An unseeded `ledgr_run(seed = NULL)` whose strategy
  draws with `runif()` must leave the caller state unchanged. The strategy
  draws from the caller's stream, so only the outer wrapper restores it;
  storage neutrality alone does not.

**Boundary witnesses.** These pin the documented behaviour of Section 5.1;
they do not claim neutrality.

- `ledgr_utc({ invisible(sample.int(100, 1)); "2020-01-01T00:00:00Z" })`
  leaves the caller's next draw equal to that of a session that ran
  `sample.int(100, 1)` itself.
- A user-defined `ledgr_metric_context.review_rng` that draws and returns
  `ledgr_metric_us_equity()` advances the stream the same way.

**Decision (15) witnesses (argument evaluation).**

- **Two-call seed.** From `set.seed(1)`, call
  `ledgr_run(exp, run_id = "a", seed = sample.int(1e6, 1))` and then the
  same with `run_id = "b"`. The two runs' `config$engine$seed` values
  differ and equal the first and second values of `sample.int(1e6, 1)` drawn
  in an untouched session from `set.seed(1)`. Afterwards the caller's next
  `runif(1)` equals that session's next draw after the two `sample.int`
  draws.
- **A draw in an ordinary argument.** `ledgr_sweep(exp, grid, seed = 7L,
  retain = { runif(1); ledgr_sweep_retention() })` leaves the caller's next
  draw equal to that of a session that ran `runif(1)` once. This shows the
  draw advanced the stream and was not undone.
- **A user S3 method after entry is restored.** Define
  `as_tibble.review_rng <- function(x, ...) { runif(1); NextMethod() }`,
  then pass `structure(sw, class = c("review_rng", class(sw)))` to
  `ledgr_sweep_review(..., rank_by = desc(sharpe_ratio))`. The caller state
  is unchanged.
- **Captured expressions are not forced early.** A `rank_by` that draws is
  restored, as in the dynamic routes above.
- **Missing arguments and defaults.** `ledgr_run(exp)` with every optional
  argument missing behaves as today. An argument whose evaluation errors
  raises its error before any run row exists.
- Removing step 1 (`ledgr_rng_force_args()`) must make the two-call seed
  witness give identical seeds and the ordinary-argument witness fail.

**Decision (16) witnesses (built callables).**

- `strat <- ledgr_signal_strategy(function(ctx) { if (runif(1) > 0.5)
  c(AAA = "LONG") else c(AAA = "FLAT") })`, run with `ledgr_run(..., seed =
  7L)` on a one-instrument 30-pulse fixture. The signal sequence (read from
  fills or positions) is not constant across pulses: the strategy draws a
  different value on different pulses inside the run, so it has no
  per-call restore. A second run with the same seed gives identical fills,
  and the caller state is unchanged by the run.
- Called directly, `set.seed(1); strat(list(universe = "AAA"), list())`
  leaves the caller's next `runif(1)` equal to the second draw of an
  untouched session from `set.seed(1)`.
- An indicator from `ledgr_adapter_r()` whose package function draws,
  called directly through `$fn(window)`, likewise advances the caller's
  stream.

`ledgr_backtest_bench` reads telemetry only (`R/backtest-results.R:322`) and
is N. Its `bt` argument is evaluated outside any restore, as caller code
(Section 5.1).

**Box-Muller limitation (decisions (5) and (12)).** The restored state is
the kind plus `.Random.seed`, or its absence. A pending Box-Muller normal is
not in that state and is lost when the fold pins Inversion. The same holds
for state that a user-supplied generator keeps outside `.Random.seed`. One
test primes a Box-Muller caller (seed 123, one `rnorm`). It asserts that the
kind and `.Random.seed` are identical after the call and that the next
normal differs from the untouched session. That is documented behaviour,
not a failure.

## 6. (e) The seed-rule constant, its records and validation

`ledgr_pulse_seed_rule_version <- 2L` is defined in `R/rng.R`. It matches
`^ledgr_[a-z_]+_(schema|rule)_version$`, so it enters
`ledgr_store_format_bindings()` (`R/store-gate.R:3-12`) automatically. The
string marker is derived from it and has no separate literal:
`ledgr_seed_contract_current()` returns
`paste0("ledgr_seed_v", ledgr_pulse_seed_rule_version)`, which is
`"ledgr_seed_v2"`.

| Record | Site | Value |
| --- | --- | --- |
| sweep attribute `seed_contract` | `R/sweep.R:469` | `ledgr_seed_contract_current()` |
| sweep candidate provenance `seed_contract` | `R/sweep.R:2179` | the same |
| copies | `R/sweep-persistence.R:584`, `R/promotion-context.R:133`, `R/sweep.R:736` (reproduction key) | copied, as today |
| committed configuration | `R/backtest-config.R:186-192` | `engine$pulse_seed_rule <- ledgr_pulse_seed_rule_version`, **only when `seed` is non-NULL** (unseeded config and hash unchanged) |
| configuration validation | `R/config-validate.R:70-77` | a seeded config whose `engine$pulse_seed_rule` is not the current integer aborts with `ledgr_seed_rule_mismatch` |
| walk-forward results object | `R/walk-forward.R:290` (`ledgr_walk_forward()`) and `R/walk-forward-inspection.R:76` (`ledgr_walk_forward_open()`) | attribute `pulse_seed_contract <- ledgr_seed_contract_current()`, stamped when the results are produced or opened. Opening passes the store gate, so the store was written under the current constant. This is set for every session, seeded or not, and is independent of `engine$pulse_seed_rule`. |
| walk-forward candidate provenance and attribute | `R/walk-forward-inspection.R:217, 271` | `seed_contract` stays `"ledgr_walk_forward_seed_v1"` (derivation, unchanged). New field `pulse_seed_contract` is **copied from the results object's attribute**, not re-derived from the constant at candidate time, so a results object or candidate made before the change carries no current marker. Present for every candidate, seeded or not. |
| reproduction key (`R/sweep.R:733-737`, seed section) | | gains `pulse_seed_contract = provenance$pulse_seed_contract %||% NULL`. Walk-forward keys show both markers; sweep keys show `seed_contract = "ledgr_seed_v2"` only (the field is NULL and dropped). |
| promotion source metadata (`R/promotion-context.R:132-133`) | | gains `pulse_seed_contract = meta$pulse_seed_contract %||% candidate$provenance$pulse_seed_contract` beside `seed_contract`; the full provenance also travels in `provenance_json`, as today |

**Candidate validation.** `ledgr_candidate_validate_seed_rule(candidate)`
runs in `ledgr_promote` right after the argument class checks, before
`ledgr_snapshot_hold()` (`R/sweep.R:819`) and before `ledgr_run`. Both failure
cases abort with class `c("ledgr_seed_rule_mismatch", "ledgr_invalid_args")`:

- **Sweep candidate.** `provenance$seed_contract` must be
  `ledgr_seed_contract_current()`, seeded or not. Sweeps always carry it. A
  missing marker or `"ledgr_seed_v1"` is refused.
- **Walk-forward candidate** (`provenance$evaluation_scope ==
  "walk_forward"`), seeded or unseeded. `seed_contract` must be
  `"ledgr_walk_forward_seed_v1"`, and `pulse_seed_contract` must be
  `ledgr_seed_contract_current()`. A missing pulse marker or one naming
  another rule is refused, including on an unseeded candidate (review F2).

LDG-3159 tests these cases, each before any snapshot hold or run row:

| Candidate | Current marker | Old marker (`ledgr_seed_v1`) | Missing marker |
| --- | --- | --- | --- |
| sweep, seeded | promotes | refused | refused |
| sweep, unseeded | promotes | refused | refused |
| walk-forward, seeded | promotes | refused | refused |
| walk-forward, unseeded | promotes | refused | refused |

A refused case leaves no run row and no snapshot hold. In addition, a
walk-forward candidate whose derivation marker is changed is refused.

No path other than promotion executes a stored or in-memory candidate.
`ledgr_walk_forward` runs only the candidates it creates. A store written
under v1 is refused when opened, with the existing
`ledgr_store_rebuild_required` (`R/store-gate.R:77`), because its recorded
bindings lack the new constant. There is no compatibility path.

## 7. (f) Identity declarations

| Axis | Change | Evidence LDG-3159 shows |
| --- | --- | --- |
| Snapshot content identity | none: hash rule and canonical input unchanged; simulators produce identical output under the default kind | identical snapshot hash for identical canonical input; `ledgr_snapshot_content_hash_rule_version` unchanged |
| Run configuration identity | seeded runs: `config_json` gains `engine.pulse_seed_rule = 2`, so `config_hash` changes; unseeded runs unchanged; `ledgr_identity_rule_version` stays 4 | config hash of one seeded run before and after; unseeded hash unchanged |
| Generated run ids | seeded runs with `run_id = NULL` change, because `R/run-registration.R:20` hashes `config_hash`; walk-forward test run ids (`R/walk-forward.R:1108`) and sweep ids unchanged | before/after id for one seeded default-id run |
| Store format fingerprint | `ledgr_store_format_bindings()` gains exactly `ledgr_pulse_seed_rule_version = 2L` | binding diff against `aa2931e9` lists only that name |
| Candidate and walk-forward seeds | none: `ledgr_derive_seed` and `ledgr_walk_forward_execution_seed` unchanged; walk-forward session id payload unchanged | candidate `execution_seed` columns identical in both successors |
| Executable candidate markers | sweep `seed_contract` v1 to v2; every walk-forward candidate (seeded or not) gains `pulse_seed_contract = "ledgr_seed_v2"` from its results object; the reproduction key and promotion source metadata expose it | successor A0 `sweep_attrs` and `sweep.csv`; the Section 6 candidate table |
| Simulated inputs | changed only for callers whose session kind is not the default | a witness under L'Ecuyer-CMRG equals the default-kind output |

## 8. (g) Successor records

The original A0 records (`dev/bench/v0_2_3_output_freeze/records/`) and the
RNG baseline (`dev/bench/v0_2_3_rng_baseline/records/`) stay unchanged as
history, along with their checkers, guts and `gut_results.csv`. Successors
are recorded on the candidate under `dev/bench/v0_2_3_cut3_successors/a0/`
and `.../rng/`. A comparator there reads original and successor field by
field. Every field not named below must be identical. Each named change must
satisfy its predicate. Any other difference fails.

The probes may change their observation in exactly these ways and no
others; fixture semantics stay unchanged:

- the census's pulse-seed observer moves from the deleted scalar helper to
  the accessor `ledgr_pulse_seed_at`, and the `pulse_seeds`/`rule_overlap`
  "current" rule reads `ledgr_pulse_seeds`;
- the census's `RNGkind` trace splits queries from mutations and records
  their callers;
- the census adds the new observer columns of Section 8.2.1.

**Pulse-rule model.** A predicate that says "equals the pulse-rule model"
means the output of the base tree `aa2931e9` run sequentially with
`ledgr_derive_pulse_seed` replaced in memory by the independent v2
reference function. No other change is made. **Storage model** means the
base tree with every `DBI::dbAppendTable` call traced to keep
`.Random.seed`. Both are oracles for causal attribution. Neither is a gut.
The models cannot patch mirai workers. Two-worker rows are therefore checked
by equality with the sequential successor rows.

### 8.1 A0 successor

LDG-3158 changes no A0 field. A0 strategies draw nothing, so neither kind
pinning nor RNG-neutral storage can move them. After LDG-3158, the original
A0 `check.R` must pass unchanged.

| Id | Field | Predicate | Cause (ticket) |
| --- | --- | --- | --- |
| A1 | `sweep_attrs.csv`, row `seed_contract`, all 14 sweep record dirs | `ledgr_seed_v1` becomes `ledgr_seed_v2`; every other row identical | seed-rule version (LDG-3159) |
| A2 | `sweep.csv`, column `provenance`, all 14 sweep dirs | only the `seed_contract` element changes, v1 to v2 | seed-rule version (LDG-3159) |
| A3 | `runs.csv`, `config_json` and `config_hash`, the 11 seeded run dirs (all `run/`, `run_interrupted/`, `run_resumed/`, `walk_forward/walk_forward/`) | `engine` gains exactly `"pulse_seed_rule":2`; `config_hash` equals `config_hash()` of the new JSON; `dense_cost/run_db_live` and `failures/run_abort` (unseeded) identical | seed-rule version (LDG-3159) |
| A4 | `dense_risk_features` economic rows in `run/` and `sweep_w1/` | equal the pulse-rule model. Measured on the model: only candidate `tight` changes, from 2020-01-03 on: `ledger_events` 5 rows, `fills` 5, `equity_curve` 6, `trades` 2, `metrics` 7 values, `memory_events` 6, `memory_fills` 5, `memory_equity` 6, `sweep` 1 row, `sweep_returns` 6, `sweep_trades` 2. `loose` stays identical (its `qty_b = -5` is clamped by long-only). | v2 pulse rule via `ctx$pulse_seed %% 2L` (`fixtures.R:64`) (LDG-3159) |
| A5 | `dense_risk_features/sweep_w2` economic rows | equal the A4 `sweep_w1` successor rows | v2 pulse rule, worker agreement (LDG-3159) |

The A0 manifest changes only in the bytes and SHA-256 of files touched by
A1 to A5.

### 8.2 RNG baseline successor

| Table | Predicate | Cause (ticket) |
| --- | --- | --- |
| `pulse_seeds` | `execution_seed`, `pulse_idx` identical; `pulse_seed` equals the Section 2.5 reference for every row | v2 rule (LDG-3159) |
| `rule_overlap` | rows for `add`, `stride`, `mixer` identical; every `current` row equals the original `mixer` row of the same metric | v2 rule (LDG-3159) |
| `census` | the exact field-level predicates and expected-call ledger of Section 8.2.1; no wholesale exemption | kind pin, walk-forward fix, caller restore, v2 rule |
| `worker_agreement` | `candidate_id`, `pin`, `execution_seed`, `daemon_rng_kind` (the probe starts its own daemon) identical; statuses `DONE`; all four agreement booleans TRUE (LDG-3158); `n_trades_run == n_trades_w1 == n_trades_w2 >= 10`; final equities equal across paths and equal to the pulse-rule model (LDG-3159). After LDG-3158 alone: only the `none` row's `*_w2` fields change, to its `*_w1` values | kind pin; v2 rule |
| `stochastic_fills`, `stochastic_trades` | `run` and `sweep_w1` rows equal the pulse-rule model (LDG-3159); `sweep_w2` rows equal `sweep_w1` rows for every candidate (LDG-3158); each candidate trades at least two distinct instruments. After LDG-3158 alone: only `sweep_w2`/`none` trades change, to the original `sweep_w1`/`none` rows | kind pin; v2 rule |
| `caller_rng` | every row `caller_rng_unchanged` TRUE and `after_kind == before_kind`; `after_sha256 == before_sha256` where the state was set; rows 01, 05, 09, 13, 15 change only in those fields; all other rows identical. Rows 01, 05 and 09 (unseeded `ledgr_run`, flat fixture) are already preserved by RNG-neutral storage; rows 13 and 15 (two-worker sweeps) need the outer wrapper around daemon start and stop | RNG-neutral storage (rows 01, 05, 09) and caller restore (rows 13, 15) (LDG-3158) |
| `store_rng` | `equity_identical` TRUE and `first_differing_pulse` NA in both rows; row a both equities `99984.34987600008`; row b both `99967.891749199887`; equal to the storage model, executed on 2026-10-29 with exactly these values | RNG-neutral storage (LDG-3158), not the pulse rule |
| `detection_gap` | identical (decision (11): detection policy unchanged) | none |

#### 8.2.1 Census predicates and expected-call ledger (review F3)

**Fixture fact.** `rp_census` runs right after `rp_rule_overlap`, which ends
with `rp_clear_seed()`. Every ledgr call restores an absent state as absent,
so `.Random.seed` is absent at the start of every census case. A new column
records this, and every count below relies on it.

**New observer columns (successor schema).** They are appended after the
original 13, in this order:

| Column | Type | Meaning |
| --- | --- | --- |
| `entry_seed_present` | logical | `.Random.seed` exists when the case starts |
| `preserve_calls` | integer | entries into `ledgr_rng_preserve_caller` |
| `rngkind_query_calls` | integer | zero-argument `RNGkind()` calls |
| `rngkind_query_callers` | character | sorted unique immediate callers of those, comma-joined |
| `rngkind_mutation_calls` | integer | argument-bearing `RNGkind(...)` calls |
| `rngkind_mutation_callers` | character | sorted unique immediate callers of those, comma-joined |
| `pulse_seed_vectors` | integer | calls to `ledgr_pulse_seeds` |

In the copy rows 03 and 08 every new column is the empty string, as their
other observer columns are today.

**Field predicates.** `case`, `path`, `seed_arg`, `default_seed`,
`set_seed_calls`, `set_seed_seeds` and `pulse_seed_execution_seeds` stay
identical in every row. The exception is row 05: its outcome changes
(below), while its `set_seed_calls` stays 0 and its
`pulse_seed_execution_seeds` stays empty. In operational rows (all except
03 and 08):

- `outcome` is `ok`. Row 05 changes from `ERROR ledgr_invalid_args: ...` to
  `ok` (walk-forward fix, LDG-3158).
- Where `set_seed_calls > 0`, `set_seed_callers` is exactly
  `ledgr_rng_seed_pinned` (changed from `ledgr_fold_envelope`) and
  `set_seed_kind_args` is exactly `Mersenne-Twister` (changed from `NULL`).
  Rows with no `set.seed` call keep empty strings (kind pin, LDG-3158).
- `entry_seed_present` is FALSE.
- `rngkind_query_callers` is `ledgr_rng_caller_state`.
  `rngkind_mutation_callers` is `ledgr_rng_restore`. No other caller is
  allowed; the worker pin does not run, because the census uses one worker.
- `rngkind_calls` (original column, total of queries and mutations) equals
  `rngkind_query_calls + rngkind_mutation_calls`.
- With E the number of wrapped-export frames entered and S =
  `set_seed_calls`:
  - `preserve_calls` = E;
  - `rngkind_query_calls` = E + S, because every wrapper and every seeded
    fold envelope captures the state once;
  - `rngkind_mutation_calls` = E + S, because every capture sees an absent
    state, so every restore takes the absent branch once.
- `pulse_seed_calls` counts calls to `ledgr_pulse_seed_at`, one per
  decision-due pulse. `pulse_seed_nonnull` counts those returning non-NULL.
  `pulse_seed_vectors` = S.

**Independent expected-call ledger.** E per path is fixed by the source:

- `ledgr_run` 1, `ledgr_sweep` 1, `ledgr_walk_forward` 1;
- `ledgr_promote` 2, because it calls the exported `ledgr_run`
  (`R/sweep.R:849`).

No other wrapped export is called internally on these paths: `ledgr_backtest`
and the windows call internals.

| Row | Path, seed | E | S | `preserve_calls` | query | mutation | `rngkind_calls` | `pulse_seed_calls` | `pulse_seed_nonnull` | `pulse_seed_vectors` |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 01 | run, NULL | 1 | 0 | 1 | 1 | 1 | 2 | 10 | 0 | 0 |
| 02 | sweep, NULL | 1 | 0 | 1 | 1 | 1 | 2 | 20 | 0 | 0 |
| 04 | promote, NULL | 2 | 0 | 2 | 2 | 2 | 4 | 10 | 0 | 0 |
| 05 | walk-forward, NULL | 1 | 0 | 1 | 1 | 1 | 2 | 19 | 0 | 0 |
| 06 | run, 24 | 1 | 1 | 1 | 2 | 2 | 4 | 10 | 10 | 1 |
| 07 | sweep, 24 | 1 | 2 | 1 | 3 | 3 | 6 | 20 | 20 | 2 |
| 09 | promote, 24 | 2 | 1 | 2 | 3 | 3 | 6 | 10 | 10 | 1 |
| 10 | walk-forward, 24 | 1 | 6 | 1 | 7 | 7 | 14 | 19 | 19 | 6 |

The positive predicates that review F3 required to keep:

- row 05's outcome is `ok`;
- row 05 has zero seed calls and zero non-NULL pulse seeds;
- row 05 has 19 decision reads, equal to row 10, which has the same folds
  and calendar.

Every other `pulse_seed_calls` value equals the original record. The
`pulse_seed_vectors` values also witness "computed once per fold".

**Ticket staging.**

- After LDG-3158 alone, with the original probe unchanged, the original
  census differs only in:
  - `set_seed_callers`, `set_seed_kind_args` and `rngkind_calls`, each as
    in the ledger;
  - row 05's `outcome`, `pulse_seed_calls` (19) and `pulse_seed_nonnull`
    (0). The scalar helper still exists and is still called once per
    decision-due pulse.
- After LDG-3159 the successor probe uses the adapted observer and the full
  schema above.

### 8.3 Replacement regression guts

The fix-shaped guts become inert once the fixes ship (`worker_kind`,
`flush_keeps_rng`, and `caller_leak`, which a wrapper would undo). They stay
as history. The replacement guts each undo a shipped fix in memory, reach
its production operation, and must make the comparator fail the named
predicate. A probe crash or a scope failure does not count.

| Gut | Mutation | Must fail |
| --- | --- | --- |
| R1 `kind_unpinned` | `ledgr_rng_seed_pinned` seeds without a kind; the worker pin is a no-op | `worker_agreement` booleans; `stochastic_*` w2 equality |
| R2 `store_unguarded` | `ledgr_store_append` calls `DBI::dbAppendTable` directly | `store_rng` equality |
| R3 `caller_unrestored` | `ledgr_rng_preserve_caller` forces `expr` without restoring; storage neutrality stays in place | `caller_rng` rows 13 and 15. Rows 01, 05 and 09 are not required to change, because storage neutrality protects them. The Section 5.5 drawing unseeded-run witness and the dynamic-route witnesses must fail too. |
| R4 `wf_seed_na` | `ledgr_walk_forward_run_or_open` passes the NA seed through again | `census` row 05 outcome |
| R5 `pulse_shift` | `ledgr_pulse_seeds(s, p)` returns v2 at `p + 1` | `pulse_seeds` reference; A4 |
| R6 `seed_ignoring` | `ledgr_pulse_seeds` ignores the execution seed | `pulse_seeds` reference; `stochastic_*` model equality |
| R7 `marker_stale` | `ledgr_seed_contract_current()` returns v1 | A1, A2 |
| R8 `config_rule_dropped` | the seeded config omits `pulse_seed_rule` | A3 |
| R9 `census_seed_caller` | `ledgr_fold_envelope` calls `set.seed` directly again | Section 8.2.1 `set_seed_callers`/`set_seed_kind_args` |
| R10 `wf_marker_from_constant` | `ledgr_candidate.ledgr_walk_forward_results` derives `pulse_seed_contract` from the constant instead of the results attribute | the LDG-3159 old/missing walk-forward candidate cases (Section 6) |

`wf_seed` (derivation) and `preflight_wide` (detection) stay meaningful and
remain in the original gut list.

## 9. Probe inventory dispositions (each site once)

| Inventory site | Disposition |
| --- | --- |
| `set.seed`: `R/fold-engine.R:1629`, `R/sim-bars.R:42`, `R/sim-pit-inputs.R:417` | `ledgr_rng_seed_pinned` (Section 3) |
| `.Random.seed` save/restore: `R/fold-engine.R:1615-1628`, `R/sim-bars.R:33-40`, `R/sim-pit-inputs.R:401-415` | replaced by `ledgr_rng_caller_state` and `ledgr_rng_restore` (Section 3) |
| `.Random.seed` save/restore: `R/backtest-runner.R:386-399`, `R/sweep.R:157-174`, `R/walk-forward.R:99-114` | deleted; owned by the entry wrapper (Section 5) |
| `.Random.seed` save/restore: `R/backtest-fills.R:64-76` | deleted; owned by `ledgr_store_append` (Section 4) |
| `stats::rnorm` in the simulators | inside the pinned seed and restore; unchanged |
| `mirai::daemons(workers)`, `R/parallel-workers.R:331` (and stop, `:337`) | worker pin after start; caller restore outside stop (Sections 3, 5) |
| every `dbAppendTable` (27 sites) | `ledgr_store_append` (Section 4) |
| `duckdb::duckdb_register`, `R/snapshot_adapters.R:309` | not a consumer (`tempfile()`) |
| `ledgr_derive_seed`, `R/rng.R:21-31`; `R/sweep.R:1294`; `R/walk-forward-identity.R:97` | unchanged (decision (2)) |
| `ledgr_derive_pulse_seed`, `R/rng.R:33-57`, and its call `R/fold-engine.R:766` | replaced by `ledgr_pulse_seeds` (Section 2) |
| `R/run-registration.R:20` | unchanged code; seeded default ids change through `config_hash` (Section 7) |
| version markers `R/sweep.R:469, 2179`, `R/sweep-persistence.R:584`, `R/promotion-context.R:133` | from the constant (Section 6) |
| static lists `R/strategy-preflight.R:673-679`, `R/determinism.R:7` | unchanged (decision (11)) |
| defect: `ledgr_walk_forward(seed = NULL)` (`R/walk-forward.R:676-684` via `:1118-1139`) | `ledgr_walk_forward_run_or_open` maps a missing or NA seed to `NULL` before `ledgr_run_window`; scores keep `execution_seed` NA (LDG-3158) |

## 10. Notes for the implementing tickets

- **LDG-3158** owns Sections 3, 4 and 5, the walk-forward fix, the NMOF
  `LSopt` gate (`dev/spikes/nmof-probe/probe.R`, `mv_card`: plain
  `with_seed` form agreeing across one and two workers, two `seed = 42` runs
  identical, `seed = 43` different; a missing NMOF is missing evidence), and
  the after-LDG-3158 rows of Section 8.
- **LDG-3159** owns Sections 2, 6 and 7, and A1 to A5 plus the v2 rows of
  Section 8.2.
- **Seven shapes.** Only the fold envelope changes on the hot path. One
  O(n_pulses) vector is built once per fold. The context reads one element
  by index through `ledgr_pulse_seed_at`, which replaces the per-pulse
  SHA-256 call with one subset. There is no new per-pulse work beyond that
  read, and the store helper runs per append, not per pulse.
- **Timing.** Timing is judged under the LDG-3156 protocol on the shared timing
  harness of LDG-3155.
- **Type 2.** Review F1 was settled by maintainer decision (14). The design
  review confirmed the two earlier readings: the run-local axis origin, with
  the same-calendar qualification of Section 2.3, and coverage of callback
  evaluators. The maintainer ruled on the two cases the first revision left
  open: decision (15) for A-1 and decision (16) for A-2 (Section 5.4). One
  narrow point remains listed, not decided: B-1, whether
  `ledgr_indicator_dev()`'s two helpers also force their arguments before
  saving. LDG-3158 needs a ruling on it before implementing those two
  helpers.

## 11. Review response (correction round 1)

The review is `ws2_rng_design_review.md` (Codex, NEEDS_TYPE_2, at
`565e8bbf`, recorded in `607ce382`). The maintainer settled F1 with decision
(14) (option B).

| Finding | Response | Where |
| --- | --- | --- |
| F1 boundary and partition | Decision (14) is stated as the boundary, with the documentation sentence. The rule now has W own-work, W service-code, R returned callables, H and N classes. `ledgr_sweep_review` moves from H to W. The source search adds `ledgr_pbo`, `ledgr_feature_grid` and `ledgr_strategy_grid` to W. `ledgr_indicator_dev`'s `test` and `test_dates` restore on their own calls; the constructor is H. Promises and external S3 methods are outside the promise. Dynamic-route, error-after-draw, interrupt-after-draw, worker/store-route and boundary witnesses are added. Counts regenerated: W 15, H 55, N 111 exports; S3 W 1, H 42, N 50; R 2. The two cases decision (14) did not settle were listed and are now ruled by decisions (15) and (16) (rows below). | Sections 1, 5.1-5.5, Appendix A |
| F2 unseeded walk-forward marker | A current `pulse_seed_contract` is required on every walk-forward candidate, seeded or not. It is stamped from the constant on the results object when the results are produced or opened, and copied into the candidate, independent of `engine$pulse_seed_rule`. Refusal comes before the snapshot hold. Old, missing and current cases cover seeded and unseeded sweep and walk-forward candidates. The derivation marker and the unseeded config rule are unchanged. | Section 6, Section 7, gut R10 |
| F3 census predicates | The new seeding caller, the query/mutation caller roles, the new column schema and an independent expected-call ledger with exact counts are frozen. The observation changes are authorised explicitly. Row 05's positive predicates are kept, there is no wholesale exemption, and the staging after LDG-3158 alone is stated. | Section 8 preamble, 8.2, 8.2.1, gut R9 |
| F4 `RNGkind` source guard | Exactly the zero-argument query is allowed in `ledgr_rng_caller_state`. Mutations are allowed only in `ledgr_rng_restore` and `ledgr_parallel_worker_rng_pin`. The pass and injected-failure tests are specified. | Sections 3, 4 |
| Optional: R3 | Rows 01, 05 and 09 are protected by storage neutrality, so R3 must fail rows 13 and 15 plus a drawing unseeded-run witness. | Sections 5.5, 8.2, 8.3 |
| Optional: B5 endpoints | Seed pairs (s, s+1) for s = 1..19, p = 1..(500-k), both directions; add control 9481. | Section 2.4 |
| Optional: walk-forward marker in summaries | Reproduction key and promotion source metadata gain `pulse_seed_contract`. | Section 6 |
| Reading (i) | Same-calendar equality only. A longer calendar need not agree, walk-forward promotion runs on the full calendar, and LDG-3159 must not assert overlapping-bar equality. | Section 2.3 |
| Reading (ii) | Confirmed by the review and subsumed by decision (14). | Section 5 |
| Decision (15), argument evaluation (case A-1, option b) | Each wrapped export has two steps: `ledgr_rng_force_args()` forces caller-supplied ordinary arguments and dots before `ledgr_rng_preserve_caller()` saves the state. Missing arguments and defaults stay lazy. The frozen `lazy` set (`rank_by`, `.filter`) is never forced. `missing()` and `match.arg()` stay in the prologue, all `on.exit` cleanup moves into the implementation, and S3 generics carry the steps in their methods. User S3 methods dispatched after entry are restored. Source check and witnesses are added: two-call seed, draw in an argument, S3 method after entry, missing and default arguments, and a gut that removes step 1. The documentation sentence is rewritten. Counts unchanged. | Sections 1, 5, 5.1, 5.4, 5.5 |
| Decision (16), built callables (case A-2, option 1) | `ledgr_signal_strategy()`'s strategy and `ledgr_adapter_r()`'s indicator function are machinery with no own restore; a direct call is the caller's own code. R is only `ledgr_indicator_dev()`'s `test` and `test_dates`. Witnesses: a drawing signal strategy varies across pulses inside a run and advances the caller's stream when called directly, and an `ledgr_adapter_r()` indicator called directly advances it too. The documentation sentence is rewritten; counts unchanged. One residual point, B-1 (argument forcing in the two R helpers), is listed, not decided. | Sections 5.1-5.5, 10, Appendix A |

## Appendix A. Entry-point partition (rule of Section 5.2)

Exports (181): W 15 (listed in Section 5.2, without the S3 method), H 55,
N 111. Registered S3 methods (93): W 1, H 42, N 50. Returned callables: R 2
(`ledgr_indicator_dev()`'s `test` and `test_dates`). Under decision (16),
`ledgr_signal_strategy()`'s strategy and `ledgr_adapter_r()`'s indicator
function are machinery with no restore of their own. They are not exports,
so the counts are unchanged by decisions (15) and (16). Changes from the
first draft: W gains
`ledgr_sweep_review`, `ledgr_pbo`, `ledgr_feature_grid` and
`ledgr_strategy_grid`; `ledgr_indicator_dev` moves from W to H, and its
returned methods become R.

**H exports:** ledgr_business_objective, ledgr_compute_metrics, ledgr_dsr,
ledgr_effective_trials, ledgr_experiment, ledgr_experiment_plan,
ledgr_facts_history, ledgr_facts_resolve, ledgr_facts_validate,
ledgr_feature_contract_check, ledgr_feature_contracts, ledgr_history_info, ledgr_indicator_dev,
ledgr_k_ratio, ledgr_min_track_record, ledgr_objective_diagnostic_threshold,
ledgr_objective_even_profit, ledgr_objective_even_trades,
ledgr_objective_max_drawdown, ledgr_objective_min_trades,
ledgr_objective_positive_trajectory, ledgr_objective_stable_region,
ledgr_objective_stable_runs, ledgr_parameters, ledgr_results,
ledgr_return_panel, ledgr_run_compare, ledgr_run_explain, ledgr_run_fills,
ledgr_run_info, ledgr_run_list, ledgr_run_strategy, ledgr_run_tags,
ledgr_snapshot_from_csv, ledgr_snapshot_from_df, ledgr_snapshot_from_yahoo,
ledgr_snapshot_info, ledgr_snapshot_list, ledgr_snapshot_open,
ledgr_snapshot_quarantine, ledgr_state_reconstruct, ledgr_sweep_filter,
ledgr_sweep_list, ledgr_sweep_open, ledgr_sweep_returns,
ledgr_sweep_returns_data_frame, ledgr_sweep_returns_matrix,
ledgr_sweep_returns_panel, ledgr_sweep_returns_wide, ledgr_sweep_returns_xts,
ledgr_sweep_save, ledgr_sweep_trades,
ledgr_walk_forward_folds, ledgr_walk_forward_open, ledgr_walk_forward_scores.

**H S3 methods:** as_tibble for ledgr_backtest, ledgr_dsr,
ledgr_effective_trials, ledgr_k_ratio, ledgr_min_track_record, ledgr_pbo,
ledgr_result_table, ledgr_sweep_filter_result; ledgr_candidate.default;
plot.ledgr_backtest; print for ledgr_backtest, ledgr_business_objective,
ledgr_comparison, ledgr_dsr, ledgr_effective_trials, ledgr_experiment,
ledgr_experiment_plan, ledgr_facts_history, ledgr_facts_report,
ledgr_facts_resolution, ledgr_fold_list, ledgr_history, ledgr_k_ratio,
ledgr_min_track_record, ledgr_objective_criterion, ledgr_pbo,
ledgr_result_table, ledgr_run_list, ledgr_selection, ledgr_signal,
ledgr_snapshot, ledgr_sweep_filter_result, ledgr_sweep_list,
ledgr_sweep_results, ledgr_sweep_review, ledgr_target,
ledgr_valuation_summary, ledgr_walk_forward_degradation,
ledgr_walk_forward_results, ledgr_weights; summary for ledgr_backtest and
ledgr_snapshot.

**N exports:** ledgr_adapter_csv, ledgr_adapter_r, ledgr_align_weights,
ledgr_backtest_bench, ledgr_calendar, ledgr_calendar_crypto,
ledgr_calendar_us_equity, ledgr_corporate_action_summary,
ledgr_corporate_actions, ledgr_corporate_actions_research,
ledgr_corporate_actions_strict, ledgr_cost_chain, ledgr_cost_describe,
ledgr_cost_fixed_fee, ledgr_cost_notional_bps_fee, ledgr_cost_spread_bps,
ledgr_cost_steps, ledgr_cost_zero, ledgr_db_init,
ledgr_demo_sma_crossover_strategy, ledgr_facts,
ledgr_facts_equity_corporate_actions, ledgr_facts_lifetime,
ledgr_facts_membership_intervals, ledgr_facts_membership_snapshots,
ledgr_facts_sessions, ledgr_facts_sessions_qlcal,
ledgr_facts_trading_status, ledgr_feature_id,
ledgr_feature_map, ledgr_fold, ledgr_folds_anchored, ledgr_folds_rolling,
ledgr_grid_add_baseline, ledgr_grid_cross, ledgr_grid_named,
ledgr_history_frame, ledgr_history_matrix, ledgr_history_policy,
ledgr_ind_ema, ledgr_ind_returns, ledgr_ind_rsi, ledgr_ind_sma,
ledgr_ind_ttr, ledgr_ind_ttr_outputs, ledgr_ind_ttr_warmup_rules,
ledgr_indicator, ledgr_indicator_get, ledgr_indicator_list,
ledgr_indicator_register, ledgr_indicator_remove, ledgr_iso_utc,
ledgr_metric_context, ledgr_metric_context_hash, ledgr_metric_crypto,
ledgr_metric_us_equity, ledgr_opening, ledgr_opening_from_broker,
ledgr_param, ledgr_passed_warmup, ledgr_promotion_context,
ledgr_pulse_features, ledgr_pulse_wide, ledgr_risk_chain,
ledgr_risk_free_rate, ledgr_risk_long_only, ledgr_risk_max_weight,
ledgr_risk_none, ledgr_rule_argmax, ledgr_rule_argmin, ledgr_run_archive,
ledgr_run_completion, ledgr_run_label, ledgr_run_open,
ledgr_run_promotion_context, ledgr_run_tag, ledgr_run_untag,
ledgr_schedule_dates, ledgr_schedule_from_param, ledgr_schedule_month_day,
ledgr_schedule_month_end, ledgr_schedule_month_start,
ledgr_schedule_quarter_start, ledgr_schedule_week_start,
ledgr_schedule_weekday, ledgr_schedule_year_start, ledgr_select_top_n,
ledgr_selection, ledgr_signal, ledgr_signal_feature, ledgr_signal_return,
ledgr_signal_strategy, ledgr_snapshot_close, ledgr_snapshot_create,
ledgr_snapshot_seal, ledgr_strategy_preflight,
ledgr_strategy_schedule, ledgr_sweep_info, ledgr_sweep_retention,
ledgr_target, ledgr_target_quantity, ledgr_target_rebalance,
ledgr_temp_store, ledgr_timing_next_open, ledgr_universe_members,
ledgr_utc, ledgr_validate_schema, ledgr_valuation_stale,
ledgr_valuation_summary, ledgr_weight_equal, ledgr_weights.

**N S3 methods:** [.ledgr_history_matrix, [.ledgr_sweep_results,
[<-.ledgr_history_matrix, as.matrix.ledgr_history_matrix,
close.ledgr_backtest, close.ledgr_indicator_dev, close.ledgr_pulse_context,
close.ledgr_snapshot, format.ledgr_metrics,
ledgr_candidate.ledgr_sweep_filter_result, ledgr_metric_context methods for
default, ledgr_backtest, ledgr_comparison, ledgr_experiment,
ledgr_metric_context, ledgr_metrics, ledgr_promotion_context and
ledgr_sweep_results, Math.ledgr_history_matrix, Ops.ledgr_history_matrix,
and print methods for ledgr_calendar, ledgr_config, ledgr_executable_grid,
ledgr_extracted_strategy, ledgr_fact_family, ledgr_facts,
ledgr_feature_map, ledgr_fold, ledgr_history_info, ledgr_history_policy,
ledgr_indicator, ledgr_indicator_bundle, ledgr_indicator_dev,
ledgr_metric_context, ledgr_metrics, ledgr_opening, ledgr_param_ref,
ledgr_precomputed_features, ledgr_pulse_context, ledgr_risk_free_rate,
ledgr_risk_model, ledgr_run_completion, ledgr_run_info,
ledgr_selection_rule, ledgr_strategy_grid, ledgr_strategy_preflight,
ledgr_sweep_candidate, ledgr_sweep_info, ledgr_universe_rule and
ledgr_valuation_policy.

## Appendix B. Evidence for this note

Scratch probes, run on the base tree `aa2931e9` with no product change. The
`load_all` side effect on `R/cpp11.R` and `src/cpp11.cpp` (line endings
only) was reverted after each run.

- Python goldens (Section 2.5) and the R double-split cross-check, including
  the probe digest reproduction: equal.
- Bounds table (Section 2.4).
- A0 pulse-rule model of `dense_risk_features`: rows listed in A4; loose
  and sweep_w2 identical, the latter because the model cannot reach workers.
- Storage model of `store_rng`: the values in Section 8.2, identical to the
  re-review's `flush_keeps_rng` observation.
- Static call graph over `asNamespace("ledgr")` with S3 dispatch edges:
  the Section 5 and Appendix A partition.
- Correction round 1: a read-only source search of `R/` at `aa2931e9` for
  `eval`, `evalq`, `eval_tidy`, `eval_bare`, `exec`, `do.call`,
  `match.fun`, `substitute`, `enquo`, `is.function()` parameters and
  returned closures (Section 5.3). The Section 8.2.1 ledger values `E` come
  from reading the internal calls between wrapped exports (only
  `ledgr_promote` -> `ledgr_run` on the census paths). The partition was
  rechecked against `NAMESPACE`: 15 + 55 + 111 = 181, with no overlap and
  no omission.

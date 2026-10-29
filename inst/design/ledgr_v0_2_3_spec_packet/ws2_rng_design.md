# WS2 design note: RNG reproducibility and the v2 pulse-seed rule

Role: record; the LDG-3157 design note for v0.2.3 cut 4, workstream 11.
Status: draft for review, written before any product change; it directs
LDG-3158 to LDG-3161 once its design review accepts it.
Authority: `tickets.yml` cut 4 (decisions (1) to (13)) and LDG-3157 scope;
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
as it was. Twelve exported functions (and one S3 method, through its
generic) are wrapped, at their outermost frame, by
`ledgr_rng_preserve_caller()`. It restores the caller's kind and
`.Random.seed`, or their absence, after all cleanup. Every other export is
RNG-neutral because the store helper covers its only possible draw. Old or
missing seed-rule markers on candidates are refused before a run is created.

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
- An unseeded fold builds no vector, and `ctx$pulse_seed` stays NULL.

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
| B5 shifted streams | seeds 1..20, pulses 1..500, shifts k = 1..5: count of `V(s+1, p) == V(s, p+k)` or `V(s, p) == V(s+1, p+k)` | <= 1 |
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
| worker start, `ledgr_parallel_worker_setup` (`R/parallel-workers.R:202`) | daemons run L'Ecuyer-CMRG | after `ledgr_parallel_mirai_start()`, `everywhere(RNGkind("Mersenne-Twister", "Inversion", "Rejection"))`. This is supplementary; the envelope still enforces the kind for each seeded fold. |

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
3. a call to `RNGkind` outside `ledgr_rng_restore` and the worker pin;
4. a call to mirai `daemons()` outside `ledgr_parallel_mirai_start` and
   `ledgr_parallel_mirai_stop`.

The inventory is a function over parsed source. Its test feeds it an
injected `DBI::dbAppendTable(con, "x", df)` and requires a report.
Separately, the helper is tested directly: present state, absent state, and
an error raised by the append.

## 5. (d) Caller restore at exported entry points

`ledgr_rng_preserve_caller(expr)` captures `ledgr_rng_caller_state()`,
registers `on.exit(ledgr_rng_restore(state))` and then forces `expr`.

- Each wrapped export's body is
  `ledgr_rng_preserve_caller(<existing implementation call>)`. Every inner
  `on.exit` therefore finishes before the restore: worker stop
  (`R/sweep.R:225`), store closing and snapshot release. The restore runs
  last on success, error and interrupt, for every seed value.
- The seeded-only restores at `R/backtest-runner.R:386-399`,
  `R/sweep.R:157-174` and `R/walk-forward.R:99-114` are deleted, because the
  wrapper owns them.
- Nested wrappers are harmless: `ledgr_promote` calls `ledgr_run`, and
  `ledgr_backtest` reaches the run path.

**Disposition rule.** The rule is mechanical. It uses a static call graph
over the ledgr namespace: symbol references, plus edges from every called S3
generic to all registered ledgr methods of that generic. An export is
**W (wrapped)** if its reach includes any of:

- `ledgr_fold_envelope`;
- a seeding site;
- worker start or stop;
- the feature-callback invokers `ledgr_call_feature_fn` and
  `ledgr_call_feature_series_fn`;
- the direct callback in `ledgr_indicator_dev`.

Every other export is **not wrapped**. Its only possible ledgr-owned RNG
consumption is a nonempty append, which the store helper neutralises. Such an
export is **H** if its static reach includes an append site (H exports get
caller-state witnesses), and **N** otherwise. All 181 exports and 93
registered S3 methods fall in exactly one class (Appendix A). Wrapping
callback evaluators satisfies decision (4) under its broadest reading: a
user indicator that draws leaves the caller's stream unchanged. Indicator
purity stays governed by `R/determinism.R`. LDG-3158 regenerates the
partition from the same rule. Its test fails if an export that the rule
puts in W lacks the wrapper. It also traces, during the targeted tests,
`ledgr_fold_envelope`, `ledgr_rng_seed_pinned` and
`ledgr_parallel_mirai_start`, and fails if the outermost ledgr export on the
stack is not in W. That catches dynamic calls the static graph misses.

**W (12 exports):** `ledgr_backtest`, `ledgr_candidate` (and the method
`ledgr_candidate.ledgr_walk_forward_results` through it),
`ledgr_candidate_reproduction_key`, `ledgr_indicator_dev`,
`ledgr_precompute_features`, `ledgr_promote`, `ledgr_pulse_snapshot` (which
runs an unseeded memory fold with an internal capture callback,
`R/pulse-snapshot.R:483-518`), `ledgr_run`, `ledgr_sim_bars`,
`ledgr_sim_pit_inputs`, `ledgr_sweep`, `ledgr_walk_forward`. The private
windows `ledgr_run_window` and the sweep window run inside
`ledgr_walk_forward`'s wrapper.

**Witnesses (LDG-3158).** The caller's next `runif(1)` and next
`sample(10)` after the call must equal those of an untouched session, and the
kind must be unchanged. They are run for every W export and for the H
representatives that append nonempty frames:

- `ledgr_snapshot_from_df`;
- `ledgr_results(bt, "fills")`;
- `print(bt)`;
- `ledgr_sweep_save`;
- `ledgr_state_reconstruct`;
- `ledgr_snapshot_quarantine`.

Caller states:

- MT/Inversion/Rejection;
- L'Ecuyer-CMRG;
- a non-default sample kind (Rounding);
- an absent `.Random.seed` under a non-default active kind. For this one
  the test asserts that the seed is still absent and that the kind is
  unchanged, because an unseeded next draw has no fixed value.

Exits:

- success;
- a setup failure after RNG state was touched;
- an interrupt, from a strategy that calls `rlang::interrupt()`, caught by
  the test with `tryCatch(interrupt = )`;
- a two-worker sweep, whose daemon start and stop consume caller RNG.

`ledgr_backtest_bench` reads telemetry only (`R/backtest-results.R:322`) and
is N.

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
| committed configuration | `R/backtest-config.R:186-192` | `engine$pulse_seed_rule <- ledgr_pulse_seed_rule_version`, **only when `seed` is non-NULL** |
| configuration validation | `R/config-validate.R:70-77` | a seeded config whose `engine$pulse_seed_rule` is not the current integer aborts with `ledgr_seed_rule_mismatch` |
| walk-forward candidate provenance | `R/walk-forward-inspection.R:217, 271` | `seed_contract` stays `"ledgr_walk_forward_seed_v1"` (derivation, unchanged); new field `pulse_seed_contract` is `paste0("ledgr_seed_v", cfg$engine$pulse_seed_rule)` from the test run's configuration when seeded, absent when unseeded |

**Candidate validation.** `ledgr_candidate_validate_seed_rule(candidate)`
runs in `ledgr_promote` right after argument checks, before the snapshot
hold and before `ledgr_run`. Both failure cases abort with class
`c("ledgr_seed_rule_mismatch", "ledgr_invalid_args")`:

- **Sweep candidate.** `provenance$seed_contract` must be
  `ledgr_seed_contract_current()`, seeded or not. Sweeps always carry it. A
  missing marker or `"ledgr_seed_v1"` is refused.
- **Walk-forward candidate** (`provenance$evaluation_scope ==
  "walk_forward"`). `seed_contract` must be `"ledgr_walk_forward_seed_v1"`.
  When `execution_seed` is not NA, `pulse_seed_contract` must also be
  current. An unseeded candidate runs no pulse seed.

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
| Executable candidate markers | sweep `seed_contract` v1 to v2; walk-forward candidates gain `pulse_seed_contract` | successor A0 `sweep_attrs` and `sweep.csv` |
| Simulated inputs | changed only for callers whose session kind is not the default | a witness under L'Ecuyer-CMRG equals the default-kind output |

## 8. (g) Successor records

The original A0 records (`dev/bench/v0_2_3_output_freeze/records/`) and the
RNG baseline (`dev/bench/v0_2_3_rng_baseline/records/`) stay unchanged as
history, along with their checkers, guts and `gut_results.csv`. Successors
are recorded on the candidate under `dev/bench/v0_2_3_cut3_successors/a0/`
and `.../rng/`. A comparator there reads original and successor field by
field. Every field not named below must be identical. Each named change must
satisfy its predicate. Any other difference fails. The probes may be adapted
only where they observe a deleted function (the scalar pulse-seed helper)
and only to read the vector owner instead.

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
| `census` | `path`, `seed_arg`, `default_seed`, `set_seed_calls`, `set_seed_seeds`, `set_seed_callers`, `pulse_seed_execution_seeds` identical for rows 01-04 and 06-10; `set_seed_kind_args` is `Mersenne-Twister` wherever `set_seed_calls > 0` (LDG-3158, kind pin); row 05 `outcome` is `ok`, `set_seed_calls` 0, `pulse_seed_nonnull` 0 (LDG-3158, unseeded walk-forward). With the observer adapted to count decision-due reads of the pulse-seed vector, `pulse_seed_calls` equals the original for every row except 05, which equals row 10's 19. Every `RNGkind` call has caller `ledgr_rng_restore` (observer extended to record callers) | kind pin, walk-forward fix, caller restore |
| `worker_agreement` | `candidate_id`, `pin`, `execution_seed`, `daemon_rng_kind` (the probe starts its own daemon) identical; statuses `DONE`; all four agreement booleans TRUE (LDG-3158); `n_trades_run == n_trades_w1 == n_trades_w2 >= 10`; final equities equal across paths and equal to the pulse-rule model (LDG-3159). After LDG-3158 alone: only the `none` row's `*_w2` fields change, to its `*_w1` values | kind pin; v2 rule |
| `stochastic_fills`, `stochastic_trades` | `run` and `sweep_w1` rows equal the pulse-rule model (LDG-3159); `sweep_w2` rows equal `sweep_w1` rows for every candidate (LDG-3158); each candidate trades at least two distinct instruments. After LDG-3158 alone: only `sweep_w2`/`none` trades change, to the original `sweep_w1`/`none` rows | kind pin; v2 rule |
| `caller_rng` | every row `caller_rng_unchanged` TRUE and `after_kind == before_kind`; `after_sha256 == before_sha256` where the state was set; rows 01, 05, 09, 13, 15 change only in those fields; all other rows identical | caller restore (LDG-3158) |
| `store_rng` | `equity_identical` TRUE and `first_differing_pulse` NA in both rows; row a both equities `99984.34987600008`; row b both `99967.891749199887`; equal to the storage model, executed on 2026-10-29 with exactly these values | RNG-neutral storage (LDG-3158), not the pulse rule |
| `detection_gap` | identical (decision (11): detection policy unchanged) | none |

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
| R3 `caller_unrestored` | `ledgr_rng_preserve_caller` forces `expr` without restoring | `caller_rng` rows 01, 05, 09, 13, 15 |
| R4 `wf_seed_na` | `ledgr_walk_forward_run_or_open` passes the NA seed through again | `census` row 05 outcome |
| R5 `pulse_shift` | `ledgr_pulse_seeds(s, p)` returns v2 at `p + 1` | `pulse_seeds` reference; A4 |
| R6 `seed_ignoring` | `ledgr_pulse_seeds` ignores the execution seed | `pulse_seeds` reference; `stochastic_*` model equality |
| R7 `marker_stale` | `ledgr_seed_contract_current()` returns v1 | A1, A2 |
| R8 `config_rule_dropped` | the seeded config omits `pulse_seed_rule` | A3 |

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
  O(n_pulses) vector is built once per fold, and the context reads one
  element by index. There is no new per-pulse work, and the store helper
  runs per append, not per pulse.
- **Timing.** Timing is judged under the LDG-3156 protocol on the shared timing
  harness of LDG-3155.
- **Type 2.** This note leaves no open Type 2 question. Two readings are
  stated so the review can reject them: the axis origin is the run's own
  calendar (Section 2.3), and wrapping covers callback evaluators
  (Section 5).

## Appendix A. Entry-point partition (static rule of Section 5)

Exports (181): W 12 (listed in Section 5, without the S3 method), H 56,
N 113. Registered S3 methods (93): W 1, H 42, N 50.

**H exports:** ledgr_business_objective, ledgr_compute_metrics, ledgr_dsr,
ledgr_effective_trials, ledgr_experiment, ledgr_experiment_plan,
ledgr_facts_history, ledgr_facts_resolve, ledgr_facts_validate,
ledgr_feature_contract_check, ledgr_feature_contracts, ledgr_history_info,
ledgr_k_ratio, ledgr_min_track_record, ledgr_objective_diagnostic_threshold,
ledgr_objective_even_profit, ledgr_objective_even_trades,
ledgr_objective_max_drawdown, ledgr_objective_min_trades,
ledgr_objective_positive_trajectory, ledgr_objective_stable_region,
ledgr_objective_stable_runs, ledgr_parameters, ledgr_pbo, ledgr_results,
ledgr_return_panel, ledgr_run_compare, ledgr_run_explain, ledgr_run_fills,
ledgr_run_info, ledgr_run_list, ledgr_run_strategy, ledgr_run_tags,
ledgr_snapshot_from_csv, ledgr_snapshot_from_df, ledgr_snapshot_from_yahoo,
ledgr_snapshot_info, ledgr_snapshot_list, ledgr_snapshot_open,
ledgr_snapshot_quarantine, ledgr_state_reconstruct, ledgr_sweep_filter,
ledgr_sweep_list, ledgr_sweep_open, ledgr_sweep_returns,
ledgr_sweep_returns_data_frame, ledgr_sweep_returns_matrix,
ledgr_sweep_returns_panel, ledgr_sweep_returns_wide, ledgr_sweep_returns_xts,
ledgr_sweep_review, ledgr_sweep_save, ledgr_sweep_trades,
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
ledgr_facts_trading_status, ledgr_feature_grid, ledgr_feature_id,
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
ledgr_snapshot_seal, ledgr_strategy_grid, ledgr_strategy_preflight,
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

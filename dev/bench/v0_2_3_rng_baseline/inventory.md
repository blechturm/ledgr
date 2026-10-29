# RNG inventory of `R/` (v0.2.3 RNG probe, question 5)

Tree: `release/v0.2.3` at `c836d291`. Located by grep for `set.seed`,
`RNGkind`, `.Random.seed`, `runif`/`rnorm`/`sample`/`r*(`, `with_seed`,
`dbAppendTable` and `daemons`; each hit read in its enclosing function. Rows
marked *executed* were observed by `probe.R` (record table in brackets).

## `set.seed()` calls

| Site | Function | Seed | Kind | Purpose |
| --- | --- | --- | --- | --- |
| `R/fold-engine.R:1629` | `ledgr_fold_envelope` | `as.integer(execution$seed)`, only when non-NULL | not pinned: the active kind (L'Ecuyer-CMRG on a mirai worker) | ambient stream for the fold; *executed*, the only `set.seed` caller in run, sweep, promote and walk-forward [census] |
| `R/sim-bars.R:42` | `ledgr_sim_bars` | `seed` argument | not pinned | simulated bars |
| `R/sim-pit-inputs.R:417` | `ledgr_sim_pit_inputs` | `seed` argument | not pinned | simulated PIT fixture |

No file in `R/` calls `RNGkind()` (the census traced zero calls). `RNGkind`
appears only as a name in the preflight mutation list.

## `.Random.seed` save and restore

All use the same idiom: remember `.Random.seed` (or its absence) and put it
back `on.exit`.

| Site | Function | When | Note |
| --- | --- | --- | --- |
| `R/fold-engine.R:1615-1628` | `ledgr_fold_envelope` | `seed` non-NULL | around the fold's `set.seed` |
| `R/backtest-runner.R:386-399` | `ledgr_run_fold_impl` | `seed` non-NULL | committed run, around the fold and its store writes |
| `R/sweep.R:157-174` | `ledgr_sweep_impl` | `seed` non-NULL | covers mirai start/stop only when seeded (H8) |
| `R/walk-forward.R:99-114` | `ledgr_walk_forward` | `seed` non-NULL | |
| `R/backtest-fills.R:64-76` | `ledgr_extract_fills_impl` | always | guards its own `dbAppendTable` at `:160` (the duckdb draw below) |
| `R/sim-bars.R:33-40`, `R/sim-pit-inputs.R:401-415` | simulators | always | around their `set.seed` |

With `seed = NULL` nothing is restored: `ledgr_run` advances the caller's
RNG and `ledgr_sweep(workers = 2)` advances it too; `ledgr_sweep(workers = 1)`
leaves it unchanged [caller_rng rows 01, 05, 09, 13, 15 vs 03, 07, 11].

## RNG-using calls

| Site | Call | Purpose |
| --- | --- | --- |
| `R/sim-bars.R:45,54,57-59,61` | `stats::rnorm` | simulated prices and volume, inside the saved seed |
| `R/sim-pit-inputs.R:421,423,437,441,447` | `stats::rnorm` | simulated PIT fixture, inside the saved seed |
| `R/parallel-workers.R:331` | `mirai::daemons(workers)` (mirai 2.7.2) | starting daemons advances the caller's RNG (or creates `.Random.seed`); daemons run L'Ecuyer-CMRG; *executed* [caller_rng 13, 15; worker_agreement `daemon_rng_kind`] |
| every `DBI::dbAppendTable` on a duckdb connection | duckdb 2.0.0 `duckdb_random_string()` = `paste(sample(letters, 10, replace = TRUE), collapse = "")` names a temporary view | traced in a committed run at `R/output-handler.R:74` (`ledger_events`) and `R/derived-state.R:215/219` (`equity_curve`) [store_rng; caller_rng 01, 05, 09]. Same call, by reading: `R/backtest-runner.R:289`, `R/output-handler.R:63,70,152`, `R/run-finalize.R:413,563`, `R/backtest-fills.R:160`, `R/sweep-persistence.R:63-69`, `R/walk-forward.R:1097-1102`, snapshot build `R/availability-persistence.R:20-141` |

`R/snapshot_adapters.R:309` (`duckdb::duckdb_register`) takes a name from
`tempfile()`, which does not use R's RNG.

Inside a seeded fold the flushes at `R/fold-engine.R:1558` (every
`checkpoint_every` pulses, default 10000 from `R/run-prepare.R:43`) and
`:2034` (end of fold) append through the persistent sink, so they draw from
the fold's seeded stream. The memory sink (sweep) does not. An ambient-RNG
strategy therefore gets the same draws in `ledgr_run` and `ledgr_sweep` only
up to the first checkpoint: the 10010-pulse case diverges at pulse 10004
[store_rng b]. With `ledgr_backtest(checkpoint_every = 5)` and a caller
`set.seed(1)`, results differ from `checkpoint_every = 10000` from pulse 8
[store_rng a]: a storage parameter changes stochastic results.

## Seed derivation (no RNG; SHA-256 of canonical JSON)

| Site | Function | Input |
| --- | --- | --- |
| `R/rng.R:21-31` | `ledgr_derive_seed` | `canonical_json(list(base_seed, salt))`, SHA-256, six 24-bit chunks weighted mod 2^31-1, plus 1 |
| `R/rng.R:33-57` | `ledgr_derive_pulse_seed` | salt `list(scope = "pulse", pulse_idx)`; returns NULL for a NULL seed |
| `R/fold-engine.R:766` | `ledgr_fold_stage_decide` | every decision-due pulse, also when `seed = NULL` (returns NULL); scheduled-skip pulses do not call it |
| `R/sweep.R:1294` | `ledgr_sweep_candidate_tasks` | candidate seed from `list(run_id = label, params = raw_params)`; NA when `seed = NULL` |
| `R/walk-forward-identity.R:97` | `ledgr_walk_forward_execution_seed` | `list(fold_seq, window, candidate_key)` |

`ledgr_run` and `ledgr_promote` derive nothing: `ledgr_run(seed = s)` uses `s`
as the execution seed, and promotion passes the candidate's stored
`execution_seed` to `ledgr_run`. `R/run-registration.R:20` hashes the seed
into the generated run id (no RNG).

Version marker: the sweep result carries `seed_contract = "ledgr_seed_v1"`
(`R/sweep.R:469`, and per candidate provenance at `:2179`), copied into sweep persistence and the promotion context
(`R/sweep-persistence.R:584`, `R/promotion-context.R:133`). A grep of `R/`
finds no seed-rule version in committed-run identity.

## Static RNG lists

| Site | List | Used by |
| --- | --- | --- |
| `R/strategy-preflight.R:673-675` | mutation: `set.seed`, `RNGkind` | Tier 3 |
| `R/strategy-preflight.R:677-679` | ambient: `runif`, `rnorm`, `sample` | Tier 2; refused for `workers > 1` (`R/sweep.R:216`) and resume (`R/run-resume.R:3`) |
| `R/determinism.R:7` | indicator purity: `runif`, `rnorm`, `sample` among others | custom indicator checks; same three names, same gap |

## What was learned, demoted, deleted

- Learned: an RNG consumer outside ledgr code that inventory rows X1 and H8
  do not name: duckdb's view naming on every append (caller RNG and the
  seeded fold stream). `R/backtest-fills.R` already guards it locally. H8's
  suspicion about worker start is confirmed: daemon start advances the
  caller's RNG.
- Learned: `ledgr_walk_forward(seed = NULL)` aborts. The test window passes
  `NA_integer_` to `ledgr_run_window` (`R/walk-forward.R:684` via `:1132`),
  and `ledgr_config` refuses it in `ledgr_seed_normalize` [census row 05].
- Learned, from the gut reruns (scratch, not records): pinning the daemons
  to Mersenne-Twister/Inversion/Rejection after start (`worker_kind`) makes
  the plain `with_seed` candidate agree across 1 and 2 workers; saving and
  restoring `.Random.seed` around `flush_pending` (`flush_keeps_rng`) makes
  both store_rng rows identical but leaves `ledgr_run(seed = NULL)` still
  advancing the caller's RNG (the post-fold equity append is outside it).
- Learned: why existing tests did not see this. `tests/testthat/test-rng.R`
  checks the caller RNG for snapshot ingestion, fill reads and *seeded* runs
  and sweeps only; the parallel and promotion `pulse_seed` tests
  (`test-sweep-parallel.R:136`, `test-sweep-parity.R:410`) use
  `ctx$pulse_seed %% modulus` arithmetic and never draw from an RNG.
- Demoted: the cost numbers in `cost/` are descriptive, one host, other
  sessions possibly running; they are not records and `check.R` ignores them.
- Excluded from records as non-deterministic: the digest of a caller RNG state
  created from the clock (caller state `absent`); the row keeps only whether a
  state appeared and its kind.
- Nothing deleted.

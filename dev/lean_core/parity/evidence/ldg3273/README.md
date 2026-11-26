# LDG-3273: sweep workers run lean, and the feature bridge

Cut 26 decision 5 and decision 6's worker workloads. Pin: the installed
library d5b3a151 (`C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`). Every run
below starts outside any ledgr source package (LDG-3271); `run_proofs.R`
reproduces the parity steps.

## What changed

- `dev/lean_core/loop_workers.R` (new, harness only): the worker channel.
  `lean_loop_install()` binds `lean_worker_setup()` over the pin's worker
  setup and `lean_worker_dispatch()` over its candidate dispatch, in gate and
  inert modes. After the pin starts its workers, each worker sources
  `load.R`, loads the lean core from the same pinned library with the
  parent's debug setting (and a variant's registered edits), installs the
  lean loop with the parent's hook mode, and wraps two bindings: the fold
  envelope (entries counted, each checked to be the lean envelope, outside
  the fold hooks) and the candidate task (the worker's entry record reset,
  every DuckDB bridge and the package writer watched over the whole
  candidate, one record file written on every exit path). The restore
  function of `lean_loop_install()` merges the records into `lean_entry`
  (counters by sum, bounds by maximum) after checking: every worker booted;
  one record per dispatched task, none missing, duplicated, undispatched or
  from another attempt; each record from the pinned build, the lean
  envelope, the parent's debug setting and hook mode, and (harness hooks)
  lean folds plus refusals equal to envelope entries. A failed check is a
  worker fault.
- `dev/lean_core/loop_harness.R`: the sweep-workers entry refusal and its
  recorder (`lean_sweep_impl`) are deleted; the entry record gains the
  worker fields; the backstop test seam: `backstop_after` marks the attempt
  at a set strategy call ("test seam: backstop"), so the whole-workload
  rerun is reachable again (nothing has called `lean_abort_attempt()` since
  Cut 19).
- `loop_parity.R`: the worker signal includes worker faults; the store
  signal and store path include store calls anywhere in a worker candidate;
  a variant expecting `worker` can be CAUGHT; a variant's edits are passed to
  its workers; new columns `worker_records`, `worker_entries`,
  `worker_faults`, `worker_store`; `<out>_workers.csv` holds one row per
  worker record (attempt, sweep, candidate, pid, origin, envelope entries,
  lean envelope, debug, hooks, lean folds, backstop, store calls). The
  workers_guard_off variant is removed (its two rows retired).
- `loop_workloads.R`: `witness_sweep_workers` is no longer a registered
  refusal.
- `loop_workloads_slice5.R`: nine worker workloads with reach predicates
  (each counts, in the pinned arm, the tasks dispatched to workers):
  `s5_workers_sizing` (slice-2 sizing with the fee-bearing cost chain),
  `s5_workers_missing` (slice-3 missing bars, frozen valuation),
  `s5_workers_facts` (slice-4 member facts: D joins and is held),
  `s5_workers_dividend` (a corporate action), `s5_workers_consecutive` (two
  sweeps), `s5_workers_failing` (an unmarked failing candidate, as a row and
  escaping), `s5_workers_backstop` and `s5_workers_backstop_escape` (the
  late worker backstop), `s5_walk_forward_workers` (costs, a risk chain,
  two-worker training sweeps).
- `feature_bridge.R` (new): the feature bridge, below.

## Workers run lean (acceptance 1)

| run | result |
| --- | --- |
| `workers_gate_debug0` / `_debug1` | 17 workloads (the six existing worker workloads, walk_forward, witness_walk_forward and the nine new ones), 382 tables, 0 different, PASS 17 |
| `workers_batch1_debug0` / `_debug1` | the same at batch bound one: PASS 17 |
| `workers_inert_debug0` / `_debug1` | the same with inert hooks: 0 different, PASS* 17 (inert hooks count no lean folds; the worker records do) |

`*_workers.csv`: 37 worker records per run (15 workloads with worker
sweeps; walk_forward and witness_walk_forward have none), every record
from `C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151/ledgr`, every envelope entry
the lean envelope, debug as run, hooks `harness` (gate, batch one) or
`inert` (inert), no store call, no worker fault. `s5_workers_consecutive`
shows two sweeps (sweep 1 and 2, four distinct worker processes); the
walk-forward training sweeps are one sweep per fold.

Fail-closed checks, each its own variant, CAUGHT with debug off and on
with identical public tables (`variant_*`):
`worker_lean_not_installed` (pinned envelope, inert hooks),
`worker_record_dropped` (missing), `worker_record_duplicated` (duplicated),
`worker_wrong_build` (workers reload ledgr from a copy of the pinned
library: same commit, another directory; the origin check names it). A
record from another attempt fails the same check (`lean_workers_merge`:
"worker records from another attempt").

## Worker-local faults (acceptance 2)

| fault | variant | signal reaching the parent | tables |
| --- | --- | --- | --- |
| store access while a worker's pulses run | `store_execute` | store (`rapi_prepare`, `rapi_execute`, `rapi_release`) | identical |
| terminal durable write in a worker | `worker_terminal_write` | store, path `ledgr::ledgr_store_append` from the whole-candidate watch | identical |
| sink call while pulses run | `write_in_loop` | sink (`write_fill_events`) | differ (the duplicate write's own refusal) |
| hold expansion | `worker_hold_signal` | hold (2 calls) | identical |
| append-bound violation | `expand_whole` at batch one | unbounded (range > 1) | identical |
| lowered P5 fill limit | `worker_capacity_lowered` | the capacity refusal in the candidate rows | differ |

A worker candidate never computes holds: its memory sink has no
implicit-record encoder (the pin's `R/output-handler.R:625`;
`ledgr_fold_diagnostic_writer()` then reports `can_encode` FALSE), so a hold
expansion is unreachable in a worker. `worker_hold_signal` drives the
detector's hook in the worker to prove its transport.

Debug-only assertion in an actual worker: `cost_columns_short` on
`s5_workers_sizing` with debug on is CAUGHT with the resolver's debug-only
message ("The cost resolver must return one price and one fee per fill")
in the worker's candidate rows; with debug off
(`variant_cost_columns_short_debug0_production`) the check does not run
and the fault surfaces as the production error ("replacement has length
zero"; the run's UNRELATED verdict and status 1 are expected: it is
recorded, not a manifest row). Unmutated, debug off, the
worker results are unchanged (`workers_gate_debug0`).

## Backstop, failures, fresh channel (acceptance 3)

- `s5_workers_backstop`: the seam marks every worker candidate at its
  sixth strategy call, after the day-2 and day-4 fills; candidate c fails
  unmarked on day 3. The workload draws from the caller's stream first
  (`set.seed(4251)`) and reports the entry state. The lean arm's records
  carry the mark; the parent reruns the whole workload on pin-only workers
  (`workers lean 4/4`: two from the attempt, two from the rerun, every
  origin the pin; the rerun's workers load no lean core and send no
  record) with the entry RNG restored: every table identical.
- `s5_workers_backstop_escape`: stop_on_error TRUE, so the first marked
  failure escapes the sweep; entry state unseeded with the Wichmann-Hill
  kind, reseeded under Mersenne-Twister inside the workload. Identical after
  the rerun.
- `worker_backstop_rerun_skipped` (the rerun skipped): CAUGHT on both,
  the coverage condition visible; `worker_rng_restore_skipped`: CAUGHT on
  both (`rng_entry`, `rng_after`).
- `s5_workers_failing`: an unmarked failing worker candidate keeps its
  original condition as a row (stop_on_error FALSE) and escaping (TRUE),
  with no rerun.
- Channel state is per install (one attempt) and per sweep (sweep sequence
  in every key); each task resets the worker's entry record, and the merge
  checks lean folds against envelope entries per record.

## The feature bridge (acceptance 4)

`feature_bridge.R` loads one library per fresh process and, at every
fold-envelope entry (parent and each worker), reads what the lean fold
reads from the execution (`dev/lean_core/loop.R`: the validated execution,
its projection indexed at the fold's pulses, the pin's lookup state for the
feature IDs and active aliases): values, NA mask, indexed planes, axes and
mapping, each a sha256 digest. Inputs: the accepted oracle's own e2e
fixtures and indicators (`dev/feature_parity/corpus.R`: bar-native and
declared sessions with gaps and a late-known inactive instrument) plus two
parameterised aliases (RSI, BBands), two candidates; routes: implicit
preparation, implicit with two workers, explicit precompute reused, and
that reuse with two workers.

| file | result |
| --- | --- |
| `bridge/pin.csv`, `bridge/final.csv` | pin `pin-lib-d5b3a151/ledgr @ d5b3a151`, final build `lib-final-2bd1a33e/ledgr @ 2bd1a33e` (release head, installed by `dev/feature_parity/install_arm.R`); 96 records each from 9 processes (parent and workers), every process naming its build |
| `bridge/check_final.txt` | BRIDGE CHECK PASS: every route equal per candidate in each arm, the final build equal to the pin |
| `bridge/check_fault_value.txt` | `--fault=value` (one transferred projected cell changed in the workers): FAIL, `values` signals on the worker routes |
| `bridge/check_fault_mapping.txt` | `--fault=mapping` (a candidate's alias map reversed in the workers): FAIL, `mapping`, `values` and `na` signals |
| `bridge/oracle_check_final_vs_pin.txt` | the accepted oracle (`runner.R` on both libraries, `check.R`): CHECK PASS, 694 cases, 52 declared cases compared with `declared_expected.csv`; `oracle_provenance_*.csv` name the builds |

The bridge is not the gate: the gate runs the lean loop over the pin
only, so no gate run exercised the new package feature path. The full
integrated proof (the lean loop consuming the new feature path) is a switch
obligation, recorded in Section 19.14 (LDG-3274).

## LDG-3272's variant witnesses

`compiled_dispatch_skipped` on `s5_compiled_missing_native` and
`compiled_event_kinds_skipped` on `s5_compiled_event_kinds` (the E-stage
call omitted: the lean FIFO completes where the pin refuses, the pin's
refusal lost) and `capacity_late` on `s5_compiled_capacity_over` at the
normal bound and batch one: CAUGHT with debug off and on.

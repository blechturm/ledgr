# Slice-5 probe (slice-5 cut input, 2026-11-26)

A probe, not product code. The question: what does the lean loop need to
reproduce the pin for slice 5, and how big is it? The method is slice 4's
probe (`dev/spikes/slice4_probe/`). The slice-5 cut rebuilds the work
properly; these files are inputs, not evidence.

Slice 5 is the set of coverage refusals left after slice 4 (interface
Section 19.13's table): sweep workers, compiled FIFO, restart,
walk-forward and the checkpoint control. Base: release/v0.2.3 at
2bd1a33e, `dev/lean_core/` unchanged since Cut 21 except as below; pin
library `C:/Users/maxth/ledgr-wt/pin-lib-d5b3a151`.

`probe.patch` is the final diff against 2bd1a33e. Every change is marked
"slice-5 probe":
- `dev/lean_core/loop.R`: the compiled-FIFO and checkpoint coverage checks
  disabled.
- `dev/lean_core/loop_harness.R`: the walk-forward and checkpoint entry
  refusals disabled; the sweep-workers record removed; a wrapper over the
  pin's `ledgr_parallel_worker_setup()` that, after the pin starts its
  workers, loads the lean core into every worker from the same pinned
  library, installs the lean loop with the harness hooks, and logs each
  worker fold (pid, lean folds, refused, backstop, store accesses, sink
  calls) to `Sys.getenv("LEAN_PROBE_WORKER_LOG")`.
- `dev/lean_core/parity/loop_workloads.R`: the four registered refusals
  (loop_expect_refused) commented out.
- `dev/lean_core/parity/loop_workloads_slice5.R` (new): two restart
  workloads; `loop_parity.R` sources it.

Reproduce: a worktree at 2bd1a33e, `git apply probe.patch`, then from a
directory that is NOT a ledgr source package (see the harness finding)
run `dev/lean_core/parity/loop_parity.R --lib=<pin library> --debug=0|1
--out=... [--workloads=...] [--freeze=.../loop_freeze.csv]` with
`LEAN_PROBE_WORKER_LOG` set.

## Steps and results

| Step | File | Result |
| --- | --- | --- |
| 1. Baseline | `a_baseline_debug1.csv` | The 10 workloads that reach a slice-5 refusal, 304 tables identical; each refused at its slice-5 feature. |
| 2. Compiled FIFO, refusal lifted | `b_compiled_debug1.csv` | `dense_cost` (the only workload with `compiled_accounting_model = "spot_fifo"`, its `sweep_compiled` path) runs 9 folds lean instead of 6; 40 tables identical. The lean R FIFO reproduces the compiled arm's output on this workload. |
| 3. Checkpoint control, refusal lifted | `c_checkpoint_debug1.csv` | Both checkpoint witnesses run lean; 32 tables identical (FAIL only because they were registered as refusals). |
| 4. Walk-forward, refusal lifted | `d_walk_forward_debug1.csv` | `walk_forward` 10 lean folds, `witness_walk_forward` 6; with step 3, 92 tables identical. |
| 5. Sweep workers, lean loaded in each worker | `e_workers_debug1.csv` | Run from the scratch directory: 6 workloads, 212 tables identical; all 12 worker processes load the pinned library and install the lean loop, every worker fold ran lean with no refusal, backstop, store access or sink call. |
| 6. Restart | `f_restart_debug1.csv` | Two new workloads (`s5_restart_plain`, `s5_restart_opening`): a first attempt fails in the strategy on day 5, a second `ledgr_run()` under the same run_id replaces it. 58 tables identical, 2 lean folds each. The pin's own tables show the restart (attempt 1 FAILED with 0 events or its 2 opening events; attempt 2 DONE with 4 fills, or 2 openings plus 4 fills, no duplicates). |
| 7. Full gate, against `loop_freeze.csv` | `g_gate_debug0.csv`, `g_gate_debug1.csv` | 205 workloads, 3,194 tables, 0 different in each mode; 192 PASS, 1 PASS* (`s3_sched_none`, as before), 12 PATH, all expected (below). Every worker process (12 in each mode) loaded the pinned library and installed the lean loop; every worker fold ran lean with no store access or sink call. |

The 12 PATH verdicts in step 7: the 10 workloads of step 1 now run lean
(their frozen rows record the old refusals), and the 2 new restart
workloads have no frozen row.

## Findings

- **Restart is already covered.** Pulse-level resume was retired
  (per-pulse records synthesis); `ledgr_run_restart_nonterminal()` always
  returns `start_idx = 1L` (`R/run-resume.R:55`), so the lean loop's
  `start_idx` check (`dev/lean_core/loop.R:83`) can never fire. A restart
  replaces the earlier attempt before the fold and the lean loop runs it
  from pulse one.
- **Compiled FIFO.** The pin uses `spot_fifo.cpp` only for buffered
  ephemeral folds (sweep candidates) with FILL events
  (`R/compiled-spot-fifo.R:54-107`). With the refusal lifted, the lean loop
  runs its own R FIFO for such a run and the tables are identical on the
  one gate workload that selects it. The accepted pulse-plumbing amendment
  (R10) keeps "the existing compiled arm's state/sequence-before-append
  order ... until its separately authorized WS14 replacement" and slice 1
  refusing compiled FIFO; R12 routes any compiled FIFO to WS14. The
  maintainer decided on this probe (2026-11-26): the lean loop ignores the
  selector until WS14, with an amendment to that text.
- **Checkpoint control.** Lifting the refusal gives identical tables, but
  the accepted D3 synthesis (Section 2) keeps the control refused before
  the switch and removes it at the switch; it explicitly rejects keeping it
  "as an ignored compatibility control". The cut keeps it refused.
- **Walk-forward** was refused for scope only; every table is identical.
- **Sweep workers** run lean once each worker loads the lean core. Before
  the switch only the harness can do that (workers load the installed
  package); at the switch the lean loop is in the package and workers load
  it with it. A coverage condition raised in a worker cannot rerun the
  workload from the worker; worker records must reach the parent's entry
  record.
- **Harness gap (pre-existing).** `ledgr_parallel_ledgr_source_path()`
  (`R/parallel-workers.R:244-262`, the same in the pin) makes workers
  `pkgload::load_all()` the working directory when it is a ledgr source
  package. Run from a worktree root, as earlier gates were, the A0
  workloads' worker sweeps (`sweep_w2` in `dev/bench/v0_2_3_output_freeze/lib.R:489`)
  loaded the worktree's release source in both arms, not the pin; the
  probe's first worker run showed it (workers loaded from the worktree and
  the lean load refused). Those tables were never a pin comparison of the
  worker path; no lean claim rested on them, because the lean loop refused
  worker sweeps. `witness_sweep_workers` loaded the pin. The cut must run
  the gate from a non-package directory and check that every worker loads
  the pinned library.

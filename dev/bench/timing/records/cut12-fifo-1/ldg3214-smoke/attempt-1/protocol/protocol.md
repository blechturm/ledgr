# Protocol cut12-fifo-1

The Cut 12 FIFO gate owned by LDG-3214 (Cut 12 decision (5)). It asks, per
caller and block bucket of the registered fill-heavy run (500 x 1,260, SMA
5/10, `dev/bench/v0_2_3_ws16_entry/workloads.R`), whether the lean kernel plus
its boundary validation costs at most half the pinned kernel plus input
validation on the same captured calls.

Both arms install the pin `d5b3a151`. The runner is launched with
`--candidate-overlay=dev/lean_core,dev/bench/v0_2_3_ws16_entry`, so the
candidate arm is the pin plus the committed `dev/lean_core/` tree, and the
checker treats the record as a gate. The base arm reads only the entry
workload and its capture helpers from the overlay; it never sources
`dev/lean_core/`.

Each slot, in a fresh process: builds the fill-heavy snapshot in its slot
directory, runs it with `ledgr_lot_apply` wrapped (the entry method of
`fifo_cost.R`: caller found on the stack, the call's book and input kept when
its caller and bucket are the cell's), reads fills and equity (the replay
caller), restores the kernel, then times its arm `reps` times over the kept
calls in one section:

| arm | timed per call |
| --- | --- |
| base | `ledgr_lot_apply(book, ledgr_lot_input(...))`, installed (byte-compiled) |
| candidate | `lean_lot_apply(book, lean_lot_input(...))` from `fifo.R`, debug off, every function `cmpfun`-compiled |

The JIT is off for the timed section in both arms. The clock `block` is the
wall time of that section; the snapshot, the run and the capture are outside
it. `reps` is frozen per cell so each candidate section lasts about 3 s at the
expected 0.5x (entry record: 246 and 268 us per pinned call).

Cells: `fold_10_49`, `fold_50plus` (`ledgr_fold_fill_candidate`) and
`replay_10_49`, `replay_50plus` (`ledgr_replay_accounting_events`); the entry
record holds 361, 888, 363 and 887 calls. These four cells are the
fill-heavy per-bucket gate. Decision (5)'s other clause, no captured
operation group slower than pinned in total, groups calls by operation
(opening, fill, disposition) and block bucket (1-9, 10-49, 50+) across every
capture (A0 workloads, momentum, fill-heavy, the test suite's unmocked
calls); it runs through the descriptive probe
`dev/bench/v0_2_3_cut12_floor_budget/fifo_groups.R`, not through this
protocol.

Work string: caller, bucket, kept calls, their rows, fill count, final equity
(entry record 67,725 and 10728506.707646), a SHA-256 prefix of the kept calls
and of the arm's results (format-2 serialization), and `reps`. Both arms must
report the same string, so the gate also proves result parity on every timed
call.

Bound 0.5 on every cell (decision (5)); a miss is fixed or accepted by the
maintainer in a separate record. Eight alternating pairs.

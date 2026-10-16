# History worker shared-memory feasibility closeout

**Verdict:** RED for adopting mori in the present two-worker history design.
The integration is technically feasible and exact, and none of the charter's
RED kill conditions fired. Adoption is rejected under the question's
*materially* clause and the repository complexity gate. At two workers, the
largest avoidable copy is about `(workers - 1) * 44.9 MB`, only 3--4% of the
roughly 1.3 GB sampled total; the observed reduction was 42.0 MB (3.1%). No
numerical materiality threshold was preregistered. Wall time is observational
and does not decide the verdict.

## What ran

The binding run reused E0's vendor-neutral availability fixture and production
task builder/evaluator: 160 instruments, 208,797 bars, 1,305 pulses, four
candidates and two mirai daemons. Corrected staged mirai C was compared with:

- D-share, sharing eight immutable fields and rebuilding `pulses_iso`;
- D-rebuild, also rebuilding `bars_mat` and `static_bars_views`.

All twelve measured candidates finished `DONE`; final equity, return, trades,
seed, snapshot hash, strategy hash and reproduction-key hash matched. Separate
verification runs reconstructed all four tasks in each mori arm, comparing all
28 named fields. Every selected atomic leaf remained shared around evaluation.

A deterministic single-reference probe confirmed that a shared root list
refuses ledgr's outer-list replacement with mori's `Set_elt` error. Extra
references may make R duplicate to an ordinary list first, so such success is
not a stable guarantee. The working form uses one region and ordinary outer
containers around shared leaves.

## Binding observations

| Arm | Parent + daemons private | Parent sampled | Parent checkpoint | Wall |
| --- | ---: | ---: | ---: | ---: |
| C staged mirai | >=1,338.3 MB | >=619.1 MB | >=485.3 MB | 10.28 s |
| D-share | >=1,296.2 MB | >=550.1 MB | >=559.1 MB | 11.37 s |
| D-rebuild | >=1,374.8 MB | >=546.4 MB | >=508.8 MB | 10.89 s |

The sampled population is the parent plus recorded mirai daemons; the
dispatcher is not sampled. Sampling and in-process checkpoints missed
different spikes. Honest parent lower bounds are therefore C >=619.1 MB,
D-share >=559.1 MB and D-rebuild >=546.4 MB, with ranking indeterminate.
Parent-plus-daemon working-set bounds were 1,282.6, 1,359.2 and 1,371.5 MB,
but may count shared pages more than once. Private commit is not unique RSS.

D-share's 44.9 MB ordinary XDR substrate became a 361-byte mori reference.
Daemon sampled private commit fell 6.5%, but the parent retained the task list
and paid to create and touch the region. Versus D-share, D-rebuild increased
sampled parent-plus-daemon private commit 6.1% and daemon private commit 8.4%.
If reconsidered, share both bar derivatives and rebuild only `pulses_iso`.

Each returned result serialized to 3,219 bytes; collected result lists occupied
44,208 bytes. In D-share, private commit after dropping promises was 0.02 MB
higher, not measurably lower, than the largest collection checkpoint. The old
2,128-byte number measured promise handles, not retained payload. Promise
payload retention remains unmeasured.

## Lifecycle and boundary

Success and deliberate worker failure completed explicit cleanup. A live
mapping positive control passed immediately before forced process-tree
termination; after creator death, Windows removed the mapping although R
cleanup did not run. This uses a toy payload. Production sweep interruption
and POSIX orphan behavior remain untested.

The gut retained all field names but corrupted `runtime_projection`;
daemon-side `identical()` named it and the checker rejected the evidence. The
spike proves exact local sharing, compact serialization, copy-on-write
isolation, exercised parity and Windows OS cleanup. It does not prove unique
RSS, larger-worker scaling, a persistent lifecycle, Linux behavior or speed.

Reopen only when `(workers - 1) * substrate bytes` is a material share of
measured total private commit on the real H1/Sharadar workload, and/or when
another platform permits unique-page measurement. Measurement capability
alone creates no benefit. For this wave, retain staged mirai C and add no mori
dependency or product abstraction.

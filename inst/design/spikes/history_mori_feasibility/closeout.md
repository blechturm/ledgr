# History worker shared-memory feasibility closeout

**Verdict:** RED for adopting mori in the present two-worker history design.
The integration is technically feasible and exact, but at the binding shape it
did not materially reduce measured total memory. D-share lowered sampled
process-tree private commit by 3.1%, while process-tree working-set sum rose
6.0%, the in-process parent private peak rose 15.2%, and observed wall time
rose 10.6%. These are observations from one Windows shape, not a portable
performance ranking.

## What ran

The runner reused E0's vendor-neutral availability-active fixture and actual
production candidate-task builder/evaluator: 160 instruments, 208,797 bars,
1,305 open pulses, four candidates and two mirai daemons. Corrected staged
mirai C was compared with D-share (mori shares the eight observed immutable
fields and rebuilds `pulses_iso`) and D-rebuild (also rebuilds `bars_mat` and
`static_bars_views`). Exact reconstruction ran in separate processes so its
full expected-task payload did not enter the measured arms.

All twelve measured candidates finished `DONE`. Final equity, total return,
trade count, execution seed, snapshot hash, strategy hash and normalized
reproduction-key hash matched. Both mori forms reconstructed every field of
all four production tasks exactly. Every selected atomic leaf remained
mori-backed before and after evaluation. A root shared list was rejected by
the probe because ledgr legitimately updates outer list containers and mori's
read-only ALTLIST has no `Set_elt`; the working form maps one region and
reconstructs ordinary outer containers around shared atomic leaves.

## Binding observations

| Arm | Tree private | Tree working set | Daemon private | Parent private | Wall |
| --- | ---: | ---: | ---: | ---: | ---: |
| C staged mirai | 1,338.3 MB | 1,282.6 MB | 889.5 MB | 485.3 MB | 10.28 s |
| D-share | 1,296.2 MB | 1,359.2 MB | 831.9 MB | 559.1 MB | 11.37 s |
| D-rebuild | 1,374.8 MB | 1,371.5 MB | 901.7 MB | 508.8 MB | 10.89 s |

D-share's 44.9 MB ordinary XDR substrate serialized as a 361-byte mori
reference. That compact transport is real, but the parent still retained the
production task list and paid to create/touch the shared region. The daemons'
private peak fell 6.5%, while the parent's in-process private peak rose 15.2%.
Windows working-set sums double-count shared pages, and private commit is not
PSS or unique resident memory, so the totals do not reveal the true unique
physical peak.

Rebuilding the bar derivatives is the losing form at this shape: versus
D-share, D-rebuild raised tree private commit by 6.1% and daemon private commit
by 8.4%. If a later design reopens mori, share `bars_mat` and
`static_bars_views`; continue rebuilding the cheap `pulses_iso`.

Promise handles peaked at 2,128 bytes and collected result lists at 44,208
bytes in every arm. Returned candidate results serialized to 12,876 bytes in
every arm. Dropping promise handles was observed separately from retaining
results; neither is a material explanation for the peak at this fixture.

## Lifecycle and boundary

Success and deliberate worker failure completed explicit cleanup. After a
forced parent interruption, the process tree exited with no surviving Windows
mapping even though R cleanup did not complete. The deliberate gut omitted
`runtime_projection`; exact reconstruction named that field and the registered
checker rejected the altered evidence.

The spike proves exact local sharing, compact serialization, copy-on-write
isolation, the exercised output/identity parity and cleanup behavior. It does
not prove PSS/unique RSS, larger-worker scaling, a persistent worker lifecycle,
Linux behavior, or a speed benefit. Reconsider only if the design grows beyond
two local workers or a platform can measure unique shared-page attribution.
For the current history wave, retain corrected staged mirai C and add no mori
dependency or product abstraction.


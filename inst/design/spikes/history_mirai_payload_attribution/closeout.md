# History worker payload attribution spike closeout

**Verdict:** GREEN for the charter's prerequisite question. The current
executor repeats a large candidate-invariant payload, and staging that exact
payload once per persistent daemon reduced sampled process-tree memory without
changing results or identity. This does not select mori or a product design.

## What ran

The binding Windows record used a vendor-neutral availability-active snapshot:
160 instruments, 208,797 bars, 1,305 open pulses, four candidates and two
workers. Arms were run serially in fresh processes:

- A: production sequential sweep, as the result and resource reference;
- B: current mirai task dispatch, instrumented at task and promise boundaries;
- C: the same worker evaluator, with exact invariant task fields staged once
  on each daemon and only candidate fields sent per task.

All twelve candidate executions finished `DONE`. Candidate metrics, execution
seeds, snapshot and strategy hashes, and normalized reproduction-key hashes
were identical across A, B and C. The checker reran and diffed the deterministic
record. The gut demo removed `bars_by_id` from C and was rejected.

## Payload attribution

Each current task serialized to 45,058,205 bytes. Four tasks totaled
180,232,820 bytes. The invariant sublist serialized to 44,955,808 bytes, while
all four candidate-varying lists together serialized to 410,308 bytes. A
two-daemon staged proxy was 90,321,924 bytes: 89,910,896 bytes, or 49.9%, below
the current repeated-task proxy.

The dominant invariant fields were the three bar representations:
`static_bars_views` (16.14 MB serialized), `bars_by_id` (15.72 MB) and
`bars_mat` (10.86 MB). The feature projection was 1.80 MB. Availability data,
fact rows and pulse axes were much smaller on this fixture but remain part of
the same immutable substrate. The R task-list `object.size()` was 228.3 MB;
that figure is not additive because list fields may share R objects.

## Time and memory

| Arm | Sweep wall | Parent peak working set | Daemon peak sum | Tree peak sum | Tree private commit |
| --- | ---: | ---: | ---: | ---: | ---: |
| A sequential | 14.58 s | 501.2 MB | n/a | 501.2 MB | 514.4 MB |
| B current mirai | 14.50 s | 692.8 MB | 923.1 MB | 1,543.8 MB | 1,683.1 MB |
| C staged mirai | 10.10 s | 702.9 MB | 845.8 MB | 1,285.2 MB | 1,335.3 MB |

C reduced the sampled tree peak by 258.5 MB (16.7%) on working-set sums and
347.8 MB (20.7%) on private committed bytes relative to B. Its daemon sums
were about 8% lower. Parent working set did not improve.

The wall numbers are not a speed comparison. B's instrumented sweep includes a
4.53-second `everywhere()` PID-discovery synchronization; C's PID lookup was
already satisfied by its 0.67-second staging synchronization. Removing the
diagnostic PID time gives 9.97 seconds for B versus 10.10 seconds for C. The
observed benefit is memory and transport, not demonstrated execution speed.

## What the next spike may consume

E1 may test mori only for the observed immutable substrate: bar views,
`bars_by_id`, `bars_mat`, runtime feature projection, availability data and
fact rows, and pulse axes. It must preserve the same candidate and identity
rows and compare against staged mirai, not merely against repeated full tasks.

Windows working-set sums can double-count shared pages, and private commit is
not PSS or unique resident memory. Sampling was about every 0.22 seconds. The
fixture is smaller than H1's Sharadar workload, so these are attribution and
growth inputs, not a production worker budget. Cleanup under interruption and
worker failure belongs to E1, as the macro plan specifies.

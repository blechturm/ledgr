# History worker payload attribution spike closeout

**Verdict:** GREEN for the charter's prerequisite question. Current mirai
tasks repeat a large candidate-invariant payload. Staging the exact invariant
fields once per persistent daemon reduced sampled memory without changing the
exercised result or identity surfaces. This selects neither mori nor a product
design.

## What ran

The exclusive Windows record used a vendor-neutral, availability-active
snapshot: 160 instruments, 208,797 bars, 1,305 open pulses, four candidates
and two workers. A was the sequential reference, B current mirai dispatch and
C staged mirai dispatch. Each fresh process first ran the same unmeasured
one-candidate sequential warm-up; warm-up times were 4.52, 4.58 and 4.62
seconds. The authoritative B task map was captured before submission and was
identical to the warmed A and C maps.

All twelve measured candidates finished `DONE`. Final equity, total return,
trade count, execution seed, snapshot and strategy hashes, and normalized
reproduction-key hash matched across arms. Warnings, retained output payloads,
event rows and full result objects were not parity-tested. The checker reran
and diffed the deterministic record. The gut removed `runtime_projection`;
the exact, field-order-preserving reconstruction assertion and result-identity
check rejected it.

## Payload map

Each current task serialized to 45,061,618 bytes; four tasks totaled
180,246,472 bytes. The invariant list was 44,959,221 bytes and all four
candidate-varying lists totaled 410,308 bytes. The two-worker staged formula
is `workers * shared_serialized_bytes + variant_serialized_sum`, or 90,328,750
bytes here. The 89,917,722-byte (49.9%) reduction is specific to this four-task,
two-worker shape and is a base-R XDR proxy, not mirai wire telemetry.

The largest invariant fields were `static_bars_views` (16.14 MB serialized),
`bars_by_id` (15.72 MB), `bars_mat` (10.86 MB) and `runtime_projection`
(1.80 MB). `static_bars_views` is derived from the bar matrix and pulse axis,
not immutable source substrate. E1 must compare omitting and rebuilding that
view against sharing it. Availability data, fact rows and pulse axes were
smaller on this fixture. The task-list `object.size()` was 228.5 MB but is not
additive because fields may share R objects.

## Time and memory

| Arm | Sweep wall | Parent peak WS | Daemon WS sum | Observed-tree WS | Tree private commit |
| --- | ---: | ---: | ---: | ---: | ---: |
| A sequential | 13.53 s | 530.3 MB | n/a | 530.3 MB | 544.3 MB |
| B current mirai | 10.18 s | 714.8 MB | 900.7 MB | 1,518.0 MB | 1,663.7 MB |
| C staged mirai | 10.14 s | 618.4 MB | 847.3 MB | 1,309.6 MB | 1,366.5 MB |

C's sampled observed-tree peaks were 208.4 MB (13.7%) lower by working-set
sum and 297.2 MB (17.9%) lower by private commit than B. Daemon sums were 5.9%
and 5.7% lower. At in-process phase points, B's parent private commit rose
398.8 MB from before to after submission; C rose 24.9 MB from after staging to
after submission. These phase deltas are measured process memory, not wire
bytes. Promise retention and result-transfer bytes were not measured:
`promise_handle_object_bytes` and `collected_result_object_bytes` are only
parent-side R `object.size()` values.

The three measured sweep walls are reported but support no speed claim. The
common warm-up removed the known cold-order confound; B and C were effectively
equal at this one shape. Sampling medians were about 0.220 seconds, maximum
gaps were 0.239 to 0.243 seconds and maximum in-sweep blackouts were 0.222 to
0.239 seconds.

## Boundary for E1

E1 may test mori only for the observed immutable task inputs: bar structures,
runtime feature projection, availability data and fact rows, and pulse axes.
It must separately test omission/rebuild of derived `static_bars_views`, keep
the same exercised parity rows, and compare with staged mirai rather than only
with repeated full tasks.

All sampled peaks are lower bounds. Working-set sums can double-count shared
pages, private commit is not unique RSS/PSS, the sampler observes only the
parent and PID-file daemons, and this fixture is smaller than H1's workload.
This single shape sets no growth claim or production worker budget. Cleanup
under interruption and worker failure remains E1's question.

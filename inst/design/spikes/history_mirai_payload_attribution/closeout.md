# History worker payload attribution spike closeout

**Verdict:** GREEN for the charter's prerequisite question. Current mirai
tasks repeat a large candidate-invariant payload. Staging the invariant fields
once per persistent daemon reduced sampled memory without changing the
exercised result or identity surfaces. This selects neither mori nor a product
design.

## What ran

The exclusive Windows record used a vendor-neutral, availability-active
snapshot: 160 instruments, 208,797 bars, 1,305 open pulses, four candidates
and two workers. Before any arm, a clean-process `pkgload::load_all(...,
compile = TRUE)` preflight built and loaded the current 3,655,686-byte DLL in
6.10 seconds. A was the sequential reference, B current mirai dispatch and C
staged mirai dispatch. Each fresh arm then ran the same unmeasured
one-candidate sequential warm-up (4.50 to 4.57 seconds). The authoritative B
task map was captured before submission and matched the warmed A and C maps.

All twelve measured candidates finished `DONE`. Final equity, total return,
trade count, execution seed, snapshot and strategy hashes, and normalized
reproduction-key hash matched. Warnings, retained outputs, event rows and full
result objects were not parity-tested. The C daemon hashed the exact serialized
task it constructed; all four matched the parent tasks after restoring field
order. The gut removed `runtime_projection`, named it as missing and failed the
reconstruction and result-identity checks.

## Payload map

Each current task serialized to 45,061,618 bytes; four tasks totaled
180,246,472 bytes. The invariant list was 44,959,221 bytes and all varying
lists totaled 410,308 bytes. The two-worker staged formula is `workers *
shared_serialized_bytes + variant_serialized_sum`, or 90,328,750 bytes here.
The 89,917,722-byte (49.9%) reduction is specific to this four-task,
two-worker shape and is a base-R XDR proxy, not mirai wire telemetry.

The largest invariant fields were `static_bars_views` (16.14 MB serialized),
`bars_by_id` (15.72 MB), `bars_mat` (10.86 MB) and `runtime_projection`
(1.80 MB). `bars_mat` is built from aligned bar columns and
`static_bars_views` from that matrix and the pulse axis (`backtest-runner.R`);
`pulses_iso` is formatted from `pulses_posix` (`availability-provider.R`). They
are derived immutable data, not source substrate. E1 must compare rebuilding
`bars_mat` and `static_bars_views` against sharing them; `pulses_iso` may be
rebuilt cheaply. The task-list `object.size()` was 228.5 MB but is not additive
because fields may share R objects.

## Time and memory

| Arm | Sweep wall | Sampled parent WS | In-process parent WS | Daemon WS sum | Observed-tree WS | Tree private commit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A sequential | 13.57 s | 528.9 MB | 460.8 MB | n/a | 528.9 MB | 542.6 MB |
| B current mirai | 10.12 s | 738.4 MB | 738.3 MB | 900.8 MB | 1,526.1 MB | 1,672.6 MB |
| C staged mirai | 11.09 s | 562.0 MB | 482.7 MB | 889.5 MB | 1,364.8 MB | 1,421.8 MB |

C's sampled observed-tree peaks were 161.3 MB (10.6%) lower by working-set
sum and 250.8 MB (15.0%) lower by private commit than B. Daemon sums differed
by only 1.3% and 1.2%; most observed relief was in the parent. Sampled parent
working set was 176.4 MB lower. In-process parent working-set peaks were 738.3
MB for B and 482.7 MB for C, but those phase points do not continuously sample
the interval and are not substitutes for the external lower-bound peaks.

B's private commit rose 403.0 MB from immediately before to after task
submission. C rose 41.7 MB while staging and another 10.6 MB while submitting.
From C's before-sweep point through after-submit it rose 25.0 MB because a
collection between those boundaries released memory; all three boundaries are
reported rather than treating one delta as allocation volume. C's boundary
therefore includes the staging cost.

The wall numbers support no speed claim. C includes its 0.21-second stage plus
daemon-side exact-byte instrumentation and took 11.09 seconds versus B's
10.12. Promise retention and result-transfer bytes were not measured:
`promise_handle_object_bytes` and `collected_result_object_bytes` are only
parent-side R `object.size()` values. Measuring both is assigned to E1.

Sampling medians were about 0.220 seconds and maximum all-process gaps 0.224
to 0.240 seconds. Maximum in-sweep blackouts were 0.222 to 0.240 seconds.
Daemon-specific maximum blackouts were 1.82 seconds for B and 1.72 seconds for
C, including daemon discovery; C's PID file was written before staging, so the
staging transfer is inside its daemon-sampling interval.

## Boundary for E1

E1 may test mori only for the observed immutable task inputs. It must test
omit/rebuild versus sharing for derived bar structures, retain the exercised
parity rows, measure promise retention and result-transfer bytes, and compare
with staged mirai rather than only repeated full tasks.

All sampled peaks are lower bounds. Working-set sums can double-count shared
pages, private commit is not unique RSS/PSS, the sampler observes only the
parent and PID-file daemons, and this fixture is smaller than H1's workload.
This one shape sets no growth claim or worker budget. Cleanup under
interruption and worker failure remains E1's question.

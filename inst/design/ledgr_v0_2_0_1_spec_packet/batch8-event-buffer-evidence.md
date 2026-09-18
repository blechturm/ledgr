# v0.2.0.1 Batch 8 Linear Event-Buffer Evidence

Status: Review pending.

Tickets: LDG-2736, LDG-2737, and LDG-2738.
Implementation base: `0e214f0862bd60dd0820877f6f332343e36b8a5d`.

## Production route

Both output handlers now write event fields through one private helper over
buffer-owned typed storage. The helper uses `collapse::setv()` for character,
list, timestamp, integer, and numeric columns. List writes use the explicit
one-dimensional list-vector route. The memory handler uses the helper for
scalar rows, copied rows, compiled batches, metadata, and capacity growth. The
durable handler uses it for scalar rows and capacity growth.

The existing geometric-growth helper remains the sole capacity policy. Each
handler accepts a private initial-capacity injection for boundary tests; no
public argument or configuration surface changed. Active row counts advance
only after every field of a row has been written, so a failed write cannot
make a partial row visible. The private write helper rejects any column
container that is not an environment, preserving the ownership condition its
by-reference writes require.

`DESCRIPTION` now declares `collapse (>= 2.1.8)`. There is no 2.1.7 branch,
runtime version switch, option, environment selector, arm stamp, or fallback.

## Implementation-choice record

The ignored local evidence prefix is:

`dev/bench/results/v0_2_0_1_batch8_event_buffer_20260917T150012Z/`

It contains 40 result rows plus the derived summary and environment record:

| File | SHA-256 |
| --- | --- |
| `runs.csv` | `63c20a4daddcb99b7c8e5e43bb7b8ab56bef183f3d5e85996c2da27b7a2b7f27` |
| `summary.csv` | `f440d6c81dffd6e01832d698626142321272a97b4b04b357c3655d63e57fd1df` |
| `environment.csv` | `0c96553cc1eddcd0bdf51472cdbe916e995a5b53f01ff67d0a2f01d0eb037b4a` |

The run used R 4.6.1 on Windows, collapse 2.1.8, seed 20260530, SMA 5/10,
zero costs, 1,260 sessions, stable instrument subsets, and the registered
shared-bars artifact whose SHA-256 is
`0b183457b3fe720d63b02a90fe552e1202fdb31b4e967a75e91304f9d3e416fc`.
Runs were serial, and peak working set was sampled externally every 200 ms.

The `current` arm reproduced the extract/mutate/reassign source at the
implementation base. The `control` arm temporarily removed one buffer binding,
used `collapse::setv()`, and restored the binding. Both existed only in a
temporary harness under `C:/tmp`; neither is installed or retained in the
repository. The `direct` arm is the production candidate.

At 500 instruments, each handler ran one warm-up and three interleaved measured
repetitions:

| Handler | Arm | Measured engine seconds | Median | Direct / comparison |
| --- | --- | --- | ---: | ---: |
| memory | current | 145.43, 136.89, 146.23 | 145.43 | 0.200 |
| memory | direct | 29.28, 28.61, 29.12 | 29.12 | - |
| memory | control | 30.41, 30.59, 30.89 | 30.59 | 0.952 |
| durable | current | 144.39, 147.60, 143.12 | 144.39 | 0.355 |
| durable | direct | 50.40, 55.31, 51.31 | 51.31 | - |
| durable | control | 49.65, 52.06, 50.86 | 50.86 | 1.009 |

The route gate requires direct/control at or below 1.20 for each handler. Both
pass. Direct writes reduce median engine time by 80.0 percent in memory mode
and 64.5 percent in durable mode relative to the reproduced old writer.

All measured arms produced 68,201 fills, the same final equity, one common
fills hash, and one common equity hash within each handler. Serialized hashes
are handler-specific because the durable and memory result frames retain
different boundary representations; their shared contracted surfaces are
covered by the focused memory/durable parity tests.

## Scaling and memory gates

The smaller points are one diagnostic run per arm. The 500-instrument values
are the measured medians.

| Handler | Instruments | Fills | Current seconds | Direct seconds |
| --- | ---: | ---: | ---: | ---: |
| memory | 50 | 6,961 | 5.96 | 4.30 |
| memory | 100 | 13,690 | 12.24 | 6.86 |
| memory | 200 | 27,415 | 30.84 | 11.83 |
| memory | 350 | 47,872 | 77.31 | 20.61 |
| memory | 500 | 68,201 | 145.43 | 29.12 |
| durable | 50 | 6,961 | 9.18 | 7.82 |
| durable | 100 | 13,690 | 16.11 | 11.71 |
| durable | 200 | 27,415 | 37.97 | 20.15 |
| durable | 350 | 47,872 | 83.78 | 36.12 |
| durable | 500 | 68,201 | 144.39 | 51.31 |

At 500 instruments, direct/current is 0.200 for memory and 0.355 for durable,
both below the 0.60 limit. Direct microseconds per fill at 500 are 426.97 and
752.34. Their ratios to the minimum observed over 100, 200, 350, and 500 are
1.000 and 1.024, both below the 1.35 limit.

The maximum measured direct working set is 757.25 MiB for memory and
1,000.17 MiB for durable. Those are 0.808 and 0.832 of the paired current-arm
maxima, below the 1.15 limit. Every scaling point reconciles fill count and
final equity between current and direct. The harness concluded with
`BATCH8_EVENT_BUFFER_GATES_OK` only after all route, scaling, parity, and
memory predicates evaluated true.

## Semantic and failure matrix

The focused regression net exercises the production handlers rather than a
benchmark-only implementation:

| Requirement | Durable witness |
| --- | --- |
| complete ordered event schema, parsed metadata, repeated allocation, ordinary and forced GC | `test-ledger-writer.R` |
| private capacity 2, with writes before, at, and after two growth boundaries in both handlers | `test-ledger-writer.R` |
| injected write failure exposes no active partial row and exact retry succeeds | `test-ledger-writer.R` |
| fills, trades, cash, positions, equity, state, completion, diagnostics, and telemetry | `test-accounting-consistency.R`, `test-backtest-wrapper.R`, `test-runner.R`, `test-sweep.R` |
| opens, closes, reversals, repeated same-side and no-op targets, final-bar no-fill, fees, and slippage | `test-accounting-consistency.R`, `test-cost-model.R`, `test-backtest-wrapper.R`, `test-sweep.R` |
| controlled stop, unexpected error, interruption, resume to DONE, resume then error, and reopen | `test-backtest-lifecycle.R`, `test-run-store.R`, `test-experiment-run.R`, `test-availability-economics.R`, `test-availability-finalization-prefix.R` |
| memory/durable common surfaces and persisted round trips | `test-sweep-persistence-api.R`, `test-sweep-persistence-parity.R`, `test-sweep-persistence-roundtrip.R` |

Those 14 focused files passed under R 4.6.1 and collapse 2.1.8 in 226.7
seconds with zero failures, errors, warnings, or skips.

The dependency-floor test constructs an isolated fake collapse 2.1.7 package,
parses the declared Imports floor, resolves the fake package with
`packageVersion()`, and verifies that the resolved version is below that floor
without relying on an undocumented base R internal.
The original implementation evidence separately checked the machine's actual
Documents-library collapse 2.1.7 through package dependency resolution; it
resolved `required_but_obsolete = "collapse"` and ended
`ACTUAL_UNDER_FLOOR_REJECTED`. That historical corroboration remains recorded,
but the durable regression test now uses only the public version interface.
The source guard requires the declared floor and the single direct helper, and
rejects the former scalar and bulk extract/mutate/reassign shapes, temporary
unbind calls, arm selectors, routes, and fallbacks in the production handlers.

The post-review correction also promotes the character and list buffers with
three full garbage collections before their first write, and the injected
growth test now compares all five memory-handler attributes: cash delta,
position delta, parsed metadata, realized P&L, and cost basis.

Post-review verification reran `test-ledger-writer.R` and
`test-documentation-contracts.R` under R 4.6.1 with collapse 2.1.8. Both
completed with zero failures, errors, warnings, or skips.

## Harness correction and containment

The first full launch formed a nonexistent Windows `x64/x64/Rscript.exe` path
and recorded no row. A second launch recorded eight valid current/direct
scaling rows and their warm-ups, then exposed that the temporary control used
base replacement rather than the accepted unbind/setv/rebind operation. The
driver was stopped before measured repetitions, its one invalid control
warm-up was removed, and a three-arm smoke proved exact parity after the
control correction. The final run resumed the valid rows and generated every
control result and every measured repetition with the corrected control.
There was no concurrent R process during the record.

The raw prefix is ignored local measurement evidence; this tracked record and
its file hashes bind it. The old oracle remains reconstructible from the named
base commit. The implementation commit will follow this prefix and cite this
record. No oracle, control, benchmark selector, or temporary harness is part of
installed source.

Batch 8 stops here for independent review. It makes no final-release or peer
benchmark claim; Batch 10 reruns the release records from accepted final
source.

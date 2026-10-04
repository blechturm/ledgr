# Durable-run preparation memory record

This maintained LDG-2951 runner measures one public availability-aware
`ledgr_run()` shape: 1,514 sessions, 600 physical instruments, 500 members and
three returns features read by a monthly top-10 momentum strategy. It records
feature persistence both off and on. A dense public run of the same bars is an
exactness witness, not a memory gate.

The peak-child-RSS and elapsed gates use unmarked fresh child processes. Phase
attribution uses separate paired marked runs; those markers call `gc()` and
therefore never supply a gate clock. The two persistence variants independently
require a median candidate/baseline peak-RSS ratio at most 0.90 and elapsed
ratio at most 1.05 over at least five alternating pairs. A miss receives one
complete fresh retry at the same pair count and stands only when the retry also
misses.

The checker compares completion and normalized public equity, fills, trades,
diagnostics, decoded strategy state, persisted features and availability
surfaces. It also compares the dense witness and proves that changing a
normalized output is detected.

`LEDGR_BENCH_LIB` may name an isolated dependency library. The runner prepends
it inside every controller and child process and records the resolved package
versions; leaving it unset uses the ordinary R library resolution.

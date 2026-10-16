# WS41 aggregate-only segment census

This early Workstream 41 record uses only the checked-in aggregate WS39 lake
record. It reads no private row, identifier or path and does not open the
schema-120 store from the current schema-121 package tree.

Reproduce from the repository root with:

```text
Rscript dev/bench/v0_2_2_history_substrate/aggregate_segment_census.R .
```

The 580 complete membership sets each contribute one header fact to every one
of 1,166 instruments. Together with 290,811 member assertions this gives
967,091 prepared membership facts. The complete-set compiler emits at most one
segment per header plus the initial unknown segment for each instrument:
677,446 segments in aggregate and a per-instrument ratio bounded by
581 / 580 = 1.001724138. The default `max(4 * facts, 16)` guard therefore
passes by construction. The lake declares no trading-status rows; its one
default segment per instrument also passes exactly.

The 829 aggregate lifetime rows do not disclose their distribution by
instrument, their clocks or how many carry terminal labels. Those aggregates
cannot establish lifetime or lifetime-terminal segment counts without
inventing private-row facts, so this early record says `needs_full_census`
rather than claiming a pass. LTB-0291 exercises the exact per-instrument
census and refusal on synthetic two-clock data. LDG-3070 still owns the
required full current-format Sharadar census, including aggregate and maximum
lifetime and terminal counts, before Cut 16 closes.

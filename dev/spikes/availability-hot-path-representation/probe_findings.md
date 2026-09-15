# Availability Hot-Path Representation Probe Findings

**Date:** 2026-09-14

**Outcome:** GREEN for the prerequisite; RED for the current diagnostic representation at scale.

## Question Run

Does `collapse` 2.1.8 preserve character and list values under the long-running
`setv()` write shape that failed in ledgr under 2.1.7, and does ledgr's current
availability diagnostic representation reproduce the previously retired
per-row-data-frame scaling mechanism?

## Environment

- ledgr source: `cb3047b8b45c64e34589b58ef2e8bfb33f5b2cc2`
- R: 4.5.2
- Platform: `x86_64-w64-mingw32`
- collapse: 2.1.8, compiled from CRAN source under this R installation
- Runner: `dev/spikes/availability-hot-path-representation/probe.R`

## What Ran

The prerequisite test performed 70,000 by-reference writes into preallocated
character and list vectors. Replacement values were allocated inside the loop,
and garbage collection was forced repeatedly. Both buffers were compared with
base-R reference buffers using `identical()`.

The ledgr test called the production
`ledgr_availability_diagnostic_row()` constructor for 5,000, 10,000, and 20,000
synthetic decision rows, retained the rows as the production fold does, and
combined them with the production `do.call(rbind, ...)` expression. It compared
that result with one column-oriented data-frame construction using exact type,
value, order, and attribute parity.

## Results

- collapse character parity: `TRUE`
- collapse list parity: `TRUE`
- 70,000-write collapse test: 0.89 seconds

| Rows | Current construct | Current bind | Current list | Column build | Column frame | Exact parity |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 5,000 | 3.14 s | 1.82 s | 27.08 MiB | 0.02 s | 0.81 MiB | TRUE |
| 10,000 | 5.98 s | 5.94 s | 54.17 MiB | <0.01 s | 1.60 MiB | TRUE |
| 20,000 | 11.61 s | 20.04 s | 108.34 MiB | <0.01 s | 3.16 MiB | TRUE |

The 2.1.7 character/list failure did not reproduce. collapse 2.1.8's release
notes identify and fix the missing generational write barrier in `setv()` and
`copyv()` for `STRSXP` and `VECSXP` vectors (issue 876). No new upstream issue
is warranted from this run.

The current availability path does reproduce the retired ledgr mechanism:
one data frame per evidence row, retained in a scale-growing list, followed by
`do.call(rbind, ...)`. Binding cost grows faster than row count over this small
ladder, and the retained object graph is much larger than the final table. The
single column-oriented alternative produced an exactly identical result.

## What The Seed May Consume

- Treat collapse 2.1.8 character/list `setv()` as eligible for a production
  spike, not as proven for every ledgr buffer shape.
- Treat the current diagnostic representation as a confirmed mechanism worth
  a bounded production-path spike.
- Preserve every diagnostic row and the public/persistent schemas; this probe
  supports a representation change, not evidence deletion.
- Compare only the current implementation with one columnar/chunked
  alternative in the next spike.

## Still Open

This probe did not run a complete production-sized availability fold, select a
chunk size, prove DuckDB persistence parity, or optimize membership, lifetime,
status, valuation, context, or compiled execution. Those questions must not be
smuggled into the first spike.

Source for the upstream fix:
<https://fastverse.org/collapse/news/index.html#collapse-218>

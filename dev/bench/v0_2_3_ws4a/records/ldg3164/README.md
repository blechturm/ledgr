# LDG-3164 candidate verification

The maintainer ran this verification on 2026-10-30 and 2026-10-31. Product
candidate df1b3b62; a6b3643e changes only memory.R; this record was
committed in ad8ed703 and bee6c028. Base 953338df. Its results describe
df1b3b62 only; the correction round below changed the product. Library:
E:/ledgr-data/r-lib/ledgr-ws4a-df1b3b62. The script is
`verify_3164.sh` in the session scratchpad; its commands appear below.

`sequence.log` records the exit code of each step in order. Two lines were
appended to it later:

- The first memory run (exit 1) stopped before measuring, because the
  prepared folder was missing on a fresh scratch directory. a6b3643e fixed
  this, and the second run produced `memory/`.
- `memory exit 1 23:47:32`: memory.R exits 1 because its validation flags
  the candidate's own deep-forward cell as unstable (spread 11.75%). It is
  not a gate result; the gate comparison is in the memory table below.

| Step | Command | Outcome |
| --- | --- | --- |
| cases | `check.R --base=HEAD` | PASS, 23 cases identical |
| guts | `guts.R --base=HEAD --guts=C3_tolerance_x10,C4_lifo,C5a_reorder_carried_openings,C5b_kahan_on_openings,C6_leave_one_live_lot,C9_drop_comp_in_unpack,C14a_book_by_reference,M3_drop_lot_fee,M5_positions_plus_delta,M7_drop_partial_remainder,M11_uncompensated_totals` | 11 of 11 fail their case; the invalid-base control is refused |
| dense | `peer_benchmark/dense/check.R` | PASS, nine native arms identical |
| A0 | `cut3_successors/a0/record.R` and `compare.R` | PASS, 295 checks, 0 fail (`a0-compare.csv`) |
| suite | `testthat::test_local(stop_on_failure=TRUE)` | exit 0. Includes test-ws4a-carrier.R, which holds the LDG-3164 detectors, validators and controls (design note Section 8) |
| real data | `v0_2_2-reference/compare.R` against `E:/ledgr-data/reference/v0.2.3-base-953338df` | all six workloads COMPARE_IDENTICAL (`realdata.txt`, comparison names only) |
| memory | `memory.R --lib=<candidate>` | `memory/`; see the table below |
| timing | shared harness, protocol ws4a-timing-1 | `dev/bench/timing/records/ws4a-timing-1/ldg3164-gate/attempt-1` |

detectors.R certifies base outcomes only (design note Section 8). It binds the
deleted named-list functions, so it does not run against the candidate.

## Gates of decisions (6) and (8)

The memory metric is peak R heap. Base medians come from
`records/memory/validation.csv`. The budget is 1.10 x base.

| Cell | Candidate | Base | Ratio | Gated at |
| --- | --- | --- | --- | --- |
| wide replay | 237.87 MB | 258.09 MB | 0.92 | LDG-3164, pass |
| deep replay | 281.70 MB | 321.36 MB | 0.88 | LDG-3164, pass |
| wide forward | 399.03 MB | 399.09 MB | 1.00 | LDG-3169 |
| deep forward | 481.69 MB, unstable | 426.12 MB | 1.13 | LDG-3169 |

Timing, as the median candidate/base ratio:

| Cells | Ratio | Gated at |
| --- | --- | --- |
| read_fills / read_trades / read_equity | 0.408 / 0.405 / 0.987 | LDG-3164, pass |
| no-fill cells | at most 1.03 | LDG-3164, pass |
| `dense_wide_run` / `avail_wide_run` | 1.32 / 1.26 | LDG-3169 |
| `dense_wide_sweep` / `avail_wide_sweep` | 1.56 / 1.28 | LDG-3169 |
| sparse cells | 1.016-1.059 | LDG-3169 |
| `avail_wide_marginal` | 1.405 (279 us candidate, 199 us base) | LDG-3169 |

Decision (6) is settled on blocks. Replay applies consecutive conflict-free
blocks, and the gated replay cells pass on both timing and memory.

The fold cells regressed while P4 makes one typed call per fill, which is
allowed until LDG-3167. Rprofmem bytes per fill also rose: dense 70,311
(base 46,609) and availability 131,673 (base 108,349). These cells gate at
LDG-3169.

## Correction round 1 (close review F1-F7)

Product commit 03aed8b7 answers `ws12_close_review.md` F1-F4; the harness,
design note and evidence follow in the next commit. Verified by the
implementer on 2026-10-31 against 03aed8b7, with no timing, memory or
real-data runs (the maintainer reruns those):

| Step | Command | Outcome |
| --- | --- | --- |
| cases | `check.R --base=HEAD` | PASS, 23 cases identical, with the C14 native serialize witness (F5) |
| guts | `guts.R --base=HEAD` over the eleven guts above plus `M11_cumsum_total_basis` and `C14a_rename_by_reference` | 13 of 13 fail their case; the invalid-base control is refused |
| dense | `peer_benchmark/dense/check.R` | PASS, nine native arms identical |
| A0 | `cut3_successors/a0/record.R` and `compare.R` | PASS, 295 checks, 0 fail |
| tests | test-ws4a-carrier.R and 17 lot, replay, accounting, disposition, walk-forward and terminal files | all pass |

M11 is now registered to `M11_cumsum_total_basis` (the total basis as one
`cumsum()`), which fails C3 (`book_totals`, equity); C5b does not detect
it. `M11_uncompensated_totals` stays as a gut. `records/mutations.csv` and
`records/gut_results.csv` are the LDG-3163 base records and were not
rewritten. `C14a_rename_by_reference` names a retained typed column by
reference, which the base-shaped view hides; only the native witness fails.

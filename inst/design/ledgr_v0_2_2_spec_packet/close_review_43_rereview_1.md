# WS43 focused re-review 1 (Type 1), `83032e5e..bfffb0f7`

## Verdict: CHANGES_REQUIRED

Correction 1 closes F1, F4, F6 and F7 as claimed, routes F5 to LDG-3070 as
instructed, and implements F2 and decision (19) as described for the
fixtures it registers. The frame evidence now reports every v12 Sections 5-6
state, matches the per-instrument reader cell for cell on every edge case
probed except late-known facts (by design, R4), reads by binary search
without recomputation, and stays identical across sequential and two-worker
sweeps. Retained planes and full-panel reads scale linearly.

Two defects remain. Decision (20) is implemented on WS41's sticky terminal
plane, which changes only once per instrument, so a second delisting and
relisting still lets bounded windows mix prices across the terminal interval
(R1). The `used_before_window` line that the correction changed still
under-reports carried history, and reverting it fails no block (R2). Two
lower findings cover remaining id-collision paths under decision (19) (R3)
and detector or record gaps (R4). None asks to reopen a Cut 16 decision, so
this is not NEEDS_TYPE_2.

Method:
- Read `close_review_43.md`, the Correction 1 section of
  `indicator_history_closeout.md`, Cut 16 decisions (15), (19) and (20),
  LDG-3065..3067 and LDG-3070, v12 Sections 5-6, the optimization style
  manual's seven shapes, and `git diff 83032e5e..bfffb0f7` in full for `R/`,
  the four test files, `tests/claims.yml`, the contract, NEWS, the
  `indicators` vignette and the WS42 closeout route.
- Probes on a source copy (`agree.R`, `dispatch.R`, `used_before.R`,
  `used_before_input.R`, the first review's `evidence_probe.R`): frame
  evidence against `ledgr_history_feature_planes()` at several cutoffs on 23
  cases (warm-up after a restart, output-carry expiry, a return with
  carried input, cells outside the calculation, MACD signal and BBands up,
  a relisting, a relisting followed by a gap, a relisting on the last
  session, a delisting without relisting, two delisting cycles, a
  nonterminal inactive interval and a late-known lifetime fact), plus
  decision (19) collisions, the slice-off-axis refusal and
  `used_before_window`.
- 13 own source-copy mutations, each restored (table below); the agent's
  CSV was not used.
- `planes_scale.R` at four small and medium shapes (disclosure only).
- Full suite, `tools/check-codebase-contracts.R --mode=check` and
  `tools/check-fold-phase-contract.R` on the source copy (results below).
  `git diff --check` is clean and every changed file is ASCII.

## Findings

### R1 (medium): decision (20) holds only for an instrument's first terminal interval

`R/history-features.R:341-348`. Runs break where `inputs$terminal` changes
along the calculation rows. That plane comes from
`ledgr_history_substrate_terminal_at()` (`R/history-substrate.R:1695-1731`),
which is TRUE from the first terminal column onward and never changes again.
A second delisting therefore produces no break, and bounded windows span it.

Evidence (`agree.R`, case B5, one instrument, 20 sessions): two
known-inactive intervals with `terminal_event = "delisting"` at sessions 5-6
and 12-13, relistings at 7 and 14. The terminal plane is
`0 0 0 0 1 1 ... 1`. SMA(3) restarts after the first relisting (NA at 7-8),
but at session 14 it reads 21.67 = mean(20, 21, 24), averaging sessions 10
and 11 (before the second delisting) with session 14 (after the relisting).
That is the mixture decision (20) forbids. TTR EMA(3) restarts at both
relistings, because history-dependent rows already split at the inactive
columns. `ledgr_history_feature_planes()` uses the same sticky equality for
its carried-input windows (`R/history-features.R:822-826`), so the two
readers agree on the wrong answer and LTB-0319 cannot see it. LTB-0320
covers one cycle only. LCL-0312, the Strict Features contract ("restarts on
WS41's sticky terminal barrier plane"), NEWS and the `indicators` vignette
all state the rule without the one-interval limit.

Single-cycle cases are correct: a relisting (SMA NA for `requires_bars - 1`
sessions), a relisting followed by a gap (restart after the gap), a relisting
on the last session (`not_ready`), and a delisting without relisting (no
carry or output carry across the interval).

Fix: break on each terminal interval, not on the sticky plane. For example,
return the per-column terminal assertion (`asserted` in
`ledgr_history_substrate_terminal_at()`) beside the sticky barrier, and start
a new run at each expected row that follows an asserted column. The barrier
rule is unchanged: this only reads the existing fact plane. Apply the same
rule in the seam, and add a two-cycle case to LTB-0320.

### R2 (medium): `used_before_window` still under-reports carried history, and the changed line is undetected

`R/history-frame.R:712-719`. The correction counts output-carried cells, but
still decides "used before the window" by the column width rule alone. The
contract (`contracts.md:1734-1736`) says the flag records "whether any
returned value used an observation or calculation state before the returned
window".

Evidence (`used_before.R`, `used_before_input.R`; WS42 fixture, a bounded
width-1 custom close level, `lookback = 1`):
- output carry 2, no price carry: at 2021-01-06 BBB's value is
  output-carried from 2021-01-05 (age 1, source before the one-session
  window), and `used_before_window` is FALSE;
- default price carry: at 2021-01-06 BBB's input is carried from
  2021-01-05, and `used_before_window` is FALSE.

By reading (not probed), a bounded window that spans a lifetime-inactive
interval under decision (15) also reaches back further than `width` columns,
and the rule misses it.

Mutation RR11 reverts the changed line to `calculation_valid` alone. No
block fails in the broad filter (indicator, history, strict, feature,
backtest, runner, sweep, precompute, pulse and acceptance files). The
closeout does not mention the change.

Fix: for feature cells, also return TRUE when a kept output-carried cell's
`source_ts_utc` is before the window start. For input-carried cells and
bounded windows that span inactive columns, derive the earliest dependency
from the retained segment start (or the expected-session count) rather than
from `columns - width + 1`. Register a block with the two probe cases above.
Record the behavior change in the closeout.

### R3 (low): decision (19) leaves id-collision paths

`R/backtest-runner.R:1607-1650`.
- The legacy `sma_n` config branch (line 1643) has no `shadowed()` check.
  `ledgr_indicator("sma_n", function(window) 42, requires_bars = 3L,
  params = list(n = 3L))` runs as built-in SMA(3) under id `sma_3`, with the
  custom fingerprint attached, in both modes. A strategy that reads `sma_n`
  gets `Unknown feature name`; one that reads `sma_3` gets built-in values
  (`dispatch.R`). No test or production caller uses the `sma_n` id.
- `shadowed()` requires a registry entry. A stored fingerprint that differs
  from the built-in, with no registry entry, falls back to the built-in `fn`
  and keeps the custom fingerprint (`dispatch.R`: built-in `fn` TRUE,
  custom fingerprint TRUE). Inference: unreachable today, because config
  construction registers every indicator just before the fold reads it.
- `.onLoad` pre-registers `return_1`, `sma_50` and `sma_200`
  (`R/ledgr-package.R:71-78`). In a default session a custom `return_1`
  therefore refuses at experiment construction (`ledgr_invalid_args`,
  "already registered with different logic") instead of running its own
  function. This is not silent, but `?ledgr_indicator`, NEWS, the Strict
  Features contract and LCL-0313 say a custom `return_1` "runs its own
  function". LTB-0321 deletes the registry entries before each run, so the
  default-session path is never exercised.

Fix: delete the `sma_n` branch (pre-CRAN, no compatibility), or give it the
`shadowed()` test. Make a fingerprint that differs from the built-in refuse
when no registered indicator matches. Qualify the doc sentence ("after
replacing the pre-registered entry with `overwrite = TRUE`"), or add a
default-session refusal assertion to LTB-0321.

### R4 (low, detector and record gaps)

- RR8: probing the last instrument with calculated cells passes LTB-0316,
  because the two-instrument panel puts the most-calculated instrument last.
  Put it in the middle of three instruments.
- RR12: removing the seam's decision (20) window rule for carried-input
  counts (`R/history-features.R:822-826`) fails no block. LTB-0319 compares
  the two readers on no terminal case, and LTB-0320 asserts no seam count.
- "Both readers agree cell for cell" (closeout F2 item, LCL-0311 scope)
  holds only when no lifetime or terminal fact is learned after the column
  it changes. In `agree.R` case K (an inactive interval at sessions 8-9
  learned at 13), the frame at cutoff 13 keeps each pulse's earlier answer:
  EMA(3) at sessions 10-11 is `ready`, valid, reason `""`, value 48.50 and
  34.25. The seam recomputes at that cutoff and reports `not_ready`. SMA
  values differ the same way (72.33 against 16.67 at session 10). This
  follows the accepted LTB-0313 rule. Scope the claim and the closeout
  sentence to facts known at their column.

## Item results

| Item | Result |
| --- | --- |
| F1 data-start sentence | PASS; `contracts.md` now says "from the data start through each window's scoring end" with the link |
| F2 frame states | PASS on fixtures: all seven reasons, admission, readiness and validity match the seam at every cutoff in 21 of 23 cases (the two late-known cases are R4); nothing recomputed per read (`findInterval` over retained keys); two-worker sweep evidence identical; slice off its axis drops the planes and the read refuses with `ledgr_invalid_history_substrate`; production slices only on the validated identical axis (`R/sweep.R:331-343`); late-known facts R4 |
| F3 / decision (19) | PASS for `sma_<n>` and `return_1` with a cleared registry (LTB-0321, RR10 detected); residual paths R3 |
| F4 terminal carry barrier | PASS (LTB-0320; RR6 detected) |
| Decision (20) | first terminal interval PASS (RR7 detected); later intervals R1 |
| F5 routed | PASS: the factor is stated in the seven-shape walk, and the LDG-3070 scope asks for the per-instrument distribution of lagged facts |
| F6 detectors | PASS for probe-first, probe-every and all-price-field input carry (RR9 detected); probe-last R4 |
| F7 record | PASS: aroon dense change and extra warm-up row in NEWS and the contract, the return-family sentence qualified, stale closeout lines corrected, LDG-3067 evidence names the commits |
| Docs and claims | LCL-0311..0313 and LTB-0319..0321 are inside the reserved ranges, one block each, with no duplicate (307 claims); `?ledgr_indicator`, NEWS, contract and vignette match behavior apart from R1 and R3 |

## Mutations (source copy, each restored)

| ID | Mutation | Result |
| --- | --- | --- |
| RR1 | retained `segment_ready` = segment start | LTB-0318, LTB-0319, LTB-0320 fail |
| RR2 | frame `calculated` back to finite and not output-carried | LTB-0318, LTB-0319, LTB-0320 fail |
| RR3 | excluded code 2 without the carried-input test | LTB-0319 fails |
| RR4 | expired code 3 not retained | LTB-0319 fails |
| RR5 | frame ignores the calculation bounds | LTB-0319 fails |
| RR6 | feature input carry ignores the terminal barrier | LTB-0320 fails |
| RR7 | no terminal break in runs (decision 20) | LTB-0320 fails |
| RR8 | probe the last instrument with calculated cells | no block fails (R4) |
| RR9 | input-carry exceptions from any price field | LTB-0319 fails |
| RR10 | `shadowed()` ignores the fingerprint | LTB-0321 fails |
| RR11 | `used_before_window` ignores output carry (revert) | no block fails, broad filter (R2) |
| RR12 | seam carried-count windows span terminal intervals | no block fails, broad filter (R4) |
| RR13 | seam valid cells lose own source time and age | LTB-0319 fails |

## Changed oracles

- LTB-0318: `calculated` becomes admission, `ready` first-valid and
  `calculation_valid` a ready finite value. BBB's return at sessions 1 and 5
  is admitted and not ready: warm-up, then re-warming after the raw
  session-4 gap that a return never carries. The carry planes the block was
  written for are unchanged. Valid, for the F2 reason.
- LTB-0144 and LTB-0276: only the availability engine digest changes
  (`283ce161...`), because the hashed `compute`, `calculate` and `runs`
  helpers changed. The dense literals are unchanged. Valid.
- LTB-0316: extended, not weakened. The earlier assertions are unchanged.

## Cost and shape

- The changed preparation code is vectorized per instrument, range and
  definition: one `match`, run-length encoding and segment vectors. The
  per-field append loop runs over at most ten fields. The frame read is
  `findInterval` over sorted keys, and projection indexing is one radix
  `order` per set. No new loop grows with bars, pulses or cells.
- `planes_scale.R` (realistic panel, 14 definitions, single runs, disclosure
  only):

  | Shape | Prep s | Segments | Reason runs | Planes MB | Values MB | Full read s |
  | --- | ---: | ---: | ---: | ---: | ---: | ---: |
  | 150 x 500 | 2.74 | 5,521 | 4,921 | 0.30 | 8.74 | 0.20 |
  | 150 x 1,000 | 4.04 | 8,540 | 8,673 | 0.49 | 17.33 | 0.42 |
  | 150 x 2,000 | 6.77 | 14,975 | 16,849 | 0.90 | 34.53 | 0.91 |
  | 300 x 1,000 | 7.39 | 17,237 | 17,682 | 0.96 | 33.48 | 0.79 |

  Planes stay at about 3 percent of values and grow linearly in both
  dimensions, as does the full-panel read. This agrees with the agent's
  24.1 MB (2.7 percent) at 1,166 x 7,213. The agent's own records show that
  full-panel read rose from 9.2 to 24.7 seconds and preparation from 154.8
  to 163.3 seconds (single runs). Both are disclosed and are not findings.

## Suite and checkers

- Full suite on the source copy after `load_all()`: 1,139 blocks, 0
  failures, 0 errors, one optional skip (Yahoo missing-package path), 705 s.
  No `_problems` artifacts. The test-control-plane block validates the
  claims registry.
- `tools/check-codebase-contracts.R --mode=check`:
  `LEDGR_CODEBASE_CENSUS_OK` (helpers 1,804). The correction adds no
  `availability_active` or other execution-mode branch: the diff of `R/`
  touches no mode test. Decision (20) reads WS41's terminal plane, and dense
  is untouched (the dense engine literal is unchanged).
- `tools/check-fold-phase-contract.R .`: `LEDGR_FOLD_PHASE_CONTRACT_OK`.

## Maintainer note (not a finding)

A cell that is admitted and ready but whose calculation returns a non-finite
value has `calculation_valid = FALSE` and an empty `missing_reason` in both
readers. v12 Section 5 lists errors among the states that are never
fillable, but it does not name a reason for them. Whether to add one
(for example `calculation_missing`) is the maintainer's call.

## Review ratio

Four findings (R1-R4) over nine re-reviewed items (F1-F7 and decisions (19)
and (20)): 4/9 = 0.444. This is correction round 1.

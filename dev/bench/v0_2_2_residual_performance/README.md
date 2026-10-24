# v0.2.2 Residual Performance Evidence

This directory holds the bounded Cut 18 performance records. It is internal
release evidence, not a public benchmark or a speed claim against another
engine.

## Workstream 51: release-gate headroom

Implementation commit `2bad5e33` repairs the LTB-0393 `gc()` tracer, reduces
repeated work in the source-derived codebase scan, and splits two expensive
public integration claims without weakening either claim. The cheap boundary
detector remains in `fast`; the end-to-end public witness remains in `review`.

| Claim | Fast detector | Review integration |
| --- | --- | --- |
| ordered and contiguous carried test windows | LCL-0204 / LTB-0204 | LCL-0471 / LTB-0481 |
| assumed corporate-action knowledge | LCL-0444 / LTB-0454 | LCL-0472 / LTB-0482 |

LTB-0483 derives these profiles from `claims.yml` and the two owning source
files. Removing or changing either representative makes the map fail.

The profile changes have narrow reasons:

- LTB-0204 now exercises the complete carry-window decision table directly;
  LTB-0481 retains availability and dense public-entry refusal before work.
- LTB-0454 now exercises constructor provenance and metadata in memory;
  LTB-0482 retains sealing and public result disclosure for both universe
  kinds.

No fixture or semantic oracle was weakened. The codebase scanner reads each
source once, builds one combined reference-token parse, and accumulates
condition classes without repeatedly growing a character vector. Its census
is unchanged: 1,842 helpers, 2,401 condition references, 158 mode-branch sites
and 55 mode-flow sites. `tools/check-codebase-contracts.R --mode=check` passes.

LTB-0393 now keeps its counter in an option visible to the base `gc()` tracer.
The ordinary sequential arm observes zero explicit collections. Replacing only
the production `workers > 1L` guard with `TRUE` produces one collection and
fails the count assertion as well as the placement assertion.

The binding record is `evidence/ws51_fast/`, taken in three serial fresh R
processes on Windows 11, R 4.6.1, High performance power plan, and process
affinity `0xFFFF`. All 574 selected blocks passed in every run:

| Run | Seconds |
| --- | ---: |
| 1 | 106.88 |
| 2 | 106.74 |
| 3 | 107.32 |

The median is 106.88 seconds. The unchanged 112-second gate passes with 5.12
seconds of headroom. The preregistered 106.4-second durable-headroom target
misses by 0.48 seconds. The maintainer accepted that narrow secondary-target
miss on 2026-10-24; the bound, profile rules and claims remain unchanged.

The maintained long-window record passes its self-test (`LWREG_CHECK_OK`) and
`test-long-window-regression-control.R` passes. The workflow still executes
the review profile nightly and on release tags
(`.github/workflows/R-CMD-check.yaml`, review-profile step), while
`inst/design/release_ci_playbook.md` keeps hosted clocks advisory and the local
reference-host record binding.

## Workstream 52: set-wise readers

Implementation commits `3208c99e` and `3d6b3322` remove five bounded growth
shapes without changing a public API, schema, identity or condition:

- sweep candidate features are split once by candidate row;
- one fetched run-equity table is split once and accumulated into vectors;
- latest pulse bars use one set query and restore requested order and
  duplicates with `match()`;
- corporate-action composition formats all bar and effective timestamps in
  one vector call; and
- `ledgr_run_explain()` reads one instrument's trace and matching availability
  rows through one held run connection.

`evidence/ws52_h1/operation_counts.csv` records the source-derived expensive
units at 1, 7 and 31 groups or rows. LTB-0484 through LTB-0487 compare the
set-wise outputs with the former rules, pin the preparation boundary and cover
empty, duplicated, reordered and hostile-time shapes. Restoring each old
shape fails its owner: LTB-0484 and LTB-0485 each fail one preparation-count
assertion, LTB-0486 fails three query counts, and LTB-0487 fails the formatter
boundary. LTB-0063 separately fails when either the full diagnostics reader or
the full availability reader returns to `ledgr_run_explain()`.

The H1 reader record uses six alternating fresh processes, the same synthetic
800-instrument by 1,260-session fixture and strategy in both arms, R 4.6.1,
High priority and affinity `0xFFFF`. Each process builds and runs the fixture,
performs one untimed warm read after a full-GC counter reset, then records R's
peak used heap and the median of three warm explanation reads. The base is
accepted WS51 commit `0fd89a23`; the candidate product is `3d6b3322` (the
later `f96bfaa2` commit changes only a test helper).

| Measure | Base median | Candidate median | Ratio |
| --- | ---: | ---: | ---: |
| explanation elapsed | 1.3090 s | 0.2391 s | 0.1827 |
| explanation peak R heap | 514.1 MB | 252.9 MB | 0.4919 |

Both preregistered 0.95 gates pass. The dense-availability rows in the same
record are a non-gated control and remain within 2.8 percent in heap and 1.9
percent in elapsed time. This record measures R heap, not DuckDB native RSS.

An attempted full fixture-lane parity record stopped in its unchanged
`run_families()` reader projection on the base tree because a list had lengths
1, 0 and 3; no partial record is retained or claimed. Exactness is instead
owned independently by the four focused pre-rule comparisons, the existing
sweep-persistence, run-store, pulse-snapshot and corporate-action suites, and
the scalar/history/reopen explanation differential.

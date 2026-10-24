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

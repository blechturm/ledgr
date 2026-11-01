# Workstream 13 final candidate 15ea966a

15ea966a applies ws13_close_review_rereview_1.md (PASS_AFTER_PATCHES) N1, N2
and N3 verbatim on top of correction round 1 (d027c242). The maintainer's
session verified it on 2026-10-31/11-01, one R job at a time, on a clean
(non-covr) build.

| Gate | Outcome |
| --- | --- |
| check.R --base=HEAD | 23 cases identical |
| guts.R (36 registered guts) | 36 of 36 fail as expected; invalid-base control refused |
| dense check.R | PASS, nine native arms identical |
| A0 record + compare | 295 of 295 PASS (`a0-compare.csv`) |
| full suite (stop_on_failure) | exit 0 |
| R CMD build | exit 0 (outside the tracked tree) |
| R CMD check --no-manual --no-build-vignettes | exit 0; Status: 1 NOTE, the pre-existing `head` global in ledgr_history_bar_mask_view (`check-summary.txt`) |
| real data, six workloads, library E:/ledgr-data/r-lib/ledgr-ws4a-15ea966a | all COMPARE_IDENTICAL against E:/ledgr-data/reference/v0.2.3-base-953338df (`realdata.txt`, `realdata-sequence.log`) |

Coverage stays "not obtained" (covr child-result collection, tooling,
maintainer 2026-10-31; horizon.md). No timing or memory gate applies
(amendment_performance).
